-- late/guild_all_contracts.lua: guild points from every guild each day (2026-11-27, shamwow_guy; the user: yes).
-- The file is loaded the way the map server loads a module file (the real modules/module_utils.lua); its overrides
-- are put over stand-ins of the game's three guild point functions, which behave like the real ones (one contract,
-- one tally for the day, kept in [GUILD]daily_points the way src/map/guild.cpp keeps it). No server, no database.
--   luajit test_guild_all_contracts.lua <server folder>
local SERVER = arg[1]
assert(SERVER, 'usage: test_guild_all_contracts.lua <server folder>')

local passed, failed = 0, 0
local function check(c, label) if c then passed = passed + 1 else failed = failed + 1 io.write('FAIL: ', label, '\n') end end
local function section(n) io.write('\n== ', n, '\n') end

package.path = SERVER .. '/?.lua;' .. package.path
xi    = { settings = { main = { RESTRICT_CONTENT = 1 } } }
utils = { splitStr = function() return {} end }
bit   = bit or require('bit')
JstMidnight = function() return 999999 end
assert(loadfile(SERVER .. '/modules/module_utils.lua'))()
package.loaded['modules/module_utils'] = true
package.loaded['scripts/globals/hobbies/crafting/guild_points'] = true

-- the game's own functions, as stand-ins that keep the game's rules
local MAX = 100        -- the most points a guild takes in a day
local EACH = 20        -- points per item handed in
local events = {}
xi.crafting = {}
xi.crafting.guildPointOnTrade = function(player, npc, trade, csid, guildId)
    if player:getCharVar('[GUILD]currentGuild') - 1 ~= guildId then return end           -- not the contract: nothing
    local cur = player:getCharVar('[GUILD]daily_points')
    if cur == 1 then return end                                                             -- the day after a change: barred
    local add = math.min(trade.count * EACH, math.max(0, MAX - cur))
    if add > 0 then
        player.points[guildId] = (player.points[guildId] or 0) + add
        player:setCharVar('[GUILD]daily_points', cur + add, JstMidnight())
        trade.taken = add / EACH
    end
end
xi.crafting.guildPointOnTrigger = function(player, csid, guildId)
    local cur = player:getCharVar('[GUILD]daily_points')
    events[#events + 1] = { guild = player:getCharVar('[GUILD]currentGuild') - 1, remaining = cur == 1 and 0 or MAX - cur }
end
finishCalls = 0
xi.crafting.guildPointOnEventFinish = function(player, option, guildId)
    finishCalls = finishCalls + 1
    if bit.tobit(option) == -1 then
        local old = player:getCharVar('[GUILD]currentGuild') - 1
        player:setCharVar('[GUILD]currentGuild', guildId + 1)
        if old ~= -1 then player:setCharVar('[GUILD]daily_points', 1, JstMidnight()) end
    end
end
local originals = { trade = xi.crafting.guildPointOnTrade, trigger = xi.crafting.guildPointOnTrigger, finish = xi.crafting.guildPointOnEventFinish }

assert(loadfile(SERVER .. '/modules/custom/late/guild_all_contracts.lua'))()

section('what the file registers')
local module = xi.module.registry[1]
check(#xi.module.registry == 1 and module.name == 'guild_all_contracts' and #module.overrides == 3, 'one module, three overrides')
for _, o in ipairs(module.overrides) do
    local name = o.name:match('%.([%w]+)$')
    applyOverride(xi.crafting, name, o.func, o.name, 'guild_all_contracts.lua')
end

local function newPlayer(contract)
    local p = { vars = { ['[GUILD]currentGuild'] = contract and contract + 1 or 0 }, expiries = {}, points = {} }
    function p:getCharVar(n) return self.vars[n] or 0 end
    function p:setCharVar(n, v, e) self.vars[n] = v; self.expiries[n] = e end
    return p
end
local function hand(p, guild, count) local t = { count = count } xi.crafting.guildPointOnTrade(p, nil, t, 0, guild) return t.taken or 0 end
local SMITH, CLOTH, ALCH = 2, 4, 7

section('off (the default): the game\'s own rule')
do
    xi.settings.main.GUILD_ALL_CONTRACTS = nil
    local p = newPlayer(SMITH)
    check(hand(p, SMITH, 3) == 3 and p.points[SMITH] == 60, 'the contracted guild takes the items')
    check(hand(p, CLOTH, 3) == 0 and p.points[CLOTH] == nil, 'another guild takes nothing')
    xi.crafting.guildPointOnEventFinish(p, -1, CLOTH)
    check(p.vars['[GUILD]currentGuild'] == CLOTH + 1 and p.vars['[GUILD]daily_points'] == 1, 'changing the contract blocks the day, as in the game')
    xi.settings.main.GUILD_ALL_CONTRACTS = 0
    local q = newPlayer(SMITH)
    check(hand(q, CLOTH, 2) == 0, '0 is off too')
end

section('on: every guild, each with its own day')
do
    xi.settings.main.GUILD_ALL_CONTRACTS = 1
    local p = newPlayer(SMITH)
    check(hand(p, SMITH, 3) == 3 and p.points[SMITH] == 60, 'the contracted guild takes the items')
    check(hand(p, CLOTH, 4) == 4 and p.points[CLOTH] == 80, 'another guild takes them too, with no contract')
    check(hand(p, ALCH, 9) == 5 and p.points[ALCH] == 100, 'a third: up to its own daily most (100), not what the others took')
    check(hand(p, SMITH, 9) == 2 and p.points[SMITH] == 100, 'the first one has 40 left of its own day')
    check(hand(p, SMITH, 1) == 0, 'and then nothing more today')
    check(p.vars['[GUILD]daily_2'] == 100 and p.vars['[GUILD]daily_4'] == 80 and p.vars['[GUILD]daily_7'] == 100, 'each guild\'s tally kept apart')
    check(p.expiries['[GUILD]daily_4'] == 999999, 'and gone at Japanese midnight, like the game\'s own')
    check(p.vars['[GUILD]daily_points'] == 0, 'the game\'s one tally is put back as it was')
    events = {}
    xi.crafting.guildPointOnTrigger(p, 0, CLOTH)
    check(events[1].guild == CLOTH and events[1].remaining == 20, 'the representative\'s menu: its own guild as the contract, 20 left today')
    xi.crafting.guildPointOnEventFinish(p, -1, ALCH)
    check(p.vars['[GUILD]currentGuild'] == ALCH + 1 and p.vars['[GUILD]daily_points'] ~= 1, 'the contract dialog never blocks the day')
    check(hand(p, CLOTH, 1) == 1, 'and the others still take items afterwards')
    check(p.vars['[GUILD]currentGuild'] == CLOTH + 1, 'the contract follows the last representative you dealt with')
    finishCalls = 0
    xi.crafting.guildPointOnEventFinish(p, 3, ALCH)  -- another option: the game's own handling
    check(finishCalls == 1, 'any other choice in that menu goes to the game')
end

section('a mistake inside does not leave the tallies mixed')
do
    xi.settings.main.GUILD_ALL_CONTRACTS = 1
    local p = newPlayer(SMITH)
    p.vars['[GUILD]daily_points'] = 40
    p.vars['[GUILD]daily_4'] = 10
    local real = originals.trade
    -- the game's function stops halfway (an error after it wrote its tally)
    local broken = function(player) player:setCharVar('[GUILD]daily_points', 70, JstMidnight()) error('stopped') end
    local mod = module.overrides[1]
    local env = getfenv(mod.func)
    local saved = rawget(env, 'super')
    rawset(env, 'super', broken)
    local ok = pcall(xi.crafting.guildPointOnTrade, p, nil, { count = 1 }, 0, CLOTH)
    rawset(env, 'super', saved)
    check(not ok, 'the error is passed on')
    check(p.vars['[GUILD]daily_points'] == 40 and p.vars['[GUILD]daily_4'] == 70, 'the game\'s tally is put back, the guild\'s own keeps what was written')
    check(real ~= nil, '(stand-in kept)')
end

io.write(string.format('\n%d passed, %d failed\n', passed, failed))
os.exit(failed == 0 and 0 or 1)
