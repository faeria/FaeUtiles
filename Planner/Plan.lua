local _, Cortex = ...

local Plan = {}
Plan.__index = Plan

function Plan.Create(budgetMinutes, currentLocation)
    return setmetatable({
        budgetMinutes = budgetMinutes, isUnlimited = budgetMinutes == nil, estimatedMinutes = 0,
        remainingMinutes = budgetMinutes, currentLocation = Cortex.Schema.Copy(currentLocation), skipped = {},
    }, Plan)
end

function Plan:Add(candidate, selectionReason)
    local entry = Cortex.PlanEntry.Create(candidate, selectionReason)
    if not entry then return false end
    self[#self + 1] = entry
    self.estimatedMinutes = self.estimatedMinutes + entry.estimatedMinutes
    if self.budgetMinutes then self.remainingMinutes = self.budgetMinutes - self.estimatedMinutes end
    return true
end

function Plan:AddSkipped(candidateId, reason)
    self.skipped[#self.skipped + 1] = { id = candidateId, reason = reason }
end

function Plan:GetEntries() return self end
function Plan:GetTotalEstimatedMinutes() return self.estimatedMinutes end
function Plan:GetRemainingMinutes() return self.remainingMinutes end
function Plan:CanFit(minutes)
    return self.isUnlimited or self.estimatedMinutes + minutes <= self.budgetMinutes
end

Cortex.Plan = Plan
