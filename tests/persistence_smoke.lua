function issecretvalue()
    return false
end

function issecrettable()
    return false
end

function canaccessvalue()
    return true
end

local Cortex = { L = {} }
local files = {
    "Core/Namespace.lua",
    "Core/Constants.lua",
    "Data/Schema.lua",
    "Data/Migrations.lua",
    "Data/Repositories.lua",
}

for index = 1, #files do
    local chunk = assert(loadfile(files[index]))
    chunk("FaeUtiles", Cortex)
end

local existingCharacter = {
    schemaVersion = 1,
    guid = "Player-1-ABC",
    name = "Existing",
    realm = "Realm",
    level = 80,
}

local versionOne = {
    schemaVersion = 1,
    settings = { logLevel = "DEBUG" },
    goals = {
        schemaVersion = 1,
        nextId = 2,
        items = {
            [1] = { id = 1, title = "Keep me", status = "active", estimatedMinutes = 45 },
        },
    },
    warband = {
        schemaVersion = 1,
        characters = { [existingCharacter.guid] = existingCharacter },
    },
}

local migrated, reason = Cortex.Migrations.Run(
    versionOne,
    Cortex.Constants.ACCOUNT_SCHEMA_VERSION,
    Cortex.Migrations.account
)
assert(migrated, reason)
Cortex.Schema.MergeMissing(versionOne, Cortex.Schema.accountDefaults)
Cortex.Schema.ValidateAccount(versionOne)

assert(versionOne.schemaVersion == 7)
assert(versionOne.settings.logLevel == "DEBUG")
assert(versionOne.settings.profiling == false)
assert(versionOne.goals.items[1].title == "Keep me")
assert(versionOne.goals.items[1].status == Cortex.Constants.GOAL_STATUSES.ACTIVE)
assert(versionOne.goals.items[1].type == "GENERIC")
assert(versionOne.goals.items[1].schemaVersion == Cortex.Constants.GOAL_SCHEMA_VERSION)
assert(versionOne.goals.items[1].metadata.estimatedMinutes == 45)
assert(versionOne.goals.items[1].estimatedMinutes == nil)
assert(versionOne.characters[existingCharacter.guid].name == "Existing")
assert(versionOne.warband.characters == nil)
assert(type(versionOne.history.items) == "table")
assert(type(versionOne.sessions.byCharacter) == "table")
assert(type(versionOne.modules.states) == "table")
assert(versionOne.templates.schemaVersion == 1)
assert(type(versionOne.templates.sessions) == "table")
assert(type(versionOne.templates.taskLists) == "table")
assert(versionOne.characters[existingCharacter.guid].schemaVersion == 2)
assert(type(versionOne.characters[existingCharacter.guid].snapshot.fields) == "table")

local versionTwo = {
    schemaVersion = 2,
    settings = {
        logLevel = "INFO",
        modules = { Goals = false, Planner = true },
    },
    goals = { schemaVersion = 1, nextId = 1, items = {} },
    warband = { schemaVersion = 1, characters = {} },
}

migrated, reason = Cortex.Migrations.Run(
    versionTwo,
    Cortex.Constants.ACCOUNT_SCHEMA_VERSION,
    Cortex.Migrations.account
)
assert(migrated, reason)
assert(versionTwo.modules.states.Goals == false)
assert(versionTwo.modules.states.Planner == true)
assert(versionTwo.settings.modules == nil)

local beforeSecondRun = Cortex.Schema.Copy(versionTwo)
local migrationThree = assert(Cortex.Migrations.account[3])
migrationThree(versionTwo)
assert(versionTwo.modules.states.Goals == beforeSecondRun.modules.states.Goals)
assert(versionTwo.modules.states.Planner == beforeSecondRun.modules.states.Planner)
assert(versionTwo.settings.modules == nil)

local migrationFour = assert(Cortex.Migrations.account[4])
migrationFour(versionTwo)
assert(versionTwo.goals.schemaVersion == Cortex.Constants.GOALS_SCHEMA_VERSION)
local migrationFive = assert(Cortex.Migrations.account[5])
migrationFive(versionTwo)
assert(versionTwo.settings.window.point == "CENTER")
local migrationSix = assert(Cortex.Migrations.account[6])
migrationSix(versionTwo)
assert(versionTwo.warband.schemaVersion == 2)
local migrationSeven = assert(Cortex.Migrations.account[7])
migrationSeven(versionTwo)
assert(versionTwo.templates.schemaVersion == 1)
local templatesBeforeSecondRun = Cortex.Schema.Copy(versionTwo.templates)
migrationSeven(versionTwo)
assert(versionTwo.templates.nextId == templatesBeforeSecondRun.nextId)

versionTwo.settings.window = { point = "INVALID", relativePoint = "BOTTOM", x = 99999, y = -99999, scale = 3 }
Cortex.Schema.ValidateAccount(versionTwo)
assert(versionTwo.settings.window.point == "CENTER")
assert(versionTwo.settings.window.relativePoint == "BOTTOM")
assert(versionTwo.settings.window.x == 4000)
assert(versionTwo.settings.window.y == -4000)
assert(versionTwo.settings.window.scale == 1.25)

local futureVersion = { schemaVersion = 99, sentinel = "preserve" }
migrated, reason = Cortex.Migrations.Run(
    futureVersion,
    Cortex.Constants.ACCOUNT_SCHEMA_VERSION,
    Cortex.Migrations.account
)
assert(migrated and reason == "newer")
assert(futureVersion.sentinel == "preserve")
assert(futureVersion.settings == nil)

local repositories = Cortex.Repositories.New(versionOne)
assert(repositories.characters:Upsert({ name = "Name only" }) == nil)
local stored, characterKey = repositories.characters:Upsert({
    guid = "Player-1-NEW",
    name = "New",
    realm = "Realm",
    classFile = "MAGE",
    classId = 8,
    level = 80,
    lastSeenAt = 100,
})
assert(stored and characterKey == "Player-1-NEW")

repositories.sessions:MarkLogin(characterKey, 101)
repositories.sessions:CaptureCharacterState(characterKey, stored)
repositories.sessions:CaptureUnfinishedGoals(characterKey, {
    [4] = { status = "ACTIVE" },
    [9] = { status = "COMPLETED" },
})
repositories.sessions:CaptureUnfinishedTasks(characterKey, {
    { id = "task:one", goalId = 4 },
    { id = "task:one", goalId = 4 },
    { id = "task:two" },
})
repositories.sessions:MarkLogout(characterKey, 200)

local snapshot = repositories.sessions:Get(characterKey)
assert(snapshot.lastLogin == 101)
assert(snapshot.lastLogout == 200)
assert(snapshot.lastKnownCharacterState.level == 80)
assert(snapshot.unfinishedGoals[1] == 4)
assert(#snapshot.unfinishedTasks == 2)

for index = 1, Cortex.Constants.MAX_HISTORY_ENTRIES + 5 do
    repositories.history:Append("test", index, characterKey, { sequence = index })
end
assert(#versionOne.history.items == Cortex.Constants.MAX_HISTORY_ENTRIES)
assert(versionOne.history.items[1].details.sequence == 6)

print("persistence smoke test: ok")
