-----------------------------------
-- Doll Festival (XI: Forever Offline seasonal event)
-----------------------------------
-- The era Doll Festival (2005-2007), the Far Eastern festival for the health and happiness of young girls:
--  * Festival moogles in Southern and Northern San d'Oria, Bastok Mines and Markets, Windurst Waters and Woods
--    (the six areas of 2005 and 2006). Talk to one once per Vana'diel day for a rice cake of a random race (Hume,
--    Elvaan, Mithran or Tarutaru: 60 minutes as a little girl of that race, men too). New characters wait one
--    Vana'diel day (2005, 2006).
--  * 2005: with ten in your party or alliance in the same area (squad mates and bot players count) the moogle gives
--    more, and with the doll stage's mix (six men, four women: the emperor and the five musicians, the empress and
--    the three ladies-in-waiting) a rice cake of every race.
--  * 2007: the Mog House Management Union sends every character 11 rice cakes of a random race, once a festival.
--  * 2008 (out of era, only with the launcher's Out-of-era content switch, modules/wedding/lua/doll_festival_2008.lua):
--    a set of Festival Dolls and a Bonbori lantern in the delivery box, once a festival.
--  * The towns' Far Eastern screens, parasols and cherry trees (retail decoration NPCs already in the zone data; which
--    set is which is checked in game with !dollpeek, see below). During the festival the cherry trees are date spots
--    for romance (modules/wedding/lua/wedding_romance.lua asks xi.dollFestival.underBlossoms).
--  * The world joins in: town crowds and bot players talk about it, bot players in the towns now and then eat a rice
--    cake, squad mates notice the blossoms, and the chat AIs are told the festival is on (festival_now.txt).
--  * Music: retail kept each town's own music for this event, so this does too.
--
-- Dates: February 28 to March 14, the moogle years' retail dates (2005: Feb 28-Mar 13, 2006: Feb 28-Mar 14; 2007 ran
-- Feb 23-Mar 4), plus the one-off weekends in EXTRA below, the PC's local date, unless the launcher's Seasonal events
-- setting is Always on or Off (events_mode.lua), and never while its own Doll Festival switch is off.
--
-- !dollpeek (GM): the hidden decoration sets of the town you stand in (doll_festival_spots.lua), one at a time:
--   !dollpeek            list the sets here          !dollpeek <n>     show set n (and say where the nearest one is)
--   !dollpeek hide       hide the set you showed     !dollpeek mark <n> decor|tree|off   save what set n is
-- Marks are saved in doll_festival_marks.lua. Until a set is marked, the best guess (GUESS below) is shown.
--
-- NOT FROM RETAIL CAPTURES: the moogles' text (our own, in the chat log), their spots (the town event moogles' spots),
-- the 2005 extras (the exact amounts were not recorded) and the decorations until checked with !dollpeek.
-----------------------------------
require('modules/module_utils')
require('scripts/globals/npc_util')

local m     = Module:new('doll_festival')
local SPOTS = require('modules/custom/lua/doll_festival_spots')
local LINES = require('modules/custom/lua/doll_festival_lines')

xi = xi or {}
xi.dollFestival = xi.dollFestival or {}
local D = xi.dollFestival

local ZONE = xi.zone

-- month * 100 + day, inclusive
D.START  = 228
D.FINISH = 314

-- one-off extra days, yyyymmdd inclusive
D.EXTRA =
{
    { start = 20261127, finish = 20261130 }, -- the romance update weekend (squad mates and bot players can be dated)
}

D.CAKES =
{
    { id = 5294, name = 'Hume Rice Cake',     power = 118 },
    { id = 5295, name = 'Elvaan Rice Cake',   power = 158 },
    { id = 5296, name = 'Tarutaru Rice Cake', power = 823 },
    { id = 5297, name = 'Mithran Rice Cake',  power = 182 },
}

D.FESTIVAL_DOLLS = 215
D.BONBORI        = 180

local VANA_DAY_SECONDS = 3456 -- one Vana'diel day (57.6 minutes)
local BOX_COUNT        = 11   -- 2007
local PARTY_SIZE       = 10   -- 2005
local STAGE_MEN        = 6
local STAGE_WOMEN      = 4
local BOT_CAKE_CHANCE  = 0.03 -- per bot in a festival town, every BOT_TICK seconds
local BOT_TICK         = 150
local CHAT_SHARE       = 0.25 -- share of town chatter that is about the festival
local NEAR_TREE        = 15   -- yalms: under the cherry blossoms
local NEAR_DECOR       = 20

local CITY_NAME =
{
    [ZONE.SOUTHERN_SAN_DORIA] = "Southern San d'Oria",
    [ZONE.NORTHERN_SAN_DORIA] = "Northern San d'Oria",
    [ZONE.BASTOK_MINES]       = 'Bastok Mines',
    [ZONE.BASTOK_MARKETS]     = 'Bastok Markets',
    [ZONE.WINDURST_WATERS]    = 'Windurst Waters',
    [ZONE.WINDURST_WOODS]     = 'Windurst Woods',
}
D.CITY_NAME = CITY_NAME

local ZONE_SCRIPT =
{
    [ZONE.SOUTHERN_SAN_DORIA] = 'Southern_San_dOria',
    [ZONE.NORTHERN_SAN_DORIA] = 'Northern_San_dOria',
    [ZONE.BASTOK_MINES]       = 'Bastok_Mines',
    [ZONE.BASTOK_MARKETS]     = 'Bastok_Markets',
    [ZONE.WINDURST_WATERS]    = 'Windurst_Waters',
    [ZONE.WINDURST_WOODS]     = 'Windurst_Woods',
}

-- the festival moogles stand where the towns' event moogles stand (the Starlight token moogles' spots)
local MOOGLES =
{
    [ZONE.SOUTHERN_SAN_DORIA] = {   59.002,   1.999,  -25.885, 198 },
    [ZONE.NORTHERN_SAN_DORIA] = {    0.000,   0.499,   49.910, 192 },
    [ZONE.BASTOK_MINES]       = {   21.893,   0.000,  -88.895, 144 },
    [ZONE.BASTOK_MARKETS]     = { -259.330, -12.021,  -78.102,  17 },
    [ZONE.WINDURST_WATERS]    = {  -53.708,  -5.368,  214.584, 209 },
    [ZONE.WINDURST_WOODS]     = {  105.558,  -4.999,  -54.148, 140 },
}
local MOOGLE_LOOK = '0x0000520000000000000000000000000000000000' -- model 82, the moogle

-- the cherry trees count the most in the three towns the later festivals decorated
local BLOSSOM_TOWNS = { [ZONE.NORTHERN_SAN_DORIA] = true, [ZONE.BASTOK_MINES] = true, [ZONE.WINDURST_WOODS] = true }

-- best guess until checked in game: the one set of seven that turns up in all six festival towns (3 or 4 per town)
local GUESS = { [1287] = 'decor', [1293] = 'decor', [1294] = 'decor' }

local MARKS_MODULE = 'modules/custom/lua/doll_festival_marks'
local MARKS_FILE   = 'modules/custom/lua/doll_festival_marks.lua'
local NOW_FILE     = 'modules/custom/lua/festival_now.txt'

local state =
{
    active = nil,
    moogle = {},  -- [zoneId] = dynamic NPC id
    shown  = {},  -- [npcId] = 'decor' | 'tree'
    peek   = {},  -- [zoneId] = { index, ids }
    botTick = 0,
}
D.state = state

-----------------------------------
-- small helpers
-----------------------------------
local function channel(name, fallback)
    return (xi.msg and xi.msg.channel and xi.msg.channel[name]) or fallback
end

local SAY = channel('NS_SAY', 13)
local SYS = channel('SYSTEM_3', 29)

local function pick(list)
    return list[math.random(1, #list)]
end

local function fill(text, vars)
    return (tostring(text or ''):gsub('{(%w+)}', function(k)
        local v = vars and vars[k]
        return v ~= nil and tostring(v) or '{' .. k .. '}'
    end))
end

local function sys(player, text)
    player:printToPlayer(text, SYS)
end

local function moogleSay(player, text, vars)
    player:printToPlayer(fill(text, vars), SAY, 'Moogle')
end

local function isBot(entity)
    return BotIsBot ~= nil and entity ~= nil and BotIsBot(entity:getID()) == true
end

local function year()
    return tonumber(os.date('%Y')) or 0
end

-----------------------------------
-- on or off
-----------------------------------
D.inDates = function(t)
    local d = os.date('*t', t)
    local md = d.month * 100 + d.day
    if md >= D.START and md <= D.FINISH then
        return true
    end

    local ymd = d.year * 10000 + md
    for _, e in ipairs(D.EXTRA) do
        if ymd >= e.start and ymd <= e.finish then
            return true
        end
    end

    return false
end

D.isActive = function()
    local mode = 'date'
    if xi.eventsMode and xi.eventsMode.get then
        mode = xi.eventsMode.get()
    end

    if mode == 'off' or (xi.eventsMode and xi.eventsMode.allowed and not xi.eventsMode.allowed('doll_festival')) then
        return false
    elseif mode == 'on' then
        return true
    end

    return D.inDates()
end

-- out of era (2008): set by modules/wedding/lua/doll_festival_2008.lua, which only loads with the Out-of-era switch on
D.outOfEra = function()
    return D.furnishings == true
end

-----------------------------------
-- decorations
-----------------------------------
local function loadMarks()
    package.loaded[MARKS_MODULE] = nil
    local ok, marks = pcall(require, MARKS_MODULE)
    if ok and type(marks) == 'table' then
        return marks
    end

    return {}
end

-- what each set in a town is: a mark, else the guess, else nothing
D.kindOf = function(zoneId, model, marks)
    marks = marks or loadMarks()
    local zm = marks[zoneId]
    if type(zm) == 'table' and zm[model] ~= nil then
        local kind = zm[model]
        return (kind == 'decor' or kind == 'tree') and kind or nil
    end

    return GUESS[model]
end

D.sets = function(zoneId)
    return SPOTS[zoneId] or {}
end

local function setStatus(id, on)
    local npc = GetNPCByID(id)
    if npc then
        npc:setStatus(on and xi.status.NORMAL or xi.status.DISAPPEAR)
    end

    return npc
end

local function spawnMoogle(zone)
    local zoneId = zone:getID()
    if state.moogle[zoneId] then
        return GetNPCByID(state.moogle[zoneId])
    end

    local pos = MOOGLES[zoneId]
    local npc = zone:insertDynamicEntity({
        objtype    = xi.objType.NPC,
        name       = 'DollFestivalMoogle',
        packetName = 'Moogle',
        look       = MOOGLE_LOOK,
        x          = pos[1],
        y          = pos[2],
        z          = pos[3],
        rotation   = pos[4],
        widescan   = 1,
        onTrigger  = function(player, npc)
            D.moogleTrigger(player, npc)
        end,
    })
    if npc then
        state.moogle[zoneId] = npc:getID()
    end

    return npc
end

local function applyZone(zoneId, on)
    local zone = GetZone(zoneId)
    if not zone then
        return
    end

    local marks = loadMarks()
    for _, set in ipairs(D.sets(zoneId)) do
        local kind = on and D.kindOf(zoneId, set.model, marks) or nil
        for _, id in ipairs(set.ids) do
            if kind then
                setStatus(id, true)
                state.shown[id] = kind
            elseif state.shown[id] then
                setStatus(id, false)
                state.shown[id] = nil
            end
        end
    end

    if on then
        local npc = spawnMoogle(zone)
        if npc then
            npc:setStatus(xi.status.NORMAL)
        end
    elseif state.moogle[zoneId] then
        setStatus(state.moogle[zoneId], false)
    end
end

D.applyZone = applyZone

local function writeNow(on)
    local handle = io.open(NOW_FILE, 'w')
    if not handle then
        return
    end

    if on then
        handle:write('The Doll Festival is on in the three nations: cherry blossoms, Far Eastern screens and parasols in town, ' ..
            'and festival moogles hand out rice cakes that turn whoever eats one into a little girl for an hour.\n')
    end

    handle:close()
end

local function refresh(force)
    local on = D.isActive()
    if on == state.active and not force then
        return
    end

    state.active = on
    print('[doll_festival] The Doll Festival is ' .. (on and 'on' or 'off'))
    for zoneId in pairs(CITY_NAME) do
        applyZone(zoneId, on)
    end

    writeNow(on)
end

D.refresh = refresh

-----------------------------------
-- the 2005 party: ten in the area, and the doll stage's mix
-----------------------------------
local MALE_RACE = { [1] = true, [3] = true, [5] = true, [8] = true } -- Hume, Elvaan, Tarutaru male; Galka

local function isMale(entity)
    local ok, gender = pcall(function()
        return entity:getGender()
    end)
    if ok and (gender == 0 or gender == 1) and entity:isPC() then
        return gender == 1
    end

    local okR, race = pcall(function()
        return entity:getRace()
    end)
    return okR and MALE_RACE[race] == true
end

-- everyone in your party or alliance (squad mates and bot players too) who is in the same area
D.festivalGroup = function(player)
    local zoneId = player:getZoneID()
    local seen, men, women, count = {}, 0, 0, 0
    local function add(e)
        if e and not seen[e:getID()] and e:getZoneID() == zoneId then
            seen[e:getID()] = true
            count = count + 1
            if isMale(e) then
                men = men + 1
            else
                women = women + 1
            end
        end
    end

    local okA, alliance = pcall(function()
        return player:getAlliance()
    end)
    local members = (okA and type(alliance) == 'table' and #alliance > 0) and alliance or { player }
    for _, member in ipairs(members) do
        local okP, party = pcall(function()
            return member:getPartyWithTrusts()
        end)
        if okP and type(party) == 'table' then
            for _, e in ipairs(party) do
                add(e)
            end
        else
            add(member)
        end
    end

    add(player)
    return count, men, women
end

-----------------------------------
-- the moogles
-----------------------------------
local function randomCake()
    return D.CAKES[math.random(1, #D.CAKES)]
end

-- what the moogle gives today: { { id, qty }... }, the cake names, and which line it says
D.giftFor = function(player)
    local count, men, women = D.festivalGroup(player)
    if count >= PARTY_SIZE and men >= STAGE_MEN and women >= STAGE_WOMEN then
        local items, names = {}, {}
        for _, cake in ipairs(D.CAKES) do
            table.insert(items, { cake.id, 1 })
            table.insert(names, cake.name)
        end

        return items, names, 'stage'
    elseif count >= PARTY_SIZE then
        local a, b = randomCake(), randomCake()
        if a.id == b.id then
            return { { a.id, 2 } }, { a.name, a.name }, 'party'
        end

        return { { a.id, 1 }, { b.id, 1 } }, { a.name, b.name }, 'party'
    end

    local cake = randomCake()
    return { { cake.id, 1 } }, { cake.name }, 'given'
end

D.moogleTrigger = function(player, npc)
    if not state.active then
        return
    end

    local y = year()
    if player:getCharVar('[Doll]Intro') ~= y then
        player:setCharVar('[Doll]Intro', y)
        for i, line in ipairs(LINES.moogle.intro) do
            if i == 1 then
                moogleSay(player, line)
            else
                player:timer((i - 1) * 2500, function(p)
                    moogleSay(p, line)
                end)
            end
        end

        player:timer(#LINES.moogle.intro * 2500, function(p)
            D.giveToday(p)
        end)
        return
    end

    D.giveToday(player)
end

D.giveToday = function(player)
    if player:getPlaytime(false) < VANA_DAY_SECONDS then
        moogleSay(player, pick(LINES.moogle.newbie))
        return false
    end

    local today = VanadielUniqueDay()
    if player:getCharVar('[Doll]Day') == today then
        moogleSay(player, pick(LINES.moogle.already))
        return false
    end

    local items, names, kind = D.giftFor(player)
    if player:getFreeSlotsCount() < #items then
        moogleSay(player, pick(LINES.moogle.full))
        return false
    end

    moogleSay(player, pick(LINES.moogle.hello))
    if kind == 'given' then
        moogleSay(player, pick(LINES.moogle.given), { cake = names[1] })
        if math.random() < 0.3 then
            moogleSay(player, pick(LINES.moogle.tenHint))
        end
    else
        moogleSay(player, pick(LINES.moogle[kind]))
    end

    if not npcUtil.giveItem(player, items) then
        return false
    end

    player:setCharVar('[Doll]Day', today)
    return true
end

-----------------------------------
-- the delivery box: 2007's rice cakes, 2008's furnishings
-----------------------------------
local function send(player, itemId, qty, from)
    local ok, code = pcall(SendItemToDeliveryBox, player:getName(), itemId, qty, from)
    return ok and tonumber(code) == 0
end

D.deliver = function(player)
    if isBot(player) then
        return
    end

    local y = year()
    if player:getCharVar('[Doll]Box') ~= y then
        local cake = randomCake()
        if send(player, cake.id, BOX_COUNT, 'M.H.M.U.') then
            player:setCharVar('[Doll]Box', y)
            sys(player, fill(LINES.boxNote, { count = BOX_COUNT, cake = cake.name }))
        end
    end

    if D.outOfEra() and player:getCharVar('[Doll]Furn') ~= y then
        if send(player, D.FESTIVAL_DOLLS, 1, 'M.H.M.U.') and send(player, D.BONBORI, 1, 'M.H.M.U.') then
            player:setCharVar('[Doll]Furn', y)
            sys(player, LINES.furnNote)
        end
    end
end

-----------------------------------
-- cherry blossoms (romance date spots), chatter, squad mates, bot players
-----------------------------------
D.underBlossoms = function(player)
    if not state.active then
        return false
    end

    local zoneId = player:getZoneID()
    if not CITY_NAME[zoneId] then
        return false
    end

    local trees, decor, nearDecor = false, false, false
    for id, kind in pairs(state.shown) do
        local npc = GetNPCByID(id)
        if npc and npc:getZoneID() == zoneId then
            local dist = player:checkDistance(npc)
            if kind == 'tree' then
                trees = true
                if dist <= NEAR_TREE then
                    return true
                end
            else
                decor = true
                if dist <= NEAR_DECOR then
                    nearDecor = true
                end
            end
        end
    end

    if trees then
        return false -- the trees are known here, and you are not under one
    end

    -- the trees are not marked yet: the three blossom towns count, near the decorations (or anywhere if none show)
    if not BLOSSOM_TOWNS[zoneId] then
        return false
    end

    return nearDecor or not decor
end

-- a line for the town chatter (crowds_chat.lua): nil when it should be an ordinary one
D.chatLine = function(zoneId)
    if not state.active or zoneId < 230 or zoneId > 241 or math.random() >= CHAT_SHARE then
        return nil
    end

    return pick(LINES.say)
end

D.chatPair = function(zoneId)
    if not state.active or zoneId < 230 or zoneId > 241 or math.random() >= CHAT_SHARE then
        return nil
    end

    local p = pick(LINES.pairs)
    return p[1], p[2]
end

local SQUAD_CHAT_DIR = (function()
    local ok, paths = pcall(require, 'modules/custom/lua/kit_paths')
    if ok and type(paths) == 'table' and type(paths.kit) == 'string' and paths.kit ~= '' then
        return paths.kit .. 'squad-chat/'
    end

    return 'C:/FFXISOLO/squad-chat/'
end)()
local AI_WAIT_MS = 8000

local function sidecarOffset()
    local handle = io.open(SQUAD_CHAT_DIR .. 'state.json', 'r')
    if not handle then
        return -1
    end

    local text = handle:read('*a') or ''
    handle:close()
    return tonumber(text:match('"in_offset"%s*:%s*(%d+)')) or -1
end

local function squadMates(player)
    local mates = {}
    local ok, party = pcall(function()
        return player:getPartyWithTrusts()
    end)
    for _, e in ipairs(ok and party or {}) do
        if e:getID() ~= player:getID() and e:getLocalVar('SQUAD_ID') ~= 0 then
            table.insert(mates, e)
        end
    end

    return mates
end

local function clean(text)
    return (tostring(text or ''):gsub('[\t\r\n|]', ' '))
end

-- a squad mate notices the festival, once a Vana'diel day: the squad chat AI answers it, else the written line
D.mateNotice = function(player)
    if not state.active or not CITY_NAME[player:getZoneID()] then
        return false
    end

    local today = VanadielUniqueDay()
    if player:getCharVar('[Doll]MateDay') == today then
        return false
    end

    local mates = squadMates(player)
    if #mates == 0 then
        return false
    end

    player:setCharVar('[Doll]MateDay', today)
    local mate = pick(mates)
    local name = mate:getPacketName()
    local city = CITY_NAME[player:getZoneID()]
    local line = fill(pick(LINES.mate), { name = player:getName(), city = city })
    local moment = string.format('The Doll Festival is on in %s: cherry blossoms, screens and parasols, and moogles giving out rice cakes', city)

    if player:getCharVar('SQUAD_CHAT_OFF') ~= 1 then
        local handle = io.open(SQUAD_CHAT_DIR .. 'in.txt', 'a')
        if handle then
            handle:write(string.format('LOVEEV\t%s\t%s\t%s\t%s\n', clean(name), clean(moment), clean(line), 'a squad mate'))
            local mark = handle:seek('end')
            handle:close()
            player:timer(AI_WAIT_MS, function(p)
                if sidecarOffset() < mark then
                    p:printToPlayer(line, xi.msg.channel.PARTY, name)
                end
            end)
            return true
        end
    end

    player:printToPlayer(line, xi.msg.channel.PARTY, name)
    return true
end

-- bot players in the festival towns now and then eat a rice cake
D.botTick = function(now)
    if not state.active then
        return 0
    end

    now = now or os.time()
    if now - state.botTick < BOT_TICK then
        return 0
    end

    state.botTick = now
    local ate = 0
    for zoneId in pairs(CITY_NAME) do
        local zone = GetZone(zoneId)
        local ok, players = pcall(function()
            return zone and zone:getPlayers() or {}
        end)
        for _, p in pairs(ok and players or {}) do
            if isBot(p) and not p:hasStatusEffect(xi.effect.COSTUME) and math.random() < BOT_CAKE_CHANCE then
                local cake = randomCake()
                p:addStatusEffect(xi.effect.COSTUME, { power = cake.power, duration = 3600, origin = p })
                ate = ate + 1
            end
        end
    end

    return ate
end

-----------------------------------
-- !dollpeek (GM): which hidden set is which
-----------------------------------
local function tell(player, text)
    player:printToPlayer(text, SYS)
end

local function hidePeek(zoneId)
    local p = state.peek[zoneId]
    if not p then
        return
    end

    for _, id in ipairs(p.ids) do
        if not state.shown[id] then
            setStatus(id, false)
        end
    end

    state.peek[zoneId] = nil
end

local function markLabel(zoneId, model, marks)
    local zm = marks[zoneId]
    if type(zm) == 'table' and zm[model] ~= nil then
        return 'marked ' .. tostring(zm[model])
    end

    return GUESS[model] and ('guess: ' .. GUESS[model]) or ''
end

D.saveMarks = function(marks)
    local zones = {}
    for zoneId in pairs(marks) do
        table.insert(zones, zoneId)
    end

    table.sort(zones)
    local out = {
        '-----------------------------------',
        '-- Doll Festival: what each hidden decoration set is (written by !dollpeek mark; doll_festival.lua)',
        '-----------------------------------',
        "-- [zone id] = { [model] = 'decor' (shown in the festival), 'tree' (a cherry tree: shown, and a romance date spot)",
        "-- or 'off' (not the festival's) }",
        '-----------------------------------',
        'return',
        '{',
    }
    for _, zoneId in ipairs(zones) do
        local models = {}
        for model in pairs(marks[zoneId]) do
            table.insert(models, model)
        end

        table.sort(models)
        local parts = {}
        for _, model in ipairs(models) do
            table.insert(parts, string.format("[%d] = '%s'", model, marks[zoneId][model]))
        end

        table.insert(out, string.format('    [%d] = { %s }, -- %s', zoneId, table.concat(parts, ', '), CITY_NAME[zoneId] or ''))
    end

    table.insert(out, '}')
    local handle = io.open(MARKS_FILE, 'w')
    if not handle then
        return false
    end

    handle:write(table.concat(out, '\n') .. '\n')
    handle:close()
    return true
end

D.peekCommand = function(player, a1, a2, a3)
    local zoneId = player:getZoneID()
    local sets = D.sets(zoneId)
    if not CITY_NAME[zoneId] or #sets == 0 then
        tell(player, 'Stand in one of the six festival towns (the San d\'Oria, Bastok and Windurst cities) to peek at its decorations.')
        return
    end

    local marks = loadMarks()
    if a1 == nil or a1 == '' or a1 == 'list' then
        tell(player, string.format('%s: %d hidden sets. !dollpeek <n> shows one.', CITY_NAME[zoneId], #sets))
        for i, set in ipairs(sets) do
            local notes = {}
            if set.seen ~= '' then
                table.insert(notes, set.seen)
            end

            local label = markLabel(zoneId, set.model, marks)
            if label ~= '' then
                table.insert(notes, label)
            end

            tell(player, string.format('  %d) model %d, %d of them%s', i, set.model, #set.ids,
                #notes > 0 and (' (' .. table.concat(notes, ', ') .. ')') or ''))
        end

        return
    end

    if a1 == 'hide' then
        hidePeek(zoneId)
        tell(player, 'Hidden again.')
        return
    end

    if a1 == 'mark' then
        local index = tonumber(a2)
        local kind = a3
        local set = index and sets[index]
        if not set or (kind ~= 'decor' and kind ~= 'tree' and kind ~= 'off') then
            tell(player, 'Usage: !dollpeek mark <n> decor|tree|off')
            return
        end

        marks[zoneId] = type(marks[zoneId]) == 'table' and marks[zoneId] or {}
        marks[zoneId][set.model] = kind
        if not D.saveMarks(marks) then
            tell(player, 'Could not write ' .. MARKS_FILE .. '.')
            return
        end

        hidePeek(zoneId)
        applyZone(zoneId, state.active == true)
        tell(player, string.format('Model %d in %s is now %s.', set.model, CITY_NAME[zoneId],
            kind == 'off' and 'not part of the festival' or (kind == 'tree' and 'a cherry tree (and a date spot)' or 'a festival decoration')))
        return
    end

    local index = tonumber(a1)
    local set = index and sets[index]
    if not set then
        tell(player, 'Usage: !dollpeek [list | <n> | hide | mark <n> decor|tree|off]')
        return
    end

    hidePeek(zoneId)
    local nearest, best = nil, nil
    for _, id in ipairs(set.ids) do
        local npc = setStatus(id, true)
        if npc then
            local dist = player:checkDistance(npc)
            if not best or dist < best then
                nearest, best = npc, dist
            end
        end
    end

    state.peek[zoneId] = { index = index, ids = set.ids }
    if nearest then
        tell(player, string.format('Showing set %d (model %d, %d of them). The nearest is %.0f yalms away, at x %.1f, z %.1f.',
            index, set.model, #set.ids, best, nearest:getXPos(), nearest:getZPos()))
    else
        tell(player, string.format('Showing set %d (model %d).', index, set.model))
    end
end

-- single-player server: your own character may use it (like !crowd and !bots)
xi.module.registerCommand('dollpeek', {
    cmdprops  = { permission = 0, parameters = 'sss' },
    onTrigger = function(player, a1, a2, a3)
        D.peekCommand(player, a1, a2, a3)
    end,
})

-----------------------------------
-- hooks
-----------------------------------
for zoneId, zoneName in pairs(ZONE_SCRIPT) do
    m:addOverride('xi.zones.' .. zoneName .. '.Zone.onInitialize', function(zone)
        super(zone)
        if state.active == nil then
            state.active = D.isActive()
            writeNow(state.active)
        end

        if state.active then
            applyZone(zoneId, true)
        end
    end)
end

m:addOverride('xi.server.onServerStart', function()
    super()
    refresh(true)
end)

m:addOverride('xi.server.onJSTMidnight', function()
    super()
    refresh(false)
end)

m:addOverride('xi.server.onTimeServerTick', function()
    super()
    pcall(D.botTick)
end)

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if not state.active or isBot(player) then
        return
    end

    D.deliver(player)
    if not CITY_NAME[player:getZoneID()] then
        return
    end

    local day = tonumber(os.date('%Y%m%d')) or 0
    if player:getCharVar('[Doll]Notice') ~= day then
        player:setCharVar('[Doll]Notice', day)
        sys(player, LINES.notice)
    end

    player:timer(5000, function(p)
        pcall(D.mateNotice, p)
    end)
end)

return m
