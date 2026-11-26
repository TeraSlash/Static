if not CLIENT then return end


local CLICK_SOUND         = "player/dfujiclick.wav"
local STAGE_1_DURATION    = 0
local STAGE_1_MIN_DIST    = 60
local STAGE_1_MAX_DIST    = 120
local STAGE_1_MIN_HEIGHT  = -20
local STAGE_1_MAX_HEIGHT  = 0
local STAGE_1_LOOK_HEIGHT = 15
local BLACK_FADE_DURATION = 7
local BLACK_FADE_OUT_DURATION = 2
local REALISH_BLACK_FADE_DURATION = 0.35
local REALISH_BLACK_FADE_OUT_DURATION = 0.45
local DEATH_TEXT_FADE_IN  = 1
local OPTIONS_FADE_IN     = 1.0
local TRANSITION_DURATION = 0.6
local DOUBLE_CLICK_WINDOW = 0.5

local DEATH_SOUNDS = {
    [0] = "rem_brutaldeath.mp3",
}


local cfg_spectator     = true
local cfg_compat        = false
local cfg_options_delay = 4
local cfg_realish       = false

net.Receive("DeathEffect_Config", function()
    cfg_spectator     = net.ReadBool()
    cfg_compat        = net.ReadBool()
    cfg_options_delay = net.ReadFloat()
    cfg_realish       = net.ReadBool()




    timer.Simple(0, function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        if not ply:Alive() and not isDead then



            ply.DeathEffect_ServerDeathSignal = CurTime()
        end
    end)
end)


CreateClientConVar(
    "deatheffect_cam_max_dist", "150",
    true, false,
    "maximum camera follow distance in stage 2",
    40, 2000
)
CreateClientConVar(
    "deatheffect_cam_min_dist", "60",
    true, false,
    "minimum camera follow distance in stage 2",
    0, 2000
)
CreateClientConVar(
    "deatheffect_alt_sound", "0",
    true, false,
    "use the quieter death sound",
    0, 1
)
CreateClientConVar(
    "deatheffect_death_screen", "1",
    true, false,
    "enable the cinematic death screen",
    0, 1
)

local cv_cam_max_dist = GetConVar("deatheffect_cam_max_dist")
local cv_cam_min_dist = GetConVar("deatheffect_cam_min_dist")
local cv_alt_sound    = GetConVar("deatheffect_alt_sound")
local cv_death_screen = GetConVar("deatheffect_death_screen")

surface.CreateFont("DeathEffect_Key", { font = "Roboto", size = 52, weight = 700 })
surface.CreateFont("DeathEffect_Label", { font = "Roboto", size = 22, weight = 400 })
surface.CreateFont("DeathEffect_Hint", { font = "Roboto", size = 17, weight = 300 })

local hg_font = ConVarExists("hg_font") and GetConVar("hg_font") or nil
surface.CreateFont("DeathEffect_HG", { font = (hg_font and hg_font:GetString() ~= "" and hg_font:GetString()) or "Lora", size = 52, weight = 400, antialias = true })
surface.CreateFont("DeathEffect_HG_Large", { font = (hg_font and hg_font:GetString() ~= "" and hg_font:GetString()) or "Lora", size = 120, weight = 400, antialias = true })
surface.CreateFont("DeathEffect_HG_Desc", { font = (hg_font and hg_font:GetString() ~= "" and hg_font:GetString()) or "Lora", size = 28, weight = 400, antialias = true })


local function LookupKey(binding)
    local key = input.LookupBinding("+" .. binding) or input.LookupBinding(binding)
    if not key or key == "" then return KEY_UNKNOWN, "?" end
    return input.GetKeyCode(key), string.upper(key)
end

local reloadKeyCode, reloadKeyName = LookupKey("reload")
local jumpKeyCode,   jumpKeyName   = LookupKey("jump")
local crouchKeyCode, crouchKeyName = LookupKey("duck")
local sprintKeyCode, sprintKeyName = LookupKey("speed")

local function SafeKeyDown(code)
    if not code or code == KEY_UNKNOWN then return false end
    return input.IsButtonDown(code)
end

local m_pitch = GetConVar("m_pitch")
local m_yaw   = GetConVar("m_yaw")

local hasSpawned    = false
local isDead        = false
local stage2Started = false
local deathTime     = 0
local stage2Time    = 0
local autoCompatTriggered = false
local deathCamPos   = Vector(0, 0, 0)
local deathCamAng   = Angle(0, 0, 0)
local deathPos      = Vector(0, 0, 0)
local ragdollEnt    = nil
local matWhite      = Material("models/debug/debugwhite")

local deathSoundChannels = {}
local keepSoundAlive    = false

local inTransition        = false
local transitionStartTime = 0
local transitionCallback  = nil
local transitionFired     = false

local prevReloadDown = false
local prevJumpDown   = false

local compatActive     = false
local compatActiveTime = 0
local compatTriggered  = false

local inSpectator         = false
local freecamPos          = Vector(0, 0, 0)
local freecamAng          = Angle(0, 0, 0)
local lastReloadPressTime = 0
local prevSpecReloadDown  = false
local nextCamSync         = 0
local nextSoundfade       = 0


-- Filled in by the "video-style death" section at the end of this file (the camera lives in the body's eyes).
local GetRagdollEyeView, HideRagdollHead

-- the corpse that belongs to us
local function FindDeathRagdoll(ply)
    local rag = ply:GetNWEntity("RagdollDeath")
    if IsValid(rag) then return rag end
    rag = ply:GetRagdollEntity()
    if IsValid(rag) then return rag end
    rag = ply:GetNWEntity("FakeRagdoll")
    if IsValid(rag) then return rag end
end

-- While you are dead nothing but this file may decide what the camera shows. The gamemode's own view and other
-- addons (ActMod compatibility ...) also hook RenderScene / CalcView, and some of them win against ours, so every
-- other hook on those two events is parked until you respawn.
local takenHooks = {}
local authorityTaken = false

local function TakeHookEvent(event, keepName)
    local tbl = hook.GetTable()[event]
    if not tbl then return end

    local names = {}
    for name in pairs(tbl) do
        if name ~= keepName then names[#names + 1] = name end
    end

    takenHooks[event] = takenHooks[event] or {}
    for _, name in ipairs(names) do
        takenHooks[event][name] = tbl[name]
        hook.Remove(event, name)
    end
end

local function TakeAuthority()
    authorityTaken = true
    TakeHookEvent("RenderScene", "CinematicDeathRenderScene")
    TakeHookEvent("CalcView", "CinematicDeathCamera")
end

local function ReleaseAuthority()
    authorityTaken = false
    for event, parked in pairs(takenHooks) do
        for name, fn in pairs(parked) do
            hook.Add(event, name, fn)
        end
    end
    takenHooks = {}
end

local function DeathEffectRoundActive()
    if zb and zb.ROUND_STATE ~= nil then
        return zb.ROUND_STATE == 1
    end

    return true
end

local function DeathScreenEnabled()
    return not cv_death_screen or cv_death_screen:GetBool()
end

local function RealishDeathEffect()
    -- the video-style death plays in every mode, realish included
    return false
end

cvars.AddChangeCallback("deatheffect_death_screen", function(_, _, newValue)
    if newValue == "0" then
        ReleaseAuthority()
    elseif isDead and not compatActive then
        TakeAuthority()
    end
end, "DeathEffect_DeathScreenToggle")


local function PlayClick()
    sound.PlayFile("sound/" .. CLICK_SOUND, "noplay", function(ch)
        if IsValid(ch) then ch:Play() end
    end)
end

local function DoRespawn()
    net.Start("DeathEffect_Respawn")
    net.SendToServer()
end

local function EnterSpectator()
    inSpectator  = true
    freecamPos   = Vector(deathCamPos.x, deathCamPos.y, deathCamPos.z)
    freecamAng   = Angle(deathCamAng.pitch, deathCamAng.yaw, deathCamAng.roll)
    nextCamSync  = 0
    inTransition = false
    LocalPlayer():SetDSP(0)
    LocalPlayer():ConCommand("soundfade 0 1")
    net.Start("DeathEffect_EnterSpectator")
    net.SendToServer()
end

local function ActivateCompatMode()
    compatActive     = true
    compatActiveTime = CurTime()
    inTransition     = false
    LocalPlayer():SetDSP(0)
    LocalPlayer():ConCommand("soundfade 0 1")
    ReleaseAuthority() 
    net.Start("DeathEffect_CompatUnblock")
    net.SendToServer()
end

local function BeginTransition(callback)
    inTransition        = true
    transitionStartTime = CurTime()
    transitionCallback  = callback
    transitionFired     = false
    PlayClick()
end

local function InitDeathSequence(ply)
    if isDead then return end
    isDead           = true
    TakeAuthority()
    stage2Started    = false
    keepSoundAlive   = true
    inTransition     = false
    inSpectator      = false
    autoCompatTriggered = false
    compatActive     = false
    compatActiveTime = 0
    compatTriggered  = false
    deathTime        = CurTime()
    ragdollEnt       = FindDeathRagdoll(ply)
    prevReloadDown   = false
    prevJumpDown     = false
    prevSpecReloadDown = false

    local plyPos = ply:GetPos()
    deathPos     = plyPos

    local randYaw  = math.random(0, 360)
    local randDist = math.random(STAGE_1_MIN_DIST, STAGE_1_MAX_DIST)
    local offset   = Vector(
        math.cos(math.rad(randYaw)) * randDist,
        math.sin(math.rad(randYaw)) * randDist,
        math.random(STAGE_1_MIN_HEIGHT, STAGE_1_MAX_HEIGHT)
    )

    local traceStart = plyPos + Vector(0, 0, 40)
    
    local tr = util.TraceLine({
        start  = traceStart,
        endpos = traceStart + offset,
        mask   = MASK_SOLID_BRUSHONLY
    })

    deathCamPos = tr.HitPos + tr.HitNormal * 5
    deathCamAng = (plyPos + Vector(0, 0, STAGE_1_LOOK_HEIGHT) - deathCamPos):Angle()

    deathSoundChannels = {}
    for _, deathSound in pairs(DEATH_SOUNDS) do
        sound.PlayFile("sound/" .. deathSound, "noplay", function(station)
            if IsValid(station) then
                deathSoundChannels[#deathSoundChannels + 1] = station
                station:Play()
            end
        end)
    end
end


local function CinematicDeathTracker()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if not DeathEffectRoundActive() then
        hasSpawned = ply:Alive()

        if isDead then
            isDead = false
            stage2Started = false
            keepSoundAlive = false
            inTransition = false
            inSpectator = false
            autoCompatTriggered = false
            compatActive = false
            ReleaseAuthority()

            if IsValid(ragdollEnt) then
                ragdollEnt:SetNoDraw(false)
            end
            ragdollEnt = nil

            ply:SetDSP(0)
            ply:ConCommand("soundfade 0 1")

            for _, station in ipairs(deathSoundChannels) do
                if IsValid(station) then
                    station:Stop()
                end
            end
            deathSoundChannels = {}

            if ply:GetNWBool("DeathEffect_BlockRespawn", false) then
                net.Start("DeathEffect_CompatUnblock")
                net.SendToServer()
            end
        end

        return
    end

    if isDead and input.IsButtonDown(KEY_BACKSPACE) then
        isDead = false
        hasSpawned = false
        ReleaseAuthority()
        ply:SetDSP(0)
        ply:ConCommand("soundfade 0 1")
        if IsValid(ragdollEnt) then
            ragdollEnt:SetNoDraw(false)
        end
        if IsValid(deathSoundChannel) then
            deathSoundChannel:Stop()
            deathSoundChannel = nil
        end

        if ply:GetNWBool("DeathEffect_BlockRespawn", false) then
            net.Start("DeathEffect_CompatUnblock")
            net.SendToServer()
        end
        return
    end

    if ply:Alive() and not hasSpawned then
        hasSpawned = true
    end

    if not ply:Alive() and not isDead and hasSpawned then
        InitDeathSequence(ply)
    elseif not ply:Alive() and not isDead and ply:GetNWBool("DeathEffect_BlockRespawn", false) then



        if not ply.DeathEffect_ClientBlockStart then
            ply.DeathEffect_ClientBlockStart = CurTime()
        end
        if (CurTime() - ply.DeathEffect_ClientBlockStart) > 0.5 or ply.DeathEffect_ServerDeathSignal then

            if ply.DeathEffect_ServerDeathSignal and (CurTime() - ply.DeathEffect_ServerDeathSignal) < 5 then
                InitDeathSequence(ply)
                ply.DeathEffect_ClientBlockStart = nil
                ply.DeathEffect_ServerDeathSignal = nil
            elseif (CurTime() - ply.DeathEffect_ClientBlockStart) > 0.5 then
                InitDeathSequence(ply)
                ply.DeathEffect_ClientBlockStart = nil
                ply.DeathEffect_ServerDeathSignal = nil
            end
        end
    else
        if ply:GetNWBool("DeathEffect_BlockRespawn", false) and ply:Alive() then

            ply.DeathEffect_ClientBlockStart = nil
            ply.DeathEffect_ServerDeathSignal = nil
        elseif not ply:GetNWBool("DeathEffect_BlockRespawn", false) then
            ply.DeathEffect_ClientBlockStart = nil

            if ply.DeathEffect_ServerDeathSignal and (CurTime() - ply.DeathEffect_ServerDeathSignal) > 5 then
                ply.DeathEffect_ServerDeathSignal = nil
            end
        end
    end

    if ply:Alive() and isDead then
        isDead         = false
        stage2Started  = false
        keepSoundAlive = false
        inTransition   = false
        inSpectator    = false
        autoCompatTriggered = false
        compatActive   = false
        ReleaseAuthority() 
        
        if IsValid(ragdollEnt) then
            ragdollEnt:SetNoDraw(false)
        end
        ragdollEnt = nil

        ply:SetDSP(0)
        ply:ConCommand("soundfade 0 1")

        for _, station in ipairs(deathSoundChannels) do
            if IsValid(station) then
                station:Stop()
            end
        end
        deathSoundChannels = {}
    end

    if isDead and not stage2Started then
        if (CurTime() - deathTime) >= STAGE_1_DURATION then
            stage2Started = true
            stage2Time    = CurTime()
            if DeathScreenEnabled() and not RealishDeathEffect() then
                LocalPlayer():SetDSP(17)
                LocalPlayer():ConCommand("soundfade 100 99999")
            end
        end
    end


    if isDead and not compatActive and DeathScreenEnabled() and not RealishDeathEffect() then
        ply:SetViewPunchAngles(Angle(0,0,0))
        ply:ScreenFade(SCREENFADE.IN, Color(0,0,0,0), 0.1, 0)
        
        if stage2Started and not inSpectator then
            ply:SetDSP(17)

            if CurTime() >= nextSoundfade then
                nextSoundfade = CurTime() + 0.5
                ply:ConCommand("soundfade 100 99999")
            end
        end
    end

    if isDead and keepSoundAlive then
        local t = CurTime() - deathTime
        local anyPlaying = false
        for _, station in ipairs(deathSoundChannels) do
            if IsValid(station) and t < station:GetLength() then
                anyPlaying = true
                if station:GetState() ~= 1 then
                    station:Play()
                    station:SetTime(t, false)
                end
            end
        end
        if #deathSoundChannels > 0 and not anyPlaying then
            keepSoundAlive = false
        end
    end

    if isDead and not IsValid(ragdollEnt) then
        ragdollEnt = FindDeathRagdoll(ply)
        if not IsValid(ragdollEnt) then
            local bestDist = math.huge
            for _, ent in ipairs(ents.FindByClass("prop_ragdoll")) do
                if ent:GetModel() == ply:GetModel() then
                    local dist = ent:GetPos():DistToSqr(deathPos)
                    if dist < 100000 and dist < bestDist then
                        ragdollEnt = ent
                        bestDist   = dist
                    end
                end
            end
        end
    end

    if inTransition and not transitionFired then
        if (CurTime() - transitionStartTime) >= TRANSITION_DURATION then
            transitionFired = true
            PlayClick()
            if transitionCallback then
                transitionCallback()
                transitionCallback = nil
            end
        end
    end

    if isDead and stage2Started and not autoCompatTriggered then
        local fadeDuration = RealishDeathEffect() and REALISH_BLACK_FADE_DURATION or BLACK_FADE_DURATION
        local fadeOutDuration = RealishDeathEffect() and REALISH_BLACK_FADE_OUT_DURATION or BLACK_FADE_OUT_DURATION

        if (CurTime() - stage2Time) >= (fadeDuration + fadeOutDuration) then
            autoCompatTriggered = true
            ActivateCompatMode()
        end
    end




    if not isDead and not ply:Alive() and ply:GetNWBool("DeathEffect_BlockRespawn", false) then
        if ply.DeathEffect_ClientBlockStart and (CurTime() - ply.DeathEffect_ClientBlockStart) > 8 then
            ply.DeathEffect_ClientBlockStart = nil
            ply.DeathEffect_ServerDeathSignal = nil
            net.Start("DeathEffect_CompatUnblock")
            net.SendToServer()
        end
    end

    if inSpectator and not inTransition then
        local reloadDown = SafeKeyDown(reloadKeyCode)

        if reloadDown and not prevSpecReloadDown then
            local now = CurTime()
            if (now - lastReloadPressTime) <= DOUBLE_CLICK_WINDOW then
                BeginTransition(DoRespawn)
            else
                lastReloadPressTime = now
            end
        end

        prevSpecReloadDown = reloadDown

        local timeNow = CurTime()
        if timeNow >= nextCamSync then
            nextCamSync = timeNow + 0.05
            net.Start("DeathEffect_UpdateCam")
                net.WriteVector(freecamPos)
                net.WriteAngle(freecamAng)
            net.SendToServer()
        end
    end
end
hook.Add("Think", "CinematicDeathTracker", CinematicDeathTracker)


local function CinematicDeathFreecamLook(cmd)
    if not inSpectator then return end
    local mX = cmd:GetMouseX()
    local mY = cmd:GetMouseY()
    freecamAng.pitch = math.Clamp(freecamAng.pitch + mY * m_pitch:GetFloat(), -89, 89)
    freecamAng.yaw   = freecamAng.yaw - mX * m_yaw:GetFloat()
    freecamAng.roll  = 0
    cmd:SetViewAngles(freecamAng)
end
hook.Add("CreateMove", "CinematicDeathFreecamLook", CinematicDeathFreecamLook)


local function BuildDeathView(fov)
    if RealishDeathEffect() then return end

    -- (compat mode and the death itself: you keep looking out of the body when it is there)
    if compatActive then
        local eyePos, eyeAng = GetRagdollEyeView()
        if eyePos then
            HideRagdollHead(ragdollEnt)
            return { origin = eyePos, angles = eyeAng, fov = fov, znear = 1, drawviewer = false }
        end
        return {
            origin     = LocalPlayer():EyePos(),
            angles     = LocalPlayer():EyeAngles(),
            fov        = fov,
            drawviewer = false,
        }
    end

    if inSpectator then
        local dt        = FrameTime()
        local speedMult = SafeKeyDown(sprintKeyCode) and 3 or 1
        local speed     = 200 * dt * speedMult
        local fwd       = freecamAng:Forward()
        local right     = freecamAng:Right()
        local up        = Vector(0, 0, 1)

        if input.IsButtonDown(KEY_W) then freecamPos = freecamPos + fwd   * speed end
        if input.IsButtonDown(KEY_S) then freecamPos = freecamPos - fwd   * speed end
        if input.IsButtonDown(KEY_A) then freecamPos = freecamPos - right * speed end
        if input.IsButtonDown(KEY_D) then freecamPos = freecamPos + right * speed end
        if SafeKeyDown(jumpKeyCode)   then freecamPos = freecamPos + up   * speed end
        if SafeKeyDown(crouchKeyCode) then freecamPos = freecamPos - up   * speed end

        return { origin = freecamPos, angles = freecamAng, fov = fov, drawviewer = false }
    end

    -- stay attached to the limp body: see what the corpse sees
    local eyePos, eyeAng = GetRagdollEyeView()
    if eyePos then
        HideRagdollHead(ragdollEnt)
        return { origin = eyePos, angles = eyeAng, fov = fov, znear = 1, drawviewer = false }
    end

    -- the ragdoll has not shown up yet: stay exactly where the player was looking
    local ply = LocalPlayer()
    return { origin = ply:EyePos(), angles = ply:EyeAngles(), fov = fov, drawviewer = false }
end


local function CinematicDeathCamera(ply, pos, angles, fov)
    if not isDead then return end
    return BuildDeathView(fov)
end
hook.Add("CalcView", "CinematicDeathCamera", CinematicDeathCamera)

local function CinematicDeathHGCalcView(ply, origin, angles, fov, znear, zfar)
    if not isDead then return end
    return BuildDeathView(fov)
end
hook.Add("HG_CalcView", "CinematicDeathHGOverride", CinematicDeathHGCalcView)


local function CinematicDeathMute()
    if isDead and stage2Started and not inSpectator and not compatActive and DeathScreenEnabled() and not RealishDeathEffect() then
        return false
    end
end
hook.Add("EntityEmitSound", "CinematicDeathMute", CinematicDeathMute)

local function CinematicDeathHideRagdoll()
    if not isDead or not IsValid(ragdollEnt) or compatActive or not DeathScreenEnabled() or RealishDeathEffect() then return end
    
    if (CurTime() - deathTime) < STAGE_1_DURATION then
        ragdollEnt:SetNoDraw(true)
    else
        ragdollEnt:SetNoDraw(false)
    end
end
hook.Add("PreDrawOpaqueRenderables", "CinematicDeathHideRagdoll", CinematicDeathHideRagdoll)

local function CinematicDeathBackground()
    if not isDead or compatActive then return end

    local sw, sh  = ScrW(), ScrH()
    local elapsed = CurTime() - deathTime

    if inTransition then
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, sw, sh)
        return
    end

    if inSpectator then
        local hint = "double click [" .. reloadKeyName .. "] to respawn"
        surface.SetFont("DeathEffect_Hint")
        local hw = surface.GetTextSize(hint)
        surface.SetTextColor(Color(180, 180, 180, 140))
        surface.SetTextPos(sw / 2 - hw / 2, 20)
        surface.DrawText(hint)
        return
    end

end
hook.Add("DrawOverlay", "CinematicDeathBackground", CinematicDeathBackground)

local function HideDefaultDamage(name)
    if isDead and name == "CHudDamageIndicator" then return false end
end
hook.Add("HUDShouldDraw", "HideDefaultDamage", HideDefaultDamage)


local deathRenderView = {
    x = 0, y = 0, drawhud = true, drawviewmodel = false, dopostprocess = true, drawmonitors = true,
}
local renderingDeathView = false

local function CinematicDeathRenderScene(pos, angle, fov)
    if not isDead or renderingDeathView then return end

    local view = BuildDeathView(fov)
    if not view then return end

    deathRenderView.w          = ScrW()
    deathRenderView.h          = ScrH()
    deathRenderView.fov        = view.fov or fov
    deathRenderView.znear      = view.znear or 1
    deathRenderView.origin     = view.origin
    deathRenderView.angles     = view.angles
    deathRenderView.drawviewer = view.drawviewer

    renderingDeathView = true
    render.RenderView(deathRenderView)
    renderingDeathView = false

    return true
end
hook.Add("RenderScene", "CinematicDeathRenderScene", CinematicDeathRenderScene)



-- =============================================================================================
-- VIDEO-STYLE DEATH
-- =============================================================================================
-- Every death looks like the reference video:
--   0.0 - 1.0s   you look out of the body, the colour drains to grey
--   0.8 - 1.2s   the edges close in and the picture goes black
--   1.2 - 1.6s   pure black
--   1.6s on      the static fades in out of the black (2s) - and a noise fades in with it
-- Headshot / explosion / killbrick (flagged by sv_cdeath.lua): BLACK AT ONCE, then the static fades in.
-- Console: deathstatic_test (normal death) / deathstatic_test 1 (instant death) previews it for 10 seconds,
--          deathstatic_debug 1 prints the state once per second.
-- Settings > Gameplay: "Death static" (on/off: off = only the camera in the body) and "Death static loudness (%)".

local DEATH_GREY_TIME   = 1.0   -- seconds for the colour to drain completely
local DEATH_DARK_START  = 0.8   -- when the picture starts to close in
local DEATH_DARK_TIME   = 0.4   -- how long it takes to go fully black
local DEATH_BLACK_HOLD  = 0.4   -- seconds of pure black before the static starts
local STATIC_FADE_TIME  = 2.0   -- seconds the static takes to fade in out of the black
local STATIC_MIN_VOLUME = 0.0   -- loudness when the static first starts
local STATIC_MAX_VOLUME = 1.0   -- loudness at full static (before the slider)

local cv_death_static  = CreateClientConVar("hg_death_static", "1", true, false, "Fade to static when you die", 0, 1)
local cv_static_volume = CreateClientConVar("hg_death_static_volume", "100", true, false, "Loudness of the death static noise, in percent (0 - 120)", 0, 120)
local cv_static_debug  = CreateClientConVar("deathstatic_debug", "0", true, false, "print the state of the static death once per second")

-- state
local ownDeathStart, ownHasLived = 0, false   -- the local player's own death (does not wait for the tracker above)
local instantStart = 0                        -- when the instant-death flag first showed up (0 = not an instant death)
local testUntil, testStart, testInstant = 0, 0, false
local eyePosSmooth, eyeAngSmooth = nil, nil
local headHiddenEnt, headHiddenBone, headHiddenPrev = nil, nil, nil
local staticStation, staticLoading = nil, false

-- ---- the camera in the body -------------------------------------------------------------
-- (smoothed so a tumbling ragdoll does not shake the screen apart)
GetRagdollEyeView = function()
    if not IsValid(ragdollEnt) then return end

    local pos, ang
    local attID = ragdollEnt:LookupAttachment("eyes")
    if attID and attID > 0 then
        local att = ragdollEnt:GetAttachment(attID)
        if att then pos, ang = att.Pos, att.Ang end
    end

    if not pos then
        local bone = ragdollEnt:LookupBone("ValveBiped.Bip01_Head1")
        if not bone then return end
        pos, ang = ragdollEnt:GetBonePosition(bone)
        if not pos then return end
    end

    local t = math.min(FrameTime() * 25, 1)
    eyePosSmooth = eyePosSmooth and LerpVector(t, eyePosSmooth, pos) or pos
    eyeAngSmooth = eyeAngSmooth and LerpAngle(t, eyeAngSmooth, ang) or ang

    -- spectator mode starts from wherever the corpse was looking
    deathCamPos = Vector(eyePosSmooth.x, eyePosSmooth.y, eyePosSmooth.z)
    deathCamAng = Angle(eyeAngSmooth.p, eyeAngSmooth.y, eyeAngSmooth.r)

    return eyePosSmooth, eyeAngSmooth
end

-- hide the corpse's head while we are inside it
HideRagdollHead = function(ent)
    if headHiddenEnt == ent or not IsValid(ent) then return end
    local bone = ent:LookupBone("ValveBiped.Bip01_Head1")
    if not bone then return end

    local prev = ent:GetManipulateBoneScale(bone)
    if prev.x < 0.5 then return end -- already gone (headshot), leave it alone

    headHiddenEnt, headHiddenBone, headHiddenPrev = ent, bone, prev
    ent:ManipulateBoneScale(bone, Vector(0.01, 0.01, 0.01))
end

local function RestoreRagdollHead()
    if IsValid(headHiddenEnt) and headHiddenBone then
        headHiddenEnt:ManipulateBoneScale(headHiddenBone, headHiddenPrev or Vector(1, 1, 1))
    end
    headHiddenEnt, headHiddenBone, headHiddenPrev = nil, nil, nil
end

-- ---- which kind of death, and how far along it is ---------------------------------------
-- the server flags a headshot / explosion / killbrick the moment it happens (sv_cdeath.lua)
local function HeadshotFlagged()
    local ply = LocalPlayer()
    if not IsValid(ply) then return false end
    local flaggedAt = ply:GetNWFloat("DeathEffect_HeadshotTime", 0)
    return flaggedAt > 0 and (CurTime() - flaggedAt) < 15
end

local function IsInstantDeath()
    if testUntil > CurTime() then return testInstant end
    return instantStart > 0
end

local function Smooth(x)
    x = math.Clamp(x, 0, 1)
    return x * x * (3 - 2 * x)
end

-- seconds since this death began (the test command has its own clock)
local function DeathClock()
    if testUntil > CurTime() then return CurTime() - testStart end
    if ownDeathStart > 0 then return CurTime() - ownDeathStart end
    return CurTime() - deathTime
end

-- 0 = clear picture, 1 = pure static
local function GetStaticLevel()
    if IsInstantDeath() then
        local since = (testUntil > CurTime()) and (CurTime() - testStart) or (CurTime() - instantStart)
        return Smooth(since / STATIC_FADE_TIME)
    end
    local staticStartsAt = DEATH_DARK_START + DEATH_DARK_TIME + DEATH_BLACK_HOLD
    return Smooth((DeathClock() - staticStartsAt) / STATIC_FADE_TIME)
end

-- how far the colour has drained (normal deaths)
local function GetGreyLevel()
    if IsInstantDeath() then return 0 end
    return Smooth(DeathClock() / DEATH_GREY_TIME)
end

-- how far the picture has closed in to black: 0 = not at all, 1 = black
local function GetDarkLevel()
    if IsInstantDeath() then return 1 end
    return Smooth((DeathClock() - DEATH_DARK_START) / DEATH_DARK_TIME)
end

-- true while the effect is on screen
local function StaticDeathActive()
    if testUntil > CurTime() then return true end
    if not cv_death_static:GetBool() then return false end
    if HeadshotFlagged() and not inTransition then return true end
    return (isDead or ownDeathStart > 0) and not inSpectator and not inTransition
end

-- ---- the noise picture and the noise sound -----------------------------------------------
-- --- noise picture: a 512x512 texture of random grey pixels, drawn with random offsets every frame ---
local NOISE_SIZE = 512
local NOISE_ROWS_PER_FRAME = 32
local noiseRT, noiseMat
local noiseRows = 0
local noiseReady = false

local function FillNoiseChunk()
    if not noiseRT then
        local ok = pcall(function()
            noiseRT = GetRenderTarget("zc_death_static_rt_v1", NOISE_SIZE, NOISE_SIZE)
            noiseMat = CreateMaterial("zc_death_static_mat_v1", "UnlitGeneric", {
                ["$basetexture"] = noiseRT:GetName(),
                ["$vertexalpha"] = 1,
                ["$vertexcolor"] = 1,
                ["$nolod"] = 1,
            })
        end)
        if not ok then
            noiseRT, noiseMat = nil, nil
            noiseReady = true -- give up on the texture, the coarse fallback is used instead
            return
        end
    end

    render.PushRenderTarget(noiseRT)
    cam.Start2D()
        if noiseRows == 0 then
            render.Clear(0, 0, 0, 255)
        end
        for y = noiseRows, math.min(noiseRows + NOISE_ROWS_PER_FRAME - 1, NOISE_SIZE - 1) do
            for x = 0, NOISE_SIZE - 1 do
                local v = math.random(0, 255)
                surface.SetDrawColor(v, v, v, 255)
                surface.DrawRect(x, y, 1, 1)
            end
        end
    cam.End2D()
    render.PopRenderTarget()

    noiseRows = noiseRows + NOISE_ROWS_PER_FRAME
    if noiseRows >= NOISE_SIZE then
        noiseReady = true
    end
end

-- built a few rows per frame at startup so there is no hitch
hook.Add("PostRender", "DeathStaticFill", function()
    if noiseReady then
        hook.Remove("PostRender", "DeathStaticFill")
        return
    end
    FillNoiseChunk()
end)

local function DrawStatic(level, w, h)
    local alpha = math.floor(255 * math.min(level * 1.15, 1) ^ 0.9)

    if noiseMat then
        local scale = math.max(4, w / (NOISE_SIZE * 0.98)) -- screen pixels per noise pixel
        local spanU = w / (NOISE_SIZE * scale)
        local spanV = h / (NOISE_SIZE * scale)
        local u0 = math.Rand(0, 1 - spanU)
        local v0 = math.Rand(0, 1 - spanV)
        local u1, v1 = u0 + spanU, v0 + spanV
        if math.random() < 0.5 then u0, u1 = u1, u0 end
        if math.random() < 0.5 then v0, v1 = v1, v0 end

        surface.SetMaterial(noiseMat)
        surface.SetDrawColor(255, 255, 255, alpha)
        surface.DrawTexturedRectUV(0, 0, w, h, u0, v0, u1, v1)

        -- torn bands that get brighter as the signal dies
        if level > 0.2 then
            for _ = 1, 3 do
                if math.random() < 0.5 then
                    local bandH = math.random(6, 40) * (h / 1080)
                    local by = math.random(0, math.max(h - bandH, 1))
                    local uu = math.Rand(0, 1 - spanU)
                    surface.SetDrawColor(255, 255, 255, math.min(255, alpha + 60))
                    surface.DrawTexturedRectUV(0, by, w, bandH, uu, v0, uu + spanU, math.min(v0 + bandH / (NOISE_SIZE * scale), 1))
                end
            end
        end
    else
        -- texture not available: coarse random blocks
        local block = math.max(10, math.ceil(math.sqrt(w * h / 9000)))
        for y = 0, h, block do
            for x = 0, w, block do
                local v = math.random(0, 255)
                surface.SetDrawColor(v, v, v, alpha)
                surface.DrawRect(x, y, block, block)
            end
        end
    end

    -- scanlines and a slow rolling dark bar, like an old tube TV
    surface.SetDrawColor(0, 0, 0, 55 * level)
    for y = 0, h, 4 do
        surface.DrawRect(0, y, w, 1)
    end
    local rollY = ((CurTime() * 0.35) % 1) * h * 1.3 - h * 0.15
    surface.SetDrawColor(0, 0, 0, 45 * level)
    surface.DrawRect(0, rollY, w, h * 0.12)
end

-- --- noise sound: white noise written to data/ once, then looped ---
local STATIC_WAV = "zcity_death_static_v2.wav" -- v2: louder noise than the first version

local function WriteString(f, str)
    for i = 1, #str do
        f:WriteByte(string.byte(str, i))
    end
end

local function EnsureStaticWav()
    if file.Exists(STATIC_WAV, "DATA") then return true end

    local rate = 22050
    local samples = rate * 2
    local dataSize = samples * 2

    local f = file.Open(STATIC_WAV, "wb", "DATA")
    if not f then return false end

    WriteString(f, "RIFF")
    f:WriteLong(36 + dataSize)
    WriteString(f, "WAVE")
    WriteString(f, "fmt ")
    f:WriteLong(16)
    f:WriteShort(1)          -- PCM
    f:WriteShort(1)          -- mono
    f:WriteLong(rate)
    f:WriteLong(rate * 2)
    f:WriteShort(2)
    f:WriteShort(16)
    WriteString(f, "data")
    f:WriteLong(dataSize)
    for _ = 1, samples do
        f:WriteShort(math.random(-30000, 30000))
    end
    f:Close()

    return true
end

local function StopStaticSound()
    if IsValid(staticStation) then
        staticStation:Stop()
    end
    staticStation = nil
end

local staticWanted = false -- set every frame from StaticDeathActive()
local STATIC_SOUND_PATHS = {"sound/static/death_static.wav", "data/" .. STATIC_WAV}
local staticPathIndex = 1

local function UpdateStaticSound(level)
    if not IsValid(staticStation) then
        if staticLoading then return end
        local path = STATIC_SOUND_PATHS[staticPathIndex]
        if not path then return end
        if staticPathIndex == 2 and not EnsureStaticWav() then return end

        staticLoading = true
        sound.PlayFile(path, "noplay", function(station)
            staticLoading = false
            if not IsValid(station) then
                staticPathIndex = staticPathIndex + 1 -- that file isn't available, try the next one
                return
            end
            if not staticWanted then
                station:Stop()
                return
            end
            station:EnableLooping(true)
            station:SetVolume(0)
            station:Play()
            staticStation = station
        end)
        return
    end

    -- fades in with the picture; the slider scales the whole thing (up to 120%)
    local loudness = math.Clamp(cv_static_volume:GetFloat() / 100, 0, 1.2)
    staticStation:SetVolume(math.Clamp(Lerp(level, STATIC_MIN_VOLUME, STATIC_MAX_VOLUME) * loudness, 0, 1.2))
    if staticStation:GetState() == GMOD_CHANNEL_STOPPED then
        staticStation:SetTime(0)
        staticStation:Play()
    end
end


-- ---- drawing ---------------------------------------------------------------------------
-- vignette textures: opaque at the named edge, fading out towards the middle
local deathGradientL = surface.GetTextureID("vgui/gradient-l")
local deathGradientR = surface.GetTextureID("vgui/gradient-r")
local deathGradientU = surface.GetTextureID("vgui/gradient-u")
local deathGradientD = surface.GetTextureID("vgui/gradient-d")

-- HUDPaint, not DrawOverlay: panels (the esc menu) are drawn after HUDPaint, so the menu sits ON TOP of the death
-- (HOOK_LOW = last of the HUD hooks, so it still covers the rest of the HUD)
hook.Add("HUDPaint", "DeathStaticOverlay", function()
    if not StaticDeathActive() then return end

    local w, h = ScrW(), ScrH()
    local dark = GetDarkLevel()
    if dark >= 1 then
        -- solid black (instant deaths start here); the static brightens out of it
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, w, h)
    elseif dark > 0 then
        -- the edges close in towards the middle, then the middle goes out as well
        surface.SetDrawColor(0, 0, 0, 255)
        local sideW, sideH = dark * w * 0.6, dark * h * 0.6
        surface.SetTexture(deathGradientL)
        surface.DrawTexturedRect(0, 0, sideW, h)
        surface.SetTexture(deathGradientR)
        surface.DrawTexturedRect(w - sideW, 0, sideW, h)
        surface.SetTexture(deathGradientU)
        surface.DrawTexturedRect(0, 0, w, sideH)
        surface.SetTexture(deathGradientD)
        surface.DrawTexturedRect(0, h - sideH, w, sideH)
        surface.SetDrawColor(0, 0, 0, 255 * math.Clamp((dark - 0.6) / 0.4, 0, 1))
        surface.DrawRect(0, 0, w, h)
    end

    local level = GetStaticLevel()
    if level <= 0 then return end
    DrawStatic(level, w, h)
end, HOOK_LOW or 1)

-- the colour drains to grey
hook.Add("RenderScreenspaceEffects", "DeathStaticColor", function()
    if not StaticDeathActive() then return end
    local level = GetGreyLevel()
    if level <= 0 then return end
    DrawColorModify({
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = 0,
        ["$pp_colour_contrast"] = 1 + level * 0.25,
        ["$pp_colour_colour"] = 1 - level * 0.92,
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0,
    })
end)

-- ---- guaranteed priority for the camera ----------------------------------------------------
-- Even with the other hooks parked, something may still answer first. While dead we sit on top of hook.Call.
local originalHookCall, wrappedHookCall = nil, nil

local function InstallHookCallWrapper()
    if hook.Call == wrappedHookCall then return end

    originalHookCall = hook.Call
    wrappedHookCall = function(name, gm, ...)
        if isDead and (name == "RenderScene" or name == "CalcView") then
            local ok, result
            if name == "RenderScene" then
                ok, result = pcall(CinematicDeathRenderScene, ...)
            else
                -- CalcView arguments: ply, origin, angles, fov, znear, zfar
                local _, _, _, fov = ...
                ok, result = pcall(BuildDeathView, fov)
            end

            if ok then
                if result ~= nil then return result end
            else
                ErrorNoHaltWithStack(result)
            end
        end

        return originalHookCall(name, gm, ...)
    end
    hook.Call = wrappedHookCall
end

local function RemoveHookCallWrapper()
    if hook.Call == wrappedHookCall and originalHookCall then
        hook.Call = originalHookCall
    end
end

-- ---- every frame ---------------------------------------------------------------------------
local nextAuthorityCheck, nextHookCheck, nextDebugPrint, aliveSince = 0, 0, 0, nil

hook.Add("Think", "DeathStaticThink", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    -- the local player's own death: starts when you stop being alive, ends when you respawn
    if lp:Alive() then
        ownHasLived = true
        ownDeathStart = 0
    elseif ownHasLived and ownDeathStart == 0 then
        ownDeathStart = CurTime()
    end

    -- instant death: remember when the flag first showed up (cleared again on respawn)
    if HeadshotFlagged() then
        if instantStart == 0 then instantStart = CurTime() end
    else
        instantStart = 0
    end

    staticWanted = StaticDeathActive()
    if staticWanted then
        UpdateStaticSound(GetStaticLevel())
    else
        StopStaticSound()
    end

    -- your own hats and glasses would be right in front of the camera (read by RenderAccessories)
    lp.DeathHideAccessories = isDead or nil

    -- other scripts may re-add their camera hooks while we are dead
    if authorityTaken and CurTime() > nextAuthorityCheck then
        nextAuthorityCheck = CurTime() + 0.25
        TakeAuthority()
    end

    if isDead then
        if CurTime() > nextHookCheck then
            nextHookCheck = CurTime() + 1
            InstallHookCallWrapper()
        end
    else
        RemoveHookCallWrapper()
        RestoreRagdollHead()
    end

    -- safety net: if the death state sticks after you are alive again, end it ourselves
    if isDead and lp:Alive() then
        aliveSince = aliveSince or CurTime()
        if CurTime() - aliveSince > 0.75 then
            aliveSince = nil
            isDead = false
            stage2Started = false
            inTransition = false
            inSpectator = false
            compatActive = false
            ReleaseAuthority()
            RemoveHookCallWrapper()
            RestoreRagdollHead()
            StopStaticSound()
            if IsValid(ragdollEnt) then ragdollEnt:SetNoDraw(false) end
            ragdollEnt = nil
            lp.DeathHideAccessories = nil
        end
    else
        aliveSince = nil
    end

    if cv_static_debug:GetBool() and CurTime() > nextDebugPrint then
        nextDebugPrint = CurTime() + 1
        print(string.format("[DeathStatic] isDead=%s ownDeath=%.1f instant=%s active=%s level=%.2f ragdoll=%s authority=%s noise=%s sound=%s",
            tostring(isDead), ownDeathStart > 0 and (CurTime() - ownDeathStart) or 0, tostring(IsInstantDeath()),
            tostring(StaticDeathActive()), GetStaticLevel(), tostring(IsValid(ragdollEnt)), tostring(authorityTaken),
            tostring(noiseReady and noiseMat ~= nil), tostring(IsValid(staticStation))))
    end
end)

-- type  deathstatic_test  (or  deathstatic_test 1  for the instant version) to see/hear it for 10 seconds
concommand.Add("deathstatic_test", function(_, _, args)
    testStart = CurTime()
    testUntil = CurTime() + 10
    testInstant = args[1] == "1"
end)
