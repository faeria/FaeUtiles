local _, Cortex = ...
local UI = Cortex.UI

local Badge = {}

function Badge.Create(parent, width)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetSize(width or 88, 20)
    badge.background = UI.CreateBackground(badge, UI.Theme.colors.accentSoft)
    badge.label = UI.CreateText(badge, "GameFontHighlightSmall", UI.Theme.colors.text, "CENTER")
    badge.label:SetPoint("CENTER")
    function badge:SetValue(text, tone)
        self.label:SetText(text or "")
        UI.SetColor(self.background, tone or UI.Theme.colors.accentSoft)
    end
    return badge
end

UI.Badge = Badge
