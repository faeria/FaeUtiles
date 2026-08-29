local _, Cortex = ...
local Utils = Cortex.CollectorUtils

local QuestCollector = {
    events = { "QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT" },
    requiresOutOfCombat = true,
}

local QUEST_FIELDS = { "questID", "title", "level", "difficultyLevel", "frequency", "isTask", "isBounty",
    "isStory", "isScaling", "isAutoComplete", "questClassification" }
local OBJECTIVE_FIELDS = { "text", "type", "finished", "numFulfilled", "numRequired", "objectiveType" }

function QuestCollector:Collect()
    if type(C_QuestLog) ~= "table" or type(C_QuestLog.GetNumQuestLogEntries) ~= "function"
        or type(C_QuestLog.GetInfo) ~= "function" then
        return Utils.Unavailable({ "quests.current", "quests.count", "quests.readyForTurnIn" }, "api-unavailable")
    end

    local shownEntries = C_QuestLog.GetNumQuestLogEntries()
    if not Utils.IsAccessible(shownEntries) then
        return Utils.Unavailable({ "quests.current", "quests.count", "quests.readyForTurnIn" }, "restricted-or-not-ready")
    end

    local quests, readyForTurnIn = {}, {}
    local readyForTurnInAvailable = type(C_QuestLog.ReadyForTurnIn) == "function"
    for index = 1, shownEntries do
        local info = C_QuestLog.GetInfo(index)
        if Utils.IsUsableTable(info) and Utils.IsAccessible(info.isHeader) and not info.isHeader
            and Utils.IsAccessible(info.questID) then
            local quest = Utils.CopyFields(info, QUEST_FIELDS)
            local questID = info.questID
            if type(C_QuestLog.IsComplete) == "function" then
                local complete = C_QuestLog.IsComplete(questID)
                if Cortex:IsAccessibleValue(complete) then quest.isComplete = complete end
            end
            if readyForTurnInAvailable then
                local ok, ready = Utils.Call(C_QuestLog.ReadyForTurnIn, questID)
                if ok and Cortex:IsAccessibleValue(ready) and type(ready) == "boolean" then
                    quest.isReadyForTurnIn = ready
                    if ready then readyForTurnIn[#readyForTurnIn + 1] = questID end
                else
                    readyForTurnInAvailable = false
                end
            end
            quest.objectives = {}
            if type(C_QuestLog.GetQuestObjectives) == "function" then
                local objectives = C_QuestLog.GetQuestObjectives(questID)
                if Utils.IsUsableTable(objectives) then
                    for objectiveIndex = 1, #objectives do
                        local objective = Utils.CopyFields(objectives[objectiveIndex], OBJECTIVE_FIELDS)
                        if objective then quest.objectives[#quest.objectives + 1] = objective end
                    end
                end
            end
            quests[#quests + 1] = quest
        end
    end
    local facts = { ["quests.current"] = quests, ["quests.count"] = #quests }
    local unavailable = {}
    if readyForTurnInAvailable then
        facts["quests.readyForTurnIn"] = readyForTurnIn
    else
        unavailable["quests.readyForTurnIn"] = type(C_QuestLog.ReadyForTurnIn) == "function"
            and "quest-data-not-ready-or-restricted" or "api-unavailable"
    end
    return { facts = facts, unavailable = unavailable }
end

Cortex:RegisterCollector("Quest", QuestCollector)
