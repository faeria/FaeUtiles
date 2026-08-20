local _, Cortex = ...

local GoalEngine = {}

local function getGoalsDatabase()
    return Cortex:GetService("Database"):GetAccount().goals
end

local function publishChanged(action, goal)
    Cortex.Events:Publish(Cortex.Constants.EVENTS.GOALS_CHANGED, action, goal)
end

function GoalEngine:Initialize()
    self.dependencies = Cortex.DependencyGraph:New()
end

function GoalEngine:Add(title)
    if type(title) ~= "string" or title == "" then
        return nil
    end

    local goals = getGoalsDatabase()
    local goal = Cortex.Goal.Create(goals.nextId, title)
    if not goal then
        return nil
    end

    goals.items[goal.id] = goal
    goals.nextId = goal.id + 1
    publishChanged("added", goal)
    return goal
end

function GoalEngine:Complete(id)
    local goal = getGoalsDatabase().items[id]
    if not Cortex.Goal.IsActive(goal) then
        return false
    end

    goal.status = "completed"
    goal.completedAt = time()
    publishChanged("completed", goal)
    return true
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

function GoalEngine:GetDependencyGraph()
    return self.dependencies
end

Cortex:RegisterModule("Goals", GoalEngine, {
    services = { "Database", "Events" },
}, {
    defaultEnabled = true,
})
