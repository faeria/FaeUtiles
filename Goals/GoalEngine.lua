local _, Cortex = ...

local GoalEngine = {
    types = {},
}

local STATUSES = Cortex.Constants.GOAL_STATUSES

local function getGoalsDatabase()
    return Cortex:GetService("Database"):GetAccount().goals
end

local function publishChanged(action, goal)
    Cortex.Events:Publish(Cortex.Constants.EVENTS.GOALS_CHANGED, action, goal)
end

function GoalEngine:Initialize()
    self.dependencies = Cortex.DependencyGraph:New()
    self.types = {}
    self:RegisterType("GENERIC", {
        GetActions = function(goal)
            return {
                {
                    id = "goal:" .. goal.id .. ":manual",
                    type = "MANUAL",
                    goalId = goal.id,
                    title = goal.title,
                    metadata = {
                        estimatedMinutes = goal.metadata.estimatedMinutes or 30,
                    },
                },
            }
        end,
    })
    self:RegisterType("WEEKLY_COMPLETION", {
        Evaluate = function(goal, context)
            local required = tonumber(goal.target.requiredActivities) or 1
            required = math.max(1, math.floor(required))
            local activities = context:Get("weekly.activities")
            if type(activities) ~= "table" then
                return {
                    current = goal.progress.current or 0,
                    total = required,
                    availability = "UNAVAILABLE",
                    complete = false,
                }
            end
            local completed = 0
            for index = 1, #activities do
                local activity = activities[index]
                if type(activity) == "table" and type(activity.progress) == "number"
                    and type(activity.threshold) == "number" and activity.threshold > 0
                    and activity.progress >= activity.threshold then
                    completed = completed + 1
                end
            end
            return {
                current = completed,
                total = required,
                availability = "AVAILABLE",
                complete = completed >= required,
            }
        end,
        GetActions = function(goal)
            if goal.progress.availability ~= "AVAILABLE" then return {} end
            return {
                {
                    id = "goal:" .. goal.id .. ":weekly",
                    type = "WEEKLY_ACTIVITY",
                    goalId = goal.id,
                    title = goal.title,
                    metadata = {
                        completedActivities = goal.progress.current,
                        requiredActivities = goal.progress.total,
                        estimatedMinutes = goal.metadata.estimatedMinutes or 30,
                    },
                },
            }
        end,
    })
    self.dependencies:Rebuild(getGoalsDatabase().items)
    self:EvaluateAll("initialize")
    Cortex:GetService("Commands"):Register({
        id = "weekly.create-goal",
        title = Cortex:GetText("COMMAND_CREATE_WEEKLY_GOAL"),
        subtitle = Cortex:GetText("COMMAND_CREATE_WEEKLY_GOAL_SUBTITLE"),
        keywords = { "weekly", "vault", "goal" },
        execute = function() return GoalEngine:CreateWeeklyCompletionGoal(1) ~= nil end,
    })
end

function GoalEngine:Enable()
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.CONTEXT_UPDATED, self, self.OnContextUpdated)
end

function GoalEngine:Disable()
    Cortex.Events:UnsubscribeOwner(self)
end

function GoalEngine:OnContextUpdated(collectorName)
    if collectorName == "Weekly" then self:EvaluateAll("weekly-context") end
end

function GoalEngine:RegisterType(typeId, definition)
    if type(typeId) ~= "string" or typeId == "" or type(definition) ~= "table" then return false end
    typeId = string.upper(typeId)
    if definition.Evaluate ~= nil and type(definition.Evaluate) ~= "function" then return false end
    if definition.GetActions ~= nil and type(definition.GetActions) ~= "function" then return false end
    self.types[typeId] = definition
    return true
end

function GoalEngine:Add(title)
    return self:AddGoal({ title = title, type = "GENERIC" })
end

function GoalEngine:AddGoal(specification)
    local goals = getGoalsDatabase()
    local goal = Cortex.Goal.Create(goals.nextId, specification)
    if not goal or not self.types[goal.type] then return nil end

    goals.items[goal.id] = goal
    goals.nextId = goal.id + 1
    self.dependencies:Rebuild(goals.items)
    local automaticallyCompleted = self:EvaluateGoal(goal)
    Cortex:GetService("Database"):RefreshUnfinishedGoals()
    Cortex:GetService("Database"):AppendHistory("goal-added", { goalId = goal.id })
    if automaticallyCompleted then
        Cortex:GetService("Database"):AppendHistory("goal-completed", {
            goalId = goal.id, automatic = true,
        })
    end
    publishChanged("added", goal)
    return goal
end

function GoalEngine:CreateWeeklyCompletionGoal(requiredActivities)
    requiredActivities = tonumber(requiredActivities) or 1
    requiredActivities = math.max(1, math.floor(requiredActivities))
    return self:AddGoal({
        type = "WEEKLY_COMPLETION",
        title = Cortex:GetText("WEEKLY_GOAL_TITLE"),
        description = Cortex:GetText("WEEKLY_GOAL_DESCRIPTION"),
        target = { requiredActivities = requiredActivities },
        metadata = { estimatedMinutes = 30 },
    })
end

function GoalEngine:Complete(id)
    local goal = getGoalsDatabase().items[id]
    if not goal or Cortex.Goal.IsCompleted(goal) or goal.status == STATUSES.FAILED then return false end

    goal.status = STATUSES.COMPLETED
    goal.completedAt = time()
    self.dependencies:Rebuild(getGoalsDatabase().items)
    self:EvaluateAll("dependency-completed")
    Cortex:GetService("Database"):RefreshUnfinishedGoals()
    Cortex:GetService("Database"):AppendHistory("goal-completed", { goalId = goal.id })
    publishChanged("completed", goal)
    return true
end

function GoalEngine:SetDependencies(goalId, dependencyIds)
    self.dependencies:Rebuild(getGoalsDatabase().items)
    local ok, reason, dependencyId = self.dependencies:SetDependencies(goalId, dependencyIds)
    if not ok then return false, reason, dependencyId end
    self:EvaluateAll("dependencies-changed")
    Cortex:GetService("Database"):RefreshUnfinishedGoals()
    Cortex:GetService("Database"):AppendHistory("goal-dependencies-changed", { goalId = goalId })
    publishChanged("dependencies", getGoalsDatabase().items[goalId])
    return true
end

function GoalEngine:EvaluateGoal(goal)
    local definition = self.types[goal.type]
    if not definition or type(definition.Evaluate) ~= "function" or Cortex.Goal.IsCompleted(goal) then return false end
    local ok, result = pcall(definition.Evaluate, goal, Cortex:GetService("Context"))
    if not ok or type(result) ~= "table" then return false end
    Cortex.Goal.SetProgress(goal, result.current or 0, result.total or 1,
        result.availability or "UNAVAILABLE", time())
    if result.complete then
        goal.status = STATUSES.COMPLETED
        goal.completedAt = time()
        return true
    end
    return false
end

function GoalEngine:EvaluateAll(reason)
    local items = getGoalsDatabase().items
    local changed, completed = false, {}
    local maximumPasses, pass = math.max(1, self:GetGoalCount() + 1), 0
    repeat
        pass = pass + 1
        local completedThisPass = false
        self.dependencies:Rebuild(items)
        for _, goal in pairs(items) do
            if not Cortex.Goal.IsCompleted(goal) and goal.status ~= STATUSES.PAUSED and goal.status ~= STATUSES.FAILED then
                local nextStatus = #self.dependencies:GetBlockers(goal.id) > 0 and STATUSES.BLOCKED or STATUSES.ACTIVE
                if goal.status ~= nextStatus then goal.status, changed = nextStatus, true end
                if nextStatus == STATUSES.ACTIVE then
                    local beforeCurrent = goal.progress.current
                    local beforeAvailability = goal.progress.availability
                    if self:EvaluateGoal(goal) then
                        completed[#completed + 1] = goal
                        completedThisPass, changed = true, true
                    elseif beforeCurrent ~= goal.progress.current or beforeAvailability ~= goal.progress.availability then
                        changed = true
                    end
                end
            end
        end
    until not completedThisPass or pass >= maximumPasses
    self.dependencies:Rebuild(items)
    if changed then
        Cortex:GetService("Database"):RefreshUnfinishedGoals()
        for index = 1, #completed do
            Cortex:GetService("Database"):AppendHistory("goal-completed", {
                goalId = completed[index].id, automatic = true,
            })
        end
        publishChanged("evaluated:" .. (reason or "unknown"), nil)
    end
    return changed
end

function GoalEngine:GetGoal(id)
    return getGoalsDatabase().items[id]
end

function GoalEngine:GetGoals()
    local goals = {}
    for _, goal in pairs(getGoalsDatabase().items) do goals[#goals + 1] = goal end
    table.sort(goals, function(left, right) return left.id < right.id end)
    return goals
end

function GoalEngine:GetActiveGoals()
    local activeGoals = {}
    for _, goal in pairs(getGoalsDatabase().items) do
        if Cortex.Goal.IsActive(goal) then
            activeGoals[#activeGoals + 1] = goal
        end
    end

    table.sort(activeGoals, function(left, right)
        return left.id < right.id
    end)
    return activeGoals
end

function GoalEngine:GetActiveCount()
    return #self:GetActiveGoals()
end

function GoalEngine:GetGoalCount()
    local count = 0
    for _ in pairs(getGoalsDatabase().items) do count = count + 1 end
    return count
end

function GoalEngine:RefreshDependencyGraph()
    self.dependencies:Rebuild(getGoalsDatabase().items)
    return self.dependencies
end

function GoalEngine:GetBlockers(goalId, useCurrentGraph)
    if not useCurrentGraph then self:RefreshDependencyGraph() end
    return self.dependencies:GetBlockers(goalId)
end

function GoalEngine:GetAvailableActions(goalId, useCurrentGraph)
    if not Cortex.Schema.IsPositiveInteger(goalId) then return {} end
    if not useCurrentGraph then self:RefreshDependencyGraph() end
    local ids = self.dependencies:GetAvailableGoalIds(goalId)
    local actions = {}
    for index = 1, #ids do
        local goal = getGoalsDatabase().items[ids[index]]
        local definition = goal and self.types[goal.type]
        if definition and type(definition.GetActions) == "function" then
            local ok, generated = pcall(definition.GetActions, goal)
            if ok and type(generated) == "table" then
                for actionIndex = 1, #generated do actions[#actions + 1] = generated[actionIndex] end
            end
        end
    end
    return actions
end

function GoalEngine:GetDirectActions(goalId)
    if not Cortex.Schema.IsPositiveInteger(goalId) then return {} end
    local goal = getGoalsDatabase().items[goalId]
    if not goal or Cortex.Goal.IsCompleted(goal) or goal.status == STATUSES.PAUSED
        or goal.status == STATUSES.FAILED then return {} end
    local definition = self.types[goal.type]
    if not definition or type(definition.GetActions) ~= "function" then return {} end
    local ok, actions = pcall(definition.GetActions, goal)
    if not ok or type(actions) ~= "table" then return {} end
    return Cortex.Schema.Copy(actions)
end

function GoalEngine:DebugSnapshot()
    self:RefreshDependencyGraph()
    local snapshot = { total = 0, statuses = {}, diagnostics = self.dependencies:GetDiagnostics(), goals = {} }
    for _, goal in ipairs(self:GetGoals()) do
        snapshot.total = snapshot.total + 1
        snapshot.statuses[goal.status] = (snapshot.statuses[goal.status] or 0) + 1
        snapshot.goals[#snapshot.goals + 1] = {
            id = goal.id,
            type = goal.type,
            status = goal.status,
            progress = Cortex.Schema.Copy(goal.progress),
            dependencies = self.dependencies:GetDependencies(goal.id),
            blockers = self.dependencies:GetBlockers(goal.id),
            availableActions = #self:GetAvailableActions(goal.id, true),
        }
    end
    return snapshot
end

function GoalEngine:GetDependencyGraph()
    return self.dependencies
end

Cortex:RegisterModule("Goals", GoalEngine, {
    services = { "Database", "Events", "Context", "Commands" },
}, {
    defaultEnabled = true,
})
