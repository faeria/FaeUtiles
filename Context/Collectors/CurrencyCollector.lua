local _, Cortex = ...
local Utils = Cortex.CollectorUtils

local CurrencyCollector = {
    events = { "CURRENCY_DISPLAY_UPDATE" },
    requiresOutOfCombat = true,
}

local CURRENCY_FIELDS = { "name", "currencyID", "quantity", "maxQuantity", "quantityEarnedThisWeek",
    "maxWeeklyQuantity", "discovered", "isAccountWide", "isAccountTransferable", "iconFileID" }

local function copyCurrency(info)
    local copy = Utils.CopyFields(info, CURRENCY_FIELDS)
    if not copy or not Utils.IsAccessible(copy.currencyID) then return nil end
    return copy
end

function CurrencyCollector:Collect(context, event, currencyType)
    if type(C_CurrencyInfo) ~= "table" then
        return Utils.Unavailable({ "currency.byID", "currency.count" }, "api-unavailable")
    end

    if event == "CURRENCY_DISPLAY_UPDATE" and Utils.IsAccessible(currencyType)
        and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
        local byId = Cortex.Schema.Copy(context:GetLastKnown("currency.byID") or {})
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyType)
        local copy = copyCurrency(info)
        if not copy then
            return Utils.Unavailable({ "currency.byID", "currency.count" }, "currency-data-not-ready-or-restricted")
        end
        byId[copy.currencyID] = copy
        local count = 0
        for _ in pairs(byId) do count = count + 1 end
        return { facts = { ["currency.byID"] = byId, ["currency.count"] = count }, replace = false }
    end

    if type(C_CurrencyInfo.GetCurrencyListSize) ~= "function"
        or type(C_CurrencyInfo.GetCurrencyListInfo) ~= "function" then
        return Utils.Unavailable({ "currency.byID", "currency.count" }, "api-unavailable")
    end
    local size = C_CurrencyInfo.GetCurrencyListSize()
    if not Utils.IsAccessible(size) then
        return Utils.Unavailable({ "currency.byID", "currency.count" }, "restricted-or-not-ready")
    end
    local byId, count = {}, 0
    for index = 1, size do
        local info = C_CurrencyInfo.GetCurrencyListInfo(index)
        if Utils.IsUsableTable(info) then
            local isHeader = info.isHeader
            if Utils.IsAccessible(isHeader) and not isHeader then
                local copy = copyCurrency(info)
                if copy then byId[copy.currencyID], count = copy, count + 1 end
            end
        end
    end
    return { facts = { ["currency.byID"] = byId, ["currency.count"] = count } }
end

Cortex:RegisterCollector("Currency", CurrencyCollector)
