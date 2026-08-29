local _, Cortex = ...

local FactStore = {
    facts = {},
    sourceKeys = {},
}

local function isAccessibleTree(value, seen)
    if not Cortex:IsAccessibleValue(value) then return false end
    if type(value) ~= "table" then return true end
    seen = seen or {}
    if seen[value] then return true end
    seen[value] = true
    for key, child in pairs(value) do
        if not Cortex:IsAccessibleValue(key) or not isAccessibleTree(child, seen) then return false end
    end
    return true
end

local function publish(key, record)
    Cortex.Events:Publish(Cortex.Constants.EVENTS.FACT_CHANGED, key,
        record.status == "available" and record.value or nil, record.status, record)
end

local function previousState(record)
    if record.status == "stale" then
        return record.staleFromStatus, record.staleFromReason
    end
    return record.status, record.reason
end

local function clearStaleState(record)
    record.staleFromStatus = nil
    record.staleFromReason = nil
end

local function rememberSourceKey(self, source, key)
    local keys = self.sourceKeys[source]
    if not keys then keys = {}; self.sourceKeys[source] = keys end
    keys[key] = true
end

function FactStore:Set(key, value, source)
    if type(key) ~= "string" or key == "" or not isAccessibleTree(value) then return false end
    source = type(source) == "string" and source or "unknown"
    local timestamp = time()
    local record = self.facts[key] or {}
    local previousStatus = previousState(record)
    local changed = previousStatus ~= "available" or not Cortex.Schema.ValuesEqual(record.value, value)
    record.value, record.source, record.status = value, source, "available"
    record.reason, record.updatedAt, record.checkedAt = nil, timestamp, timestamp
    clearStaleState(record)
    self.facts[key] = record
    rememberSourceKey(self, source, key)
    publish(key, record)
    return true, changed
end

function FactStore:MarkStale(key, reason)
    local record = self.facts[key]
    if not record then return false end
    if record.status ~= "stale" then
        record.staleFromStatus = record.status
        record.staleFromReason = record.reason
    end
    record.status = "stale"
    record.reason = type(reason) == "string" and reason or "invalidated"
    record.checkedAt = time()
    publish(key, record)
    return true
end

function FactStore:MarkSourceStale(source, reason)
    local keys = self.sourceKeys[source]
    if not keys then return 0 end
    local count = 0
    for key in pairs(keys) do if self:MarkStale(key, reason) then count = count + 1 end end
    return count
end

function FactStore:SetUnavailable(key, source, reason)
    if type(key) ~= "string" or key == "" then return false end
    source = type(source) == "string" and source or "unknown"
    local record = self.facts[key] or {}
    local previousStatus, previousReason = previousState(record)
    local nextReason = type(reason) == "string" and reason or "temporarily-unavailable"
    local changed = previousStatus ~= "unavailable" or previousReason ~= nextReason
    record.source, record.status = source, "unavailable"
    record.reason = nextReason
    record.checkedAt = time()
    clearStaleState(record)
    self.facts[key] = record
    rememberSourceKey(self, source, key)
    publish(key, record)
    return true, changed
end

function FactStore:Apply(source, result)
    if type(source) ~= "string" or type(result) ~= "table" then return false end
    local previous, seen, changed, changedKeys = self.sourceKeys[source], {}, false, {}
    local changedKeySet = {}
    local function recordChanged(key, valueChanged)
        if valueChanged and not changedKeySet[key] then
            changed = true
            changedKeySet[key] = true
            changedKeys[#changedKeys + 1] = key
        end
    end
    local facts = type(result.facts) == "table" and result.facts or {}
    for key, value in pairs(facts) do
        local applied, valueChanged = self:Set(key, value, source)
        if applied then seen[key] = true; recordChanged(key, valueChanged) end
    end
    local unavailable = type(result.unavailable) == "table" and result.unavailable or {}
    for key, reason in pairs(unavailable) do
        local applied, valueChanged = self:SetUnavailable(key, source, reason)
        if applied then seen[key] = true; recordChanged(key, valueChanged) end
    end
    if result.replace ~= false and previous then
        for key in pairs(previous) do
            if not seen[key] then
                local _, valueChanged = self:SetUnavailable(key, source, "not-returned")
                recordChanged(key, valueChanged)
            end
        end
    end
    table.sort(changedKeys)
    return true, changed, changedKeys
end

function FactStore:Get(key)
    local fact = self.facts[key]
    return fact and fact.status == "available" and fact.value or nil
end

function FactStore:GetLastKnown(key) local fact = self.facts[key]; return fact and fact.value or nil end
function FactStore:GetRecord(key) return self.facts[key] end
function FactStore:GetUpdatedAt(key) local fact = self.facts[key]; return fact and fact.updatedAt or nil end
function FactStore:GetStatus(key) local fact = self.facts[key]; return fact and fact.status or "unknown" end

function FactStore:GetSourceKeys(source)
    local copy = {}
    for key in pairs(self.sourceKeys[source] or {}) do copy[#copy + 1] = key end
    table.sort(copy)
    return copy
end

function FactStore:Remove(key)
    local record = self.facts[key]
    if not record then return false end
    self.facts[key] = nil
    local keys = self.sourceKeys[record.source]
    if keys then keys[key] = nil end
    Cortex.Events:Publish(Cortex.Constants.EVENTS.FACT_CHANGED, key, nil, "removed", nil)
    return true
end

function FactStore:Clear() self.facts = {}; self.sourceKeys = {} end

Cortex:RegisterService("Facts", FactStore, { services = { "Events" } })
