local _, Cortex = ...

local Goal = {}

function Goal.Create(id, title)
    if type(id) ~= "number" or type(title) ~= "string" or title == "" then
        return nil
    end

    return {
        schemaVersion = Cortex.Constants.GOAL_SCHEMA_VERSION,
        id = id,
        title = title,
        status = "active",
        priority = 50,
        estimatedMinutes = 30,
        createdAt = time(),
    }
end

function Goal.IsActive(goal)
    return type(goal) == "table"
        and type(goal.id) == "number"
        and goal.id >= 1
        and goal.id == math.floor(goal.id)
        and type(goal.title) == "string"
        and goal.status == "active"
end

Cortex.Goal = Goal
