-----------------------------------
-- Guild points from every guild each day (XI: Forever Offline, 2026-11-27)
--
-- shamwow_guy: "it would be nice to allow the option to have daily turn-ins for all of the guilds at once, as guild
-- points quickly become a bottleneck if you're looking to get multiple crafts to 100+". The user: yes.
--
-- The game lets a character hold one guild contract at a time: only that guild's Union Representative takes the day's
-- items, and the day's tally ([GUILD]daily_points, read and written by the map server, src/map/guild.cpp) is one
-- number for all guilds. Changing the contract also blocks turn-ins for the rest of the day.
-- With main.GUILD_ALL_CONTRACTS = 1 (RULES > Skills and crafting; 0 = the game's own rule, the default):
--   * every Union Representative takes its guild's items, contract or not (the contract simply follows the last
--     representative you talked to), and changing it never blocks the day;
--   * each guild keeps its own tally for the day ([GUILD]daily_<guild>, gone at Japanese midnight like the game's
--     own). The game's one tally is swapped for the guild's own around each turn-in and each look at the
--     representative's menu, and put back afterwards.
-- Lua only: a server restart (or the launcher's reload) is enough.
-----------------------------------
require('modules/module_utils')
require('scripts/globals/hobbies/crafting/guild_points')
-----------------------------------
local m = Module:new('guild_all_contracts')

local SHARED   = '[GUILD]daily_points'
local CONTRACT = '[GUILD]currentGuild'

local function allGuilds()
    local main = xi.settings and xi.settings.main
    return main ~= nil and tonumber(main.GUILD_ALL_CONTRACTS) == 1
end

local function tallyOf(guildId)
    return '[GUILD]daily_' .. tostring(guildId)
end

local function expiry()
    return type(JstMidnight) == 'function' and JstMidnight() or 0
end

-- run fn with this guild as the contract and its own tally in the game's one; the guild's tally is saved after
local function asGuild(player, guildId, fn)
    local shared = player:getCharVar(SHARED)
    player:setCharVar(CONTRACT, guildId + 1)
    player:setCharVar(SHARED, player:getCharVar(tallyOf(guildId)), expiry())

    local ok, err = pcall(fn)

    local now = player:getCharVar(SHARED)
    player:setCharVar(tallyOf(guildId), now, expiry())
    player:setCharVar(SHARED, shared, expiry())

    if not ok then
        error(err, 0)
    end
end

m:addOverride('xi.crafting.guildPointOnTrade', function(player, npc, trade, csid, guildId)
    if not allGuilds() then
        return super(player, npc, trade, csid, guildId)
    end

    asGuild(player, guildId, function()
        super(player, npc, trade, csid, guildId)
    end)
end)

m:addOverride('xi.crafting.guildPointOnTrigger', function(player, csid, guildId)
    if not allGuilds() then
        return super(player, csid, guildId)
    end

    -- the menu shows this guild as the one under contract, with what it still takes today
    asGuild(player, guildId, function()
        super(player, csid, guildId)
    end)
end)

m:addOverride('xi.crafting.guildPointOnEventFinish', function(player, option, guildId)
    if allGuilds() and bit.tobit(option) == -1 then
        -- the contract dialog: every guild counts already, so nothing is ended and nothing is blocked for the day
        player:setCharVar(CONTRACT, guildId + 1)
        return
    end

    return super(player, option, guildId)
end)

return m
