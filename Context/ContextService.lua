local _, Cortex = ...

local ContextService = {
    currentCharacter = nil,
}

local function isUsableValue(value)
    return value ~= nil and Cortex:IsAccessibleValue(value)
end

function ContextService:RefreshCurrentCharacter()
    if Cortex:IsInCombatLockdown() then
        return false, "combat"
    end

    local name, realm = UnitFullName("player")
    local guid = UnitGUID("player")
    local _, classFile, classId = UnitClass("player")
    local level = UnitLevel("player")

    if not isUsableValue(name)
        or not isUsableValue(realm)
        or not isUsableValue(guid)
        or not isUsableValue(classFile)
        or not isUsableValue(classId)
        or not isUsableValue(level) then
        Cortex:GetService("Logger"):Warn(Cortex:GetText("CONTEXT_RESTRICTED_WARN"))
        return false, "restricted"
    end

    local record = {
        schemaVersion = Cortex.Constants.CHARACTER_RECORD_SCHEMA_VERSION,
        guid = guid,
        name = name,
        realm = realm,
        classFile = classFile,
        classId = classId,
        level = level,
        lastSeenAt = time(),
    }

    Cortex:GetService("Database"):RecordCharacter(record)
    Cortex:GetService("Facts"):Set("character.current", record, "Context")
    self.currentCharacter = record
    Cortex.Events:Publish(Cortex.Constants.EVENTS.CONTEXT_UPDATED, record)
    return true
end

function ContextService:RequestRefresh(reason)
    return Cortex:DeferUntilOutOfCombat("context:current-character", function()
        local captured, captureReason = self:RefreshCurrentCharacter()
        if not captured and captureReason ~= "combat" then
            Cortex:GetService("Logger"):Debug("Context refresh skipped: " .. tostring(captureReason))
        end
    end, reason)
end

function ContextService:GetCurrentCharacter()
    return self.currentCharacter
end

function ContextService:GetKnownCharacterCount()
    local count = 0
    local characters = Cortex:GetService("Database"):GetAccount().warband.characters
    for _, record in pairs(characters) do
        if type(record) == "table" and type(record.guid) == "string" then
            count = count + 1
        end
    end
    return count
end

Cortex:RegisterService("Context", ContextService, {
    services = { "Logger", "Events", "Database", "Facts" },
})
