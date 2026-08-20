local _, Cortex = ...

local Logger = {
    levels = Cortex.Constants.LOG_LEVELS,
    currentLevel = "INFO",
}

local function writeToChat(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(Cortex:GetText("ADDON_PREFIX") .. message)
    end
end

function Logger:IsValidLevel(level)
    return type(level) == "string" and self.levels[string.upper(level)] ~= nil
end

function Logger:SetLevel(level)
    if not self:IsValidLevel(level) then
        return false
    end

    self.currentLevel = string.upper(level)
    return true
end

function Logger:GetLevel()
    return self.currentLevel
end

function Logger:Write(level, message)
    local normalizedLevel = type(level) == "string" and string.upper(level) or "INFO"
    local threshold = self.levels[normalizedLevel]
    local currentThreshold = self.levels[self.currentLevel]

    if not threshold or threshold > currentThreshold then
        return
    end

    if type(message) ~= "string" or Cortex:IsSecretValue(message) then
        return
    end

    writeToChat("[" .. normalizedLevel .. "] " .. message)
end

function Logger:Error(message)
    self:Write("ERROR", message)
end

function Logger:Warn(message)
    self:Write("WARN", message)
end

function Logger:Info(message)
    self:Write("INFO", message)
end

function Logger:Debug(message)
    self:Write("DEBUG", message)
end

function Logger:Trace(message)
    self:Write("TRACE", message)
end

function Logger:User(message)
    if type(message) ~= "string" or Cortex:IsSecretValue(message) then
        return
    end

    writeToChat(message)
end

Cortex.Logger = Logger
Cortex:RegisterService("Logger", Logger)
