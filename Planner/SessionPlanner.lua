local _, Cortex = ...

local SessionPlanner = {}
local STATUSES = Cortex.Constants.GOAL_STATUSES

local function normalizeBudget(value)
    if value == nil or value == "unlimited" or value == "UNLIMITED" then return nil, true end
    local minutes = tonumber(value)
    if not minutes or minutes < 5 or minutes > 480 then return nil, false end
    return math.floor(minutes), true
end

local function recommendationMaps(recommendations)
    local byId, byGoal = {}, {}
    for index = 1, #recommendations do
        local recommendation = recommendations[index]
        byId[recommendation.id] = recommendation
        if recommendation.goalId then
            local current = byGoal[recommendation.goalId]
            if not current or recommendation.score > current.score
                or (recommendation.score == current.score and recommendation.id < current.id) then
                byGoal[recommendation.goalId] = recommendation
            end
        end
    end
    return byId, byGoal
end

local function candidateSort(left, right)
    if left.adjustedScore ~= right.adjustedScore then return left.adjustedScore > right.adjustedScore end
    if left.priority ~= right.priority then return left.priority > right.priority end
    if left.duration.minutes ~= right.duration.minutes then return left.duration.minutes < right.duration.minutes end
    return left.id < right.id
end

local function blockersAreGoalDependencies(recommendation, goal)
    if not recommendation or recommendation.actionable then return true end
    if #recommendation.blockers == 0 then return false end
    local dependencies = {}
    for index = 1, #(goal.dependencies or {}) do dependencies[goal.dependencies[index]] = true end
    for index = 1, #recommendation.blockers do
        local blocker = recommendation.blockers[index]
        if type(blocker) ~= "table" or not dependencies[blocker.goalId] then return false end
    end
    return true
end

function SessionPlanner:NormalizeBudget(value) return normalizeBudget(value) end

function SessionPlanner:Initialize()
    Cortex:GetService("Commands"):Register({
        id = "session.open",
        title = Cortex:GetText("COMMAND_OPEN_SESSION"),
        subtitle = Cortex:GetText("COMMAND_OPEN_SESSION_SUBTITLE"),
        keywords = { "session", "plan", "30", "60", "120", "unlimited" },
        execute = function()
            Cortex:GetService("Navigation"):GoTo("session")
            Cortex:GetService("MainWindow"):Show()
        end,
    })
end

function SessionPlanner:BuildCandidates(recommendations, goals, context)
    local estimator = Cortex:GetService("DurationEstimator")
    local byRecommendationId, recommendationByGoal = recommendationMaps(recommendations)
    local candidates, byGoal = {}, {}
    local location = context and context:Get("location.current") or nil

    for _, goal in ipairs(goals:GetGoals()) do
        if goal.status ~= STATUSES.COMPLETED and goal.status ~= STATUSES.PAUSED
            and goal.status ~= STATUSES.FAILED then
            local actions = goals:GetDirectActions(goal.id)
            table.sort(actions, function(left, right) return left.id < right.id end)
            local action = actions[1]
            local recommendation = action and (byRecommendationId[action.id] or recommendationByGoal[goal.id])
            if recommendation and not blockersAreGoalDependencies(recommendation, goal) then action = nil end
            if action then
                local metadata = Cortex.Schema.Copy(action.metadata or {})
                if recommendation then
                    for key, value in pairs(recommendation.metadata or {}) do
                        if metadata[key] == nil then metadata[key] = Cortex.Schema.Copy(value) end
                    end
                end
                local priority = recommendation and recommendation.priority or goal.priority or 0
                local score = recommendation and recommendation.score or priority * 1.2
                local locationMapID = metadata.mapID or metadata.locationMapID
                local locationBonus = type(location) == "table" and location.mapID == locationMapID and 5 or 0
                local candidate = {
                    id = action.id,
                    title = recommendation and recommendation.actionable and recommendation.title or action.title,
                    description = recommendation and recommendation.actionable and recommendation.description
                        or goal.description,
                    category = recommendation and recommendation.category or "GOALS",
                    goalId = goal.id, recommendationId = recommendation and recommendation.id or nil,
                    recommendation = recommendation, action = action, goal = goal, priority = priority,
                    score = score, adjustedScore = score + locationBonus,
                    benefit = recommendation and recommendation.benefit or "",
                    dependencyGoalIds = Cortex.Schema.Copy(goal.dependencies or {}),
                    locationMapID = locationMapID, isCurrentLocation = locationBonus > 0, metadata = metadata,
                }
                candidate.duration = estimator:Estimate(candidate)
                candidates[#candidates + 1], byGoal[goal.id] = candidate, candidate
            end
        end
    end

    for index = 1, #recommendations do
        local recommendation = recommendations[index]
        if not recommendation.goalId and recommendation.actionable and #recommendation.blockers == 0 then
            local locationMapID = recommendation.metadata.mapID or recommendation.metadata.locationMapID
            local locationBonus = type(location) == "table" and location.mapID == locationMapID and 5 or 0
            local candidate = {
                id = recommendation.id, title = recommendation.title, description = recommendation.description,
                category = recommendation.category, recommendationId = recommendation.id,
                recommendation = recommendation, priority = recommendation.priority, score = recommendation.score,
                adjustedScore = recommendation.score + locationBonus, benefit = recommendation.benefit,
                dependencyGoalIds = {}, locationMapID = locationMapID,
                isCurrentLocation = locationBonus > 0, metadata = Cortex.Schema.Copy(recommendation.metadata),
            }
            candidate.duration = estimator:Estimate(candidate)
            candidates[#candidates + 1] = candidate
        end
    end
    table.sort(candidates, candidateSort)
    return candidates, byGoal, location
end

local function collectBundle(candidate, byGoal, goals, selected, visiting, bundled, bundle)
    if selected[candidate.id] or bundled[candidate.id] then return true end
    if visiting[candidate.id] then return false, "cycle" end
    visiting[candidate.id] = true
    for index = 1, #candidate.dependencyGoalIds do
        local dependencyId = candidate.dependencyGoalIds[index]
        local dependency = goals:GetGoal(dependencyId)
        if not dependency then visiting[candidate.id] = nil; return false, "missing-dependency" end
        if not Cortex.Goal.IsCompleted(dependency) then
            local dependencyCandidate = byGoal[dependencyId]
            if not dependencyCandidate then visiting[candidate.id] = nil; return false, "blocked-dependency" end
            local ok, reason = collectBundle(dependencyCandidate, byGoal, goals, selected, visiting,
                bundled, bundle)
            if not ok then visiting[candidate.id] = nil; return false, reason end
        end
    end
    visiting[candidate.id] = nil
    if not selected[candidate.id] and not bundled[candidate.id] then
        bundled[candidate.id] = true
        bundle[#bundle + 1] = candidate
    end
    return true
end

function SessionPlanner:Build(budget, input)
    local budgetMinutes, valid = normalizeBudget(budget)
    if not valid then return nil, "invalid-budget" end
    input = type(input) == "table" and input or {}
    local recommendations = input.recommendations or Cortex:GetModule("Recommendations"):GetRecommendations()
    local goals = input.goals or Cortex:GetModule("Goals")
    local context = input.context or Cortex:GetService("Context")
    local candidates, byGoal, location = self:BuildCandidates(recommendations, goals, context)
    local plan, selected = Cortex.Plan.Create(budgetMinutes, location), {}

    for index = 1, #candidates do
        local root = candidates[index]
        if not selected[root.id] then
            local bundle = {}
            local ok, reason = collectBundle(root, byGoal, goals, selected, {}, {}, bundle)
            local bundleMinutes = 0
            for bundleIndex = 1, #bundle do bundleMinutes = bundleMinutes + bundle[bundleIndex].duration.minutes end
            if not ok then
                plan:AddSkipped(root.id, reason)
            elseif plan:CanFit(bundleMinutes) then
                for bundleIndex = 1, #bundle do
                    local candidate = bundle[bundleIndex]
                    local selectionReason
                    if candidate.id ~= root.id then
                        selectionReason = Cortex:GetText("PLAN_DEPENDENCY_REASON", root.title)
                    elseif candidate.isCurrentLocation and location and location.name then
                        selectionReason = Cortex:GetText("PLAN_SELECTION_LOCATION_REASON",
                            candidate.adjustedScore, candidate.duration.minutes, location.name)
                    else
                        selectionReason = Cortex:GetText("PLAN_SELECTION_REASON", candidate.adjustedScore,
                            candidate.duration.minutes)
                    end
                    plan:Add(candidate, selectionReason)
                    selected[candidate.id] = true
                end
            else
                plan:AddSkipped(root.id, "time-budget")
            end
        end
    end

    Cortex:GetService("Database"):SetUnfinishedTasks(plan)
    return plan, plan:GetRemainingMinutes()
end

Cortex:RegisterModule("Planner", SessionPlanner, {
    services = { "Database", "DurationEstimator", "Context", "Commands", "Navigation" },
    modules = { "Recommendations", "Goals" },
}, {
    defaultEnabled = true,
})
