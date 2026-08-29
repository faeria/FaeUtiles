local _, Cortex = ...
local Utils = {}

function Utils.IsAccessible(value) return Cortex:IsAccessibleValue(value) and value ~= nil end
function Utils.IsUsableTable(value) return Cortex:IsAccessibleValue(value) and type(value) == "table" end

function Utils.Call(callback, ...)
    if type(callback) ~= "function" then return false, "api-unavailable" end
    return pcall(callback, ...)
end

function Utils.AllAccessible(...)
    for index = 1, select("#", ...) do
        if not Cortex:IsAccessibleValue(select(index, ...)) then return false end
    end
    return true
end

function Utils.CopyFields(source, fields)
    if not Utils.IsUsableTable(source) then return nil end
    local copy = {}
    for index = 1, #fields do
        local field, value = fields[index], source[fields[index]]
        if Cortex:IsAccessibleValue(value) and value ~= nil and type(value) ~= "table" then copy[field] = value end
    end
    return copy
end

function Utils.Unavailable(keys, reason)
    local unavailable = {}
    for index = 1, #keys do unavailable[keys[index]] = reason end
    return { unavailable = unavailable }
end

Cortex.CollectorUtils = Utils
