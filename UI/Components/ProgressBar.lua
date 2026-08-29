local _, Cortex = ...
local UI = Cortex.UI

local ProgressBar = {}

function ProgressBar.Create(parent, width, height)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width or 280, height or 18)
    container.background = UI.CreateBackground(container, UI.Theme.colors.sidebar)
    container.bar = CreateFrame("StatusBar", nil, container)
    container.bar:SetAllPoints()
    container.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    container.bar:SetStatusBarColor(UI.Theme.colors.accent[1], UI.Theme.colors.accent[2], UI.Theme.colors.accent[3], 1)
    container.bar:SetMinMaxValues(0, 1)
    container.label = UI.CreateText(container, "GameFontHighlightSmall", UI.Theme.colors.text, "CENTER")
    container.label:SetPoint("CENTER")
    function container:SetProgress(current, total, label)
        current = type(current) == "number" and current or 0
        total = type(total) == "number" and total > 0 and total or 1
        self.bar:SetMinMaxValues(0, total)
        self.bar:SetValue(math.max(0, math.min(total, current)))
        self.label:SetText(label or (current .. " / " .. total))
    end
    return container
end

UI.ProgressBar = ProgressBar
