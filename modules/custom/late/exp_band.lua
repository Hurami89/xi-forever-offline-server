-----------------------------------
-- Experience bands (FFXI Offline house rules, 2026-11-07)
--
-- The Chariot Band, from the Conquest Overseer's normal list (the gate guards), works this way:
--   * +75% experience, up to 4000 bonus experience per use, 12 hours at most.
--   * 3 charges, and 15 hours between two uses.
--   * Costs 1000 conquest points.
--   * Buying it or recharging it counts for the conquest period: once per period, and a band bought this period cannot be
--     recharged until the next one (the overseers' "one ring per tally" char var, CONQUEST_RING_RECHARGE).
--   * Recharge: trade it to a Conquest Overseer, 1000 conquest points for a full recharge (less when only some of its
--     charges were used).
--   * Only one experience band at a time (Chariot / Empress / Emperor), as before.
-- The 3 charges and the 15 hour wait are also in the database (item_usable, applied by the launcher's house_rules.py,
-- so the game window shows them); the rules here hold even without that.
-- An Emperor Band you already have keeps working (same 4000 cap); it is no longer sold (!emperorband is gone).
-----------------------------------
require('modules/module_utils')
require('scripts/globals/conquest')
-----------------------------------
local m = Module:new('exp_band')

local CHARIOT       = 15761
local EMPEROR       = 15763
local EXP_BANDS     = { 15761, 15762, 15763 }
local CHARIOT_OPT   = 32933     -- its line in the overseer's list
local PRICE         = 1000
local FULL_CHARGE   = 1000      -- conquest points for a full recharge
local CHARGES       = 3
local WAIT          = 15 * 3600 -- seconds between two uses
local POWER         = 75
local EMPEROR_POWER = 50
local DURATION      = 43200
local MAX_BONUS     = 4000
local RECHARGE      = 'CONQUEST_RING_RECHARGE'
local USES          = '[ExpBand]Uses'  -- uses since it was bought or recharged
local NEXT_USE      = '[ExpBand]Next'  -- when it can be used again

local function say(player, text)
    player:printToPlayer(text)
end

local function now()
    return os.time()
end

local function usedThisPeriod(player)
    return xi.settings.main.BYPASS_EXP_RING_ONE_PER_WEEK ~= 1 and player:getCharVar(RECHARGE) ~= 0
end

local function hasABand(player)
    if xi.settings.main.ALLOW_MULTIPLE_EXP_RINGS == 1 then
        return false
    end

    for _, id in ipairs(EXP_BANDS) do
        if player:hasItem(id) then
            return true
        end
    end

    return false
end

local function freshBand(player)
    player:setCharVar(USES, 0)
    player:setCharVar(NEXT_USE, 0)
    player:setCharVar(RECHARGE, 1, NextConquestTally())
end

-----------------------------------
-- using it
-----------------------------------
m:addOverride('xi.items.chariot_band.onItemCheck', function(target, item, caster)
    if target:hasStatusEffect(xi.effect.DEDICATION) then
        return xi.msg.basic.ITEM_UNABLE_TO_USE_2
    end

    if target:getCharVar(USES) >= CHARGES then
        say(target, 'Your Chariot Band has no charges left. Recharge it at a Conquest Overseer (next conquest period).')
        return xi.msg.basic.ITEM_UNABLE_TO_USE_2
    end

    local wait = target:getCharVar(NEXT_USE) - now()
    if wait > 0 then
        say(target, string.format('Your Chariot Band can be used again in %dh %02dm.', math.floor(wait / 3600), math.floor(wait % 3600 / 60)))
        return xi.msg.basic.ITEM_UNABLE_TO_USE_2
    end

    return 0
end)

m:addOverride('xi.items.chariot_band.onItemUse', function(target)
    xi.itemUtils.addItemExpEffect(target, xi.effect.DEDICATION, POWER, DURATION, MAX_BONUS)
    target:setCharVar(USES, target:getCharVar(USES) + 1)
    target:setCharVar(NEXT_USE, now() + WAIT)
end)

-- an Emperor Band bought earlier keeps the same cap
m:addOverride('xi.items.emperor_band.onItemUse', function(target)
    xi.itemUtils.addItemExpEffect(target, xi.effect.DEDICATION, EMPEROR_POWER, DURATION, MAX_BONUS)
end)

-----------------------------------
-- buying it from the overseer's list
-----------------------------------
m:addOverride('xi.conquest.overseerOnEventUpdate', function(player, csid, option, guardNation)
    if option ~= CHARIOT_OPT then
        return super(player, csid, option, guardNation)
    end

    -- (2 = can equip it; the CP flag only when short of points: the other reasons are told when buying)
    player:updateEvent(2, player:getCP() < PRICE and 1 or 0, CHARIOT)
end)

m:addOverride('xi.conquest.overseerOnEventFinish', function(player, csid, option, guardNation, guardType, guardRegion)
    if option ~= CHARIOT_OPT then
        return super(player, csid, option, guardNation, guardType, guardRegion)
    end

    if hasABand(player) then
        say(player, 'You already have an experience band (Chariot, Empress or Emperor). Only one at a time.')
        return
    end

    if usedThisPeriod(player) then
        say(player, 'You already bought or recharged an experience band this conquest period. Come back after the next conquest tally.')
        return
    end

    if player:getCP() < PRICE then
        say(player, string.format('The Chariot Band costs %d conquest points (you have %d).', PRICE, player:getCP()))
        return
    end

    if npcUtil.giveItem(player, CHARIOT) then
        player:delCP(PRICE)
        freshBand(player)
        say(player, string.format('Chariot Band: +%d%% experience, up to %d per use, %d charges, %d hours between uses. Recharge: next conquest period.',
            POWER, MAX_BONUS, CHARGES, WAIT / 3600))
    end
end)

-----------------------------------
-- recharging it (trade it to the overseer)
-----------------------------------
m:addOverride('xi.conquest.overseerOnTrade', function(player, npc, trade, guardNation, guardType)
    if not npcUtil.tradeHas(trade, CHARIOT) then
        return super(player, npc, trade, guardNation, guardType)
    end

    if usedThisPeriod(player) then
        say(player, 'Your Chariot Band was already bought or recharged this conquest period. Come back after the next conquest tally.')
        return
    end

    local used = math.max(0, math.min(CHARGES, player:getCharVar(USES)))
    if used == 0 then
        say(player, 'The Chariot Band is already fully charged.')
        return
    end

    local cost = math.ceil(FULL_CHARGE * used / CHARGES)
    if player:getCP() < cost then
        say(player, string.format('Recharging the Chariot Band costs %d conquest points (you have %d).', cost, player:getCP()))
        return
    end

    player:delCP(cost)
    player:confirmTrade()
    player:addItem(CHARIOT)
    freshBand(player)
    say(player, string.format('Your Chariot Band is fully recharged (%d conquest points). Next recharge: after the conquest tally.', cost))
end)

return m
