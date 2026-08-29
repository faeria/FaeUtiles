local _, Cortex = ...

local Database = {
    initialized = false,
    readOnly = false,
    pendingLoginAt = nil,
}

function Database:Initialize()
    local storedAccount = _G.CortexDB
    if type(storedAccount) ~= "table" then
        storedAccount = {}
    end
    local account = Cortex.Schema.Copy(storedAccount)

    local storedCharacter = _G.CortexCharacterDB
    local hasLegacyCharacter = type(storedCharacter) == "table"
    local character = hasLegacyCharacter and Cortex.Schema.Copy(storedCharacter) or nil

    local accountOk, accountReason = Cortex.Migrations.Run(
        account,
        Cortex.Constants.ACCOUNT_SCHEMA_VERSION,
        Cortex.Migrations.account
    )
    local characterOk = true
    local characterReason = nil
    if hasLegacyCharacter then
        characterOk, characterReason = Cortex.Migrations.Run(
            character,
            Cortex.Constants.CHARACTER_SCHEMA_VERSION,
            Cortex.Migrations.character
        )
    end

    if not accountOk then
        Cortex:GetService("Logger"):Error(Cortex:GetText("DATABASE_ACCOUNT_MIGRATION_ERROR", accountReason))
        return false
    end
    if not characterOk then
        Cortex:GetService("Logger"):Error(Cortex:GetText("DATABASE_CHARACTER_MIGRATION_ERROR", characterReason))
        return false
    end

    self.readOnly = accountReason == "newer"
    Cortex.Schema.MergeMissing(account, Cortex.Schema.accountDefaults)
    Cortex.Schema.ValidateAccount(account)
    if hasLegacyCharacter then
        Cortex.Schema.MergeMissing(character, Cortex.Schema.characterDefaults)
        Cortex.Schema.ValidateCharacter(character)
    end

    if accountReason == "newer" then
        Cortex:GetService("Logger"):Warn(Cortex:GetText("DATABASE_ACCOUNT_NEWER_WARN"))
    else
        _G.CortexDB = account
    end
    if hasLegacyCharacter then
        if characterReason == "newer" then
            Cortex:GetService("Logger"):Warn(Cortex:GetText("DATABASE_CHARACTER_NEWER_WARN"))
        else
            _G.CortexCharacterDB = character
        end
    end

    self.account = account
    self.legacyCharacter = character
    self.repositories = Cortex.Repositories.New(account)
    self.initialized = true
    return true
end

function Database:IsInitialized()
    return self.initialized
end

function Database:GetAccount()
    return self.account
end

function Database:GetCharacter()
    return self.legacyCharacter
end

function Database:IsReadOnly()
    return self.readOnly
end

function Database:GetSchemaVersion()
    local version = self.account and self.account.schemaVersion
    return type(version) == "number" and version or 0
end

function Database:CanWrite()
    return self.initialized and not self.readOnly
end

function Database:GetLogLevel()
    local settings = self.account and self.account.settings
    local level = settings and settings.logLevel
    return Cortex.Constants.LOG_LEVELS[level] and level or "INFO"
end

function Database:SetLogLevel(level)
    if self:CanWrite() and Cortex.Constants.LOG_LEVELS[level] then
        self.account.settings.logLevel = level
        return true
    end
    return false
end

function Database:IsProfilingEnabled()
    local settings = self.account and self.account.settings
    return settings and settings.profiling == true or false
end

function Database:SetProfilingEnabled(enabled)
    if not self:CanWrite() or type(enabled) ~= "boolean" then return false end
    self.account.settings.profiling = enabled
    return true
end

function Database:GetWindowPlacement()
    return Cortex.Schema.Copy(self.account.settings.window)
end

function Database:SetWindowPlacement(placement)
    if not self:CanWrite() or type(placement) ~= "table" then return false end
    self.account.settings.window = Cortex.Schema.NormalizeWindowPlacement(Cortex.Schema.Copy(placement))
    return true
end

function Database:GetModuleState(name)
    local modules = self.account and self.account.modules
    local states = modules and modules.states
    local state = states and states[name]
    if type(state) == "boolean" then
        return state
    end
    return nil
end

function Database:SetModuleState(name, enabled)
    if not self:CanWrite() or type(name) ~= "string" or type(enabled) ~= "boolean" then
        return false
    end
    self.account.modules.states[name] = enabled
    return true
end

function Database:RecordCharacter(record)
    if not self:CanWrite() then
        return false, "read-only"
    end

    local stored, characterKey = self.repositories.characters:Upsert(record)
    if not stored then
        return false, characterKey
    end

    self.activeCharacterKey = characterKey
    self.repositories.sessions:CaptureCharacterState(characterKey, stored)
    self.repositories.sessions:CaptureUnfinishedGoals(characterKey, self.account.goals.items)

    if self.pendingLoginAt then
        self.repositories.sessions:MarkLogin(characterKey, self.pendingLoginAt)
        self.pendingLoginAt = nil
    end

    self.repositories.sessions:ImportLegacy(characterKey, self.legacyCharacter, time())
    return true, characterKey
end

function Database:MarkLogin()
    if not self:CanWrite() then
        return false
    end

    local timestamp = time()
    if self.activeCharacterKey then
        return self.repositories.sessions:MarkLogin(self.activeCharacterKey, timestamp)
    end

    self.pendingLoginAt = timestamp
    return true
end

function Database:MarkLogout()
    if not self:CanWrite() or not self.activeCharacterKey then
        return false
    end

    local timestamp = time()
    local character = self.repositories.characters:Get(self.activeCharacterKey)
    self.repositories.sessions:MarkLogout(self.activeCharacterKey, timestamp)
    self.repositories.sessions:CaptureCharacterState(self.activeCharacterKey, character)
    self.repositories.sessions:CaptureUnfinishedGoals(self.activeCharacterKey, self.account.goals.items)
    return true
end

function Database:RefreshUnfinishedGoals()
    if not self:CanWrite() or not self.activeCharacterKey then
        return false
    end
    return self.repositories.sessions:CaptureUnfinishedGoals(
        self.activeCharacterKey,
        self.account.goals.items
    )
end

function Database:SetUnfinishedTasks(tasks)
    if not self:CanWrite() or not self.activeCharacterKey then
        return false
    end
    return self.repositories.sessions:CaptureUnfinishedTasks(self.activeCharacterKey, tasks)
end

function Database:GetSnapshot(characterKey)
    local key = characterKey or self.activeCharacterKey
    local snapshot = key and self.repositories.sessions:Get(key) or nil
    return snapshot and Cortex.Schema.Copy(snapshot) or nil
end

function Database:GetKnownCharacterCount()
    return self.repositories.characters:Count()
end

function Database:GetActiveCharacterKey()
    return self.activeCharacterKey
end

function Database:AppendHistory(eventType, details)
    if not self:CanWrite() then
        return nil
    end
    return self.repositories.history:Append(eventType, time(), self.activeCharacterKey, details)
end

function Database:DebugInspect(section)
    if section == nil or section == "" then
        return Cortex.Schema.Copy(self.account)
    end
    if type(section) ~= "string" or self.account[section] == nil then
        return nil, "unknown-section"
    end
    return Cortex.Schema.Copy(self.account[section])
end

function Database:DebugSummary()
    local sessionCount = 0
    for _ in pairs(self.account.sessions.byCharacter) do
        sessionCount = sessionCount + 1
    end

    return {
        schemaVersion = self.account.schemaVersion,
        characterCount = self.repositories.characters:Count(),
        historyCount = self.repositories.history:Count(),
        sessionCount = sessionCount,
        activeCharacterKey = self.activeCharacterKey,
        readOnly = self.readOnly,
    }
end

Cortex:RegisterService("Database", Database, { services = { "Logger" } })
