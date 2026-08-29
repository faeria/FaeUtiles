local _, Cortex = ...
local UI = Cortex.UI

local OverviewPage = {}

local function createSummaryCard(parent, title)
    local card = UI.Card.Create(parent, 350, 106)
    card.heading = UI.CreateText(card, "GameFontNormal", UI.Theme.colors.muted)
    card.heading:SetPoint("TOPLEFT", 14, -12)
    card.heading:SetText(title)
    card.primary = UI.CreateText(card, "GameFontNormalLarge", UI.Theme.colors.text)
    card.primary:SetPoint("TOPLEFT", 14, -38)
    card.primary:SetPoint("RIGHT", -14, 0)
    card.secondary = UI.CreateText(card, "GameFontHighlightSmall", UI.Theme.colors.muted)
    card.secondary:SetPoint("TOPLEFT", card.primary, "BOTTOMLEFT", 0, -7)
    card.secondary:SetPoint("RIGHT", -14, 0)
    return card
end

local function createRecommendationRow(parent)
    local row = UI.Card.Create(parent, 350, 66)
    row.rank = UI.Badge.Create(row, 30)
    row.rank:SetPoint("LEFT", 10, 0)
    row.title = UI.CreateText(row, "GameFontNormal", UI.Theme.colors.text)
    row.title:SetPoint("TOPLEFT", 50, -10)
    row.title:SetPoint("RIGHT", -76, 0)
    row.reason = UI.CreateText(row, "GameFontHighlightSmall", UI.Theme.colors.muted)
    row.reason:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -5)
    row.reason:SetPoint("RIGHT", -10, 0)
    row.score = UI.Badge.Create(row, 58)
    row.score:SetPoint("TOPRIGHT", -9, -9)
    return row
end

function OverviewPage.Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()

    page.title = UI.CreateText(page, "GameFontNormalLarge", UI.Theme.colors.text)
    page.title:SetPoint("TOPLEFT", 0, -2)
    page.title:SetText(Cortex:GetText("OVERVIEW_TITLE"))
    page.subtitle = UI.CreateText(page, "GameFontHighlight", UI.Theme.colors.muted)
    page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -6)
    page.subtitle:SetText(Cortex:GetText("OVERVIEW_SUBTITLE"))

    page.character = createSummaryCard(page, Cortex:GetText("OVERVIEW_CHARACTER"))
    page.character:SetPoint("TOPLEFT", 0, -64)
    page.character.badge = UI.Badge.Create(page.character, 82)
    page.character.badge:SetPoint("TOPRIGHT", -12, -12)

    page.goal = createSummaryCard(page, Cortex:GetText("OVERVIEW_CURRENT_GOAL"))
    page.goal:SetPoint("TOPLEFT", page.character, "BOTTOMLEFT", 0, -12)
    page.goal.badge = UI.Badge.Create(page.goal, 82)
    page.goal.badge:SetPoint("TOPRIGHT", -12, -12)

    page.weekly = createSummaryCard(page, Cortex:GetText("OVERVIEW_WEEKLY"))
    page.weekly:SetPoint("TOPLEFT", page.goal, "BOTTOMLEFT", 0, -12)
    page.weekly.progress = UI.ProgressBar.Create(page.weekly, 322, 17)
    page.weekly.progress:SetPoint("BOTTOMLEFT", 14, 12)

    page.warband = createSummaryCard(page, Cortex:GetText("OVERVIEW_WARBAND"))
    page.warband:SetPoint("TOPLEFT", page.weekly, "BOTTOMLEFT", 0, -12)

    page.nextAction = UI.Card.Create(page, 370, 232)
    page.nextAction:SetPoint("TOPLEFT", 366, -64)
    page.nextAction.heading = UI.CreateText(page.nextAction, "GameFontNormal", UI.Theme.colors.muted)
    page.nextAction.heading:SetPoint("TOPLEFT", 16, -14)
    page.nextAction.heading:SetText(Cortex:GetText("OVERVIEW_NEXT_ACTION"))
    page.nextAction.badge = UI.Badge.Create(page.nextAction, 90)
    page.nextAction.badge:SetPoint("TOPRIGHT", -14, -12)
    page.nextAction.title = UI.CreateText(page.nextAction, "GameFontNormalLarge", UI.Theme.colors.text)
    page.nextAction.title:SetPoint("TOPLEFT", 16, -43)
    page.nextAction.title:SetPoint("RIGHT", -16, 0)
    page.nextAction.description = UI.CreateText(page.nextAction, "GameFontHighlightSmall", UI.Theme.colors.muted)
    page.nextAction.description:SetPoint("TOPLEFT", page.nextAction.title, "BOTTOMLEFT", 0, -8)
    page.nextAction.description:SetPoint("RIGHT", -16, 0)
    page.nextAction.description:SetHeight(30)
    page.nextAction.reason = UI.CreateText(page.nextAction, "GameFontHighlightSmall", UI.Theme.colors.text)
    page.nextAction.reason:SetPoint("TOPLEFT", page.nextAction.description, "BOTTOMLEFT", 0, -5)
    page.nextAction.reason:SetPoint("RIGHT", -16, 0)
    page.nextAction.reason:SetHeight(28)
    page.nextAction.meta = UI.CreateText(page.nextAction, "GameFontHighlightSmall", UI.Theme.colors.text)
    page.nextAction.meta:SetPoint("TOPLEFT", page.nextAction.reason, "BOTTOMLEFT", 0, -5)
    page.nextAction.meta:SetPoint("RIGHT", -16, 0)
    page.nextAction.why = UI.Button.Create(page.nextAction, {
        text = Cortex:GetText("OVERVIEW_WHY"), width = 72, height = 26, align = "center",
    })
    page.nextAction.why:SetPoint("BOTTOMLEFT", 14, 12)
    page.nextAction.explanation = UI.CreateText(page.nextAction, "GameFontHighlightSmall", UI.Theme.colors.accent)
    page.nextAction.explanation:SetPoint("BOTTOMLEFT", 98, 13)
    page.nextAction.explanation:SetPoint("RIGHT", -14, 0)
    page.nextAction.explanation:SetHeight(42)
    page.nextAction.explanation:Hide()
    page.nextAction.why:SetScript("OnClick", function()
        page.nextAction.explanation:SetShown(not page.nextAction.explanation:IsShown())
    end)

    page.recommendations = UI.Section.Create(page, Cortex:GetText("OVERVIEW_TOP_RECOMMENDATIONS"))
    page.recommendations:SetPoint("TOPLEFT", page.nextAction, "BOTTOMLEFT", 0, -14)
    page.recommendations:SetPoint("BOTTOMRIGHT", 0, 0)
    page.recommendations.list = UI.ScrollList.Create(page.recommendations.content, {
        capacity = 3,
        rowHeight = 66,
        createRow = createRecommendationRow,
        updateRow = function(row, item, index)
            row.rank:SetValue(tostring(index))
            row.title:SetText(item.title)
            row.reason:SetText(item.reason)
            row.score:SetValue(string.format("%.0f", item.score))
        end,
    })
    page.recommendations.list:SetAllPoints()

    function page:SetData(data)
        self.character.primary:SetText(data.character.primary)
        self.character.secondary:SetText(data.character.secondary)
        self.character.badge:SetValue(data.character.badge)

        self.goal.primary:SetText(data.goal.primary)
        self.goal.secondary:SetText(data.goal.secondary)
        self.goal.badge:SetValue(data.goal.badge)

        self.weekly.primary:SetText(data.weekly.primary)
        self.weekly.secondary:SetText(data.weekly.secondary)
        self.weekly.progress:SetProgress(data.weekly.current, data.weekly.total, data.weekly.progressLabel)

        self.warband.primary:SetText(data.warband.primary)
        self.warband.secondary:SetText(data.warband.secondary)

        local recommendation = data.nextAction
        self.nextAction.title:SetText(recommendation.title)
        self.nextAction.description:SetText(recommendation.description)
        self.nextAction.reason:SetText(recommendation.reason)
        self.nextAction.badge:SetValue(recommendation.badge)
        self.nextAction.meta:SetText(recommendation.meta)
        self.nextAction.explanation:SetText(recommendation.why)
        self.nextAction.explanation:Hide()
        self.nextAction.why:SetShown(recommendation.hasRecommendation)
        self.recommendations.list:SetItems(data.recommendations)
    end

    return page
end

UI.OverviewPage = OverviewPage
