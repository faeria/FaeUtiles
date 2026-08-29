local _, Cortex = ...

local Explanation = {}
Explanation.__index = Explanation

local LEVELS = { SUMMARY = true, DETAIL = true, DEBUG = true }

local function displayValue(value)
    if value == nil then return Cortex:GetText("DETECTIVE_VALUE_UNKNOWN") end
    if type(value) == "boolean" then return Cortex:GetText(value and "DEBUG_YES" or "DEBUG_NO") end
    if type(value) == "number" or type(value) == "string" then return tostring(value) end
    return Cortex:GetText("DETECTIVE_VALUE_STRUCTURED")
end

function Explanation.Create(specification)
    if type(specification) ~= "table" or type(specification.targetType) ~= "string"
        or type(specification.result) ~= "string" or type(specification.reason) ~= "string" then return nil end
    return setmetatable({
        targetType = specification.targetType,
        targetId = specification.targetId,
        title = type(specification.title) == "string" and specification.title or "",
        result = specification.result,
        reason = specification.reason,
        evidence = specification.evidence or {},
        conditions = specification.conditions or {},
        blockers = specification.blockers or {},
        trace = specification.trace or {},
    }, Explanation)
end

function Explanation:GetTrace()
    return Cortex.Schema.Copy(self.trace)
end

function Explanation:GetLines(level)
    level = string.upper(type(level) == "string" and level or "SUMMARY")
    if not LEVELS[level] then level = "SUMMARY" end
    local lines = {
        Cortex:GetText("DETECTIVE_RESULT", self.result),
        Cortex:GetText("DETECTIVE_REASON", self.reason),
    }
    if level == "SUMMARY" then return lines end

    for index = 1, #self.evidence do
        local evidence = self.evidence[index]
        local value = evidence.valueText or displayValue(evidence.value)
        lines[#lines + 1] = Cortex:GetText("DETECTIVE_EVIDENCE_LINE",
            evidence.label, value, string.upper(evidence.status))
    end
    for index = 1, #self.conditions do
        local condition = self.conditions[index]
        lines[#lines + 1] = Cortex:GetText("DETECTIVE_CONDITION_LINE", condition.label,
            displayValue(condition.actual), displayValue(condition.expected),
            Cortex:GetText(condition.met and "DETECTIVE_MET" or "DETECTIVE_NOT_MET"))
    end
    for index = 1, #self.blockers do
        local blocker = self.blockers[index]
        lines[#lines + 1] = Cortex:GetText("DETECTIVE_BLOCKER_LINE", blocker.label, blocker.reason)
    end
    if level ~= "DEBUG" then return lines end

    for index = 1, #self.trace do
        local node = self.trace[index]
        lines[#lines + 1] = Cortex:GetText("DETECTIVE_TRACE_LINE", index,
            node.type, tostring(node.id), node.details or "")
    end
    return lines
end

function Explanation:GetText(level)
    return table.concat(self:GetLines(level), "\n")
end

Cortex.Explanation = Explanation
