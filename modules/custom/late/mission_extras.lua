-----------------------------------
-- Mission extras (FFXI Offline)
--
-- 1. Harder mission fights: listed battlefields get their monsters a few levels higher and with more HP, so a full party
--    (you, your dualbox character and your squad) still has to work for it. First: San d'Oria 1-3 "Save the Children"
--    (+4 levels, +50% HP, everyone capped at level 10).
-- 2. A cosmetic reward for rank 2 (missions 1-3) of every nation: one random piece of event/cosmetic gear from Phoenix's own
--    era list (modules/phoenix/lua/data/cosmetic_wardrobe_items.lua), skipping race- and gender-locked outfits and the
--    beta tester reward, and preferring a piece you do not own yet. No room in your bags: it waits and is handed over the next
--    time you zone or log in.
-----------------------------------
require('modules/module_utils')
require('scripts/globals/battlefield')
-----------------------------------
local m = Module:new('mission_extras')

-- battlefield id -> how much harder
local HARDER =
{
    [xi.battlefield.id.SAVE_THE_CHILDREN] = { levels = 4, hpPercent = 65, attackPercent = 15 }, -- was +50% HP; made 15% harder
}

m:addOverride('Battlefield.onBattlefieldInitialize', function(self, battlefield)
    super(self, battlefield)

    local tune = HARDER[self.battlefieldId]
    if tune == nil then
        return
    end

    for _, mob in ipairs(battlefield:getMobs(true, true)) do
        mob:setMobLevel(math.min(mob:getMainLvl() + tune.levels, 99))
        if (tune.attackPercent or 0) > 0 then
            mob:addMod(xi.mod.ATTP, tune.attackPercent)
        end

        if tune.hpPercent > 0 then
            mob:addMod(xi.mod.HPP, tune.hpPercent)
            mob:updateHealth()
        end

        mob:setHP(mob:getMaxHP())
    end
end)

-- battlefield id -> level cap for everyone who enters (the server's own setting caps mission fights at the max level)
local LEVEL_CAP =
{
    [xi.battlefield.id.SAVE_THE_CHILDREN] = 10,
}

-- The game has just put its own (max level) restriction on the player; replace it with ours. Squad mates called inside
-- follow the player's level, so they are capped too.
m:addOverride('Battlefield.onBattlefieldEnter', function(self, player, battlefield)
    local result = super(self, player, battlefield)

    local cap = LEVEL_CAP[self.battlefieldId]
    if cap ~= nil then
        local ok, err = pcall(function()
            player:delStatusEffectSilent(xi.effect.LEVEL_RESTRICTION)
            player:addStatusEffect(xi.effect.LEVEL_RESTRICTION, { origin = player, power = cap })
        end)
        if ok then
            player:printToPlayer(string.format('This fight is level capped at %d.', cap), xi.msg.channel.SYSTEM_3, '')
        else
            print('[mission_extras] level cap failed: ' .. tostring(err))
        end
    end

    return result
end)

-----------------------------------
-- Cosmetic rewards
-----------------------------------
local REWARD_MISSIONS =
{
    [xi.mission.log_id.SANDORIA] = { [xi.mission.id.sandoria.SAVE_THE_CHILDREN] = 'Sandoria_1_3' },
    [xi.mission.log_id.BASTOK]   = { [xi.mission.id.bastok.FETICHISM]           = 'Bastok_1_3'   },
    [xi.mission.log_id.WINDURST] = { [xi.mission.id.windurst.THE_PRICE_OF_PEACE] = 'Windurst_1_3' },
}

local PENDING = '[CosmeticReward]Pending'

-- ...and the nation's ring (San d'Orian / Bastokan / Windurstian Ring) when you finish 1-3, if you do not have one
-- (never had it, dropped it or sold it). It is a rare item, so you can only hold one.
local NATION_RING =
{
    [xi.mission.log_id.SANDORIA] = xi.item.SAN_DORIAN_RING,
    [xi.mission.log_id.BASTOK]   = xi.item.BASTOKAN_RING,
    [xi.mission.log_id.WINDURST] = xi.item.WINDURSTIAN_RING,
}
local PENDING_RING = '[CosmeticReward]PendingRing'

-- Outfits made for one race or gender (swimsuits, yukatas) and the beta tester cap are left out
local SKIP = { 'GILET', 'TOP', 'TRUNKS', 'SHORTS', 'MAILLOT', 'YUKATA', 'CELESTE' }

local pool = {}
do
    local ok, list = pcall(require, 'modules/phoenix/lua/data/cosmetic_wardrobe_items')
    local names = {}
    for name, id in pairs(xi.item) do
        names[id] = name
    end

    if ok and type(list) == 'table' then
        for _, itemId in ipairs(list) do
            local name = names[itemId] or ''
            local skip = false
            for _, word in ipairs(SKIP) do
                if string.find(name, word, 1, true) then
                    skip = true
                end
            end

            if itemId and not skip then
                pool[#pool + 1] = itemId
            end
        end
    end

    if #pool == 0 then
        print('[mission_extras] no cosmetic items found - the rank 2 rewards are off')
    end
end

local function pickReward(player)
    local fresh = {}
    for _, itemId in ipairs(pool) do
        if not player:hasItem(itemId) then
            fresh[#fresh + 1] = itemId
        end
    end

    local from = #fresh > 0 and fresh or pool
    return from[math.random(#from)]
end

local function hand(player, itemId)
    if npcUtil.giveItem(player, itemId) then
        player:setCharVar(PENDING, 0)
        player:printToPlayer('A little something for your service to the nation!', xi.msg.channel.SYSTEM_3, '')
        return true
    end

    player:setCharVar(PENDING, itemId)
    player:printToPlayer('You earned a cosmetic reward, but your bags are full. It will be given to you the next time you zone.', xi.msg.channel.SYSTEM_3, '')
    return false
end

local function handRing(player, ringId)
    if player:hasItem(ringId) then
        player:setCharVar(PENDING_RING, 0)
        return true
    end

    if npcUtil.giveItem(player, ringId) then
        player:setCharVar(PENDING_RING, 0)
        return true
    end

    player:setCharVar(PENDING_RING, ringId)
    player:printToPlayer('Your nation\'s ring is waiting for you: make room in your bags and zone.', xi.msg.channel.SYSTEM_3, '')
    return false
end

m:addOverride('npcUtil.completeMission', function(player, logId, missionId, params)
    local result = super(player, logId, missionId, params)

    local key = result and REWARD_MISSIONS[logId] and REWARD_MISSIONS[logId][missionId]
    if key then
        local var = '[CosmeticReward]' .. key
        if player:getCharVar(var) == 0 then
            player:setCharVar(var, 1)
            if #pool > 0 then
                hand(player, pickReward(player))
            end

            if NATION_RING[logId] then
                handRing(player, NATION_RING[logId])
            end
        end
    end

    return result
end)

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)

    local waiting = player:getCharVar(PENDING)
    if waiting > 0 then
        player:timer(3000, function(entity)
            hand(entity, waiting)
        end)
    end

    local ring = player:getCharVar(PENDING_RING)
    if ring > 0 then
        player:timer(4000, function(entity)
            handRing(entity, ring)
        end)
    end
end)
