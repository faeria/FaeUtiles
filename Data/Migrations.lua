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

        migration(database)
        database.schemaVersion = nextVersion
        version = nextVersion
    end
    return true
end

Cortex.Migrations = Migrations
