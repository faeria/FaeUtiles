local _, Cortex = ...

local CommandRegistry = {
    commands = {},
    order = {},
}

local function isString(value)
    return type(value) == "string" and value ~= "" and Cortex:IsAccessibleValue(value)
end

local function normalizeIcon(value)
    if (type(value) == "string" or type(value) == "number") and Cortex:IsAccessibleValue(value) then
        return value
    end
    return nil
end

function CommandRegistry:Register(specification)
    if type(specification) ~= "table" or not isString(specification.id)
        or not isString(specification.title) or type(specification.execute) ~= "function"
        or self.commands[specification.id] then
        return false
    end

    local keywords = {}
    if type(specification.keywords) == "table" and not Cortex:IsSecretTable(specification.keywords) then
        for index = 1, #specification.keywords do
            if isString(specification.keywords[index]) then
                keywords[#keywords + 1] = specification.keywords[index]
            end
        end
    end

    local command = {
        id = specification.id,
        title = specification.title,
        subtitle = isString(specification.subtitle) and specification.subtitle or "",
        type = "COMMAND",
        icon = normalizeIcon(specification.icon),
        keywords = keywords,
        priority = type(specification.priority) == "number" and specification.priority or 0,
        execute = specification.execute,
        isAvailable = type(specification.isAvailable) == "function" and specification.isAvailable or nil,
    }
    self.commands[command.id] = command
    self.order[#self.order + 1] = command.id
    return true
end

function CommandRegistry:Unregister(id)
    if not self.commands[id] then return false end
    self.commands[id] = nil
    for index = #self.order, 1, -1 do
        if self.order[index] == id then table.remove(self.order, index); break end
    end
    return true
end

function CommandRegistry:Get(id)
    return self.commands[id]
end

function CommandRegistry:GetCommands()
    local commands = {}
    for index = 1, #self.order do
        local command = self.commands[self.order[index]]
        if command then commands[#commands + 1] = command end
    end
    return commands
end

function CommandRegistry:Execute(id, ...)
    local command = self.commands[id]
    if not command then return false, "missing-command" end
    if command.isAvailable then
        local available, result = pcall(command.isAvailable)
        if not available or result ~= true then return false, "unavailable-command" end
    end
    local ok, result = pcall(command.execute, ...)
    if not ok or result == false then
        Cortex:GetService("Logger"):Error(Cortex:GetText("COMMAND_EXECUTION_ERROR", command.title))
        return false, ok and "execution-rejected" or result
    end
    return true, result
end

Cortex.Commands = CommandRegistry
Cortex:RegisterService("Commands", CommandRegistry, { services = { "Logger" } })
