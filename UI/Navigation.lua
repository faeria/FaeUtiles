local _, Cortex = ...

local Navigation = {
    currentPage = "overview",
}

local PAGES = {
    overview = true,
    session = true,
    goals = true,
    weekly = true,
    gear = true,
    warband = true,
}

local PAGE_COMMANDS = {
    { id = "overview", label = "NAV_OVERVIEW", keywords = { "dashboard", "home" } },
    { id = "session", label = "NAV_SESSION", keywords = { "plan", "time", "minutes" } },
    { id = "goals", label = "NAV_GOALS", keywords = { "goal", "objectives" } },
    { id = "weekly", label = "NAV_WEEKLY", keywords = { "vault", "week" } },
    { id = "gear", label = "NAV_GEAR", keywords = { "equipment", "items", "upgrade" } },
    { id = "warband", label = "NAV_WARBAND", keywords = { "characters", "account" } },
}

function Navigation:Initialize()
    local commands = Cortex:GetService("Commands")
    for index = 1, #PAGE_COMMANDS do
        local page = PAGE_COMMANDS[index]
        commands:Register({
            id = "navigation." .. page.id,
            title = Cortex:GetText("COMMAND_OPEN_PAGE", Cortex:GetText(page.label)),
            subtitle = Cortex:GetText("COMMAND_OPEN_PAGE_SUBTITLE"),
            keywords = page.keywords,
            priority = page.id == "overview" and 20 or 10,
            execute = function()
                Navigation:GoTo(page.id)
                Cortex:GetService("MainWindow"):Show()
            end,
        })
    end
end

function Navigation:GoTo(page)
    if type(page) ~= "string" or not PAGES[page] or page == self.currentPage then
        return false
    end

    self.currentPage = page
    Cortex.Events:Publish(Cortex.Constants.EVENTS.NAVIGATION_CHANGED, page)
    return true
end

function Navigation:IsValidPage(page) return PAGES[page] == true end

function Navigation:GetCurrentPage()
    return self.currentPage
end

Cortex:RegisterService("Navigation", Navigation, { services = { "Events", "Commands" } })
