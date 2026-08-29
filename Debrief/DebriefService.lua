local _, Cortex = ...

local DebriefService = {
    eventFrame = nil,
    latest = nil,
    pendingEncounter = nil,
}

local TRACKED_TYPES = {
    { key = "interrupts", enumKey = "Interrupts" },
    { key = "absorbs", enumKey = "Absorbs" },
    { key = "avoidableDamageTaken", enumKey = "AvoidableDamageTaken" },
    { key = "deaths", enumKey = "Deaths", includeSources = true },
}

local EVENTS = {
    "ENCOUNTER_START",
    "ENCOUNTER_END",
    "PLAYER_REGEN_ENABLED",
    "DAMAGE_METER_COMBAT_SESSION_UPDATED",
    "DAMAGE_METER_RESET",
}

local function safeValue(value, expectedType)
    if not Cortex:IsAccessibleValue(value) then
        return nil
    end
    if expectedType and type(value) ~= expectedType then
        return nil
    end
    return value
end

local function unavailable(reason)
    return {
        status = "UNAVAILABLE",
        reason = reason,
    }
end

local function formatTotal(category)
    if type(category) == "table" and category.status == "AVAILABLE" and type(category.total) == "number" then
        return tostring(category.total)
    end
    return "—"
end

local function copyDeathSources(combatSources)
    if safeValue(combatSources, "table") == nil then
        return {}
    end

    local sources = {}
    for index = 1, #combatSources do
        local source = safeValue(combatSources[index], "table")
        if source then
            local isLocalPlayer = safeValue(source.isLocalPlayer, "boolean")
            local total = safeValue(source.totalAmount, "number")
            local deathTimeSeconds = safeValue(source.deathTimeSeconds, "number")
            local classFilename = safeValue(source.classFilename, "string")
            if total or deathTimeSeconds then
                sources[#sources + 1] = {
                    isLocalPlayer = isLocalPlayer == true,
                    classFilename = classFilename,
                    total = total,
                    deathTimeSeconds = deathTimeSeconds,
                }
            end
        end
    end
    return sources
end

local function readCategory(sessionID, enumKey, includeSources)
    local damageMeterType = Enum and Enum.DamageMeterType and Enum.DamageMeterType[enumKey]
    if type(damageMeterType) ~= "number" then
        return unavailable("missing-enum")
    end

    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, sessionID, damageMeterType)
    if not ok or safeValue(session, "table") == nil then
        return unavailable("session-unavailable")
    end

    local total = safeValue(session.totalAmount, "number")
    if total == nil then
        return unavailable("total-unavailable")
    end

    local result = {
        status = "AVAILABLE",
        total = total,
    }
    if includeSources then
        result.sources = copyDeathSources(session.combatSources)
    end
    return result, safeValue(session.durationSeconds, "number")
end

local function findSession(encounterName)
    local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not ok or safeValue(sessions, "table") == nil then
        return nil, "sessions-unavailable"
    end

    local matches = {}
    for index = 1, #sessions do
        local session = safeValue(sessions[index], "table")
        local name = session and safeValue(session.name, "string") or nil
        local sessionID = session and safeValue(session.sessionID, "number") or nil
        if name == encounterName and sessionID then
            matches[#matches + 1] = session
        end
    end

    if #matches == 0 then
        return nil, "session-not-found"
    end
    if #matches > 1 then
        return nil, "session-ambiguous"
    end
    return matches[1]
end

local function hasDamageMeterAPI()
    return type(C_DamageMeter) == "table"
        and type(C_DamageMeter.IsDamageMeterAvailable) == "function"
        and type(C_DamageMeter.GetAvailableCombatSessions) == "function"
        and type(C_DamageMeter.GetCombatSessionFromID) == "function"
end

function DebriefService:PublishLatest()
    if not self.latest or Cortex:IsInCombatLockdown() then
        return false
    end
    Cortex.Events:Publish(Cortex.Constants.EVENTS.DEBRIEF_UPDATED, self.latest)
    return true
end

function DebriefService:RequestNativeRefresh()
    return Cortex:DeferUntilOutOfCombat("debrief:native-refresh", function()
        self:RefreshNativeStatistics()
    end)
end

function DebriefService:Initialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)

    Cortex:GetService("Commands"):Register({
        id = "debrief.inspect",
        title = Cortex:GetText("COMMAND_DEBRIEF"),
        subtitle = Cortex:GetText("COMMAND_DEBRIEF_SUBTITLE"),
        keywords = { "debrief", "encounter", "interrupts", "deaths" },
        execute = function() self:PrintLatest() end,
    })
end

function DebriefService:Enable()
    for index = 1, #EVENTS do
        self.eventFrame:RegisterEvent(EVENTS[index])
    end
end

function DebriefService:Disable()
    for index = 1, #EVENTS do
        self.eventFrame:UnregisterEvent(EVENTS[index])
    end
    self.pendingEncounter = nil
end

function DebriefService:OnEncounterStart(encounterID, encounterName, difficultyID, groupSize)
    encounterID = safeValue(encounterID, "number")
    encounterName = safeValue(encounterName, "string")
    difficultyID = safeValue(difficultyID, "number")
    groupSize = safeValue(groupSize, "number")
    if not encounterID or not encounterName or not difficultyID or not groupSize then
        self.pendingEncounter = nil
        return
    end

    self.pendingEncounter = {
        encounterID = encounterID,
        name = encounterName,
        difficultyID = difficultyID,
        groupSize = groupSize,
    }
end

function DebriefService:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    encounterID = safeValue(encounterID, "number")
    encounterName = safeValue(encounterName, "string")
    difficultyID = safeValue(difficultyID, "number")
    groupSize = safeValue(groupSize, "number")
    success = safeValue(success, "number")
    if not encounterID or not encounterName or not difficultyID or not groupSize or success == nil then
        self.pendingEncounter = nil
        return
    end

    self.pendingEncounter = {
        encounterID = encounterID,
        name = encounterName,
        difficultyID = difficultyID,
        groupSize = groupSize,
    }
    self.latest = {
        schemaVersion = 1,
        completedAt = time(),
        encounter = Cortex.Schema.Copy(self.pendingEncounter),
        result = success == 1 and "SUCCESS" or "FAILURE",
        nativeSession = unavailable("waiting-for-post-combat"),
        statistics = {
            interrupts = unavailable("waiting-for-post-combat"),
            absorbs = unavailable("waiting-for-post-combat"),
            avoidableDamageTaken = unavailable("waiting-for-post-combat"),
            deaths = unavailable("waiting-for-post-combat"),
        },
    }
    self:RequestNativeRefresh()
end

function DebriefService:RefreshNativeStatistics()
    if not self.latest or not self.pendingEncounter then
        return false, "no-encounter"
    end
    if Cortex:IsInCombatLockdown() then
        return false, "combat-lockdown"
    end
    if not hasDamageMeterAPI() then
        self.latest.nativeSession = unavailable("damage-meter-api-unavailable")
        self:PublishLatest()
        return false, "damage-meter-api-unavailable"
    end

    local ok, isAvailable, failureReason = pcall(C_DamageMeter.IsDamageMeterAvailable)
    if not ok or safeValue(isAvailable, "boolean") ~= true then
        local reason = safeValue(failureReason, "string") or "damage-meter-unavailable"
        self.latest.nativeSession = unavailable(reason)
        self:PublishLatest()
        return false, reason
    end

    local session, reason = findSession(self.pendingEncounter.name)
    if not session then
        self.latest.nativeSession = {
            status = reason == "session-ambiguous" and "AMBIGUOUS" or "UNAVAILABLE",
            reason = reason,
        }
        self:PublishLatest()
        return false, reason
    end

    local sessionID = safeValue(session.sessionID, "number")
    if not sessionID then
        self.latest.nativeSession = unavailable("session-id-unavailable")
        self:PublishLatest()
        return false, "session-id-unavailable"
    end

    local durationSeconds = safeValue(session.durationSeconds, "number")
    for index = 1, #TRACKED_TYPES do
        local tracked = TRACKED_TYPES[index]
        local category, categoryDuration = readCategory(sessionID, tracked.enumKey, tracked.includeSources)
        self.latest.statistics[tracked.key] = category
        if durationSeconds == nil and categoryDuration ~= nil then
            durationSeconds = categoryDuration
        end
    end

    self.latest.nativeSession = {
        status = "AVAILABLE",
        sessionID = sessionID,
        durationSeconds = durationSeconds,
    }
    self.pendingEncounter = nil
    self:PublishLatest()
    return true
end

function DebriefService:OnEvent(event, ...)
    Cortex:GetService("Profiler"):RecordEvent("wow.debrief", event)
    if event == "ENCOUNTER_START" then
        self:OnEncounterStart(...)
    elseif event == "ENCOUNTER_END" then
        self:OnEncounterEnd(...)
    elseif event == "PLAYER_REGEN_ENABLED" or event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        self:RequestNativeRefresh()
    elseif event == "DAMAGE_METER_RESET" and self.latest and self.pendingEncounter then
        self.latest.nativeSession = unavailable("damage-meter-reset")
        self:PublishLatest()
    end
end

function DebriefService:GetLatest()
    return self.latest and Cortex.Schema.Copy(self.latest) or nil
end

function DebriefService:DebugSnapshot()
    return self:GetLatest()
end

function DebriefService:PrintLatest()
    local logger = Cortex:GetService("Logger")
    if Cortex:IsInCombatLockdown() then
        logger:User(Cortex:GetText("DEBRIEF_COMBAT_LOCKDOWN"))
        return
    end
    local debrief = self:GetLatest()
    if not debrief then
        logger:User(Cortex:GetText("DEBRIEF_NONE"))
        return
    end

    logger:User(Cortex:GetText("DEBRIEF_HEADER", debrief.encounter.name, debrief.result))
    logger:User(Cortex:GetText(
        "DEBRIEF_NATIVE_STATUS",
        debrief.nativeSession.status,
        debrief.nativeSession.durationSeconds
            and (tostring(math.floor(debrief.nativeSession.durationSeconds)) .. "s") or "—"
    ))
    logger:User(Cortex:GetText(
        "DEBRIEF_STATS",
        formatTotal(debrief.statistics.deaths),
        formatTotal(debrief.statistics.interrupts),
        formatTotal(debrief.statistics.absorbs),
        formatTotal(debrief.statistics.avoidableDamageTaken)
    ))
end

Cortex:RegisterModule("Debrief", DebriefService, {
    services = { "Logger", "Profiler", "Events", "Commands" },
}, {
    defaultEnabled = true,
})
