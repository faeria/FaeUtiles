local frames = {}
local combat = false
local playerLevel = 80
local clock = 1000

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
    end

    function widget:Show()
        self.visible = true
        if self.scripts.OnShow then
            self.scripts.OnShow(self)
        end
    end

    function widget:Hide()
        self.visible = false
    end

    function widget:IsShown()
        return self.visible
    end

    function widget:SetSize() end
    function widget:SetPoint() end
    function widget:SetFrameStrata() end
    function widget:EnableMouse() end
    function widget:SetAllPoints() end
    function widget:SetColorTexture() end
    function widget:SetJustifyH() end

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

function issecrettable()
    return false
end

function canaccessvalue()
    return true
end

function time()
    clock = clock + 1
    return clock
end

CortexDB = {
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
    "Core/EventBus.lua",
    "Data/Schema.lua",
    "Data/Migrations.lua",
    "Data/Database.lua",
    "Context/FactStore.lua",
    "Context/ContextService.lua",
    "Goals/Goal.lua",
    "Goals/DependencyGraph.lua",
    "Goals/GoalEngine.lua",
    "Recommendations/Recommendation.lua",
    "Recommendations/RuleEngine.lua",
    "Recommendations/Prioritizer.lua",
    "Recommendations/RecommendationEngine.lua",
    "Planner/SessionPlanner.lua",
    "UI/Navigation.lua",
    "UI/MainWindow.lua",
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

assert(CortexDB.schemaVersion == 2)
assert(CortexDB.goals.items[1].title == "Existing goal")
assert(type(CortexDB.settings.modules) == "table")
assert(Cortex:GetService("Context") ~= nil)
assert(Cortex:GetModule("Goals") ~= nil)
assert(Cortex:IsModuleEnabled("Goals"))
assert(Cortex:IsModuleEnabled("Recommendations"))
assert(Cortex:IsModuleEnabled("Planner"))
assert(Cortex:GetService("Context"):GetCurrentCharacter().level == 80)
assert(Cortex:GetService("Facts"):Get("character.current").guid == "Player-1-00000001")
assert(_G.Cortex == nil)

local eventDelivered = false
Cortex.Events:Subscribe("TEST_EVENT", Cortex, function(_, value)
    eventDelivered = value
end)
Cortex.Events:Publish("TEST_EVENT", true)
assert(eventDelivered)

assert(type(SlashCmdList.CORTEX) == "function")
SlashCmdList.CORTEX("")
assert(Cortex:GetService("MainWindow").frame:IsShown())
SlashCmdList.CORTEX("debug")
assert(Cortex:GetService("Logger"):GetLevel() == "DEBUG")
assert(CortexDB.settings.logLevel == "DEBUG")
SlashCmdList.CORTEX("debug")
assert(Cortex:GetService("Logger"):GetLevel() == "INFO")

combat = true
dispatch(eventFrame, "PLAYER_REGEN_DISABLED")
playerLevel = 81
local queued, state = Cortex:GetService("Context"):RequestRefresh("test")
assert(queued and state == "deferred")
assert(Cortex:GetService("Context"):GetCurrentCharacter().level == 80)
combat = false
dispatch(eventFrame, "PLAYER_REGEN_ENABLED")
assert(Cortex:GetService("Context"):GetCurrentCharacter().level == 81)

assert(not Cortex:DisableModule("Goals"))
assert(Cortex:DisableModule("Planner"))
assert(Cortex:DisableModule("Recommendations"))
assert(Cortex:DisableModule("Goals"))
assert(not Cortex:IsModuleEnabled("Goals"))
assert(Cortex.Registry:ApplyModuleStates())
assert(not Cortex:IsModuleEnabled("Goals"))
assert(not Cortex:IsModuleEnabled("Recommendations"))
assert(not Cortex:IsModuleEnabled("Planner"))
assert(Cortex:EnableModule("Planner"))
assert(Cortex:IsModuleEnabled("Goals"))
assert(Cortex:IsModuleEnabled("Recommendations"))
assert(Cortex:IsModuleEnabled("Planner"))
assert(CortexDB.settings.modules.Goals == true)
assert(CortexDB.settings.modules.Recommendations == true)
assert(CortexDB.settings.modules.Planner == true)

print("foundation smoke test: ok")
