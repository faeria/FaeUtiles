local _, Cortex = ...

local ChatCommands = {
    isRegistered = false,
}

local function trim(value)
    return value:match("^%s*(.-)%s*$")
end

local function printText(key, ...)
    Cortex:GetService("Logger"):User(Cortex:GetText(key, ...))
end

local function printHelp()
    printText("HELP_HEADER")
    printText("HELP_OPEN")
    printText("HELP_NOW")
    printText("HELP_GOAL_ADD")
    printText("HELP_GOAL_DONE")
    printText("HELP_GOALS")
    printText("HELP_STATUS")
    printText("HELP_LOG")
    printText("HELP_DEBUG")
end

local function showStatus()
    local goals = Cortex:GetModule("Goals")
    printText(
        "STATUS",
        Cortex.version,
        Cortex:IsModuleEnabled("Goals") and goals:GetActiveCount() or 0,
        Cortex:GetService("Context"):GetKnownCharacterCount()
    )
end

local function showGoals()
    if not Cortex:IsModuleEnabled("Goals") then
        printText("MODULE_DISABLED", "Goals")
        return
    end

    local goals = Cortex:GetModule("Goals"):GetActiveGoals()
    if #goals == 0 then
        printText("GOALS_EMPTY")
        return
    end

    printText("GOALS_HEADER")
    for index = 1, #goals do
        printText("GOAL_ITEM", goals[index].id, goals[index].title)
    end
end

local function handleGoal(message)
    if not Cortex:IsModuleEnabled("Goals") then
        printText("MODULE_DISABLED", "Goals")
        return
    end

    local action, argument = message:match("^(%S+)%s*(.-)$")
    action = action and string.lower(action) or ""
    argument = trim(argument or "")
    local goals = Cortex:GetModule("Goals")

    if action == "add" then
        if argument == "" then
            printText("GOAL_TITLE_REQUIRED")
            return
        end

        local goal = goals:Add(argument)
        printText("GOAL_ADDED", goal.id, goal.title)
        return
    end

    if action == "done" then
        local id = tonumber(argument)
        if not id or id < 1 or id ~= math.floor(id) then
            printText("GOAL_ID_REQUIRED")
            return
        end

        if goals:Complete(id) then
            printText("GOAL_COMPLETED", id)
        else
            printText("GOAL_NOT_FOUND", id)
        end
        return
    end

    printHelp()
end

local function showPlan(message)
    if not Cortex:IsModuleEnabled("Planner") then
        printText("MODULE_DISABLED", "Planner")
        return
    end

    local durationText = trim(message)
    local minutes = durationText == "" and 30 or tonumber(durationText)
    if not minutes or minutes < 5 or minutes > 240 then
        printText("INVALID_DURATION")
        return
    end

    minutes = math.floor(minutes)
    local plan = Cortex:GetModule("Planner"):Build(minutes)
    printText("PLAN_HEADER", minutes)

    if #plan == 0 then
        printText("PLAN_EMPTY")
        return
    end

    for index = 1, #plan do
        local recommendation = plan[index]
        printText(
            "RECOMMENDATION_ITEM",
            index,
            recommendation.title,
            recommendation.estimatedMinutes,
            recommendation.priority
        )
        printText("RECOMMENDATION_DESCRIPTION", recommendation.description)
        printText("RECOMMENDATION_REASON", recommendation.reason)
        printText("RECOMMENDATION_BENEFIT", recommendation.benefit)
    end
end

local function setLogLevel(message)
    local level = string.upper(trim(message))
    local logger = Cortex:GetService("Logger")
    if not logger:SetLevel(level) then
        printText("INVALID_LOG_LEVEL")
        return
    end

    Cortex:GetService("Database"):SetLogLevel(level)
    printText("LOG_LEVEL_SET", level)
end

local function setDebug(message)
    local value = string.lower(trim(message))
    if value == "" then
        value = Cortex:GetService("Logger"):GetLevel() == "DEBUG" and "off" or "on"
    end

    if value == "on" then
        setLogLevel("DEBUG")
    elseif value == "off" then
        setLogLevel("INFO")
    else
        printText("INVALID_DEBUG_VALUE")
    end
end

function ChatCommands:Handle(message)
    local input = trim(message or "")
    if input == "" then
        Cortex:GetService("MainWindow"):Toggle()
        return
    end

    local command, arguments = input:match("^(%S+)%s*(.-)$")
    command = string.lower(command)

    if command == "help" then
        printHelp()
    elseif command == "now" then
        showPlan(arguments)
    elseif command == "goal" then
        handleGoal(arguments)
    elseif command == "goals" then
        showGoals()
    elseif command == "status" then
        showStatus()
    elseif command == "log" then
        setLogLevel(arguments)
    elseif command == "debug" then
        setDebug(arguments)
    else
        printText("UNKNOWN_COMMAND")
    end
end

function ChatCommands:Register()
    if self.isRegistered then
        return
    end

    _G.SLASH_CORTEX1 = "/cortex"
    SlashCmdList.CORTEX = function(message)
        ChatCommands:Handle(message)
    end
    self.isRegistered = true
end

function ChatCommands:Initialize()
    self:Register()
end

Cortex:RegisterService("ChatCommands", ChatCommands, {
    services = { "Logger", "Database", "Context", "MainWindow" },
    modules = { "Goals", "Planner" },
})
