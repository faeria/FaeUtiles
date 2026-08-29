local _, Cortex = ...

local DependencyGraph = {}
DependencyGraph.__index = DependencyGraph

function DependencyGraph:New()
    return setmetatable({ goals = {}, dependencies = {}, diagnostics = {} }, self)
end

function DependencyGraph:Rebuild(goals)
    self.goals = type(goals) == "table" and goals or {}
    self.dependencies = {}
    self.diagnostics = { cycles = {}, missing = {}, completedDependencies = {} }

    for goalId, goal in pairs(self.goals) do
        local dependencies = {}
        for index = 1, #(goal.dependencies or {}) do
            local dependencyId = goal.dependencies[index]
            dependencies[#dependencies + 1] = dependencyId
            local dependency = self.goals[dependencyId]
            if not dependency then
                self.diagnostics.missing[#self.diagnostics.missing + 1] = {
                    goalId = goalId, dependencyId = dependencyId,
                }
            elseif Cortex.Goal.IsCompleted(dependency) then
                self.diagnostics.completedDependencies[#self.diagnostics.completedDependencies + 1] = {
                    goalId = goalId, dependencyId = dependencyId,
                }
            end
        end
        self.dependencies[goalId] = dependencies
    end

    local colors = {}
    local function visit(goalId)
        colors[goalId] = 1
        for index = 1, #(self.dependencies[goalId] or {}) do
            local dependencyId = self.dependencies[goalId][index]
            if self.goals[dependencyId] then
                if colors[dependencyId] == 1 then
                    self.diagnostics.cycles[#self.diagnostics.cycles + 1] = {
                        goalId = goalId, dependencyId = dependencyId,
                    }
                elseif colors[dependencyId] ~= 2 then
                    visit(dependencyId)
                end
            end
        end
        colors[goalId] = 2
    end
    for goalId in pairs(self.goals) do if not colors[goalId] then visit(goalId) end end
    return self.diagnostics
end

function DependencyGraph:SetDependencies(goalId, dependencyIds)
    local goal = self.goals[goalId]
    if not goal or type(dependencyIds) ~= "table" then return false, "goal-not-found" end

    local copy, seen = {}, {}
    for index = 1, #dependencyIds do
        local dependencyId = dependencyIds[index]
        if not Cortex.Schema.IsPositiveInteger(dependencyId) then return false, "invalid-dependency" end
        if not self.goals[dependencyId] then return false, "missing-dependency", dependencyId end
        if seen[dependencyId] then return false, "duplicate-dependency", dependencyId end
        copy[#copy + 1], seen[dependencyId] = dependencyId, true
    end

    local previous = goal.dependencies
    goal.dependencies = copy
    self:Rebuild(self.goals)
    if #self.diagnostics.cycles > 0 then
        goal.dependencies = previous
        self:Rebuild(self.goals)
        return false, "cycle"
    end
    return true
end

function DependencyGraph:GetDependencies(goalId)
    return Cortex.Schema.Copy(self.dependencies[goalId] or {})
end

function DependencyGraph:GetDiagnostics()
    return Cortex.Schema.Copy(self.diagnostics)
end

function DependencyGraph:GetBlockers(goalId)
    local blockers, seen = {}, {}
    local function add(dependencyId, reason)
        if seen[dependencyId] then return end
        blockers[#blockers + 1] = { goalId = dependencyId, reason = reason }
        seen[dependencyId] = true
    end
    for index = 1, #(self.dependencies[goalId] or {}) do
        local dependencyId = self.dependencies[goalId][index]
        local dependency = self.goals[dependencyId]
        if not dependency then
            add(dependencyId, "MISSING")
        elseif not Cortex.Goal.IsCompleted(dependency) then
            add(dependencyId, dependency.status)
        end
    end
    for index = 1, #(self.diagnostics.cycles or {}) do
        local cycle = self.diagnostics.cycles[index]
        if cycle.goalId == goalId then add(cycle.dependencyId, "CYCLE") end
    end
    return blockers
end

function DependencyGraph:GetAvailableGoalIds(goalId)
    local available, seen, visiting = {}, {}, {}
    local function visit(candidateId)
        if visiting[candidateId] then return end
        local goal = self.goals[candidateId]
        if not goal or Cortex.Goal.IsCompleted(goal)
            or goal.status == Cortex.Constants.GOAL_STATUSES.PAUSED
            or goal.status == Cortex.Constants.GOAL_STATUSES.FAILED then return end
        visiting[candidateId] = true
        local hasOpenDependency, hasInvalidDependency = false, false
        for index = 1, #(self.dependencies[candidateId] or {}) do
            local dependency = self.goals[self.dependencies[candidateId][index]]
            if not dependency then
                hasInvalidDependency = true
            elseif not Cortex.Goal.IsCompleted(dependency) then
                hasOpenDependency = true
                visit(dependency.id)
            end
        end
        visiting[candidateId] = nil
        if not hasOpenDependency and not hasInvalidDependency and not seen[candidateId] then
            available[#available + 1], seen[candidateId] = candidateId, true
        end
    end
    visit(goalId)
    table.sort(available)
    return available
end

Cortex.DependencyGraph = DependencyGraph
