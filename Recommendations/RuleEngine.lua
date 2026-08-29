local _, Cortex = ...

local RuleEngine = {
    rules = {},
    byId = {},
    contextSources = {},
    rulesByContextSource = {},
    diagnostics = {},
}

function RuleEngine:Register(rule)
    if type(rule) ~= "table" or type(rule.id) ~= "string" or rule.id == ""
        or self.byId[rule.id] or type(rule.evaluate) ~= "function"
        or (rule.conditions ~= nil and type(rule.conditions) ~= "function")
        or (rule.buildRecommendation ~= nil and type(rule.buildRecommendation) ~= "function") then return false end
    rule.category = type(rule.category) == "string" and rule.category or "GENERAL"
    rule.priority = type(rule.priority) == "number" and rule.priority or 50
    rule.factKeys = type(rule.factKeys) == "table" and Cortex.Schema.Copy(rule.factKeys) or {}
    for index = #rule.factKeys, 1, -1 do
        if type(rule.factKeys[index]) ~= "string" or rule.factKeys[index] == "" then
            table.remove(rule.factKeys, index)
        end
    end
    table.sort(rule.factKeys)
    rule.contextSources = type(rule.contextSources) == "table"
        and Cortex.Schema.Copy(rule.contextSources) or {}
    local seenSources = {}
    for index = #rule.contextSources, 1, -1 do
        local source = rule.contextSources[index]
        if type(source) ~= "string" or source == "" or seenSources[source] then
            table.remove(rule.contextSources, index)
        else
            seenSources[source] = true
            self.contextSources[source] = true
            local sourceRules = self.rulesByContextSource[source]
            if not sourceRules then sourceRules = {}; self.rulesByContextSource[source] = sourceRules end
            sourceRules[#sourceRules + 1] = rule
        end
    end
    table.sort(rule.contextSources)
    self.rules[#self.rules + 1] = rule
    self.byId[rule.id] = rule
    return true
end

function RuleEngine:UsesContextSource(source)
    return type(source) == "string" and self.contextSources[source] == true
end

function RuleEngine:UsesContextChange(source, changedKeys)
    local sourceRules = type(source) == "string" and self.rulesByContextSource[source] or nil
    if not sourceRules then return false end
    if type(changedKeys) ~= "table" then return true end

    local changed = {}
    for index = 1, #changedKeys do
        if type(changedKeys[index]) == "string" then changed[changedKeys[index]] = true end
    end
    for ruleIndex = 1, #sourceRules do
        local factKeys = sourceRules[ruleIndex].factKeys
        if #factKeys == 0 then return true end
        for keyIndex = 1, #factKeys do
            if changed[factKeys[keyIndex]] then return true end
        end
    end
    return false
end

function RuleEngine:Evaluate(context, goals)
    local candidates = {}
    self.diagnostics = {}

    for index = 1, #self.rules do
        local rule = self.rules[index]
        local applies, conditionError = true, false
        if rule.conditions then
            local ok, result = pcall(rule.conditions, context, goals)
            applies, conditionError = ok and result == true, not ok
        end
        if conditionError then
            self.diagnostics[#self.diagnostics + 1] = { ruleId = rule.id, stage = "conditions" }
        elseif applies then
            local ok, matches = pcall(rule.evaluate, context, goals)
            if not ok then
                self.diagnostics[#self.diagnostics + 1] = { ruleId = rule.id, stage = "evaluate" }
            elseif type(matches) == "table" then
                for matchIndex = 1, #matches do
                    local buildOk, candidate = true, matches[matchIndex]
                    if rule.buildRecommendation then
                        buildOk, candidate = pcall(rule.buildRecommendation,
                            matches[matchIndex], context, goals)
                    end
                    if buildOk and type(candidate) == "table" then
                        candidate.ruleId = rule.id
                        candidate.category = candidate.category or rule.category
                        candidate.priority = candidate.priority or rule.priority
                        candidate.metadata = type(candidate.metadata) == "table" and candidate.metadata or {}
                        candidate.metadata.detective = type(candidate.metadata.detective) == "table"
                            and candidate.metadata.detective or {}
                        candidate.metadata.detective.factKeys = Cortex.Schema.Copy(rule.factKeys)
                        candidates[#candidates + 1] = candidate
                    elseif not buildOk then
                        self.diagnostics[#self.diagnostics + 1] = {
                            ruleId = rule.id, stage = "buildRecommendation",
                        }
                    end
                end
            end
        end
    end

    return candidates
end

function RuleEngine:GetRules()
    local rules = {}
    for index = 1, #self.rules do
        rules[index] = {
            id = self.rules[index].id,
            category = self.rules[index].category,
            priority = self.rules[index].priority,
            factKeys = Cortex.Schema.Copy(self.rules[index].factKeys),
            contextSources = Cortex.Schema.Copy(self.rules[index].contextSources),
        }
    end
    return rules
end

function RuleEngine:GetRule(ruleId)
    local rule = self.byId[ruleId]
    if not rule then return nil end
    return {
        id = rule.id,
        category = rule.category,
        priority = rule.priority,
        factKeys = Cortex.Schema.Copy(rule.factKeys),
        contextSources = Cortex.Schema.Copy(rule.contextSources),
    }
end

function RuleEngine:GetDiagnostics()
    return Cortex.Schema.Copy(self.diagnostics)
end

Cortex.RuleEngine = RuleEngine
Cortex:RegisterService("Rules", RuleEngine)
