local _, Cortex = ...
local UI = Cortex.UI

local WarbandPage = {}

local function createCharacterRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.background = UI.CreateBackground(row, UI.Theme.colors.surface)
    row.title = UI.CreateText(row, "GameFontHighlight", UI.Theme.colors.text)
    row.title:SetPoint("TOPLEFT", 14, -9); row.title:SetPoint("RIGHT", -136, 0)
    row.details = UI.CreateText(row, "GameFontHighlightSmall", UI.Theme.colors.muted)
    row.details:SetPoint("TOPLEFT", 14, -29); row.details:SetPoint("RIGHT", -136, 0)
    row.capabilities = UI.CreateText(row, "GameFontHighlightSmall", UI.Theme.colors.muted)
    row.capabilities:SetPoint("BOTTOMLEFT", 14, 7); row.capabilities:SetPoint("RIGHT", -136, 0)
    row.badge = UI.Badge.Create(row, 122)
    row.badge:SetPoint("RIGHT", -10, 0)
    return row
end

local function createInsightRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.background = UI.CreateBackground(row, UI.Theme.colors.surface)
    row.title = UI.CreateText(row, "GameFontHighlight", UI.Theme.colors.text)
    row.title:SetPoint("TOPLEFT", 12, -10); row.title:SetPoint("RIGHT", -12, 0)
    row.reason = UI.CreateText(row, "GameFontHighlightSmall", UI.Theme.colors.muted)
    row.reason:SetPoint("TOPLEFT", 12, -31); row.reason:SetPoint("BOTTOMRIGHT", -12, 8)
    return row
end

local function pageItems(items, offset, capacity)
    local visible = {}
    for index = 1, capacity do
        if items[offset + index] then visible[index] = items[offset + index] end
    end
    return visible
end

local function lastPageOffset(itemCount, capacity)
    if itemCount < 1 then return 0 end
    return math.floor((itemCount - 1) / capacity) * capacity
end

function WarbandPage.Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.title = UI.CreateText(page, "GameFontNormalLarge", UI.Theme.colors.text)
    page.title:SetPoint("TOPLEFT"); page.title:SetText(Cortex:GetText("WARBAND_TITLE"))
    page.subtitle = UI.CreateText(page, "GameFontHighlight", UI.Theme.colors.muted)
    page.subtitle:SetPoint("TOPLEFT", 0, -28); page.subtitle:SetText(Cortex:GetText("WARBAND_SUBTITLE"))
    page.summary = UI.CreateText(page, "GameFontHighlightSmall", UI.Theme.colors.accent)
    page.summary:SetPoint("TOPLEFT", 0, -52)

    local characterHeader = UI.CreateText(page, "GameFontNormal", UI.Theme.colors.muted)
    characterHeader:SetPoint("TOPLEFT", 0, -80); characterHeader:SetText(Cortex:GetText("WARBAND_CHARACTERS"))
    local insightHeader = UI.CreateText(page, "GameFontNormal", UI.Theme.colors.muted)
    insightHeader:SetPoint("TOPLEFT", 486, -80); insightHeader:SetText(Cortex:GetText("WARBAND_INSIGHTS"))

    page.characterList = UI.ScrollList.Create(page, {
        capacity = 5, rowHeight = 68,
        createRow = function(listParent) return createCharacterRow(listParent) end,
        updateRow = function(row, character)
            row.title:SetText(character.title)
            row.details:SetText(character.details)
            row.capabilities:SetText(character.capabilities)
            row.badge:SetValue(character.status)
        end,
    })
    page.characterList:SetPoint("TOPLEFT", 0, -104); page.characterList:SetWidth(462)
    page.insightList = UI.ScrollList.Create(page, {
        capacity = 4, rowHeight = 82,
        createRow = function(listParent) return createInsightRow(listParent) end,
        updateRow = function(row, insight)
            row.title:SetText(insight.title)
            row.reason:SetText(insight.reason)
        end,
    })
    page.insightList:SetPoint("TOPLEFT", 486, -104); page.insightList:SetWidth(250)

    page.characterPrevious = UI.Button.Create(page, {
        text = Cortex:GetText("SESSION_PREVIOUS"), width = 62, height = 26, align = "center",
    })
    page.characterPrevious:SetPoint("BOTTOMLEFT", 0, 0)
    page.characterNext = UI.Button.Create(page, {
        text = Cortex:GetText("SESSION_NEXT"), width = 62, height = 26, align = "center",
    })
    page.characterNext:SetPoint("BOTTOMLEFT", 68, 0)
    page.insightPrevious = UI.Button.Create(page, {
        text = Cortex:GetText("SESSION_PREVIOUS"), width = 62, height = 26, align = "center",
    })
    page.insightPrevious:SetPoint("BOTTOMLEFT", 486, 0)
    page.insightNext = UI.Button.Create(page, {
        text = Cortex:GetText("SESSION_NEXT"), width = 62, height = 26, align = "center",
    })
    page.insightNext:SetPoint("BOTTOMLEFT", 554, 0)
    page.emptyCharacters = UI.CreateText(page, "GameFontHighlight", UI.Theme.colors.muted, "CENTER")
    page.emptyCharacters:SetPoint("TOP", page.characterList, "TOP", 0, -60)
    page.emptyCharacters:SetText(Cortex:GetText("WARBAND_NO_CHARACTERS")); page.emptyCharacters:Hide()
    page.emptyInsights = UI.CreateText(page, "GameFontHighlightSmall", UI.Theme.colors.muted, "CENTER")
    page.emptyInsights:SetPoint("TOP", page.insightList, "TOP", 0, -36)
    page.emptyInsights:SetWidth(220); page.emptyInsights:SetText(Cortex:GetText("WARBAND_NO_INSIGHTS"))
    page.emptyInsights:Hide()

    function page:Render()
        self.characterList:SetItems(pageItems(self.characters, self.characterOffset, 5))
        self.insightList:SetItems(pageItems(self.insights, self.insightOffset, 4))
        self.characterPrevious:SetShown(self.characterOffset > 0)
        self.characterNext:SetShown(self.characterOffset + 5 < #self.characters)
        self.insightPrevious:SetShown(self.insightOffset > 0)
        self.insightNext:SetShown(self.insightOffset + 4 < #self.insights)
        self.emptyCharacters:SetShown(#self.characters == 0)
        self.emptyInsights:SetShown(#self.insights == 0)
    end
    page.characterPrevious:SetScript("OnClick", function()
        page.characterOffset = math.max(0, page.characterOffset - 5); page:Render()
    end)
    page.characterNext:SetScript("OnClick", function()
        page.characterOffset = math.min(lastPageOffset(#page.characters, 5), page.characterOffset + 5); page:Render()
    end)
    page.insightPrevious:SetScript("OnClick", function()
        page.insightOffset = math.max(0, page.insightOffset - 4); page:Render()
    end)
    page.insightNext:SetScript("OnClick", function()
        page.insightOffset = math.min(lastPageOffset(#page.insights, 4), page.insightOffset + 4); page:Render()
    end)
    function page:SetData(data)
        data = type(data) == "table" and data or {}
        self.characters, self.insights = data.characters or {}, data.insights or {}
        self.characterOffset = math.min(self.characterOffset, lastPageOffset(#self.characters, 5))
        self.insightOffset = math.min(self.insightOffset, lastPageOffset(#self.insights, 4))
        self.summary:SetText(data.summary or "")
        self:Render()
    end
    page.characters, page.insights, page.characterOffset, page.insightOffset = {}, {}, 0, 0
    page:Render(); page:Hide()
    return page
end

UI.WarbandPage = WarbandPage
