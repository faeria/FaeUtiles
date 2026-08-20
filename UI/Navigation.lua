local _, Cortex = ...

local Navigation = {
    currentPage = "overview",
}

function Navigation:GoTo(page)
    if type(page) ~= "string" or page == "" or page == self.currentPage then
        return false
    end

    self.currentPage = page
    Cortex.Events:Publish(Cortex.Constants.EVENTS.NAVIGATION_CHANGED, page)
    return true
end

function Navigation:GetCurrentPage()
    return self.currentPage
end

Cortex:RegisterService("Navigation", Navigation, { services = { "Events" } })
