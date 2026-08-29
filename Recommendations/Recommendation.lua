local _, Cortex = ...

local Recommendation = {}
Recommendation.__index = Recommendation

function Recommendation:GetReason()
    return self.reason
end

function Recommendation:GetScoreBreakdown()
    return self.metadata and self.metadata.scoreBreakdown or nil
end

function Recommendation:GetFactKeys()
    local detective = self.metadata and self.metadata.detective
    return Cortex.Schema.Copy(type(detective) == "table" and detective.factKeys or {})
end

function Recommendation.Normalize(candidate)
    if type(candidate) ~= "table"
        or type(candidate.id) ~= "string"
        or candidate.id == ""
        or type(candidate.ruleId) ~= "string"
        or candidate.ruleId == ""
        or type(candidate.title) ~= "string"
        or candidate.title == ""
        or type(candidate.description) ~= "string"
        or type(candidate.reason) ~= "string"
        or candidate.reason == "" then
        return nil
    end

    local priority = type(candidate.priority) == "number" and candidate.priority or 0
    priority = math.max(0, math.min(100, priority))
    local score = type(candidate.score) == "number" and candidate.score or priority
    local metadata = Cortex.Schema.Copy(type(candidate.metadata) == "table" and candidate.metadata or {})
    local estimatedMinutes = metadata.estimatedMinutes
    if type(estimatedMinutes) ~= "number" or estimatedMinutes <= 0 then
        estimatedMinutes = 30
    end

    return setmetatable({
        id = candidate.id,
        ruleId = candidate.ruleId,
        title = candidate.title,
        description = candidate.description,
        category = type(candidate.category) == "string" and candidate.category or "GENERAL",
        priority = priority,
        score = score,
        reason = candidate.reason,
        benefit = type(candidate.benefit) == "string" and candidate.benefit or "",
        goalId = Cortex.Schema.IsPositiveInteger(candidate.goalId) and candidate.goalId or nil,
        actionable = candidate.actionable == true,
        blockers = Cortex.Schema.Copy(type(candidate.blockers) == "table" and candidate.blockers or {}),
        metadata = metadata,
        estimatedMinutes = estimatedMinutes,
    }, Recommendation)
end

Cortex.Recommendation = Recommendation
