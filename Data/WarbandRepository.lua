local _, Cortex = ...

local WarbandRepository = {
    root = nil,
}

local FIELD_NAMES = { "itemLevel", "professions", "transferableCurrencies", "weekly" }

local function fieldState(field, isActive, liveSince)
    if type(field) ~= "table" or field.value == nil then return "UNKNOWN" end
    if isActive and type(liveSince) == "number" and liveSince > 0
        and type(field.capturedAt) == "number" and field.capturedAt >= liveSince then
        return "LIVE"
    end
    return "CACHED"
end

function WarbandRepository:Initialize()
    self.root = Cortex:GetService("Database"):GetAccount()
end

function WarbandRepository:Capture(characterKey, identity, values, capturedAt)
    if type(characterKey) ~= "string" or characterKey == "" or type(identity) ~= "table"
        or type(values) ~= "table" or type(capturedAt) ~= "number" then return false end
    local record = self.root.characters[characterKey]
    local changed = type(record) ~= "table"
    if type(record) ~= "table" then
        record = { guid = characterKey, snapshot = Cortex.Schema.NewWarbandSnapshot() }
        self.root.characters[characterKey] = record
    end
    if not Cortex.Schema.NormalizeWarbandCharacter(record, characterKey) then return false end

    changed = changed or record.name ~= identity.name or record.realm ~= identity.realm
        or record.classFile ~= identity.classFile or record.classId ~= identity.classId
        or record.level ~= identity.level
    record.name, record.realm = identity.name, identity.realm
    record.classFile, record.classId = identity.classFile, identity.classId
    record.level = identity.level
    record.lastSeenAt = math.max(record.lastSeenAt or 0, capturedAt)
    local snapshot = record.snapshot
    snapshot.capturedAt = math.max(snapshot.capturedAt or 0, capturedAt)
    for index = 1, #FIELD_NAMES do
        local fieldName = FIELD_NAMES[index]
        if values[fieldName] ~= nil then
            local current = snapshot.fields[fieldName]
            if type(current) ~= "table" or not Cortex.Schema.ValuesEqual(current.value, values[fieldName]) then
                changed = true
            end
            snapshot.fields[fieldName] = {
                capturedAt = capturedAt,
                value = Cortex.Schema.Copy(values[fieldName]),
            }
        end
    end
    if not Cortex.Schema.NormalizeWarbandCharacter(record, characterKey) then return false end
    return true, changed
end

function WarbandRepository:Get(characterKey)
    local record = self.root.characters[characterKey]
    return record and Cortex.Schema.Copy(record) or nil
end

function WarbandRepository:GetCharacters(activeCharacterKey, liveSince, currentTime)
    local characters = {}
    for characterKey, record in pairs(self.root.characters) do
        if type(record) == "table" and record.guid == characterKey
            and type(record.snapshot) == "table" and type(record.snapshot.fields) == "table" then
            local isActive = characterKey == activeCharacterKey
            local snapshot, fields = record.snapshot, {}
            for index = 1, #FIELD_NAMES do
                local fieldName = FIELD_NAMES[index]
                local field = snapshot.fields[fieldName]
                fields[fieldName] = {
                    state = fieldState(field, isActive, liveSince),
                    capturedAt = type(field) == "table" and field.capturedAt or nil,
                    value = type(field) == "table" and Cortex.Schema.Copy(field.value) or nil,
                }
            end
            local professions = fields.professions.value or {}
            local professionNames, professionSkillLines = {}, {}
            for index = 1, #professions do
                professionNames[#professionNames + 1] = professions[index].name
                if professions[index].skillLine then professionSkillLines[#professionSkillLines + 1] = professions[index].skillLine end
            end
            characters[#characters + 1] = {
                key = characterKey,
                name = record.name,
                realm = record.realm,
                classFile = record.classFile,
                classId = record.classId,
                level = record.level,
                lastSeenAt = record.lastSeenAt,
                ageSeconds = type(currentTime) == "number" and math.max(0, currentTime - record.lastSeenAt) or nil,
                state = isActive and "LIVE" or (record.lastSeenAt > 0 and "CACHED" or "UNKNOWN"),
                fields = fields,
                capabilities = {
                    professionNames = professionNames,
                    professionSkillLines = professionSkillLines,
                    hasTransferableCurrencies = #(fields.transferableCurrencies.value or {}) > 0,
                    hasWeeklyReward = fields.weekly.value and
                        (fields.weekly.value.canClaimRewards or fields.weekly.value.hasAvailableRewards) or false,
                },
            }
        end
    end
    table.sort(characters, function(left, right)
        if left.state ~= right.state then
            local order = { LIVE = 1, CACHED = 2, UNKNOWN = 3 }
            return order[left.state] < order[right.state]
        end
        if left.lastSeenAt ~= right.lastSeenAt then return left.lastSeenAt > right.lastSeenAt end
        local leftName, rightName = left.name or "", right.name or ""
        if leftName ~= rightName then return leftName < rightName end
        return left.key < right.key
    end)
    return characters
end

Cortex:RegisterService("WarbandRepository", WarbandRepository, { services = { "Database" } })
