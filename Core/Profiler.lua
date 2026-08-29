local _, Cortex = ...

local Profiler = {
    enabled = false,
    timings = {},
    events = {},
}

local function sortedKeys(values)
    local keys = {}
    for key in pairs(values) do keys[#keys + 1] = key end
    table.sort(keys)
    return keys
end

function Profiler:SetEnabled(enabled)
    self.enabled = enabled == true
    return self.enabled
end

function Profiler:IsEnabled()
    return self.enabled
end

function Profiler:Start()
    if not self.enabled or type(GetTimePreciseSec) ~= "function" then
        return nil
    end
    return GetTimePreciseSec()
end

function Profiler:Stop(category, name, startedAt)
    if not self.enabled or type(startedAt) ~= "number"
        or type(GetTimePreciseSec) ~= "function" then return nil end
    if type(category) ~= "string" or category == ""
        or type(name) ~= "string" or name == "" then return nil end

    local elapsedMilliseconds = math.max(0, (GetTimePreciseSec() - startedAt) * 1000)
    local categoryMetrics = self.timings[category]
    if not categoryMetrics then
        categoryMetrics = {}
        self.timings[category] = categoryMetrics
    end
    local metric = categoryMetrics[name]
    if not metric then
        metric = { count = 0, totalMilliseconds = 0, maxMilliseconds = 0, lastMilliseconds = 0 }
        categoryMetrics[name] = metric
    end
    metric.count = metric.count + 1
    metric.totalMilliseconds = metric.totalMilliseconds + elapsedMilliseconds
    metric.maxMilliseconds = math.max(metric.maxMilliseconds, elapsedMilliseconds)
    metric.lastMilliseconds = elapsedMilliseconds
    return elapsedMilliseconds
end

function Profiler:RecordEvent(owner, eventName)
    if not self.enabled or type(owner) ~= "string" or owner == ""
        or type(eventName) ~= "string" or eventName == "" then return false end
    local ownerEvents = self.events[owner]
    if not ownerEvents then
        ownerEvents = {}
        self.events[owner] = ownerEvents
    end
    ownerEvents[eventName] = (ownerEvents[eventName] or 0) + 1
    return true
end

function Profiler:Reset()
    self.timings = {}
    self.events = {}
end

function Profiler:GetSnapshot()
    local snapshot = { enabled = self.enabled, timings = {}, events = {}, totalEvents = 0 }
    local categories = sortedKeys(self.timings)
    for categoryIndex = 1, #categories do
        local category = categories[categoryIndex]
        local names = sortedKeys(self.timings[category])
        for nameIndex = 1, #names do
            local name = names[nameIndex]
            local metric = self.timings[category][name]
            snapshot.timings[#snapshot.timings + 1] = {
                category = category,
                name = name,
                count = metric.count,
                totalMilliseconds = metric.totalMilliseconds,
                averageMilliseconds = metric.count > 0 and metric.totalMilliseconds / metric.count or 0,
                maxMilliseconds = metric.maxMilliseconds,
                lastMilliseconds = metric.lastMilliseconds,
            }
        end
    end
    local owners = sortedKeys(self.events)
    for ownerIndex = 1, #owners do
        local owner = owners[ownerIndex]
        local names = sortedKeys(self.events[owner])
        for nameIndex = 1, #names do
            local name = names[nameIndex]
            local count = self.events[owner][name]
            snapshot.events[#snapshot.events + 1] = { owner = owner, name = name, count = count }
            snapshot.totalEvents = snapshot.totalEvents + count
        end
    end
    return snapshot
end

Cortex:RegisterService("Profiler", Profiler)
