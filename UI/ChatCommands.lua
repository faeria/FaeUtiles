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
    printText("HELP_HELP")
    printText("HELP_NOW")
    printText("HELP_GOAL_ADD")
    printText("HELP_GOAL_DONE")
    printText("HELP_GOAL_WEEKLY")
    printText("HELP_GOAL_LIST")
    printText("HELP_GOAL_DEBUG")
    printText("HELP_GOALS")
    printText("HELP_RECOMMEND")
    printText("HELP_WHY")
    printText("HELP_SHARE")
    printText("HELP_DEBRIEF")
    printText("HELP_VERSION")
    printText("HELP_STATUS")
    printText("HELP_LOG")
    printText("HELP_DEBUG")
    printText("HELP_DEBUG_DB")
    printText("HELP_DEBUG_CONTEXT")
    printText("HELP_DEBUG_REFRESH")
    printText("HELP_DEBUG_PROFILE")
end

local function handleShare(message)
    local action, rest = trim(message):match("^(%S*)%s*(.-)$")
    action = string.lower(action or "")
    rest = trim(rest or "")
    if action == "" or action == "import" then
        Cortex:GetService("ShareCodeDialog"):Show(rest ~= "" and rest or nil)
        return
    end
    if action ~= "export" then printText("SHARE_USAGE"); return end
    local shareType, idText = rest:match("^(%S+)%s+(%d+)$")
    local templateId = tonumber(idText)
    shareType = string.lower(shareType or "")
    local code, reason
    if shareType == "goal" then
        code, reason = Cortex:GetService("ShareCodes"):ExportGoal(templateId)
    elseif shareType == "session" then
        code, reason = Cortex:GetService("ShareCodes"):ExportTemplate("SESSION", templateId)
    elseif shareType == "tasks" or shareType == "task_list" then
        code, reason = Cortex:GetService("ShareCodes"):ExportTemplate("TASK_LIST", templateId)
    else
        printText("SHARE_USAGE")
        return
    end
    if code then printText("SHARE_EXPORT_CODE", code) else printText("SHARE_EXPORT_FAILED", reason or "unknown") end
end

local function showExplanation(message)
    local targetType, targetId, level = trim(message):match("^(%S*)%s*(%S*)%s*(%S*)$")
    targetType = string.lower(targetType or "")
    level = string.upper(level ~= "" and level or "DETAIL")
    if level ~= "SUMMARY" and level ~= "DETAIL" and level ~= "DEBUG" then
        printText("DETECTIVE_INVALID_LEVEL")
        return
    end

    local explanation
    if targetType == "" then
        local recommendations = Cortex:GetModule("Recommendations"):GetRecommendations()
        explanation = recommendations[1]
            and Cortex:GetService("Detective"):ExplainRecommendation(recommendations[1]) or nil
    elseif targetType == "recommendation" or targetType == "recommend" then
        explanation = Cortex:GetService("Detective"):ExplainRecommendation(targetId)
    elseif targetType == "goal" then
        explanation = Cortex:GetService("Detective"):ExplainGoal(tonumber(targetId))
    elseif targetType == "fact" then
        explanation = Cortex:GetService("Detective"):ExplainFact(targetId)
    else
        printText("DETECTIVE_USAGE")
        return
    end
    if not explanation then
        printText("DETECTIVE_NO_RECOMMENDATION")
        return
    end
    printText("DETECTIVE_HEADER", explanation.targetType, tostring(explanation.targetId or "—"), level)
    local lines = explanation:GetLines(level)
    for index = 1, #lines do Cortex:GetService("Logger"):User(lines[index]) end
end

local function showRecommendations()
    if not Cortex:IsModuleEnabled("Recommendations") then
        printText("MODULE_DISABLED", "Recommendations")
        return
    end
    local recommendations = Cortex:GetModule("Recommendations"):GetRecommendations()
    if #recommendations == 0 then printText("RECOMMENDATIONS_EMPTY"); return end
    printText("RECOMMENDATIONS_DEBUG_HEADER", #recommendations)
    for index = 1, #recommendations do
        local recommendation = recommendations[index]
        printText("RECOMMENDATION_DEBUG_ITEM", index, recommendation.ruleId,
            recommendation.score, Cortex:GetText(recommendation.actionable and "DEBUG_YES" or "DEBUG_NO"),
            #recommendation.blockers, recommendation.title)
        printText("RECOMMENDATION_REASON", recommendation:GetReason())
    end
end

local function showVersion()
    printText("VERSION", Cortex.version)
end

local function showStatus()
    local database = Cortex:GetService("Database")
    local logger = Cortex:GetService("Logger")
    local profiler = Cortex:GetService("Profiler")
    local modules = Cortex:GetEnabledModuleNames()
    local moduleList = #modules > 0 and table.concat(modules, ", ") or Cortex:GetText("STATUS_NONE")
    local logLevel = logger:GetLevel()
    local debugEnabled = logLevel == "DEBUG" or logLevel == "TRACE"

    printText("STATUS_HEADER")
    printText("STATUS_VERSION", Cortex.version)
    printText(
        "STATUS_DATABASE",
        database:GetSchemaVersion(),
        Cortex:GetText(database:IsReadOnly() and "DATABASE_READ_ONLY" or "DATABASE_READ_WRITE")
    )
    printText("STATUS_MODULES", moduleList)
    printText(
        "STATUS_DEBUG",
        Cortex:GetText(debugEnabled and "STATUS_ENABLED" or "STATUS_DISABLED"),
        logLevel,
        Cortex:GetText(profiler:IsEnabled() and "STATUS_ENABLED" or "STATUS_DISABLED")
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

    if action == "list" then
        local allGoals = goals:GetGoals()
        if #allGoals == 0 then printText("GOAL_LIST_EMPTY"); return end
        printText("GOAL_LIST_HEADER")
        for index = 1, #allGoals do
            local goal = allGoals[index]
            printText("GOAL_LIST_ITEM", goal.id, goal.status, goal.type, goal.title,
                goal.progress.current, goal.progress.total, goal.progress.availability)
        end
        return
    end

    if action == "debug" then
        local snapshot = goals:DebugSnapshot()
        printText("GOAL_DEBUG_SUMMARY", snapshot.total,
            #snapshot.diagnostics.cycles, #snapshot.diagnostics.missing,
            #snapshot.diagnostics.completedDependencies)
        for index = 1, #snapshot.goals do
            local goal = snapshot.goals[index]
            printText("GOAL_DEBUG_ITEM", goal.id, goal.type, goal.status,
                #goal.dependencies, #goal.blockers, goal.availableActions)
        end
        return
    end

    if action == "weekly" then
        local required = argument == "" and 1 or tonumber(argument)
        if not required or required < 1 or required ~= math.floor(required) then
            printText("GOAL_WEEKLY_COUNT_REQUIRED")
            return
        end
        local goal = goals:CreateWeeklyCompletionGoal(required)
        printText("GOAL_ADDED", goal.id, goal.title)
        return
    end

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

    local durationText = string.lower(trim(message))
    local budget = durationText == "" and 30 or durationText
    local minutes, valid = Cortex:GetModule("Planner"):NormalizeBudget(budget)
    if not valid then
        printText("INVALID_DURATION")
        return
    end
    local plan = Cortex:GetModule("Planner"):Build(minutes)
    if plan.isUnlimited then printText("PLAN_HEADER_UNLIMITED") else printText("PLAN_HEADER", minutes) end

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
    printText("PLAN_TOTAL_ESTIMATED", plan:GetTotalEstimatedMinutes())
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

local function showDatabaseDebug()
    local summary = Cortex:GetService("Database"):DebugSummary()
    printText(
        "DATABASE_DEBUG_SUMMARY",
        summary.schemaVersion,
        summary.characterCount,
        summary.sessionCount,
        summary.historyCount,
        Cortex:GetText(summary.readOnly and "DATABASE_READ_ONLY" or "DATABASE_READ_WRITE")
    )
    if summary.activeCharacterKey then
        printText("DATABASE_DEBUG_CHARACTER", summary.activeCharacterKey)
    end
end

local function showContextDebug()
    local summary = Cortex:GetService("Context"):DebugSummary()
    printText("CONTEXT_DEBUG_SUMMARY", summary.available, summary.stale, summary.unavailable)
    local _, order = Cortex:GetCollectors()
    for index = 1, #order do
        local name = order[index]
        local collector = summary.collectors[name]
        printText("CONTEXT_DEBUG_COLLECTOR", name, collector.status,
            collector.facts.available, collector.facts.stale, collector.facts.unavailable)
    end
end

local function refreshContext(message)
    local requested = trim(message)
    local context = Cortex:GetService("Context")
    local collectorName = requested ~= "" and context:ResolveCollectorName(requested) or nil
    if requested ~= "" and not collectorName then
        printText("CONTEXT_UNKNOWN_COLLECTOR", requested)
        return
    end
    local ok, state = context:RequestRefresh("debug", collectorName)
    if ok then printText("CONTEXT_REFRESH_REQUESTED", collectorName or "all", state) end
end

local function showProfiler(message)
    local action = string.lower(trim(message))
    local profiler = Cortex:GetService("Profiler")
    if action == "on" or action == "off" then
        local enabled = action == "on"
        profiler:SetEnabled(enabled)
        Cortex:GetService("Database"):SetProfilingEnabled(enabled)
    elseif action == "reset" then
        profiler:Reset()
        printText("PROFILE_RESET")
    elseif action ~= "" and action ~= "show" then
        printText("PROFILE_USAGE")
        return
    end

    local snapshot = profiler:GetSnapshot()
    printText("PROFILE_STATUS", Cortex:GetText(snapshot.enabled and "PROFILE_ON" or "PROFILE_OFF"),
        #snapshot.timings, snapshot.totalEvents)
    for index = 1, #snapshot.timings do
        local metric = snapshot.timings[index]
        printText("PROFILE_TIMING", metric.category, metric.name, metric.count,
            metric.totalMilliseconds, metric.averageMilliseconds, metric.maxMilliseconds)
    end
    for index = 1, #snapshot.events do
        local event = snapshot.events[index]
        printText("PROFILE_EVENT", event.owner, event.name, event.count)
    end
end

local function handleDebug(arguments)
    local action, rest = trim(arguments):match("^(%S*)%s*(.-)$")
    action = string.lower(action or "")
    if action == "db" then
        showDatabaseDebug()
    elseif action == "context" then
        showContextDebug()
    elseif action == "refresh" then
        refreshContext(rest)
    elseif action == "profile" then
        showProfiler(rest)
    else
        setDebug(arguments)
    end
end

function ChatCommands:Handle(message)
    local input = trim(message or "")
    if input == "" then
        Cortex:GetService("CommandPalette"):Toggle()
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
    elseif command == "recommend" then
        showRecommendations()
    elseif command == "why" then
        showExplanation(arguments)
    elseif command == "share" then
        handleShare(arguments)
    elseif command == "debrief" then
        if Cortex:IsModuleEnabled("Debrief") then
            Cortex:GetModule("Debrief"):PrintLatest()
        else
            printText("MODULE_DISABLED", "Debrief")
        end
    elseif command == "version" then
        showVersion()
    elseif command == "status" then
        showStatus()
    elseif command == "log" then
        setLogLevel(arguments)
    elseif command == "debug" then
        handleDebug(arguments)
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
    Cortex:GetService("Commands"):Register({
        id = "settings.debug",
        title = Cortex:GetText("COMMAND_TOGGLE_DEBUG"),
        subtitle = Cortex:GetText("COMMAND_TOGGLE_DEBUG_SUBTITLE"),
        keywords = { "settings", "debug", "logging", "log" },
        execute = function() setDebug("") end,
    })
    self:Register()
end

Cortex:RegisterService("ChatCommands", ChatCommands, {
    services = { "Logger", "Profiler", "Database", "Context", "MainWindow", "CommandPalette", "Commands",
        "Detective", "ShareCodes", "ShareCodeDialog" },
    modules = { "Goals", "Recommendations", "Planner", "Debrief" },
})
