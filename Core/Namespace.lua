local addonName, Cortex = ...

Cortex.addonName = addonName
Cortex.L = Cortex.L or {}

function Cortex:IsSecretValue(value)
    return issecretvalue and issecretvalue(value) or false
end

function Cortex:IsSecretTable(value)
    return type(value) == "table" and issecrettable and issecrettable(value) or false
end

function Cortex:IsAccessibleValue(value)
    if self:IsSecretValue(value) or self:IsSecretTable(value) then
        return false
    end

    return not canaccessvalue or canaccessvalue(value)
end

function Cortex:GetText(key, ...)
    local text = self.L[key] or key
    if select("#", ...) == 0 then
        return text
    end

    return string.format(text, ...)
end
