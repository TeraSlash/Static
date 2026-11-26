-- Static: allow two accessories per slot type (2 hats, 2 face items, 2 body items = 6 attachments).
-- This lives in its own file and is re-applied after every addon has loaded, so it keeps working even when
-- another addon (for example Clothing+) ships its own copy of sh_shared.lua.
hg = hg or {}
hg.Appearance = hg.Appearance or {}

local MAX_ATTACHMENTS = 6   -- 1 hat, 2 face, 3 body, 4 hat 2, 5 face 2, 6 body 2
local MAX_PER_PLACEMENT = 2 -- never three hats

local function ValidateAttachments(tbl)
	if not istable(tbl) then return false end
	if table.Count(tbl) > MAX_ATTACHMENTS then return false, "Too many" end

	local occupied = {}
	for k, v in ipairs(tbl) do
		local data = hg.Accessories and hg.Accessories[v]
		if not data then continue end

		local placement = data.placement
		if placement and (occupied[placement] or 0) >= MAX_PER_PLACEMENT then
			tbl[k] = ""
			continue
		end
		if placement then occupied[placement] = (occupied[placement] or 0) + 1 end
	end

	return true
end

local function Install()
	if hg.Appearance.ValidateFunctions then
		hg.Appearance.ValidateFunctions.AAttachments = ValidateAttachments
	end
end

Install()
hook.Add("InitPostEntity", "Static_AppearanceValidator", Install)
