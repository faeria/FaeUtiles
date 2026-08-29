local _, Cortex = ...

local PlanEntry = {}
PlanEntry.__index = PlanEntry

function PlanEntry:GetReason() return self.selectionReason end

function PlanEntry.Create(candidate, selectionReason)
    if type(candidate) ~= "table" or type(candidate.id) ~= "string" or candidate.id == ""
        or type(candidate.title) ~= "string" or candidate.title == ""
        or type(candidate.duration) ~= "table" or type(candidate.duration.minutes) ~= "number" then
        return nil
    end
    return setmetatable({
        id = candidate.id, title = candidate.title, description = candidate.description or "",
        category = candidate.category or "GENERAL", goalId = candidate.goalId,
        recommendationId = candidate.recommendationId, priority = candidate.priority or 0,
        priorityScore = candidate.adjustedScore or candidate.score or 0,
        estimatedMinutes = candidate.duration.minutes, durationIsEstimate = true,
        durationSource = candidate.duration.source, reason = selectionReason,
        selectionReason = selectionReason, benefit = candidate.benefit or "",
        dependencyGoalIds = Cortex.Schema.Copy(candidate.dependencyGoalIds or {}),
        locationMapID = candidate.locationMapID, isCurrentLocation = candidate.isCurrentLocation == true,
        metadata = Cortex.Schema.Copy(candidate.metadata or {}),
    }, PlanEntry)
end

Cortex.PlanEntry = PlanEntry
