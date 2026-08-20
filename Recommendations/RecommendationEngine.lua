local _, Cortex = ...

local RecommendationEngine = {
    isDirty = true,
    cache = {},
}

function RecommendationEngine:Initialize()
    self.isDirty = true
    self.cache = {}
end

function RecommendationEngine:Enable()
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.GOALS_CHANGED, self, self.OnSourceChanged)
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.CONTEXT_UPDATED, self, self.OnSourceChanged)
    self:Invalidate("enable")
end

function RecommendationEngine:Disable()
    Cortex.Events:UnsubscribeOwner(self)
    self.cache = {}
    self.isDirty = true
end

function RecommendationEngine:OnSourceChanged()
    self:Invalidate("source")
end

function RecommendationEngine:Invalidate(reason)
    self.isDirty = true
    Cortex:GetService("Logger"):Trace(Cortex:GetText("RECOMMENDATIONS_INVALIDATED_TRACE", reason or "unknown"))
    Cortex.Events:Publish(Cortex.Constants.EVENTS.RECOMMENDATIONS_INVALIDATED, reason)
end

function RecommendationEngine:Rebuild()
    local facts = {
        activeGoals = Cortex:GetModule("Goals"):GetActiveGoals(),
        currentCharacter = Cortex:GetService("Context"):GetCurrentCharacter(),
    }
    local candidates = Cortex:GetService("Rules"):Evaluate(facts)
    local recommendations = {}

    for index = 1, #candidates do
        local recommendation = Cortex.Recommendation.Normalize(candidates[index])
        if recommendation then
            recommendations[#recommendations + 1] = recommendation
        end
    end

    self.cache = Cortex.Prioritizer.Sort(recommendations)
    self.isDirty = false
end

function RecommendationEngine:GetRecommendations()
    if self.isDirty then
        self:Rebuild()
    end
    return self.cache
end

Cortex:RegisterModule("Recommendations", RecommendationEngine, {
    services = { "Logger", "Events", "Rules", "Context" },
    modules = { "Goals" },
}, {
    defaultEnabled = true,
})
