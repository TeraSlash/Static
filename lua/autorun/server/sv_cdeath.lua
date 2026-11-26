if not SERVER then return end


CreateConVar(
    "deatheffect_spectator", "1",
    bit.bor(FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE),
    "allow players to enter spectator mode on the death screen",
    0, 1
)
CreateConVar(
    "deatheffect_compat", "0",
    bit.bor(FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE),
    "remove all cinematic effects before the option screen appears, for better compatibility with other mods",
    0, 1
)
CreateConVar(
    "deatheffect_options_delay", "4",
    bit.bor(FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE),
    "how many seconds it takes for the respawn/spectator options to show up",
    0, 60
)


util.AddNetworkString("DeathEffect_Respawn")
util.AddNetworkString("DeathEffect_UpdateCam")
util.AddNetworkString("DeathEffect_EnterSpectator")
util.AddNetworkString("DeathEffect_CompatUnblock")
util.AddNetworkString("DeathEffect_Config")

local function DeathEffectRoundActive()
    if zb and zb.ROUND_STATE ~= nil then
        return zb.ROUND_STATE == 1
    end

    return true
end

local function DeathEffect_GetTimerName(ply)
    if not IsValid(ply) then return nil end

    local id = ply:SteamID64()
    if id and id ~= "" then
        return "DeathEffect_AutoUnblock_" .. id
    end
    return "DeathEffect_AutoUnblock_EI" .. ply:EntIndex()
end

local function DeathEffect_ClearBlock(ply, removeTimer)
    if not IsValid(ply) then return end
    ply:SetNWBool("DeathEffect_BlockRespawn", false)
    ply.DeathEffect_DeathTime = nil
    if removeTimer ~= false then
        local tname = DeathEffect_GetTimerName(ply)
        if tname then timer.Remove(tname) end
    end
end



hook.Add("PlayerDeathThink", "DeathEffect_BlockRespawn", function(ply)
    if ply:GetNWBool("DeathEffect_BlockRespawn", false) then


        local dt = ply.DeathEffect_DeathTime
        if not dt then

            ply.DeathEffect_DeathTime = CurTime() - 11
            return false
        end
        if (CurTime() - dt) > 12 then
            DeathEffect_ClearBlock(ply, true)
            return
        end
        return false
    else

        if ply.DeathEffect_DeathTime and ply:Alive() then
            ply.DeathEffect_DeathTime = nil
        end
    end
end)


timer.Create("DeathEffect_StuckSweep", 5, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:GetNWBool("DeathEffect_BlockRespawn", false) and not ply:Alive() then
            local dt = ply.DeathEffect_DeathTime
            if not dt then
                ply.DeathEffect_DeathTime = CurTime() - 11
            elseif (CurTime() - dt) > 12 then
                DeathEffect_ClearBlock(ply, true)
            end
        end
    end
end)

-- Headshot tracking: remember where the last hit landed so the client can cut straight to static.
-- A hit counts when it was to the head and the player died within DEATH_HEADSHOT_WINDOW seconds of it.
local DEATH_HEADSHOT_WINDOW = 8

local function DeathEffect_FlagHeadshot(ply)
    ply:SetNWBool("DeathEffect_Headshot", true)
    ply:SetNWFloat("DeathEffect_HeadshotTime", CurTime())
end

hook.Add("HomigradDamage", "DeathEffect_TrackHeadHit", function(victim, dmgInfo, hitgroup)
    local ply = victim
    if IsValid(ply) and not ply:IsPlayer() then
        -- ragdolled players take hits on their ragdoll
        ply = hg and hg.RagdollOwner and hg.RagdollOwner(victim) or victim.ply
    end
    if not IsValid(ply) or not ply:IsPlayer() then return end

    ply.DeathEffect_LastHit = {
        head = hitgroup == HITGROUP_HEAD,
        time = CurTime()
    }

    -- the killing shot can be reported after the death itself: flag it now
    if hitgroup == HITGROUP_HEAD and not ply:Alive() then
        DeathEffect_FlagHeadshot(ply)
    end

    -- A head hit that wrecks the brain (the game stops the heart at 0.6) is a headtap. Flag it the moment it
    -- happens - the actual death only follows seconds later. (Bleeding and suffocation raise the brain damage
    -- too, but never together with a head hit, so those deaths keep their normal fade.)
    if hitgroup == HITGROUP_HEAD then
        local function check()
            local org = IsValid(ply) and ply.organism
            if org and ((tonumber(org.brain) or 0) >= 0.6 or (tonumber(org.brainHemorrhage) or 0) >= 0.3) then
                DeathEffect_FlagHeadshot(ply)
            end
        end
        check()
        timer.Simple(0.05, check)
        timer.Simple(0.3, check)
    end
end)

-- Explosions: a blown-off head or a body that bursts goes to instant static, the same as a headtap.
-- hg.ExplodeHead / hg.FullBodyExplode are defined by the gamemode, so they are wrapped once they exist.
local function DeathEffect_OwnerOf(ent)
    if not IsValid(ent) then return nil end
    if ent:IsPlayer() then return ent end
    local org = ent.organism
    if org and IsValid(org.owner) and org.owner:IsPlayer() then return org.owner end
    local owner = hg and hg.RagdollOwner and hg.RagdollOwner(ent)
    if IsValid(owner) and owner:IsPlayer() then return owner end
    if IsValid(ent.ply) and ent.ply:IsPlayer() then return ent.ply end
    return nil
end

local deathEffectWrapped = {}
local function DeathEffect_WrapExplosions()
    if not istable(hg) then return end

    if isfunction(hg.ExplodeHead) and not deathEffectWrapped.head then
        local original = hg.ExplodeHead
        hg.ExplodeHead = function(ent, ...)
            local owner = DeathEffect_OwnerOf(ent)
            if IsValid(owner) then DeathEffect_FlagHeadshot(owner) end
            return original(ent, ...)
        end
        deathEffectWrapped.head = true
    end

    if isfunction(hg.FullBodyExplode) and not deathEffectWrapped.body then
        local original = hg.FullBodyExplode
        hg.FullBodyExplode = function(target, ...)
            local result = original(target, ...)
            local owner = DeathEffect_OwnerOf(target)
            -- only when it really burst (the function refuses some targets)
            if IsValid(owner) and (target.fullbodyexploded or owner.fullbodyexploded) then
                DeathEffect_FlagHeadshot(owner)
            end
            return result
        end
        deathEffectWrapped.body = true
    end

    if deathEffectWrapped.head and deathEffectWrapped.body then
        timer.Remove("DeathEffect_WrapExplosions")
    end
end
timer.Create("DeathEffect_WrapExplosions", 2, 0, DeathEffect_WrapExplosions)

-- Environment deaths (a map's killbrick = trigger_hurt): the same instant black + static as a headtap.
-- Only trigger_* inflictors count: the gamemode's own bleeding / suffocation damage also comes "from the world"
-- and must keep the normal slow fade.
hook.Add("EntityTakeDamage", "DeathEffect_TrackEnvironmentDamage", function(target, dmgInfo)
    if not (IsValid(target) and target:IsPlayer()) then return end

    local inflictor = dmgInfo:GetInflictor()
    if not IsValid(inflictor) or not string.StartWith(inflictor:GetClass(), "trigger_") then return end

    target.DeathEffect_EnvTime = CurTime()
    -- a killbrick that hits for more than you have left: black right now
    if dmgInfo:GetDamage() >= target:Health() then
        DeathEffect_FlagHeadshot(target)
    end
end)

local function DeathEffect_WasHeadshot(ply)
    local last = ply.DeathEffect_LastHit
    if last and last.head and (CurTime() - last.time) <= DEATH_HEADSHOT_WINDOW then return true end

    -- the corpse of THIS death with its head blown off (ply.headexploded is not used: it can be left over from a
    -- life before, and a brain-damage guess made every shot-then-bled-out death look like a headshot)
    local ragdoll = ply:GetNWEntity("RagdollDeath")
    if IsValid(ragdoll) and ragdoll.headexploded then return true end

    -- killed by a killbrick a moment ago
    if ply.DeathEffect_EnvTime and (CurTime() - ply.DeathEffect_EnvTime) <= 6 then return true end

    return false
end

hook.Add("PlayerDeath", "DeathEffect_Headshot", function(ply)
    local headshot = DeathEffect_WasHeadshot(ply)
    -- (cleared again on spawn; never cleared here: the flag may already have been set by the head hit itself)
    if headshot and not ply:GetNWBool("DeathEffect_Headshot", false) then
        DeathEffect_FlagHeadshot(ply)
    end

    -- the damage code can finish its bookkeeping a moment after the death: look again
    if not headshot then
        for _, delay in ipairs({0, 0.2, 1}) do
            timer.Simple(delay, function()
                if IsValid(ply) and not ply:Alive() and not ply:GetNWBool("DeathEffect_Headshot", false) and DeathEffect_WasHeadshot(ply) then
                    DeathEffect_FlagHeadshot(ply)
                end
            end)
        end
    end
end)

hook.Add("PlayerDeath", "DeathEffect_OnDeath", function(ply)
    if ply:IsBot() then
        ply:SetNWBool("DeathEffect_BlockRespawn", false)

        timer.Simple(0, function()
            if IsValid(ply) and not ply:Alive() then
                ply:Spawn()
            end
        end)

        return
    end

    if not DeathEffectRoundActive() then
        ply:SetNWBool("DeathEffect_BlockRespawn", false)
        return
    end

    local realish = CurrentRound and CurrentRound().name == "realish"

    ply:SetNWBool("DeathEffect_BlockRespawn", true)
    ply.DeathEffect_DeathTime = CurTime()




    local failsafeDelay = realish and 3 or 12
    local tname = DeathEffect_GetTimerName(ply)
    if tname then
        timer.Create(tname, failsafeDelay, 1, function()
            if IsValid(ply) and ply:GetNWBool("DeathEffect_BlockRespawn", false) and not ply:Alive() then
                DeathEffect_ClearBlock(ply, false)
            end
        end)
    end

    net.Start("DeathEffect_Config")
        net.WriteBool(not realish and GetConVar("deatheffect_spectator"):GetBool())
        net.WriteBool(GetConVar("deatheffect_compat"):GetBool())
        net.WriteFloat(realish and 0 or GetConVar("deatheffect_options_delay"):GetFloat())
        net.WriteBool(realish)
    net.Send(ply)
end)

hook.Add("PlayerSpawn", "DeathEffect_OnSpawn", function(ply)
    DeathEffect_ClearBlock(ply, true)
    ply:SetNWBool("DeathEffect_Headshot", false)
    ply:SetNWFloat("DeathEffect_HeadshotTime", 0)
    ply.DeathEffect_LastHit = nil
    ply.DeathEffect_EnvTime = nil
end)

hook.Add("PlayerDisconnected", "DeathEffect_Cleanup", function(ply)
    local tname = DeathEffect_GetTimerName(ply)
    if tname then timer.Remove(tname) end
end)


net.Receive("DeathEffect_Respawn", function(len, ply)
    if IsValid(ply) and not ply:Alive() then
        DeathEffect_ClearBlock(ply, true)
        ply:UnSpectate()
        ply:Spawn()
    end
end)


net.Receive("DeathEffect_CompatUnblock", function(len, ply)
    if IsValid(ply) then
        DeathEffect_ClearBlock(ply, true)
    end
end)

net.Receive("DeathEffect_EnterSpectator", function(len, ply)
    if IsValid(ply) and not ply:Alive() then
        DeathEffect_ClearBlock(ply, true)
        ply.viewmode = 3
        ply:Spectate(OBS_MODE_ROAMING)
        ply:SetMoveType(MOVETYPE_NOCLIP)
    end
end)


net.Receive("DeathEffect_UpdateCam", function(len, ply)
    if IsValid(ply) and not ply:Alive() and ply:GetNWBool("DeathEffect_BlockRespawn", false) then
        local camPos = net.ReadVector()
        local camAng = net.ReadAngle()
        ply:SetPos(camPos)
        ply:SetEyeAngles(camAng)
    end
end)
