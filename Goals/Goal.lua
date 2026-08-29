local _, Cortex = ...

local Goal = {}
local STATUSES = Cortex.Constants.GOAL_STATUSES

function Goal.Create(id, specification)
    if not Cortex.Schema.IsPositiveInteger(id) then return nil end
    if type(specification) == "string" then specification = { title = specification } end
    if type(specification) ~= "table" or type(specification.title) ~= "string"
        or specification.title == "" then return nil end

    local goal = {
        schemaVersion = Cortex.Constants.GOAL_SCHEMA_VERSION,
        id = id,
        type = specification.type or "GENERIC",
        title = specification.title,
        description = specification.description or "",
        status = specification.status or STATUSES.ACTIVE,
        priority = specification.priority or 50,
        createdAt = specification.createdAt or time(),
        completedAt = specification.completedAt,
        progress = Cortex.Schema.Copy(specification.progress or {
            current = 0,
            total = 1,
            percent = 0,
            availability = "UNKNOWN",
            updatedAt = 0,
        }),
        target = Cortex.Schema.Copy(specification.target or {}),
        dependencies = Cortex.Schema.Copy(specification.dependencies or {}),
        metadata = Cortex.Schema.Copy(specification.metadata or {}),
    }
    return Cortex.Schema.NormalizeGoal(goal, id) and goal or nil
end

function Goal.IsStatus(value)
    return type(value) == "string" and STATUSES[value] ~= nil
end

function Goal.IsActive(goal)
    return type(goal) == "table" and goal.status == STATUSES.ACTIVE
end

function Goal.IsCompleted(goal)
    return type(goal) == "table" and goal.status == STATUSES.COMPLETED
end

function Goal.IsOpen(goal)
    return type(goal) == "table" and (goal.status == STATUSES.ACTIVE
        or goal.status == STATUSES.BLOCKED or goal.status == STATUSES.PAUSED)
end

function Goal.SetProgress(goal, current, total, availability, updatedAt)
    if type(goal) ~= "table" or type(current) ~= "number" or type(total) ~= "number" or total <= 0 then
        return false
    end
    goal.progress = goal.progress or {}
    goal.progress.current = math.max(0, current)
    goal.progress.total = total
    goal.progress.percent = math.max(0, math.min(1, current / total))
    goal.progress.availability = type(availability) == "string" and availability or "AVAILABLE"
    goal.progress.updatedAt = type(updatedAt) == "number" and updatedAt or time()
    return true
end

Cortex.Goal = Goal
