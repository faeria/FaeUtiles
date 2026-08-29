local _, Cortex = ...

local Prioritizer = {
    factors = {},
    factorOrder = {},
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function Prioritizer.RegisterFactor(id, resolver)
    if type(id) ~= "string" or id == "" or type(resolver) ~= "function" or Prioritizer.factors[id] then
        return false
    end
    Prioritizer.factors[id] = resolver
    Prioritizer.factorOrder[#Prioritizer.factorOrder + 1] = id
    return true
end

Prioritizer.RegisterFactor("importance", function(scoring)
    return clamp(tonumber(scoring.importance) or 1, 0, 2)
end)
Prioritizer.RegisterFactor("goalRelevance", function(scoring)
    return clamp(tonumber(scoring.goalRelevance) or 1, 0, 2)
end)
Prioritizer.RegisterFactor("urgency", function(scoring)
    return clamp(tonumber(scoring.urgency) or 1, 0, 2)
end)
Prioritizer.RegisterFactor("efficiency", function(scoring)
    return clamp(tonumber(scoring.efficiency) or 1, 0, 2)
end)
Prioritizer.RegisterFactor("cost", function(scoring)
    local cost = clamp(tonumber(scoring.cost) or 0, 0, 2)
    return 1 / (1 + cost)
end)

function Prioritizer.Score(recommendation)
    local score = clamp(tonumber(recommendation.priority) or 0, 0, 100)
    local scoring = type(recommendation.metadata.scoring) == "table" and recommendation.metadata.scoring or {}
    local breakdown = { basePriority = score }
    for index = 1, #Prioritizer.factorOrder do
        local id = Prioritizer.factorOrder[index]
        local ok, multiplier = pcall(Prioritizer.factors[id], scoring, recommendation)
        multiplier = ok and type(multiplier) == "number" and clamp(multiplier, 0, 2) or 1
        breakdown[id] = multiplier
        score = score * multiplier
    end
    recommendation.score = math.floor(score * 100 + 0.5) / 100
    recommendation.metadata.scoreBreakdown = breakdown
    return recommendation.score
end

function Prioritizer.Sort(recommendations)
    for index = 1, #recommendations do Prioritizer.Score(recommendations[index]) end
    table.sort(recommendations, function(left, right)
        if left.score == right.score then
            return left.id < right.id
        end
        return left.score > right.score
    end)
    return recommendations
end

Cortex.Prioritizer = Prioritizer
