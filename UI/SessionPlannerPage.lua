local _, Cortex = ...
local UI = Cortex.UI

local SessionPlannerPage = {}

local BUDGETS = {
    { value = 30, label = "SESSION_BUDGET_30" },
    { value = 60, label = "SESSION_BUDGET_60" },
    { value = 120, label = "SESSION_BUDGET_120" },
    { value = "unlimited", label = "SESSION_BUDGET_UNLIMITED" },
}

local function createEntryRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.background = UI.CreateBackground(row, UI.Theme.colors.surface)
    row.number = UI.Badge.Create(row, 32)
    row.number:SetPoint("LEFT", 10, 0)
    row.title = UI.CreateText(row, "GameFontHighlight", UI.Theme.colors.text)
    row.title:SetPoint("TOPLEFT", 54, -9); row.title:SetPoint("RIGHT", -100, 0)
    row.reason = UI.CreateText(row, "GameFontHighlightSmall", UI.Theme.colors.muted)
    row.reason:SetPoint("BOTTOMLEFT", 54, 8); row.reason:SetPoint("RIGHT", -100, 0)
    row.duration = UI.CreateText(row, "GameFontHighlightSmall", UI.Theme.colors.accent, "RIGHT")
    row.duration:SetPoint("RIGHT", -14, 0)
    return row
end

function SessionPlannerPage.Create(parent, onBudgetChanged)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.selectedBudget = 60
    page.title = UI.CreateText(page, "GameFontNormalLarge", UI.Theme.colors.text)
    page.title:SetPoint("TOPLEFT"); page.title:SetText(Cortex:GetText("SESSION_TITLE"))
    page.subtitle = UI.CreateText(page, "GameFontHighlight", UI.Theme.colors.muted)
    page.subtitle:SetPoint("TOPLEFT", 0, -28); page.subtitle:SetText(Cortex:GetText("SESSION_SUBTITLE"))

    page.budgetButtons = {}
    for index = 1, #BUDGETS do
        local budget = BUDGETS[index]
        local button = UI.Button.Create(page, {
            text = Cortex:GetText(budget.label), width = budget.value == "unlimited" and 120 or 88,
            height = 30, align = "center",
        })
        button:SetPoint("TOPLEFT", (index - 1) * 98, -58)
        button:SetScript("OnClick", function()
            page.selectedBudget = budget.value
            for buttonIndex = 1, #page.budgetButtons do
                page.budgetButtons[buttonIndex]:SetActive(buttonIndex == index)
            end
            if onBudgetChanged then onBudgetChanged(budget.value) end
        end)
        button:SetActive(budget.value == page.selectedBudget)
        page.budgetButtons[index] = button
    end

    local summary = UI.Card.Create(page, 720, 62)
    summary:SetPoint("TOPLEFT", 0, -100); summary:SetPoint("RIGHT")
    summary.primary = UI.CreateText(summary, "GameFontHighlight", UI.Theme.colors.text)
    summary.primary:SetPoint("TOPLEFT", 16, -12); summary.primary:SetPoint("RIGHT", -154, 0)
    summary.secondary = UI.CreateText(summary, "GameFontHighlightSmall", UI.Theme.colors.muted)
    summary.secondary:SetPoint("BOTTOMLEFT", 16, 11); summary.secondary:SetPoint("RIGHT", -16, 0)
    page.summary = summary
    page.previous = UI.Button.Create(summary, {
        text = Cortex:GetText("SESSION_PREVIOUS"), width = 62, height = 26, align = "center",
    })
    page.previous:SetPoint("RIGHT", -78, 0)
    page.next = UI.Button.Create(summary, {
        text = Cortex:GetText("SESSION_NEXT"), width = 62, height = 26, align = "center",
    })
    page.next:SetPoint("RIGHT", -10, 0)

    page.list = UI.ScrollList.Create(page, {
        capacity = 6, rowHeight = 48,
        createRow = function(listParent) return createEntryRow(listParent) end,
        updateRow = function(row, entry, index)
            row.number:SetValue(tostring(entry.ordinal or index))
            row.title:SetText(entry.title)
            row.reason:SetText(entry.reason)
            row.duration:SetText(entry.duration)
        end,
    })
    page.list:SetPoint("TOPLEFT", 0, -176); page.list:SetPoint("RIGHT")
    page.empty = UI.CreateText(page, "GameFontHighlight", UI.Theme.colors.muted, "CENTER")
    page.empty:SetPoint("TOP", 0, -224); page.empty:SetText(Cortex:GetText("SESSION_EMPTY")); page.empty:Hide()

    function page:RenderEntries()
        local visible = {}
        for index = 1, 6 do
            local sourceIndex = self.pageOffset + index
            local entry = self.entries[sourceIndex]
            if entry then
                visible[index] = {
                    ordinal = sourceIndex, title = entry.title, reason = entry.reason, duration = entry.duration,
                }
            end
        end
        self.list:SetItems(visible)
        self.previous:SetShown(self.pageOffset > 0)
        self.next:SetShown(self.pageOffset + 6 < #self.entries)
    end
    page.previous:SetScript("OnClick", function()
        page.pageOffset = math.max(0, page.pageOffset - 6); page:RenderEntries()
    end)
    page.next:SetScript("OnClick", function()
        page.pageOffset = math.min(math.max(0, #page.entries - 1), page.pageOffset + 6)
        page:RenderEntries()
    end)

    function page:GetBudget() return self.selectedBudget end
    function page:SetData(data)
        data = type(data) == "table" and data or { entries = {} }
        self.entries = data.entries or {}
        self.pageOffset = math.min(self.pageOffset or 0, math.max(0, #self.entries - 1))
        self.summary.primary:SetText(data.summary or "")
        self.summary.secondary:SetText(data.details or "")
        self:RenderEntries()
        self.empty:SetShown(#self.entries == 0)
    end
    page.entries, page.pageOffset = {}, 0
    page:RenderEntries()
    page:Hide()
    return page
end

UI.SessionPlannerPage = SessionPlannerPage
