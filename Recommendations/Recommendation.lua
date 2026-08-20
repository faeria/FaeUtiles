local _, Cortex = ...

local Recommendation = {}

function Recommendation.Normalize(candidate)
    if type(candidate) ~= "table"
        or type(candidate.id) ~= "string"
        or type(candidate.title) ~= "string"
        or type(candidate.description) ~= "string"
        or type(candidate.reason) ~= "string" then
        return nil
    end

    local priority = type(candidate.priority) == "number" and candidate.priority or 0
    local score = type(candidate.score) == "number" and candidate.score or priority
    local metadata = type(candidate.metadata) == "table" and candidate.metadata or {}
    local estimatedMinutes = metadata.estimatedMinutes
    if type(estimatedMinutes) ~= "number" or estimatedMinutes <= 0 then
        estimatedMinutes = 30
    end

    return {
        id = candidate.id,
        title = candidate.title,
        description = candidate.description,
        category = type(candidate.category) == "string" and candidate.category or "GENERAL",
        priority = priority,
        score = score,
        reason = candidate.reason,
        benefit = type(candidate.benefit) == "string" and candidate.benefit or "",
        goalId = candidate.goalId,
        actionable = candidate.actionable == true,
        blockers = type(candidate.blockers) == "table" and candidate.blockers or {},
        metadata = metadata,
        estimatedMinutes = estimatedMinutes,
    }
end

Cortex.Recommendation = Recommendation
