local _, Cortex = ...

local Rules = Cortex:GetService("Rules")
local STATUSES = Cortex.Constants.GOAL_STATUSES

local function estimatedMinutes(goal, fallback)
    return type(goal.metadata) == "table" and type(goal.metadata.estimatedMinutes) == "number"
        and goal.metadata.estimatedMinutes or fallback
end

Rules:Register({
    id = "define-first-goal",
    category = "GOALS",
    priority = 100,
    conditions = function(_, goals)
        local allGoals = goals:GetGoals()
        for index = 1, #allGoals do if Cortex.Goal.IsOpen(allGoals[index]) then return false end end
        return true
    end,
    evaluate = function() return { true } end,
    buildRecommendation = function()
        return {
            id = "onboarding:define-goal",
            title = Cortex:GetText("RECOMMENDATION_DEFINE_GOAL_TITLE"),
            description = Cortex:GetText("RECOMMENDATION_DEFINE_GOAL_DESCRIPTION"),
            reason = Cortex:GetText("RECOMMENDATION_DEFINE_GOAL_REASON"),
            benefit = Cortex:GetText("RECOMMENDATION_DEFINE_GOAL_BENEFIT"),
            actionable = true,
            blockers = {},
            metadata = {
                estimatedMinutes = 5,
                command = "/cortex goal add <title>",
                scoring = { importance = 1.2, goalRelevance = 1, urgency = 1, efficiency = 1.5, cost = 0 },
            },
        }
    end,
})

Rules:Register({
    id = "available-goal-action",
    category = "GOALS",
    priority = 60,
    evaluate = function(_, goals)
        local matches, seen = {}, {}
        local allGoals = goals:GetGoals()
        for index = 1, #allGoals do
            local root = allGoals[index]
            if Cortex.Goal.IsOpen(root) then
                local actions = goals:GetAvailableActions(root.id, true)
                for actionIndex = 1, #actions do
                    local action = actions[actionIndex]
                    local actionGoal = goals:GetGoal(action.goalId)
                    if actionGoal and actionGoal.type ~= "WEEKLY_COMPLETION" and not seen[action.id] then
                        matches[#matches + 1] = { action = action, goal = actionGoal }
                        seen[action.id] = true
                    end
                end
            end
        end
        return matches
    end,
    buildRecommendation = function(match)
        local goal, action = match.goal, match.action
        return {
            id = action.id,
            title = Cortex:GetText("RECOMMENDATION_ADVANCE_GOAL_TITLE", goal.title),
            description = Cortex:GetText("RECOMMENDATION_ADVANCE_GOAL_DESCRIPTION"),
            priority = goal.priority,
            reason = Cortex:GetText("RECOMMENDATION_GOAL_ACTION_REASON", goal.title),
            benefit = Cortex:GetText("RECOMMENDATION_ADVANCE_GOAL_BENEFIT"),
            goalId = goal.id,
            actionable = true,
            blockers = {},
            metadata = {
                actionType = action.type,
                estimatedMinutes = action.metadata.estimatedMinutes or estimatedMinutes(goal, 30),
                scoring = { importance = 1, goalRelevance = 1.4, urgency = 1, efficiency = 1, cost = 0 },
            },
        }
    end,
})

Rules:Register({
    id = "goal-blocked",
    category = "GOALS",
    priority = 55,
    evaluate = function(_, goals)
        local matches = {}
        for _, goal in ipairs(goals:GetGoals()) do
            if goal.status == STATUSES.BLOCKED then
                matches[#matches + 1] = { goal = goal, blockers = goals:GetBlockers(goal.id, true) }
            end
        end
        return matches
    end,
    buildRecommendation = function(match)
        return {
            id = "goal:" .. match.goal.id .. ":blocked",
            title = Cortex:GetText("RECOMMENDATION_BLOCKED_GOAL_TITLE", match.goal.title),
            description = Cortex:GetText("RECOMMENDATION_BLOCKED_GOAL_DESCRIPTION"),
            priority = match.goal.priority,
            reason = Cortex:GetText("RECOMMENDATION_BLOCKED_GOAL_REASON", #match.blockers),
            goalId = match.goal.id,
            actionable = false,
            blockers = match.blockers,
            metadata = {
                estimatedMinutes = 5,
                scoring = { importance = 1, goalRelevance = 1.2, urgency = 0.8, efficiency = 0.5, cost = 0 },
            },
        }
    end,
})

Rules:Register({
    id = "weekly-incomplete",
    category = "WEEKLY",
    priority = 75,
    factKeys = { "weekly.activities" },
    evaluate = function(_, goals)
        local matches = {}
        for _, goal in ipairs(goals:GetGoals()) do
            if goal.type == "WEEKLY_COMPLETION" and goal.status == STATUSES.ACTIVE
                and goal.progress.availability == "AVAILABLE"
                and goal.progress.current < goal.progress.total then matches[#matches + 1] = goal end
        end
        return matches
    end,
    buildRecommendation = function(goal)
        return {
            id = "goal:" .. goal.id .. ":weekly",
            title = Cortex:GetText("RECOMMENDATION_WEEKLY_TITLE"),
            description = Cortex:GetText("RECOMMENDATION_WEEKLY_DESCRIPTION",
                goal.progress.current, goal.progress.total),
            priority = goal.priority,
            reason = Cortex:GetText("RECOMMENDATION_WEEKLY_REASON",
                goal.progress.current, goal.progress.total),
            goalId = goal.id,
            actionable = true,
            blockers = {},
            metadata = {
                estimatedMinutes = estimatedMinutes(goal, 30),
                scoring = { importance = 1, goalRelevance = 1.5, urgency = 1.25, efficiency = 1, cost = 0.2 },
            },
        }
    end,
})

Rules:Register({
    id = "missing-gems",
    category = "GEAR",
    priority = 65,
    factKeys = { "gear.missingGems" },
    contextSources = { "Gear" },
    conditions = function(context) return type(context:Get("gear.missingGems")) == "table" end,
    evaluate = function(context)
        local slots, slotCount, socketCount = context:Get("gear.missingGems"), 0, 0
        for _, missing in pairs(slots) do
            if type(missing) == "table" and type(missing.emptySockets) == "number" and missing.emptySockets > 0 then
                slotCount, socketCount = slotCount + 1, socketCount + missing.emptySockets
            end
        end
        return socketCount > 0 and { { slotCount = slotCount, socketCount = socketCount } } or {}
    end,
    buildRecommendation = function(match)
        return {
            id = "gear:missing-gems",
            title = Cortex:GetText("RECOMMENDATION_MISSING_GEMS_TITLE"),
            description = Cortex:GetText("RECOMMENDATION_MISSING_GEMS_DESCRIPTION", match.socketCount, match.slotCount),
            reason = Cortex:GetText("RECOMMENDATION_MISSING_GEMS_REASON", match.socketCount),
            actionable = true,
            blockers = {},
            metadata = {
                emptySockets = match.socketCount,
                affectedSlots = match.slotCount,
                estimatedMinutes = 5,
                scoring = { importance = 1, goalRelevance = 1, urgency = 1, efficiency = 1.4, cost = 0.4 },
            },
        }
    end,
})

Rules:Register({
    id = "available-upgrade",
    category = "GEAR",
    priority = 62,
    factKeys = { "gear.upgrades" },
    contextSources = { "Gear" },
    conditions = function(context) return type(context:Get("gear.upgrades")) == "table" end,
    evaluate = function(context)
        local matches = {}
        for slotId, upgrade in pairs(context:Get("gear.upgrades")) do
            if type(slotId) == "number" and type(upgrade) == "table"
                and type(upgrade.currentLevel) == "number" and type(upgrade.maxLevel) == "number"
                and upgrade.currentLevel < upgrade.maxLevel then
                matches[#matches + 1] = upgrade
            end
        end
        table.sort(matches, function(left, right) return left.slotId < right.slotId end)
        return matches
    end,
    buildRecommendation = function(upgrade)
        return {
            id = "gear:upgrade:" .. upgrade.slotId,
            title = Cortex:GetText("RECOMMENDATION_UPGRADE_TITLE", upgrade.slotId),
            description = Cortex:GetText("RECOMMENDATION_UPGRADE_DESCRIPTION",
                upgrade.currentLevel, upgrade.maxLevel),
            reason = Cortex:GetText("RECOMMENDATION_UPGRADE_REASON"),
            benefit = type(upgrade.maxItemLevel) == "number"
                and Cortex:GetText("RECOMMENDATION_UPGRADE_BENEFIT", upgrade.maxItemLevel) or nil,
            actionable = true,
            blockers = {},
            metadata = {
                slotId = upgrade.slotId,
                itemId = upgrade.itemId,
                trackString = upgrade.trackString,
                currentLevel = upgrade.currentLevel,
                maxLevel = upgrade.maxLevel,
                maxItemLevel = upgrade.maxItemLevel,
                estimatedMinutes = 5,
                scoring = { importance = 1, goalRelevance = 1, urgency = 1, efficiency = 1.2, cost = 0.5 },
            },
        }
    end,
})
