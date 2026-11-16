-----------------------------------
-- Healing Breath II
-- Family: Wyvern Pet
-- Description: Restores HP for target
-----------------------------------
---@type TMobSkill
local mobskillObject = {}

mobskillObject.onMobSkillCheck = function(target, mob, skill)
    return 0
end

mobskillObject.onMobWeaponSkill = function(mob, target, skill, action)
    local params = {}

    params.primaryMessage = xi.msg.basic.SELF_HEAL
    params.baseHeal       = mob:getMaxHP()
    params.additiveHeal   = 24
    params.fTP =
    {
        { tp = 1000, modifier = 48 / 256 },
        { tp = 2000, modifier = 48 / 256 },
        { tp = 3000, modifier = 48 / 256 },
    }

    return xi.mobskills.mobHealMove(mob, target, skill, action, params)
end

return mobskillObject
