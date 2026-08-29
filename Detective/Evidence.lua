local _, Cortex = ...

local Evidence = {}
Evidence.__index = Evidence

function Evidence.Create(specification)
    if type(specification) ~= "table" or type(specification.id) ~= "string"
        or specification.id == "" or type(specification.label) ~= "string"
        or specification.label == "" then return nil end
    return setmetatable({
        id = specification.id,
        kind = type(specification.kind) == "string" and specification.kind or "FACT",
        label = specification.label,
        value = Cortex.Schema.Copy(specification.value),
        valueText = type(specification.valueText) == "string" and specification.valueText or nil,
        status = type(specification.status) == "string" and specification.status or "unknown",
        source = type(specification.source) == "string" and specification.source or nil,
        updatedAt = type(specification.updatedAt) == "number" and specification.updatedAt or nil,
        factKey = type(specification.factKey) == "string" and specification.factKey or nil,
    }, Evidence)
end

Cortex.Evidence = Evidence
