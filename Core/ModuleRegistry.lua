local _, Cortex = ...

local Registry = {
    services = {},
    serviceOrder = {},
    modules = {},
    moduleOrder = {},
}

local function normalizeDependencies(dependencies)
    dependencies = type(dependencies) == "table" and dependencies or {}
    return {
        services = type(dependencies.services) == "table" and dependencies.services or {},
        modules = type(dependencies.modules) == "table" and dependencies.modules or {},
    }
end

local function reportError(message)
    local descriptor = Registry.services.Logger
    if descriptor and descriptor.initialized and descriptor.object then
        descriptor.object:Error(message)
        return
    end

    error(message)
end

local function register(collection, order, name, object, dependencies, options)
    if type(name) ~= "string" or name == "" or type(object) ~= "table" or collection[name] then
        return false
    end

    options = type(options) == "table" and options or {}
    collection[name] = {
        name = name,
        object = object,
        dependencies = normalizeDependencies(dependencies),
        defaultEnabled = options.defaultEnabled == true,
        initialized = false,
        initializing = false,
        enabled = false,
    }
    order[#order + 1] = name
    return true
end

function Cortex:RegisterService(name, service, dependencies)
    return register(Registry.services, Registry.serviceOrder, name, service, dependencies)
end

function Cortex:RegisterModule(name, module, dependencies, options)
    return register(Registry.modules, Registry.moduleOrder, name, module, dependencies, options)
end

function Cortex:GetService(name)
    local descriptor = Registry.services[name]
    return descriptor and descriptor.object or nil
end

function Cortex:GetModule(name)
    local descriptor = Registry.modules[name]
    return descriptor and descriptor.object or nil
end

local initializeService
local initializeModule

local function initializeDescriptor(descriptor)
    if descriptor.initialized then
        return true
    end
    if descriptor.initializing then
        return false, "dependency-cycle:" .. descriptor.name
    end

    descriptor.initializing = true

    for index = 1, #descriptor.dependencies.services do
        local dependencyName = descriptor.dependencies.services[index]
        local ok, reason = initializeService(dependencyName)
        if not ok then
            descriptor.initializing = false
            return false, reason
        end
    end

    for index = 1, #descriptor.dependencies.modules do
        local dependencyName = descriptor.dependencies.modules[index]
        local ok, reason = initializeModule(dependencyName)
        if not ok then
            descriptor.initializing = false
            return false, reason
        end
    end

    if type(descriptor.object.Initialize) == "function" then
        local ok, result = pcall(descriptor.object.Initialize, descriptor.object)
        if not ok or result == false then
            descriptor.initializing = false
            return false, "initialize-failed:" .. descriptor.name
        end
    end

    descriptor.initializing = false
    descriptor.initialized = true
    return true
end

initializeService = function(name)
    local descriptor = Registry.services[name]
    if not descriptor then
        return false, "missing-service:" .. tostring(name)
    end
    return initializeDescriptor(descriptor)
end

initializeModule = function(name)
    local descriptor = Registry.modules[name]
    if not descriptor then
        return false, "missing-module:" .. tostring(name)
    end
    return initializeDescriptor(descriptor)
end

function Registry:InitializeAll()
    for index = 1, #self.serviceOrder do
        local ok, reason = initializeService(self.serviceOrder[index])
        if not ok then
            reportError("Cortex service initialization failed: " .. reason)
            return false, reason
        end
    end

    for index = 1, #self.moduleOrder do
        local ok, reason = initializeModule(self.moduleOrder[index])
        if not ok then
            reportError("Cortex module initialization failed: " .. reason)
            return false, reason
        end
    end

    return true
end

local function publishModuleState(name, enabled)
    local events = Cortex:GetService("Events")
    if events then
        events:Publish(Cortex.Constants.EVENTS.MODULE_STATE_CHANGED, name, enabled)
    end
end

local function persistModuleState(name, enabled)
    local database = Cortex:GetService("Database")
    if database and database:IsInitialized() then
        database:SetModuleState(name, enabled)
    end
end

function Cortex:EnableModule(name, persist)
    local descriptor = Registry.modules[name]
    if not descriptor then
        return false, "missing-module"
    end
    if descriptor.enabled then
        return true
    end

    local ok, reason = initializeModule(name)
    if not ok then
        return false, reason
    end

    for index = 1, #descriptor.dependencies.modules do
        local dependencyName = descriptor.dependencies.modules[index]
        local dependencyEnabled, dependencyReason = self:EnableModule(dependencyName, persist)
        if not dependencyEnabled then
            return false, dependencyReason
        end
    end

    local function enableNow()
        if type(descriptor.object.Enable) == "function" then
            local callOk, result = pcall(descriptor.object.Enable, descriptor.object)
            if not callOk or result == false then
                return false
            end
        end

        descriptor.enabled = true
        if persist ~= false then
            persistModuleState(name, true)
        end
        publishModuleState(name, true)
        return true
    end

    if descriptor.object.requiresOutOfCombat and self:IsInCombatLockdown() then
        self:DeferUntilOutOfCombat("module:enable:" .. name, enableNow)
        return true, "deferred"
    end

    if not enableNow() then
        return false, "enable-failed"
    end
    return true
end

function Cortex:DisableModule(name, persist)
    local descriptor = Registry.modules[name]
    if not descriptor then
        return false, "missing-module"
    end
    if not descriptor.enabled then
        return true
    end

    for index = 1, #Registry.moduleOrder do
        local dependent = Registry.modules[Registry.moduleOrder[index]]
        if dependent.enabled then
            for dependencyIndex = 1, #dependent.dependencies.modules do
                if dependent.dependencies.modules[dependencyIndex] == name then
                    return false, "required-by:" .. dependent.name
                end
            end
        end
    end

    local function disableNow()
        if type(descriptor.object.Disable) == "function" then
            local callOk, result = pcall(descriptor.object.Disable, descriptor.object)
            if not callOk or result == false then
                return false
            end
        end

        descriptor.enabled = false
        if persist ~= false then
            persistModuleState(name, false)
        end
        publishModuleState(name, false)
        return true
    end

    if descriptor.object.requiresOutOfCombat and self:IsInCombatLockdown() then
        self:DeferUntilOutOfCombat("module:disable:" .. name, disableNow)
        return true, "deferred"
    end

    if not disableNow() then
        return false, "disable-failed"
    end
    return true
end

function Cortex:IsModuleEnabled(name)
    local descriptor = Registry.modules[name]
    return descriptor and descriptor.enabled or false
end

function Cortex:GetEnabledModuleNames()
    local names = {}
    for index = 1, #Registry.moduleOrder do
        local name = Registry.moduleOrder[index]
        if Registry.modules[name].enabled then
            names[#names + 1] = name
        end
    end
    return names
end

function Registry:ApplyModuleStates()
    local database = Cortex:GetService("Database")
    for index = 1, #self.moduleOrder do
        local name = self.moduleOrder[index]
        local descriptor = self.modules[name]
        local configured = nil
        if database then
            configured = database:GetModuleState(name)
        end
        local shouldEnable = descriptor.defaultEnabled
        if type(configured) == "boolean" then
            shouldEnable = configured
        end
        if shouldEnable then
            local ok, reason = Cortex:EnableModule(name, false)
            if not ok then
                return false, name .. ":" .. tostring(reason)
            end
        end
    end
    return true
end

function Registry:GetDescriptors()
    return self.services, self.modules
end

Cortex.Registry = Registry
