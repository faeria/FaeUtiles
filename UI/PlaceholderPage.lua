local _, Cortex = ...
local UI = Cortex.UI

local PlaceholderPage = {}

function PlaceholderPage.Create(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.title = UI.CreateText(page, "GameFontNormalLarge", UI.Theme.colors.text)
    page.title:SetPoint("TOPLEFT")
    page.subtitle = UI.CreateText(page, "GameFontHighlight", UI.Theme.colors.muted)
    page.subtitle:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -8)
    page.card = UI.Card.Create(page, 736, 150)
    page.card:SetPoint("TOPLEFT", 0, -64)
    page.card.label = UI.CreateText(page.card, "GameFontNormalLarge", UI.Theme.colors.text)
    page.card.label:SetPoint("TOPLEFT", 18, -18)
    page.card.message = UI.CreateText(page.card, "GameFontHighlight", UI.Theme.colors.muted)
    page.card.message:SetPoint("TOPLEFT", page.card.label, "BOTTOMLEFT", 0, -12)
    page.card.message:SetPoint("RIGHT", -18, 0)
    function page:SetData(data)
        self.title:SetText(data.title)
        self.subtitle:SetText(data.subtitle)
        self.card.label:SetText(data.cardTitle)
        self.card.message:SetText(data.message)
    end
    return page
end

UI.PlaceholderPage = PlaceholderPage
