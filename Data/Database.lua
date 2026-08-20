local _, Cortex = ...

local Database = {
    initialized = false,
}

function Database:Initialize()
    local account = _G.CortexDB
    if type(account) ~= "table" then
        account = {}
        _G.CortexDB = account
    end

    local character = _G.CortexCharacterDB
    if type(character) ~= "table" then
        character = {}
        _G.CortexCharacterDB = character
    end

    local accountOk, accountReason = Cortex.Migrations.Run(
        account,
        Cortex.Constants.ACCOUNT_SCHEMA_VERSION,
        Cortex.Migrations.account
    )
    local characterOk, characterReason = Cortex.Migrations.Run(
        character,
        Cortex.Constants.CHARACTER_SCHEMA_VERSION,
        Cortex.Migrations.character
    )

    if not accountOk then
        Cortex:GetService("Logger"):Error(Cortex:GetText("DATABASE_ACCOUNT_MIGRATION_ERROR", accountReason))
        return false
    end
    if not characterOk then
        Cortex:GetService("Logger"):Error(Cortex:GetText("DATABASE_CHARACTER_MIGRATION_ERROR", characterReason))
        return false
    end

    Cortex.Schema.MergeMissing(account, Cortex.Schema.accountDefaults)
    Cortex.Schema.MergeMissing(character, Cortex.Schema.characterDefaults)
    Cortex.Schema.ValidateAccount(account)
    Cortex.Schema.ValidateCharacter(character)

    if accountReason == "newer" then
        Cortex:GetService("Logger"):Warn(Cortex:GetText("DATABASE_ACCOUNT_NEWER_WARN"))
    end
    if characterReason == "newer" then
        Cortex:GetService("Logger"):Warn(Cortex:GetText("DATABASE_CHARACTER_NEWER_WARN"))
    end

    self.account = account
    self.character = character
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
    return self.character
end

function Database:GetLogLevel()
    return self.account.settings.logLevel
end

function Database:SetLogLevel(level)
    if Cortex.Constants.LOG_LEVELS[level] then
        self.account.settings.logLevel = level
        return true
    end
    return false
end

function Database:GetModuleState(name)
    local state = self.account.settings.modules[name]
    if type(state) == "boolean" then
        return state
    end
    return nil
end

function Database:SetModuleState(name, enabled)
    if type(name) ~= "string" or type(enabled) ~= "boolean" then
        return false
    end
    self.account.settings.modules[name] = enabled
    return true
end

function Database:RecordCharacter(record)
    self.account.warband.characters[record.guid] = record
end

function Database:MarkLogin()
    self.character.session.lastLoginAt = time()
end

function Database:MarkLogout()
    self.character.session.lastLogoutAt = time()
end

Cortex:RegisterService("Database", Database, { services = { "Logger" } })
