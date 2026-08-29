local _, Cortex = ...
local UI = Cortex.UI

local Card = {}

function Card.Create(parent, width, height)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(width or 320, height or 120)
    card.background = UI.CreateBackground(card, UI.Theme.colors.surface)
    card.border = UI.CreateBorder(card, UI.Theme.colors.border)
    return card
end

UI.Card = Card
