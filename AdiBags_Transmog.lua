--[[
AdiBags_Transmog - Adds Transmog filters to AdiBags.
Copyright 2019 Frafall (frafall@hotmail.com)

Originally by (Adibags_Legion):
Copyright 2016 Dia (mrdiablo@divine-pride.net)
All rights reserved.

Strings from: https://www.townlong-yak.com/framexml/live/GlobalStrings.lua
--]]

local _, ns = ...

local addon = LibStub('AceAddon-3.0'):GetAddon('AdiBags')
local L = setmetatable({}, {__index = addon.L})

do -- Localization
	L["Transmog"] = "Visuals"
        L["Account transmog"] = "Account visuals"
        L['Put Transmog Stuff in their own sections.'] = "Put Transmog Stuff in their own sections."
        L['Check this if you want a section for not collected transmog items.'] = "Check this if you want a section for not collected transmog items."

        --[[
	local locale = GetLocale()
	if locale == "frFR" then
		L["Transmog"] = "Transmog"
	elseif locale == "deDE" then
		L["Transmog"] = "Transmog"
	elseif locale == 'ptBR' then
		L["Transmog"] = "Transmog"
	end
        --]]
end

-- The filter itself

local transmogFilter = addon:RegisterFilter("Transmog", 95, 'ABEvent-1.0')
transmogFilter.uiName = L['Transmog']
transmogFilter.uiDesc = L['Put Transmog Stuff in their own sections.']

function transmogFilter:OnInitialize()
	self.db = addon.db:RegisterNamespace('Transmog', {
		profile = { enableTransmog = true },
		char = {	},
	})
end

local function unescape(String)
	local Result = tostring(String)
	Result = gsub(Result, "|c........", "") -- Remove color start.
	Result = gsub(Result, "|r", "") -- Remove color end.
	Result = gsub(Result, "|H.-|h(.-)|h", "%1") -- Remove links.
	Result = gsub(Result, "|T.-|t", "") -- Remove textures.
	Result = gsub(Result, "{.-}", "") -- Remove raid target icons.
	return Result
end

function transmogFilter:Update()
	self:SendMessage('AdiBags_FiltersChanged')
end

function transmogFilter:OnEnable()
	addon:UpdateFilters()
end

function transmogFilter:OnDisable()
	addon:UpdateFilters()
end

--[[
   Determine text color, either as a color set bySetTextColor or
   but in-game escape codes.
--]]
local function getColorText(tip)
    if not tip then return 0,0,0,nil end

    local str = tip:GetText()
    if not str then return 0,0,0,nil end

    local r, g, b = str:match("|cff(%x%x)(%x%x)(%x%x)")
    local text = unescape(str)

    -- Any escape codes overruling?
    if r and g and b then
        return tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), text
    end

    -- No escape codes, use widget color
    r, g, b = tip:GetTextColor()
    return floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5), text
end

-- Map the classIndex (UnitClass) to main item subclassid
-- Indexed by classIndex (0-12) ie toons class
local classItemIndex = {
    [0] = LE_ITEM_ARMOR_GENERIC,	-- None, should never occure
    	  LE_ITEM_ARMOR_PLATE,		-- Warrior
    	  LE_ITEM_ARMOR_PLATE,		-- Paladin
    	  LE_ITEM_ARMOR_MAIL,		-- Hunter
          LE_ITEM_ARMOR_LEATHER,    	-- Rogue
          LE_ITEM_ARMOR_CLOTH,    	-- Priest
          LE_ITEM_ARMOR_PLATE,    	-- DeathKnight
          LE_ITEM_ARMOR_MAIL,    	-- Shaman
          LE_ITEM_ARMOR_CLOTH,    	-- Mage
          LE_ITEM_ARMOR_CLOTH,    	-- Warlock
          LE_ITEM_ARMOR_LEATHER,    	-- Monk
          LE_ITEM_ARMOR_LEATHER,    	-- Druid
          LE_ITEM_ARMOR_LEATHER,    	-- Demon Hunter
}

--[[
	* Do we have an issue with shields, LE_ITEM_ARMOR_SHIELD separate field in enum
          Shield registers as itemClassID 4, ie as LE_ITEM_CLASS_ARMOR

	* How to determine if a weapon transmog is usable by toon?
--]]

local function itemUsableByCharacter(itemName)
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
          itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID,
          isCraftingReagent = GetItemInfo(itemName)

    -- Is this equipment/clothing
    if itemClassID == LE_ITEM_CLASS_ARMOR then

        -- Is this itemSubType (leather, cloth, mail, plate) for our class? 
        local className, classClass, classIndex = UnitClass("player")
        if itemSubClassID ~= classItemIndex[classIndex] then return false end

    -- Is this weapons
    elseif itemClassID == LE_ITEM_CLASS_WEAPON then

        -- Seems we can trust the red coloring in weapons as indicator if
        -- we can collect the weapon visual

    else
        return false
    end

    -- Is our level higher than minlevel
    if UnitLevel("player") < itemMinLevel then return false end

    -- Transmog usable by current toon
    return true
end

--[[
   Determine if this is a transmog we do not have yet:
      - equipable (no recipes, mats...)
      - no red text in tooltip (bad type, weapon)
      - "You haven't collected this appearance"	 (Transmog) = TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN
      - "You've collected this appearance but not from this item"  = TRANSMOGRIFY_TOOLTIP_ITEM_UNKNOWN_APPEARANCE_KNOWN

   Two categories:
      - Transmog for this character ("You haven't collected this appearance" and wearable and char's type)
      - Possible transmog for other characters on account ("You haven't collected this appearance" and BoE/BoA)
--]]
local tip

function transmogFilter:Filter(slotData)
        local DEBUG = false
        local d_bag = 0
        local d_slot = 19

        function dprintf(fmt, ...)
            if DEBUG and slotData.bag == d_bag and slotData.slot == d_slot then
                print(string.format(fmt, ...))
            end
        end

        -- Is module active?
        if not self.db.profile.enableTransmog then
                return
        end

        -- Setup tooltip
	tip = tip or CreateFrame("GameTooltip", "AdiTransmogTooltip", nil, "GameTooltipTemplate")
	tip:SetOwner(UIParent, "ANCHOR_NONE")

        -- Populate tooltip
	if slotData.bag == BANK_CONTAINER then
		tip:SetInventoryItem("player", BankButtonIDToInvSlotID(slotData.slot, nil))
	else
		tip:SetBagItem(slotData.bag, slotData.slot)
	end

        -- Is the item an equippable item
        local itemName = _G["AdiTransmogTooltipTextLeft1"]:GetText()
        dprintf("Item: %s", itemName)

        if itemName and IsEquippableItem(itemName) and IsDressableItem(itemName) then

            local appearance_missing = false
            local item_usable = itemUsableByCharacter(itemName) 
            local item_bound = true

            -- Scan for red text or appearance strings
	    for i = 2,tip:NumLines() do
		local r,g,b,t = getColorText(_G["AdiTransmogTooltipTextLeft"..i])
                if t then
                    dprintf("Left: (%d, %d, %d) %s", r,g,b,t)

                    -- Red text?
                    if r == 255 and g == 32 and b == 32 then
                        item_usable = false
                    end

                    -- Missing appearance?
		    if t == TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN then
                        appearance_missing = true
                    end

                    -- BoE/BoA
                    if t == ITEM_BIND_ON_EQUIP or t == ITEM_ACCOUNTBOUND or t == ITEM_BIND_TO_BNETACCOUNT or t == ITEM_BNETACCOUNTBOUND then
                        item_bound = false
                    end

		    -- XXX: Optimize, break on info found?
                end
            end
            dprintf("Left: missing %s, bound %s, usable %s", tostring(appearance_missing), tostring(item_bound), tostring(item_usable))

            -- Now, what are the results
            if appearance_missing then

                -- Scan for red text in right side as well
	        for i = 2,tip:NumLines() do
		    local r,g,b,t = getColorText(_G["AdiTransmogTooltipTextRight"..i])
                    if t then
                        dprintf("Right: (%d, %d, %d) %s", r, g, b, t)
 
                        -- Red text?
                        if r == 255 and g == 32 and b == 32 then
                            dprintf("Right side RED <%s>", t)
                            item_usable = false
                        end
                    end
                end
                dprintf("Right: missing %s, bound %s, usable %s", tostring(appearance_missing), tostring(item_bound), tostring(item_usable))

                if item_usable then
                    return L["Transmog"]
         
                elseif not item_bound then
                    return L["Account transmog"]
    
                end
            end
        end

	tip:Hide()
end

function transmogFilter:GetOptions()
	return {
		enableTransmog = {
			name = L['Transmog'],
			desc = L['Check this if you want a section for not collected transmog items.'],
			type = 'toggle',
			order = 60,
		},
	}, addon:GetOptionHandler(self, false, function() return self:Update() end)
end
