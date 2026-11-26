hg = hg or {}
hg.WeaponSelector = hg.WeaponSelector or {}
local WS = hg.WeaponSelector

function WS.GetPrintName( self )
	local class = self:GetClass()
	local phrase = language.GetPhrase(class)
	return phrase ~= class and phrase or self:GetPrintName()
end

WS.Show = 0
WS.Transparent = 0
WS.LastSelectedSlot = 0
WS.LastSelectedSlotPos = 0

WS.SelectedSlot = 0
WS.SelectedSlotPos = 0

WS.HighlightProgress = WS.HighlightProgress or {}
WS.StackProgress = WS.StackProgress or {}
WS.StackState = WS.StackState or {}

-- Weapon wheel (bottom right corner): three icons on a small arc, no background.
-- The selected weapon sits up-left of the corner, the next one above it and the previous one below it.
-- Sizes are fractions of the screen height.
local WHEEL_RING = 0.115           -- distance of the icons from the corner pivot
local WHEEL_ICON_W = 0.10        -- width of the selected icon
local WHEEL_INSET = -0.25           -- pivot sits this far past the corner (x ring), which pushes the two side icons partly off screen
local WHEEL_SHADOW_ALPHA = 150    -- darkness of the soft shadow behind the icons (0 = none)
local WHEEL_SELECT_ANGLE = 225     -- screen angle of the selected weapon (225 = up-left)
local WHEEL_STEP = 30              -- degrees between neighbouring weapons
local WHEEL_TURN_SPEED = 0.18      -- how fast it turns when you switch
local WHEEL_SIDE_ALPHA = 0.45      -- brightness of the neighbouring icons

function WS.DrawText(text, font, posX, posY, color, textAlign)
    local alpha = color.a or 255
    draw.DrawText( text, font, posX + 2, posY + 2, ColorAlpha(color_black, alpha), textAlign )
    draw.DrawText( text, font, posX, posY, ColorAlpha(color, alpha), textAlign )
end

function WS.GetSelectedWeapon()
    if not IsValid( LocalPlayer() ) or not LocalPlayer():Alive() then return end
    local Weapons = WS.GetWeaponTable( LocalPlayer() )
    return Weapons[WS.SelectedSlot] and Weapons[WS.SelectedSlot][WS.SelectedSlotPos] or Weapons[WS.LastSelectedSlot][WS.LastSelectedSlotPos] or Weapons[0][0]
end

function WS.GetWeaponTable( ply )
    if not IsValid( ply ) or not ply:Alive() then return end
    local WeaponsGet = ply:GetWeapons()
    local FormatedTable = {
        [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {},
    }

    table.sort(WeaponsGet, function(a, b) return (a.SlotPos or 0) > (b.SlotPos or 0) end)

    for k,wep in ipairs(WeaponsGet) do
        local tTbl = FormatedTable[wep.Slot or 0]
        local iMinPos = math.min( (wep.SlotPos and wep.SlotPos) or 1, ((#tTbl or 0) + 1)) - 1
        local iPos = tTbl[ iMinPos ] and #tTbl + 1 or iMinPos
        tTbl[ iPos ] = wep
    end
    return FormatedTable
end

local function WS_DrawWeaponIcon(wep, x, y, w, h, alpha, angle)
    if h <= 0 then return end

    local drawX = x
    local drawY = y
    local drawW = w
    local drawH = h
    local useFilter = false

    surface.SetDrawColor(255, 255, 255, alpha)

    if wep.IconOverride and wep.IconOverride ~= "" and wep.WepSelectIcon2 then
        useFilter = true
        surface.SetMaterial(wep.WepSelectIcon2)
        if wep.WepSelectIcon2box then
            drawW = w / 1.95
            drawH = drawW
            drawX = x + w * 0.5 - drawW * 0.5
            drawY = y
        else
            drawW = w
            drawH = w / 2
        end
    elseif isnumber(wep.WepSelectIcon) then
        surface.SetTexture(wep.WepSelectIcon)
        drawX = x + 10
        drawY = y + 10
        drawW = math.max(w - 20, 1)
        drawH = drawW / 2
    elseif wep.WepSelectIcon then
        surface.SetMaterial(wep.WepSelectIcon)
        drawX = x + 10
        drawY = y + 10
        drawW = math.max(w - 20, 1)
        drawH = drawW / 2
    elseif wep.DrawWeaponSelection then
        wep:DrawWeaponSelection(x, y, w, h, alpha)
        return
    else
        return
    end

    if useFilter then
        render.PushFilterMag(TEXFILTER.ANISOTROPIC)
        render.PushFilterMin(TEXFILTER.ANISOTROPIC)
    end

    surface.DrawTexturedRectRotated(drawX + drawW * 0.5, drawY + drawH * 0.5, drawW, drawH, angle)

    if useFilter then
        render.PopFilterMin()
        render.PopFilterMag()
    end
end

-- ---------------------------------------------------------------------------
-- Weapon wheel
-- ---------------------------------------------------------------------------
-- every weapon the player owns, in slot order
local function WS_BuildWheelList(ply)
    local list = {}
    local weapons = WS.GetWeaponTable(ply)
    if not weapons then return list end

    for slot = 0, 5 do
        local slotTbl = weapons[slot]
        if slotTbl then
            for pos = 0, #slotTbl do
                if IsValid(slotTbl[pos]) then
                    list[#list + 1] = {wep = slotTbl[pos], slot = slot}
                end
            end
        end
    end

    return list
end

function WS.WeaponSelectorDraw( ply )
    if not IsValid( ply ) or not ply:Alive() or GetGlobalBool("RadialInventory", false) then return end

    local isOpen = WS.Show >= CurTime()
    if not isOpen then
        WS.SelectedSlot = WS.LastSelectedSlot
        WS.SelectedSlotPos = -1
    end

    local list = WS_BuildWheelList(ply)
    local count = #list
    if count < 1 then return end

    -- which weapon is the wheel pointing at?
    local selected = isOpen and WS.GetSelectedWeapon() or ply:GetActiveWeapon()
    local index = 1
    for i, entry in ipairs(list) do
        if entry.wep == selected then
            index = i
            break
        end
    end

    -- keep a continuous position so the wheel turns the short way round
    if WS.WheelCount ~= count or WS.WheelTarget == nil then
        WS.WheelTarget = index
        WS.WheelPos = index
    elseif WS.WheelIndex ~= index then
        local delta = index - WS.WheelIndex
        if delta > count / 2 then delta = delta - count end
        if delta < -count / 2 then delta = delta + count end
        WS.WheelTarget = WS.WheelTarget + delta
    end
    WS.WheelIndex = index
    WS.WheelCount = count
    WS.WheelPos = LerpFT(WHEEL_TURN_SPEED, WS.WheelPos or WS.WheelTarget, WS.WheelTarget)

    local sw, sh = ScrW(), ScrH()
    local ring = sh * WHEEL_RING
    local cx = sw - ring * WHEEL_INSET
    local cy = sh - ring * WHEEL_INSET
    local baseAlpha = 1

    -- soft shadow behind the icons that fades out just past the selected weapon
    if WHEEL_SHADOW_ALPHA > 0 then
        local reach = ring + sh * WHEEL_ICON_W * 0.55
        local layers = 12
        draw.NoTexture()
        for layer = 1, layers do
            local t = layer / layers
            local poly = {}
            local r = reach * t
            for k = 0, 35 do
                local a = math.rad(k * 10)
                poly[#poly + 1] = {x = cx + math.cos(a) * r, y = cy + math.sin(a) * r}
            end
            surface.SetDrawColor(0, 0, 0, WHEEL_SHADOW_ALPHA / layers * 0.9)
            surface.DrawPoly(poly)
        end
    end

    for i, entry in ipairs(list) do
        local offset = ((i - WS.WheelPos + count / 2) % count) - count / 2
        local dist = math.abs(offset)
        if dist >= 1.6 then continue end

        -- 1 for the selected weapon, 0 one step away; fades out completely by 1.6 steps
        local near = 1 - math.min(dist, 1)
        local fade = dist <= 1 and 1 or 1 - (dist - 1) / 0.6
        local alpha = 255 * baseAlpha * fade * Lerp(near, WHEEL_SIDE_ALPHA, 1)

        local rad = math.rad(WHEEL_SELECT_ANGLE + offset * WHEEL_STEP)
        local iconW = sh * WHEEL_ICON_W * Lerp(near, 0.72, 1)
        local iconH = iconW * 0.5
        local iconX = cx + math.cos(rad) * ring - iconW * 0.5
        local iconY = cy + math.sin(rad) * ring - iconH * 0.5

        WS_DrawWeaponIcon(entry.wep, iconX, iconY, iconW, iconH, alpha, 0)
        WS.DrawText(entry.slot + 1, "HomigradFontSmall", iconX - 6, iconY + iconH * 0.5 - 8, ColorAlpha(color_white, alpha), TEXT_ALIGN_RIGHT)
    end
end

-- Changer
local tAcceptKeys = {
    ["slot1"] = 1,
    ["slot2"] = 2,
    ["slot3"] = 3,
    ["slot4"] = 4,
    ["slot5"] = 5,
    ["slot6"] = 6,
}

--[[
    Table:
        [1]	=	Weapon [52][weapon_hands_sh]
        [2]	=	Weapon [117][weapon_bigconsumable]
        [3]	=	Weapon [121][weapon_handcuffs_key]
        [4]	=	Weapon [122][weapon_handcuffs]
        [5]	=	Weapon [123][weapon_traitor_poison1]
        [6]	=	Weapon [124][weapon_traitor_suit]
        [7]	=	Weapon [125][weapon_matches]

    TableFormated:
    [0]:
		[0]	=	Weapon [126][weapon_physgun]
		[1]	=	Weapon [52][weapon_hands_sh]
    [1]:
    [2]:
    [3]:
		[1]	=	Weapon [117][weapon_bigconsumable]
		[2]	=	Weapon [121][weapon_handcuffs_key]
		[3]	=	Weapon [122][weapon_handcuffs]
		[4]	=	Weapon [123][weapon_traitor_poison1]
		[5]	=	Weapon [125][weapon_matches]
    [4]:
    [5]:
		[1]	=	Weapon [124][weapon_traitor_suit]
--]]

local function GetUpper(Weapons)
    if #LocalPlayer():GetWeapons() < 1 then return end
    WS.SelectedSlot = WS.SelectedSlot < 0 and #Weapons or WS.SelectedSlot - 1
    WS.SelectedSlotPos = Weapons[WS.SelectedSlot] and #Weapons[WS.SelectedSlot] or 0

    --print(WS.SelectedSlot, WS.SelectedSlotPos)

    if Weapons[WS.SelectedSlot] == nil or Weapons[WS.SelectedSlot][WS.SelectedSlotPos] == nil then
        GetUpper(Weapons)
    end
end

local function GetDown(Weapons)
    if #LocalPlayer():GetWeapons() < 1 then return end
    WS.SelectedSlot = WS.SelectedSlot > #Weapons and 0 or WS.SelectedSlot + 1
    WS.SelectedSlotPos = 0

    --print(WS.SelectedSlot, WS.SelectedSlotPos)

    if Weapons[WS.SelectedSlot] == nil or Weapons[WS.SelectedSlot][WS.SelectedSlotPos] == nil then
        GetDown(Weapons)
    end
end

local LastSelected = 0

local function get_active_tool(ply, tool)
    local activeWep = ply:GetActiveWeapon()
    if not IsValid(activeWep) or activeWep:GetClass() ~= "gmod_tool" or activeWep.Mode ~= tool then return end
    return activeWep:GetToolObject(tool)
end

local function canUseSelector(ply)
    local wep = ply:GetActiveWeapon()
    local tool = get_active_tool(ply, "submaterial")
    if tool and IsValid(ply:GetEyeTraceNoCursor().Entity) then
        return true
    end

    return IsAiming(ply) or (IsValid(wep) and wep:GetClass() == "weapon_physgun" and ply:KeyDown(IN_ATTACK)) or (lply.organism and lply.organism.pain and lply.organism.pain > 100) or GetGlobalBool("RadialInventory", false)
end

function WS.ChangeSelectionWep( ply, key )
    if not IsValid( ply ) or not ply:Alive() or GetGlobalBool("RadialInventory", false) then return end
    if ply.organism and ply.organism.otrub then return end
    if canUseSelector( ply ) then return end
    --print(canUseSelector( ply ))
    --print("Table")
    --PrintTable( WS.GetWeaponTable( ply ) )
    local iPos = tAcceptKeys[ key ]
    if iPos or key == "invnext" or key == "invprev" or key == "lastinv" then

        local Weapons = WS.GetWeaponTable( ply )

        WS.Show = CurTime() + 4
        --print(key)
        surface.PlaySound("arc9_eft_shared/weapon_generic_rifle_spin"..math.random(10)..".ogg")
        if iPos then
            iPos = iPos - 1
            if LastSelected ~= iPos then
                WS.SelectedSlotPos = -1
            end
            WS.SelectedSlotPos = (Weapons[iPos] and LastSelected == iPos and WS.SelectedSlotPos + 1 > #Weapons[iPos] and 0 or math.min( WS.SelectedSlotPos + 1, #Weapons[iPos] )) or 0
            WS.SelectedSlot = iPos
            LastSelected = iPos
            --print(WS.SelectedSlotPos)
            --print(iPos)
            --print( Weapons[WS.SelectedSlot][WS.SelectedSlotPos] )
        elseif key == "invprev" then
            WS.SelectedSlotPos = WS.SelectedSlotPos - 1
            --print(WS.SelectedSlotPos)
            if Weapons[WS.SelectedSlot] and WS.SelectedSlotPos < 0  then
                GetUpper(Weapons)
            end
            --WS.SelectedSlot = Weapons[WS.SelectedSlot] and #Weapons[WS.SelectedSlot] > (WS.SelectedSlotPos + 1) and WS.SelectedSlot + 1 or WS.SelectedSlot + 1 > #Weapons - 1 and 0 or 0
        elseif key == "invnext" then
            WS.SelectedSlotPos = WS.SelectedSlotPos + 1
            --print(WS.SelectedSlotPos)
            if Weapons[WS.SelectedSlot] and WS.SelectedSlotPos > #Weapons[WS.SelectedSlot] then
                GetDown(Weapons)
            end
        elseif key == "lastinv" and IsValid(WS.LastInv) then
            WS.Show = 0
            WS.LastInv = WS.LastInv or "weapon_hands_sh"
            local oldwep = ply:GetActiveWeapon()
            input.SelectWeapon( WS.LastInv )
            WS.LastInv = oldwep
        end

    end
end

function WS.SetActuallyWeapon( ply, cmd )
    if not IsValid( ply ) or not ply:Alive() or GetGlobalBool("RadialInventory", false) then return end
    if (cmd:KeyDown( IN_ATTACK ) or cmd:KeyDown( IN_ATTACK2 )) and WS.Show > CurTime() then

        if WS.Selected and WS.Selected > CurTime() then
            cmd:RemoveKey(IN_ATTACK)
            cmd:RemoveKey(IN_ATTACK2)
        else
            cmd:RemoveKey(IN_ATTACK)
            cmd:RemoveKey(IN_ATTACK2)
            --print(WS.GetSelectedWeapon())

            if IsValid(WS.GetSelectedWeapon()) then
                WS.LastInv = WS.LastInv ~= ply:GetActiveWeapon() and WS.LastInv or ply:GetActiveWeapon()
                input.SelectWeapon( WS.GetSelectedWeapon() )
            end
            cmd:RemoveKey(IN_ATTACK)
            cmd:RemoveKey(IN_ATTACK2)

            WS.LastSelectedSlot = WS.SelectedSlot
            WS.LastSelectedSlotPos = WS.SelectedSlotPos
            WS.Selected = CurTime() + 0.2
            WS.Show = CurTime() + 0.2
            surface.PlaySound("arc9_eft_shared/weapon_generic_spin"..math.random(1,10)..".ogg")
        end
    end
end

hook.Add( "PlayerBindPress", "WeaponSelector_PlayerBindPress", WS.ChangeSelectionWep )

hook.Add( "HUDPaint", "WeaponSelector_Draw", function()
    WS.WeaponSelectorDraw( LocalPlayer() )
end)

hook.Add( "StartCommand", "WeaponSelector_StartCommand", WS.SetActuallyWeapon )

local tHideElements = {
    ["CHudWeaponSelection"] = true
}

hook.Add("HUDShouldDraw", "WeaponSelector_HUDShouldDraw", function(sElementName)
    if tHideElements[sElementName] then return false end
end)

-- Я ТАК ЗАДОЛБАЛСЯ ПРОСТО УБЕЙТЕ МЕНЯ ХАХАХАХАХАХАХАХАХАХААХАХАХАХАХАХА
-- ПОЛЧАСА Я ПЫТАЛСЯ СДЕЛАТЬ НОРМЛАЬНОЕ ПЕРЕКЛЮЧЕНИЕ ГОВНА!!!
-- ЗАТО ПОЛУЧИЛОСЬ!!!!
-- УЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭЭ
--[[
    /\_/\
    |_ _|
    |   |__
   /_|_____\ -- IT'S SO OVER
--]]
