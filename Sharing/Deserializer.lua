local _, Cortex = ...

local Deserializer = {}

local function readCount(state)
    local start = state.position
    while state.position <= state.length and state.input:sub(state.position, state.position):match("%d") do
        state.position = state.position + 1
        if state.position - start > 8 then return nil end
    end
    if state.position == start or state.input:sub(state.position, state.position) ~= ":" then return nil end
    local count = tonumber(state.input:sub(start, state.position - 1))
    state.position = state.position + 1
    return count
end

local parseValue

local function readString(state)
    local length = readCount(state)
    if not length or length > Cortex.Constants.MAX_SHARE_STRING_BYTES
        or state.position + length - 1 > state.length then return nil, "invalid-string" end
    local value = state.input:sub(state.position, state.position + length - 1)
    state.position = state.position + length
    return value
end

local function readTable(state, depth, isMap)
    local count = readCount(state)
    if not count or count > Cortex.Constants.MAX_SHARE_NODES then return nil, "invalid-count" end
    local result = {}
    for index = 1, count do
        if isMap then
            if state.input:sub(state.position, state.position) ~= "s" then return nil, "invalid-map-key" end
            state.position = state.position + 1
            local key, keyReason = readString(state)
            if not key then return nil, keyReason end
            if key == "" or result[key] ~= nil then return nil, "invalid-map-key" end
            local value, reason = parseValue(state, depth + 1)
            if value == nil then return nil, reason end
            result[key] = value
        else
            local value, reason = parseValue(state, depth + 1)
            if value == nil then return nil, reason end
            result[index] = value
        end
    end
    return result
end

parseValue = function(state, depth)
    state.nodes = state.nodes + 1
    if state.nodes > Cortex.Constants.MAX_SHARE_NODES then return nil, "node-limit" end
    if depth > Cortex.Constants.MAX_SHARE_DEPTH or state.position > state.length then
        return nil, "depth-or-end"
    end
    local marker = state.input:sub(state.position, state.position)
    state.position = state.position + 1
    if marker == "s" then return readString(state) end
    if marker == "t" or marker == "f" then
        if state.input:sub(state.position, state.position) ~= ";" then return nil, "invalid-boolean" end
        state.position = state.position + 1
        return marker == "t"
    end
    if marker == "d" then
        local encoded, reason = readString(state)
        if not encoded then return nil, reason end
        if not encoded:match("^[%+%-]?[%d%.eE]+$") then return nil, "invalid-number" end
        local value = tonumber(encoded)
        if not value or value ~= value or value == math.huge or value == -math.huge then
            return nil, "invalid-number"
        end
        return value
    end
    if marker == "a" then return readTable(state, depth, false) end
    if marker == "m" then return readTable(state, depth, true) end
    return nil, "unknown-marker"
end

function Deserializer:Deserialize(input)
    if type(input) ~= "string" or input == "" then return nil, "invalid-payload" end
    if #input > Cortex.Constants.MAX_SHARE_PAYLOAD_BYTES then return nil, "payload-too-large" end
    local state = { input = input, length = #input, position = 1, nodes = 0 }
    local value, reason = parseValue(state, 1)
    if value == nil then return nil, reason or "invalid-payload" end
    if state.position ~= state.length + 1 then return nil, "trailing-content" end
    return value
end

Cortex:RegisterService("Deserializer", Deserializer)
