local _, Cortex = ...

local DurationEstimator = {}

local function validMinutes(value)
    return type(value) == "number" and Cortex:IsAccessibleValue(value) and value > 0
end

local function normalizeMinutes(value)
    return math.max(1, math.min(480, math.floor(value + 0.5)))
end

function DurationEstimator:Estimate(candidate)
    candidate = type(candidate) == "table" and candidate or {}
    local recommendation = type(candidate.recommendation) == "table" and candidate.recommendation or {}
    local action = type(candidate.action) == "table" and candidate.action or {}
    local goal = type(candidate.goal) == "table" and candidate.goal or {}
    local sources = {}
    if recommendation.actionable then
        sources[#sources + 1] = { value = recommendation.estimatedMinutes, source = "recommendation" }
        sources[#sources + 1] = { value = recommendation.metadata and recommendation.metadata.estimatedMinutes,
            source = "recommendation-metadata" }
    end
    sources[#sources + 1] = { value = action.metadata and action.metadata.estimatedMinutes, source = "action" }
    sources[#sources + 1] = { value = goal.metadata and goal.metadata.estimatedMinutes, source = "goal" }
    for index = 1, #sources do
        if validMinutes(sources[index].value) then
            return { minutes = normalizeMinutes(sources[index].value), source = sources[index].source,
                isEstimate = true }
        end
    end
    return { minutes = 30, source = "fallback", isEstimate = true }
end

Cortex:RegisterService("DurationEstimator", DurationEstimator)
