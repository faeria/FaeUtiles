local _, Cortex = ...
local Utils = Cortex.CollectorUtils

local WarbandCollector = {
    dependencies = { "Character", "Currency", "Reputation" },
    requiresOutOfCombat = true,
}

function WarbandCollector:Collect(context)
    local account = Cortex:GetService("Database"):GetAccount()
    if type(account) ~= "table" or type(account.characters) ~= "table" then
        return Utils.Unavailable({ "warband" }, "local-history-unavailable")
    end
    local characterCount = 0
    for _ in pairs(account.characters) do characterCount = characterCount + 1 end

    local accountWideCurrencies = {}
    local currencies = context:GetLastKnown("currency.byID") or {}
    if Utils.IsUsableTable(currencies) then
        for currencyID, currency in pairs(currencies) do
            if Utils.IsUsableTable(currency) and Utils.IsAccessible(currency.isAccountWide)
                and currency.isAccountWide then
                accountWideCurrencies[currencyID] = Cortex.Schema.Copy(currency)
            end
        end
    end

    local accountWideReputations = {}
    local reputations = context:GetLastKnown("reputation.byID") or {}
    if Utils.IsUsableTable(reputations) then
        for factionID, faction in pairs(reputations) do
            if Utils.IsUsableTable(faction) and Utils.IsAccessible(faction.isAccountWide)
                and faction.isAccountWide then
                accountWideReputations[factionID] = Cortex.Schema.Copy(faction)
            end
        end
    end

    return { facts = { ["warband"] = {
        characterCount = characterCount,
        accountWideCurrencies = accountWideCurrencies,
        accountWideReputations = accountWideReputations,
    } } }
end

Cortex:RegisterCollector("Warband", WarbandCollector)
