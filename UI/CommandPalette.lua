local _, Cortex = ...
local UI = Cortex.UI

local CommandPalette = {
    frame = nil,
    results = {},
    selectedIndex = 1,
    capacity = 8,
}

local function createResultRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row.background = UI.CreateBackground(row, UI.Theme.colors.surface)
    row.accent = row:CreateTexture(nil, "ARTWORK")
    row.accent:SetPoint("TOPLEFT"); row.accent:SetPoint("BOTTOMLEFT"); row.accent:SetWidth(3)
    UI.SetColor(row.accent, UI.Theme.colors.accent)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", 14, 0); row.icon:SetSize(28, 28); row.icon:Hide()
    row.title = UI.CreateText(row, "GameFontHighlight", UI.Theme.colors.text)
    row.title:SetPoint("TOPLEFT", 16, -12); row.title:SetPoint("RIGHT", -112, 0)
    row.subtitle = UI.CreateText(row, "GameFontHighlightSmall", UI.Theme.colors.muted)
    row.subtitle:SetPoint("BOTTOMLEFT", 16, 10); row.subtitle:SetPoint("RIGHT", -112, 0)
    row.badge = UI.Badge.Create(row, 96)
    row.badge:SetPoint("RIGHT", -12, 0)

    function row:SetSelected(selected)
        self.isSelected = selected == true
        UI.SetColor(self.background, self.isSelected and UI.Theme.colors.accentSoft or UI.Theme.colors.surface)
        self.accent:SetShown(self.isSelected)
    end
    row:SetScript("OnEnter", function(self)
        if not self.isSelected then UI.SetColor(self.background, UI.Theme.colors.surfaceHover) end
    end)
    row:SetScript("OnLeave", function(self)
        if not self.isSelected then UI.SetColor(self.background, UI.Theme.colors.surface) end
    end)
    return row
end

function CommandPalette:Initialize()
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.GOALS_CHANGED, self, self.RefreshIfVisible)
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.RECOMMENDATIONS_INVALIDATED, self, self.RefreshIfVisible)
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.MODULE_STATE_CHANGED, self, self.RefreshIfVisible)
end

function CommandPalette:Create()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(640, 568)
    frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    UI.CreateBackground(frame, UI.Theme.colors.window)
    UI.CreateBorder(frame, UI.Theme.colors.border)

    local title = UI.CreateText(frame, "GameFontNormalLarge", UI.Theme.colors.text)
    title:SetPoint("TOPLEFT", 20, -18); title:SetText(Cortex:GetText("PALETTE_TITLE"))
    local hint = UI.CreateText(frame, "GameFontHighlightSmall", UI.Theme.colors.muted)
    hint:SetPoint("TOPRIGHT", -20, -22); hint:SetText(Cortex:GetText("PALETTE_HINT"))

    local searchSurface = CreateFrame("Frame", nil, frame)
    searchSurface:SetPoint("TOPLEFT", 16, -52); searchSurface:SetPoint("TOPRIGHT", -16, -52)
    searchSurface:SetHeight(54)
    UI.CreateBackground(searchSurface, UI.Theme.colors.surface)
    UI.CreateBorder(searchSurface, UI.Theme.colors.border)
    local prompt = UI.CreateText(searchSurface, "GameFontNormalLarge", UI.Theme.colors.accent)
    prompt:SetPoint("LEFT", 16, 0); prompt:SetText(">")
    local editBox = CreateFrame("EditBox", nil, searchSurface)
    editBox:SetPoint("LEFT", 42, 0); editBox:SetPoint("RIGHT", -12, 0); editBox:SetHeight(38)
    editBox:SetAutoFocus(false); editBox:SetFontObject(GameFontHighlight)
    editBox:SetTextInsets(0, 0, 0, 0); editBox:SetMaxLetters(80)
    local placeholder = UI.CreateText(searchSurface, "GameFontHighlight", UI.Theme.colors.muted)
    placeholder:SetPoint("LEFT", 42, 0); placeholder:SetText(Cortex:GetText("PALETTE_PLACEHOLDER"))
    self.searchBox, self.placeholder = editBox, placeholder

    local noResults = UI.CreateText(frame, "GameFontHighlight", UI.Theme.colors.muted, "CENTER")
    noResults:SetPoint("TOP", 0, -156); noResults:SetText(Cortex:GetText("PALETTE_NO_RESULTS")); noResults:Hide()
    self.noResults = noResults

    local list = UI.ScrollList.Create(frame, {
        capacity = self.capacity, rowHeight = 48,
        createRow = function(parent)
            local row = createResultRow(parent)
            row:SetScript("OnClick", function(owner) self:ExecuteIndex(owner.resultIndex) end)
            return row
        end,
        updateRow = function(row, result, index)
            row.resultIndex = index
            row.title:SetText(result.title)
            row.subtitle:SetText(result.subtitle or "")
            row.badge:SetValue(result.type)
            if result.icon then
                row.icon:SetTexture(result.icon); row.icon:Show()
                row.title:ClearAllPoints(); row.title:SetPoint("TOPLEFT", 54, -12); row.title:SetPoint("RIGHT", -112, 0)
                row.subtitle:ClearAllPoints(); row.subtitle:SetPoint("BOTTOMLEFT", 54, 10); row.subtitle:SetPoint("RIGHT", -112, 0)
            else
                row.icon:Hide()
                row.title:ClearAllPoints(); row.title:SetPoint("TOPLEFT", 16, -12); row.title:SetPoint("RIGHT", -112, 0)
                row.subtitle:ClearAllPoints(); row.subtitle:SetPoint("BOTTOMLEFT", 16, 10); row.subtitle:SetPoint("RIGHT", -112, 0)
            end
            row:SetSelected(index == self.selectedIndex)
        end,
    })
    list:SetPoint("TOPLEFT", 16, -118); list:SetPoint("TOPRIGHT", -16, -118)
    self.list = list

    editBox:SetScript("OnTextChanged", function(owner)
        placeholder:SetShown(owner:GetText() == "")
        self:RefreshResults()
    end)
    editBox:SetScript("OnArrowPressed", function(_, key)
        if key == "UP" then self:MoveSelection(-1) elseif key == "DOWN" then self:MoveSelection(1) end
    end)
    editBox:SetScript("OnEnterPressed", function() self:ExecuteSelected() end)
    editBox:SetScript("OnEscapePressed", function() self:Hide() end)
    frame:SetScript("OnShow", function()
        editBox:SetText(""); self.selectedIndex = 1; self:RefreshResults(); editBox:SetFocus()
    end)
    frame:SetScript("OnHide", function() editBox:ClearFocus() end)
    frame:Hide()
    self.frame = frame
    return frame
end

function CommandPalette:RefreshResults()
    local profiler = Cortex:GetService("Profiler")
    local startedAt = profiler:Start()
    self.results = Cortex:GetService("Search"):Search(self.searchBox:GetText(), self.capacity)
    if #self.results == 0 then self.selectedIndex = 0
    elseif self.selectedIndex < 1 or self.selectedIndex > #self.results then self.selectedIndex = 1 end
    self.list:SetItems(self.results)
    self.noResults:SetShown(#self.results == 0)
    profiler:Stop("ui", "command-palette", startedAt)
end

function CommandPalette:RefreshIfVisible()
    if self.frame and self.frame:IsShown() then self:RefreshResults() end
end

function CommandPalette:MoveSelection(delta)
    if #self.results == 0 then return false end
    self.selectedIndex = ((self.selectedIndex - 1 + delta) % #self.results) + 1
    self.list:SetItems(self.results)
    return true
end

function CommandPalette:ExecuteIndex(index)
    local result = self.results[index]
    if not result then return false end
    self:Hide()
    return Cortex:GetService("Search"):Execute(result)
end

function CommandPalette:ExecuteSelected() return self:ExecuteIndex(self.selectedIndex) end
function CommandPalette:Show() self:Create():Show() end
function CommandPalette:Hide() if self.frame then self.frame:Hide() end end
function CommandPalette:Toggle()
    local frame = self:Create()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

Cortex:RegisterService("CommandPalette", CommandPalette, {
    services = { "Profiler", "Search", "MainWindow", "Events" },
})
