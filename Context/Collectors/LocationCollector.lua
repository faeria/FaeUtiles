local _, Cortex = ...
local Utils = Cortex.CollectorUtils

local LocationCollector = {
    events = { "PLAYER_MAP_CHANGED", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" },
    requiresOutOfCombat = true,
}

local MAP_FIELDS = { "mapID", "name", "mapType", "parentMapID" }

function LocationCollector:Collect()
    if type(C_Map) ~= "table" or type(C_Map.GetBestMapForUnit) ~= "function"
        or type(C_Map.GetMapInfo) ~= "function" then
        return Utils.Unavailable({ "location.current", "location.position" }, "api-unavailable")
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not Utils.IsAccessible(mapID) then
        return Utils.Unavailable({ "location.current", "location.position" }, "map-unavailable-or-restricted")
    end
    local mapInfo = Utils.CopyFields(C_Map.GetMapInfo(mapID), MAP_FIELDS)
    if not mapInfo then
        return Utils.Unavailable({ "location.current", "location.position" }, "map-data-not-ready")
    end
    mapInfo.mapID = mapID
    local facts, unavailable = { ["location.current"] = mapInfo }, {}
    if type(C_Map.GetPlayerMapPosition) == "function" then
        local position = C_Map.GetPlayerMapPosition(mapID, "player")
        if Utils.IsUsableTable(position) and type(position.GetXY) == "function" then
            local ok, x, y = Utils.Call(position.GetXY, position)
            if ok and Utils.IsAccessible(x) and Utils.IsAccessible(y) then
                facts["location.position"] = { x = x, y = y, mapID = mapID }
            else
                unavailable["location.position"] = "position-restricted"
            end
        else
            unavailable["location.position"] = "position-unavailable"
        end
    else
        unavailable["location.position"] = "api-unavailable"
    end
    return { facts = facts, unavailable = unavailable }
end

Cortex:RegisterCollector("Location", LocationCollector)
