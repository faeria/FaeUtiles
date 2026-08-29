local _, Cortex = ...
local UI = Cortex.UI

local MainWindow = { frame = nil, pages = {}, sidebarButtons = {} }

local PAGE_ORDER = {
    { id = "overview", label = "NAV_OVERVIEW" },
    { id = "session", label = "NAV_SESSION" },
    { id = "goals", label = "NAV_GOALS" },
    { id = "weekly", label = "NAV_WEEKLY" },
    { id = "gear", label = "NAV_GEAR" },
    { id = "warband", label = "NAV_WARBAND" },
}

local function countTable(values)
    local count = 0
    for _ in pairs(type(values) == "table" and values or {}) do count = count + 1 end
    return count
end

local function findCurrentGoal(goals, recommendations)
    for index = 1, #recommendations do
        local goal = recommendations[index].goalId and goals:GetGoal(recommendations[index].goalId)
        if goal and Cortex.Goal.IsOpen(goal) then return goal end
    end
    for _, goal in ipairs(goals:GetGoals()) do if Cortex.Goal.IsOpen(goal) then return goal end end
    return nil
end

local function findWeeklyGoal(goals)
    for _, goal in ipairs(goals:GetGoals()) do
        if goal.type == "WEEKLY_COMPLETION" and Cortex.Goal.IsOpen(goal) then return goal end
    end
    return nil
end

local function buildRecommendationView(recommendation)
    if not recommendation then
        return {
            hasRecommendation = false,
            title = Cortex:GetText("OVERVIEW_NO_ACTION_TITLE"),
            description = Cortex:GetText("OVERVIEW_NO_ACTION_DESCRIPTION"),
            reason = Cortex:GetText("OVERVIEW_NO_ACTION_REASON"),
            badge = Cortex:GetText("OVERVIEW_IDLE"),
            meta = Cortex:GetText("OVERVIEW_NO_ACTION_META"),
            why = "",
        }
    end
    local metadata = recommendation.metadata or {}
    local explanation = Cortex:GetService("Detective"):ExplainRecommendation(recommendation)
    local parts = { Cortex:GetText("OVERVIEW_PRIORITY", recommendation.priority) }
    if recommendation.benefit and recommendation.benefit ~= "" then
        parts[#parts + 1] = Cortex:GetText("OVERVIEW_BENEFIT", recommendation.benefit)
    end
    if type(metadata.costLabel) == "string" and metadata.costLabel ~= "" then
        parts[#parts + 1] = Cortex:GetText("OVERVIEW_COST", metadata.costLabel)
    end
    if type(recommendation.estimatedMinutes) == "number" then
        parts[#parts + 1] = Cortex:GetText("OVERVIEW_TIME", recommendation.estimatedMinutes)
    end
    return {
        hasRecommendation = true,
        title = recommendation.title,
        description = Cortex:GetText("OVERVIEW_DETAILS", recommendation.description),
        reason = Cortex:GetText("OVERVIEW_REASON", recommendation:GetReason()),
        badge = recommendation.category,
        meta = table.concat(parts, "  •  "),
        why = explanation:GetText("SUMMARY"),
    }
end

function MainWindow:Initialize()
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.RECOMMENDATIONS_INVALIDATED,
        self, self.OnRecommendationsInvalidated)
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.COMBAT_LOCKDOWN_CHANGED,
        self, self.OnCombatLockdownChanged)
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.CONTEXT_UPDATED, self, self.OnContextUpdated)
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.NAVIGATION_CHANGED, self, self.OnNavigationChanged)
    Cortex.Events:Subscribe(Cortex.Constants.EVENTS.WARBAND_UPDATED, self, self.OnWarbandUpdated)
end

function MainWindow:ApplyPlacement(frame)
    local placement = Cortex:GetService("Database"):GetWindowPlacement()
    frame:ClearAllPoints()
    frame:SetPoint(placement.point, UIParent, placement.relativePoint, placement.x, placement.y)
    frame:SetScale(placement.scale)
end

function MainWindow:SavePlacement()
    if not self.frame then return false end
    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    return Cortex:GetService("Database"):SetWindowPlacement({
        point = point, relativePoint = relativePoint, x = x, y = y, scale = self.frame:GetScale(),
    })
end

function MainWindow:SetScale(scale)
    if type(scale) ~= "number" then return false end
    local frame = self:Create()
    frame:SetScale(math.max(0.75, math.min(1.25, scale)))
    return self:SavePlacement()
end

function MainWindow:CreateSidebar(frame)
    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetPoint("TOPLEFT", 0, -64)
    sidebar:SetPoint("BOTTOMLEFT", 0, 32)
    sidebar:SetWidth(180)
    UI.CreateBackground(sidebar, UI.Theme.colors.sidebar)
    local label = UI.CreateText(sidebar, "GameFontHighlightSmall", UI.Theme.colors.muted)
    label:SetPoint("TOPLEFT", 18, -20)
    label:SetText(Cortex:GetText("NAV_WORKSPACE"))
    for index = 1, #PAGE_ORDER do
        local pageInfo = PAGE_ORDER[index]
        local button = UI.Button.Create(sidebar, {
            text = Cortex:GetText(pageInfo.label), width = 148, height = 34,
        })
        button:SetPoint("TOPLEFT", 16, -42 - ((index - 1) * 42))
        button:SetScript("OnClick", function() Cortex:GetService("Navigation"):GoTo(pageInfo.id) end)
        self.sidebarButtons[pageInfo.id] = button
    end
end

function MainWindow:CreatePages(content)
    self.pages.overview = UI.OverviewPage.Create(content)
    self.pages.session = UI.SessionPlannerPage.Create(content, function() self:RefreshPageIfVisible("session") end)
    self.pages.warband = UI.WarbandPage.Create(content)
    for index = 3, #PAGE_ORDER do
        local pageInfo = PAGE_ORDER[index]
        if pageInfo.id ~= "warband" then self.pages[pageInfo.id] = UI.PlaceholderPage.Create(content) end
    end
end

local function formatCachedAge(ageSeconds)
    if type(ageSeconds) ~= "number" then return Cortex:GetText("WARBAND_STATUS_CACHED") end
    if ageSeconds < 3600 then
        return Cortex:GetText("WARBAND_STATUS_CACHED_MINUTES", math.max(1, math.floor(ageSeconds / 60)))
    elseif ageSeconds < 86400 then
        return Cortex:GetText("WARBAND_STATUS_CACHED_HOURS", math.floor(ageSeconds / 3600))
    end
    return Cortex:GetText("WARBAND_STATUS_CACHED_DAYS", math.floor(ageSeconds / 86400))
end

local function formatWarbandFieldState(state)
    return Cortex:GetText("WARBAND_FIELD_" .. (state or "UNKNOWN"))
end

function MainWindow:BuildWarbandViewModel()
    local overview = Cortex:GetModule("Warband"):GetOverview()
    local characters, insights = {}, {}
    for index = 1, #overview.characters do
        local character = overview.characters[index]
        local itemLevel = character.fields.itemLevel.value
        local title = itemLevel and Cortex:GetText("WARBAND_CHARACTER_TITLE",
            character.name or "?", math.floor(itemLevel + 0.5))
            or Cortex:GetText("WARBAND_CHARACTER_TITLE_UNKNOWN", character.name or "?")
        local professionNames = character.capabilities.professionNames
        local professionText = character.fields.professions.state == "UNKNOWN"
            and Cortex:GetText("WARBAND_PROFESSIONS_UNKNOWN")
            or (#professionNames > 0 and table.concat(professionNames, ", ")
                or Cortex:GetText("WARBAND_NO_PROFESSIONS"))
        characters[index] = {
            title = title,
            details = Cortex:GetText("WARBAND_CHARACTER_DETAILS", character.level or 0,
                character.classFile or "?", character.realm or "?",
                formatWarbandFieldState(character.fields.itemLevel.state)),
            capabilities = professionText,
            status = character.state == "LIVE" and Cortex:GetText("WARBAND_STATUS_LIVE")
                or (character.state == "CACHED" and formatCachedAge(character.ageSeconds)
                    or Cortex:GetText("WARBAND_STATUS_UNKNOWN")),
        }
    end
    for index = 1, #overview.insights do
        local insight = overview.insights[index]
        insights[index] = {
            title = Cortex:GetText("WARBAND_INSIGHT_TITLE", insight.characterName or "?", insight.professionName),
            reason = insight.reason,
        }
    end
    return {
        characters = characters,
        insights = insights,
        summary = Cortex:GetText("WARBAND_SUMMARY", #characters, overview.counts.LIVE,
            overview.counts.CACHED, overview.counts.UNKNOWN),
    }
end

function MainWindow:BuildSessionViewModel()
    local plan = Cortex:GetModule("Planner"):Build(self.pages.session:GetBudget())
    local entries = {}
    for index = 1, #plan do
        local entry = plan[index]
        entries[index] = {
            title = entry.title,
            reason = entry:GetReason(),
            duration = Cortex:GetText("SESSION_DURATION_ESTIMATE", entry.estimatedMinutes),
        }
    end
    local budgetLabel = plan.isUnlimited and Cortex:GetText("SESSION_BUDGET_UNLIMITED")
        or Cortex:GetText("SESSION_BUDGET_MINUTES", plan.budgetMinutes)
    local details
    if plan.isUnlimited then
        details = Cortex:GetText("SESSION_SUMMARY_UNLIMITED", #plan)
    else
        details = Cortex:GetText("SESSION_SUMMARY_REMAINING", plan.remainingMinutes, #plan)
    end
    return {
        entries = entries,
        summary = Cortex:GetText("SESSION_SUMMARY", budgetLabel, plan.estimatedMinutes),
        details = details,
    }
end

function MainWindow:Create()
    if self.frame then return self.frame end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(980, 650)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    UI.CreateBackground(frame, UI.Theme.colors.window)
    UI.CreateBorder(frame, UI.Theme.colors.border)
    self:ApplyPlacement(frame)

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(64)
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); self:SavePlacement() end)
    local logo = UI.Badge.Create(header, 38)
    logo:SetPoint("LEFT", 16, 0); logo:SetValue("C")
    local title = UI.CreateText(header, "GameFontNormalLarge", UI.Theme.colors.text)
    title:SetPoint("TOPLEFT", 66, -14); title:SetText(Cortex:GetText("WINDOW_TITLE"))
    local subtitle = UI.CreateText(header, "GameFontHighlightSmall", UI.Theme.colors.muted)
    subtitle:SetPoint("TOPLEFT", 66, -38); subtitle:SetText(Cortex:GetText("WINDOW_SUBTITLE"))
    local close = UI.Button.Create(header, {
        text = Cortex:GetText("WINDOW_CLOSE_SHORT"), width = 32, height = 30, align = "center",
    })
    close:SetPoint("RIGHT", -16, 0); close:SetScript("OnClick", function() frame:Hide() end)

    self:CreateSidebar(frame)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 204, -82); content:SetPoint("BOTTOMRIGHT", -20, 46)
    self.content = content
    self:CreatePages(content)

    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT"); footer:SetHeight(32)
    UI.CreateBackground(footer, UI.Theme.colors.sidebar)
    footer.status = UI.CreateText(footer, "GameFontHighlightSmall", UI.Theme.colors.muted)
    footer.status:SetPoint("LEFT", 16, 0)
    footer.combat = UI.CreateText(footer, "GameFontHighlightSmall", UI.Theme.colors.warning)
    footer.combat:SetPoint("RIGHT", -16, 0)
    self.footer = footer

    frame:SetScript("OnKeyDown", function(owner, key)
        owner:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then owner:Hide() end
    end)
    frame:SetScript("OnShow", function(owner)
        owner:EnableKeyboard(true)
        self:Refresh()
    end)
    frame:SetScript("OnHide", function(owner)
        owner:EnableKeyboard(false); owner:SetPropagateKeyboardInput(true)
    end)
    frame:Hide()
    self.frame = frame
    return frame
end

function MainWindow:BuildOverviewViewModel()
    local context, goals = Cortex:GetService("Context"), Cortex:GetModule("Goals")
    local recommendations = Cortex:GetModule("Recommendations"):GetRecommendations()
    local character, itemLevel = context:Get("character.current"), context:Get("character.itemLevel")
    local currentGoal, weeklyGoal = findCurrentGoal(goals, recommendations), findWeeklyGoal(goals)
    local warband, top = context:Get("warband"), {}
    for index = 1, math.min(3, #recommendations) do
        top[index] = {
            title = recommendations[index].title,
            reason = recommendations[index]:GetReason(),
            score = recommendations[index].score,
        }
    end
    local weeklyCurrent, weeklyTotal = weeklyGoal and weeklyGoal.progress.current or 0,
        weeklyGoal and weeklyGoal.progress.total or 1
    return {
        character = {
            primary = character and character.name or Cortex:GetText("UI_UNAVAILABLE"),
            secondary = character and Cortex:GetText("OVERVIEW_CHARACTER_DETAILS",
                character.level or 0, character.classFile or "?", character.realm or "?")
                or Cortex:GetText("OVERVIEW_DATA_PENDING"),
            badge = itemLevel and Cortex:GetText("OVERVIEW_ITEM_LEVEL", math.floor(itemLevel + 0.5))
                or Cortex:GetText("OVERVIEW_ITEM_LEVEL_UNKNOWN"),
        },
        goal = {
            primary = currentGoal and currentGoal.title or Cortex:GetText("OVERVIEW_NO_GOAL"),
            secondary = currentGoal and (currentGoal.description ~= "" and currentGoal.description
                or Cortex:GetText("OVERVIEW_GOAL_STATUS", currentGoal.status))
                or Cortex:GetText("OVERVIEW_NO_GOAL_DESCRIPTION"),
            badge = currentGoal and currentGoal.status or Cortex:GetText("OVERVIEW_IDLE"),
        },
        weekly = {
            primary = weeklyGoal and weeklyGoal.title or Cortex:GetText("OVERVIEW_WEEKLY_NOT_TRACKED"),
            secondary = weeklyGoal and Cortex:GetText("OVERVIEW_WEEKLY_STATUS", weeklyGoal.progress.availability)
                or Cortex:GetText("OVERVIEW_WEEKLY_HINT"),
            current = weeklyCurrent, total = weeklyTotal,
            progressLabel = Cortex:GetText("OVERVIEW_PROGRESS", weeklyCurrent, weeklyTotal),
        },
        warband = {
            primary = Cortex:GetText("OVERVIEW_WARBAND_CHARACTERS",
                warband and warband.characterCount or context:GetKnownCharacterCount()),
            secondary = warband and Cortex:GetText("OVERVIEW_WARBAND_DETAILS",
                countTable(warband.accountWideCurrencies), countTable(warband.accountWideReputations))
                or Cortex:GetText("OVERVIEW_DATA_PENDING"),
        },
        nextAction = buildRecommendationView(recommendations[1]),
        recommendations = top,
    }
end

function MainWindow:BuildPlaceholderViewModel(pageId)
    return {
        title = Cortex:GetText("PAGE_" .. string.upper(pageId) .. "_TITLE"),
        subtitle = Cortex:GetText("PAGE_PLACEHOLDER_SUBTITLE"),
        cardTitle = Cortex:GetText("PAGE_FOUNDATION_READY"),
        message = Cortex:GetText("PAGE_PLACEHOLDER_MESSAGE"),
    }
end

function MainWindow:ShowPage(pageId)
    local profiler = Cortex:GetService("Profiler")
    local startedAt = profiler:Start()
    if not Cortex:GetService("Navigation"):IsValidPage(pageId) then pageId = "overview" end
    for id, page in pairs(self.pages) do page:SetShown(id == pageId) end
    for id, button in pairs(self.sidebarButtons) do button:SetActive(id == pageId) end
    if pageId == "overview" then
        self.pages.overview:SetData(self:BuildOverviewViewModel())
    elseif pageId == "session" then
        self.pages.session:SetData(self:BuildSessionViewModel())
    elseif pageId == "warband" then
        self.pages.warband:SetData(self:BuildWarbandViewModel())
    else
        self.pages[pageId]:SetData(self:BuildPlaceholderViewModel(pageId))
    end
    profiler:Stop("ui", "page:" .. pageId, startedAt)
end

function MainWindow:OnNavigationChanged(pageId)
    if self.frame and self.frame:IsShown() then self:ShowPage(pageId) end
end
function MainWindow:RefreshPageIfVisible(pageId)
    if self.frame and self.frame:IsShown()
        and Cortex:GetService("Navigation"):GetCurrentPage() == pageId then self:Refresh() end
end
function MainWindow:OnRecommendationsInvalidated()
    local pageId = Cortex:GetService("Navigation"):GetCurrentPage()
    if pageId == "overview" or pageId == "session" then self:RefreshPageIfVisible(pageId) end
end
function MainWindow:OnCombatLockdownChanged()
    if self.frame and self.frame:IsShown() then self:RefreshFooter() end
end
function MainWindow:OnContextUpdated(source)
    if source == "Warband" then
        self:RefreshPageIfVisible("overview")
    elseif source == "Location" then
        self:RefreshPageIfVisible("session")
    end
end
function MainWindow:OnWarbandUpdated(_, reason)
    self:RefreshPageIfVisible("warband")
    if reason == "Character" then self:RefreshPageIfVisible("overview") end
end
function MainWindow:RefreshFooter()
    self.footer.status:SetText(Cortex:GetText("WINDOW_STATUS", Cortex.version,
        Cortex:GetModule("Goals"):GetActiveCount(), Cortex:GetService("Context"):GetKnownCharacterCount()))
    self.footer.combat:SetText(Cortex:IsInCombatLockdown() and Cortex:GetText("WINDOW_COMBAT_NOTICE") or "")
end
function MainWindow:Refresh()
    local profiler = Cortex:GetService("Profiler")
    local startedAt = profiler:Start()
    self:Create()
    self:ShowPage(Cortex:GetService("Navigation"):GetCurrentPage())
    self:RefreshFooter()
    profiler:Stop("ui", "main-refresh", startedAt)
end
function MainWindow:Show() self:Create():Show() end
function MainWindow:Hide() if self.frame then self.frame:Hide() end end
function MainWindow:Toggle()
    local frame = self:Create()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

Cortex:RegisterService("MainWindow", MainWindow, {
    services = { "Profiler", "Events", "Context", "Navigation", "Database", "Detective" },
    modules = { "Goals", "Recommendations", "Planner", "Warband" },
})
