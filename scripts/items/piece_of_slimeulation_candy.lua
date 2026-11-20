-----------------------------------
-- ID: 6187
-- Item: Piece of Slimeulation Candy
-- Food Effect: Costume Slime
-----------------------------------
local itemObject = {}

itemObject.onItemCheck = function(target, user)
    return 0
end

itemObject.onItemUse = function(target, user)
    -- (2026-11-20, Sunie: the candy gave the costume status but no slime) the effect runs scripts/effects/costume.lua, which
    -- shows the model in the effect's power; without one it set costume 0
    target:addStatusEffect(xi.effect.COSTUME, { power = 2881, duration = 10000, origin = user, subType = 6187 })
end

itemObject.onEffectGain = function(target, effect)
    target:setCostume(2881)
end

itemObject.onEffectLose = function(target, effect)
    target:setCostume(0)
end

return itemObject
