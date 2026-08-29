local _, Cortex = ...
local Utils = Cortex.CollectorUtils

local ReputationCollector = {
    events = { "FACTION_STANDING_CHANGED", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "MAJOR_FACTION_UNLOCKED" },
    requiresOutOfCombat = true,
}

local FACTION_FIELDS = { "factionID", "name", "reaction", "currentReactionThreshold", "nextReactionThreshold",
    "currentStanding", "isWatched", "hasBonusRepGain", "isAccountWide" }
local RENOWN_FIELDS = { "name", "factionID", "expansionID", "isUnlocked", "renownLevel", "maxLevel",
    "renownReputationEarned", "renownLevelThreshold" }

local function copyFaction(data)
    if not Utils.IsUsableTable(data) then return nil end
    return Utils.CopyFields(data, FACTION_FIELDS)
end

local function copyRenown(data)
    if not Utils.IsUsableTable(data) then return nil end
    return Utils.CopyFields(data, RENOWN_FIELDS)
end

function ReputationCollector:Collect(context, event, factionID)
    if type(C_Reputation) ~= "table" or type(C_MajorFactions) ~= "table" then
        return Utils.Unavailable({ "reputation.byID", "renown.byID" }, "api-unavailable")
    end

    if event == "FACTION_STANDING_CHANGED" and Utils.IsAccessible(factionID)
        and type(C_Reputation.GetFactionDataByID) == "function" then
        local byId = Cortex.Schema.Copy(context:GetLastKnown("reputation.byID") or {})
        local faction = copyFaction(C_Reputation.GetFactionDataByID(factionID))
        if not faction or not Utils.IsAccessible(faction.factionID) then
            return Utils.Unavailable({ "reputation.byID" }, "faction-data-not-ready-or-restricted")
        end
        byId[faction.factionID] = faction
        return { facts = { ["reputation.byID"] = byId }, replace = false }
    end

    if (event == "MAJOR_FACTION_RENOWN_LEVEL_CHANGED" or event == "MAJOR_FACTION_UNLOCKED")
        and Utils.IsAccessible(factionID) and type(C_MajorFactions.GetMajorFactionData) == "function" then
        local byId = Cortex.Schema.Copy(context:GetLastKnown("renown.byID") or {})
        local renown = copyRenown(C_MajorFactions.GetMajorFactionData(factionID))
        if not renown or not Utils.IsAccessible(renown.factionID) then
            return Utils.Unavailable({ "renown.byID" }, "renown-data-not-ready-or-restricted")
        end
        byId[renown.factionID] = renown
        return { facts = { ["renown.byID"] = byId }, replace = false }
    end

    if type(C_Reputation.GetNumFactions) ~= "function" or type(C_Reputation.GetFactionDataByIndex) ~= "function"
        or type(C_MajorFactions.GetMajorFactionIDs) ~= "function"
        or type(C_MajorFactions.GetMajorFactionData) ~= "function" then
        return Utils.Unavailable({ "reputation.byID", "renown.byID" }, "api-unavailable")
    end
    local factionCount = C_Reputation.GetNumFactions()
    if not Utils.IsAccessible(factionCount) then
        return Utils.Unavailable({ "reputation.byID", "renown.byID" }, "restricted-or-not-ready")
    end
    local reputations = {}
    for index = 1, factionCount do
        local data = C_Reputation.GetFactionDataByIndex(index)
        if Utils.IsUsableTable(data) and Utils.IsAccessible(data.isHeader) and not data.isHeader then
            local faction = copyFaction(data)
            if faction and Utils.IsAccessible(faction.factionID) then reputations[faction.factionID] = faction end
        end
    end

    local ids = C_MajorFactions.GetMajorFactionIDs()
    local renown = {}
    if Utils.IsUsableTable(ids) then
        for index = 1, #ids do
            local id = ids[index]
            if Utils.IsAccessible(id) then
                local data = copyRenown(C_MajorFactions.GetMajorFactionData(id))
                if data and Utils.IsAccessible(data.factionID) then renown[data.factionID] = data end
            end
        end
    end
    return { facts = { ["reputation.byID"] = reputations, ["renown.byID"] = renown } }
end

Cortex:RegisterCollector("Reputation", ReputationCollector)
