local _, Cortex = ...
local Utils = Cortex.CollectorUtils

local CharacterCollector = {
    events = { "PLAYER_LEVEL_UP" },
    requiresOutOfCombat = true,
}

function CharacterCollector:Collect()
    local name, realm = UnitFullName("player")
    local guid = UnitGUID("player")
    local _, classFile, classId = UnitClass("player")
    local level = UnitLevel("player")
    if not Utils.IsAccessible(name) or not Utils.IsAccessible(realm) or not Utils.IsAccessible(guid)
        or not Utils.IsAccessible(classFile) or not Utils.IsAccessible(classId) or not Utils.IsAccessible(level) then
        return Utils.Unavailable({ "character.current", "character.level" }, "restricted-or-not-ready")
    end

    local record = {
        schemaVersion = Cortex.Constants.CHARACTER_RECORD_SCHEMA_VERSION,
        guid = guid,
        name = name,
        realm = realm,
        classFile = classFile,
        classId = classId,
        level = level,
        lastSeenAt = time(),
    }
    return { facts = { ["character.current"] = record, ["character.level"] = level } }
end

Cortex:RegisterCollector("Character", CharacterCollector)
