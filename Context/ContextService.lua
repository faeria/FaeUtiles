local _, Cortex = ...

local ContextService = {
    currentCharacter = nil,
    eventCollectors = {},
    dependents = {},
    pending = {},
    collectorState = {},
    flushScheduled = false,
    isFlushing = false,
    activePending = nil,
    restrictionPending = {},
}

local RESTRICTION_NAMES = { "Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map" }

local function copyArguments(...)
    return { count = select("#", ...), ... }
end

local function unpackArguments(arguments)
    return unpack(arguments, 1, arguments.count or #arguments)
end

function ContextService:Initialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    local collectors, order = Cortex:GetCollectors()
    for index = 1, #order do
        local name = order[index]
        local collector = collectors[name]
        self.collectorState[name] = { status = "never", lastCheckedAt = nil, lastUpdatedAt = nil }
        for eventIndex = 1, #(collector.events or {}) do
            local event = collector.events[eventIndex]
            local owners = self.eventCollectors[event]
            if not owners then
                owners = {}
                self.eventCollectors[event] = owners
                self.eventFrame:RegisterEvent(event)
            end
            owners[#owners + 1] = name
        end
        for dependencyIndex = 1, #(collector.dependencies or {}) do
            local dependency = collector.dependencies[dependencyIndex]
            local dependents = self.dependents[dependency]
            if not dependents then dependents = {}; self.dependents[dependency] = dependents end
            dependents[#dependents + 1] = name
        end
    end
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnGameEvent(event, ...)
    end)
end

function ContextService:GetActiveRestriction()
    if type(C_RestrictedActions) ~= "table" or type(C_RestrictedActions.IsAddOnRestrictionActive) ~= "function"
        or type(Enum) ~= "table" or type(Enum.AddOnRestrictionType) ~= "table" then
        return nil
    end
    for index = 1, #RESTRICTION_NAMES do
        local name = RESTRICTION_NAMES[index]
        local restrictionType = Enum.AddOnRestrictionType[name]
        if Cortex:IsAccessibleValue(restrictionType) and restrictionType ~= nil then
            local ok, active = pcall(C_RestrictedActions.IsAddOnRestrictionActive, restrictionType)
            if ok and Cortex:IsAccessibleValue(active) and active then return name end
        end
    end
    return nil
end

function ContextService:Get(key) return Cortex:GetService("Facts"):Get(key) end
function ContextService:GetLastKnown(key) return Cortex:GetService("Facts"):GetLastKnown(key) end
function ContextService:GetRecord(key) return Cortex:GetService("Facts"):GetRecord(key) end
function ContextService:GetStatus(key) return Cortex:GetService("Facts"):GetStatus(key) end
function ContextService:GetLastUpdated(key) return Cortex:GetService("Facts"):GetUpdatedAt(key) end

function ContextService:CollectNow(name, event, arguments)
    local collector = Cortex:GetCollector(name)
    local state = self.collectorState[name]
    if not collector or not state then return false, "unknown-collector" end

    if collector.requiresOutOfCombat and Cortex:IsInCombatLockdown() then
        state.status = "deferred"
        Cortex:DeferUntilOutOfCombat("context:collector:" .. name, function()
            self:CollectNow(name, event, arguments)
        end)
        return true, "deferred"
    end

    local restriction = self:GetActiveRestriction()
    if restriction then
        state.status = "restricted:" .. restriction
        self.restrictionPending[name] = true
        return true, "restricted"
    end

    local profiler = Cortex:GetService("Profiler")
    local startedAt = profiler:Start()
    local ok, result = pcall(collector.Collect, collector, self, event, unpackArguments(arguments or { count = 0 }))
    profiler:Stop("collector", name, startedAt)
    state.lastCheckedAt = time()
    if not ok or not Cortex:IsAccessibleValue(result) or type(result) ~= "table" then
        state.status = "error"
        Cortex:GetService("Logger"):Error(Cortex:GetText("CONTEXT_COLLECTOR_ERROR", name))
        return false, "collector-error"
    end

    local _, changed, changedKeys = Cortex:GetService("Facts"):Apply(name, result)
    state.status = "ready"
    if changed then state.lastUpdatedAt = time() end
    if name == "Character" then
        self.currentCharacter = self:GetLastKnown("character.current")
        if self.currentCharacter then Cortex:GetService("Database"):RecordCharacter(self.currentCharacter) end
    end
    if not changed then return true, "unchanged" end

    Cortex.Events:Publish(Cortex.Constants.EVENTS.CONTEXT_UPDATED, name, state.lastUpdatedAt, changedKeys)

    for index = 1, #(self.dependents[name] or {}) do
        self:QueueCollector(self.dependents[name][index], "dependency:" .. name)
    end
    return true, "collected"
end

function ContextService:FlushPending()
    self.flushScheduled = false
    local pending = self.pending
    self.pending = {}
    self.isFlushing = true
    self.activePending = pending
    local _, order = Cortex:GetCollectors()
    for index = 1, #order do
        local name = order[index]
        local request = pending[name]
        pending[name] = nil
        if request then self:CollectNow(name, request.event, request.arguments) end
    end
    self.isFlushing = false
    self.activePending = nil
    if next(self.pending) then self:ScheduleFlush() end
end

function ContextService:ScheduleFlush()
    if self.flushScheduled then return end
    self.flushScheduled = true
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(0, function() self:FlushPending() end)
    else
        self:FlushPending()
    end
end

function ContextService:QueueCollector(name, event, ...)
    if not Cortex:GetCollector(name) then return false, "unknown-collector" end
    if self.isFlushing and self.activePending and self.activePending[name] then
        return true, Cortex:IsInCombatLockdown() and "deferred" or "queued"
    end
    local existing = self.pending[name]
    if existing then
        -- Multiple targeted updates can carry different IDs. A full collector pass is safer than
        -- retaining only the last payload and silently missing an earlier currency/faction change.
        existing.event = "coalesced"
        existing.arguments = { count = 0 }
        return true, Cortex:IsInCombatLockdown() and "deferred" or "queued"
    end
    Cortex:GetService("Facts"):MarkSourceStale(name, event or "refresh-requested")
    self.pending[name] = { event = event, arguments = copyArguments(...) }
    if not self.isFlushing then self:ScheduleFlush() end
    return true, Cortex:IsInCombatLockdown() and "deferred" or "queued"
end

function ContextService:OnGameEvent(event, ...)
    Cortex:GetService("Profiler"):RecordEvent("wow.context", event)
    if event == "ADDON_RESTRICTION_STATE_CHANGED" then
        local _, restrictionState = ...
        local inactive = type(Enum) == "table" and type(Enum.AddOnRestrictionState) == "table"
            and Enum.AddOnRestrictionState.Inactive or 0
        if Cortex:IsAccessibleValue(restrictionState) and restrictionState == inactive then
            local pending = self.restrictionPending
            self.restrictionPending = {}
            for name in pairs(pending) do self:QueueCollector(name, "restriction-ended") end
        end
        return
    end
    local owners = self.eventCollectors[event]
    if not owners then return end
    for index = 1, #owners do
        local name = owners[index]
        local collector = Cortex:GetCollector(name)
        local shouldCollect = true
        if type(collector.ShouldCollect) == "function" then
            local ok, result = pcall(collector.ShouldCollect, collector, self, event, ...)
            shouldCollect = ok and result == true
        end
        if shouldCollect then self:QueueCollector(name, event, ...) end
    end
end

function ContextService:RequestRefresh(reason, collectorName)
    if collectorName and not Cortex:GetCollector(collectorName) then return false, "unknown-collector" end
    if collectorName then return self:QueueCollector(collectorName, "manual:" .. (reason or "unknown")) end

    local _, order = Cortex:GetCollectors()
    local state = Cortex:IsInCombatLockdown() and "deferred" or "queued"
    for index = 1, #order do self:QueueCollector(order[index], "manual:" .. (reason or "unknown")) end
    return true, state
end

function ContextService:ResolveCollectorName(candidate)
    if type(candidate) ~= "string" then return nil end
    local _, order = Cortex:GetCollectors()
    local lowered = string.lower(candidate)
    for index = 1, #order do
        if string.lower(order[index]) == lowered then return order[index] end
    end
    return nil
end

function ContextService:RefreshCurrentCharacter()
    return self:CollectNow("Character", "compatibility", { count = 0 })
end

function ContextService:GetCurrentCharacter() return self.currentCharacter end
function ContextService:GetKnownCharacterCount() return Cortex:GetService("Database"):GetKnownCharacterCount() end

function ContextService:DebugSummary()
    local summary = { collectors = {}, available = 0, stale = 0, unavailable = 0 }
    local _, order = Cortex:GetCollectors()
    local facts = Cortex:GetService("Facts")
    for index = 1, #order do
        local name = order[index]
        local state = self.collectorState[name]
        local keys = facts:GetSourceKeys(name)
        local counts = { available = 0, stale = 0, unavailable = 0 }
        for keyIndex = 1, #keys do
            local status = facts:GetStatus(keys[keyIndex])
            if counts[status] ~= nil then counts[status] = counts[status] + 1 end
            if summary[status] ~= nil then summary[status] = summary[status] + 1 end
        end
        summary.collectors[name] = {
            status = state.status,
            lastCheckedAt = state.lastCheckedAt,
            lastUpdatedAt = state.lastUpdatedAt,
            facts = counts,
        }
    end
    return summary
end

Cortex:RegisterService("Context", ContextService, {
    services = { "Logger", "Profiler", "Events", "Database", "Facts" },
})
