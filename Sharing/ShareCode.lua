local _, Cortex = ...

local ShareCode = {}
ShareCode.__index = ShareCode

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DECODE = {}
for index = 1, #ALPHABET do DECODE[ALPHABET:sub(index, index)] = index - 1 end

local function encodeBase64(input)
    local output = {}
    for index = 1, #input, 3 do
        local first = input:byte(index)
        local second = input:byte(index + 1)
        local third = input:byte(index + 2)
        local combined = first * 65536 + (second or 0) * 256 + (third or 0)
        local a = math.floor(combined / 262144) % 64
        local b = math.floor(combined / 4096) % 64
        local c = math.floor(combined / 64) % 64
        local d = combined % 64
        output[#output + 1] = ALPHABET:sub(a + 1, a + 1)
        output[#output + 1] = ALPHABET:sub(b + 1, b + 1)
        output[#output + 1] = second and ALPHABET:sub(c + 1, c + 1) or "="
        output[#output + 1] = third and ALPHABET:sub(d + 1, d + 1) or "="
    end
    return table.concat(output)
end

local function decodeBase64(input)
    if type(input) ~= "string" or input == "" or #input % 4 ~= 0 then return nil, "invalid-base64" end
    if math.floor(#input / 4) * 3 > Cortex.Constants.MAX_SHARE_PAYLOAD_BYTES + 2 then
        return nil, "payload-too-large"
    end
    local output = {}
    for index = 1, #input, 4 do
        local chars = {
            input:sub(index, index), input:sub(index + 1, index + 1),
            input:sub(index + 2, index + 2), input:sub(index + 3, index + 3),
        }
        local isLast = index + 3 == #input
        if not DECODE[chars[1]] or not DECODE[chars[2]] then return nil, "invalid-base64" end
        if chars[3] == "=" and (chars[4] ~= "=" or not isLast) then return nil, "invalid-base64" end
        if chars[4] == "=" and not isLast then return nil, "invalid-base64" end
        if chars[3] ~= "=" and not DECODE[chars[3]] then return nil, "invalid-base64" end
        if chars[4] ~= "=" and not DECODE[chars[4]] then return nil, "invalid-base64" end
        local combined = DECODE[chars[1]] * 262144 + DECODE[chars[2]] * 4096
            + (DECODE[chars[3]] or 0) * 64 + (DECODE[chars[4]] or 0)
        output[#output + 1] = string.char(math.floor(combined / 65536) % 256)
        if chars[3] ~= "=" then output[#output + 1] = string.char(math.floor(combined / 256) % 256) end
        if chars[4] ~= "=" then output[#output + 1] = string.char(combined % 256) end
    end
    local decoded = table.concat(output)
    if #decoded > Cortex.Constants.MAX_SHARE_PAYLOAD_BYTES then return nil, "payload-too-large" end
    if encodeBase64(decoded) ~= input then return nil, "invalid-base64" end
    return decoded
end

function ShareCode.Create(envelope, payload, summary)
    return setmetatable({
        formatVersion = envelope.formatVersion,
        type = envelope.type,
        payload = Cortex.Schema.Copy(payload),
        summary = summary,
    }, ShareCode)
end

function ShareCode:GetSummary() return self.summary end

local ShareCodeService = { pendingPreview = nil }

function ShareCodeService:Export(shareType, payload)
    shareType = type(shareType) == "string" and Cortex:IsAccessibleValue(shareType)
        and string.upper(shareType) or ""
    local validated, validationReason = Cortex:GetService("ShareValidation"):Validate(shareType, payload)
    if not validated then return nil, validationReason end
    local serialized, serializationReason = Cortex:GetService("Serializer"):Serialize(validated)
    if not serialized then return nil, serializationReason end
    local code = Cortex:GetService("ShareVersioning"):BuildEnvelope(shareType, encodeBase64(serialized))
    if #code > Cortex.Constants.MAX_SHARE_CODE_BYTES then return nil, "code-too-large" end
    return code
end

function ShareCodeService:Decode(code)
    local envelope, envelopeReason = Cortex:GetService("ShareVersioning"):ParseEnvelope(code)
    if not envelope then return nil, envelopeReason end
    local validation = Cortex:GetService("ShareValidation")
    if not validation:IsKnownType(envelope.type) then return nil, "unknown-type" end
    local decoded, decodeReason = decodeBase64(envelope.encodedPayload)
    if not decoded then return nil, decodeReason end
    local payload, deserializeReason = Cortex:GetService("Deserializer"):Deserialize(decoded)
    if not payload then return nil, deserializeReason end
    local validated, validationReason = validation:Validate(envelope.type, payload)
    if not validated then return nil, validationReason end
    return ShareCode.Create(envelope, validated, validation:Describe(envelope.type, validated))
end

function ShareCodeService:PrepareImport(code)
    self.pendingPreview = nil
    local preview, reason = self:Decode(code)
    if not preview then return nil, reason end
    self.pendingPreview = {
        token = preview,
        type = preview.type,
        payload = Cortex.Schema.Copy(preview.payload),
        formatVersion = preview.formatVersion,
    }
    return preview
end

function ShareCodeService:CancelImport()
    self.pendingPreview = nil
end

function ShareCodeService:Confirm(preview)
    local pending = self.pendingPreview
    if preview == nil or type(pending) ~= "table" or preview ~= pending.token then
        return nil, "confirmation-required"
    end
    self.pendingPreview = nil
    if not Cortex:GetService("Database"):CanWrite() then return nil, "read-only" end
    local imported, reason
    if pending.type == "GOAL" then
        local payload = pending.payload
        imported = Cortex:GetModule("Goals"):AddGoal({
            type = payload.goalType,
            title = payload.title,
            description = payload.description,
            priority = payload.priority,
            target = payload.goalType == "WEEKLY_COMPLETION"
                and { requiredActivities = payload.requiredActivities } or {},
            metadata = { estimatedMinutes = payload.estimatedMinutes },
        })
        if not imported then reason = "goal-import-failed" end
    else
        imported, reason = Cortex:GetService("TemplateRepository"):Add(pending.type, pending.payload, time())
    end
    if not imported then return nil, reason or "import-failed" end
    Cortex:GetService("Database"):AppendHistory("share-import", {
        shareType = pending.type,
        importedId = imported.id,
        formatVersion = pending.formatVersion,
    })
    return imported
end

function ShareCodeService:ExportGoal(goalId)
    local goal = Cortex:GetModule("Goals"):GetGoal(goalId)
    if not goal then return nil, "goal-not-found" end
    return self:Export("GOAL", {
        title = goal.title,
        description = goal.description,
        goalType = goal.type,
        priority = goal.priority,
        estimatedMinutes = goal.metadata.estimatedMinutes or 30,
        requiredActivities = goal.type == "WEEKLY_COMPLETION" and goal.target.requiredActivities or nil,
    })
end

function ShareCodeService:ExportTemplate(shareType, templateId)
    shareType = type(shareType) == "string" and Cortex:IsAccessibleValue(shareType)
        and string.upper(shareType) or ""
    local template = Cortex:GetService("TemplateRepository"):Get(shareType, templateId)
    if not template then return nil, "template-not-found" end
    template.id, template.importedAt = nil, nil
    return self:Export(shareType, template)
end

Cortex.ShareCode = ShareCode
Cortex:RegisterService("ShareCodes", ShareCodeService, {
    services = { "Serializer", "Deserializer", "ShareVersioning", "ShareValidation", "TemplateRepository", "Database" },
    modules = { "Goals" },
})
