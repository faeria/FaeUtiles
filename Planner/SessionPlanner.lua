local _, Cortex = ...

local SessionPlanner = {}

function SessionPlanner:Build(minutes)
    local remainingMinutes = minutes
    local plan = {}
    local recommendations = Cortex:GetModule("Recommendations"):GetRecommendations()

    for index = 1, #recommendations do
        local recommendation = recommendations[index]
        if recommendation.actionable
            and #recommendation.blockers == 0
            and recommendation.estimatedMinutes <= remainingMinutes then
            plan[#plan + 1] = recommendation
            remainingMinutes = remainingMinutes - recommendation.estimatedMinutes
        end
    end

    return plan, remainingMinutes
end

Cortex:RegisterModule("Planner", SessionPlanner, {
    modules = { "Recommendations" },
}, {
    defaultEnabled = true,
})
