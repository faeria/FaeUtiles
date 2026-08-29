local _, Cortex = ...
local Utils = Cortex.CollectorUtils

local WeeklyCollector = {
    events = { "WEEKLY_REWARDS_UPDATE", "WEEKLY_REWARDS_ITEM_CHANGED" },
    requiresOutOfCombat = true,
}

local ACTIVITY_FIELDS = { "type", "index", "threshold", "progress", "id", "activityTierID", "level", "claimID", "raidString" }

function WeeklyCollector:Collect()
    if type(C_WeeklyRewards) ~= "table" or type(C_WeeklyRewards.GetActivities) ~= "function" then
        return Utils.Unavailable({ "weekly", "weekly.activities" }, "api-unavailable")
    end
    local activities = C_WeeklyRewards.GetActivities()
    if not Utils.IsUsableTable(activities) then
        return Utils.Unavailable({ "weekly", "weekly.activities" }, "restricted-or-not-ready")
    end
    local copied = {}
    for index = 1, #activities do
        local activity = Utils.CopyFields(activities[index], ACTIVITY_FIELDS)
        if activity then copied[#copied + 1] = activity end
    end
    local canClaim, hasAvailable
    if type(C_WeeklyRewards.CanClaimRewards) == "function" then
        local value = C_WeeklyRewards.CanClaimRewards()
        if Cortex:IsAccessibleValue(value) then canClaim = value end
    end
    if type(C_WeeklyRewards.HasAvailableRewards) == "function" then
        local value = C_WeeklyRewards.HasAvailableRewards()
        if Cortex:IsAccessibleValue(value) then hasAvailable = value end
    end
    local weekly = { activities = copied, canClaimRewards = canClaim, hasAvailableRewards = hasAvailable }
    return { facts = { ["weekly"] = weekly, ["weekly.activities"] = copied } }
end

Cortex:RegisterCollector("Weekly", WeeklyCollector)
