local _, Cortex = ...

local Condition = {}
Condition.__index = Condition

function Condition.Create(specification)
    if type(specification) ~= "table" or type(specification.id) ~= "string"
        or specification.id == "" or type(specification.label) ~= "string"
        or specification.label == "" or type(specification.met) ~= "boolean" then return nil end
    return setmetatable({
        id = specification.id,
        label = specification.label,
        met = specification.met,
        expected = specification.expected,
        actual = specification.actual,
        factKey = type(specification.factKey) == "string" and specification.factKey or nil,
        ruleId = type(specification.ruleId) == "string" and specification.ruleId or nil,
    }, Condition)
end

Cortex.Condition = Condition
