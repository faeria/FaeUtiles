local _, Cortex = ...

local FactStore = {
    facts = {},
}

function FactStore:Set(key, value, source)
    if type(key) ~= "string" or key == "" or not Cortex:IsAccessibleValue(value) then
        return false
    end

    self.facts[key] = {
        value = value,
        source = type(source) == "string" and source or "unknown",
        updatedAt = time(),
    }
    Cortex.Events:Publish(Cortex.Constants.EVENTS.FACT_CHANGED, key, value)
    return true
end

function FactStore:Get(key)
    local fact = self.facts[key]
    return fact and fact.value or nil
end

function FactStore:GetRecord(key)
    return self.facts[key]
end

function FactStore:Remove(key)
    if self.facts[key] == nil then
        return false
    end
    self.facts[key] = nil
    Cortex.Events:Publish(Cortex.Constants.EVENTS.FACT_CHANGED, key, nil)
    return true
end

function FactStore:Clear()
    self.facts = {}
end

Cortex:RegisterService("Facts", FactStore, { services = { "Events" } })
