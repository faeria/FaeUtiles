local _, Cortex = ...

local SearchProvider = {
    providers = {},
    providerOrder = {},
}

local VALID_TYPES = {
    COMMAND = true,
    GOAL = true,
    RECOMMENDATION = true,
    CHARACTER = true,
    MODULE = true,
}

local TYPE_ORDER = { COMMAND = 1, GOAL = 2, RECOMMENDATION = 3, CHARACTER = 4, MODULE = 5 }

local function accessibleString(value)
    return type(value) == "string" and Cortex:IsAccessibleValue(value) and value or ""
end

local function normalize(value)
    return string.lower(accessibleString(value))
end

local function isSubsequence(needle, haystack)
    local position = 1
    for index = 1, #needle do
        position = string.find(haystack, string.sub(needle, index, index), position, true)
        if not position then return false end
        position = position + 1
    end
    return true
end

local function scoreResult(result, query)
    if query == "" then return result.priority or 0 end
    local title = normalize(result.title)
    local parts = { title, normalize(result.subtitle), normalize(result.type) }
    for index = 1, #(result.keywords or {}) do parts[#parts + 1] = normalize(result.keywords[index]) end
    local searchable = table.concat(parts, " ")
    local score = result.priority or 0
    for token in string.gmatch(query, "%S+") do
        if title == token then
            score = score + 100
        elseif string.sub(title, 1, #token) == token then
            score = score + 70
        elseif string.find(title, token, 1, true) then
            score = score + 50
        elseif string.find(searchable, token, 1, true) then
            score = score + 25
        elseif isSubsequence(token, searchable) then
            score = score + 10
        else
            return nil
        end
    end
    return score
end

local function openPage(page)
    local navigation = Cortex:GetService("Navigation")
    if navigation and navigation:IsValidPage(page) then navigation:GoTo(page) end
    local window = Cortex:GetService("MainWindow")
    if window then window:Show() end
end

function SearchProvider:RegisterProvider(id, collect)
    if type(id) ~= "string" or id == "" or type(collect) ~= "function" or self.providers[id] then
        return false
    end
    self.providers[id] = collect
    self.providerOrder[#self.providerOrder + 1] = id
    return true
end

function SearchProvider:Initialize()
    self:RegisterProvider("commands", function()
        local results = {}
        for _, command in ipairs(Cortex:GetService("Commands"):GetCommands()) do
            local available = true
            if command.isAvailable then
                local ok, value = pcall(command.isAvailable)
                available = ok and value == true
            end
            if available then
                results[#results + 1] = {
                    id = command.id, title = command.title, subtitle = command.subtitle,
                    type = "COMMAND", icon = command.icon, keywords = command.keywords,
                    priority = command.priority,
                    action = function() return Cortex:GetService("Commands"):Execute(command.id) end,
                }
            end
        end
        return results
    end)

    self:RegisterProvider("goals", function()
        local results = {}
        for _, goal in ipairs(Cortex:GetModule("Goals"):GetGoals()) do
            results[#results + 1] = {
                id = "goal:" .. goal.id, title = accessibleString(goal.title),
                subtitle = Cortex:GetText("SEARCH_GOAL_SUBTITLE", goal.status, goal.type),
                type = "GOAL", keywords = { goal.type, goal.status, tostring(goal.id) },
                priority = goal.priority or 0, action = function() openPage("goals") end,
            }
        end
        return results
    end)

    self:RegisterProvider("recommendations", function()
        local results = {}
        for _, recommendation in ipairs(Cortex:GetModule("Recommendations"):GetRecommendations()) do
            results[#results + 1] = {
                id = "recommendation:" .. recommendation.id, title = accessibleString(recommendation.title),
                subtitle = accessibleString(recommendation:GetReason()), type = "RECOMMENDATION",
                keywords = { recommendation.category, recommendation.ruleId },
                priority = recommendation.score or recommendation.priority or 0,
                action = function() openPage("overview") end,
            }
        end
        return results
    end)

    self:RegisterProvider("characters", function()
        local results = {}
        local characters = Cortex:GetService("Database"):GetAccount().characters
        for characterKey, character in pairs(type(characters) == "table" and characters or {}) do
            local name = accessibleString(character.name)
            if name ~= "" then
                results[#results + 1] = {
                    id = "character:" .. characterKey, title = name,
                    subtitle = Cortex:GetText("SEARCH_CHARACTER_SUBTITLE", character.level or 0,
                        accessibleString(character.classFile), accessibleString(character.realm)),
                    type = "CHARACTER", keywords = { characterKey, character.realm, character.classFile },
                    action = function() openPage("warband") end,
                }
            end
        end
        return results
    end)

    self:RegisterProvider("modules", function()
        local results = {}
        local _, modules = Cortex.Registry:GetDescriptors()
        for name in pairs(modules) do
            local page = string.lower(name)
            if not Cortex:GetService("Navigation"):IsValidPage(page) then page = "overview" end
            results[#results + 1] = {
                id = "module:" .. name, title = name,
                subtitle = Cortex:GetText(Cortex:IsModuleEnabled(name)
                    and "SEARCH_MODULE_ENABLED" or "SEARCH_MODULE_DISABLED"),
                type = "MODULE", keywords = { "module", name },
                action = function() openPage(page) end,
            }
        end
        return results
    end)
end

function SearchProvider:Search(query, limit)
    query = normalize(query):match("^%s*(.-)%s*$")
    limit = math.max(1, math.floor(tonumber(limit) or 20))
    local matches = {}
    for index = 1, #self.providerOrder do
        local providerId = self.providerOrder[index]
        local ok, results = pcall(self.providers[providerId])
        if not ok then
            Cortex:GetService("Logger"):Error(Cortex:GetText("SEARCH_PROVIDER_ERROR", providerId))
        elseif type(results) == "table" and not Cortex:IsSecretTable(results) then
            for resultIndex = 1, #results do
                local result = results[resultIndex]
                if type(result) == "table" and VALID_TYPES[result.type] and accessibleString(result.id) ~= ""
                    and accessibleString(result.title) ~= "" and type(result.action) == "function" then
                    local score = scoreResult(result, query)
                    if score then result.searchScore = score; matches[#matches + 1] = result end
                end
            end
        end
    end
    table.sort(matches, function(left, right)
        if left.searchScore ~= right.searchScore then return left.searchScore > right.searchScore end
        if TYPE_ORDER[left.type] ~= TYPE_ORDER[right.type] then return TYPE_ORDER[left.type] < TYPE_ORDER[right.type] end
        local leftTitle, rightTitle = normalize(left.title), normalize(right.title)
        if leftTitle ~= rightTitle then return leftTitle < rightTitle end
        return left.id < right.id
    end)
    while #matches > limit do table.remove(matches) end
    return matches
end

function SearchProvider:Execute(result)
    if type(result) ~= "table" or type(result.action) ~= "function" then return false end
    local ok, value = pcall(result.action)
    if not ok or value == false then
        Cortex:GetService("Logger"):Error(Cortex:GetText("SEARCH_ACTION_ERROR", result.title or "?"))
        return false
    end
    return true
end

Cortex:RegisterService("Search", SearchProvider, {
    services = { "Logger", "Commands", "Database", "Navigation" },
    modules = { "Goals", "Recommendations" },
})
