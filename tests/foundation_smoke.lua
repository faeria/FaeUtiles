local frames = {}
local combat = false
local playerLevel = 80
local clock = 1000
local preciseClock = 10
unpack = unpack or table.unpack

local function newWidget()
    local widget = {
        scripts = {},
        events = {},
        visible = true,
    }

    function widget:RegisterEvent(event)
        self.events[event] = true
    end

    function widget:UnregisterEvent(event)
        self.events[event] = nil
    end

    function widget:SetScript(script, callback)
        self.scripts[script] = callback
    end

    function widget:CreateTexture()
        local texture = newWidget()
        return texture
    end

    function widget:CreateFontString()
        local fontString = newWidget()
        return fontString
    end

    function widget:SetText(text)
        self.text = text
        if self.scripts.OnTextChanged then
            self.scripts.OnTextChanged(self, false)
        end
    end

    function widget:GetText() return self.text or "" end

    function widget:SetShown(shown)
        if shown then self:Show() else self:Hide() end
    end

    function widget:Show()
        self.visible = true
        if self.scripts.OnShow then
            self.scripts.OnShow(self)
        end
    end

    function widget:Hide()
        self.visible = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end

    function widget:IsShown()
        return self.visible
    end

    function widget:SetSize(width, height) self.width, self.height = width, height end
    function widget:SetWidth(width) self.width = width end
    function widget:SetHeight(height) self.height = height end
    function widget:SetPoint(point, relativeTo, relativePoint, x, y)
        if type(relativeTo) == "number" then
            x, y, relativeTo, relativePoint = relativeTo, relativePoint, nil, point
        end
        self.point = { point, relativeTo, relativePoint or point, x or 0, y or 0 }
    end
    function widget:GetPoint() return unpack(self.point or { "CENTER", UIParent, "CENTER", 0, 0 }) end
    function widget:ClearAllPoints() self.point = nil end
    function widget:SetFrameStrata() end
    function widget:EnableMouse() end
    function widget:EnableKeyboard(enabled) self.keyboardEnabled = enabled end
    function widget:SetPropagateKeyboardInput(value) self.propagateKeyboard = value end
    function widget:SetClampedToScreen() end
    function widget:SetMovable() end
    function widget:RegisterForDrag() end
    function widget:StartMoving() end
    function widget:StopMovingOrSizing() end
    function widget:SetScale(scale) self.scale = scale end
    function widget:GetScale() return self.scale or 1 end
    function widget:SetAllPoints() end
    function widget:SetColorTexture() end
    function widget:SetTexture(texture) self.texture = texture end
    function widget:SetJustifyH() end
    function widget:SetTextColor() end
    function widget:SetWordWrap() end
    function widget:SetStatusBarTexture() end
    function widget:SetStatusBarColor() end
    function widget:SetMinMaxValues() end
    function widget:SetValue(value) self.value = value end
    function widget:SetAutoFocus() end
    function widget:SetFontObject() end
    function widget:SetTextInsets() end
    function widget:SetMaxLetters() end
    function widget:SetFocus() self.hasFocus = true end
    function widget:ClearFocus() self.hasFocus = false end

    return widget
end

function CreateFrame()
    local frame = newWidget()
    frames[#frames + 1] = frame
    return frame
end

UIParent = newWidget()
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {
    messages = {},
    AddMessage = function(self, message)
        self.messages[#self.messages + 1] = message
    end,
}

function GetLocale()
    return "enUS"
end

function InCombatLockdown()
    return combat
end

function UnitFullName()
    return "Tester", "TestRealm"
end

function UnitGUID()
    return "Player-1-00000001"
end

function UnitClass()
    return "Mage", "MAGE", 8
end

function UnitLevel()
    return playerLevel
end

function issecretvalue()
    return false
end

function issecrettable(value)
    return type(value) == "table" and value.__secret == true
end

function canaccessvalue()
    return true
end

function time()
    clock = clock + 1
    return clock
end

function GetTimePreciseSec()
    preciseClock = preciseClock + 0.0001
    return preciseClock
end

local damageMeterDetailReads = 0
local damageMeterSessions = {
    { sessionID = 77, name = "Test Encounter", durationSeconds = 95.5 },
}

Enum = {
    DamageMeterType = {
        Absorbs = 4,
        Interrupts = 5,
        AvoidableDamageTaken = 8,
        Deaths = 9,
    },
}

C_DamageMeter = {
    IsDamageMeterAvailable = function()
        return true, ""
    end,
    GetAvailableCombatSessions = function()
        return damageMeterSessions
    end,
    GetCombatSessionFromID = function(sessionID, damageMeterType)
        assert(sessionID == 77)
        damageMeterDetailReads = damageMeterDetailReads + 1
        if damageMeterType == Enum.DamageMeterType.Deaths then
            return {
                totalAmount = 2,
                durationSeconds = 95.5,
                combatSources = {
                    {
                        isLocalPlayer = true,
                        classFilename = "MAGE",
                        totalAmount = 1,
                        deathTimeSeconds = 45.25,
                    },
                },
            }
        elseif damageMeterType == Enum.DamageMeterType.Interrupts then
            return { totalAmount = 6, durationSeconds = 95.5, combatSources = {} }
        elseif damageMeterType == Enum.DamageMeterType.Absorbs then
            return { totalAmount = 12000, durationSeconds = 95.5, combatSources = {} }
        elseif damageMeterType == Enum.DamageMeterType.AvoidableDamageTaken then
            return { totalAmount = 8000, durationSeconds = 95.5, combatSources = {} }
        end
        error("unexpected damage meter type")
    end,
}

local originalCortexDB = {
    schemaVersion = 1,
    settings = { logLevel = "INFO" },
    goals = {
        schemaVersion = 1,
        nextId = 2,
        items = {
            [1] = {
                schemaVersion = 1,
                id = 1,
                title = "Existing goal",
                status = "active",
                priority = 50,
                estimatedMinutes = 30,
            },
        },
    },
    warband = { schemaVersion = 1, characters = {} },
}
CortexDB = originalCortexDB
CortexCharacterDB = {
    schemaVersion = 1,
    session = { schemaVersion = 1, lastLoginAt = 10, lastLogoutAt = 20 },
}

local Cortex = {}
local addonFiles = {
    "Core/Namespace.lua",
    "Core/Constants.lua",
    "Locales/enUS.lua",
    "Locales/frFR.lua",
    "Core/ModuleRegistry.lua",
    "Core/Logger.lua",
    "Core/Profiler.lua",
    "Core/EventBus.lua",
    "Core/CommandRegistry.lua",
    "Data/Schema.lua",
    "Data/Migrations.lua",
    "Data/Repositories.lua",
    "Data/Database.lua",
    "Data/WarbandRepository.lua",
    "Data/TemplateRepository.lua",
    "Context/FactStore.lua",
    "Context/CollectorRegistry.lua",
    "Context/CollectorUtils.lua",
    "Context/Collectors/CharacterCollector.lua",
    "Context/Collectors/GearCollector.lua",
    "Context/Collectors/CurrencyCollector.lua",
    "Context/Collectors/QuestCollector.lua",
    "Context/Collectors/WeeklyCollector.lua",
    "Context/Collectors/InstanceCollector.lua",
    "Context/Collectors/ProfessionCollector.lua",
    "Context/Collectors/ReputationCollector.lua",
    "Context/Collectors/LocationCollector.lua",
    "Context/Collectors/WarbandCollector.lua",
    "Context/ContextService.lua",
    "Goals/Goal.lua",
    "Goals/DependencyGraph.lua",
    "Goals/GoalEngine.lua",
    "Sharing/Serializer.lua",
    "Sharing/Deserializer.lua",
    "Sharing/Versioning.lua",
    "Sharing/Validation.lua",
    "Sharing/ShareCode.lua",
    "Warband/WarbandIntelligence.lua",
    "Debrief/DebriefService.lua",
    "Recommendations/Recommendation.lua",
    "Recommendations/RuleEngine.lua",
    "Recommendations/Rules.lua",
    "Recommendations/Prioritizer.lua",
    "Recommendations/RecommendationEngine.lua",
    "Detective/Evidence.lua",
    "Detective/Condition.lua",
    "Detective/Blocker.lua",
    "Detective/Explanation.lua",
    "Detective/DetectiveService.lua",
    "Planner/DurationEstimator.lua",
    "Planner/PlanEntry.lua",
    "Planner/Plan.lua",
    "Planner/SessionPlanner.lua",
    "CommandPalette/SearchProvider.lua",
    "UI/Theme.lua",
    "UI/Components/Button.lua",
    "UI/Components/Card.lua",
    "UI/Components/Badge.lua",
    "UI/Components/ProgressBar.lua",
    "UI/Components/Section.lua",
    "UI/Components/ScrollList.lua",
    "UI/OverviewPage.lua",
    "UI/PlaceholderPage.lua",
    "UI/SessionPlannerPage.lua",
    "UI/WarbandPage.lua",
    "UI/ShareCodeDialog.lua",
    "UI/Navigation.lua",
    "UI/MainWindow.lua",
    "UI/CommandPalette.lua",
    "UI/ChatCommands.lua",
    "Core/Bootstrap.lua",
}

for index = 1, #addonFiles do
    local chunk = assert(loadfile(addonFiles[index]))
    chunk("FaeUtiles", Cortex)
end

local eventFrame = assert(frames[1])
local dispatch = assert(eventFrame.scripts.OnEvent)
dispatch(eventFrame, "ADDON_LOADED", "FaeUtiles", false)
dispatch(eventFrame, "PLAYER_LOGIN")

assert(CortexDB.schemaVersion == 7)
assert(CortexDB ~= originalCortexDB)
assert(originalCortexDB.schemaVersion == 1)
assert(CortexDB.goals.items[1].title == "Existing goal")
assert(CortexDB.settings.modules == nil)
assert(CortexDB.settings.profiling == false)
assert(type(CortexDB.characters) == "table")
assert(type(CortexDB.history) == "table")
assert(type(CortexDB.sessions) == "table")
assert(type(CortexDB.modules.states) == "table")
assert(Cortex:GetService("Context") ~= nil)
assert(Cortex:GetModule("Goals") ~= nil)
assert(Cortex:IsModuleEnabled("Goals"))
assert(Cortex:IsModuleEnabled("Recommendations"))
assert(Cortex:IsModuleEnabled("Planner"))
local initialRecommendations = Cortex:GetModule("Recommendations"):GetRecommendations()
assert(#initialRecommendations > 0)
assert(initialRecommendations[1].ruleId ~= nil)
assert(initialRecommendations[1]:GetReason() ~= "")
assert(type(initialRecommendations[1]:GetScoreBreakdown()) == "table")
local detective = Cortex:GetService("Detective")
assert(detective ~= nil)
local initialExplanation = detective:ExplainRecommendation(initialRecommendations[1])
assert(initialExplanation.result == "AVAILABLE")
assert(initialExplanation:GetText("SUMMARY"):find(initialRecommendations[1]:GetReason(), 1, true))
assert(initialExplanation:GetText("DETAIL") ~= "")
assert(initialExplanation:GetText("DEBUG"):find("RULE", 1, true))
assert(initialExplanation:GetText("DEBUG") == initialExplanation:GetText("DEBUG"))
local unknownFactExplanation = detective:ExplainFact("test.never-recorded")
assert(unknownFactExplanation.result == "UNKNOWN")
assert(unknownFactExplanation.evidence[1].status == "unknown")
local resourceExplanation = detective:ExplainBlocker({
    id = "currency:test", label = "Upgrade currency", required = 30, available = 12,
})
assert(resourceExplanation.result == "BLOCKED")
assert(resourceExplanation.reason:find("18", 1, true))
assert(Cortex:GetService("Context"):GetCurrentCharacter().level == 80)
assert(Cortex:GetService("Facts"):Get("character.current").guid == "Player-1-00000001")
assert(CortexDB.characters["Player-1-00000001"].level == 80)
assert(CortexDB.sessions.byCharacter["Player-1-00000001"].lastLogin > 10)
assert(CortexDB.sessions.byCharacter["Player-1-00000001"].lastLogout == 20)
assert(CortexDB.sessions.byCharacter["Player-1-00000001"].unfinishedGoals[1] == 1)
assert(CortexCharacterDB.migration.characterKey == "Player-1-00000001")
assert(CortexDB.characters["Player-1-00000001"].snapshot.schemaVersion == 1)
local warband = Cortex:GetModule("Warband")
assert(Cortex:IsModuleEnabled("Warband"))
local initialWarband = warband:GetOverview()
assert(#initialWarband.characters == 1)
assert(initialWarband.characters[1].state == "LIVE")
assert(initialWarband.characters[1].fields.itemLevel.state == "UNKNOWN")
local facts = Cortex:GetService("Facts")
facts:Set("character.itemLevel", 700, "Gear")
assert(warband:CaptureCurrent("Gear"))
assert(not warband:CaptureCurrent("Gear"))
assert(_G.Cortex == nil)

local eventDelivered = false
Cortex.Events:Subscribe("TEST_EVENT", Cortex, function(_, value)
    eventDelivered = value
end)
Cortex.Events:Publish("TEST_EVENT", true)
assert(eventDelivered)

assert(type(SlashCmdList.CORTEX) == "function")
assert(Cortex.version == "0.1.0-alpha")
assert(Cortex:GetService("Database"):GetSchemaVersion() == 7)
local enabledModules = Cortex:GetEnabledModuleNames()
assert(#enabledModules == 5)
SlashCmdList.CORTEX("version")
assert(DEFAULT_CHAT_FRAME.messages[#DEFAULT_CHAT_FRAME.messages]:find("0.1.0-alpha", 1, true))
SlashCmdList.CORTEX("status")
assert(DEFAULT_CHAT_FRAME.messages[#DEFAULT_CHAT_FRAME.messages]:find("profiling: disabled", 1, true))
local commands = Cortex:GetService("Commands")
assert(commands ~= nil)
assert(not commands:Register({ id = "invalid" }))
assert(not commands:Register({ id = "navigation.overview", title = "Duplicate", execute = function() end }))
local executed = false
assert(commands:Register({
    id = "test.execute", title = "Execute test", keywords = { "runner" },
    execute = function() executed = true end,
}))
assert(commands:Execute("test.execute"))
assert(executed)

local search = Cortex:GetService("Search")
local allResults = search:Search("", 100)
local resultTypes = {}
for index = 1, #allResults do resultTypes[allResults[index].type] = true end
assert(resultTypes.COMMAND and resultTypes.GOAL and resultTypes.RECOMMENDATION)
assert(resultTypes.CHARACTER and resultTypes.MODULE)
assert(search:Search("weekly", 20)[1] ~= nil)
assert(search:Search("open weekly", 20)[1] ~= nil)
assert(search:Search("ovrvw", 20)[1] ~= nil)
assert(#search:Search("definitely-no-cortex-result", 20) == 0)

SlashCmdList.CORTEX("")
local palette = Cortex:GetService("CommandPalette")
assert(palette.frame:IsShown())
assert(palette.searchBox.hasFocus)
local paletteFrameCount = #frames
palette.searchBox:SetText("dashboard")
assert(#palette.results > 0)
assert(#frames == paletteFrameCount)
palette.selectedIndex = #palette.results
assert(palette:MoveSelection(1) and palette.selectedIndex == 1)
assert(palette:MoveSelection(-1) and palette.selectedIndex == #palette.results)
palette.searchBox.scripts.OnArrowPressed(palette.searchBox, "UP")
for index = 1, #palette.results do
    if palette.results[index].id == "navigation.overview" then palette.selectedIndex = index; break end
end
palette.searchBox.scripts.OnEnterPressed(palette.searchBox)
assert(not palette.frame:IsShown())
assert(Cortex:GetService("MainWindow").frame:IsShown())
local mainWindow = Cortex:GetService("MainWindow")
assert(mainWindow.pages.overview:IsShown())
assert(mainWindow.pages.overview.nextAction.title.text ~= nil)
assert(mainWindow.sidebarButtons.overview.isActive)
local frameCountAfterCreate = #frames
mainWindow:Refresh()
assert(#frames == frameCountAfterCreate)
mainWindow.pages.overview.nextAction.why.scripts.OnClick()
assert(mainWindow.pages.overview.nextAction.explanation:IsShown())
assert(mainWindow.pages.overview.nextAction.explanation.text ~= "")
assert(Cortex:GetService("Navigation"):GoTo("goals"))
assert(mainWindow.pages.goals:IsShown())
assert(not mainWindow.pages.overview:IsShown())
assert(not Cortex:GetService("Navigation"):GoTo("invalid"))
assert(Cortex:GetService("Navigation"):GoTo("session"))
assert(mainWindow.pages.session:IsShown())
assert(mainWindow.pages.session.summary.primary.text ~= "")
local sessionFrameCount = #frames
mainWindow.pages.session.budgetButtons[1].scripts.OnClick()
assert(mainWindow.pages.session:GetBudget() == 30)
assert(#frames == sessionFrameCount)
mainWindow.frame.scripts.OnKeyDown(mainWindow.frame, "ESCAPE")
assert(not mainWindow.frame:IsShown())
SlashCmdList.CORTEX("")
assert(palette.frame:IsShown())
palette.searchBox.scripts.OnEscapePressed(palette.searchBox)
assert(not palette.frame:IsShown())
mainWindow:Show()
mainWindow.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 123, -87)
assert(mainWindow:SavePlacement())
assert(CortexDB.settings.window.point == "TOPLEFT")
assert(CortexDB.settings.window.x == 123)
SlashCmdList.CORTEX("debug")
assert(Cortex:GetService("Logger"):GetLevel() == "DEBUG")
assert(CortexDB.settings.logLevel == "DEBUG")
SlashCmdList.CORTEX("debug")
assert(Cortex:GetService("Logger"):GetLevel() == "INFO")
SlashCmdList.CORTEX("debug profile on")
assert(Cortex:GetService("Profiler"):IsEnabled())
assert(CortexDB.settings.profiling == true)
SlashCmdList.CORTEX("debug profile reset")
SlashCmdList.CORTEX("debug profile off")
assert(not Cortex:GetService("Profiler"):IsEnabled())
assert(CortexDB.settings.profiling == false)
SlashCmdList.CORTEX("debug db")
SlashCmdList.CORTEX("debug context")
SlashCmdList.CORTEX("debug refresh character")
assert(Cortex:GetService("Context"):Get("character.level") == 80)

facts = Cortex:GetService("Facts")
facts:Set("test.temporary", 42, "Test")
local lastUpdated = facts:GetUpdatedAt("test.temporary")
facts:SetUnavailable("test.temporary", "Test", "cache-pending")
assert(facts:Get("test.temporary") == nil)
assert(facts:GetLastKnown("test.temporary") == 42)
assert(facts:GetStatus("test.temporary") == "unavailable")
assert(facts:GetUpdatedAt("test.temporary") == lastUpdated)
local _, changed = facts:Set("test.dedup", { value = 1 }, "Test")
assert(changed)
facts:MarkStale("test.dedup", "test-refresh")
_, changed = facts:Set("test.dedup", { value = 1 }, "Test")
assert(not changed)

clock = 1000000
facts:Set("character.itemLevel", 728, "Gear")
facts:Set("professions.learned", {
    primary1 = { name = "Blacksmithing", skillLine = 164, skillLevel = 80, maxSkillLevel = 100 },
}, "Profession")
facts:Set("currency.byID", {
    [1] = { currencyID = 1, name = "Transferable", quantity = 12,
        isAccountTransferable = true, isAccountWide = false },
    [2] = { currencyID = 2, name = "Account wide", quantity = 99,
        isAccountTransferable = true, isAccountWide = true },
    [3] = { currencyID = 3, name = "Character only", quantity = 7,
        isAccountTransferable = false, isAccountWide = false },
}, "Currency")
facts:Set("weekly", {
    activities = { { progress = 1, threshold = 1 }, { progress = 0, threshold = 1 } },
    canClaimRewards = false, hasAvailableRewards = false,
}, "Weekly")
assert(warband:CaptureCurrent("test"))
assert(not warband:CaptureCurrent("Currency"))
local currentWarbandRecord = Cortex:GetService("WarbandRepository"):Get("Player-1-00000001")
assert(currentWarbandRecord.snapshot.fields.itemLevel.value == 728)
assert(currentWarbandRecord.snapshot.fields.professions.value[1].name == "Blacksmithing")
assert(#currentWarbandRecord.snapshot.fields.transferableCurrencies.value == 1)
assert(currentWarbandRecord.snapshot.fields.transferableCurrencies.value[1].currencyID == 1)
assert(currentWarbandRecord.snapshot.fields.weekly.value.completedActivities == 1)

local offlineKey = "Player-1-00000002"
assert(Cortex:GetService("WarbandRepository"):Capture(offlineKey, {
    guid = offlineKey, name = "Altmage", realm = "TestRealm", classFile = "MAGE", classId = 8,
    level = 80,
}, {
    itemLevel = 704,
    professions = { { name = "Enchanting", skillLine = 333, skillLevel = 75, maxSkillLevel = 100 } },
}, time() - (3 * 86400)))
local warbandOverview = warband:GetOverview()
local offlineCharacter
for index = 1, #warbandOverview.characters do
    if warbandOverview.characters[index].key == offlineKey then offlineCharacter = warbandOverview.characters[index] end
end
assert(offlineCharacter and offlineCharacter.state == "CACHED")
assert(offlineCharacter.fields.itemLevel.state == "CACHED")
assert(offlineCharacter.fields.weekly.state == "UNKNOWN")
assert(offlineCharacter.ageSeconds >= 3 * 86400)
assert(offlineCharacter.fields.professions.value[1].recipes == nil)

local contributionGoal = Cortex:GetModule("Goals"):AddGoal({
    title = "Prepare an enchant", type = "GENERIC",
    metadata = { requiredProfessionSkillLine = 333, estimatedMinutes = 10 },
})
local contributions = warband:GetProfessionContributions()
local sawOfflineContribution = false
for index = 1, #contributions do
    if contributions[index].goalId == contributionGoal.id and contributions[index].characterKey == offlineKey then
        sawOfflineContribution = true
        assert(contributions[index].certainty == "POTENTIAL")
        assert(contributions[index].reason:find("unknown", 1, true))
    end
end
assert(sawOfflineContribution)
assert(Cortex:GetService("Navigation"):GoTo("warband"))
assert(mainWindow.pages.warband:IsShown())
assert(mainWindow.pages.warband.summary.text ~= "")
local warbandFrameCount = #frames
mainWindow:Refresh()
assert(#frames == warbandFrameCount)

local contextEventFrame
for index = 1, #frames do
    if frames[index].events.PLAYER_LEVEL_UP then
        contextEventFrame = frames[index]
        break
    end
end
assert(contextEventFrame and contextEventFrame.scripts.OnEvent)
local gearCheckedAt = Cortex:GetService("Context"):DebugSummary().collectors.Gear.lastCheckedAt
playerLevel = 82
contextEventFrame.scripts.OnEvent(contextEventFrame, "PLAYER_LEVEL_UP", 82)
assert(Cortex:GetService("Context"):Get("character.level") == 82)
assert(Cortex:GetService("Context"):DebugSummary().collectors.Gear.lastCheckedAt == gearCheckedAt)

local database = Cortex:GetService("Database")
local inspected = database:DebugInspect("sessions")
inspected.byCharacter["Player-1-00000001"].lastLogin = -1
assert(CortexDB.sessions.byCharacter["Player-1-00000001"].lastLogin > 10)
local summary = database:DebugSummary()
assert(summary.schemaVersion == 7)
assert(summary.characterCount == 2)
assert(summary.sessionCount == 1)

combat = true
dispatch(eventFrame, "PLAYER_REGEN_DISABLED")
playerLevel = 81
local queued, state = Cortex:GetService("Context"):RequestRefresh("test")
assert(queued and state == "deferred")
assert(Cortex:GetService("Context"):GetCurrentCharacter().level == 82)
combat = false
dispatch(eventFrame, "PLAYER_REGEN_ENABLED")
assert(Cortex:GetService("Context"):GetCurrentCharacter().level == 81)

assert(not Cortex:DisableModule("Goals"))
assert(Cortex:DisableModule("Planner"))
assert(Cortex:DisableModule("Recommendations"))
assert(Cortex:DisableModule("Warband"))
assert(Cortex:DisableModule("Goals"))
assert(not Cortex:IsModuleEnabled("Goals"))
assert(Cortex.Registry:ApplyModuleStates())
assert(not Cortex:IsModuleEnabled("Goals"))
assert(not Cortex:IsModuleEnabled("Recommendations"))
assert(not Cortex:IsModuleEnabled("Planner"))
assert(not Cortex:IsModuleEnabled("Warband"))
assert(Cortex:EnableModule("Planner"))
assert(Cortex:EnableModule("Warband"))
assert(Cortex:IsModuleEnabled("Goals"))
assert(Cortex:IsModuleEnabled("Recommendations"))
assert(Cortex:IsModuleEnabled("Planner"))
assert(Cortex:IsModuleEnabled("Warband"))
assert(CortexDB.modules.states.Goals == true)
assert(CortexDB.modules.states.Recommendations == true)
assert(CortexDB.modules.states.Planner == true)
assert(CortexDB.modules.states.Warband == true)
assert(Cortex:IsModuleEnabled("Debrief"))

local debrief = Cortex:GetModule("Debrief")
local debriefDispatch = assert(debrief.eventFrame.scripts.OnEvent)
combat = true
dispatch(eventFrame, "PLAYER_REGEN_DISABLED")
debriefDispatch(debrief.eventFrame, "ENCOUNTER_START", 123, "Test Encounter", 16, 20)
debriefDispatch(debrief.eventFrame, "ENCOUNTER_END", 123, "Test Encounter", 16, 20, 1, {})
assert(damageMeterDetailReads == 0)
local combatDebrief = assert(debrief:GetLatest())
assert(combatDebrief.result == "SUCCESS")
assert(combatDebrief.nativeSession.status == "UNAVAILABLE")

combat = false
dispatch(eventFrame, "PLAYER_REGEN_ENABLED")
debriefDispatch(debrief.eventFrame, "PLAYER_REGEN_ENABLED")
local latestDebrief = assert(debrief:GetLatest())
assert(damageMeterDetailReads == 4)
assert(latestDebrief.nativeSession.status == "AVAILABLE")
assert(latestDebrief.nativeSession.durationSeconds == 95.5)
assert(latestDebrief.statistics.deaths.total == 2)
assert(latestDebrief.statistics.deaths.sources[1].isLocalPlayer)
assert(latestDebrief.statistics.interrupts.total == 6)
assert(latestDebrief.statistics.absorbs.total == 12000)
assert(latestDebrief.statistics.avoidableDamageTaken.total == 8000)

local readsBeforeAmbiguous = damageMeterDetailReads
damageMeterSessions = {
    { sessionID = 77, name = "Ambiguous Encounter", durationSeconds = 10 },
    { sessionID = 78, name = "Ambiguous Encounter", durationSeconds = 11 },
}
debriefDispatch(debrief.eventFrame, "ENCOUNTER_END", 124, "Ambiguous Encounter", 16, 20, 0, {})
local ambiguousDebrief = assert(debrief:GetLatest())
assert(ambiguousDebrief.result == "FAILURE")
assert(ambiguousDebrief.nativeSession.status == "AMBIGUOUS")
assert(damageMeterDetailReads == readsBeforeAmbiguous)

damageMeterSessions = { __secret = true }
debriefDispatch(debrief.eventFrame, "ENCOUNTER_END", 125, "Secret Encounter", 16, 20, 0, {})
local secretDebrief = assert(debrief:GetLatest())
assert(secretDebrief.nativeSession.status == "UNAVAILABLE")
assert(secretDebrief.nativeSession.reason == "sessions-unavailable")
assert(damageMeterDetailReads == readsBeforeAmbiguous)

damageMeterSessions = {
    { sessionID = 77, name = "Test Encounter", durationSeconds = 95.5 },
}
SlashCmdList.CORTEX("debrief")

SlashCmdList.CORTEX("now 30")
local snapshot = database:GetSnapshot("Player-1-00000001")
assert(#snapshot.unfinishedTasks > 0)

local planner = Cortex:GetModule("Planner")
assert(planner:NormalizeBudget(30) == 30)
assert(planner:NormalizeBudget("60") == 60)
assert(planner:NormalizeBudget(120) == 120)
local unlimitedBudget, unlimitedValid = planner:NormalizeBudget("unlimited")
assert(unlimitedBudget == nil and unlimitedValid)
local invalidBudget, invalidValid = planner:NormalizeBudget("forever")
assert(invalidBudget == nil and not invalidValid)
local thirtyMinutePlan = assert(planner:Build(30))
assert(thirtyMinutePlan:GetTotalEstimatedMinutes() <= 30)
for index = 1, #thirtyMinutePlan do
    assert(thirtyMinutePlan[index].durationIsEstimate)
    assert(thirtyMinutePlan[index]:GetReason() ~= "")
end
local unlimitedPlan = assert(planner:Build("unlimited"))
assert(unlimitedPlan.isUnlimited and unlimitedPlan:GetRemainingMinutes() == nil)
local repeatedPlan = assert(planner:Build("unlimited"))
assert(#repeatedPlan == #unlimitedPlan)
for index = 1, #unlimitedPlan do assert(repeatedPlan[index].id == unlimitedPlan[index].id) end
local fallbackDuration = Cortex:GetService("DurationEstimator"):Estimate({})
assert(fallbackDuration.minutes == 30 and fallbackDuration.isEstimate and fallbackDuration.source == "fallback")

local blockedStandalone = assert(Cortex.Recommendation.Normalize({
    id = "test:blocked", ruleId = "test", title = "Blocked standalone",
    description = "Blocked", reason = "External blocker", priority = 100,
    actionable = false, blockers = { { reason = "EXTERNAL" } }, metadata = { estimatedMinutes = 5 },
}))
local blockedPlan = assert(planner:Build("unlimited", { recommendations = { blockedStandalone } }))
for index = 1, #blockedPlan do assert(blockedPlan[index].id ~= blockedStandalone.id) end
local externallyBlockedGoal = assert(Cortex.Recommendation.Normalize({
    id = "goal:1:external-block", ruleId = "test", title = "Externally blocked goal",
    description = "Blocked", reason = "External blocker", priority = 100, goalId = 1,
    actionable = false, blockers = { { reason = "EXTERNAL" } }, metadata = { estimatedMinutes = 5 },
}))
local externalBlockPlan = assert(planner:Build("unlimited", { recommendations = { externallyBlockedGoal } }))
for index = 1, #externalBlockPlan do assert(externalBlockPlan[index].goalId ~= 1) end

local remoteRecommendation = assert(Cortex.Recommendation.Normalize({
    id = "a:remote", ruleId = "test", title = "Remote action", description = "Remote",
    reason = "Test", priority = 50, actionable = true, blockers = {},
    metadata = { estimatedMinutes = 5, mapID = 7 },
}))
local localRecommendation = assert(Cortex.Recommendation.Normalize({
    id = "z:local", ruleId = "test", title = "Local action", description = "Local",
    reason = "Test", priority = 50, actionable = true, blockers = {},
    metadata = { estimatedMinutes = 5, mapID = 42 },
}))
local locationContext = { Get = function(_, key)
    return key == "location.current" and { mapID = 42, name = "Test Zone" } or nil
end }
local locationPlan = assert(planner:Build("unlimited", {
    recommendations = { remoteRecommendation, localRecommendation }, context = locationContext,
}))
local localIndex, remoteIndex
for index = 1, #locationPlan do
    if locationPlan[index].id == localRecommendation.id then localIndex = index end
    if locationPlan[index].id == remoteRecommendation.id then remoteIndex = index end
end
assert(localIndex and remoteIndex and localIndex < remoteIndex)
assert(locationPlan[localIndex]:GetReason():find("Test Zone", 1, true))

local added = Cortex:GetModule("Goals"):Add("Persist this goal")
assert(added.id == contributionGoal.id + 1)
snapshot = database:GetSnapshot("Player-1-00000001")
assert(#snapshot.unfinishedGoals >= 3)
assert(CortexDB.history.items[#CortexDB.history.items].type == "goal-added")

local goals = Cortex:GetModule("Goals")
local dependency = goals:Add("Acquire reagents")
local parent = goals:Add("Craft boots")
dependency.priority = 10
parent.priority = 90
assert(goals:SetDependencies(parent.id, { dependency.id }))
assert(parent.status == Cortex.Constants.GOAL_STATUSES.BLOCKED)
assert(#goals:GetBlockers(parent.id) == 1)
local blockedGoalExplanation = detective:ExplainGoal(parent.id)
assert(blockedGoalExplanation.result == "BLOCKED")
assert(#blockedGoalExplanation.blockers == 1)
assert(blockedGoalExplanation.blockers[1].goalId == dependency.id)
assert(goals:GetAvailableActions(parent.id)[1].goalId == dependency.id)
local blockedRecommendations = Cortex:GetModule("Recommendations"):GetRecommendations()
local sawBlockedGoal = false
for index = 1, #blockedRecommendations do
    if blockedRecommendations[index].ruleId == "goal-blocked" then
        sawBlockedGoal = true
        assert(not blockedRecommendations[index].actionable)
        assert(#blockedRecommendations[index].blockers > 0)
    end
end
assert(sawBlockedGoal)
local dependencyPlan = assert(planner:Build("unlimited"))
local dependencyIndex, parentIndex
for index = 1, #dependencyPlan do
    if dependencyPlan[index].goalId == dependency.id then dependencyIndex = index end
    if dependencyPlan[index].goalId == parent.id then parentIndex = index end
end
assert(dependencyIndex and parentIndex and dependencyIndex < parentIndex)
assert(dependencyPlan[dependencyIndex]:GetReason():find("dependency", 1, true))

local cycleA, cycleB = goals:Add("Cycle A"), goals:Add("Cycle B")
cycleA.dependencies, cycleB.dependencies = { cycleB.id }, { cycleA.id }
local cyclePlan = assert(planner:Build("unlimited", { recommendations = {} }))
for index = 1, #cyclePlan do
    assert(cyclePlan[index].goalId ~= cycleA.id and cyclePlan[index].goalId ~= cycleB.id)
end
local sawCycleSkip = false
for index = 1, #cyclePlan.skipped do
    if cyclePlan.skipped[index].reason == "cycle" then sawCycleSkip = true end
end
assert(sawCycleSkip)
cycleA.dependencies, cycleB.dependencies = {}, {}

local missingDependencyGoal = goals:Add("Missing dependency")
missingDependencyGoal.dependencies = { 99999 }
local missingDependencyPlan = assert(planner:Build("unlimited", { recommendations = {} }))
for index = 1, #missingDependencyPlan do
    assert(missingDependencyPlan[index].goalId ~= missingDependencyGoal.id)
end
missingDependencyGoal.dependencies = {}
assert(not goals:SetDependencies(parent.id, { 9999 }))
assert(not goals:SetDependencies(dependency.id, { parent.id }))
assert(goals:Complete(dependency.id))
assert(parent.status == Cortex.Constants.GOAL_STATUSES.ACTIVE)
assert(#goals:GetBlockers(parent.id) == 0)

local weekly = goals:CreateWeeklyCompletionGoal(1)
assert(weekly.type == "WEEKLY_COMPLETION")
assert(weekly.progress.availability == "UNAVAILABLE")
facts:Set("weekly.activities", { { progress = 1, threshold = 1 } }, "Weekly")
goals:EvaluateAll("test")
assert(weekly.status == Cortex.Constants.GOAL_STATUSES.COMPLETED)
local incompleteWeekly = goals:CreateWeeklyCompletionGoal(2)
goals:EvaluateAll("test-incomplete")
assert(incompleteWeekly.status == Cortex.Constants.GOAL_STATUSES.ACTIVE)
local weeklyRecommendations = Cortex:GetModule("Recommendations"):GetRecommendations()
local sawWeekly = false
for index = 1, #weeklyRecommendations do
    if weeklyRecommendations[index].ruleId == "weekly-incomplete" then sawWeekly = true end
end
assert(sawWeekly)
local weeklyRecommendation
for index = 1, #weeklyRecommendations do
    if weeklyRecommendations[index].ruleId == "weekly-incomplete" then
        weeklyRecommendation = weeklyRecommendations[index]
        break
    end
end
local weeklyExplanation = detective:ExplainRecommendation(weeklyRecommendation)
local weeklyTrace = weeklyExplanation:GetTrace()
assert(weeklyTrace[1].type == "FACT" and weeklyTrace[1].id == "weekly.activities")
assert(weeklyTrace[2].type == "RULE" and weeklyTrace[2].id == "weekly-incomplete")
assert(weeklyTrace[3].type == "RECOMMENDATION")
assert(weeklyTrace[4].type == "GOAL" and weeklyTrace[4].id == incompleteWeekly.id)
SlashCmdList.CORTEX("why recommendation " .. weeklyRecommendation.id .. " debug")
SlashCmdList.CORTEX("why goal " .. parent.id .. " detail")
SlashCmdList.CORTEX("why fact weekly.activities debug")

facts:Set("gear.missingGems", { [1] = { slotId = 1, emptySockets = 1 } }, "Gear")
facts:Set("gear.upgrades", {
    [1] = { slotId = 1, itemId = 1001, currentLevel = 2, maxLevel = 6, maxItemLevel = 710 },
}, "Gear")
Cortex:GetModule("Recommendations"):Invalidate("test-gear")
local gearRecommendations = Cortex:GetModule("Recommendations"):GetRecommendations()
local sawGems, sawUpgrade = false, false
for index = 1, #gearRecommendations do
    sawGems = sawGems or gearRecommendations[index].ruleId == "missing-gems"
    sawUpgrade = sawUpgrade or gearRecommendations[index].ruleId == "available-upgrade"
end
assert(sawGems and sawUpgrade)

local gearCollector = Cortex:GetCollector("Gear")
local contextService = Cortex:GetService("Context")
facts:Set("gear.cachePending", true, "Gear")
facts:Set("gear.slots", { [1] = { itemId = 1001 } }, "Gear")
assert(gearCollector:ShouldCollect(contextService, "GET_ITEM_INFO_RECEIVED", 1001, true))
assert(not gearCollector:ShouldCollect(contextService, "GET_ITEM_INFO_RECEIVED", 2002, true))
assert(not gearCollector:ShouldCollect(contextService, "GET_ITEM_INFO_RECEIVED", 1001, false))

local profiler = Cortex:GetService("Profiler")
profiler:Reset()
profiler:SetEnabled(true)
Cortex.Events:Publish(Cortex.Constants.EVENTS.CONTEXT_UPDATED, "Location", time())
Cortex:GetModule("Recommendations"):GetRecommendations()
assert(#profiler:GetSnapshot().timings == 0)
Cortex.Events:Publish(Cortex.Constants.EVENTS.CONTEXT_UPDATED, "Gear", time(), { "character.itemLevel" })
Cortex:GetModule("Recommendations"):GetRecommendations()
assert(#profiler:GetSnapshot().timings == 0)
Cortex.Events:Publish(Cortex.Constants.EVENTS.CONTEXT_UPDATED, "Gear", time())
Cortex:GetModule("Recommendations"):GetRecommendations()
local recommendationRebuilds = 0
for _, metric in ipairs(profiler:GetSnapshot().timings) do
    if metric.category == "recommendation" and metric.name == "rebuild" then
        recommendationRebuilds = metric.count
    end
end
assert(recommendationRebuilds == 1)

profiler:Reset()
local _, firstGearState = contextService:CollectNow("Gear", "test", { count = 0 })
assert(firstGearState == "collected")
Cortex:GetModule("Recommendations"):GetRecommendations()
local _, secondGearState = contextService:CollectNow("Gear", "test", { count = 0 })
assert(secondGearState == "unchanged")
Cortex:GetModule("Recommendations"):GetRecommendations()
recommendationRebuilds = 0
for _, metric in ipairs(profiler:GetSnapshot().timings) do
    if metric.category == "recommendation" and metric.name == "rebuild" then
        recommendationRebuilds = metric.count
    end
end
assert(recommendationRebuilds == 1)
profiler:SetEnabled(false)

contextService.pending = {}
contextService.flushScheduled = true
assert(contextService:QueueCollector("Currency", "CURRENCY_DISPLAY_UPDATE", 1))
assert(contextService:QueueCollector("Currency", "CURRENCY_DISPLAY_UPDATE", 2))
assert(contextService.pending.Currency.event == "coalesced")
contextService.pending = {}
contextService.flushScheduled = false

local shareCodes = Cortex:GetService("ShareCodes")
local goalPayload = {
    title = "Shared weekly", description = "Safe template", goalType = "WEEKLY_COMPLETION",
    priority = 70, estimatedMinutes = 25, requiredActivities = 2,
}
local goalCode = assert(shareCodes:Export("GOAL", goalPayload))
assert(goalCode:find("^CORTEX:1:GOAL:") == 1)
assert(shareCodes:Export("GOAL", goalPayload) == goalCode)
local decodedGoal = assert(shareCodes:Decode(goalCode))
assert(decodedGoal.formatVersion == 1 and decodedGoal.type == "GOAL")
assert(decodedGoal.payload.title == goalPayload.title)
assert(decodedGoal.payload.requiredActivities == 2)
local goalCountBeforePreview = goals:GetGoalCount()
local historyBeforePreview = #CortexDB.history.items
local goalPreview = assert(shareCodes:PrepareImport(goalCode))
assert(goals:GetGoalCount() == goalCountBeforePreview)
assert(#CortexDB.history.items == historyBeforePreview)
assert(shareCodes:Confirm(assert(shareCodes:Decode(goalCode))) == nil)
assert(goals:GetGoalCount() == goalCountBeforePreview)
goalPreview.payload.title = "Tampered after preview"
local importedGoal = assert(shareCodes:Confirm(goalPreview))
assert(importedGoal.title == goalPayload.title)
assert(goals:GetGoalCount() == goalCountBeforePreview + 1)
assert(shareCodes:Confirm(goalPreview) == nil)

local sessionPayload = {
    title = "One hour", budgetMinutes = 60,
    tasks = { { title = "Weekly quest", estimatedMinutes = 10, category = "WEEKLY" } },
}
local sessionCode = assert(shareCodes:Export("SESSION", sessionPayload))
local sessionPreview = assert(shareCodes:PrepareImport(sessionCode))
assert(#Cortex:GetService("TemplateRepository"):GetAll("SESSION") == 0)
local importedSession = assert(shareCodes:Confirm(sessionPreview))
assert(importedSession.budgetMinutes == 60 and #importedSession.tasks == 1)
assert(shareCodes:ExportTemplate("SESSION", importedSession.id) == sessionCode)

local taskListCode = assert(shareCodes:Export("TASK_LIST", {
    title = "Reset list", tasks = { { title = "Check vault" }, { title = "Visit vendor", estimatedMinutes = 5 } },
}))
local taskListPreview = assert(shareCodes:PrepareImport(taskListCode))
assert(#Cortex:GetService("TemplateRepository"):GetAll("TASK_LIST") == 0)
local importedTaskList = assert(shareCodes:Confirm(taskListPreview))
assert(#importedTaskList.tasks == 2)

local rejected, rejection = shareCodes:Decode(goalCode:gsub("CORTEX:1:", "CORTEX:2:", 1))
assert(rejected == nil and rejection == "incompatible-version")
rejected, rejection = shareCodes:Decode(goalCode:gsub(":GOAL:", ":UNKNOWN:", 1))
assert(rejected == nil and rejection == "unknown-type")
rejected, rejection = shareCodes:Decode("CORTEX:1:GOAL:not-base64")
assert(rejected == nil and rejection == "invalid-code")
rejected, rejection = shareCodes:Decode("CORTEX:1:GOAL:" .. string.rep("A", 10924))
assert(rejected == nil and rejection == "payload-too-large")
rejected, rejection = shareCodes:Decode(string.rep("A", Cortex.Constants.MAX_SHARE_CODE_BYTES + 1))
assert(rejected == nil and rejection == "code-too-large")
assert(Cortex:GetService("Deserializer"):Deserialize("s1:ax") == nil)
assert(Cortex:GetService("Serializer"):Serialize(function() end) == nil)
local cyclic = {}; cyclic.self = cyclic
assert(Cortex:GetService("Serializer"):Serialize(cyclic) == nil)
assert(shareCodes:Export("GOAL", { title = "Unsafe", unexpected = true }) == nil)
local tooManyTasks = {}
for index = 1, Cortex.Constants.MAX_SHARE_TASKS + 1 do tooManyTasks[index] = { title = "Task " .. index } end
assert(shareCodes:Export("TASK_LIST", { title = "Too many", tasks = tooManyTasks }) == nil)

local shareDialog = Cortex:GetService("ShareCodeDialog")
shareDialog:Show(taskListCode)
local shareFrameCount = #frames
assert(shareDialog.frame:IsShown() and shareDialog.pendingPreview == nil)
assert(shareDialog:Preview() and shareDialog.pendingPreview ~= nil)
shareDialog.input:SetText(goalCode)
assert(shareDialog.pendingPreview == nil)
assert(shareDialog:Preview())
assert(shareDialog:Confirm())
shareDialog:Hide()
shareDialog:Show()
assert(#frames == shareFrameCount)
shareDialog:Hide()
SlashCmdList.CORTEX("share import")
assert(shareDialog.frame:IsShown())
shareDialog:Hide()
SlashCmdList.CORTEX("goal list")
SlashCmdList.CORTEX("goal debug")
SlashCmdList.CORTEX("recommend")

dispatch(eventFrame, "PLAYER_LOGOUT")
snapshot = database:GetSnapshot("Player-1-00000001")
assert(snapshot.lastLogout > snapshot.lastLogin)

print("foundation smoke test: ok")
