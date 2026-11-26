hg.Appearance = hg.Appearance or {}
local APmodule = hg.Appearance
local PANEL = {}

local colors = {}
colors.secondary = Color(25,25,35,195)
colors.mainText = Color(255,255,255,255)
colors.secondaryText = Color(45,45,45,125)
colors.selectionBG = Color(20,130,25,225)
colors.highlightText = Color(120,35,35)
colors.presetBG = Color(35,35,45,220)
colors.presetBorder = Color(80,80,100,255)
colors.presetHover = Color(50,50,65,240)
colors.scrollbarBG = Color(20,20,30,200)
colors.scrollbarGrip = Color(70,70,90,255)
colors.scrollbarGripHover = Color(100,100,130,255)
colors.scrollbarBorder = Color(100,100,120,200)
colors.previewBorder = Color(255,200,50,255)

local presetsDir = "zcity/appearances/presets/"
local SOUND_APPEARANCE_SUCCESS = "ui/rem_success.wav"

local function SavePreset(strName, tblAppearance)
    file.CreateDir(presetsDir)
    file.Write(presetsDir .. strName .. ".json", util.TableToJSON(tblAppearance, true))
end

local function LoadPreset(strName)
    if not file.Exists(presetsDir .. strName .. ".json", "DATA") then return nil end
    return util.JSONToTable(file.Read(presetsDir .. strName .. ".json", "DATA"))
end

local function GetPresetList()
    file.CreateDir(presetsDir)
    local files = file.Find(presetsDir .. "*.json", "DATA")
    local presets = {}
    for _, f in ipairs(files or {}) do
        table.insert(presets, string.StripExtension(f))
    end
    return presets
end

local function DeletePreset(strName)
    if file.Exists(presetsDir .. strName .. ".json", "DATA") then
        file.Delete(presetsDir .. strName .. ".json")
        return true
    end
    return false
end

hg.Appearance.SavePreset = SavePreset
hg.Appearance.LoadPreset = LoadPreset
hg.Appearance.GetPresetList = GetPresetList
hg.Appearance.DeletePreset = DeletePreset

local modelsPrecached = false
local function PrecacheAccessoryModels()
    if modelsPrecached then return end
    modelsPrecached = true
    
    timer.Simple(0.1, function()
        if APmodule.PlayerModels then
            for _, sexModels in SortedPairs(APmodule.PlayerModels) do
                for _, modelData in SortedPairs(sexModels) do
                    if modelData.mdl then
                        util.PrecacheModel(modelData.mdl)
                    end
                end
            end
        end
        
        if hg.Accessories then
            for _, accessory in SortedPairs(hg.Accessories) do
                if accessory.model then
                    util.PrecacheModel(accessory.model)
                end
            end
        end
    end)
end


hook.Add("InitPostEntity", "HG_PrecacheAppearanceModels", function()
    timer.Simple(5, PrecacheAccessoryModels)
end)

hg.Appearance.PrecacheModels = PrecacheAccessoryModels


local function CreateStyledScrollPanel(parent)
    local scroll = vgui.Create("DScrollPanel", parent)
    
    local sbar = scroll:GetVBar()
    sbar:SetWide(ScreenScale(4))
    sbar:SetHideButtons(true)
    
    function sbar:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, colors.scrollbarBG)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    
    function sbar.btnGrip:Paint(w, h)
        local col = self:IsHovered() and colors.scrollbarGripHover or colors.scrollbarGrip
        draw.RoundedBox(4, 2, 2, w - 4, h - 4, col)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 1)
    end
    
    return scroll
end

local clr_ico, clr_menu = Color(30, 30, 40, 255), Color(15, 15, 20, 250)
local function CreateStyledAccessoryMenu(parent, title)
    local menu = vgui.Create("DFrame")
    menu:SetTitle(title or "")
    menu:SetSize(ScreenScale(90), ScreenScale(140))
    local cx,cy = input.GetCursorPos()
    menu:SetPos(cx,cy)
    menu:MakePopup()
    menu:SetDraggable(false)
    menu:ShowCloseButton(false)
    
    menu.CurrentPreviewIcon = nil  
    
    function menu:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, clr_menu)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 2)

        draw.RoundedBoxEx(8, 0, 0, w, ScreenScale(10), colors.secondary, true, true, false, false)
        surface.SetDrawColor(colors.scrollbarBorder)
        surface.DrawLine(0, ScreenScale(10), w, ScreenScale(10))
    end

    local scroll = CreateStyledScrollPanel(menu)
    scroll:Dock(FILL)
    scroll:DockMargin(ScreenScale(2), ScreenScale(2), ScreenScale(2), ScreenScale(2))

    local iconLayout = vgui.Create("DIconLayout", scroll)
    iconLayout:Dock(TOP)
    iconLayout:SetSpaceX(ScreenScale(2))
    iconLayout:SetSpaceY(ScreenScale(2))

    menu.IconLayout = iconLayout
    menu.ScrollPanel = scroll

    function menu:AddAccessoryIcon(model, accessorKey, accessoryData, onSelect, onRightClick, isPreview)
        local ico = vgui.Create("DPanel", self.IconLayout)
        local icoSize = ScreenScale(36)
        ico:SetSize(icoSize, icoSize)
        ico.Accessor = accessorKey
        ico.bIsHovered = false
        ico.IsPreviewing = false

        local spawnIcon = vgui.Create( "DModelPanel", ico )
        spawnIcon:Dock(FILL)
        spawnIcon:DockMargin(2,2,2,2)
        spawnIcon:SetModel(model or "models/error.mdl")
        spawnIcon:SetTooltip(string.NiceName(accessoryData and accessoryData.name or accessorKey))
        spawnIcon:SetFOV(15)
        spawnIcon:SetLookAt( accessoryData.vpos or Vector(0,0,0) )
        function spawnIcon:PreDrawModel(ent)
            if accessoryData.bSetColor then
                local colorDraw = accessoryData.vecColorOveride or ( lply.GetPlayerColor and lply:GetPlayerColor() or lply:GetNWVector("PlayerColor",Vector(1,1,1)) )
                render.SetColorModulation( colorDraw[1],colorDraw[2],colorDraw[3] )
            end
        end

        function spawnIcon:PostDrawModel(ent)
            if accessoryData.bSetColor then
                render.SetColorModulation( 1, 1, 1 )
            end
        end
        timer.Simple(0,function()
            if not IsValid(spawnIcon) or not IsValid(spawnIcon.Entity) then return end
            spawnIcon.Entity:SetSkin((isfunction(accessoryData.skin) and accessoryData.skin()) or (accessoryData.skin or 0))
            spawnIcon.Entity:SetBodyGroups(accessoryData.bodygroups or "0000000")
            if accessoryData.SubMat then
                spawnIcon.Entity:SetSubMaterial( 0, accessoryData.SubMat )
            end
        end)

        function spawnIcon:DoClick()
            if onSelect then onSelect(accessorKey) end
            surface.PlaySound("player/clothes_generic_foley_0"..math.random(5)..".wav")
            menu:Close()
        end
        
        function spawnIcon:Think()
            if onRightClick and self:IsHovered() then
                ico.IsPreviewing = true

                if ico.IsPreviewing then
                    menu.CurrentPreviewIcon = ico
                else
                    menu.CurrentPreviewIcon = nil
                end

                onRightClick(accessorKey, ico.IsPreviewing)
            end
        end

        function ico:Paint(w, h)
            draw.RoundedBox(4, 0, 0, w, h, clr_ico)
        end

        function ico:Think()
            self.bIsHovered = vgui.GetHoveredPanel() == self or vgui.GetHoveredPanel() == spawnIcon
        end

        return ico
    end
    
    function menu:AddNoneOption(onSelect)
        local ico = vgui.Create("DPanel", self.IconLayout)
        local icoSize = ScreenScale(36)
        ico:SetSize(icoSize, icoSize)
        ico.Accessor = "none"
        ico.bIsHovered = false
        
        function ico:Paint(w, h)
            local borderCol = self.bIsHovered and colors.scrollbarGripHover or colors.scrollbarBorder
            draw.RoundedBox(4, 0, 0, w, h, Color(30, 30, 40, 255))
            surface.SetDrawColor(borderCol)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            
            surface.SetDrawColor(colors.highlightText)
            local margin = ScreenScale(8)
            surface.DrawLine(margin, margin, w - margin, h - margin)
            surface.DrawLine(w - margin, margin, margin, h - margin)
            
            draw.SimpleText("None", "DermaDefault", w/2, h - ScreenScale(4), colors.mainText, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        end
        
        function ico:Think()
            self.bIsHovered = vgui.GetHoveredPanel() == self
        end
        
        function ico:OnMousePressed(mc)
            if mc == MOUSE_LEFT then
                if onSelect then onSelect("none") end
                surface.PlaySound("player/clothes_generic_foley_0"..math.random(5)..".wav")
                menu:Close()
            end
        end
        
        function ico:OnCursorEntered()
            self:SetCursor("hand")
        end
        
        return ico
    end
    
    return menu
end

function PANEL:SetAppearance( tAppearacne )
    self.AppearanceTable = tAppearacne
end

function PANEL:CallbackAppearance()

end

function PANEL:First( ply )
    self:AlphaTo( 255, 0.2, 0.1, nil )

    if self.PostInit then
        self:PostInit()
    end
end

local sizeX, sizeY = ScrW() * 1, ScrH() * 1

local function MenuUnit(num)
    return math.floor(num * math.min(ScrW(), ScrH()) / 1000)
end

-- ---------------------------------------------------------------------------
-- Look shared with the main esc menu (slanted dark panels, numbered bars)
-- ---------------------------------------------------------------------------
local UI_FONT = "Arial" -- change to any font installed on your clients
local SLOPE = 0 -- 0 = straight edges (same as the main menu)

local function S(n)
    return math.floor(n * ScrH() / 1080 + 0.5)
end

local function CreateAppearanceFonts()
    local function make(name, size, weight)
        surface.CreateFont(name, {
            font = UI_FONT,
            size = S(size),
            weight = weight,
            antialias = true,
            extended = true
        })
    end
    make("ZC_AP_Title", 34, 600)
    make("ZC_AP_Item", 23, 500)
    make("ZC_AP_Card", 18, 600)
    make("ZC_AP_Tab", 28, 500)
    make("ZC_AP_Small", 17, 500)
    make("ZC_AP_Tiny", 14, 400)
end
hook.Add("OnScreenSizeChanged", "ZCity_Appearance_UIFonts", CreateAppearanceFonts)
CreateAppearanceFonts()

local ap_panel = Color(21, 22, 27, 248)
local ap_text = Color(236, 238, 242)
local ap_text_dim = Color(152, 155, 163)

local function DrawSlanted(x, y, w, h)
    draw.NoTexture()
    surface.DrawPoly({
        {x = x, y = y},
        {x = x + w, y = y},
        {x = x + w + SLOPE * h, y = y + h},
        {x = x, y = y + h}
    })
end


-- ---------------------------------------------------------------------------
-- CS:GO gloves (addon "[Z-CITY] CSGO GLOVES")
-- They are not body groups: the addon draws a separate glove model over the hands and hooks itself into the
-- OLD editor panel, which this menu replaced. So this menu talks to the addon directly (global ZCGloves):
-- the cards use its icons and the preview models get its drawing code attached.
-- ---------------------------------------------------------------------------
local gloveIcons = {}
local function GloveIcon(variant)
    local icon = gloveIcons[variant.id]
    if icon == nil then
        local mat = Material("zcity_csgo_gloves/icons/" .. variant.id .. ".png", "smooth mips")
        icon = (mat and not mat:IsError()) and mat or false
        gloveIcons[variant.id] = icon
    end
    return icon or nil
end

local function CsgoVariant(name)
    local ZCG = ZCGloves
    return ZCG and ZCG.ByName and ZCG.ByName[name] or nil
end

-- the glove a preview should show: the one hovered in the CS:GO tab, else the one in the appearance it displays
function hg.StaticGetGloveVariant(viewer)
    local card = hg.StaticGlovePreviewCard
    if hg.StaticGlovePreview and IsValid(card) and card:IsHovered() then
        return hg.StaticGlovePreview
    end
    hg.StaticGlovePreview = nil

    local appearance = IsValid(viewer) and viewer.AppearanceTable
    local groups = istable(appearance) and appearance.ABodygroups
    local name = istable(groups) and groups.HANDS
    return name and CsgoVariant(name) or nil
end

-- same drawing steps the addon's own editor integration uses (cl_editor.lua), attached to any DModelPanel
function hg.StaticAttachGloves(viewer, getVariant)
    local ZCG = ZCGloves
    if not IsValid(viewer) then return end
    viewer.StaticGloveGetter = getVariant
    if viewer.StaticGlovesAttached then return end
    if not (ZCG and ZCG.DrawGlove and ZCG.Wearing and ZCG.States and ZCG.GiveBack) then return end
    viewer.StaticGlovesAttached = true

    local layout, preDraw, postDraw = viewer.LayoutEntity, viewer.PreDrawModel, viewer.PostDrawModel
    local broken = false

    local function variantOf()
        local get = viewer.StaticGloveGetter
        return get and get() or nil
    end

    local function guard(fn, ent)
        if broken then return end
        local ok, err = pcall(fn, ent)
        if not ok then
            broken = true
            ErrorNoHalt("[Static] CS:GO glove preview switched off: " .. tostring(err) .. "\n")
        end
    end

    -- the hands go only while a glove really is drawn over them
    local function gloveOn(ent)
        if not IsValid(ent) then return nil end
        local variant = variantOf()
        if not variant or not ZCG.HasModel(variant.model) then
            ZCG.GiveBack(ent)
            return nil
        end
        local state = ZCG.States[ent]
        if not state or not state.drawn then return nil end
        return variant, state
    end

    local function onLayout(ent)
        local variant = gloveOn(ent)
        if not variant then return end
        local slot, _, _, more = ZCG.Wearing(ent, variant)
        if slot then
            ent:SetSubMaterial(slot, ZCG.HideMaterial())
            ZCG.NoteHidden(ent, slot)
        end
        for _, other in ipairs(more or {}) do
            ent:SetSubMaterial(other, ZCG.HideMaterial())
            ZCG.NoteHidden(ent, other)
        end
    end

    local function onBefore(ent)
        local variant, state = gloveOn(ent)
        if not variant then return end
        local _, _, bones = ZCG.Wearing(ent, variant)
        if not bones then return end
        ent:SetupBones()
        state.shrunk = ZCG.ShrinkHands(ent, state)
    end

    local function onAfter(ent)
        local state = IsValid(ent) and ZCG.States[ent]
        if state then ZCG.GrowHands(ent, state) end
    end

    local function onDraw(ent)
        if not IsValid(ent) then return end
        local variant = variantOf()
        if variant then
            local _, fingers = ZCG.Wearing(ent, variant)
            local state = ZCG.States[ent]
            if state then state.shrunk = false end
            ZCG.DrawGlove(ent, variant, fingers)
        else
            ZCG.ClearGlove(ent)
        end
    end

    viewer.LayoutEntity = function(self, ent, ...)
        local result
        if isfunction(layout) then result = layout(self, ent, ...) end
        if not broken and IsValid(ent) and istable(self.AppearanceTable) and ZCG.FixBodygroups then
            pcall(ZCG.FixBodygroups, ent, self.AppearanceTable)
        end
        guard(onLayout, ent)
        return result
    end

    viewer.PreDrawModel = function(self, ent, ...)
        local result = true
        if isfunction(preDraw) then result = preDraw(self, ent, ...) end
        if result ~= false then guard(onBefore, ent) end
        return result
    end

    viewer.PostDrawModel = function(self, ent, ...)
        guard(onAfter, ent)
        local result
        if isfunction(postDraw) then result = postDraw(self, ent, ...) end
        guard(onDraw, ent)
        return result
    end
end

-- Camera presets for the big previews on each card.
-- fov is horizontal, dist is the camera distance, z is the height the camera looks at.
local CARD_VIEWS = {
    body  = {fov = 32, dist = 150, z = 37},
    torso = {fov = 26, dist = 105, z = 49},
    legs  = {fov = 28, dist = 110, z = 27},
    boots = {fov = 24, dist = 70,  z = 10},
    hands = {fov = 26, dist = 80,  z = 34},
    face  = {fov = 18, dist = 62,  z = 64},
}


local gradient_d = surface.GetTextureID("vgui/gradient-d")
local gradient_l = surface.GetTextureID("vgui/gradient-l")
local gradient_r = surface.GetTextureID("vgui/gradient-r")

local appearance_color_white = Color(255,255,255,240)
local appearance_color_text = Color(225,225,225)
local appearance_color_text_dim = Color(160,160,160)
local appearance_color_dim = Color(60,60,60,180)
local appearance_clr_1 = Color(100,100,100,35)
local appearance_clr_verygray = Color(10,10,19,235)
local appearance_gradient_right = Color(18,18,18,65)
local appearance_preview_shift_x = 230
local appearance_preview_shift_y = 140
local appearance_name_width = 360
local appearance_preview_move_time = 0.25
local appearance_preview_fov = 13 -- lower = bigger character
local appearance_preview_cam_pos = Vector(118, 0, 64)
local appearance_preview_look_ang = Angle(11, 180, 0)
local appearance_selector_width = 400
local appearance_preview_selector_shift_x = 60
local appearance_name_fade_speed = 0.18
local appearance_return_move_time = 0.32
local appearance_header_height = 70
local appearance_panel_slide_speed = 8
local appearance_unsaved_box_width = 420
local appearance_unsaved_box_height = 170
local appearance_unsaved_button_width = 140
local appearance_unsaved_button_height = 34
local appearance_unsaved_message = "You havent saved your changes."
local appearance_unsaved_fade_in_time = 0.12
local appearance_unsaved_fade_out_time = 0.1
local appearance_unsaved_box_rise = 10

local ATTACHMENT_SLOTS = 6 -- 1 hat, 2 face, 3 body, 4 hat 2, 5 face 2, 6 body 2

local function BuildComparableAppearanceTable(tblAppearance)
    local appearance = table.Copy(tblAppearance or {})
    appearance.AAttachments = appearance.AAttachments or {}
    for i = 1, ATTACHMENT_SLOTS do
        appearance.AAttachments[i] = appearance.AAttachments[i] or "none"
    end
    appearance.AClothes = appearance.AClothes or {}
    appearance.ABodygroups = appearance.ABodygroups or {}
    if IsColor(appearance.AColor) then
        appearance.AColor = {
            r = appearance.AColor.r,
            g = appearance.AColor.g,
            b = appearance.AColor.b,
            a = appearance.AColor.a
        }
    elseif istable(appearance.AColor) then
        appearance.AColor = {
            r = appearance.AColor.r or appearance.AColor[1] or 255,
            g = appearance.AColor.g or appearance.AColor[2] or 255,
            b = appearance.AColor.b or appearance.AColor[3] or 255,
            a = appearance.AColor.a or appearance.AColor[4] or 255
        }
    else
        appearance.AColor = {
            r = 255,
            g = 255,
            b = 255,
            a = 255
        }
    end
    return appearance
end

local function AppearanceValueEqual(a, b)
    if istable(a) and istable(b) then
        for k, v in pairs(a) do
            if not AppearanceValueEqual(v, b[k]) then
                return false
            end
        end
        for k, v in pairs(b) do
            if not AppearanceValueEqual(v, a[k]) then
                return false
            end
        end
        return true
    end
    return a == b
end

local function CreateAppearanceTextButton(pParent, strTitle, fnClick, fnIsActive)
    local btn = vgui.Create("DButton", pParent)
    btn:SetText("")
    btn:SetCursor("hand")
    btn:Dock(TOP)
    btn:SetTall(S(40))
    btn:DockMargin(S(36), 0, 0, S(5))
    btn.HoverLerp = 0
    btn.ActiveLerp = 0
    btn.Root = pParent.SidebarRoot or pParent

    function btn:DoClick()
        surface.PlaySound("ui/rem_select.wav")
        if fnClick then
            fnClick()
        end
    end

    function btn:OnCursorEntered()
        surface.PlaySound("ui/rem_hover.wav")
    end

    function btn:Think()
        self.HoverLerp = LerpFT(0.25, self.HoverLerp or 0, self:IsHovered() and 1 or 0)
        self.ActiveLerp = LerpFT(0.2, self.ActiveLerp or 0, (fnIsActive and fnIsActive()) and 1 or 0)
    end

    function btn:Paint(w, h)
        -- right edge follows the slanted edge of the sidebar
        local rx, ry = self.Root:LocalToScreen(0, 0)
        local sx, sy = self:LocalToScreen(0, 0)
        local lx, ly = sx - rx, sy - ry
        local wTop = (self.Root.EdgeTop or w) + SLOPE * ly - S(19) - lx

        local hl = math.max(self.HoverLerp or 0, (self.ActiveLerp or 0) * 0.85)
        surface.SetDrawColor(Lerp(hl, 33, 55), Lerp(hl, 35, 58), Lerp(hl, 41, 68), 238)
        DrawSlanted(0, 0, wTop, h)
        if hl > 0.01 then
            surface.SetDrawColor(255, 255, 255, 255 * hl)
            surface.DrawRect(0, 0, S(3), h)
        end

        local v = Lerp(hl, 205, 255)
        draw.SimpleText(string.upper(strTitle), "ZC_AP_Item", S(22), h / 2, Color(v, v, v), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        return true
    end

    return btn
end

local function CreateAppearanceInfoRow(pParent, strTitle, fnValue)
    local row = vgui.Create("DPanel", pParent)
    row:Dock(TOP)
    row:SetTall(MenuUnit(56))
    row:DockMargin(MenuUnit(10), MenuUnit(4), MenuUnit(10), MenuUnit(4))
    row.Paint = function(self, w, h)
        surface.SetDrawColor(20, 20, 30, 120)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(appearance_color_white.r, appearance_color_white.g, appearance_color_white.b, 90)
        surface.DrawRect(0, h - MenuUnit(1), w, MenuUnit(1))
        draw.SimpleText(strTitle, "ZCity_Menu_Settings_Small", MenuUnit(12), MenuUnit(8), appearance_color_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(fnValue(), "ZCity_Menu_Settings_Tiny", MenuUnit(12), MenuUnit(31), appearance_color_text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    return row
end

function PANEL:Paint(w,h)
    -- background (dim + blur) is drawn by the main menu behind this panel
end

function PANEL:GetCurrentModelData()
    if not self.AppearanceTable then return end
    return APmodule.PlayerModels[1][self.AppearanceTable.AModel] or APmodule.PlayerModels[2][self.AppearanceTable.AModel]
end

function PANEL:SyncSharedPreview()
    local parent = self:GetParent()
    local luaMenu = IsValid(parent) and parent:GetParent()
    if not IsValid(luaMenu) or not IsValid(luaMenu.previewModel) then return end
    self.SharedMenu = luaMenu
    self.SharedPreview = luaMenu.previewModel
    self.SharedPreviewHolder = luaMenu.previewHolder
    if not self.SharedPreviewOriginal then
        local baseAppearance = luaMenu.previewModel.AppearanceTable
        if not baseAppearance and luaMenu.GetPreviewAppearance then
            baseAppearance = select(1, luaMenu:GetPreviewAppearance())
        end
        self.SharedPreviewOriginal = table.Copy(baseAppearance or self.AppearanceTable or {})
    end
    luaMenu.previewModel.AppearanceTable = self.AppearanceTable
    luaMenu.previewModel:SetVisible(true)
    luaMenu.previewModel:SetAlpha(255)
    luaMenu.previewModel.EntityAngleOverride = self.PreviewRotated and Angle(0, 180, 0) or nil
    luaMenu.previewModel.SequenceNameOverride = nil
    luaMenu.previewModel.SequencePlaybackRate = nil
    luaMenu.previewModel.ActiveSequenceName = nil
    luaMenu.previewModel.CamPosOverride = appearance_preview_cam_pos
    luaMenu.previewModel.FOVOverride = appearance_preview_fov
    luaMenu.previewModel.LookAngOverride = appearance_preview_look_ang
    if IsValid(luaMenu.previewHolder) then
        if not self.SharedPreviewHolderOriginal then
            self.SharedPreviewHolderOriginal = {
                x = luaMenu.previewHolder.TargetX or luaMenu.previewHolder:GetX(),
                y = luaMenu.previewHolder.TargetY or luaMenu.previewHolder:GetY(),
                w = luaMenu.previewHolder:GetWide(),
                h = luaMenu.previewHolder:GetTall(),
                closedY = luaMenu.previewHolder.ClosedY
            }
        end
        local targetX = (self.AppearancePreviewX or luaMenu.previewHolder:GetX()) - math.floor((self.PreviewSelectorShiftX or 0) * (self.SelectorOpenLerp or 0))
        local targetY = self.AppearancePreviewY or luaMenu.previewHolder:GetY()
        luaMenu.previewHolder.TargetX = targetX
        luaMenu.previewHolder.TargetY = targetY
        luaMenu.previewHolder.AppearanceFollow = true
        luaMenu.previewHolder:SetVisible(true)
        luaMenu.previewHolder:SetAlpha(255)
        luaMenu.previewHolder:MoveToFront()
    end
end

function PANEL:RestoreSharedPreview()
    if not IsValid(self.SharedPreview) then return end
    self.SharedPreview.AppearanceTable = table.Copy(self.SharedPreviewOriginal or self.AppearanceTable or {})
    self.SharedPreview.EntityAngleOverride = nil
    self.SharedPreview.SequenceNameOverride = nil
    self.SharedPreview.SequencePlaybackRate = nil
    self.SharedPreview.ActiveSequenceName = nil
    self.SharedPreview.CamPosOverride = nil
    self.SharedPreview.FOVOverride = nil
    self.SharedPreview.LookAngOverride = nil
    if IsValid(self.SharedPreviewHolder) and self.SharedPreviewHolderOriginal then
        self.SharedPreviewHolder.AppearanceFollow = false
        self.SharedPreviewHolder.TargetX = self.SharedPreviewHolderOriginal.x
        self.SharedPreviewHolder.TargetY = self.SharedPreviewHolderOriginal.y
        self.SharedPreviewHolder:SetSize(self.SharedPreviewHolderOriginal.w, self.SharedPreviewHolderOriginal.h)
        self.SharedPreviewHolder.ClosedY = self.SharedPreviewHolderOriginal.closedY
        self.SharedPreviewHolder:MoveTo(self.SharedPreviewHolderOriginal.x, self.SharedPreviewHolderOriginal.y, appearance_return_move_time, 0, 0, function()
            if IsValid(self.SharedPreviewHolder) then
                self.SharedPreviewHolder:SetPos(self.SharedPreviewHolderOriginal.x, self.SharedPreviewHolderOriginal.y)
            end
        end)
    end
end

function PANEL:ReturnToMenu()
    self.RestoringToMenu = true
    self.SelectorOpenLerp = 0
    self:RestoreSharedPreview()
    local parent = self:GetParent()
    local luaMenu = IsValid(parent) and parent:GetParent()
    if IsValid(luaMenu) and luaMenu.UseDefaultMenuMusic then
        luaMenu:UseDefaultMenuMusic()
    end
    if IsValid(parent) then
        parent:AlphaTo(0, 0.2, 0, function()
            if IsValid(parent) then
                parent:Remove()
            end
        end)
    end
    if IsValid(luaMenu) then
        for _, child in ipairs(luaMenu:GetChildren()) do
            if child ~= parent then
                child:SetVisible(true)
                child:AlphaTo(255, 0.2, 0)
            end
        end
        if luaMenu.ResetCurrentPanel then
            luaMenu:ResetCurrentPanel()
        end
    end
end

function PANEL:PostInit()
    local main = self
    self:SetBorder(false)
    self:SetDraggable(false)
    self:ShowCloseButton(false)
    if IsValid(self.btnClose) then
        self.btnClose:SetVisible(false)
        self.btnClose:SetMouseInputEnabled(false)
    end
    local parent = self:GetParent()
    local luaMenu = IsValid(parent) and parent:GetParent()
    if IsValid(luaMenu) and luaMenu.UseAppearanceMenuMusic then
        luaMenu:UseAppearanceMenuMusic()
    end
    self.AppearanceTable = table.Copy(self.AppearanceTable or hg.Appearance.LoadAppearanceFile(hg.Appearance.SelectedAppearance:GetString()) or APmodule.GetRandomAppearance())
    self.AppearanceTable.AAttachments = self.AppearanceTable.AAttachments or {"none", "none", "none", "none", "none", "none"}
    self.AppearanceTable.AClothes = self.AppearanceTable.AClothes or {}
    self.AppearanceTable.ABodygroups = self.AppearanceTable.ABodygroups or {}
    self.AppearanceTable.AColor = self.AppearanceTable.AColor or color_white
    self.PreviewRotated = false
    self.ActiveSection = "Model"
    self.SelectorOpenLerp = 0
    self.PreviewSelectorShiftX = MenuUnit(appearance_preview_selector_shift_x)

    local nameEntry
    local previewNameLabel
    local selectorPanel
    local selectorHeaderTitle
    local selectorHeaderHint
    local selectorContent
    local currentSelectorSection
    local CloseSelectorPanel
    local savedAppearanceSnapshot
    local unsavedOverlay

    local function CloseAllAccessoryMenus()
    end

    local function AddSelectorTextRow(parent, strTitle, fnIsActive, fnClick, strTooltip)
        local row = vgui.Create("DLabel", parent)
        row:Dock(TOP)
        row:SetTall(MenuUnit(42))
        row:DockMargin(MenuUnit(12), MenuUnit(2), MenuUnit(12), 0)
        row:SetFont("ZCity_Menu_Settings_Small")
        row:SetText("")
        row:SetMouseInputEnabled(true)
        row.Title = strTitle
        if strTooltip and strTooltip != "" then
            row:SetTooltip(strTooltip)
        end
        function row:DoClick()
            if fnClick then
                fnClick()
            end
        end
        function row:Think()
            self.IsActive = fnIsActive and fnIsActive() or false
            self.HoverLerp = LerpFT(0.2, self.HoverLerp or 0, self:IsHovered() and 1 or 0)
            self.LineLerp = LerpFT(0.2, self.LineLerp or 0, (self:IsHovered() or self.IsActive) and 1 or 0)
        end
        function row:Paint(w, h)
            local isHovered = self:IsHovered()
            local flash = isHovered and (0.5 + 0.5 * math.sin(CurTime() * 10)) or 0
            local textColor = appearance_color_text
            local outlineColor = Color(0, 0, 0, 255)
            if self.IsActive then
                textColor = appearance_color_white
            end
            if isHovered then
                local v = 175 + flash * 80
                textColor = Color(v, v, v, 255)
                local inv = 255 - v
                outlineColor = Color(inv, inv, inv, 255)
            end
            draw.SimpleText(self.Title, self:GetFont(), 0, h * 0.5, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if self.LineLerp and self.LineLerp > 0.01 then
                surface.SetDrawColor(255, 255, 255, 255 * self.LineLerp)
                local tw, th = surface.GetTextSize(self.Title)
                surface.DrawRect(0, h * 0.5 + th * 0.5, tw * self.LineLerp, math.max(1, MenuUnit(1)))
            end
            return true
        end
        return row
    end

    local function CardIsInView(panel, scroll)
        local _, y = panel:LocalToScreen(0, 0)
        local _, sy = scroll:LocalToScreen(0, 0)
        return y + panel:GetTall() > sy - S(40) and y < sy + scroll:GetTall() + S(40)
    end

    local function CreateCardGrid(scroll)
        local layout = vgui.Create("DIconLayout", scroll)
        layout:Dock(TOP)
        layout:DockMargin(S(14), S(10), S(8), S(10))
        layout:SetSpaceX(S(12))
        layout:SetSpaceY(S(12))
        return layout
    end

    local function GetCardSize()
        local avail = selectorPanel:GetWide() - S(14) - S(8) - ScreenScale(4) - S(8)
        local w = math.floor((avail - S(12)) / 2)
        return w, S(252)
    end

    -- Dresses a preview entity the way the real player would look with one setting swapped.
    local function ApplyCardLook(view, ent, modelData, ov)
        ov = ov or {}
        local at = main.AppearanceTable or {}
        local sexID = modelData.sex and 2 or 1
        local list = hg.Appearance.Clothes[sexID] or {}

        view.Mats = view.Mats or ent:GetMaterials()
        view.BodyGroups = view.BodyGroups or ent:GetBodyGroups()
        local mats = view.Mats

        ent:SetSubMaterial()
        for k, matName in pairs(modelData.submatSlots or {}) do
            local slot = 1
            for i = 1, #mats do
                if mats[i] == matName then
                    slot = i - 1
                    break
                end
            end
            local val = (ov.clothesKey == k) and ov.clothesVal or (at.AClothes and at.AClothes[k])
            ent:SetSubMaterial(slot, list[val] or list.normal)
        end

        local face = ov.facemap or at.AFacemap
        local facemapSlot = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[modelData.mdl]
        if facemapSlot then
            for i = 1, #mats do
                local fm = hg.Appearance.FacemapsSlots[mats[i]]
                if fm and fm[face] then
                    ent:SetSubMaterial(i - 1, fm[face])
                end
            end
        end

        local bgTable = hg.Appearance.Bodygroups or {}
        local current = at.ABodygroups or {}
        for _, bg in ipairs(view.BodyGroups) do
            local val = (ov.bodygroupName == bg.name) and ov.bodygroupVal or current[bg.name]
            local data = val and bgTable[bg.name] and bgTable[bg.name][sexID] and bgTable[bg.name][sexID][val]
            if data then
                for i = 0, #bg.submodels do
                    if data[1] == bg.submodels[i] then
                        ent:SetBodygroup(bg.id, i)
                        break
                    end
                end
            end
        end

        local c = at.AColor or color_white
        view.PlayerVec = view.PlayerVec or Vector(1, 1, 1)
        view.PlayerVec:SetUnpacked((c.r or 255) / 255, (c.g or 255) / 255, (c.b or 255) / 255)
        ent:SetNWVector("PlayerColor", view.PlayerVec)
    end

    -- opts: title, subtitle, tooltip, isActive(), onClick(), model, camera (CARD_VIEWS entry),
    --       modelData + overrides (dress a player model), accessory (accessory data), isNone
    local function AddSelectorCard(layout, scroll, opts)
        local cardW, cardH = GetCardSize()
        local viewH = cardH - S(58)

        local card = vgui.Create("DButton", layout)
        card:SetSize(cardW, cardH)
        card:SetText("")
        card:SetCursor("hand")
        if opts.tooltip and opts.tooltip != "" then
            card:SetTooltip(opts.tooltip)
        end
        card.HoverLerp = 0
        card.ActiveLerp = 0
        card.Spin = 0

        function card:DoClick()
            if opts.onClick then
                opts.onClick()
            end
        end

        function card:OnCursorEntered()
            surface.PlaySound("ui/rem_hover.wav")
        end

        local view
        if opts.model then
            view = vgui.Create("DModelPanel", card)
            view:SetPos(0, 0)
            view:SetSize(cardW, viewH)
            view:SetMouseInputEnabled(false)
            view:SetModel(opts.model)
            view:SetAmbientLight(Color(120, 120, 124))

            local cam = opts.camera
            if cam then
                view:SetFOV(cam.fov)
                view:SetCamPos(Vector(cam.dist, 0, cam.z))
                view:SetLookAt(Vector(0, 0, cam.z))
            else
                view:SetFOV(40) -- accessories are framed from their own bounds in LayoutEntity
            end

            function view:PreDrawModel(ent)
                local acc = opts.accessory
                if acc and acc.bSetColor then
                    local c = acc.vecColorOveride or (lply.GetPlayerColor and lply:GetPlayerColor() or lply:GetNWVector("PlayerColor", Vector(1, 1, 1)))
                    render.SetColorModulation(c[1], c[2], c[3])
                end
                return true -- DModelPanel skips drawing the model unless this returns true
            end

            function view:PostDrawModel(ent)
                if opts.accessory and opts.accessory.bSetColor then
                    render.SetColorModulation(1, 1, 1)
                end
            end

            function view:LayoutEntity(ent)
                if not self.Prepared then
                    self.Prepared = true
                    if opts.modelData then
                        for _, name in ipairs({"idle_suitcase", "idle_all_01", "reference"}) do
                            local seq = ent:LookupSequence(name)
                            if seq and seq >= 0 then
                                ent:SetSequence(seq)
                                break
                            end
                        end
                        ent.GetPlayerColor = function()
                            return view.PlayerVec or Vector(1, 1, 1)
                        end
                    end
                end

                ent:SetAngles(opts.accessory and angle_zero or Angle(0, (opts.baseYaw or 0) + card.Spin, 0))

                if opts.modelData then
                    ent:SetCycle(0)
                    ApplyCardLook(self, ent, opts.modelData, opts.overrides)
                elseif opts.accessory then
                    local acc = opts.accessory
                    local skin = acc.skin
                    if isfunction(skin) then
                        local ok, value = pcall(skin, lply)
                        skin = ok and value or 0
                    end
                    ent:SetSkin(skin or 0)
                    ent:SetBodyGroups(acc.bodygroups or "")
                    if acc.SubMat then
                        ent:SetSubMaterial(0, acc.SubMat)
                    end

                    -- frame the whole model from its own bounds and orbit around it
                    if not self.AccessoryFrame then
                        local mn, mx = ent:GetRenderBounds()
                        self.AccessoryFrame = {center = (mn + mx) * 0.5, dist = math.max(mn:Distance(mx), 4) * 1.05}
                    end
                    local frame = self.AccessoryFrame
                    local yaw = math.rad(card.Spin)
                    self:SetLookAt(frame.center)
                    self:SetCamPos(frame.center + Vector(math.cos(yaw) * frame.dist, math.sin(yaw) * frame.dist, frame.dist * 0.3))
                end
            end
        end

        function card:Think()
            self.HoverLerp = LerpFT(0.2, self.HoverLerp or 0, self:IsHovered() and 1 or 0)
            self.IsActive = opts.isActive and opts.isActive() or false
            self.ActiveLerp = LerpFT(0.2, self.ActiveLerp or 0, self.IsActive and 1 or 0)
            -- hovering a CS:GO glove tries it on the character in the preview
            if opts.glove and self:IsHovered() then
                hg.StaticGlovePreview = opts.glove
                hg.StaticGlovePreviewCard = self
            end
            self.Spin = self.Spin + RealFrameTime() * (opts.accessory and 28 or 40) * (opts.accessory and 1 or self.HoverLerp)
            if IsValid(view) then
                local visible = CardIsInView(self, scroll)
                if view:IsVisible() != visible then
                    view:SetVisible(visible)
                end
            end
        end

        function card:Paint(w, h)
            local hl = self.HoverLerp or 0
            surface.SetDrawColor(Lerp(hl, 28, 40), Lerp(hl, 30, 42), Lerp(hl, 36, 50), 245)
            surface.DrawRect(0, 0, w, h)
            -- view backdrop
            surface.SetDrawColor(13, 14, 18, 255)
            surface.DrawRect(0, 0, w, viewH)

            if opts.icon then
                local size = math.min(w, viewH) - S(24)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(opts.icon)
                surface.DrawTexturedRect((w - size) / 2, (viewH - size) / 2, size, size)
            end

            if opts.isNone then
                local m = S(70)
                surface.SetDrawColor(120, 125, 140, 255)
                surface.DrawLine(m, m, w - m, viewH - m)
                surface.DrawLine(w - m, m, m, viewH - m)
            end

            draw.SimpleText(opts.title, "ZC_AP_Card", S(12), viewH + S(17), ap_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if opts.subtitle and opts.subtitle != "" then
                draw.SimpleText(opts.subtitle, "ZC_AP_Tiny", S(12), viewH + S(40), ap_text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end

        function card:PaintOver(w, h)
            local a = self.ActiveLerp or 0
            if a > 0.01 then
                surface.SetDrawColor(255, 255, 255, 255 * a)
                surface.DrawRect(0, 0, w, S(3))
                surface.DrawRect(0, h - S(3), w, S(3))
                surface.DrawRect(0, 0, S(3), h)
                surface.DrawRect(w - S(3), 0, S(3), h)
                surface.DrawRect(w - S(24), S(10), S(12), S(12))
            elseif (self.HoverLerp or 0) > 0.01 then
                surface.SetDrawColor(255, 255, 255, 90 * self.HoverLerp)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
        end

        return card
    end

    local function OpenSelectorPanel(strSection, strTitle, strHint, fnBuild)
        if not IsValid(selectorPanel) or not IsValid(selectorContent) then return end
        if currentSelectorSection == strSection and selectorPanel.TargetX == selectorPanel.OpenX then
            currentSelectorSection = nil
            main.ActiveSection = ""
            CloseSelectorPanel()
            return false
        end
        currentSelectorSection = strSection
        main.ActiveSection = strSection
        selectorContent:Clear()
        selectorHeaderTitle:SetText(string.upper(strTitle))
        selectorHeaderTitle:SizeToContents()
        selectorHeaderHint:SetText(strHint or "")
        selectorHeaderHint:SizeToContents()
        local scroll = CreateStyledScrollPanel(selectorContent)
        scroll:Dock(FILL)
        scroll.Paint = function() end
        if fnBuild then
            fnBuild(scroll)
        end
        selectorPanel.TargetX = selectorPanel.OpenX
        return true
    end

    CloseSelectorPanel = function()
        if IsValid(selectorPanel) then
            currentSelectorSection = nil
            selectorPanel.TargetX = selectorPanel.ClosedX
        end
    end

    local function GetClothesValue(key)
        return main.AppearanceTable.AClothes and main.AppearanceTable.AClothes[key] or "normal"
    end

    local function GetAttachmentValue(id)
        local value = main.AppearanceTable.AAttachments and main.AppearanceTable.AAttachments[id]
        return value and value != "" and value or "none"
    end

    local function UpdateAppearance(tbl)
        main.AppearanceTable = table.Copy(tbl or main.AppearanceTable or {})
        main.AppearanceTable.AAttachments = main.AppearanceTable.AAttachments or {"none", "none", "none", "none", "none", "none"}
        main.AppearanceTable.AClothes = main.AppearanceTable.AClothes or {}
        main.AppearanceTable.ABodygroups = main.AppearanceTable.ABodygroups or {}
        main.AppearanceTable.AColor = main.AppearanceTable.AColor or color_white
        local modelData = main:GetCurrentModelData()
        if modelData and modelData.mdl then
            local facemapKey = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[modelData.mdl]
            local facemapSet = facemapKey and hg.Appearance.FacemapsSlots[facemapKey]
            if facemapSet and not facemapSet[main.AppearanceTable.AFacemap] then
                main.AppearanceTable.AFacemap = "Default"
            end
        end
        if IsValid(nameEntry) and nameEntry:GetValue() != (main.AppearanceTable.AName or "") then
            nameEntry:SetText(main.AppearanceTable.AName or "")
        end
        main:SyncSharedPreview()
    end

    local function ApplyAppearance()
        hg.Appearance.CreateAppearanceFile(hg.Appearance.SelectedAppearance:GetString(), main.AppearanceTable)
        net.Start("OnlyGet_Appearance")
            net.WriteTable(main.AppearanceTable)
        net.SendToServer()
        main.SharedPreviewOriginal = table.Copy(main.AppearanceTable)
        savedAppearanceSnapshot = BuildComparableAppearanceTable(main.AppearanceTable)
        surface.PlaySound(SOUND_APPEARANCE_SUCCESS)
    end

    local function HasUnsavedChanges()
        return not AppearanceValueEqual(savedAppearanceSnapshot or {}, BuildComparableAppearanceTable(main.AppearanceTable))
    end

    local function CloseUnsavedPrompt(fnOnClosed)
        if IsValid(unsavedOverlay) then
            if unsavedOverlay.IsClosing then return end
            unsavedOverlay.IsClosing = true
            local overlay = unsavedOverlay
            local box = overlay.BoxPanel
            if IsValid(box) then
                box:MoveTo(box:GetX(), box.TargetY or box:GetY(), appearance_unsaved_fade_out_time, 0, -1)
                box:AlphaTo(0, appearance_unsaved_fade_out_time, 0)
            end
            overlay:AlphaTo(0, appearance_unsaved_fade_out_time, 0, function()
                if IsValid(overlay) then
                    overlay:Remove()
                end
                if fnOnClosed then
                    fnOnClosed()
                end
            end)
        end
        unsavedOverlay = nil
    end

    local function ShowUnsavedPrompt()
        if IsValid(unsavedOverlay) then return end
        unsavedOverlay = vgui.Create("DButton", main)
        unsavedOverlay:SetText("")
        unsavedOverlay:SetCursor("arrow")
        unsavedOverlay:SetSize(main:GetWide(), main:GetTall())
        unsavedOverlay:SetPos(0, 0)
        unsavedOverlay:SetAlpha(0)
        unsavedOverlay:MakePopup()
        unsavedOverlay.Paint = function(this, w, h)
            surface.SetDrawColor(0, 0, 0, 170)
            surface.DrawRect(0, 0, w, h)
        end

        local box = vgui.Create("DPanel", unsavedOverlay)
        box:SetSize(MenuUnit(appearance_unsaved_box_width), MenuUnit(appearance_unsaved_box_height))
        box:Center()
        box.TargetY = box:GetY()
        box:SetY(box.TargetY + MenuUnit(appearance_unsaved_box_rise))
        box:SetAlpha(0)
        box.Paint = function(this, w, h)
            surface.SetDrawColor(0, 0, 0, 245)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(appearance_unsaved_message, "ZCity_Menu_Settings_Small", w * 0.5, MenuUnit(42), appearance_color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        unsavedOverlay.BoxPanel = box
        unsavedOverlay:AlphaTo(255, appearance_unsaved_fade_in_time, 0)
        box:MoveTo(box:GetX(), box.TargetY, appearance_unsaved_fade_in_time, 0, -1)
        box:AlphaTo(255, appearance_unsaved_fade_in_time, 0)

        local saveBtn = vgui.Create("DButton", box)
        saveBtn:SetSize(MenuUnit(appearance_unsaved_button_width), MenuUnit(appearance_unsaved_button_height))
        saveBtn:SetPos(MenuUnit(35), box:GetTall() - MenuUnit(56))
        saveBtn:SetText("")
        saveBtn.Paint = function(this, w, h)
            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("Save", "ZCity_Menu_Settings_Small", w * 0.5, h * 0.5, appearance_color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        saveBtn.DoClick = function()
            ApplyAppearance()
            CloseUnsavedPrompt(function()
                main:ReturnToMenu()
            end)
        end

        local dontSaveBtn = vgui.Create("DButton", box)
        dontSaveBtn:SetSize(MenuUnit(appearance_unsaved_button_width), MenuUnit(appearance_unsaved_button_height))
        dontSaveBtn:SetPos(box:GetWide() - MenuUnit(35) - dontSaveBtn:GetWide(), box:GetTall() - MenuUnit(56))
        dontSaveBtn:SetText("")
        dontSaveBtn.Paint = function(this, w, h)
            surface.SetDrawColor(0, 0, 0, 255)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText("Dont Save", "ZCity_Menu_Settings_Small", w * 0.5, h * 0.5, appearance_color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        dontSaveBtn.DoClick = function()
            CloseUnsavedPrompt(function()
                main:ReturnToMenu()
            end)
        end
    end

    local function TryExitAppearance()
        CloseAllAccessoryMenus()
        if HasUnsavedChanges() then
            ShowUnsavedPrompt()
            return
        end
        main:ReturnToMenu()
    end

    local function SaveCurrentPreset()
        Derma_StringRequest("Save Preset", "Preset name", main.AppearanceTable.AName or "", function(presetName)
            if not isstring(presetName) then return end
            presetName = string.Trim(presetName)
            if presetName == "" or #presetName < 2 then
                surface.PlaySound("buttons/button10.wav")
                notification.AddLegacy("Enter a preset name (min 2 chars)", NOTIFY_ERROR, 3)
                return
            end
            presetName = string.gsub(presetName, "[^%w%s_-]", "")
            SavePreset(presetName, main.AppearanceTable)
            surface.PlaySound("buttons/button14.wav")
            notification.AddLegacy("Preset '" .. presetName .. "' saved!", NOTIFY_GENERIC, 3)
        end)
    end

    local function LoadCurrentPreset()
        local presetList = GetPresetList()
        if #presetList == 0 then
            surface.PlaySound("buttons/button10.wav")
            notification.AddLegacy("No presets saved yet!", NOTIFY_ERROR, 3)
            return
        end
        local presetMenu = vgui.Create("DFrame")
        presetMenu:SetTitle("Load Preset")
        presetMenu:SetSize(ScreenScale(120), ScreenScale(100))
        presetMenu:Center()
        presetMenu:MakePopup()
        presetMenu:SetDraggable(false)
        function presetMenu:Paint(w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(20, 20, 28, 250))
            surface.SetDrawColor(colors.presetBorder)
            surface.DrawOutlinedRect(0, 0, w, h, 2)
            draw.RoundedBoxEx(8, 0, 0, w, ScreenScale(12), colors.secondary, true, true, false, false)
        end
        local scroll = CreateStyledScrollPanel(presetMenu)
        scroll:Dock(FILL)
        scroll:DockMargin(ScreenScale(2), ScreenScale(2), ScreenScale(2), ScreenScale(2))
        for _, presetName in SortedPairs(presetList) do
            local presetBtn = vgui.Create("DButton", scroll)
            presetBtn:Dock(TOP)
            presetBtn:DockMargin(2, 2, 2, 0)
            presetBtn:SetTall(ScreenScale(14))
            presetBtn:SetFont("ZCity_Menu_Tiny")
            presetBtn:SetText(presetName)
            presetBtn:SetTextColor(colors.mainText)
            function presetBtn:Paint(w, h)
                local bgCol = self:IsHovered() and colors.presetHover or colors.presetBG
                draw.RoundedBox(4, 0, 0, w, h, bgCol)
                surface.SetDrawColor(colors.scrollbarBorder)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
            function presetBtn:DoClick()
                local loadedPreset = LoadPreset(presetName)
                if loadedPreset then
                    UpdateAppearance(loadedPreset)
                    surface.PlaySound("buttons/button14.wav")
                    notification.AddLegacy("Preset '" .. presetName .. "' loaded!", NOTIFY_GENERIC, 3)
                else
                    surface.PlaySound("buttons/button10.wav")
                    notification.AddLegacy("Failed to load preset!", NOTIFY_ERROR, 3)
                end
                presetMenu:Close()
            end
            function presetBtn:DoRightClick()
                local confirmMenu = DermaMenu()
                confirmMenu:AddOption("Delete '" .. presetName .. "'", function()
                    DeletePreset(presetName)
                    surface.PlaySound("buttons/button15.wav")
                    notification.AddLegacy("Preset deleted!", NOTIFY_HINT, 2)
                    presetBtn:Remove()
                end):SetIcon("icon16/cross.png")
                confirmMenu:Open()
            end
        end
    end

    local function DeleteCurrentPreset()
        Derma_StringRequest("Delete Preset", "Preset name", main.AppearanceTable.AName or "", function(presetName)
            if not isstring(presetName) then return end
            presetName = string.Trim(presetName)
            if presetName == "" then
                surface.PlaySound("buttons/button10.wav")
                notification.AddLegacy("Enter preset name to delete", NOTIFY_ERROR, 3)
                return
            end
            if DeletePreset(presetName) then
                surface.PlaySound("buttons/button15.wav")
                notification.AddLegacy("Preset '" .. presetName .. "' deleted!", NOTIFY_HINT, 3)
            else
                surface.PlaySound("buttons/button10.wav")
                notification.AddLegacy("Preset not found!", NOTIFY_ERROR, 3)
            end
        end)
    end

    local function FirstLine(str)
        return str and string.match(str, "^[^\n]*") or nil
    end

    local function OpenModelMenu()
        local models = {}
        for k, v in pairs(APmodule.PlayerModels[1] or {}) do
            models[k] = v
        end
        for k, v in pairs(APmodule.PlayerModels[2] or {}) do
            models[k] = v
        end
        OpenSelectorPanel("Model", "Model", "Select a player model", function(scroll)
            local grid = CreateCardGrid(scroll)
            for k, v in SortedPairs(models) do
                AddSelectorCard(grid, scroll, {
                    title = k,
                    subtitle = v.sex and "Female model" or "Male model",
                    model = v.mdl,
                    camera = CARD_VIEWS.body,
                    modelData = v,
                    overrides = {},
                    isActive = function()
                        return main.AppearanceTable.AModel == k
                    end,
                    onClick = function()
                        main.AppearanceTable.AModel = k
                        UpdateAppearance(main.AppearanceTable)
                        surface.PlaySound("player/weapon_draw_0" .. math.random(2, 5) .. ".wav")
                    end
                })
            end
        end)
    end

    -- two big outlined tabs at the top of a section (Hat 1 | Hat 2, Default | CS:GO ...).
    -- buildGrid(activeIndex) is called whenever a tab is picked and must return the new grid panel.
    local function BuildTabbedSection(scroll, labels, buildGrid)
        local active = 1

        local tabs = vgui.Create("DPanel", scroll)
        tabs:Dock(TOP)
        tabs:SetTall(S(62))
        tabs:DockMargin(S(14), S(10), S(8), 0)
        tabs.Paint = function() end
        tabs.PerformLayout = function(this, w, h)
            local gap = S(10)
            local tabW = math.floor((w - gap * (#labels - 1)) / #labels)
            for index, child in ipairs(this:GetChildren()) do
                child:SetSize(tabW, h)
                child:SetPos((index - 1) * (tabW + gap), 0)
            end
        end

        local grid
        local function rebuild()
            if IsValid(grid) then grid:Remove() end
            grid = buildGrid(active)
        end

        for index, label in ipairs(labels) do
            local tab = vgui.Create("DButton", tabs)
            tab:SetText("")
            tab:SetCursor("hand")
            tab.HoverLerp = 0
            tab.Think = function(this)
                this.HoverLerp = LerpFT(0.2, this.HoverLerp or 0, this:IsHovered() and 1 or 0)
            end
            tab.OnCursorEntered = function()
                surface.PlaySound("ui/rem_hover.wav")
            end
            tab.DoClick = function()
                if active == index then return end
                surface.PlaySound("ui/rem_select.wav")
                active = index
                rebuild()
            end
            tab.Paint = function(this, w, h)
                local selected = active == index
                surface.SetDrawColor(selected and 18 or 8, selected and 19 or 9, selected and 24 or 12, 255)
                surface.DrawRect(0, 0, w, h)
                local a = selected and 255 or Lerp(this.HoverLerp, 110, 200)
                surface.SetDrawColor(255, 255, 255, a)
                local border = selected and S(3) or S(2)
                surface.DrawRect(0, 0, w, border)
                surface.DrawRect(0, h - border, w, border)
                surface.DrawRect(0, 0, border, h)
                surface.DrawRect(w - border, 0, border, h)
                local v = selected and 255 or Lerp(this.HoverLerp, 170, 230)
                draw.SimpleText(label, "ZC_AP_Tab", w / 2, h / 2, Color(v, v, v), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        tabs:InvalidateLayout(true)
        rebuild()
    end

    -- slotIDs: the attachment slots this section edits, one per tab (e.g. {1, 4} for Hat 1 / Hat 2)
    local function OpenAccessorySlot(slotIDs, title, placements)
        OpenSelectorPanel(title, title, "Select " .. title, function(scroll)
            local labels = {}
            for index = 1, #slotIDs do
                labels[index] = title .. " " .. index
            end

            BuildTabbedSection(scroll, labels, function(active)
                local slotID = slotIDs[active]
                local grid = CreateCardGrid(scroll)

                AddSelectorCard(grid, scroll, {
                    title = "None",
                    subtitle = "Clear slot",
                    isNone = true,
                    isActive = function()
                        return GetAttachmentValue(slotID) == "none"
                    end,
                    onClick = function()
                        main.AppearanceTable.AAttachments[slotID] = "none"
                        main:SyncSharedPreview()
                        surface.PlaySound("player/clothes_generic_foley_0" .. math.random(5) .. ".wav")
                    end
                })

                for k, v in SortedPairs(hg.Accessories or {}) do
                    if not placements[v.placement] then continue end
                    if not (v.model or v.femmodel) then continue end
                    if not lply:PS_HasItem(k) and v.bPointShop and not hg.Appearance.GetAccessToAll(lply) then continue end
                    AddSelectorCard(grid, scroll, {
                        title = string.NiceName(v.name or k),
                        subtitle = v.placement or title,
                        model = v.model or v.femmodel,
                        accessory = v,
                        isActive = function()
                            return GetAttachmentValue(slotID) == k
                        end,
                        onClick = function()
                            -- the same item can't be worn in both slots: picking it moves it here
                            for other = 1, ATTACHMENT_SLOTS do
                                if other ~= slotID and main.AppearanceTable.AAttachments[other] == k then
                                    main.AppearanceTable.AAttachments[other] = "none"
                                end
                            end
                            main.AppearanceTable.AAttachments[slotID] = k
                            main:SyncSharedPreview()
                            surface.PlaySound("player/clothes_generic_foley_0" .. math.random(5) .. ".wav")
                        end
                    })
                end

                return grid
            end)
        end)
    end

    local function OpenClothesMenu(key, title, includeColor)
        local modelData = main:GetCurrentModelData()
        if not modelData then return end
        local camera = key == "main" and CARD_VIEWS.torso or (key == "pants" and CARD_VIEWS.legs or CARD_VIEWS.boots)
        OpenSelectorPanel(title, title, "Select " .. title, function(scroll)
            if includeColor then
                if not IsColor(main.AppearanceTable.AColor) or (main.AppearanceTable.AColor.r == 255 and main.AppearanceTable.AColor.g == 0 and main.AppearanceTable.AColor.b == 0) then
                    main.AppearanceTable.AColor = color_white
                end
                local colorSelector = vgui.Create("DColorCombo", scroll)
                colorSelector:Dock(TOP)
                colorSelector:DockMargin(S(14), S(10), S(8), 0)
                function colorSelector:OnValueChanged(clr)
                    main.AppearanceTable.AColor = clr
                    main:SyncSharedPreview()
                end
                colorSelector:SetColor(main.AppearanceTable.AColor)
                colorSelector.Paint = function(this, w, h)
                    surface.SetDrawColor(28, 30, 36, 245)
                    surface.DrawRect(0, 0, w, h)
                    draw.SimpleText("JACKET COLOR", "ZC_AP_Small", S(14), h * 0.5, ap_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    local clr = main.AppearanceTable.AColor or color_white
                    surface.SetDrawColor(clr.r, clr.g, clr.b, 255)
                    surface.DrawRect(w - S(44), S(8), S(28), h - S(16))
                    surface.SetDrawColor(255, 255, 255, 120)
                    surface.DrawOutlinedRect(w - S(44), S(8), S(28), h - S(16), 1)
                end
            end

            local grid = CreateCardGrid(scroll)
            for k, _ in SortedPairs(hg.Appearance.Clothes[modelData.sex and 2 or 1] or {}) do
                local tip = hg.Appearance.ClothesDesc[k] and hg.Appearance.ClothesDesc[k].desc or nil
                AddSelectorCard(grid, scroll, {
                    title = string.NiceName(k),
                    subtitle = FirstLine(tip),
                    tooltip = tip,
                    model = modelData.mdl,
                    camera = camera,
                    modelData = modelData,
                    overrides = {clothesKey = key, clothesVal = k},
                    isActive = function()
                        return GetClothesValue(key) == k
                    end,
                    onClick = function()
                        main.AppearanceTable.AClothes[key] = k
                        main:SyncSharedPreview()
                        surface.PlaySound("player/weapon_draw_0" .. math.random(2, 5) .. ".wav")
                    end
                })
            end
        end)
    end

    -- CS:GO gloves are whatever has "CS:GO" / "CSGO" / "CS GO" in its name (they come from the Clothing+ addon)
    local function IsCsgoGlove(name)
        return CsgoVariant(name) ~= nil or string.find(string.lower(tostring(name)), "cs[%s:_%-%.]*go") ~= nil
    end

    local function OpenGlovesMenu()
        local modelData = main:GetCurrentModelData()
        if not modelData then return end

        OpenSelectorPanel("Gloves", "Gloves", "Select gloves", function(scroll)
            BuildTabbedSection(scroll, {"Default", "CS:GO"}, function(active)
                local csgoOnly = active == 2
                local grid = CreateCardGrid(scroll)
                local gloves = hg.Appearance.Bodygroups["HANDS"] and hg.Appearance.Bodygroups["HANDS"][modelData.sex and 2 or 1] or {}

                for k, v in SortedPairs(gloves) do
                    if IsCsgoGlove(k) ~= csgoOnly then continue end
                    -- locked behind the shop only when the entry actually names a shop item
                    if v["ID"] and v[2] and not lply:PS_HasItem(v["ID"]) and not hg.Appearance.GetAccessToAll(lply) then continue end
                    local variant = csgoOnly and CsgoVariant(k) or nil
                    if variant and ZCGloves.HasModel and not ZCGloves.HasModel(variant.model) then continue end -- glove files not installed
                    AddSelectorCard(grid, scroll, {
                        title = variant and string.gsub(variant.name, "^CS:GO ", "") or (csgoOnly and tostring(k) or string.NiceName(k)),
                        subtitle = variant and variant.label or (csgoOnly and "CS:GO" or "Gloves"),
                        icon = variant and GloveIcon(variant) or nil,
                        glove = variant,
                        model = (not variant) and modelData.mdl or nil,
                        camera = CARD_VIEWS.hands,
                        modelData = (not variant) and modelData or nil,
                        overrides = {bodygroupName = "HANDS", bodygroupVal = k},
                        isActive = function()
                            return (main.AppearanceTable.ABodygroups and main.AppearanceTable.ABodygroups["HANDS"]) == k
                        end,
                        onClick = function()
                            main.AppearanceTable.ABodygroups = main.AppearanceTable.ABodygroups or {}
                            main.AppearanceTable.ABodygroups["HANDS"] = k
                            main:SyncSharedPreview()
                            surface.PlaySound("player/weapon_draw_0" .. math.random(2, 5) .. ".wav")
                        end
                    })
                end

                return grid
            end)
        end)
    end

    local function OpenFacemapMenu()
        local modelData = main:GetCurrentModelData()
        if not modelData then return end
        local facemapKey = hg.Appearance.FacemapsModels and hg.Appearance.FacemapsModels[modelData.mdl]
        local facemapSet = facemapKey and hg.Appearance.FacemapsSlots[facemapKey]
        if not facemapSet then return end
        OpenSelectorPanel("Facemap", "Facemap", "Select facemap", function(scroll)
            local grid = CreateCardGrid(scroll)
            for k, _ in SortedPairs(facemapSet) do
                AddSelectorCard(grid, scroll, {
                    title = k,
                    subtitle = "Face",
                    model = modelData.mdl,
                    camera = CARD_VIEWS.face,
                    modelData = modelData,
                    overrides = {facemap = k},
                    isActive = function()
                        return (main.AppearanceTable.AFacemap or "Default") == k
                    end,
                    onClick = function()
                        main.AppearanceTable.AFacemap = k
                        main:SyncSharedPreview()
                        surface.PlaySound("player/weapon_draw_0" .. math.random(2, 5) .. ".wav")
                    end
                })
            end
        end)
    end

    local function ToggleRotate()
        OpenSelectorPanel("Rotate", "Rotate", "Select silhouette direction", function(scroll)
            AddSelectorTextRow(scroll, "Front", function()
                return not main.PreviewRotated
            end, function()
                main.PreviewRotated = false
                main:SyncSharedPreview()
                surface.PlaySound("pwb2/weapons/iron.wav")
            end)
            AddSelectorTextRow(scroll, "Back", function()
                return main.PreviewRotated
            end, function()
                main.PreviewRotated = true
                main:SyncSharedPreview()
                surface.PlaySound("pwb2/weapons/iron.wav")
            end)
        end)
    end

    local sizeX, sizeY = ScrW(), ScrH()
    local sidebarTop = S(520)
    local sidebarWidth = math.ceil(sidebarTop + SLOPE * sizeY) + 2
    local sidebar = vgui.Create("DPanel", self)
    sidebar:SetSize(sidebarWidth, sizeY)
    sidebar:SetPos(-sidebarWidth, 0)
    sidebar.TargetX = 0
    sidebar.EdgeTop = sidebarTop
    sidebar.SidebarRoot = sidebar
    sidebar.Think = function(this)
        local x, y = this:GetPos()
        local targetX = this.TargetX or x
        local nextX = Lerp(FrameTime() * appearance_panel_slide_speed, x, targetX)
        if math.abs(targetX - nextX) < 1 then
            nextX = targetX
        end
        this:SetPos(math.Round(nextX), y)
    end
    sidebar.Paint = function(this, w, h)
        surface.SetDrawColor(ap_panel)
        DrawSlanted(0, 0, sidebarTop, h)
    end

    local sidebarHeader = vgui.Create("DPanel", sidebar)
    sidebarHeader:Dock(TOP)
    sidebarHeader:SetTall(S(100))
    sidebarHeader.Paint = function(this, w, h)
        draw.SimpleText("APPEARANCE", "ZC_AP_Title", S(36), S(42), ap_text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("How you look.", "ZC_AP_Small", S(36), S(76), ap_text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local mainPanel = vgui.Create("DPanel", self)
    mainPanel:SetSize(sizeX - sidebarWidth, sizeY)
    mainPanel:SetPos(sizeX, 0)
    mainPanel.TargetX = sidebarWidth
    mainPanel.Think = function(this)
        local x, y = this:GetPos()
        local targetX = this.TargetX or x
        local nextX = Lerp(FrameTime() * appearance_panel_slide_speed, x, targetX)
        if math.abs(targetX - nextX) < 1 then
            nextX = targetX
        end
        this:SetPos(math.Round(nextX), y)
    end
    mainPanel.Paint = function() end
    self.AppearancePreviewX = sidebarWidth + MenuUnit(appearance_preview_shift_x)
    self.AppearancePreviewY = MenuUnit(appearance_preview_shift_y)
    self:SyncSharedPreview()

    local header = vgui.Create("DPanel", mainPanel)
    header:Dock(TOP)
    header:SetTall(MenuUnit(appearance_header_height))
    header.Paint = function() end

    local headerTitle = vgui.Create("DLabel", header)
    headerTitle:SetPos(MenuUnit(25), MenuUnit(18))
    headerTitle:SetFont("ZCity_Menu_Settings_Medium")
    headerTitle:SetTextColor(appearance_color_white)
    headerTitle:SetText("YOU")
    headerTitle:SizeToContents()

    local headerHint = vgui.Create("DLabel", header)
    headerHint:SetPos(MenuUnit(25), MenuUnit(45))
    headerHint:SetFont("ZCity_Menu_Settings_Tiny")
    headerHint:SetTextColor(appearance_color_text_dim)
    headerHint:SetText("How you look.")
    headerHint:SizeToContents()

    selectorPanel = vgui.Create("DPanel", mainPanel)
    selectorPanel:SetSize(MenuUnit(appearance_selector_width), mainPanel:GetTall())
    selectorPanel.ClosedX = mainPanel:GetWide()
    selectorPanel.OpenX = mainPanel:GetWide() - selectorPanel:GetWide()
    selectorPanel.TargetX = selectorPanel.ClosedX
    selectorPanel:SetPos(selectorPanel.ClosedX, 0)
    selectorPanel.Paint = function(this, w, h)
        surface.SetDrawColor(17, 18, 23, 246)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawRect(0, 0, S(4), h)
    end
    selectorPanel.Think = function(this)
        local x = this:GetX()
        local targetX = this.TargetX or x
        local nextX = LerpFT(0.18, x, targetX)
        if math.abs(targetX - nextX) < 1 then
            nextX = targetX
        end
        if not main.RestoringToMenu then
            main.SelectorOpenLerp = LerpFT(appearance_name_fade_speed, main.SelectorOpenLerp or 0, targetX == this.OpenX and 1 or 0)
            if IsValid(previewNameLabel) then
                previewNameLabel:SetAlpha(math.Round(255 * (1 - (main.SelectorOpenLerp or 0))))
            end
            if IsValid(nameEntry) then
                nameEntry:SetAlpha(math.Round(255 * (1 - (main.SelectorOpenLerp or 0))))
                nameEntry:SetMouseInputEnabled((main.SelectorOpenLerp or 0) < 0.05)
            end
            if IsValid(main.SharedPreviewHolder) then
                main.SharedPreviewHolder.TargetX = (main.AppearancePreviewX or main.SharedPreviewHolder.TargetX or main.SharedPreviewHolder:GetX()) - math.floor((main.PreviewSelectorShiftX or 0) * (main.SelectorOpenLerp or 0))
                main.SharedPreviewHolder.TargetY = main.AppearancePreviewY or main.SharedPreviewHolder.TargetY or main.SharedPreviewHolder:GetY()
            end
        end
        this:SetPos(math.Round(nextX), 0)
    end

    local selectorHeader = vgui.Create("DPanel", selectorPanel)
    selectorHeader:Dock(TOP)
    selectorHeader:SetTall(MenuUnit(appearance_header_height))
    selectorHeader.Paint = function(this, w, h)
        surface.SetDrawColor(255, 255, 255, 40)
        surface.DrawRect(S(4), h - MenuUnit(1), w - S(4), MenuUnit(1))
    end

    selectorHeaderTitle = vgui.Create("DLabel", selectorHeader)
    selectorHeaderTitle:SetPos(MenuUnit(18), MenuUnit(18))
    selectorHeaderTitle:SetFont("ZCity_Menu_Settings_Small")
    selectorHeaderTitle:SetTextColor(appearance_color_white)
    selectorHeaderTitle:SetText("")
    selectorHeaderTitle:SizeToContents()

    selectorHeaderHint = vgui.Create("DLabel", selectorHeader)
    selectorHeaderHint:SetPos(MenuUnit(18), MenuUnit(45))
    selectorHeaderHint:SetFont("ZCity_Menu_Settings_Tiny")
    selectorHeaderHint:SetTextColor(appearance_color_text_dim)
    selectorHeaderHint:SetText("")
    selectorHeaderHint:SizeToContents()

    selectorContent = vgui.Create("DPanel", selectorPanel)
    selectorContent:Dock(FILL)
    selectorContent:DockMargin(0, 0, 0, MenuUnit(8))
    selectorContent.Paint = function() end

    previewNameLabel = vgui.Create("DLabel", mainPanel)
    previewNameLabel:SetFont("ZCity_Menu_Settings_Tiny")
    previewNameLabel:SetTextColor(appearance_color_text_dim)
    previewNameLabel:SetText("NAME")
    previewNameLabel:SizeToContents()
    previewNameLabel:SetPos(self.AppearancePreviewX - sidebarWidth, MenuUnit(86))

    nameEntry = vgui.Create("DTextEntry", mainPanel)
    nameEntry:SetSize(MenuUnit(appearance_name_width), MenuUnit(28))
    nameEntry:SetPos(self.AppearancePreviewX - sidebarWidth - MenuUnit(8), MenuUnit(102))
    nameEntry:SetFont("ZCity_Menu_Settings_Small")
    nameEntry:SetText(main.AppearanceTable.AName or "")
    nameEntry:SetUpdateOnType(true)
    nameEntry:SetContentAlignment(5)
    nameEntry.Paint = function(this, w, h)
        surface.SetDrawColor(20, 20, 20, 240)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(appearance_color_white.r, appearance_color_white.g, appearance_color_white.b, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        this:DrawTextEntryText(color_white, Color(120, 130, 180), color_white)
    end
    function nameEntry:OnValueChange(val)
        main.AppearanceTable.AName = val
        main:SyncSharedPreview()
    end

    savedAppearanceSnapshot = BuildComparableAppearanceTable(main.AppearanceTable)

    CreateAppearanceTextButton(sidebar, "Model", function() OpenModelMenu() end, function() return main.ActiveSection == "Model" end)
    local HAT, FACE, BODY = {head = true, ears = true}, {face = true}, {torso = true, spine = true}
    CreateAppearanceTextButton(sidebar, "Hat", function() OpenAccessorySlot({1, 4}, "Hat", HAT) end, function() return main.ActiveSection == "Hat" end)
    CreateAppearanceTextButton(sidebar, "Face", function() OpenAccessorySlot({2, 5}, "Face", FACE) end, function() return main.ActiveSection == "Face" end)
    CreateAppearanceTextButton(sidebar, "Body", function() OpenAccessorySlot({3, 6}, "Body", BODY) end, function() return main.ActiveSection == "Body" end)
    CreateAppearanceTextButton(sidebar, "Jacket", function() OpenClothesMenu("main", "Jacket", true) end, function() return main.ActiveSection == "Jacket" end)
    CreateAppearanceTextButton(sidebar, "Pants", function() OpenClothesMenu("pants", "Pants") end, function() return main.ActiveSection == "Pants" end)
    CreateAppearanceTextButton(sidebar, "Boots", function() OpenClothesMenu("boots", "Boots") end, function() return main.ActiveSection == "Boots" end)
    CreateAppearanceTextButton(sidebar, "Gloves", function() OpenGlovesMenu() end, function() return main.ActiveSection == "Gloves" end)
    CreateAppearanceTextButton(sidebar, "Facemap", function() OpenFacemapMenu() end, function() return main.ActiveSection == "Facemap" end)

    -- bottom-docked: Return sits lowest, the action bars stack above it
    local returnBtn = CreateAppearanceTextButton(sidebar, "Return", function() TryExitAppearance() end)
    returnBtn:Dock(BOTTOM)
    returnBtn:DockMargin(S(36), S(5), 0, S(24))

    local lowerActions = vgui.Create("DPanel", sidebar)
    lowerActions:Dock(BOTTOM)
    lowerActions:DockMargin(0, 0, 0, S(14))
    lowerActions:SetTall(S(45) * 5)
    lowerActions.SidebarRoot = sidebar
    lowerActions.Paint = function() end

    CreateAppearanceTextButton(lowerActions, "Rotate", function() ToggleRotate() end, function() return main.ActiveSection == "Rotate" end)
    CreateAppearanceTextButton(lowerActions, "Apply", function() main.ActiveSection = "Apply" CloseSelectorPanel() ApplyAppearance() end, function() return main.ActiveSection == "Apply" end)
    CreateAppearanceTextButton(lowerActions, "Save Preset", function() main.ActiveSection = "Save Preset" CloseSelectorPanel() SaveCurrentPreset() end, function() return main.ActiveSection == "Save Preset" end)
    CreateAppearanceTextButton(lowerActions, "Load Preset", function() main.ActiveSection = "Load Preset" CloseSelectorPanel() LoadCurrentPreset() end, function() return main.ActiveSection == "Load Preset" end)
    CreateAppearanceTextButton(lowerActions, "Delete Preset", function() main.ActiveSection = "Delete Preset" CloseSelectorPanel() DeleteCurrentPreset() end, function() return main.ActiveSection == "Delete Preset" end)

    function self:Close()
        TryExitAppearance()
    end
    self:CallbackAppearance()
end

vgui.Register( "Static_AppearanceMenu", PANEL, "ZFrame")

concommand.Add("hg_static_appearance_menu",function()
    print('use esc menu')
end)

function hg.StaticApperanceMenu(ParentPanel)
    if hg.Appearance.PrecacheModels then
        hg.Appearance.PrecacheModels()
    end

    hg.PointShop:SendNET( "SendPointShopVars", nil, function( data )
        if IsValid(StaticAppearancePanel) then
            StaticAppearancePanel:Close()
        end
        StaticAppearancePanel = vgui.Create("Static_AppearanceMenu",ParentPanel)
        StaticAppearancePanel:SetSize(ParentPanel:GetWide(),ParentPanel:GetTall())
        StaticAppearancePanel:SetPos(0,0)
    end)
    
end

-- Anything that still asks for the old name gets this menu too (the esc menu itself calls hg.StaticApperanceMenu,
-- so another addon replacing hg.CreateApperanceMenu later cannot take the menu over).
hg.CreateApperanceMenu = hg.StaticApperanceMenu


-- console helper: prints every glove name the menu can see (use it if CS:GO gloves are missing from the menu)
concommand.Add("static_list_gloves", function()
    local hands = hg.Appearance and hg.Appearance.Bodygroups and hg.Appearance.Bodygroups["HANDS"]
    if not hands then print("[Static] no HANDS bodygroup table") return end
    for sex, list in pairs(hands) do
        print("[Static] gloves for sex " .. tostring(sex) .. ":")
        for name, entry in SortedPairs(list) do
            if istable(entry) then
                print(string.format("   %s   [1]=%s [2]=%s ID=%s", tostring(name), tostring(entry[1]), tostring(entry[2]), tostring(entry["ID"])))
            else
                print("   " .. tostring(name) .. "   " .. tostring(entry))
            end
        end
    end
end)
