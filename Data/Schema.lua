local _, Cortex = ...

local Schema = {}

Schema.accountDefaults = {
    schemaVersion = Cortex.Constants.ACCOUNT_SCHEMA_VERSION,
    settings = {
        logLevel = "INFO",
        profiling = false,
        window = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
            scale = 1,
        },
    },
    characters = {},
    goals = {
        schemaVersion = Cortex.Constants.GOALS_SCHEMA_VERSION,
        nextId = 1,
        items = {},
    },
    history = {
        schemaVersion = 1,
        nextId = 1,
        items = {},
    },
    sessions = {
        schemaVersion = 1,
        byCharacter = {},
    },
    warband = {
        schemaVersion = 2,
    },
    modules = {
        schemaVersion = 1,
        states = {},
    },
    templates = {
        schemaVersion = 1,
        nextId = 1,
        sessions = {},
        taskLists = {},
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

function Schema.Copy(source, seen)
    if type(source) ~= "table" then
        return source
    end

    seen = seen or {}
    if seen[source] then
        return seen[source]
    end

    local copy = {}
    seen[source] = copy
    for key, value in pairs(source) do
        copy[Schema.Copy(key, seen)] = Schema.Copy(value, seen)
    end
    return copy
end

function Schema.ValuesEqual(left, right, seen)
    if rawequal(left, right) then return true end
    if not Cortex:IsAccessibleValue(left) or not Cortex:IsAccessibleValue(right)
        or type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    if Cortex:IsSecretTable(left) or Cortex:IsSecretTable(right) then return false end
    seen = seen or {}
    if seen[left] then return seen[left] == right end
    seen[left] = right
    for key, value in pairs(left) do
        if not Cortex:IsAccessibleValue(key) or not Schema.ValuesEqual(value, right[key], seen) then return false end
    end
    for key in pairs(right) do
        if not Cortex:IsAccessibleValue(key) or left[key] == nil then return false end
    end
    return true
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

function Schema.IsPositiveInteger(value)
    return type(value) == "number" and value >= 1 and value == math.floor(value)
end

local VALID_ANCHOR_POINTS = {
    TOPLEFT = true, TOP = true, TOPRIGHT = true,
    LEFT = true, CENTER = true, RIGHT = true,
    BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}

function Schema.NormalizeWindowPlacement(placement)
    if type(placement) ~= "table" then placement = {} end
    local defaults = Schema.accountDefaults.settings.window
    placement.point = VALID_ANCHOR_POINTS[placement.point] and placement.point or defaults.point
    placement.relativePoint = VALID_ANCHOR_POINTS[placement.relativePoint]
        and placement.relativePoint or defaults.relativePoint
    placement.x = type(placement.x) == "number" and math.max(-4000, math.min(4000, placement.x)) or defaults.x
    placement.y = type(placement.y) == "number" and math.max(-4000, math.min(4000, placement.y)) or defaults.y
    placement.scale = type(placement.scale) == "number"
        and math.max(0.75, math.min(1.25, placement.scale)) or defaults.scale
    return placement
end

local LEGACY_GOAL_STATUSES = {
    active = Cortex.Constants.GOAL_STATUSES.ACTIVE,
    blocked = Cortex.Constants.GOAL_STATUSES.BLOCKED,
    completed = Cortex.Constants.GOAL_STATUSES.COMPLETED,
    paused = Cortex.Constants.GOAL_STATUSES.PAUSED,
    failed = Cortex.Constants.GOAL_STATUSES.FAILED,
}

function Schema.NormalizeGoal(goal, goalId)
    if type(goal) ~= "table" then return false end

    if Schema.IsPositiveInteger(goalId) then goal.id = goalId end
    if not Schema.IsPositiveInteger(goal.id) then return false end
    goal.schemaVersion = Cortex.Constants.GOAL_SCHEMA_VERSION
    goal.type = type(goal.type) == "string" and goal.type ~= "" and string.upper(goal.type) or "GENERIC"
    goal.title = type(goal.title) == "string" and goal.title or ""
    goal.description = type(goal.description) == "string" and goal.description or ""

    local status = goal.status
    if type(status) == "string" then status = LEGACY_GOAL_STATUSES[string.lower(status)] or string.upper(status) end
    if not Cortex.Constants.GOAL_STATUSES[status] then status = Cortex.Constants.GOAL_STATUSES.ACTIVE end
    goal.status = status

    if type(goal.priority) ~= "number" then goal.priority = 50 end
    goal.priority = math.max(0, math.min(100, goal.priority))
    if type(goal.createdAt) ~= "number" then goal.createdAt = 0 end
    if status ~= Cortex.Constants.GOAL_STATUSES.COMPLETED then
        goal.completedAt = nil
    elseif type(goal.completedAt) ~= "number" then
        goal.completedAt = 0
    end

    goal.target = type(goal.target) == "table" and goal.target or {}
    local progress = goal.progress
    if type(progress) == "number" then progress = { current = progress } end
    if type(progress) ~= "table" then progress = {} end
    if type(progress.current) ~= "number" then progress.current = 0 end
    if type(progress.total) ~= "number" or progress.total <= 0 then progress.total = 1 end
    if type(progress.percent) ~= "number" then
        progress.percent = math.max(0, math.min(1, progress.current / progress.total))
    end
    if type(progress.availability) ~= "string" then progress.availability = "UNKNOWN" end
    if type(progress.updatedAt) ~= "number" then progress.updatedAt = 0 end
    goal.progress = progress

    local dependencies, seen = {}, {}
    if type(goal.dependencies) == "table" then
        for index = 1, #goal.dependencies do
            local dependencyId = goal.dependencies[index]
            if Schema.IsPositiveInteger(dependencyId) and not seen[dependencyId] then
                dependencies[#dependencies + 1] = dependencyId
                seen[dependencyId] = true
            end
        end
    end
    goal.dependencies = dependencies
    goal.metadata = type(goal.metadata) == "table" and goal.metadata or {}
    if type(goal.metadata.estimatedMinutes) ~= "number" and type(goal.estimatedMinutes) == "number" then
        goal.metadata.estimatedMinutes = goal.estimatedMinutes
    end
    goal.estimatedMinutes = nil
    return true
end

function Schema.NewSessionSnapshot()
    return {
        schemaVersion = Cortex.Constants.SESSION_SNAPSHOT_SCHEMA_VERSION,
        lastLogin = 0,
        lastLogout = 0,
        lastKnownCharacterState = {},
        unfinishedGoals = {},
        unfinishedTasks = {},
    }
end

function Schema.NewWarbandSnapshot()
    return {
        schemaVersion = Cortex.Constants.WARBAND_SNAPSHOT_SCHEMA_VERSION,
        capturedAt = 0,
        fields = {},
    }
end

local function normalizeTemplateTask(task)
    if type(task) ~= "table" or type(task.title) ~= "string" or task.title == ""
        or #task.title > 120 then return nil end
    local duration = type(task.estimatedMinutes) == "number" and math.floor(task.estimatedMinutes) or nil
    if duration and (duration < 1 or duration > 480) then duration = nil end
    return {
        title = task.title,
        estimatedMinutes = duration,
        category = type(task.category) == "string" and #task.category <= 40 and task.category or nil,
    }
end

local function normalizeTemplateTasks(tasks)
    local normalized = {}
    if type(tasks) ~= "table" then return normalized end
    for index = 1, math.min(#tasks, Cortex.Constants.MAX_SHARE_TASKS) do
        local task = normalizeTemplateTask(tasks[index])
        if task then normalized[#normalized + 1] = task end
    end
    return normalized
end

local function normalizeStoredTemplates(items, kind)
    local normalized = {}
    if type(items) ~= "table" then return normalized end
    for templateId, template in pairs(items) do
        if Schema.IsPositiveInteger(templateId) and type(template) == "table"
            and type(template.title) == "string" and template.title ~= "" and #template.title <= 120 then
            local record = {
                id = templateId,
                title = template.title,
                tasks = normalizeTemplateTasks(template.tasks),
                importedAt = type(template.importedAt) == "number" and template.importedAt or 0,
            }
            if kind == "SESSION" then
                local budget = template.budgetMinutes
                if budget == "UNLIMITED" or (type(budget) == "number" and budget >= 5 and budget <= 480) then
                    record.budgetMinutes = budget
                    normalized[templateId] = record
                end
            else
                normalized[templateId] = record
            end
        end
    end
    return normalized
end

function Schema.NormalizeTemplates(templates)
    templates = type(templates) == "table" and templates or {}
    templates.schemaVersion = 1
    templates.sessions = normalizeStoredTemplates(templates.sessions, "SESSION")
    templates.taskLists = normalizeStoredTemplates(templates.taskLists, "TASK_LIST")
    local maximumId = 0
    for templateId in pairs(templates.sessions) do maximumId = math.max(maximumId, templateId) end
    for templateId in pairs(templates.taskLists) do maximumId = math.max(maximumId, templateId) end
    templates.nextId = type(templates.nextId) == "number" and math.floor(templates.nextId) or 1
    templates.nextId = math.max(1, maximumId + 1, templates.nextId)
    return templates
end

local function normalizeTimestampedField(field)
    if type(field) ~= "table" or type(field.capturedAt) ~= "number" or field.capturedAt < 0 then return nil end
    return field
end

local function normalizeProfessions(field)
    field = normalizeTimestampedField(field)
    if not field or type(field.value) ~= "table" then return nil end
    local professions = {}
    for index = 1, math.min(8, #field.value) do
        local profession = field.value[index]
        if type(profession) == "table" and type(profession.name) == "string" and profession.name ~= "" then
            professions[#professions + 1] = {
                name = profession.name,
                skillLine = type(profession.skillLine) == "number" and profession.skillLine or nil,
                skillLevel = type(profession.skillLevel) == "number" and profession.skillLevel or nil,
                maxSkillLevel = type(profession.maxSkillLevel) == "number" and profession.maxSkillLevel or nil,
            }
        end
    end
    field.value = professions
    return field
end

local function normalizeCurrencies(field)
    field = normalizeTimestampedField(field)
    if not field or type(field.value) ~= "table" then return nil end
    local currencies, seen = {}, {}
    for index = 1, math.min(Cortex.Constants.MAX_WARBAND_CURRENCIES, #field.value) do
        local currency = field.value[index]
        if type(currency) == "table" and Schema.IsPositiveInteger(currency.currencyID)
            and not seen[currency.currencyID] then
            currencies[#currencies + 1] = {
                currencyID = currency.currencyID,
                name = type(currency.name) == "string" and currency.name or nil,
                quantity = type(currency.quantity) == "number" and currency.quantity or nil,
                iconFileID = type(currency.iconFileID) == "number" and currency.iconFileID or nil,
            }
            seen[currency.currencyID] = true
        end
    end
    field.value = currencies
    return field
end

local function normalizeWeekly(field)
    field = normalizeTimestampedField(field)
    if not field or type(field.value) ~= "table" then return nil end
    local weekly = field.value
    local canClaimRewards, hasAvailableRewards
    if type(weekly.canClaimRewards) == "boolean" then canClaimRewards = weekly.canClaimRewards end
    if type(weekly.hasAvailableRewards) == "boolean" then
        hasAvailableRewards = weekly.hasAvailableRewards
    end
    field.value = {
        completedActivities = type(weekly.completedActivities) == "number"
            and math.max(0, math.floor(weekly.completedActivities)) or 0,
        totalActivities = type(weekly.totalActivities) == "number"
            and math.max(0, math.floor(weekly.totalActivities)) or 0,
        canClaimRewards = canClaimRewards,
        hasAvailableRewards = hasAvailableRewards,
    }
    return field
end

function Schema.NormalizeWarbandCharacter(record, characterKey)
    if type(record) ~= "table" or type(characterKey) ~= "string" or characterKey == "" then return false end
    if type(record.guid) ~= "string" or record.guid == "" then record.guid = characterKey end
    if record.guid ~= characterKey then return false end
    record.schemaVersion = Cortex.Constants.CHARACTER_RECORD_SCHEMA_VERSION
    record.name = type(record.name) == "string" and record.name or nil
    record.realm = type(record.realm) == "string" and record.realm or nil
    record.classFile = type(record.classFile) == "string" and record.classFile or nil
    record.classId = type(record.classId) == "number" and record.classId or nil
    record.level = type(record.level) == "number" and math.max(0, math.floor(record.level)) or nil
    record.lastSeenAt = type(record.lastSeenAt) == "number" and math.max(0, record.lastSeenAt) or 0
    local snapshot = type(record.snapshot) == "table" and record.snapshot or Schema.NewWarbandSnapshot()
    snapshot.schemaVersion = Cortex.Constants.WARBAND_SNAPSHOT_SCHEMA_VERSION
    snapshot.capturedAt = type(snapshot.capturedAt) == "number" and math.max(0, snapshot.capturedAt) or 0
    snapshot.fields = type(snapshot.fields) == "table" and snapshot.fields or {}
    local fields = snapshot.fields
    local itemLevel = normalizeTimestampedField(fields.itemLevel)
    if itemLevel and type(itemLevel.value) == "number" and itemLevel.value >= 0 then
        itemLevel.value = math.floor(itemLevel.value * 100 + 0.5) / 100
    else
        itemLevel = nil
    end
    fields.itemLevel = itemLevel
    fields.professions = normalizeProfessions(fields.professions)
    fields.transferableCurrencies = normalizeCurrencies(fields.transferableCurrencies)
    fields.weekly = normalizeWeekly(fields.weekly)
    record.snapshot = snapshot
    return true
end

local function validateSessionSnapshot(snapshot)
    Schema.MergeMissing(snapshot, Schema.NewSessionSnapshot())

    if type(snapshot.lastLogin) ~= "number" then
        snapshot.lastLogin = 0
    end
    if type(snapshot.lastLogout) ~= "number" then
        snapshot.lastLogout = 0
    end
    if type(snapshot.lastKnownCharacterState) ~= "table" then
        snapshot.lastKnownCharacterState = {}
    end
    if type(snapshot.unfinishedGoals) ~= "table" then
        snapshot.unfinishedGoals = {}
    end
    if type(snapshot.unfinishedTasks) ~= "table" then
        snapshot.unfinishedTasks = {}
    end
end

function Schema.ValidateAccount(database)
    local defaults = Schema.accountDefaults

    if type(database.settings) ~= "table" then
        database.settings = Schema.Copy(defaults.settings)
    end
    if not Cortex.Constants.LOG_LEVELS[database.settings.logLevel] then
        database.settings.logLevel = defaults.settings.logLevel
    end
    if type(database.settings.profiling) ~= "boolean" then
        database.settings.profiling = defaults.settings.profiling
    end
    database.settings.window = Schema.NormalizeWindowPlacement(database.settings.window)

    if type(database.characters) ~= "table" then
        database.characters = {}
    end
    for characterKey, record in pairs(database.characters) do
        if not Schema.NormalizeWarbandCharacter(record, characterKey) then
            database.characters[characterKey] = nil
        end
    end

    if type(database.goals) ~= "table" then
        database.goals = Schema.Copy(defaults.goals)
    end
    if type(database.goals.items) ~= "table" then
        database.goals.items = {}
    end
    database.goals.schemaVersion = Cortex.Constants.GOALS_SCHEMA_VERSION
    if not Schema.IsPositiveInteger(database.goals.nextId) then
        database.goals.nextId = 1
    end

    local highestGoalId = 0
    for key, goal in pairs(database.goals.items) do
        if Schema.IsPositiveInteger(key) and Schema.NormalizeGoal(goal, key) then
            if key > highestGoalId then highestGoalId = key end
        else
            database.goals.items[key] = nil
        end
    end
    if database.goals.nextId <= highestGoalId then
        database.goals.nextId = highestGoalId + 1
    end

    if type(database.history) ~= "table" then
        database.history = Schema.Copy(defaults.history)
    end
    if type(database.history.items) ~= "table" then
        database.history.items = {}
    end
    if not Schema.IsPositiveInteger(database.history.nextId) then
        database.history.nextId = 1
    end
    local highestHistoryId = 0
    for _, entry in pairs(database.history.items) do
        if type(entry) == "table"
            and Schema.IsPositiveInteger(entry.id)
            and entry.id > highestHistoryId then
            highestHistoryId = entry.id
        end
    end
    if database.history.nextId <= highestHistoryId then
        database.history.nextId = highestHistoryId + 1
    end

    if type(database.sessions) ~= "table" then
        database.sessions = Schema.Copy(defaults.sessions)
    end
    if type(database.sessions.byCharacter) ~= "table" then
        database.sessions.byCharacter = {}
    end
    for characterKey, snapshot in pairs(database.sessions.byCharacter) do
        if type(characterKey) == "string" and type(snapshot) == "table" then
            validateSessionSnapshot(snapshot)
        end
    end

    if type(database.warband) ~= "table" then
        database.warband = Schema.Copy(defaults.warband)
    end
    database.warband.schemaVersion = 2

    if type(database.modules) ~= "table" then
        database.modules = Schema.Copy(defaults.modules)
    end
    if type(database.modules.states) ~= "table" then
        database.modules.states = {}
    end
    database.templates = Schema.NormalizeTemplates(database.templates)
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
