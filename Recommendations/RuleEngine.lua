local _, Cortex = ...

local RuleEngine = {
    rules = {},
}

function RuleEngine:Register(id, evaluate)
    if type(id) ~= "string" or type(evaluate) ~= "function" then
        return false
    end

    self.rules[#self.rules + 1] = {
        id = id,
        evaluate = evaluate,
    }
    return true
end

function RuleEngine:Evaluate(facts)
    local candidates = {}

    for index = 1, #self.rules do
        local generated = self.rules[index].evaluate(facts)
        if type(generated) == "table" then
            for candidateIndex = 1, #generated do
                candidates[#candidates + 1] = generated[candidateIndex]
            end
        end
    end

    return candidates
end

RuleEngine:Register("define-first-goal", function(facts)
    if #facts.activeGoals > 0 then
        return {}
    end

    return {
        {
            id = "onboarding:define-goal",
            title = Cortex:GetText("RECOMMENDATION_DEFINE_GOAL_TITLE"),
            description = Cortex:GetText("RECOMMENDATION_DEFINE_GOAL_DESCRIPTION"),
            category = "GOALS",
            priority = 100,
            score = 100,
            reason = Cortex:GetText("RECOMMENDATION_DEFINE_GOAL_REASON"),
            benefit = Cortex:GetText("RECOMMENDATION_DEFINE_GOAL_BENEFIT"),
            actionable = true,
            blockers = {},
            metadata = {
                estimatedMinutes = 5,
                command = "/cortex goal add <title>",
            },
        },
    }
end)

RuleEngine:Register("advance-active-goals", function(facts)
    local generated = {}

    for index = 1, #facts.activeGoals do
        local goal = facts.activeGoals[index]
        local priority = type(goal.priority) == "number" and goal.priority or 50
        local estimatedMinutes = type(goal.estimatedMinutes) == "number" and goal.estimatedMinutes or 30

        generated[#generated + 1] = {
            id = "goal:" .. goal.id,
            title = Cortex:GetText("RECOMMENDATION_ADVANCE_GOAL_TITLE", goal.title),
            description = Cortex:GetText("RECOMMENDATION_ADVANCE_GOAL_DESCRIPTION"),
            category = "GOALS",
            priority = priority,
            score = priority,
            reason = Cortex:GetText("RECOMMENDATION_ADVANCE_GOAL_REASON"),
            benefit = Cortex:GetText("RECOMMENDATION_ADVANCE_GOAL_BENEFIT"),
            goalId = goal.id,
            actionable = true,
            blockers = {},
            metadata = {
                estimatedMinutes = estimatedMinutes,
            },
        }
    end

    return generated
end)

Cortex.RuleEngine = RuleEngine
Cortex:RegisterService("Rules", RuleEngine)
