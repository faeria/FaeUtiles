local _, Cortex = ...

local Repositories = {}

local function isNonEmptyString(value)
    return type(value) == "string"
        and Cortex:IsAccessibleValue(value)
        and value ~= ""
end

local Characters = {}
Characters.__index = Characters

function Characters:Upsert(record)
    if type(record) ~= "table" or not isNonEmptyString(record.guid) then
        return nil, "invalid-character-key"
    end

    local stored = self.root.characters[record.guid]
    if type(stored) ~= "table" then
        stored = {}
        self.root.characters[record.guid] = stored
    end

    stored.schemaVersion = Cortex.Constants.CHARACTER_RECORD_SCHEMA_VERSION
    stored.guid = record.guid
    stored.name = record.name
    stored.realm = record.realm
    stored.classFile = record.classFile
    stored.classId = record.classId
    stored.level = record.level
    stored.lastSeenAt = record.lastSeenAt
    if type(stored.snapshot) ~= "table" then stored.snapshot = Cortex.Schema.NewWarbandSnapshot() end
    self.root.warband.lastActiveCharacterKey = record.guid
    return stored, record.guid
end

function Characters:Get(characterKey)
    return self.root.characters[characterKey]
end

function Characters:Count()
    local count = 0
    for characterKey, record in pairs(self.root.characters) do
        if isNonEmptyString(characterKey)
            and type(record) == "table"
            and record.guid == characterKey then
            count = count + 1
        end
    end
    return count
end

local Sessions = {}
Sessions.__index = Sessions

function Sessions:GetOrCreate(characterKey)
    if not isNonEmptyString(characterKey) then
        return nil
    end

    local snapshot = self.root.sessions.byCharacter[characterKey]
    if type(snapshot) ~= "table" then
        snapshot = Cortex.Schema.NewSessionSnapshot()
        self.root.sessions.byCharacter[characterKey] = snapshot
    else
        Cortex.Schema.MergeMissing(snapshot, Cortex.Schema.NewSessionSnapshot())
    end
    return snapshot
end

function Sessions:Get(characterKey)
    return self.root.sessions.byCharacter[characterKey]
end

function Sessions:MarkLogin(characterKey, timestamp)
    local snapshot = self:GetOrCreate(characterKey)
    if not snapshot or type(timestamp) ~= "number" then
        return false
    end
    snapshot.lastLogin = timestamp
    return true
end

function Sessions:MarkLogout(characterKey, timestamp)
    local snapshot = self:GetOrCreate(characterKey)
    if not snapshot or type(timestamp) ~= "number" then
        return false
    end
    snapshot.lastLogout = timestamp
    return true
end

function Sessions:CaptureCharacterState(characterKey, record)
    local snapshot = self:GetOrCreate(characterKey)
    if not snapshot or type(record) ~= "table" then
        return false
    end

    snapshot.lastKnownCharacterState = {
        schemaVersion = Cortex.Constants.SESSION_SNAPSHOT_SCHEMA_VERSION,
        capturedAt = type(record.lastSeenAt) == "number" and record.lastSeenAt or 0,
        level = type(record.level) == "number" and record.level or nil,
    }
    return true
end

function Sessions:CaptureUnfinishedGoals(characterKey, goalItems)
    local snapshot = self:GetOrCreate(characterKey)
    if not snapshot or type(goalItems) ~= "table" then
        return false
    end

    local goalIds = {}
    for goalId, goal in pairs(goalItems) do
        if Cortex.Schema.IsPositiveInteger(goalId)
            and type(goal) == "table"
            and (goal.status == Cortex.Constants.GOAL_STATUSES.ACTIVE
                or goal.status == Cortex.Constants.GOAL_STATUSES.BLOCKED
                or goal.status == Cortex.Constants.GOAL_STATUSES.PAUSED) then
            goalIds[#goalIds + 1] = goalId
        end
    end
    table.sort(goalIds)

    while #goalIds > Cortex.Constants.MAX_SNAPSHOT_REFERENCES do
        goalIds[#goalIds] = nil
    end
    snapshot.unfinishedGoals = goalIds
    return true
end

function Sessions:CaptureUnfinishedTasks(characterKey, taskItems)
    local snapshot = self:GetOrCreate(characterKey)
    if not snapshot or type(taskItems) ~= "table" then
        return false
    end

    local tasks = {}
    local seen = {}
    for index = 1, #taskItems do
        local task = taskItems[index]
        local taskId = type(task) == "table" and task.id or task
        if isNonEmptyString(taskId) and not seen[taskId] then
            local reference = { id = taskId }
            if type(task) == "table" and Cortex.Schema.IsPositiveInteger(task.goalId) then
                reference.goalId = task.goalId
            end
            tasks[#tasks + 1] = reference
            seen[taskId] = true
            if #tasks >= Cortex.Constants.MAX_SNAPSHOT_REFERENCES then
                break
            end
        end
    end
    snapshot.unfinishedTasks = tasks
    return true
end

function Sessions:ImportLegacy(characterKey, legacyDatabase, importedAt)
    if type(legacyDatabase) ~= "table" or type(legacyDatabase.session) ~= "table" then
        return false
    end

    local migration = legacyDatabase.migration
    if type(migration) == "table" and migration.characterKey == characterKey then
        return true
    end

    local snapshot = self:GetOrCreate(characterKey)
    if not snapshot then
        return false
    end

    local legacySession = legacyDatabase.session
    if type(legacySession.lastLoginAt) == "number" and legacySession.lastLoginAt > snapshot.lastLogin then
        snapshot.lastLogin = legacySession.lastLoginAt
    end
    if type(legacySession.lastLogoutAt) == "number" and legacySession.lastLogoutAt > snapshot.lastLogout then
        snapshot.lastLogout = legacySession.lastLogoutAt
    end

    legacyDatabase.migration = {
        characterKey = characterKey,
        importedAt = importedAt,
    }
    return true
end

local History = {}
History.__index = History

function History:Append(eventType, timestamp, characterKey, details)
    if not isNonEmptyString(eventType) or type(timestamp) ~= "number" then
        return nil
    end

    local history = self.root.history
    local entry = {
        id = history.nextId,
        type = eventType,
        at = timestamp,
    }
    if isNonEmptyString(characterKey) then
        entry.characterKey = characterKey
    end
    if type(details) == "table" then
        local compactDetails = {}
        local detailCount = 0
        for key, value in pairs(details) do
            if isNonEmptyString(key)
                and Cortex:IsAccessibleValue(value)
                and (type(value) == "string" or type(value) == "number" or type(value) == "boolean") then
                compactDetails[key] = value
                detailCount = detailCount + 1
                if detailCount >= 8 then
                    break
                end
            end
        end
        if detailCount > 0 then
            entry.details = compactDetails
        end
    end

    history.items[#history.items + 1] = entry
    history.nextId = history.nextId + 1
    while #history.items > Cortex.Constants.MAX_HISTORY_ENTRIES do
        table.remove(history.items, 1)
    end
    return entry
end

function History:Count()
    return #self.root.history.items
end

function Repositories.New(root)
    return {
        characters = setmetatable({ root = root }, Characters),
        sessions = setmetatable({ root = root }, Sessions),
        history = setmetatable({ root = root }, History),
    }
end

Cortex.Repositories = Repositories
