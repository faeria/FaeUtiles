local _, Cortex = ...

local Blocker = {}
Blocker.__index = Blocker

function Blocker.Create(specification)
    if type(specification) ~= "table" or type(specification.id) ~= "string"
        or specification.id == "" or type(specification.label) ~= "string"
        or specification.label == "" then return nil end
    return setmetatable({
        id = specification.id,
        type = type(specification.type) == "string" and specification.type or "UNKNOWN",
        label = specification.label,
        reason = type(specification.reason) == "string" and specification.reason or "UNKNOWN",
        goalId = Cortex.Schema.IsPositiveInteger(specification.goalId) and specification.goalId or nil,
        factKey = type(specification.factKey) == "string" and specification.factKey or nil,
        required = specification.required,
        available = specification.available,
        missing = specification.missing,
    }, Blocker)
end

Cortex.Blocker = Blocker
