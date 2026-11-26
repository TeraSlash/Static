local PANEL = {}
local curent_panel 
local red_select = Color(192,0,0)
local menu_music_default_path = "sound/rem_mainmenu.mp3"
local menu_music_appearance_path = "sound/rem_appearencemenu.mp3"
local menu_music_flags = "noblock noplay"
local menu_music_volume = 0.25
local menu_music_fade_speed = 1.8
local menu_music_station
local menu_music_station_path
local menu_music_station_lerp = 0
local menu_music_pending_station
local menu_music_pending_path
local menu_music_pending_lerp = 0
local menu_music_target_path = menu_music_default_path

DISCORD_URL = "https://discord.gg/475EmEdTgH"

local SOUND_MENU_SELECT = "ui/rem_select.wav"
local SOUND_MENU_HOVER = "ui/rem_hover.wav"
local SOUND_TYPEWRITER = "shitty/tap-resonant.wav"
local SOUND_TYPEWRITER_LEVEL = 55
local SOUND_TYPEWRITER_VOLUME = 0.25
local SOUND_TYPEWRITER_PITCH = 102

local function PlayTypewriterSound()
    local ply = LocalPlayer and LocalPlayer()
    if IsValid(ply) then
        ply:EmitSound(SOUND_TYPEWRITER, SOUND_TYPEWRITER_LEVEL, SOUND_TYPEWRITER_PITCH, SOUND_TYPEWRITER_VOLUME)
        return
    end
    surface.PlaySound(SOUND_TYPEWRITER)
end

local function StopMainMenuMusic()
    if menu_music_station then
        menu_music_station:Stop()
        menu_music_station = nil
    end
    menu_music_station_path = nil
    menu_music_station_lerp = 0
    if menu_music_pending_station then
        menu_music_pending_station:Stop()
        menu_music_pending_station = nil
    end
    menu_music_pending_path = nil
    menu_music_pending_lerp = 0
    menu_music_target_path = menu_music_default_path
end

local function QueueMainMenuMusic(owner, path)
    path = path or menu_music_default_path
    menu_music_target_path = path

    if not IsValid(owner) or MainMenu ~= owner then return end
    if menu_music_station and menu_music_station_path == path and not menu_music_pending_station then return end
    if menu_music_pending_station and menu_music_pending_path == path then return end

    sound.PlayFile(path, menu_music_flags, function(station)
        if not station then return end
        if not IsValid(owner) or MainMenu ~= owner or menu_music_target_path ~= path then
            station:Stop()
            return
        end

        if menu_music_pending_station and menu_music_pending_station ~= station then
            menu_music_pending_station:Stop()
        end

        menu_music_pending_station = station
        menu_music_pending_path = path
        menu_music_pending_lerp = 0
        station:EnableLooping(true)
        station:SetVolume(0)
        station:Play()
    end)
end

local function UpdateMainMenuMusic(owner)
    if not IsValid(owner) or MainMenu ~= owner then
        StopMainMenuMusic()
        return
    end

    if menu_music_station and menu_music_station_path ~= menu_music_target_path and not menu_music_pending_station then
        QueueMainMenuMusic(owner, menu_music_target_path)
    end

    local fadeStep = FrameTime() * menu_music_fade_speed

    if menu_music_pending_station then
        menu_music_pending_lerp = math.min(1, menu_music_pending_lerp + fadeStep)
        menu_music_pending_station:SetVolume(menu_music_volume * menu_music_pending_lerp)

        if menu_music_station then
            menu_music_station_lerp = math.max(0, menu_music_station_lerp - fadeStep)
            menu_music_station:SetVolume(menu_music_volume * menu_music_station_lerp)

            if menu_music_station_lerp <= 0.001 then
                menu_music_station:Stop()
                menu_music_station = menu_music_pending_station
                menu_music_station_path = menu_music_pending_path
                menu_music_station_lerp = menu_music_pending_lerp
                menu_music_pending_station = nil
                menu_music_pending_path = nil
                menu_music_pending_lerp = 0
            end
        elseif menu_music_pending_lerp >= 0.999 then
            menu_music_station = menu_music_pending_station
            menu_music_station_path = menu_music_pending_path
            menu_music_station_lerp = 1
            menu_music_pending_station = nil
            menu_music_pending_path = nil
            menu_music_pending_lerp = 0
        end
    elseif menu_music_station then
        menu_music_station_lerp = math.min(1, menu_music_station_lerp + fadeStep)
        menu_music_station:SetVolume(menu_music_volume * menu_music_station_lerp)
    elseif menu_music_target_path then
        QueueMainMenuMusic(owner, menu_music_target_path)
    end
end

local function MenuUnit(num)
    return math.floor(num * math.min(ScrW(), ScrH()) / 1000)
end

local function CreateMainMenuFonts()

    surface.CreateFont("ZCity_Menu_Tiny", {
        font = "Verily Serif Mono",
        size = ScreenScale(8),
        weight = 200
    })

    surface.CreateFont("ZCity_Menu_Small", {
        font = "Verily Serif Mono",
        size = ScreenScale(20),
        weight = 200
    })
end

hook.Add("OnScreenSizeChanged", "ZCity_MainMenu_Fonts", CreateMainMenuFonts)
CreateMainMenuFonts()

-- ---------------------------------------------------------------------------
-- Menu look (slanted side panel, numbered bars, server card, level header)
-- ---------------------------------------------------------------------------
local UI_FONT = "Arial" -- change to any font installed on your clients
local MENU_AUTHORS = "Authors: TeraSlash"
local REPO_URL = "https://github.com/TeraSlash/Static"
local LOGO_URL = "https://discord.gg/udJtKDqv4Q"
local REPO_TEXT = "GitHub: github.com/TeraSlash/Static"
local XP_PER_LEVEL = 1000
local SLOPE = 0 -- 0 = straight edges. Set to 210 / 1079 to lean them to the right again

hg.MenuSessionStart = hg.MenuSessionStart or SysTime()

-- Layout numbers below are written for 1080p and scale with screen height.
local function S(n)
    return math.floor(n * ScrH() / 1080 + 0.5)
end

local function SideEdge(y)
    return S(700) + SLOPE * y
end

local function CreateImageFonts()
    local function make(name, size, weight)
        surface.CreateFont(name, {
            font = UI_FONT,
            size = S(size),
            weight = weight,
            antialias = true,
            extended = true
        })
    end
    make("ZC_UI_Item", 26, 500)
    make("ZC_UI_Num", 16, 500)
    make("ZC_UI_Label", 15, 600)
    make("ZC_UI_Value", 25, 500)
    make("ZC_UI_Server", 30, 500)
    make("ZC_UI_Name", 30, 500)
    make("ZC_UI_Level", 16, 700)
    make("ZC_UI_Foot", 13, 400)
    surface.CreateFont("ZC_UI_Tagline", {
        font = UI_FONT,
        size = S(19),
        weight = 500,
        italic = true,
        antialias = true,
        extended = true
    })
end

hook.Add("OnScreenSizeChanged", "ZCity_MainMenu_UIFonts", CreateImageFonts)
CreateImageFonts()

local col_panel = Color(21, 22, 27, 248)
local col_card = Color(31, 33, 39, 240)
local col_text = Color(236, 238, 242)
local col_text_dim = Color(152, 155, 163)
local col_label = Color(170, 172, 180)

local function FitText(text, font, maxW)
    surface.SetFont(font)
    if surface.GetTextSize(text) <= maxW then return text end
    while #text > 1 and surface.GetTextSize(text .. "...") > maxW do
        text = string.sub(text, 1, (utf8.offset(text, -1) or #text) - 1)
    end
    return text .. "..."
end

local function DrawSlanted(x, y, w, h)
    draw.NoTexture()
    surface.DrawPoly({
        {x = x, y = y},
        {x = x + w, y = y},
        {x = x + w + SLOPE * h, y = y + h},
        {x = x, y = y + h}
    })
end

local Selects = {
    {Title = "Return", Func = function(luaMenu) luaMenu:Close() end},
    {Title = "Appearance", Func = function(luaMenu, pp) (hg.StaticApperanceMenu or hg.CreateApperanceMenu)(pp) end},
    {Title = "Settings", Docked = true, Func = function(luaMenu, pp) hg.DrawSettings(pp) end},
    {Title = "Keybinds", Docked = true, Func = function(luaMenu, pp) hg.DrawKeybinds(pp) end},
    {Title = "Achievements", Docked = true, Func = function(luaMenu, pp) hg.DrawAchievmentsMenu(pp) end},
    {Title = "Information", Docked = true, Func = function(luaMenu, pp) hg.DrawInformation(pp) end},
    {Title = "Loadout",
    GamemodeOnly = true,
    Func = function(luaMenu, pp)
        if hg.DrawLoadoutMenu then
            hg.DrawLoadoutMenu(pp)
        end
    end},
    {Title = "Discord", Group = 2, BypassTransition = true, Func = function(luaMenu) gui.OpenURL(LOGO_URL) end},
    {Title = "Main Menu", Group = 2, Func = function(luaMenu) gui.ActivateGameUI() luaMenu:Close() end},
    {Title = "Disconnect", Group = 2, BypassTransition = true, Func = function(luaMenu) luaMenu:PlayDisconnectCutscene() end},
}

local splasheh = {
    'LIKE HOMICIDED',
    'PLUV PLUV PLUVISKI',
    'LULU IS NOT DEAD | !PLUV',
    'THE TRAITOR WAS KILLED',
    'NAB HOMICIDE SERVER',
    'ALSO TRY MODDED HOMICIDE 2',
    'HOP ON Z-CITY',
    'JOHN Z-CITY',
    ':pluvrare:',
    'SAW51 IS REAL',
    'MORE SMALLTOWN',
    'MORE CLUE2022',
    'BACKROOMS == CLUE',
    'HELL IS NEAR',
    'I WISH YOU GOOD HEALTH, JASON STATHAM'
}

--print(string.upper('I wish you good health, Jason Statham'))
surface.CreateFont("ZC_MM_Title", {
    font = "Verily Serif Mono",
    size = ScreenScale(40),
    weight = 800,
    antialias = true
})
-- local Title = markup.Parse("error")

local Pluv = Material("pluv/pluvkid.jpg")
local LogoistMat = Material("vgui/logoist.png", "noclamp smooth")
local StaticLogoMat = Material("static/logo.png", "smooth") -- materials/static/logo.png

function PANEL:InitializeMarkup()
	local mapname = game.GetMap()
	local prefix = string.find(mapname, "_")
	if prefix then
		mapname = string.sub(mapname, prefix + 1)
	end
	local gm = splasheh[math.random(#splasheh)] .. " | " .. string.NiceName(mapname) 

    if hg.PluvTown.Active then
        local text = "<font=ZC_MM_Title><colour=199,2,2>    </colour>City</font>\n<font=ZCity_Menu_Tiny><colour=105,105,105>" .. gm .. "</colour></font>"

        self.SelectedPluv = table.Random(hg.PluvTown.PluvMats)

        return markup.Parse(text)
    end

    local text = "<font=ZC_MM_Title><colour=199,2,2,255>Z</colour>-City</font>\n<font=ZCity_Menu_Tiny><colour=105,105,105>" .. gm .. "</colour></font>"
    return markup.Parse(text)
end

local color_red = Color(255,25,25,45)
local clr_gray = Color(255,255,255,25)
local clr_verygray = Color(10,10,19,235)
local appearance_preview = {
    width = 340,
    height = 840,
    center_x = 0.735, -- horizontal centre of the model, as a fraction of screen width
    top = 110,
    enter_time = 1.35,
    enter_delay = 0.35,
    exit_time = 0.7,
    exit_delay = 0.05,
    ambient = Color(0, 0, 0, 255),
    light_right = Color(115, 115, 115, 255),
    light_left = Color(85, 85, 85, 255),
    light_front = Color(92, 92, 92, 255),
    light_back = Color(0, 0, 0, 255),
    light_top = Color(55, 55, 55, 255),
    light_bottom = Color(0, 0, 0, 255),
    fov = 18.4, -- wide enough that the whole body (head to boots) fits inside the holder
    cam_pos = Vector(100, 0, 55),
    look_ang = Angle(11, 180, 0),
    entity_ang = Angle(0, 0, 0),
    head_yaw = 0, -- 0 = looking straight into the screen
    head_pitch = 0,
    head_mouse_yaw = 0, -- raise these to make the head follow the mouse again
    head_mouse_pitch = 0,
    sequence = "idle_suitcase"
}
local disconnect_cutscene = {
    ui_fade_time = 0.45,
    walk_delay = 0.08,
    walk_time = 2.5,
    walk_distance = 135,
    walk_sequence = "walk_all",
    walk_playback_rate = 1,
    walk_ang = Angle(0, 90, 0),
    black_fade_time = 0.7,
    disconnect_delay = 0.05
}
local menu_profile = {
    left = 30,
    top = 90,
    min_width = 360,
    height = 160,
    medal_size = 50
}
local menu_title = {
    width = 500,
    offset_x = -11,
    spacing = 55
}
local menu_live = {
    drift_x = 14,
    drift_y = 10,
    shake_x = 1,
    shake_y = 1,
    title_x = 30,
    title_y = 25,
    title_mouse_x = 10,
    title_mouse_y = 7,
    title_float_x = 4,
    title_float_y = 3,
    title_hover_scale = 0.08,
    button_hover_scale = 0.008,
    button_drift_x = 4,
    button_drift_y = 1,
    button_shake_x = 0,
    button_shake_y = 0,
    profile_drift_x = 9,
    profile_drift_y = 6,
    bottom_drift_x = 10,
    bottom_drift_y = 6,
    logo_drift_x = 7,
    logo_drift_y = 4,
    enter_x = 18,
    enter_y = 12
}
local menu_profile_fallback_band = {
    icon = Material("vgui/mats_jack_awards/10")
}
local menu_profile_fallback_medal = {
    icon = Material("vgui/mats_jack_awards/pt")
}
local menu_news = {
    top = 24,
    height = 36,
    speed = 100,
    refresh = 2
}

local function MenuCanStartNet(messageName)
    return util.NetworkStringToID(messageName) ~= 0
end

hg.Leaderboard = hg.Leaderboard or {Rows = {}, NextRequest = 0}

function hg.Leaderboard.Request(limit)
    if not MenuCanStartNet("zb_sql_leaderboard") then return end
    if (hg.Leaderboard.NextRequest or 0) > CurTime() then return end
    hg.Leaderboard.NextRequest = CurTime() + 3

    net.Start("zb_sql_leaderboard")
        net.WriteUInt(math.Clamp(limit or 10, 1, 10), 8)
    net.SendToServer()
end

function hg.Leaderboard.Get(limit)
    hg.Leaderboard.Request(limit)

    local rows = hg.Leaderboard.Rows or {}
    if limit and #rows > limit then
        local trimmed = {}
        for i = 1, limit do
            trimmed[i] = rows[i]
        end
        return trimmed
    end

    return rows
end

function hg.Leaderboard.GetAwards(row)
    if not row or not zb or not zb.Experience or not zb.Experience.GetAwards then return menu_profile_fallback_band, menu_profile_fallback_medal end
    return zb.Experience.GetAwards({skill = row.skill or 0, exp = row.xp or 0})
end

function hg.Leaderboard.GetMedalName(row)
    local _, medal = hg.Leaderboard.GetAwards(row)
    return string.upper((medal and medal.name) or "UNRANKED")
end

if not hg.Leaderboard.NetHooked then
    net.Receive("zb_sql_leaderboard", function()
        local count = net.ReadUInt(8)
        local rows = {}

        for i = 1, count do
            rows[i] = {
                steamid = net.ReadString(),
                name = net.ReadString(),
                skill = net.ReadFloat(),
                xp = net.ReadUInt(32),
                kills = net.ReadUInt(16),
                deaths = net.ReadUInt(16),
                kd = net.ReadFloat()
            }
        end

        hg.Leaderboard.Rows = rows
    end)

    hg.Leaderboard.NetHooked = true
end

local function CleanupPreviewAccessories(ent)
    if not IsValid(ent) or not ent.modelAccess then return end
    for k, v in pairs(ent.modelAccess) do
        if IsValid(v) then
            v:Remove()
        end
        ent.modelAccess[k] = nil
    end
end

function PANEL:GetPreviewAppearance()
    if not hg or not hg.Appearance then return end
    local appearance
    if hg.Appearance.LoadAppearanceFile and hg.Appearance.SelectedAppearance then
        appearance = hg.Appearance.LoadAppearanceFile(hg.Appearance.SelectedAppearance:GetString())
    end
    appearance = appearance or (hg.Appearance.GetRandomAppearance and hg.Appearance.GetRandomAppearance())
    if not appearance or not hg.Appearance.PlayerModels then return end
    local tMdl = hg.Appearance.PlayerModels[1][appearance.AModel] or hg.Appearance.PlayerModels[2][appearance.AModel]
    if not tMdl or not tMdl.mdl then return end
    return table.Copy(appearance), tMdl
end

function PANEL:GetProfileInfo()
    local ply = LocalPlayer()
    if not IsValid(ply) then
        return "Unknown", "0 XP", nil
    end

    -- the Steam profile name, not the in-game character name
    local username = ply.SteamName and ply:SteamName() or ""
    if username == "" then
        username = ply:Nick()
    end

    local xp = tostring(math.floor(tonumber(ply.exp) or 0)) .. " XP"
    return username, xp, ply
end

function PANEL:GetLiveMouse()
    local mx, my = gui.MouseX(), gui.MouseY()
    if mx <= 0 and my <= 0 then
        mx = ScrW() * 0.5
        my = ScrH() * 0.5
    end
    local nx = math.Clamp((mx / ScrW() - 0.5) * 2, -1, 1)
    local ny = math.Clamp((my / ScrH() - 0.5) * 2, -1, 1)
    return mx, my, nx, ny
end

function PANEL:GetLiveOffset(xAmount, yAmount)
    local _, _, nx, ny = self:GetLiveMouse()
    return nx * xAmount, ny * yAmount
end

function PANEL:GetLiveShake(seedX, seedY, xAmount, yAmount)
    local t = RealTime()
    return math.sin(t * 1.8 + seedX) * xAmount, math.cos(t * 2.4 + seedY) * yAmount
end

function PANEL:Think()
    UpdateMainMenuMusic(self)

    if self.DisconnectBlackStart then
        local blackFrac = math.Clamp((CurTime() - self.DisconnectBlackStart) / math.max(disconnect_cutscene.black_fade_time, 0.001), 0, 1)
        self.DisconnectBlackAlpha = 255 * blackFrac
    end

    if self.DisconnectWalkStart and CurTime() >= self.DisconnectWalkStart then
        local walkFrac = math.Clamp((CurTime() - self.DisconnectWalkStart) / disconnect_cutscene.walk_time, 0, 1)
        if walkFrac < 1 and CurTime() > (self.NextFootstep or 0) then
            self.NextFootstep = CurTime() + 0.38
            local vol = 1 - walkFrac
            if LocalPlayer and IsValid(LocalPlayer()) then
                LocalPlayer():EmitSound("player/footsteps/concrete" .. math.random(1,4) .. ".wav", 0, 100, vol)
            end
        end
    end

    self.LiveLerp = LerpFT(0.08, self.LiveLerp or 0, 1)
    -- 1 while a sub-menu (Settings, Appearance...) is open, 0 on the main screen
    self.SubLerp = LerpFT(0.15, self.SubLerp or 0, curent_panel and 1 or 0)
end

function PANEL:CreateProfileInfo()
    local barW = S(330)
    local centerX = math.floor(ScrW() * appearance_preview.center_x) - S(18)

    local profile = vgui.Create("DPanel", self)
    self.profileInfo = profile
    profile:SetSize(barW, S(105))
    profile:SetPos(centerX - barW / 2, S(27))
    profile:SetMouseInputEnabled(false)
    profile:SetAlpha(0)
    profile.BaseY = S(27)
    profile.Think = function(this)
        if this.DockHidden == nil then return end
        local x, y = this:GetPos()
        local goal = this.DockHidden and (-this:GetTall() - S(10)) or this.BaseY
        local ny = LerpFT(0.14, y, goal)
        if math.abs(goal - ny) < 1 then
            ny = goal
            if not this.DockHidden then this.DockHidden = nil end
        end
        this:SetPos(x, math.Round(ny))
    end
    profile.Paint = function(this, w, h)
        local name, _, ply = self:GetProfileInfo()
        local exp = IsValid(ply) and math.floor(tonumber(ply.exp) or 0) or 0
        local level = math.floor(exp / XP_PER_LEVEL) + 1
        local into = exp % XP_PER_LEVEL

        -- name tab
        name = FitText(name, "ZC_UI_Name", w - S(70))
        surface.SetFont("ZC_UI_Name")
        local tw = surface.GetTextSize(name)
        local tabH = S(54)
        local tabW = S(6) + S(18) + tw + S(24)
        local tabX = math.floor((w - tabW) / 2)
        surface.SetDrawColor(24, 25, 30, 240)
        DrawSlanted(tabX, 0, tabW, tabH)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawRect(tabX, 0, S(6), tabH)
        draw.SimpleText(name, "ZC_UI_Name", tabX + S(24), tabH / 2, col_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- level + xp
        local rowY = S(76)
        draw.SimpleText("LEVEL " .. level, "ZC_UI_Level", 0, rowY, col_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(into .. " / " .. XP_PER_LEVEL .. " XP", "ZC_UI_Level", w, rowY, col_label, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        local barY, barH = S(95), math.max(2, S(5))
        surface.SetDrawColor(70, 72, 78, 200)
        surface.DrawRect(0, barY, w, barH)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawRect(0, barY, math.floor(w * into / XP_PER_LEVEL), barH)
    end

    timer.Simple(0, function()
        if not IsValid(profile) then return end
        profile:AlphaTo(255, appearance_preview.enter_time * 0.75, appearance_preview.enter_delay)
    end)
end

function PANEL:CreateTopPlayersTicker()
    local ticker = vgui.Create("DPanel", self)
    self.topPlayersTicker = ticker
    ticker:SetSize(ScrW(), MenuUnit(menu_news.height))
    ticker:SetPos(0, MenuUnit(menu_news.top))
    ticker:SetMouseInputEnabled(false)
    ticker:SetAlpha(0)
    ticker.Text = "TOP 3 PLAYERS: LOADING"
    ticker.Leaders = {}
    ticker.NextRefresh = 0
    ticker.Paint = function(this, w, h)
        if (this.NextRefresh or 0) <= CurTime() then
            local leaders = hg.Leaderboard.Get(3)
            this.Leaders = leaders
            this.Text = #leaders > 0 and "TOP 3 PLAYERS:" or "TOP 3 PLAYERS: NO SQL LEADERBOARD DATA"
            this.NextRefresh = CurTime() + menu_news.refresh
        end

        surface.SetDrawColor(0, 0, 0, 185)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(255, 255, 255, 70)
        surface.DrawRect(0, h - MenuUnit(1), w, MenuUnit(1))

        surface.SetFont("ZCity_Menu_Tiny")
        local iconSize = MenuUnit(18)
        local gap = MenuUnit(18)
        local textW = surface.GetTextSize(this.Text)
        for i, data in ipairs(this.Leaders or {}) do
            textW = textW + surface.GetTextSize("   #" .. i .. " " .. string.upper(data.name) .. " XP " .. data.xp) + iconSize + gap
        end
        local span = w + textW + MenuUnit(80)
        local x = w - ((RealTime() * menu_news.speed) % span)
        local y = h / 2
        draw.SimpleTextOutlined(this.Text, "ZCity_Menu_Tiny", x, y, Color(225, 225, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 235))
        x = x + surface.GetTextSize(this.Text)

        for i, data in ipairs(this.Leaders or {}) do
            local label = "   #" .. i .. " " .. string.upper(data.name) .. " XP " .. data.xp
            draw.SimpleTextOutlined(label, "ZCity_Menu_Tiny", x, y, Color(225, 225, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 235))
            x = x + surface.GetTextSize(label) + MenuUnit(4)

            local _, medal = hg.Leaderboard.GetAwards(data)
            if medal and medal.icon then
                surface.SetMaterial(medal.icon)
                surface.SetDrawColor(255, 255, 255, 235)
                surface.DrawTexturedRect(x, y - iconSize / 2, iconSize, iconSize)
            end

            x = x + iconSize + gap
        end
    end

    timer.Simple(0, function()
        if IsValid(ticker) then
            ticker:AlphaTo(255, appearance_preview.enter_time * 0.75, appearance_preview.enter_delay)
        end
    end)
end

function PANEL:CreateSidePanel()
    local luaMenu = self

    local side = vgui.Create("DPanel", self)
    self.sidePanel = side
    side:SetPos(0, 0)
    side:SetSize(math.ceil(SideEdge(ScrH())) + 2, ScrH())
    side.Paint = function(this, w, h)
        surface.SetDrawColor(col_panel)
        DrawSlanted(0, 0, SideEdge(0), h)
    end

    -- logo (click opens the repo, like before)
    local logoMat = StaticLogoMat
    if not logoMat or logoMat:IsError() then
        logoMat = LogoistMat -- logo file missing, fall back to the old one
    end
    local logoAspect = math.max(1, logoMat:Height()) / math.max(1, logoMat:Width())
    local logoH = math.min(S(92), math.floor(S(310) * logoAspect))
    local logoW = math.floor(logoH / logoAspect)
    local taglineH = S(26)
    local logo = vgui.Create("DPanel", side)
    self.logoPanel = logo
    logo:SetPos(S(150), S(20))
    logo:SetSize(math.max(logoW, S(260)), logoH + taglineH)
    logo:SetCursor("hand")
    logo.OnMousePressed = function(this, code)
        if code ~= MOUSE_LEFT then return end
        gui.OpenURL(LOGO_URL)
    end
    logo.Paint = function(this, w, h)
        this.HoverLerp = LerpFT(0.15, this.HoverLerp or 0, this:IsHovered() and 1 or 0)
        surface.SetDrawColor(255, 255, 255, 225 + 30 * this.HoverLerp)
        surface.SetMaterial(logoMat)
        surface.DrawTexturedRect(0, 0, logoW, logoH)
        draw.SimpleText("You can't outrun death.", "ZC_UI_Tagline", S(6), logoH + taglineH * 0.5, col_text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- numbered bars: sized so the list fills the space between the logo and the server card
    local entries = {}
    for _, v in ipairs(Selects) do
        if v.GamemodeOnly and engine.ActiveGamemode() != "zcity" then continue end
        entries[#entries + 1] = v
    end

    local startY = S(167)
    local gap = S(6)
    local cardTop = S(674)
    local pitch = math.floor(math.Clamp((cardTop - S(30) - startY + gap) / math.max(#entries, 1), S(44), S(62)))
    local barH = pitch - gap
    local f = barH / S(45)

    surface.CreateFont("ZC_UI_ItemBar", {font = UI_FONT, size = math.floor(S(26) * f), weight = 500, antialias = true, extended = true})
    surface.CreateFont("ZC_UI_NumBar", {font = UI_FONT, size = math.floor(S(16) * f), weight = 500, antialias = true, extended = true})

    self.Buttons = {}
    local y = startY
    for i, v in ipairs(entries) do
        self:AddSelect(side, i, y, v, barH)
        y = y + pitch
    end

    -- server card
    local cardX, cardY, cardH = S(36), cardTop, S(234)
    local cardWTop = SideEdge(cardY) - S(19) - cardX
    local card = vgui.Create("DPanel", side)
    self.serverCard = card
    card:SetPos(cardX, cardY)
    card:SetSize(math.ceil(cardWTop + SLOPE * cardH) + 1, cardH)
    card:SetMouseInputEnabled(false)
    card:SetAlpha(0)
    card.OpenTime = CurTime() + 0.5
    card.Think = function(this)
        this:SetAlpha(255 * math.Clamp((CurTime() - this.OpenTime) / 0.4, 0, 1))
    end
    card.Paint = function(this, w, h)
        surface.SetDrawColor(col_card)
        DrawSlanted(0, 0, cardWTop, h)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawRect(0, 0, S(5), h)

        local padL = S(18)
        local right = cardWTop - S(15)
        local col2 = S(367)

        local elapsed = math.floor(SysTime() - hg.MenuSessionStart)
        local timeText = string.format("%02d:%02d:%02d", math.floor(elapsed / 3600), math.floor(elapsed / 60) % 60, elapsed % 60)

        local ply = LocalPlayer()
        local ping = IsValid(ply) and ply:Ping() or 0
        local mode = tostring((zb and (zb.CROUND_MAIN or zb.CROUND)) or engine.ActiveGamemode())

        draw.SimpleText("SERVER", "ZC_UI_Label", padL, S(28), col_label, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("IN GAME " .. timeText, "ZC_UI_Label", right, S(28), col_label, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        draw.SimpleText(FitText(GetHostName(), "ZC_UI_Server", right - padL), "ZC_UI_Server", padL, S(64), col_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        draw.SimpleText("MAP", "ZC_UI_Label", padL, S(106), col_label, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(FitText(game.GetMap(), "ZC_UI_Value", col2 - padL - S(10)), "ZC_UI_Value", padL, S(135), col_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("MODE", "ZC_UI_Label", col2, S(106), col_label, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(FitText(string.upper(mode), "ZC_UI_Value", right - col2), "ZC_UI_Value", col2, S(135), col_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        draw.SimpleText("PLAYERS", "ZC_UI_Label", padL, S(169), col_label, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(#player.GetAll() .. " / " .. game.MaxPlayers(), "ZC_UI_Value", padL, S(198), col_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("PING", "ZC_UI_Label", col2, S(169), col_label, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(ping .. " MS", "ZC_UI_Value", col2, S(198), col_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- footer
    local foot = vgui.Create("DPanel", side)
    self.bottomDock = foot
    foot:SetPos(S(36), ScrH() - S(100))
    foot:SetSize(S(520), S(80))
    foot:SetAlpha(0)
    foot.OpenTime = CurTime() + 0.65
    foot.Think = function(this)
        this:SetAlpha(255 * math.Clamp((CurTime() - this.OpenTime) / 0.4, 0, 1))
    end

    local gitText = REPO_TEXT
    local gitBtn = vgui.Create("DButton", foot)
    gitBtn:SetText("")
    gitBtn:SetCursor("hand")
    gitBtn:SetPos(0, S(45))
    gitBtn:SetSize(S(330), S(20))
    gitBtn.Paint = function() return true end
    gitBtn.DoClick = function()
        gui.OpenURL(REPO_URL)
    end

    foot.Paint = function(this, w, h)
        draw.SimpleText(MENU_AUTHORS, "ZC_UI_Foot", 0, S(14), col_text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(hg.Version, "ZC_UI_Foot", 0, S(35), col_text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(gitText, "ZC_UI_Foot", 0, S(55), gitBtn:IsHovered() and col_text or col_text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

function PANEL:CreateAppearancePreview()
    local tbl, tMdl = self:GetPreviewAppearance()
    if not tbl or not tMdl then return end

    if hg.Appearance and hg.Appearance.PrecacheModels then
        hg.Appearance.PrecacheModels()
    end

    local holderW = MenuUnit(appearance_preview.width)
    local holderH = MenuUnit(appearance_preview.height)
    local targetX = math.floor(ScrW() * appearance_preview.center_x - holderW / 2)
    local targetY = MenuUnit(appearance_preview.top)

    self.previewHolder = vgui.Create("DPanel", self)
    local holder = self.previewHolder
    holder:SetSize(holderW, holderH)
    holder:SetPos(targetX, ScrH())
    holder:SetAlpha(0)
    holder.TargetX = targetX
    holder.TargetY = targetY
    holder.ClosedY = ScrH()
    holder:SetMouseInputEnabled(false)
    holder.Paint = function() end
    holder.Think = function(this)
        -- a docked menu is open: the character slides down out of the way (and back up when it closes)
        if this.DockHidden ~= nil and not this.AppearanceFollow then
            local x, y = this:GetPos()
            local goal = this.DockHidden and (this.ClosedY or ScrH()) or (this.TargetY or y)
            local ny = LerpFT(0.14, y, goal)
            if math.abs(goal - ny) < 1 then
                ny = goal
                if not this.DockHidden then this.DockHidden = nil end
            end
            this:SetPos(x, math.Round(ny))
            return
        end

        if not this.AppearanceFollow then return end
        local x, y = this:GetPos()
        local targetPosX = this.TargetX or x
        local targetPosY = this.TargetY or y
        local nextX = LerpFT(0.18, x, targetPosX)
        local nextY = LerpFT(0.18, y, targetPosY)
        if math.abs(targetPosX - nextX) < 1 then
            nextX = targetPosX
        end
        if math.abs(targetPosY - nextY) < 1 then
            nextY = targetPosY
        end
        this:SetPos(math.Round(nextX), math.Round(nextY))
    end

    local preview = vgui.Create("DModelPanel", holder)
    self.previewModel = preview
    preview.OwnerMenu = self
    preview:Dock(FILL)
    preview:SetModel(util.IsValidModel(tostring(tMdl.mdl)) and tostring(tMdl.mdl) or "models/player/group01/female_01.mdl")
    preview:SetFOV(appearance_preview.fov)
    preview:SetLookAng(appearance_preview.look_ang)
    preview:SetCamPos(appearance_preview.cam_pos)
    preview:SetAmbientLight(appearance_preview.ambient)
    preview:SetDirectionalLight(BOX_RIGHT, appearance_preview.light_right)
    preview:SetDirectionalLight(BOX_LEFT, appearance_preview.light_left)
    preview:SetDirectionalLight(BOX_FRONT, appearance_preview.light_front)
    preview:SetDirectionalLight(BOX_BACK, appearance_preview.light_back)
    preview:SetDirectionalLight(BOX_TOP, appearance_preview.light_top)
    preview:SetDirectionalLight(BOX_BOTTOM, appearance_preview.light_bottom)
    preview:SetMouseInputEnabled(false)
    preview.AppearanceTable = tbl

    local oldPaint = preview.Paint
    preview.Paint = function(pnl, w, h)
        DisableClipping(true)
        oldPaint(pnl, w, h)
        DisableClipping(false)
    end

    function preview:LayoutEntity(ent)
        local appearance = self.AppearanceTable
        if not appearance or not hg or not hg.Appearance or not hg.Appearance.PlayerModels then return end

        local modelData = hg.Appearance.PlayerModels[1][appearance.AModel] or hg.Appearance.PlayerModels[2][appearance.AModel]
        if not modelData or not modelData.mdl then return end

        local colorData = appearance.AColor or color_white
        ent:SetNWVector("PlayerColor", Vector((colorData.r or 255) / 255, (colorData.g or 255) / 255, (colorData.b or 255) / 255))

        local targetPos = Vector(0, 0, 0)
        if self.OwnerMenu and self.OwnerMenu.DisconnectCutscene then
            targetPos = Vector(0, self.WalkOffsetY or 0, 0)
            if self.OwnerMenu.DisconnectWalkStart and CurTime() >= self.OwnerMenu.DisconnectWalkStart then
                local walkFrac = math.Clamp((CurTime() - self.OwnerMenu.DisconnectWalkStart) / disconnect_cutscene.walk_time, 0, 1)
                targetPos = Vector(0, (self.WalkOffsetY or 0) + walkFrac * disconnect_cutscene.walk_distance, 0)
            end
        end
        ent:SetPos(targetPos)

        local targetEntityAngle = self.EntityAngleOverride or appearance_preview.entity_ang
        self.EntityAngle = LerpAngle(RealFrameTime() * 6, self.EntityAngle or targetEntityAngle, targetEntityAngle)
        ent:SetAngles(self.EntityAngle)

        local sequenceName = self.SequenceNameOverride or appearance_preview.sequence
        local seq = ent:LookupSequence(sequenceName)
        
        if self.OwnerMenu and self.OwnerMenu.DisconnectCutscene and (not seq or seq < 0) then
            local fallbacks = {"walk_suitcase", "walk_all", "walk", "walk_all_suitcase"}
            for _, v in ipairs(fallbacks) do
                seq = ent:LookupSequence(v)
                if seq and seq >= 0 then
                    sequenceName = v
                    break
                end
            end
        end

        if (not seq or seq < 0) and sequenceName != appearance_preview.sequence then
            sequenceName = appearance_preview.sequence
            seq = ent:LookupSequence(sequenceName)
        end
        if seq and seq >= 0 then
            if self.ActiveSequenceName != sequenceName then
                ent:ResetSequence(seq)
                self.ActiveSequenceName = sequenceName
            end
            ent:SetPlaybackRate(self.SequencePlaybackRate or 1)
            ent:FrameAdvance(RealFrameTime() * (self.SequencePlaybackRate or 1))
        end

        local owner = self.OwnerMenu
        local nx, ny = 0, 0
        if IsValid(owner) and owner.GetLiveMouse then
            local _, _, newNX, newNY = owner:GetLiveMouse()
            nx, ny = newNX, newNY
        end
        local targetYaw = appearance_preview.head_yaw - nx * appearance_preview.head_mouse_yaw
        local targetPitch = appearance_preview.head_pitch - ny * appearance_preview.head_mouse_pitch
        self.HeadYawLerp = LerpFT(0.08, self.HeadYawLerp or appearance_preview.head_yaw, targetYaw)
        self.HeadPitchLerp = LerpFT(0.08, self.HeadPitchLerp or appearance_preview.head_pitch, targetPitch)
        ent:SetPoseParameter("head_yaw", self.HeadYawLerp)
        ent:SetPoseParameter("head_pitch", self.HeadPitchLerp)
        -- square the body up to the camera as well
        ent:SetPoseParameter("body_yaw", 0)
        ent:SetPoseParameter("aim_yaw", 0)
        ent:SetPoseParameter("aim_pitch", 0)
        
        if self.OwnerMenu and self.OwnerMenu.DisconnectCutscene then
            ent:SetPoseParameter("move_x", 1)
            ent:SetPoseParameter("move_y", 0)
        end
        
        ent:SetSubMaterial()
        self:SetCamPos(self.CamPosOverride or appearance_preview.cam_pos)
        self:SetFOV(self.FOVOverride or appearance_preview.fov)
        self:SetLookAng(self.LookAngOverride or appearance_preview.look_ang)

        if ent:GetModel() != modelData.mdl then
            CleanupPreviewAccessories(ent)
            ent:SetModel(modelData.mdl)
            self:SetModel(modelData.mdl)
            self.ActiveSequenceName = nil
        end

        local clothes = appearance.AClothes or {}
        local mats = ent:GetMaterials()
        for k, v in SortedPairs(modelData.submatSlots or {}) do
            local slot = 1
            for i = 1, #mats do
                if mats[i] == v then
                    slot = i - 1
                    break
                end
            end
            local sexID = modelData.sex and 2 or 1
            local clothMat = hg.Appearance.Clothes[sexID] and hg.Appearance.Clothes[sexID][clothes[k]]
            ent:SetSubMaterial(slot, clothMat or (hg.Appearance.Clothes[sexID] and hg.Appearance.Clothes[sexID].normal) or nil)
        end

        local facemapSlot = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[modelData.mdl]
        for i = 1, #mats do
            if facemapSlot and hg.Appearance.FacemapsSlots[mats[i]] and hg.Appearance.FacemapsSlots[mats[i]][appearance.AFacemap] then
                ent:SetSubMaterial(i - 1, hg.Appearance.FacemapsSlots[mats[i]][appearance.AFacemap])
            end
        end

        appearance.ABodygroups = appearance.ABodygroups or {}
        for k, v in SortedPairs(ent:GetBodyGroups()) do
            if not appearance.ABodygroups[v.name] then continue end
            local bodygroupData = hg.Appearance.Bodygroups[v.name]
            local bodygroupSet = bodygroupData and bodygroupData[modelData.sex and 2 or 1] and bodygroupData[modelData.sex and 2 or 1][appearance.ABodygroups[v.name]]
            if not bodygroupSet then continue end
            for i = 0, #v.submodels do
                if bodygroupSet[1] == v.submodels[i] then
                    ent:SetBodygroup(k - 1, i)
                    break
                end
            end
        end
    end

    function preview:PostDrawModel(ent)
        local appearance = self.AppearanceTable
        if not appearance or not appearance.AAttachments then return end
        for _, attach in ipairs(appearance.AAttachments) do
            local accessoryData = hg.Accessories and hg.Accessories[attach]
            if accessoryData then
                DrawAccesories(ent, ent, attach, accessoryData, false, true)
            end
        end
        ent:SetupBones()
    end

    -- CS:GO gloves (the addon draws them over the hands): same drawing as in the appearance menu
    if hg.StaticAttachGloves then
        hg.StaticAttachGloves(preview, function()
            return hg.StaticGetGloveVariant and hg.StaticGetGloveVariant(preview) or nil
        end)
    end

    function preview:OnRemove()
        if IsValid(self.Entity) then
            CleanupPreviewAccessories(self.Entity)
        end
    end

    timer.Simple(0, function()
        if not IsValid(holder) then return end
        holder:MoveTo(targetX, targetY, appearance_preview.enter_time, 0, appearance_preview.enter_delay)
        holder:AlphaTo(255, appearance_preview.enter_time * 0.75, appearance_preview.enter_delay)
    end)
end

function PANEL:Init()
    self:SetAlpha(0)
    self:SetSize(ScrW(), ScrH())
    self:Center()
    self:SetTitle("")
    self:SetDraggable(false)
    self:SetBorder(false)
    self:SetColorBG(clr_verygray)
    self:SetDraggable(false)
    self:ShowCloseButton(false)
    curent_panel = nil
    self.Title, self.TitleShadow = self:InitializeMarkup()
    self.LiveLerp = 0
    self.LogoHoverLerp = 0
    self.DisconnectCutscene = false
    self.DisconnectBackgroundAlpha = 255
    self.DisconnectBlackAlpha = 0
    self:UseDefaultMenuMusic()

    timer.Simple(0, function()
        if self.First then
            self:First()
        end
    end)

    self:CreateAppearancePreview()
    self:CreateSidePanel()
    self:CreateProfileInfo()

    self.panelparrent = vgui.Create("DPanel", self)
    self.panelparrent:SetPos(0, 0)
    self.panelparrent:SetSize(ScrW(), ScrH())
    self.panelparrent:MoveToBack()
    self.panelparrent.Paint = function(this, w, h) end
end

function PANEL:First( ply )
    self:AlphaTo( 255, 0.1, 0, nil )
end

local gradient_d = surface.GetTextureID("vgui/gradient-d")
local gradient_r = surface.GetTextureID("vgui/gradient-r")
local gradient_l = surface.GetTextureID("vgui/gradient-l")
local menu_gradient_right = Color(18,18,18,65)

local clr_1 = Color(100,100,100,35)
function PANEL:Paint(w,h)
    local backgroundAlpha = math.Clamp(self.DisconnectBackgroundAlpha or 255, 0, 255)
    if backgroundAlpha > 0 then
        local bgMul = backgroundAlpha / 255
        -- light dim on the main screen, the original heavy dim + blur under sub-menus
        local sub = self.SubLerp or 0
        local bgA = Lerp(sub, 110, self.ColorBG.a or 255)
        draw.RoundedBox(0, 0, 0, w, h, Color(self.ColorBG.r, self.ColorBG.g, self.ColorBG.b, bgA * bgMul))
        -- barely-there blur on the main screen, the full blur under fullscreen sub-menus
        hg.DrawBlur(self, Lerp(sub, 1, 5), nil, 125 * sub)
        if sub > 0.02 then
            surface.SetDrawColor(menu_gradient_right.r, menu_gradient_right.g, menu_gradient_right.b, menu_gradient_right.a * bgMul * sub)
            surface.SetTexture(gradient_r)
            surface.DrawTexturedRect(0,0,w,h)
            surface.SetDrawColor(self.ColorBG.r, self.ColorBG.g, self.ColorBG.b, (self.ColorBG.a or 255) * bgMul * sub)
            surface.SetTexture(gradient_l)
            surface.DrawTexturedRect(0,0,w,h)
        end
        surface.SetDrawColor(clr_1.r, clr_1.g, clr_1.b, clr_1.a * bgMul)
        surface.SetTexture(gradient_d)
        surface.DrawTexturedRect(0,0,w,h)
    end
    if (self.DisconnectBlackAlpha or 0) > 0 then
        surface.SetDrawColor(0, 0, 0, self.DisconnectBlackAlpha)
        surface.DrawRect(0, 0, w, h)
    end
end

function PANEL:PlayDisconnectCutscene()
    if self.DisconnectCutscene then return end
    self.DisconnectCutscene = true
    self.DisconnectFadeStart = CurTime()
    self.DisconnectBackgroundAlpha = 255
    self.DisconnectBlackAlpha = 0
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)

    StopMainMenuMusic()

    if IsValid(self.previewHolder) then
        local holder = self.previewHolder
        holder:Stop()
        holder.DockHidden = nil
        holder:SetVisible(true)
        holder:SetAlpha(255)

        -- The preview only draws inside its own box, so walking out of it looked like walking into a wall.
        -- Stretch the box over the whole screen and widen the camera so the character keeps the same size
        -- and stays in the same place, with the whole screen to walk through.
        if IsValid(self.previewModel) and not holder.AppearanceFollow then
            local boxW, boxH = holder:GetSize()
            local boxX, boxY = holder:GetPos()
            local dist = 100
            local halfBox = math.tan(math.rad(appearance_preview.fov / 2)) * dist
            local unitsPerPixel = (halfBox * 2) / math.max(boxW, 1)
            local fullFov = math.deg(2 * math.atan((ScrW() * unitsPerPixel / 2) / dist))

            -- how far (world units) the character sits right of / below the screen centre
            local boxCenterX, boxCenterY = boxX + boxW / 2, boxY + boxH / 2
            self.previewModel.WalkOffsetY = (boxCenterX - ScrW() / 2) * unitsPerPixel
            local camPos = Vector(appearance_preview.cam_pos.x, appearance_preview.cam_pos.y, appearance_preview.cam_pos.z)
            camPos.z = camPos.z + (boxCenterY - ScrH() / 2) * unitsPerPixel
            self.previewModel.FOVOverride = math.Clamp(fullFov, 5, 120)
            self.previewModel.CamPosOverride = camPos

            holder:SetPos(0, 0)
            holder:SetSize(ScrW(), ScrH())
        end
    end

    if IsValid(self.previewModel) then
        self.WalkOffsetY = self.previewModel.WalkOffsetY
        self.previewModel.SequenceNameOverride = disconnect_cutscene.walk_sequence
        self.previewModel.SequencePlaybackRate = disconnect_cutscene.walk_playback_rate
        self.previewModel.EntityAngleOverride = disconnect_cutscene.walk_ang
        self.previewModel.ActiveSequenceName = nil
    end

    for _, child in ipairs(self:GetChildren()) do
        if child != self.previewHolder then
            child:AlphaTo(0, disconnect_cutscene.ui_fade_time, 0, function()
                if IsValid(child) then
                    child:SetVisible(false)
                end
            end)
        end
    end

    local function startBlackFade()
        if not IsValid(self) then return end
        self.DisconnectBlackStart = CurTime()
        self.DisconnectBlackAlpha = 0
        timer.Simple(disconnect_cutscene.black_fade_time + disconnect_cutscene.disconnect_delay, function()
            if IsValid(self) then
                RunConsoleCommand("disconnect")
            end
        end)
    end

    self.DisconnectWalkStart = CurTime() + disconnect_cutscene.ui_fade_time + disconnect_cutscene.walk_delay

    timer.Simple(disconnect_cutscene.ui_fade_time + disconnect_cutscene.walk_delay + disconnect_cutscene.walk_time, function()
        if IsValid(self) then
            startBlackFade()
        end
    end)
end

function PANEL:ResetCurrentPanel()
    curent_panel = nil
end

function PANEL:AddSelect(pParent, id, y, tbl, barH)
    local strTitle = tbl.Title
    local luaMenu = self
    barH = barH or S(45)
    local x = S(36)
    local wTop = SideEdge(y) - S(19) - x
    local dim = (tbl.Group or 1) > 1

    local btn = vgui.Create("DButton", pParent)
    self.Buttons[id] = btn
    btn:SetText("")
    btn:SetCursor("hand")
    btn:SetPos(x, y)
    btn:SetSize(math.ceil(wTop + SLOPE * barH) + 1, barH)
    btn:SetAlpha(0)
    btn.Func = tbl.Func
    btn.OpenTime = CurTime() + id * 0.045
    btn.HoverLerp = 0
    btn.ActiveLerp = 0

    function btn:DoClick()
        if luaMenu.DisconnectCutscene then return end
        if luaMenu.SwitchingPanel then return end
        surface.PlaySound(SOUND_MENU_SELECT)

        -- Settings / Keybinds / Achievements / Information open docked next to this menu
        if tbl.Docked then
            if luaMenu.DockTitle == strTitle then
                luaMenu:CloseDock()
            else
                luaMenu:OpenDock(strTitle, tbl.Func)
            end
            return
        end

        luaMenu:CloseDock(true)

        if tbl.BypassTransition then
            btn.Func(luaMenu)
            return
        end

        for _, child in ipairs(luaMenu:GetChildren()) do
            if child ~= luaMenu.panelparrent and not (strTitle == "Appearance" and child == luaMenu.previewHolder) then
                child:AlphaTo(0, 0.2, 0, function()
                    if IsValid(child) then child:SetVisible(false) end
                end)
            end
        end

        luaMenu.SwitchingPanel = true
        local oldPanel = luaMenu.panelparrent
        local function openPanel()
            if IsValid(luaMenu.panelparrent) then
                luaMenu.panelparrent:Remove()
            end
            luaMenu.panelparrent = vgui.Create("DPanel", luaMenu)

            luaMenu.panelparrent:SetPos(0, 0)
            luaMenu.panelparrent:SetSize(ScrW(), ScrH())
            luaMenu.panelparrent:MoveToFront()
            luaMenu.panelparrent.Paint = function(this, w, h) end
            btn.Func(luaMenu, luaMenu.panelparrent)
            curent_panel = string.lower(strTitle)
            luaMenu.SwitchingPanel = false
        end

        if IsValid(oldPanel) then
            oldPanel:AlphaTo(0, 0.2, 0, openPanel)
        else
            openPanel()
        end
    end

    function btn:Think()
        local hovered = self:IsHovered()
        if hovered and not self.WasHovered then
            surface.PlaySound(SOUND_MENU_HOVER)
        end
        self.WasHovered = hovered
        self.HoverLerp = LerpFT(0.25, self.HoverLerp or 0, hovered and 1 or 0)
        self.ActiveLerp = LerpFT(0.2, self.ActiveLerp or 0, (luaMenu.DockTitle == strTitle) and 1 or 0)

        -- slide / fade in, staggered per bar
        local t = math.Clamp((CurTime() - self.OpenTime) / 0.35, 0, 1)
        t = 1 - (1 - t) ^ 3
        self:SetAlpha(255 * t)
        self:SetX(x - S(26) * (1 - t))
    end

    function btn:Paint(w, h)
        local hl = math.max(self.HoverLerp or 0, (self.ActiveLerp or 0) * 0.8)
        surface.SetDrawColor(Lerp(hl, 33, 55), Lerp(hl, 35, 58), Lerp(hl, 41, 68), 238)
        DrawSlanted(0, 0, wTop, h)

        if hl > 0.01 then
            surface.SetDrawColor(255, 255, 255, 255 * hl)
            surface.DrawRect(0, 0, S(3), h)
        end

        local base = dim and col_text_dim or col_text
        local textCol = Color(Lerp(hl, base.r, 255), Lerp(hl, base.g, 255), Lerp(hl, base.b, 255))
        draw.SimpleText(string.format("%02d", id), "ZC_UI_NumBar", S(30), h / 2, col_text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(string.upper(strTitle), "ZC_UI_ItemBar", S(72), h / 2, textCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        return true
    end

    return btn
end

-- ---------------------------------------------------------------------------
-- Docked panels: Settings / Keybinds / Achievements / Information slide out from
-- behind the side panel and sit next to it, so any other bar can still be clicked.
-- ---------------------------------------------------------------------------
function PANEL:SetCharacterHidden(hidden, instant)
    self.CharacterHidden = hidden

    local holder = self.previewHolder
    if IsValid(holder) and not holder.AppearanceFollow then
        holder:Stop()
        holder:SetVisible(true)
        holder:SetAlpha(255)
        if instant then
            holder.DockHidden = nil
            holder:SetPos(holder.TargetX or holder:GetX(), holder.TargetY or holder:GetY())
        else
            holder.DockHidden = hidden
        end
    end

    local profile = self.profileInfo
    if IsValid(profile) then
        profile:Stop()
        profile:SetVisible(true)
        profile:SetAlpha(255)
        if instant then
            profile.DockHidden = nil
            profile:SetPos(profile:GetX(), profile.BaseY or S(27))
        else
            profile.DockHidden = hidden
        end
    end
end

-- builds the panel itself: it flies in from the right edge of the screen and stops against the side panel
function PANEL:BuildDock(strTitle, fnBuild)
    if self.DisconnectCutscene then return end

    local x0 = math.floor(SideEdge(0))
    local dockW = ScrW() - x0

    local dock = vgui.Create("DPanel", self)
    self.dock = dock
    self.DockTitle = strTitle
    dock.BaseX = x0
    dock.EnterLerp = 0
    dock:SetPos(ScrW(), 0)
    dock:SetSize(dockW, ScrH())
    dock.Paint = function(this, w, h)
        surface.SetDrawColor(17, 18, 23, 244)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawRect(0, 0, S(4), h)
    end

    -- slides back out to the right, off the edge of the screen
    dock.BeginClose = function(this, callback)
        this.Closing = true
        this.ExitStart = this:GetX()
        this.ExitLerp = 0
        this.OnClosed = callback
    end

    dock.Think = function(this)
        if this.Closing then
            this.ExitLerp = LerpFT(0.2, this.ExitLerp or 0, 1)
            -- back out the way it came in: to the right, until it is fully off screen
            this:SetX(math.floor(Lerp(this.ExitLerp, this.ExitStart, ScrW() + S(40))))
            if this.ExitLerp > 0.985 then
                local callback = this.OnClosed
                this:Remove()
                if callback then callback() end
            end
        else
            this.EnterLerp = LerpFT(0.16, this.EnterLerp or 0, 1)
            this:SetX(math.floor(Lerp(this.EnterLerp, ScrW(), this.BaseX)))
        end
    end

    local cx = math.floor(SLOPE * ScrH()) + S(26)
    local content = vgui.Create("DPanel", dock)
    content:SetPos(cx, S(26))
    content:SetSize(dockW - cx - S(26), ScrH() - S(52))
    content.IsDocked = true
    content.Paint = function() end

    local ok, err = pcall(fnBuild, self, content)
    if not ok then ErrorNoHaltWithStack(err) end
    -- the sub-menus paint a full-screen background of their own; the dock already provides one
    if IsValid(content) then content.Paint = function() end end

    -- sit under the side panel so it tucks in behind it
    dock:MoveToBack()
    if IsValid(self.panelparrent) then self.panelparrent:MoveToBack() end
end

function PANEL:OpenDock(strTitle, fnBuild)
    if self.DisconnectCutscene then return end

    self.DockTitle = strTitle
    if not self.CharacterHidden then
        self:SetCharacterHidden(true)
    end

    if IsValid(self.dock) then
        -- swapping: the open menu slides off to the right first, THEN the next one comes in
        local old = self.dock
        self.dock = nil
        self.DockQueue = {strTitle, fnBuild}
        old:BeginClose(function()
            if not IsValid(self) then return end
            local queued = self.DockQueue
            self.DockQueue = nil
            if queued then
                self:BuildDock(queued[1], queued[2])
            end
        end)
    elseif self.DockQueue then
        -- a swap is already under way, just point it at the newest choice
        self.DockQueue = {strTitle, fnBuild}
    else
        self:BuildDock(strTitle, fnBuild)
    end
end

function PANEL:CloseDock(instant)
    self.DockQueue = nil
    self.DockTitle = nil

    local dock = self.dock
    self.dock = nil
    if IsValid(dock) then
        if instant then
            dock:Remove()
        else
            dock:BeginClose()
        end
    end

    if self.CharacterHidden then
        self:SetCharacterHidden(false, instant)
    end
end

function PANEL:Close()
    if self.DisconnectCutscene then return end
    StopMainMenuMusic()
    if IsValid(self.previewModel) and IsValid(self.previewModel.Entity) then
        CleanupPreviewAccessories(self.previewModel.Entity)
    end
    if IsValid(self.previewHolder) then
        self.previewHolder.AppearanceFollow = false
        self.previewHolder:MoveTo(self.previewHolder.TargetX or self.previewHolder:GetX(), self.previewHolder.ClosedY or ScrH(), appearance_preview.exit_time, 0, appearance_preview.exit_delay)
        self.previewHolder:AlphaTo(0, appearance_preview.exit_time * 0.75, appearance_preview.exit_delay)
    end
    self:AlphaTo(0, appearance_preview.exit_time, 0, function()
        if IsValid(self) then
            self:Remove()
        end
    end)
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)
end

function PANEL:OnRemove()
    StopMainMenuMusic()
end

function PANEL:SetMenuMusic(path)
    QueueMainMenuMusic(self, path)
end

function PANEL:UseDefaultMenuMusic()
    self:SetMenuMusic(menu_music_default_path)
end

function PANEL:UseAppearanceMenuMusic()
    self:SetMenuMusic(menu_music_appearance_path)
end

vgui.Register( "ZMainMenu", PANEL, "ZFrame")

hook.Add("OnPauseMenuShow","OpenMainMenu",function()
    local run = hook.Run("OnShowZCityPause")
    if run != nil then
        return run
    end

    if MainMenu and IsValid(MainMenu) then
        if MainMenu.DisconnectCutscene then
            return false
        end
        MainMenu:Close()
        MainMenu = nil
        return false
    end

    MainMenu = vgui.Create("ZMainMenu")
    MainMenu:MakePopup()
    return false
end)
