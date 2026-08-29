local _, Cortex = ...

local Serializer = {}

local function encodeLengthPrefixed(prefix, value)
    return prefix .. #value .. ":" .. value
end

local function classifyTable(value)
    local count, maximum, hasString = 0, 0, false
    for key in pairs(value) do
        if not Cortex:IsAccessibleValue(key) then
            return nil
        elseif type(key) == "number" and key >= 1 and key == math.floor(key) then
            maximum = math.max(maximum, key)
        elseif type(key) == "string" and key ~= "" then
            hasString = true
        else
            return nil
        end
        count = count + 1
    end
    if hasString then
        for key in pairs(value) do if type(key) ~= "string" then return nil end end
        return "map", count
    end
    if maximum ~= count then return nil end
    return "array", count
end

local function serializeValue(value, state, depth)
    state.nodes = state.nodes + 1
    if state.nodes > Cortex.Constants.MAX_SHARE_NODES then return nil, "node-limit" end
    if depth > Cortex.Constants.MAX_SHARE_DEPTH then return nil, "depth-limit" end
    if not Cortex:IsAccessibleValue(value) then return nil, "inaccessible-value" end
    local valueType = type(value)
    if valueType == "string" then
        if #value > Cortex.Constants.MAX_SHARE_STRING_BYTES then return nil, "string-too-large" end
        return encodeLengthPrefixed("s", value)
    elseif valueType == "boolean" then
        return value and "t;" or "f;"
    elseif valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return nil, "invalid-number" end
        return encodeLengthPrefixed("d", tostring(value))
    elseif valueType ~= "table" then
        return nil, "unsupported-value"
    end
    if Cortex:IsSecretTable(value) or getmetatable(value) ~= nil or state.seen[value] then
        return nil, "unsafe-table"
    end
    state.seen[value] = true
    local tableKind, count = classifyTable(value)
    if not tableKind then state.seen[value] = nil; return nil, "invalid-table" end
    local output = { tableKind == "array" and "a" or "m", tostring(count), ":" }
    if tableKind == "array" then
        for index = 1, count do
            local encoded, reason = serializeValue(value[index], state, depth + 1)
            if not encoded then state.seen[value] = nil; return nil, reason end
            output[#output + 1] = encoded
        end
    else
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys)
        for index = 1, #keys do
            local key = keys[index]
            if #key > Cortex.Constants.MAX_SHARE_STRING_BYTES then
                state.seen[value] = nil
                return nil, "string-too-large"
            end
            output[#output + 1] = encodeLengthPrefixed("s", key)
            local encoded, reason = serializeValue(value[key], state, depth + 1)
            if not encoded then state.seen[value] = nil; return nil, reason end
            output[#output + 1] = encoded
        end
    end
    state.seen[value] = nil
    local result = table.concat(output)
    if #result > Cortex.Constants.MAX_SHARE_PAYLOAD_BYTES then return nil, "payload-too-large" end
    return result
end

function Serializer:Serialize(value)
    return serializeValue(value, { nodes = 0, seen = {} }, 1)
end

Cortex:RegisterService("Serializer", Serializer)
