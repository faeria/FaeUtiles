local _, Cortex = ...
local UI = Cortex.UI

local ShareCodeDialog = { frame = nil, pendingPreview = nil, suppressTextChange = false }

function ShareCodeDialog:Initialize()
    Cortex:GetService("Commands"):Register({
        id = "sharing.import",
        title = Cortex:GetText("COMMAND_IMPORT_SHARE_CODE"),
        subtitle = Cortex:GetText("COMMAND_IMPORT_SHARE_CODE_SUBTITLE"),
        keywords = { "share", "code", "import", "template", "goal", "session", "tasks" },
        execute = function() self:Show() end,
    })
end

function ShareCodeDialog:ClearPreview(message)
    self.pendingPreview = nil
    Cortex:GetService("ShareCodes"):CancelImport()
    if self.preview then self.preview:SetText(message or Cortex:GetText("SHARE_PREVIEW_REQUIRED")) end
    if self.confirm then self.confirm:SetActive(false) end
end

function ShareCodeDialog:Preview()
    local preview, reason = Cortex:GetService("ShareCodes"):PrepareImport(self.input:GetText())
    if not preview then
        self:ClearPreview(Cortex:GetText("SHARE_IMPORT_REJECTED", reason or "invalid-code"))
        return false
    end
    self.pendingPreview = preview
    self.preview:SetText(Cortex:GetText("SHARE_PREVIEW_VALID", preview.type, preview:GetSummary()))
    self.confirm:SetActive(true)
    return true
end

function ShareCodeDialog:Confirm()
    if not self.pendingPreview then
        self.preview:SetText(Cortex:GetText("SHARE_PREVIEW_REQUIRED"))
        return false
    end
    local imported, reason = Cortex:GetService("ShareCodes"):Confirm(self.pendingPreview)
    self.pendingPreview = nil
    self.confirm:SetActive(false)
    if not imported then
        self.preview:SetText(Cortex:GetText("SHARE_IMPORT_REJECTED", reason or "import-failed"))
        return false
    end
    self.preview:SetText(Cortex:GetText("SHARE_IMPORT_CONFIRMED", imported.id or "—"))
    return true
end

function ShareCodeDialog:Create()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(680, 310)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    UI.CreateBackground(frame, UI.Theme.colors.window)
    UI.CreateBorder(frame, UI.Theme.colors.border)

    local title = UI.CreateText(frame, "GameFontNormalLarge", UI.Theme.colors.text)
    title:SetPoint("TOPLEFT", 20, -18); title:SetText(Cortex:GetText("SHARE_IMPORT_TITLE"))
    local subtitle = UI.CreateText(frame, "GameFontHighlightSmall", UI.Theme.colors.muted)
    subtitle:SetPoint("TOPLEFT", 20, -46); subtitle:SetText(Cortex:GetText("SHARE_IMPORT_SUBTITLE"))

    local inputSurface = CreateFrame("Frame", nil, frame)
    inputSurface:SetPoint("TOPLEFT", 20, -76); inputSurface:SetPoint("TOPRIGHT", -20, -76)
    inputSurface:SetHeight(48)
    UI.CreateBackground(inputSurface, UI.Theme.colors.surface)
    UI.CreateBorder(inputSurface, UI.Theme.colors.border)
    local input = CreateFrame("EditBox", nil, inputSurface)
    input:SetPoint("LEFT", 12, 0); input:SetPoint("RIGHT", -12, 0); input:SetHeight(34)
    input:SetAutoFocus(false); input:SetFontObject(GameFontHighlight)
    input:SetTextInsets(0, 0, 0, 0); input:SetMaxLetters(Cortex.Constants.MAX_SHARE_CODE_BYTES)
    self.input = input

    local previewCard = CreateFrame("Frame", nil, frame)
    previewCard:SetPoint("TOPLEFT", 20, -140); previewCard:SetPoint("TOPRIGHT", -20, -140)
    previewCard:SetHeight(92)
    UI.CreateBackground(previewCard, UI.Theme.colors.surface)
    local previewLabel = UI.CreateText(previewCard, "GameFontNormal", UI.Theme.colors.muted)
    previewLabel:SetPoint("TOPLEFT", 12, -10); previewLabel:SetText(Cortex:GetText("SHARE_PREVIEW_LABEL"))
    local preview = UI.CreateText(previewCard, "GameFontHighlightSmall", UI.Theme.colors.text)
    preview:SetPoint("TOPLEFT", 12, -34); preview:SetPoint("BOTTOMRIGHT", -12, 10)
    preview:SetText(Cortex:GetText("SHARE_PREVIEW_REQUIRED"))
    self.preview = preview

    local cancel = UI.Button.Create(frame, {
        text = Cortex:GetText("SHARE_CANCEL"), width = 90, height = 30, align = "center",
    })
    cancel:SetPoint("BOTTOMLEFT", 20, 18)
    local previewButton = UI.Button.Create(frame, {
        text = Cortex:GetText("SHARE_PREVIEW"), width = 110, height = 30, align = "center",
    })
    previewButton:SetPoint("BOTTOMRIGHT", -140, 18)
    local confirm = UI.Button.Create(frame, {
        text = Cortex:GetText("SHARE_CONFIRM"), width = 110, height = 30, align = "center",
    })
    confirm:SetPoint("BOTTOMRIGHT", -20, 18); confirm:SetActive(false)
    self.confirm = confirm

    input:SetScript("OnTextChanged", function()
        if not self.suppressTextChange then self:ClearPreview() end
    end)
    input:SetScript("OnEnterPressed", function() self:Preview() end)
    input:SetScript("OnEscapePressed", function() self:Hide() end)
    previewButton:SetScript("OnClick", function() self:Preview() end)
    confirm:SetScript("OnClick", function() self:Confirm() end)
    cancel:SetScript("OnClick", function() self:Hide() end)
    frame:SetScript("OnShow", function() input:SetFocus() end)
    frame:SetScript("OnHide", function()
        input:ClearFocus()
        self:ClearPreview()
    end)
    frame:Hide()
    self.frame = frame
    return frame
end

function ShareCodeDialog:Show(code)
    local frame = self:Create()
    self.suppressTextChange = true
    self.input:SetText(type(code) == "string" and code or "")
    self.suppressTextChange = false
    self:ClearPreview()
    frame:Show()
end

function ShareCodeDialog:Hide() if self.frame then self.frame:Hide() end end

Cortex:RegisterService("ShareCodeDialog", ShareCodeDialog, {
    services = { "ShareCodes", "Commands" },
})
