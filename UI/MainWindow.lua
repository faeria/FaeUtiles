local _, Cortex = ...

local MainWindow = {
    frame = nil,
}

local function createTextButton(parent, text)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(72, 24)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.16, 0.20, 0.26, 1)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER")
    label:SetText(text)
    button.label = label
    return button
end

function MainWindow:Initialize()
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.CONTEXT_UPDATED, self, self.RefreshIfVisible)
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.GOALS_CHANGED, self, self.RefreshIfVisible)
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.COMBAT_LOCKDOWN_CHANGED, self, self.RefreshIfVisible)
end

function MainWindow:Create()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(420, 220)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:Hide()

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.025, 0.035, 0.055, 0.96)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -18)
    title:SetText(Cortex:GetText("WINDOW_TITLE"))

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(Cortex:GetText("WINDOW_SUBTITLE"))

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -28)
    status:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    status:SetJustifyH("LEFT")
    frame.status = status

    local combatNotice = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    combatNotice:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -16)
    combatNotice:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    combatNotice:SetJustifyH("LEFT")
    frame.combatNotice = combatNotice

    local closeButton = createTextButton(frame, Cortex:GetText("WINDOW_CLOSE"))
    closeButton:SetPoint("BOTTOMRIGHT", -16, 14)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame:SetScript("OnShow", function()
        self:Refresh()
    end)

    self.frame = frame
    return frame
end

function MainWindow:RefreshIfVisible()
    if self.frame and self.frame:IsShown() then
        self:Refresh()
    end
end

function MainWindow:Refresh()
    local frame = self:Create()
    local goals = Cortex:GetModule("Goals")
    local goalCount = Cortex:IsModuleEnabled("Goals") and goals:GetActiveCount() or 0
    local characterCount = Cortex:GetService("Context"):GetKnownCharacterCount()
    frame.status:SetText(Cortex:GetText("WINDOW_STATUS", Cortex.version, goalCount, characterCount))
    frame.combatNotice:SetText(Cortex:IsInCombatLockdown() and Cortex:GetText("WINDOW_COMBAT_NOTICE") or "")
end

function MainWindow:Show()
    self:Create():Show()
end

function MainWindow:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function MainWindow:Toggle()
    local frame = self:Create()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

Cortex:RegisterService("MainWindow", MainWindow, {
    services = { "Events", "Context", "Navigation" },
    modules = { "Goals" },
})
