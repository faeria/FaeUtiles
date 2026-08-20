local _, Cortex = ...

local Prioritizer = {}

function Prioritizer.Sort(recommendations)
    table.sort(recommendations, function(left, right)
        if left.score == right.score then
            return left.id < right.id
        end
        return left.score > right.score
    end)
    return recommendations
end

Cortex.Prioritizer = Prioritizer
