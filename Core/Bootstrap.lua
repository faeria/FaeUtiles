local addonName, Cortex = ...

local eventFrame = CreateFrame("Frame")
local isInitialized = false
local combatLockdown = InCombatLockdown() == true
local deferredWork = {}

function Cortex:IsInCombatLockdown()
    return combatLockdown or InCombatLockdown() == true
end

local function runSafely(callback)
    local ok = pcall(callback)
    if not ok then
        Cortex:GetService("Logger"):Error(Cortex:GetText("DEFERRED_WORK_ERROR"))
    end
    return ok
end

function Cortex:DeferUntilOutOfCombat(key, callback)
    if type(key) ~= "string" or key == "" or type(callback) ~= "function" then
        return false, "invalid-work"
    end

    if not self:IsInCombatLockdown() then
        return runSafely(callback), "executed"
    end

    deferredWork[key] = callback
    return true, "deferred"
end

local function flushDeferredWork()
    if Cortex:IsInCombatLockdown() then
        return
    end

    local pending = deferredWork
    deferredWork = {}
    for _, callback in pairs(pending) do
        runSafely(callback)
    end
end

local function initialize()
    if isInitialized then
        return true
    end

    local initialized, reason = Cortex.Registry:InitializeAll()
    if not initialized then
        error("Cortex initialization failed: " .. tostring(reason))
    end

    local database = Cortex:GetService("Database")
    Cortex:GetService("Logger"):SetLevel(database:GetLogLevel())
    Cortex:GetService("Profiler"):SetEnabled(database:IsProfilingEnabled())

    local modulesApplied, moduleReason = Cortex.Registry:ApplyModuleStates()
    if not modulesApplied then
        error("Cortex module activation failed: " .. tostring(moduleReason))
    end

    isInitialized = true
    Cortex.Events:Publish(Cortex.Constants.EVENTS.ADDON_INITIALIZED, Cortex.version)
    Cortex:GetService("Logger"):Debug(Cortex:GetText("INITIALIZED_DEBUG", Cortex.version))
    return true
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    Cortex:GetService("Profiler"):RecordEvent("wow.core", event)
    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName ~= addonName then
            return
        end

        self:UnregisterEvent("ADDON_LOADED")
        initialize()
        return
    end

    if not isInitialized then
        return
    end

    if event == "PLAYER_LOGIN" then
        Cortex:GetService("Database"):MarkLogin()
        Cortex.Events:Publish(Cortex.Constants.EVENTS.PLAYER_LOGIN)
        Cortex:GetService("Context"):RequestRefresh("login")
    elseif event == "PLAYER_LOGOUT" then
        Cortex.Events:Publish(Cortex.Constants.EVENTS.PLAYER_LOGOUT)
        Cortex:GetService("Database"):MarkLogout()
    elseif event == "PLAYER_REGEN_DISABLED" then
        combatLockdown = true
        Cortex.Events:Publish(Cortex.Constants.EVENTS.COMBAT_LOCKDOWN_CHANGED, true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        combatLockdown = false
        Cortex.Events:Publish(Cortex.Constants.EVENTS.COMBAT_LOCKDOWN_CHANGED, false)
        flushDeferredWork()
    end
end)
