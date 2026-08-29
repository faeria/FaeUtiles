local _, Cortex = ...
local Utils = Cortex.CollectorUtils

local InstanceCollector = {
    events = { "PLAYER_ENTERING_WORLD" },
    requiresOutOfCombat = true,
}

function InstanceCollector:Collect()
    if type(IsInInstance) ~= "function" or type(GetInstanceInfo) ~= "function" then
        return Utils.Unavailable({ "instance.current" }, "api-unavailable")
    end
    local isInInstance, instanceType = IsInInstance()
    if not Cortex:IsAccessibleValue(isInInstance) or not Cortex:IsAccessibleValue(instanceType) then
        return Utils.Unavailable({ "instance.current" }, "restricted")
    end
    local name, returnedType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty,
        isDynamic, instanceID, instanceGroupSize, lfgDungeonID = GetInstanceInfo()
    if not Utils.AllAccessible(name, returnedType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty,
        isDynamic, instanceID, instanceGroupSize, lfgDungeonID) then
        return Utils.Unavailable({ "instance.current" }, "restricted")
    end
    return { facts = { ["instance.current"] = {
        isInInstance = isInInstance,
        instanceType = returnedType or instanceType,
        name = name,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        maxPlayers = maxPlayers,
        dynamicDifficulty = dynamicDifficulty,
        isDynamic = isDynamic,
        instanceID = instanceID,
        instanceGroupSize = instanceGroupSize,
        lfgDungeonID = lfgDungeonID,
    } } }
end

Cortex:RegisterCollector("Instance", InstanceCollector)
