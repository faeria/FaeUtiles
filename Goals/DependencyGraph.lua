local _, Cortex = ...

local DependencyGraph = {}
DependencyGraph.__index = DependencyGraph

function DependencyGraph:New()
    return setmetatable({ dependencies = {} }, self)
end

function DependencyGraph:SetDependencies(goalId, dependencyIds)
    if type(goalId) ~= "number" or type(dependencyIds) ~= "table" then
        return false
    end

    local copy = {}
    for index = 1, #dependencyIds do
        if type(dependencyIds[index]) ~= "number" or dependencyIds[index] == goalId then
            return false
        end
        copy[index] = dependencyIds[index]
    end
    self.dependencies[goalId] = copy
    return true
end

function DependencyGraph:GetDependencies(goalId)
    return self.dependencies[goalId] or {}
end

Cortex.DependencyGraph = DependencyGraph
