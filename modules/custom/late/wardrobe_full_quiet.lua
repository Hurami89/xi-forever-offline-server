-----------------------------------
-- Quiet Mog Wardrobe messages (FFXI Offline)
--
-- Phoenix's wardrobe progression (modules/phoenix/lua/custom/wardrobe_unlocks.lua) adds 5 slots to a Mog Wardrobe for
-- each nation mission, many quests and a few key items, and says "Your Mog Wardrobe 1 capacity has been increased by 5!".
-- On this server every wardrobe starts at the full 80 slots, so the extra slots are thrown away (80 is the cap) and the
-- message is wrong. When a character's Mog Wardrobes 1-4 are all full, this marks every one of those rewards as already
-- given, so Phoenix skips them silently. A wardrobe below 80 is left alone: then the reward (and its message) is real.
-- The reward names are read from Phoenix's own file at start-up, so new rewards from a Phoenix update are covered too.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('wardrobe_full_quiet')

local SOURCE = 'modules/phoenix/lua/custom/wardrobe_unlocks.lua'
local MARK   = '[Wardrobe]QuietAllFull'   -- how many reward names were muted for this character

local rewardVars = {}
do
    local f = io.open(SOURCE, 'r')
    if f then
        local seen = {}
        for name in f:read('*a'):gmatch("var%s*=%s*'(%[Wardrobe%][^']+)'") do
            if not seen[name] then
                seen[name] = true
                rewardVars[#rewardVars + 1] = name
            end
        end

        f:close()
    else
        print('[wardrobe_full_quiet] ' .. SOURCE .. ' not found - nothing to do')
    end
end

local function wardrobesFull(player)
    for _, bag in ipairs({ xi.inv.WARDROBE, xi.inv.WARDROBE2, xi.inv.WARDROBE3, xi.inv.WARDROBE4 }) do
        if player:getContainerSize(bag) < 80 then
            return false
        end
    end

    return true
end

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)

    if #rewardVars == 0 or player:getCharVar(MARK) == #rewardVars or not wardrobesFull(player) then
        return
    end

    for _, name in ipairs(rewardVars) do
        if player:getCharVar(name) == 0 then
            player:setCharVar(name, 1)
        end
    end

    player:setCharVar(MARK, #rewardVars)
end)
