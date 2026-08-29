local _, Cortex = ...
local Utils = Cortex.CollectorUtils

local ProfessionCollector = {
    events = { "SKILL_LINES_CHANGED" },
    requiresOutOfCombat = true,
}

local PROFESSION_SLOTS = { "primary1", "primary2", "archaeology", "fishing", "cooking", "firstAid" }

function ProfessionCollector:Collect()
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        return Utils.Unavailable({ "professions.learned" }, "api-unavailable")
    end
    local indices = { GetProfessions() }
    local learned = {}
    for slot = 1, #PROFESSION_SLOTS do
        local professionIndex = indices[slot]
        if not Cortex:IsAccessibleValue(professionIndex) then
            return Utils.Unavailable({ "professions.learned" }, "restricted")
        end
        if professionIndex then
            local name, icon, skillLevel, maxSkillLevel, numAbilities, spellOffset, skillLine,
                skillModifier, specializationIndex, specializationOffset = GetProfessionInfo(professionIndex)
            if not Utils.IsAccessible(name) or not Utils.AllAccessible(icon, skillLevel, maxSkillLevel, numAbilities, spellOffset,
                skillLine, skillModifier, specializationIndex, specializationOffset) then
                return Utils.Unavailable({ "professions.learned" }, "restricted")
            end
            learned[PROFESSION_SLOTS[slot]] = {
                name = name,
                icon = icon,
                skillLevel = skillLevel,
                maxSkillLevel = maxSkillLevel,
                numAbilities = numAbilities,
                skillLine = skillLine,
                skillModifier = skillModifier,
                specializationIndex = specializationIndex,
            }
        end
    end
    return { facts = { ["professions.learned"] = learned } }
end

Cortex:RegisterCollector("Profession", ProfessionCollector)
