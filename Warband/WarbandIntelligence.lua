local _, Cortex = ...

local WarbandIntelligence = {
    liveSince = nil,
}

local CAPTURE_FIELDS = {
    Character = {},
    Gear = { itemLevel = true },
    Currency = { transferableCurrencies = true },
    Weekly = { weekly = true },
    Profession = { professions = true },
}

local function copyProfessions(learned)
    local professions = {}
    for _, profession in pairs(type(learned) == "table" and learned or {}) do
        if type(profession) == "table" and type(profession.name) == "string" then
            professions[#professions + 1] = {
                name = profession.name,
                skillLine = profession.skillLine,
                skillLevel = profession.skillLevel,
                maxSkillLevel = profession.maxSkillLevel,
            }
        end
    end
    table.sort(professions, function(left, right)
        if left.name ~= right.name then return left.name < right.name end
        return (left.skillLine or 0) < (right.skillLine or 0)
    end)
    return professions
end

local function copyTransferableCurrencies(byID)
    local ids = {}
    for currencyID, currency in pairs(type(byID) == "table" and byID or {}) do
        if type(currency) == "table" and currency.isAccountTransferable == true
            and currency.isAccountWide ~= true and Cortex.Schema.IsPositiveInteger(currencyID) then
            ids[#ids + 1] = currencyID
        end
    end
    table.sort(ids)
    local currencies = {}
    for index = 1, math.min(Cortex.Constants.MAX_WARBAND_CURRENCIES, #ids) do
        local currency = byID[ids[index]]
        currencies[index] = {
            currencyID = ids[index],
            name = currency.name,
            quantity = currency.quantity,
            iconFileID = currency.iconFileID,
        }
    end
    return currencies
end

local function copyWeekly(weekly)
    local completed, total = 0, 0
    local activities = type(weekly.activities) == "table" and weekly.activities or {}
    for index = 1, #activities do
        local activity = activities[index]
        if type(activity) == "table" and type(activity.progress) == "number"
            and type(activity.threshold) == "number" and activity.threshold > 0 then
            total = total + 1
            if activity.progress >= activity.threshold then completed = completed + 1 end
        end
    end
    return {
        completedActivities = completed,
        totalActivities = total,
        canClaimRewards = weekly.canClaimRewards,
        hasAvailableRewards = weekly.hasAvailableRewards,
    }
end

function WarbandIntelligence:Initialize() end

function WarbandIntelligence:Enable()
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.PLAYER_LOGIN, self, self.OnPlayerLogin)
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.PLAYER_LOGOUT, self, self.OnPlayerLogout)
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.CONTEXT_UPDATED, self, self.OnContextUpdated)
end

function WarbandIntelligence:Disable()
    Cortex.Events:UnsubscribeOwner(self)
    self.liveSince = nil
end

function WarbandIntelligence:OnPlayerLogin()
    self.liveSince = time()
end

function WarbandIntelligence:OnPlayerLogout()
    self:CaptureCurrent("logout")
end

function WarbandIntelligence:OnContextUpdated(source)
    if CAPTURE_FIELDS[source] then self:CaptureCurrent(source) end
end

function WarbandIntelligence:CaptureCurrent(reason)
    local context = Cortex:GetService("Context")
    local character = context:Get("character.current") or context:GetCurrentCharacter()
    if type(character) ~= "table" or type(character.guid) ~= "string" then return false end
    local requestedFields = CAPTURE_FIELDS[reason]
    local captureAll = requestedFields == nil
    local values = {}
    if (captureAll or requestedFields.itemLevel)
        and context:GetStatus("character.itemLevel") == "available" then
        values.itemLevel = context:Get("character.itemLevel")
    end
    if (captureAll or requestedFields.professions)
        and context:GetStatus("professions.learned") == "available" then
        values.professions = copyProfessions(context:Get("professions.learned"))
    end
    if (captureAll or requestedFields.transferableCurrencies)
        and context:GetStatus("currency.byID") == "available" then
        values.transferableCurrencies = copyTransferableCurrencies(context:Get("currency.byID"))
    end
    if (captureAll or requestedFields.weekly) and context:GetStatus("weekly") == "available" then
        values.weekly = copyWeekly(context:Get("weekly"))
    end
    local repository = Cortex:GetService("WarbandRepository")
    local existing = repository:Get(character.guid)
    local becameLive = false
    if type(self.liveSince) == "number" and existing and existing.snapshot
        and type(existing.snapshot.fields) == "table" then
        for fieldName in pairs(values) do
            local field = existing.snapshot.fields[fieldName]
            if type(field) ~= "table" or type(field.capturedAt) ~= "number"
                or field.capturedAt < self.liveSince then
                becameLive = true
                break
            end
        end
    end
    local capturedAt = time()
    local captured, changed = repository:Capture(character.guid, character, values, capturedAt)
    if captured and (changed or becameLive) then
        Cortex.Events:Publish(Cortex.Constants.EVENTS.WARBAND_UPDATED, character.guid, reason, capturedAt)
    end
    return captured and (changed or becameLive) or false
end

function WarbandIntelligence:GetCharacters()
    local database = Cortex:GetService("Database")
    return Cortex:GetService("WarbandRepository"):GetCharacters(
        database:GetActiveCharacterKey(), self.liveSince, time())
end

local function professionMatches(profession, requiredSkillLine, requiredName)
    if requiredSkillLine and profession.skillLine == requiredSkillLine then return true end
    return requiredName and type(profession.name) == "string"
        and string.lower(profession.name) == string.lower(requiredName)
end

function WarbandIntelligence:GetProfessionContributions(goals, characters)
    goals = goals or Cortex:GetModule("Goals")
    local insights, seen = {}, {}
    characters = characters or self:GetCharacters()
    for _, goal in ipairs(goals:GetGoals()) do
        if Cortex.Goal.IsOpen(goal) then
            local requiredSkillLine = goal.target.professionSkillLine
                or goal.metadata.requiredProfessionSkillLine
            local requiredName = goal.target.professionName or goal.metadata.requiredProfessionName
            if type(requiredSkillLine) ~= "number" then requiredSkillLine = nil end
            if type(requiredName) ~= "string" or requiredName == "" then requiredName = nil end
            if requiredSkillLine or requiredName then
                for _, character in ipairs(characters) do
                    if character.fields.professions.state ~= "UNKNOWN" then
                        for _, profession in ipairs(character.fields.professions.value or {}) do
                            if professionMatches(profession, requiredSkillLine, requiredName) then
                                local key = goal.id .. ":" .. character.key .. ":" .. profession.name
                                if not seen[key] then
                                    insights[#insights + 1] = {
                                        id = key, goalId = goal.id, characterKey = character.key,
                                        characterName = character.name, professionName = profession.name,
                                        state = character.fields.professions.state, certainty = "POTENTIAL",
                                        reason = Cortex:GetText("WARBAND_PROFESSION_POTENTIAL_REASON",
                                            character.name or "?", profession.name, goal.title),
                                    }
                                    seen[key] = true
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(insights, function(left, right) return left.id < right.id end)
    return insights
end

function WarbandIntelligence:GetOverview()
    local characters = self:GetCharacters()
    local counts = { LIVE = 0, CACHED = 0, UNKNOWN = 0 }
    for index = 1, #characters do counts[characters[index].state] = counts[characters[index].state] + 1 end
    return {
        characters = characters,
        counts = counts,
        insights = self:GetProfessionContributions(nil, characters),
    }
end

Cortex:RegisterModule("Warband", WarbandIntelligence, {
    services = { "Events", "Context", "Database", "WarbandRepository" },
    modules = { "Goals" },
}, {
    defaultEnabled = true,
})
