local _, Cortex = ...
local UI = Cortex.UI

local Button = {}

function Button.Create(parent, options)
    options = options or {}
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(options.width or 120, options.height or 30)
    button.background = UI.CreateBackground(button, UI.Theme.colors.surface)
    button.accent = button:CreateTexture(nil, "ARTWORK")
    button.accent:SetPoint("TOPLEFT"); button.accent:SetPoint("BOTTOMLEFT"); button.accent:SetWidth(2)
    UI.SetColor(button.accent, UI.Theme.colors.accent)
    button.accent:Hide()
    button.label = UI.CreateText(button, options.font or "GameFontHighlight", UI.Theme.colors.text)
    button.label:SetPoint(options.align == "center" and "CENTER" or "LEFT", options.align == "center" and 0 or 12, 0)
    button.label:SetText(options.text or "")
    button.isActive = false

    function button:SetLabel(text) self.label:SetText(text or "") end
    function button:SetActive(isActive)
        self.isActive = isActive == true
        UI.SetColor(self.background, self.isActive and UI.Theme.colors.accentSoft or UI.Theme.colors.surface)
        self.accent:SetShown(self.isActive)
    end
    button:SetScript("OnEnter", function(self)
        if not self.isActive then UI.SetColor(self.background, UI.Theme.colors.surfaceHover) end
    end)
    button:SetScript("OnLeave", function(self)
        if not self.isActive then UI.SetColor(self.background, UI.Theme.colors.surface) end
    end)
    return button
end

UI.Button = Button
