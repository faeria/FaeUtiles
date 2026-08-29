local _, Cortex = ...

local Validation = {}

local ALLOWED_TYPES = { GOAL = true, SESSION = true, TASK_LIST = true }

local function isSafeString(value, maximum, allowEmpty)
    return type(value) == "string" and Cortex:IsAccessibleValue(value)
        and #value <= maximum and (allowEmpty or value ~= "")
        and not value:find("[%z\1-\31\127]")
end

local function hasOnlyKeys(value, allowed)
    if type(value) ~= "table" or Cortex:IsSecretTable(value) or not Cortex:IsAccessibleValue(value)
        or getmetatable(value) ~= nil then return false end
    for key in pairs(value) do if type(key) ~= "string" or not allowed[key] then return false end end
    return true
end

local function isIntegerBetween(value, minimum, maximum)
    return type(value) == "number" and Cortex:IsAccessibleValue(value) and value == math.floor(value)
        and value >= minimum and value <= maximum
end

local TASK_KEYS = { title = true, estimatedMinutes = true, category = true }
local function validateTask(task)
    if not hasOnlyKeys(task, TASK_KEYS) or not isSafeString(task.title, 120, false) then
        return nil, "invalid-task"
    end
    if task.estimatedMinutes ~= nil and not isIntegerBetween(task.estimatedMinutes, 1, 480) then
        return nil, "invalid-task-duration"
    end
    if task.category ~= nil and not isSafeString(task.category, 40, false) then
        return nil, "invalid-task-category"
    end
    return {
        title = task.title,
        estimatedMinutes = task.estimatedMinutes,
        category = task.category,
    }
end

local function validateTasks(tasks)
    if type(tasks) ~= "table" or Cortex:IsSecretTable(tasks) or not Cortex:IsAccessibleValue(tasks)
        or getmetatable(tasks) ~= nil
        or #tasks > Cortex.Constants.MAX_SHARE_TASKS then return nil, "invalid-tasks" end
    local normalized = {}
    for key in pairs(tasks) do
        if type(key) ~= "number" or key < 1 or key > #tasks or key ~= math.floor(key) then
            return nil, "invalid-tasks"
        end
    end
    for index = 1, #tasks do
        local task, reason = validateTask(tasks[index])
        if not task then return nil, reason end
        normalized[index] = task
    end
    return normalized
end

local GOAL_KEYS = {
    title = true, description = true, goalType = true, priority = true,
    estimatedMinutes = true, requiredActivities = true,
}
local function validateGoal(payload)
    if not hasOnlyKeys(payload, GOAL_KEYS) or not isSafeString(payload.title, 120, false) then
        return nil, "invalid-goal"
    end
    if payload.description ~= nil and not isSafeString(payload.description, 500, true) then
        return nil, "invalid-goal-description"
    end
    local goalType = payload.goalType or "GENERIC"
    if not isSafeString(goalType, 40, false)
        or (goalType ~= "GENERIC" and goalType ~= "WEEKLY_COMPLETION") then
        return nil, "invalid-goal-type"
    end
    local priority = payload.priority or 50
    if not isIntegerBetween(priority, 0, 100) then return nil, "invalid-goal-priority" end
    local duration = payload.estimatedMinutes or 30
    if not isIntegerBetween(duration, 1, 480) then return nil, "invalid-goal-duration" end
    local requiredActivities = payload.requiredActivities
    if goalType == "WEEKLY_COMPLETION" then
        requiredActivities = requiredActivities or 1
        if not isIntegerBetween(requiredActivities, 1, 9) then return nil, "invalid-weekly-target" end
    elseif requiredActivities ~= nil then
        return nil, "unexpected-weekly-target"
    end
    return {
        title = payload.title,
        description = payload.description or "",
        goalType = goalType,
        priority = priority,
        estimatedMinutes = duration,
        requiredActivities = requiredActivities,
    }
end

local SESSION_KEYS = { title = true, budgetMinutes = true, tasks = true }
local function validateSession(payload)
    if not hasOnlyKeys(payload, SESSION_KEYS) or not isSafeString(payload.title, 120, false) then
        return nil, "invalid-session"
    end
    local budget = payload.budgetMinutes
    local validBudget = type(budget) == "string"
        and isSafeString(budget, 20, false) and budget == "UNLIMITED"
        or isIntegerBetween(budget, 5, 480)
    if not validBudget then
        return nil, "invalid-session-budget"
    end
    local tasks, reason = validateTasks(payload.tasks or {})
    if not tasks then return nil, reason end
    return { title = payload.title, budgetMinutes = budget, tasks = tasks }
end

local TASK_LIST_KEYS = { title = true, tasks = true }
local function validateTaskList(payload)
    if not hasOnlyKeys(payload, TASK_LIST_KEYS) or not isSafeString(payload.title, 120, false) then
        return nil, "invalid-task-list"
    end
    local tasks, reason = validateTasks(payload.tasks or {})
    if not tasks then return nil, reason end
    return { title = payload.title, tasks = tasks }
end

function Validation:IsKnownType(shareType)
    return isSafeString(shareType, 20, false) and ALLOWED_TYPES[shareType] == true
end

function Validation:Validate(shareType, payload)
    if not self:IsKnownType(shareType) then return nil, "unknown-type" end
    if shareType == "GOAL" then return validateGoal(payload) end
    if shareType == "SESSION" then return validateSession(payload) end
    return validateTaskList(payload)
end

function Validation:Describe(shareType, payload)
    if shareType == "GOAL" then
        return Cortex:GetText("SHARE_PREVIEW_GOAL", payload.title, payload.goalType,
            payload.priority, payload.estimatedMinutes)
    end
    if shareType == "SESSION" then
        local budget = payload.budgetMinutes == "UNLIMITED" and Cortex:GetText("SESSION_BUDGET_UNLIMITED")
            or Cortex:GetText("SESSION_BUDGET_MINUTES", payload.budgetMinutes)
        return Cortex:GetText("SHARE_PREVIEW_SESSION", payload.title, budget, #payload.tasks)
    end
    return Cortex:GetText("SHARE_PREVIEW_TASK_LIST", payload.title, #payload.tasks)
end

Cortex:RegisterService("ShareValidation", Validation)
