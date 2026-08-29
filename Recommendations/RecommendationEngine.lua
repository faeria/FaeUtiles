local _, Cortex = ...

local RecommendationEngine = {
    isDirty = true,
    cache = {},
}

function RecommendationEngine:Initialize()
    self.isDirty = true
    self.cache = {}
    Cortex:GetService("Commands"):Register({
        id = "recommendations.open",
        title = Cortex:GetText("COMMAND_OPEN_RECOMMENDATIONS"),
        subtitle = Cortex:GetText("COMMAND_OPEN_RECOMMENDATIONS_SUBTITLE"),
        keywords = { "recommend", "next", "action" },
        execute = function()
            Cortex:GetService("Navigation"):GoTo("overview")
            Cortex:GetService("MainWindow"):Show()
        end,
    })
end

function RecommendationEngine:Enable()
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.GOALS_CHANGED, self, self.OnGoalsChanged)
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.CONTEXT_UPDATED, self, self.OnContextUpdated)
    self:Invalidate("enable")
end

function RecommendationEngine:Disable()
    Cortex.Events:UnsubscribeOwner(self)
    self.cache = {}
    self.isDirty = true
end

function RecommendationEngine:OnGoalsChanged()
    self:Invalidate("goals")
end

function RecommendationEngine:OnContextUpdated(source, _, changedKeys)
    if Cortex:GetService("Rules"):UsesContextChange(source, changedKeys) then
        self:Invalidate("context:" .. source)
    end
end

function RecommendationEngine:Invalidate(reason)
    if self.isDirty then return false end
    self.isDirty = true
    Cortex:GetService("Logger"):Trace(Cortex:GetText("RECOMMENDATIONS_INVALIDATED_TRACE", reason or "unknown"))
    Cortex.Events:Publish(Cortex.Constants.EVENTS.RECOMMENDATIONS_INVALIDATED, reason)
    return true
end

function RecommendationEngine:Rebuild()
    local profiler = Cortex:GetService("Profiler")
    local startedAt = profiler:Start()
    local context = Cortex:GetService("Context")
    local goals = Cortex:GetModule("Goals")
    goals:RefreshDependencyGraph()
    local candidates = Cortex:GetService("Rules"):Evaluate(context, goals)
    local recommendations, seen = {}, {}

    for index = 1, #candidates do
        local recommendation = Cortex.Recommendation.Normalize(candidates[index])
        if recommendation and not seen[recommendation.id] then
            recommendations[#recommendations + 1] = recommendation
            seen[recommendation.id] = true
        end
    end

    self.cache = Cortex.Prioritizer.Sort(recommendations)
    self.isDirty = false
    profiler:Stop("recommendation", "rebuild", startedAt)
end

function RecommendationEngine:DebugSnapshot()
    local recommendations = self:GetRecommendations()
    local snapshot = {
        count = #recommendations,
        ruleCount = #Cortex:GetService("Rules"):GetRules(),
        diagnostics = Cortex:GetService("Rules"):GetDiagnostics(),
        recommendations = {},
    }
    for index = 1, #recommendations do
        local recommendation = recommendations[index]
        snapshot.recommendations[index] = {
            id = recommendation.id,
            ruleId = recommendation.ruleId,
            score = recommendation.score,
            actionable = recommendation.actionable,
            blockerCount = #recommendation.blockers,
            reason = recommendation:GetReason(),
            scoreBreakdown = Cortex.Schema.Copy(recommendation:GetScoreBreakdown()),
        }
    end
    return snapshot
end

function RecommendationEngine:GetRecommendations()
    if self.isDirty then
        self:Rebuild()
    end
    return self.cache
end

function RecommendationEngine:GetRecommendation(id)
    if type(id) ~= "string" or id == "" then return nil end
    for _, recommendation in ipairs(self:GetRecommendations()) do
        if recommendation.id == id then return recommendation end
    end
    return nil
end

Cortex:RegisterModule("Recommendations", RecommendationEngine, {
    services = { "Logger", "Profiler", "Events", "Rules", "Context", "Commands", "Navigation" },
    modules = { "Goals" },
}, {
    defaultEnabled = true,
})
