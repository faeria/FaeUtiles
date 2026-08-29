local _, Cortex = ...

local TemplateRepository = { root = nil, database = nil }

local COLLECTIONS = { SESSION = "sessions", TASK_LIST = "taskLists" }

local function count(items)
    local total = 0
    for _ in pairs(items) do total = total + 1 end
    return total
end

function TemplateRepository:Initialize()
    self.database = Cortex:GetService("Database")
    self.root = self.database:GetAccount().templates
end

function TemplateRepository:Add(templateType, payload, importedAt)
    local collectionName = COLLECTIONS[templateType]
    if not self.database:CanWrite() then return nil, "read-only" end
    if not collectionName or type(payload) ~= "table" then return nil, "invalid-template" end
    local collection = self.root[collectionName]
    if count(collection) >= Cortex.Constants.MAX_SHARE_TEMPLATES then return nil, "template-limit" end
    local templateId = self.root.nextId
    local record = Cortex.Schema.Copy(payload)
    record.id = templateId
    record.importedAt = type(importedAt) == "number" and importedAt or time()
    collection[templateId] = record
    self.root.nextId = templateId + 1
    self.root = Cortex.Schema.NormalizeTemplates(self.root)
    return Cortex.Schema.Copy(self.root[collectionName][templateId])
end

function TemplateRepository:Get(templateType, templateId)
    local collectionName = COLLECTIONS[templateType]
    local record = collectionName and self.root[collectionName][templateId] or nil
    return record and Cortex.Schema.Copy(record) or nil
end

function TemplateRepository:GetAll(templateType)
    local collectionName = COLLECTIONS[templateType]
    local templates = {}
    for _, record in pairs(collectionName and self.root[collectionName] or {}) do
        templates[#templates + 1] = Cortex.Schema.Copy(record)
    end
    table.sort(templates, function(left, right) return left.id < right.id end)
    return templates
end

Cortex:RegisterService("TemplateRepository", TemplateRepository, { services = { "Database" } })
