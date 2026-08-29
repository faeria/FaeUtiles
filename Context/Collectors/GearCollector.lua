local _, Cortex = ...
local Utils = Cortex.CollectorUtils

local GearCollector = {
    events = { "PLAYER_EQUIPMENT_CHANGED", "PLAYER_AVG_ITEM_LEVEL_UPDATE", "GET_ITEM_INFO_RECEIVED" },
    requiresOutOfCombat = true,
}

local EQUIPMENT_SLOT_FIRST = 1
local EQUIPMENT_SLOT_LAST = 19
local ITEM_LEVEL_SLOTS = { [1] = true, [2] = true, [3] = true, [5] = true, [6] = true, [7] = true,
    [8] = true, [9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [14] = true,
    [15] = true, [16] = true, [17] = true }
local UPGRADE_FIELDS = { "currentLevel", "maxLevel", "maxItemLevel", "trackString", "trackStringID" }

function GearCollector:ShouldCollect(context, event, itemID, success)
    if event ~= "GET_ITEM_INFO_RECEIVED" then return true end
    if context:GetLastKnown("gear.cachePending") ~= true then return false end
    if Utils.IsAccessible(success) and success == false then return false end
    if not Utils.IsAccessible(itemID) then return true end

    local slots = context:GetLastKnown("gear.slots")
    if type(slots) ~= "table" then return true end
    for _, slot in pairs(slots) do
        if type(slot) == "table" and Utils.IsAccessible(slot.itemId) and slot.itemId == itemID then
            return true
        end
    end
    return false
end

function GearCollector:Collect()
    if type(GetInventoryItemID) ~= "function" or type(GetInventoryItemLink) ~= "function"
        or type(C_Item) ~= "table" or type(C_Item.GetDetailedItemLevelInfo) ~= "function" then
        return Utils.Unavailable({ "gear.slots", "gear.itemLevel", "character.itemLevel" }, "api-unavailable")
    end

    local slots, missingGems, upgrades = {}, {}, {}
    local totalItemLevel, itemLevelCount, cachePending = 0, 0, false
    local gemDetectionRestricted, upgradeDetectionRestricted = false, false
    for slotId = EQUIPMENT_SLOT_FIRST, EQUIPMENT_SLOT_LAST do
        local itemId = GetInventoryItemID("player", slotId)
        if not Cortex:IsAccessibleValue(itemId) then
            return Utils.Unavailable({ "gear.slots", "gear.itemLevel", "character.itemLevel" }, "restricted")
        end
        if itemId then
            local itemLink = GetInventoryItemLink("player", slotId)
            if not Cortex:IsAccessibleValue(itemLink) then
                return Utils.Unavailable({ "gear.slots", "gear.itemLevel", "character.itemLevel" }, "restricted")
            end
            local itemLevel
            if itemLink then
                local ok, actualItemLevel = Utils.Call(C_Item.GetDetailedItemLevelInfo, itemLink)
                if ok and Utils.IsAccessible(actualItemLevel) then itemLevel = actualItemLevel end
            end
            cachePending = cachePending or itemLink == nil or itemLevel == nil
            local slot = { slotId = slotId, itemId = itemId, itemLink = itemLink, itemLevel = itemLevel }
            if itemLink and type(C_Item.GetItemUpgradeInfo) == "function" then
                local ok, upgradeInfo = Utils.Call(C_Item.GetItemUpgradeInfo, itemLink)
                if ok and Cortex:IsAccessibleValue(upgradeInfo) then
                    local upgrade = Utils.CopyFields(upgradeInfo, UPGRADE_FIELDS)
                    if upgrade and type(upgrade.currentLevel) == "number"
                        and type(upgrade.maxLevel) == "number" then
                        slot.upgrade = upgrade
                        if upgrade.currentLevel < upgrade.maxLevel then
                            upgrades[slotId] = {
                                slotId = slotId,
                                itemId = itemId,
                                currentLevel = upgrade.currentLevel,
                                maxLevel = upgrade.maxLevel,
                                maxItemLevel = upgrade.maxItemLevel,
                                trackString = upgrade.trackString,
                                trackStringID = upgrade.trackStringID,
                            }
                        end
                    end
                elseif not ok or not Cortex:IsAccessibleValue(upgradeInfo) then
                    upgradeDetectionRestricted = true
                end
            end
            if itemLink and type(C_Item.GetItemNumSockets) == "function"
                and type(C_Item.GetItemGemID) == "function" then
                local ok, socketCount = Utils.Call(C_Item.GetItemNumSockets, itemLink)
                if ok and Utils.IsAccessible(socketCount) then
                    local emptySockets = 0
                    for socketIndex = 1, socketCount do
                        local gemOk, gemID = Utils.Call(C_Item.GetItemGemID, itemLink, socketIndex)
                        if not gemOk or not Cortex:IsAccessibleValue(gemID) then
                            gemDetectionRestricted = true
                            break
                        end
                        if gemID == nil then emptySockets = emptySockets + 1 end
                    end
                    slot.socketCount = socketCount
                    if emptySockets > 0 and not gemDetectionRestricted then
                        missingGems[slotId] = { slotId = slotId, emptySockets = emptySockets }
                    end
                else
                    gemDetectionRestricted = true
                end
            end
            slots[slotId] = slot
            if ITEM_LEVEL_SLOTS[slotId] and itemLevel then
                totalItemLevel, itemLevelCount = totalItemLevel + itemLevel, itemLevelCount + 1
            end
        end
    end

    local facts = { ["gear.slots"] = slots, ["gear.cachePending"] = cachePending }
    local unavailable = { ["gear.missingEnchants"] = "not-reliably-detectable" }
    if upgradeDetectionRestricted then
        unavailable["gear.upgrades"] = "upgrade-info-restricted"
    elseif type(C_Item.GetItemUpgradeInfo) == "function" then
        facts["gear.upgrades"] = upgrades
    else
        unavailable["gear.upgrades"] = "api-unavailable"
    end
    if gemDetectionRestricted then
        unavailable["gear.missingGems"] = "gem-info-restricted"
    elseif type(C_Item.GetItemNumSockets) == "function" and type(C_Item.GetItemGemID) == "function" then
        facts["gear.missingGems"] = missingGems
    else
        unavailable["gear.missingGems"] = "api-unavailable"
    end
    if itemLevelCount > 0 then
        local scannedAverage = totalItemLevel / itemLevelCount
        facts["gear.scannedAverageItemLevel"] = scannedAverage
        facts["gear.itemLevelCoverage"] = { loadedSlots = itemLevelCount, expectedSlots = 16 }
    end
    if type(C_PaperDollInfo) == "table" and type(C_PaperDollInfo.GetInspectItemLevel) == "function" then
        local ok, equippedItemLevel = Utils.Call(C_PaperDollInfo.GetInspectItemLevel, "player")
        if ok and Utils.IsAccessible(equippedItemLevel) then
            facts["gear.itemLevel"] = equippedItemLevel
            facts["character.itemLevel"] = equippedItemLevel
        else
            unavailable["gear.itemLevel"] = "item-level-restricted-or-not-ready"
            unavailable["character.itemLevel"] = unavailable["gear.itemLevel"]
        end
    else
        unavailable["gear.itemLevel"] = "api-unavailable"
        unavailable["character.itemLevel"] = "api-unavailable"
    end
    return { facts = facts, unavailable = unavailable }
end

Cortex:RegisterCollector("Gear", GearCollector)
