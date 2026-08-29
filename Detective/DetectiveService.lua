local _, Cortex = ...

local DetectiveService = {}

local function countEntries(value)
    if type(value) ~= "table" then return nil end
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function factValueText(record)
    if type(record) ~= "table" or record.value == nil then
        return Cortex:GetText("DETECTIVE_VALUE_UNKNOWN")
    end
    local count = countEntries(record.value)
    if count ~= nil then return Cortex:GetText("DETECTIVE_VALUE_ENTRIES", count) end
    return nil
end

local function createFactEvidence(factKey)
    local record = Cortex:GetService("Facts"):GetRecord(factKey)
    return Cortex.Evidence.Create({
        id = "fact:" .. factKey,
        kind = "FACT",
        label = factKey,
        value = record and record.value or nil,
        valueText = factValueText(record),
        status = record and record.status or "unknown",
        source = record and record.source or nil,
        updatedAt = record and record.updatedAt or nil,
        factKey = factKey,
    })
end

local function factTraceNode(evidence)
    local source = evidence.source or Cortex:GetText("DETECTIVE_VALUE_UNKNOWN")
    local updatedAt = evidence.updatedAt or 0
    return {
        type = "FACT",
        id = evidence.factKey,
        details = Cortex:GetText("DETECTIVE_FACT_TRACE_DETAILS",
            string.upper(evidence.status), source, updatedAt),
    }
end

local function sortedFactKeys(recommendation)
    local keys = recommendation.GetFactKeys and recommendation:GetFactKeys() or {}
    table.sort(keys)
    return keys
end

local function resolveBlockers(rawBlockers)
    local blockers = {}
    local goals = Cortex:GetModule("Goals")
    for index = 1, #(rawBlockers or {}) do
        local raw = rawBlockers[index]
        if type(raw) == "table" then
            local goal = Cortex.Schema.IsPositiveInteger(raw.goalId) and goals:GetGoal(raw.goalId) or nil
            local required = type(raw.required) == "number" and raw.required or nil
            local available = type(raw.available) == "number" and raw.available or nil
            local missing = type(raw.missing) == "number" and raw.missing or nil
            if required and available then missing = math.max(0, required - available) end
            local reason = type(raw.reason) == "string" and raw.reason
                or (goal and goal.status) or "UNKNOWN"
            if required and available then
                reason = Cortex:GetText("DETECTIVE_RESOURCE_BLOCKER_REASON", required, available, missing)
            end
            local label = type(raw.label) == "string" and raw.label ~= "" and raw.label
                or (goal and goal.title)
                or Cortex:GetText("DETECTIVE_BLOCKER_FALLBACK", raw.goalId or index)
            blockers[#blockers + 1] = Cortex.Blocker.Create({
                id = type(raw.id) == "string" and raw.id ~= "" and raw.id
                    or "blocker:" .. tostring(raw.goalId or index),
                type = goal and "GOAL" or "STATE",
                label = label,
                reason = reason,
                goalId = raw.goalId,
                factKey = raw.factKey,
                required = required,
                available = available,
                missing = missing,
            })
        end
    end
    table.sort(blockers, function(left, right) return left.id < right.id end)
    return blockers
end

local function unknownExplanation(targetType, targetId)
    return Cortex.Explanation.Create({
        targetType = targetType,
        targetId = targetId,
        result = "UNKNOWN",
        reason = Cortex:GetText("DETECTIVE_TARGET_UNKNOWN"),
    })
end

function DetectiveService:ExplainRecommendation(candidate)
    local recommendation = candidate
    if type(candidate) == "string" then
        recommendation = Cortex:GetModule("Recommendations"):GetRecommendation(candidate)
    end
    if type(recommendation) ~= "table" or type(recommendation.id) ~= "string" then
        return unknownExplanation("RECOMMENDATION", candidate)
    end

    local evidence, conditions, trace = {}, {}, {}
    for _, factKey in ipairs(sortedFactKeys(recommendation)) do
        local item = createFactEvidence(factKey)
        evidence[#evidence + 1] = item
        conditions[#conditions + 1] = Cortex.Condition.Create({
            id = "fact-available:" .. factKey,
            label = Cortex:GetText("DETECTIVE_CONDITION_FACT_AVAILABLE", factKey),
            met = item.status == "available",
            expected = "available",
            actual = item.status,
            factKey = factKey,
            ruleId = recommendation.ruleId,
        })
        trace[#trace + 1] = factTraceNode(item)
    end
    local rule = Cortex:GetService("Rules"):GetRule(recommendation.ruleId)
    trace[#trace + 1] = {
        type = "RULE", id = recommendation.ruleId,
        details = rule and Cortex:GetText("DETECTIVE_RULE_TRACE_DETAILS",
            rule.category, rule.priority) or Cortex:GetText("DETECTIVE_VALUE_UNKNOWN"),
    }
    trace[#trace + 1] = {
        type = "RECOMMENDATION", id = recommendation.id,
        details = Cortex:GetText("DETECTIVE_RECOMMENDATION_TRACE_DETAILS", tostring(recommendation.score)),
    }
    if recommendation.goalId then
        trace[#trace + 1] = { type = "GOAL", id = recommendation.goalId, details = "" }
    end

    local blockers = resolveBlockers(recommendation.blockers)
    local result = recommendation.actionable and #blockers == 0 and "AVAILABLE" or "BLOCKED"
    conditions[#conditions + 1] = Cortex.Condition.Create({
        id = "recommendation:actionable",
        label = Cortex:GetText("DETECTIVE_CONDITION_ACTIONABLE"),
        met = recommendation.actionable == true,
        expected = true,
        actual = recommendation.actionable == true,
        ruleId = recommendation.ruleId,
    })
    return Cortex.Explanation.Create({
        targetType = "RECOMMENDATION",
        targetId = recommendation.id,
        title = recommendation.title,
        result = result,
        reason = recommendation:GetReason(),
        evidence = evidence,
        conditions = conditions,
        blockers = blockers,
        trace = trace,
    })
end

local function goalFactKeys(goal)
    if goal.type == "WEEKLY_COMPLETION" then return { "weekly.activities" } end
    return {}
end

local function goalResult(goal)
    if goal.status == Cortex.Constants.GOAL_STATUSES.ACTIVE then return "AVAILABLE" end
    return goal.status
end

function DetectiveService:ExplainGoal(candidate)
    local goal = candidate
    if type(candidate) == "number" then goal = Cortex:GetModule("Goals"):GetGoal(candidate) end
    if type(goal) ~= "table" or not Cortex.Schema.IsPositiveInteger(goal.id) then
        return unknownExplanation("GOAL", candidate)
    end

    local evidence, trace = {}, {}
    for _, factKey in ipairs(goalFactKeys(goal)) do
        local item = createFactEvidence(factKey)
        evidence[#evidence + 1] = item
        trace[#trace + 1] = factTraceNode(item)
    end
    evidence[#evidence + 1] = Cortex.Evidence.Create({
        id = "goal:status:" .. goal.id,
        kind = "GOAL",
        label = Cortex:GetText("DETECTIVE_GOAL_STATUS"),
        value = goal.status,
        valueText = goal.status,
        status = "available",
    })
    evidence[#evidence + 1] = Cortex.Evidence.Create({
        id = "goal:progress:" .. goal.id,
        kind = "GOAL",
        label = Cortex:GetText("DETECTIVE_GOAL_PROGRESS"),
        valueText = Cortex:GetText("DETECTIVE_PROGRESS_VALUE",
            goal.progress.current, goal.progress.total, goal.progress.availability),
        status = "available",
    })
    local blockers = resolveBlockers(Cortex:GetModule("Goals"):GetBlockers(goal.id))
    local reason
    if goal.status == Cortex.Constants.GOAL_STATUSES.BLOCKED then
        reason = Cortex:GetText("DETECTIVE_GOAL_BLOCKED_REASON", #blockers)
    elseif goal.status == Cortex.Constants.GOAL_STATUSES.COMPLETED then
        reason = Cortex:GetText("DETECTIVE_GOAL_COMPLETED_REASON")
    else
        reason = Cortex:GetText("DETECTIVE_GOAL_STATUS_REASON", goal.status)
    end
    trace[#trace + 1] = {
        type = "GOAL", id = goal.id,
        details = Cortex:GetText("DETECTIVE_GOAL_TRACE_DETAILS", goal.status),
    }
    return Cortex.Explanation.Create({
        targetType = "GOAL",
        targetId = goal.id,
        title = goal.title,
        result = goalResult(goal),
        reason = reason,
        evidence = evidence,
        blockers = blockers,
        trace = trace,
    })
end

function DetectiveService:ExplainFact(factKey)
    if type(factKey) ~= "string" or factKey == "" then
        return unknownExplanation("FACT", factKey)
    end
    local evidence = createFactEvidence(factKey)
    local reason = evidence.status == "unknown" and Cortex:GetText("DETECTIVE_FACT_UNKNOWN_REASON")
        or Cortex:GetText("DETECTIVE_FACT_STATUS_REASON", string.upper(evidence.status))
    return Cortex.Explanation.Create({
        targetType = "FACT",
        targetId = factKey,
        result = string.upper(evidence.status),
        reason = reason,
        evidence = { evidence },
        trace = { factTraceNode(evidence) },
    })
end

function DetectiveService:ExplainBlocker(blocker)
    if type(blocker) ~= "table" then return unknownExplanation("BLOCKER", nil) end
    local normalized = resolveBlockers({ blocker })[1]
    if not normalized then return unknownExplanation("BLOCKER", nil) end
    return Cortex.Explanation.Create({
        targetType = "BLOCKER",
        targetId = normalized.id,
        result = "BLOCKED",
        reason = normalized.reason,
        blockers = { normalized },
        trace = normalized.factKey and { factTraceNode(createFactEvidence(normalized.factKey)) } or {},
    })
end

function DetectiveService:Explain(target)
    if type(target) ~= "table" or type(target.type) ~= "string" then
        return unknownExplanation("UNKNOWN", nil)
    end
    local targetType = string.upper(target.type)
    if targetType == "RECOMMENDATION" then return self:ExplainRecommendation(target.value or target.id) end
    if targetType == "GOAL" then return self:ExplainGoal(target.value or target.id) end
    if targetType == "FACT" then return self:ExplainFact(target.key or target.id) end
    if targetType == "BLOCKER" then return self:ExplainBlocker(target.value or target.blocker) end
    return unknownExplanation(targetType, target.id)
end

Cortex:RegisterService("Detective", DetectiveService, {
    services = { "Facts", "Rules" },
    modules = { "Goals", "Recommendations" },
})
