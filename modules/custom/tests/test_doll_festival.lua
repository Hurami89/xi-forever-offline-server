-- Stand-in test for modules/custom/lua/doll_festival.lua (+ the 2008 flag, crowds_chat hook, romance spot)
-- (run from a scratch copy of the server dir: luajit test_doll_festival.lua <server dir>)
local server = arg[1] or '.'
package.path = server .. '/?.lua;' .. package.path
local checks, failed = 0, 0
local function ok(cond, what)
    checks = checks + 1
    if not cond then
        failed = failed + 1
        print('FAIL: ' .. what)
    end
end

-- clock: local time 2027-03-01 12:00
local realDate, realTime = os.date, os.time
local now = realTime({ year = 2027, month = 3, day = 1, hour = 12 })
os.time = function(t) if t then return realTime(t) end return now end
os.date = function(f, t) return realDate(f, t or now) end
local function setDay(month, day) now = realTime({ year = 2027, month = month, day = day, hour = 12 }) end
local vanaDay = 1000
function VanadielUniqueDay() return vanaDay end

local rolls = {}
local realRandom = math.random
math.random = function(a, b)
    local r = table.remove(rolls, 1)
    if r ~= nil then
        if a == nil then return r end
        return math.max(a, math.min(b or a, r))
    end
    if a == nil then return 0.99 end -- "no" to every chance
    return a
end

local timers = {}
local function runTimers()
    while #timers > 0 do
        table.sort(timers, function(x, y) return x.ms < y.ms end)
        local t = table.remove(timers, 1)
        t.fn(t.ent)
    end
end

xi = {
    zone = { SOUTHERN_SAN_DORIA = 230, NORTHERN_SAN_DORIA = 231, BASTOK_MINES = 234, BASTOK_MARKETS = 235,
             WINDURST_WATERS = 238, WINDURST_WOODS = 241, SELBINA = 248 },
    msg = { channel = { NS_SAY = 13, SYSTEM_3 = 29, PARTY = 4, TELL = 3 } },
    status = { NORMAL = 0, DISAPPEAR = 2 },
    objType = { NPC = 2, TRUST = 4 },
    effect = { COSTUME = 127 },
    module = {},
    server = { onServerStart = function() end, onJSTMidnight = function() end, onTimeServerTick = function() end },
    player = { onGameIn = function() end },
    zones = {},
}
for _, n in ipairs({ 'Southern_San_dOria', 'Northern_San_dOria', 'Bastok_Mines', 'Bastok_Markets', 'Windurst_Waters', 'Windurst_Woods' }) do
    xi.zones[n] = { Zone = { onInitialize = function() end } }
end

-- events_mode stand-in
local eventsCfg = { mode = 'date' }
xi.eventsMode = {
    get = function() return eventsCfg.mode end,
    allowed = function(name) return eventsCfg[name] ~= false end,
}

-- module_utils stand-in: overrides are applied by hand (super = the original)
local overrides = {}
package.preload['modules/module_utils'] = function()
    Module = {}
    function Module:new(name) return { name = name, addOverride = function(self, target, fn) overrides[target] = fn end } end
    return true
end
local commands = {}
xi.module.registerCommand = function(name, t) commands[name] = t end
local function call(target, ...)
    local fn = overrides[target]
    local env = setmetatable({ super = function() end }, { __index = _G })
    setfenv(fn, env)
    return fn(...)
end

local given = {}
package.preload['scripts/globals/npc_util'] = function()
    npcUtil = { giveItem = function(player, items)
        if player.noRoom then return false end
        for _, it in ipairs(items) do
            player.bag[it[1]] = (player.bag[it[1]] or 0) + it[2]
        end
        table.insert(given, items)
        return true
    end }
    return true
end

-- entities
local npcs = {}
local function newNpc(id, zone, x, z)
    local n = { id = id, zone = zone, x = x or 0, z = z or 0, status = 2 }
    function n:getID() return self.id end
    function n:getZoneID() return self.zone end
    function n:setStatus(s) self.status = s end
    function n:getXPos() return self.x end
    function n:getZPos() return self.z end
    npcs[id] = n
    return n
end
function GetNPCByID(id) return npcs[id] or newNpc(id, math.floor((id - 16777216) / 4096) % 512, 0, 0) end

local zonesObj = {}
local function newZone(id)
    local z = { id = id, players = {}, dyn = 0 }
    function z:getID() return self.id end
    function z:getPlayers() return self.players end
    function z:insertDynamicEntity(t)
        self.dyn = self.dyn + 1
        local n = newNpc(5000 + self.id * 10 + self.dyn, self.id, t.x, t.z)
        n.def = t
        return n
    end
    zonesObj[id] = z
    return z
end
function GetZone(id) return zonesObj[id] or newZone(id) end

local bots = {}
function BotIsBot(id) return bots[id] == true end
local sent, sendCode = {}, 0
function SendItemToDeliveryBox(name, id, qty, from)
    if sendCode == 0 then table.insert(sent, { name, id, qty, from }) end
    return sendCode
end

local printed = {}
local function newPlayer(name, opts)
    opts = opts or {}
    local p = { name = name, id = opts.id or 1, zone = opts.zone or 231, vars = {}, locals = {}, bag = {},
                playtime = opts.playtime or 100000, free = opts.free or 30, gender = opts.gender or 0, race = opts.race or 2,
                party = {}, alliance = nil, x = opts.x or 0, z = opts.z or 0, effects = {}, pc = opts.pc ~= false }
    function p:getName() return self.name end
    function p:getPacketName() return self.name end
    function p:getID() return self.id end
    function p:getZoneID() return self.zone end
    function p:isPC() return self.pc end
    function p:getGender() return self.gender end
    function p:getRace() return self.race end
    function p:getCharVar(k) return self.vars[k] or 0 end
    function p:setCharVar(k, v) self.vars[k] = v end
    function p:getLocalVar(k) return self.locals[k] or 0 end
    function p:getPlaytime() return self.playtime end
    function p:getFreeSlotsCount() return self.free end
    function p:getPartyWithTrusts() return #self.party > 0 and self.party or { self } end
    function p:getAlliance() return self.alliance or { self } end
    function p:printToPlayer(text, chan, who) table.insert(printed, { to = self.name, text = text, chan = chan, who = who }) end
    function p:timer(ms, fn) table.insert(timers, { ms = ms, fn = fn, ent = self }) end
    function p:checkDistance(n) return math.sqrt((self.x - n.x) ^ 2 + (self.z - n.z) ^ 2) end
    function p:getGMLevel() return 1 end
    function p:hasStatusEffect(e) return self.effects[e] ~= nil end
    function p:addStatusEffect(e, t) self.effects[e] = t end
    return p
end

local function lastSaid(name)
    for i = #printed, 1, -1 do
        if printed[i].to == name then return printed[i] end
    end
end
local function saidAny(name, needle)
    for _, l in ipairs(printed) do
        if l.to == name and string.find(l.text, needle, 1, true) then return true end
    end
    return false
end

-- squad chat dir in a scratch place
local kit = os.getenv('DOLL_KIT') or '/tmp/doll_kit/'
package.preload['modules/custom/lua/kit_paths'] = function() return { kit = kit } end
os.execute('mkdir -p ' .. kit .. 'squad-chat')

-- load
dofile(server .. '/modules/custom/lua/doll_festival.lua')
local D = xi.dollFestival
ok(D and D.isActive, 'module loads and exposes xi.dollFestival')
ok(commands.dollpeek and commands.dollpeek.cmdprops and type(commands.dollpeek.onTrigger) == 'function', '!dollpeek registered with cmdprops/onTrigger')
for _, t in ipairs({ 'xi.server.onServerStart', 'xi.server.onJSTMidnight', 'xi.server.onTimeServerTick', 'xi.player.onGameIn',
                     'xi.zones.Windurst_Woods.Zone.onInitialize', 'xi.zones.Southern_San_dOria.Zone.onInitialize' }) do
    ok(type(overrides[t]) == 'function', 'override ' .. t)
end

-- 1. dates and switches
setDay(2, 27); ok(not D.isActive(), 'Feb 27: off')
setDay(2, 28); ok(D.isActive(), 'Feb 28: on')
now = realTime({ year = 2026, month = 11, day = 26, hour = 23 }); ok(not D.isActive(), 'Nov 26 2026: off')
now = realTime({ year = 2026, month = 11, day = 27, hour = 23 }); ok(D.isActive(), 'romance weekend: Fri Nov 27 2026 on')
now = realTime({ year = 2026, month = 11, day = 30, hour = 23 }); ok(D.isActive(), 'romance weekend: Mon Nov 30 2026 on')
now = realTime({ year = 2026, month = 12, day = 1, hour = 1 }); ok(not D.isActive(), 'Tue Dec 1 2026: off')
now = realTime({ year = 2027, month = 11, day = 28, hour = 12 }); ok(not D.isActive(), 'the weekend is a one-off: Nov 28 2027 off')
setDay(3, 14); ok(D.isActive(), 'Mar 14: on')
setDay(3, 15); ok(not D.isActive(), 'Mar 15: off')
setDay(7, 4); eventsCfg.mode = 'on'; ok(D.isActive(), 'Always on: on in July')
eventsCfg.mode = 'off'; setDay(3, 1); ok(not D.isActive(), 'Off: off in March')
eventsCfg.mode = 'date'; eventsCfg.doll_festival = false; ok(not D.isActive(), 'own switch off: off')
eventsCfg.doll_festival = nil; ok(D.isActive(), 'own switch missing = on')

-- 2. start: decorations, moogles, festival_now.txt
call('xi.server.onServerStart')
ok(D.state.active == true, 'server start turns it on in March')
local function shownModels(zoneId)
    local out = {}
    for _, set in ipairs(D.sets(zoneId)) do
        if npcs[set.ids[1]] and npcs[set.ids[1]].status == 0 then out[set.model] = true end
    end
    return out
end
ok(shownModels(231)[1293] and shownModels(230)[1293], 'San d\'Oria towns show the guessed set 1293')
ok(shownModels(234)[1287] and shownModels(235)[1287], 'Bastok towns show 1287')
ok(shownModels(238)[1294] and shownModels(241)[1294], 'Windurst towns show 1294')
ok(not shownModels(231)[1244] and not shownModels(230)[1245], 'Starlight sets stay hidden')
local moogleIds = {}
for zoneId in pairs(D.CITY_NAME) do
    local id = D.state.moogle[zoneId]
    moogleIds[zoneId] = id
    ok(id and npcs[id] and npcs[id].status == 0 and npcs[id].def.packetName == 'Moogle', 'a festival moogle in zone ' .. zoneId)
end
local f = io.open('modules/custom/lua/festival_now.txt'); local nowText = f and f:read('*a') or ''; if f then f:close() end
ok(nowText:find('Doll Festival', 1, true), 'festival_now.txt says the festival is on')

-- 3. the moogle
local hero = newPlayer('Hurami', { zone = 238, gender = 0, race = 6 })
local moogle = npcs[moogleIds[238]]
moogle.def.onTrigger(hero, moogle)
ok(saidAny('Hurami', 'have you ever heard of the Doll Festival'), 'first talk: the intro')
ok(next(hero.bag) == nil, 'no cake before the intro is over')
runTimers()
local total = 0
for _, q in pairs(hero.bag) do total = total + q end
ok(total == 1, 'after the intro: one rice cake')
ok(hero.vars['[Doll]Day'] == 1000, 'today marked')
moogle.def.onTrigger(hero, moogle)
ok(saidAny('Hurami', 'already had your rice cake'), 'same Vana\'diel day: already')
total = 0; for _, q in pairs(hero.bag) do total = total + q end
ok(total == 1, 'still one cake')
vanaDay = 1001
moogle.def.onTrigger(hero, moogle); runTimers()
total = 0; for _, q in pairs(hero.bag) do total = total + q end
ok(total == 2, 'next Vana\'diel day: another cake, no second intro')
vanaDay = 1002
local newbie = newPlayer('Fresh', { id = 2, zone = 238, playtime = 3000 })
newbie.vars['[Doll]Intro'] = 2027
moogle.def.onTrigger(newbie, moogle)
ok(saidAny('Fresh', 'only just arrived') and next(newbie.bag) == nil, 'new character waits a Vana\'diel day')
newbie.playtime = 3456
moogle.def.onTrigger(newbie, moogle)
ok(next(newbie.bag) ~= nil, 'after one Vana\'diel day of play: a cake')
local full = newPlayer('Packrat', { id = 3, zone = 238, free = 0 }); full.vars['[Doll]Intro'] = 2027
moogle.def.onTrigger(full, moogle)
ok(saidAny('Packrat', 'bags are stuffed') and full.vars['[Doll]Day'] == nil, 'full bags: no cake, day not used')
local stuck = newPlayer('Stuck', { id = 4, zone = 238 }); stuck.vars['[Doll]Intro'] = 2027; stuck.noRoom = true
moogle.def.onTrigger(stuck, moogle)
ok(stuck.vars['[Doll]Day'] == nil, 'giveItem fails: day not used')
-- Intro again next year
hero.vars['[Doll]Intro'] = 2026
vanaDay = 1003
local before = #printed
moogle.def.onTrigger(hero, moogle)
ok(saidAny('Hurami', 'have you ever heard') and #printed > before, 'a new year: the intro again')
runTimers()

-- 4. the 2005 party
local function member(i, male, zone)
    return newPlayer('M' .. i, { id = 100 + i, zone = zone or 238, gender = male and 1 or 0, race = male and 1 or 2 })
end
local leader = newPlayer('Lead', { id = 99, zone = 238, gender = 1, race = 3 })
local function group(list)
    for _, e in ipairs(list) do e.party = {} end
    leader.party = { leader }
    leader.alliance = { leader }
    local second = nil
    for i, e in ipairs(list) do
        if i <= 5 then table.insert(leader.party, e) else
            second = second or e
            second.party = second.party or {}
            if #second.party == 0 then second.party = { second } else table.insert(second.party, e) end
        end
    end
    if second then table.insert(leader.alliance, second) end
end
local list = {}
for i = 1, 8 do table.insert(list, member(i, true)) end
group(list) -- 9 people
local c = D.festivalGroup(leader)
ok(c == 9, 'nine counted (party + alliance)')
local items, names, kind = D.giftFor(leader)
ok(kind == 'given' and #items == 1, 'nine: the daily cake')
table.insert(list, member(9, true)); group(list)
c = D.festivalGroup(leader)
ok(c == 10, 'ten counted')
items, names, kind = D.giftFor(leader)
local q = 0; for _, it in ipairs(items) do q = q + it[2] end
ok(kind == 'party' and q == 2, 'ten, wrong mix (all men): two cakes')
list = {}
for i = 1, 5 do table.insert(list, member(i, true)) end
for i = 6, 9 do table.insert(list, member(i, false)) end
group(list) -- leader male + 5 men + 4 women
local _, men, women = D.festivalGroup(leader)
ok(men == 6 and women == 4, 'doll stage counted: six men, four women')
items, names, kind = D.giftFor(leader)
local ids = {}; for _, it in ipairs(items) do ids[it[1]] = true end
ok(kind == 'stage' and ids[5294] and ids[5295] and ids[5296] and ids[5297], 'the doll stage: one cake of every race')
list[9].zone = 241; group(list)
ok(D.festivalGroup(leader) == 9, 'someone in another area does not count')
items, names, kind = D.giftFor(leader)
ok(kind == 'given', 'and then it is the daily cake')
-- trusts (squad mates) count, gender from race
list[9].zone = 238
local mate = newPlayer('Mate', { id = 300, zone = 238, pc = false, race = 7, gender = 9 })
list[9] = mate; group(list)
_, men, women = D.festivalGroup(leader)
ok(women == 4 and men == 6, 'a squad mate counts, gender from race (Mithra)')
leader.vars['[Doll]Intro'] = 2027; vanaDay = 1010
moogle.def.onTrigger(leader, moogle)
local lq = 0; for _, v in pairs(leader.bag) do lq = lq + v end
ok(lq == 4 and saidAny('Lead', 'doll stage'), 'the moogle gives the stage set and says so')

-- 5. the delivery box
sent = {}
D.deliver(hero)
ok(#sent == 1 and sent[1][3] == 11 and sent[1][2] >= 5294 and sent[1][2] <= 5297, '2007: 11 rice cakes of one race')
ok(saidAny('Hurami', 'delivery box'), 'told about the delivery')
D.deliver(hero)
ok(#sent == 1, 'once a festival')
local unlucky = newPlayer('Unlucky', { id = 5 })
sendCode = 1; D.deliver(unlucky); sendCode = 0
ok(unlucky.vars['[Doll]Box'] == nil, 'a failed send is tried again later')
D.deliver(unlucky)
ok(unlucky.vars['[Doll]Box'] == 2027, 'and then it goes')
ok(not D.outOfEra(), 'without the out-of-era switch: no furnishings')
local nofurn = true
for _, s in ipairs(sent) do if s[2] == 215 or s[2] == 180 then nofurn = false end end
ok(nofurn, 'no Festival Dolls / Bonbori sent in era')
dofile(server .. '/modules/wedding/lua/doll_festival_2008.lua')
ok(D.outOfEra(), 'the wedding folder file turns the 2008 furnishings on')
sent = {}
D.deliver(hero)
local got = {}; for _, s in ipairs(sent) do got[s[2]] = (got[s[2]] or 0) + s[3] end
ok(got[215] == 1 and got[180] == 1 and not got[5294] and not got[5295], '2008: dolls and bonbori, no second cake box')
sent = {}; D.deliver(hero)
ok(#sent == 0, 'furnishings once a festival')
local bot = newPlayer('Botty', { id = 16000001 }); bots[16000001] = true
sent = {}; D.deliver(bot)
ok(#sent == 0, 'bot players get no delivery')
now = realTime({ year = 2028, month = 3, day = 1, hour = 12 }) -- next year
sent = {}; D.deliver(hero)
ok(#sent == 3, 'next year: the cakes and the furnishings again')
setDay(3, 1)

-- 6. onGameIn: notice, delivery, mate
printed = {}
local walker = newPlayer('Walker', { id = 6, zone = 241 })
call('xi.player.onGameIn', walker, false, true)
ok(saidAny('Walker', 'The Doll Festival is here'), 'the notice in a festival town')
printed = {}
call('xi.player.onGameIn', walker, false, true)
ok(not saidAny('Walker', 'The Doll Festival is here'), 'notice once a day')
local away = newPlayer('Away', { id = 7, zone = 248 })
call('xi.player.onGameIn', away, true, false)
ok(not saidAny('Away', 'The Doll Festival is here') and away.vars['[Doll]Box'] == 2027, 'elsewhere: delivery but no notice')
timers = {}

-- 7. squad mate notice
local io_kit = kit .. 'squad-chat/'
os.remove(io_kit .. 'in.txt'); os.remove(io_kit .. 'state.json')
local sq = newPlayer('Sq', { id = 8, zone = 241 })
local m1 = newPlayer('Kurami', { id = 400, zone = 241, pc = false }); m1.locals.SQUAD_ID = 3
sq.party = { sq, m1 }
printed = {}
ok(D.mateNotice(sq), 'a squad mate notices the festival')
local fh = io.open(io_kit .. 'in.txt'); local inTxt = fh and fh:read('*a') or ''; if fh then fh:close() end
ok(inTxt:find('^LOVEEV\tKurami\tThe Doll Festival is on in Windurst Woods'), 'LOVEEV line to the squad chat AI')
runTimers()
ok(lastSaid('Sq') and lastSaid('Sq').who == 'Kurami' and lastSaid('Sq').chan == 4, 'sidecar not running: the written line in party chat')
ok(not D.mateNotice(sq), 'once a Vana\'diel day')
vanaDay = vanaDay + 1
local fh2 = io.open(io_kit .. 'state.json', 'w'); fh2:write('{"in_offset": 999999}'); fh2:close()
printed = {}
ok(D.mateNotice(sq), 'next day again')
runTimers()
ok(lastSaid('Sq') == nil, 'sidecar read it: no written line from the server')
vanaDay = vanaDay + 1
sq.vars.SQUAD_CHAT_OFF = 1
printed = {}
D.mateNotice(sq)
ok(lastSaid('Sq') and lastSaid('Sq').who == 'Kurami', 'squad chat off: said straight away')
local lonely = newPlayer('Lonely', { id = 9, zone = 241 })
ok(not D.mateNotice(lonely), 'no squad mates: nothing')
local elsewhere = newPlayer('Else', { id = 10, zone = 248 }); elsewhere.party = { elsewhere, m1 }
ok(not D.mateNotice(elsewhere), 'not in a festival town: nothing')

-- 8. bot players eat cakes
local z241 = GetZone(241)
local b1 = newPlayer('BotA', { id = 16000010, zone = 241 }); bots[16000010] = true
local b2 = newPlayer('BotB', { id = 16000011, zone = 241 }); bots[16000011] = true
b2.effects[127] = { power = 1 }
local human = newPlayer('Human', { id = 11, zone = 241 })
z241.players = { b1, b2, human }
D.state.botTick = 0
rolls = { 0.0, 0.0, 0.0, 0.0 }
local ate = D.botTick(now)
ok(ate == 1 and b1.effects[127] and b1.effects[127].duration == 3600, 'a bot eats a rice cake (60 minutes)')
ok(b2.effects[127].power == 1 and human.effects[127] == nil, 'not a bot already in costume, never a real player')
b1.effects[127] = nil
rolls = { 0.0 }
ok(D.botTick(now + 10) == 0, 'not again within the tick')
rolls = { 0.0 }
ok(D.botTick(now + 200) == 1, 'and again after it')
rolls = {}

-- 9. chatter
rolls = { 0.0 }
ok(type(D.chatLine(231)) == 'string', 'town chatter: a festival line')
ok(D.chatLine(231) == nil, 'most of the time an ordinary one (roll 0.99)')
rolls = { 0.0 }
ok(D.chatLine(248) == nil, 'Selbina: no festival talk')
rolls = { 0.0 }
local a, b = D.chatPair(241)
ok(type(a) == 'string' and type(b) == 'string', 'a festival pair')
rolls = {}

-- 10. under the blossoms (romance)
local sakuraZone = 231
local someDecor
for _, set in ipairs(D.sets(sakuraZone)) do if set.model == 1293 then someDecor = npcs[set.ids[1]] end end
someDecor.x, someDecor.z = 100, 100
local lover = newPlayer('Lover', { id = 12, zone = sakuraZone, x = 105, z = 100 })
ok(D.underBlossoms(lover), 'no trees marked: near the decorations in a blossom town')
lover.x = 500
ok(not D.underBlossoms(lover), 'far from the decorations: no')
local ssand = newPlayer('Ssand', { id = 13, zone = 230 })
ok(not D.underBlossoms(ssand), 'Southern San d\'Oria (moogle only in later years) is not a blossom town without trees')

-- 11. !dollpeek
printed = {}
local gm = newPlayer('GM', { id = 14, zone = 231 })
commands.dollpeek.onTrigger(gm)
ok(saidAny('GM', 'hidden sets'), 'peek: list')
ok(saidAny('GM', 'Starlight Celebration'), 'peek: known Starlight sets are labelled')
ok(saidAny('GM', 'guess: decor'), 'peek: the guess is labelled')
local treeIndex, treeSet
for i, set in ipairs(D.sets(231)) do if set.model == 1304 then treeIndex, treeSet = i, set end end
ok(npcs[treeSet.ids[1]] == nil or npcs[treeSet.ids[1]].status ~= 0, 'set 1304 hidden before peeking')
commands.dollpeek.onTrigger(gm, tostring(treeIndex))
ok(npcs[treeSet.ids[1]].status == 0 and saidAny('GM', 'Showing set ' .. treeIndex), 'peek: shows a set')
commands.dollpeek.onTrigger(gm, 'hide')
ok(npcs[treeSet.ids[1]].status == 2, 'peek: hide')
local guessIndex
for i, set in ipairs(D.sets(231)) do if set.model == 1293 then guessIndex = i end end
commands.dollpeek.onTrigger(gm, tostring(guessIndex))
commands.dollpeek.onTrigger(gm, 'hide')
ok(shownModels(231)[1293], 'hiding a peek does not hide the festival\'s own decorations')
commands.dollpeek.onTrigger(gm, 'mark', tostring(treeIndex), 'tree')
ok(shownModels(231)[1304], 'mark tree: shown in the festival')
local mf = io.open('modules/custom/lua/doll_festival_marks.lua'); local marksText = mf and mf:read('*a') or ''; if mf then mf:close() end
ok(marksText:find("%[231%] = { %[1304%] = 'tree' }"), 'mark saved in doll_festival_marks.lua')
commands.dollpeek.onTrigger(gm, 'mark', tostring(guessIndex), 'off')
ok(not shownModels(231)[1293], 'mark off: the guess is taken down')
ok(D.kindOf(231, 1293) == nil and D.kindOf(231, 1304) == 'tree' and D.kindOf(230, 1293) == 'decor', 'marks per town; other towns keep the guess')
-- trees now known in this town
local tree = npcs[treeSet.ids[1]]; tree.x, tree.z = 0, 0
lover.x, lover.z = 10, 0
ok(D.underBlossoms(lover), 'under a marked cherry tree: a date spot')
lover.x = 40
ok(not D.underBlossoms(lover), 'trees known and not under one: no')
commands.dollpeek.onTrigger(gm, 'mark', '999', 'tree')
ok(saidAny('GM', 'Usage: !dollpeek mark'), 'bad mark: usage')
local outside = newPlayer('Out', { id = 15, zone = 248 })
commands.dollpeek.onTrigger(outside)
ok(saidAny('Out', 'Stand in one of the six festival towns'), 'peek outside the towns: explains')

-- 12. the end of the festival
setDay(3, 15)
call('xi.server.onJSTMidnight')
ok(D.state.active == false, 'midnight after Mar 14: off')
ok(not shownModels(231)[1304] and not shownModels(234)[1287], 'decorations taken down')
ok(npcs[moogleIds[238]].status == 2, 'moogles gone')
f = io.open('modules/custom/lua/festival_now.txt'); nowText = f and f:read('*a') or 'x'; if f then f:close() end
ok(nowText == '', 'festival_now.txt emptied')
ok(not D.underBlossoms(lover), 'no date spot after the festival')
rolls = { 0.0 }
ok(D.chatLine(231) == nil, 'no festival chatter after')
moogle.def.onTrigger(hero, moogle)
-- (no output expected: inactive)
printed = {}
local late = newPlayer('Late', { id = 16, zone = 241 })
call('xi.player.onGameIn', late, true, false)
ok(#printed == 0 and late.vars['[Doll]Box'] == nil, 'after the festival: nothing on login')

-- 13. a zone that starts during the festival
setDay(3, 2)
D.state.active = nil
call('xi.zones.Windurst_Woods.Zone.onInitialize', GetZone(241))
ok(D.state.active == true and shownModels(241)[1294], 'a zone starting during the festival decorates itself')

print(string.format('%d checks, %d failed', checks, failed))
os.exit(failed == 0 and 0 or 1)
