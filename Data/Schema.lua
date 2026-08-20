local _, Cortex = ...

local Schema = {}

Schema.accountDefaults = {
    schemaVersion = Cortex.Constants.ACCOUNT_SCHEMA_VERSION,
    settings = {
        logLevel = "INFO",
        modules = {},
    },
    goals = {
        schemaVersion = 1,
        nextId = 1,
        items = {},
    },
    warband = {
        schemaVersion = 1,
        characters = {},
    },
}

Schema.characterDefaults = {
    schemaVersion = Cortex.Constants.CHARACTER_SCHEMA_VERSION,
    session = {
        schemaVersion = 1,
        lastLoginAt = 0,
        lastLogoutAt = 0,
    },
}

function Schema.Copy(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = type(value) == "table" and Schema.Copy(value) or value
    end
    return copy
end

function Schema.MergeMissing(target, defaults)
    for key, defaultValue in pairs(defaults) do
        local currentValue = target[key]
        if currentValue == nil then
            target[key] = type(defaultValue) == "table" and Schema.Copy(defaultValue) or defaultValue
        elseif type(currentValue) == "table" and type(defaultValue) == "table" then
            Schema.MergeMissing(currentValue, defaultValue)
        end
    end
end

local function isPositiveInteger(value)
    return type(value) == "number" and value >= 1 and value == math.floor(value)
end

function Schema.ValidateAccount(database)
    local defaults = Schema.accountDefaults

    if type(database.settings) ~= "table" then
        database.settings = Schema.Copy(defaults.settings)
    end
    if not Cortex.Constants.LOG_LEVELS[database.settings.logLevel] then
        database.settings.logLevel = defaults.settings.logLevel
    end
    if type(database.settings.modules) ~= "table" then
        database.settings.modules = {}
    end
    for name, enabled in pairs(database.settings.modules) do
        if type(name) ~= "string" or type(enabled) ~= "boolean" then
            database.settings.modules[name] = nil
        end
    end

    if type(database.goals) ~= "table" then
        database.goals = Schema.Copy(defaults.goals)
    end
    if type(database.goals.items) ~= "table" then
        database.goals.items = {}
    end
    if not isPositiveInteger(database.goals.nextId) then
        database.goals.nextId = 1
    end

    local highestGoalId = 0
    for key, goal in pairs(database.goals.items) do
        if isPositiveInteger(key) and key > highestGoalId and type(goal) == "table" then
            highestGoalId = key
        end
    end
    if database.goals.nextId <= highestGoalId then
        database.goals.nextId = highestGoalId + 1
    end

    if type(database.warband) ~= "table" then
        database.warband = Schema.Copy(defaults.warband)
    end
    if type(database.warband.characters) ~= "table" then
        database.warband.characters = {}
    end
end

function Schema.ValidateCharacter(database)
    local defaults = Schema.characterDefaults
    if type(database.session) ~= "table" then
        database.session = Schema.Copy(defaults.session)
    end
    if type(database.session.lastLoginAt) ~= "number" then
        database.session.lastLoginAt = 0
    end
    if type(database.session.lastLogoutAt) ~= "number" then
        database.session.lastLogoutAt = 0
    end
end

Cortex.Schema = Schema
