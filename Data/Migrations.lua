local _, Cortex = ...

local Migrations = {}

Migrations.account = {
    [1] = function(database)
        Cortex.Schema.MergeMissing(database, {
            settings = { logLevel = "INFO" },
            goals = { schemaVersion = 1, nextId = 1, items = {} },
            warband = { schemaVersion = 1, characters = {} },
        })
    end,
    [2] = function(database)
        Cortex.Schema.MergeMissing(database, {
            settings = { modules = {} },
        })
    end,
    [3] = function(database)
        local characters = type(database.characters) == "table" and database.characters or {}
        local warband = type(database.warband) == "table" and database.warband or {}
        local legacyCharacters = warband.characters

        if type(legacyCharacters) == "table" then
            for characterKey, record in pairs(legacyCharacters) do
                if characters[characterKey] == nil
                    or (type(characters[characterKey]) ~= "table" and type(record) == "table") then
                    characters[characterKey] = record
                elseif type(characters[characterKey]) == "table" and type(record) == "table" then
                    Cortex.Schema.MergeMissing(characters[characterKey], record)
                end
            end
        end

        local modules = type(database.modules) == "table" and database.modules or {}
        local states = type(modules.states) == "table" and modules.states or {}
        local settings = type(database.settings) == "table" and database.settings or {}
        local legacyModuleStates = settings.modules

        if type(legacyModuleStates) == "table" then
            for name, enabled in pairs(legacyModuleStates) do
                if type(enabled) == "boolean" and type(states[name]) ~= "boolean" then
                    states[name] = enabled
                end
            end
        end

        database.settings = settings
        database.characters = characters
        database.warband = warband
        database.modules = modules
        modules.states = states

        warband.characters = nil
        settings.modules = nil

        Cortex.Schema.MergeMissing(database, {
            history = { schemaVersion = 1, nextId = 1, items = {} },
            sessions = { schemaVersion = 1, byCharacter = {} },
            warband = { schemaVersion = 1 },
            modules = { schemaVersion = 1, states = {} },
        })
    end,
    [4] = function(database)
        local goals = type(database.goals) == "table" and database.goals or {}
        local items = type(goals.items) == "table" and goals.items or {}
        goals.items = items
        goals.schemaVersion = Cortex.Constants.GOALS_SCHEMA_VERSION
        database.goals = goals
        for goalId, goal in pairs(items) do
            if not Cortex.Schema.NormalizeGoal(goal, goalId) then items[goalId] = nil end
        end
    end,
    [5] = function(database)
        local settings = type(database.settings) == "table" and database.settings or {}
        database.settings = settings
        settings.window = Cortex.Schema.NormalizeWindowPlacement(settings.window)
    end,
    [6] = function(database)
        local characters = type(database.characters) == "table" and database.characters or {}
        database.characters = characters
        for characterKey, record in pairs(characters) do
            if type(record) == "table" then
                record.schemaVersion = Cortex.Constants.CHARACTER_RECORD_SCHEMA_VERSION
                if type(record.snapshot) ~= "table" then
                    record.snapshot = Cortex.Schema.NewWarbandSnapshot()
                end
            else
                characters[characterKey] = nil
            end
        end
        local warband = type(database.warband) == "table" and database.warband or {}
        database.warband = warband
        warband.schemaVersion = 2
    end,
    [7] = function(database)
        database.templates = Cortex.Schema.NormalizeTemplates(database.templates)
    end,
}

Migrations.character = {
    [1] = function(database)
        Cortex.Schema.MergeMissing(database, {
            session = { schemaVersion = 1, lastLoginAt = 0, lastLogoutAt = 0 },
        })
    end,
}

local function getVersion(database)
    local version = database.schemaVersion
    if type(version) ~= "number" or version < 0 or version ~= math.floor(version) then
        return 0
    end
    return version
end

function Migrations.Run(database, currentVersion, migrations)
    local version = getVersion(database)
    if version > currentVersion then
        return true, "newer"
    end

    while version < currentVersion do
        local nextVersion = version + 1
        local migration = migrations[nextVersion]
        if type(migration) ~= "function" then
            return false, "missing-migration:" .. nextVersion
        end

        local migrationOk = pcall(migration, database)
        if not migrationOk then
            return false, "migration-failed:" .. nextVersion
        end
        database.schemaVersion = nextVersion
        version = nextVersion
    end
    return true
end

Cortex.Migrations = Migrations
