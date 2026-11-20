-----------------------------------
-- FFXI Offline: bot players - battlefields (BCNMs and KSNMs). Used by bots.lua.
--
-- Orbs are earned the era way: a bot keeps the Beastmen's and Kindred's Seals its kills drop, and when it has enough for
-- an orb that fits its level it takes them to Shami in Port Jeuno (Cloudy 20, Sky 30, Star 40, Comet 50, Moon 60
-- Beastmen's Seals; Clotho / Lachesis / Atropos 30 and Themis 99 Kindred's Seals). The exchange itself is done for it
-- (a bot cannot answer her menu), but the seals are really spent and the orb is a real item in its bag.
-- Now and then a bot carrying an orb gathers a few free bots of about its level (20+) for that battlefield, like
-- players of the era did: the leader shouts for members, they travel to the Burning Circle
-- (Horlais Peak, Waughroon Shrine, Balga's Dais, Ghelsba ...), and enter through the server's own battlefield system
-- (registerBattlefield / enterBattlefield: the level cap, the time limit, the real monsters, the record).
-- They fight it out with their usual fighting (squad job profiles, cures, weapon skills), open the Armoury Crate (the
-- server's own loot rolls: gil to each, items into the party's treasure pool), and come back out. A wipe is a wipe:
-- the orb is gone, they go home. Their names end up in the battlefield records you see at the circle.
-- The catalog is the server's own: xi.battlefield.contents, orb battlefields for 3+ players (no missions, no ENMs).
-----------------------------------
local BF = {}

local CHECK_EVERY  = 900        -- seconds between two tries to start a battlefield run (server wide)
local MIN_LEVEL    = 20
local GATHER_WAIT  = 70         -- seconds the leader waits at the circle for its members to join
local RUN_LIMIT    = 45 * 60    -- a run that takes longer than this is over
local LEAVE_AFTER  = 75         -- seconds after a win before it walks out on its own
local START_CHANCE = 0.6
local ORB_EVERY    = 120        -- seconds between two looks for bots with enough seals for an orb
local SHAMI        = { x = -53.9, y = 0, z = 10.8, zone = 246 } -- Port Jeuno
local SEAL         = { BEASTMEN = 1126, KINDRED = 1127 }
-- orb -> { seal, cost } (Shami's own price list, scripts/zones/Port_Jeuno/npcs/Shami.lua)
local ORBS = {
    [1551] = { 1126, 20, 'Cloudy Orb' }, [1552] = { 1126, 30, 'Sky Orb' }, [1131] = { 1126, 40, 'Star Orb' },
    [1177] = { 1126, 50, 'Comet Orb' }, [1130] = { 1126, 60, 'Moon Orb' },
    [1175] = { 1127, 30, 'Clotho Orb' }, [1178] = { 1127, 30, 'Lachesis Orb' }, [1180] = { 1127, 30, 'Atropos Orb' },
    [1553] = { 1127, 99, 'Themis Orb' },
}

local state, hunt, craft
local nextCheck = 0
local nextOrbCheck = 0
local catalogCache
local runs = 0

local function now()
    return os.time()
end

local function rnd(a, b)
    return math.random(a, b)
end

local function pick(list)
    return list[rnd(1, #list)]
end

local function note(text)
    print('[bots] ' .. text)
end

function BF.setup(brainState, huntModule, craftModule)
    state, hunt, craft = brainState, huntModule, craftModule
end

-----------------------------------
-- the catalog: the server's orb battlefields
-----------------------------------
function BF.catalog()
    if catalogCache then
        return catalogCache
    end

    local out = {}
    local contents = xi.battlefield and xi.battlefield.contents or {}
    for id, c in pairs(contents) do
        if type(c) == 'table' and not c.isMission and not c.experimental and type(c.requiredItems) == 'table' and
            type(c.requiredItems[1]) == 'number' and (#(c.requiredKeyItems or {}) == 0) and (c.maxPlayers or 0) >= 3 and
            type(c.entryNpcs) == 'table' and c.entryNpcs[1] and c.zoneId then
            out[#out + 1] = { id = id, content = c, cap = c.levelCap or 0, orb = c.requiredItems[1], zone = c.zoneId,
                              entry = c.entryNpcs[1], max = c.maxPlayers }
        end
    end

    table.sort(out, function(a, b)
        return a.id < b.id
    end)
    catalogCache = out
    note(string.format('battlefield catalog: %d orb battlefields for bot parties', #out))
    return out
end

-- does a battlefield fit a level? its cap a bit under to a bit over it (an uncapped one only at 70+)
local function fits(b, level)
    if b.cap > 0 then
        return b.cap <= level + 3 and b.cap >= level - 12
    end

    return level >= 70
end

-- one for this orb that fits a group (an uncapped one only for a full party)
local function choose(orb, level, size)
    local options = {}
    for _, b in ipairs(BF.catalog()) do
        if b.orb == orb and size <= b.max and fits(b, level) and (b.cap > 0 or size >= 5) then
            options[#options + 1] = b
        end
    end

    return #options > 0 and pick(options) or nil
end

local function count(bot, item)
    local ok, n = pcall(function()
        return bot:getItemCount(item)
    end)
    return (ok and n) or 0
end

-- the orb it carries that fits its level, or nil
local function carriedOrb(bot)
    local lvl = bot:getMainLvl()
    for orb in pairs(ORBS) do
        if count(bot, orb) > 0 then
            for _, b in ipairs(BF.catalog()) do
                if b.orb == orb and fits(b, lvl) then
                    return orb
                end
            end
        end
    end

    return nil
end

-- the best orb its seals buy for its level, or nil
local function orbToBuy(bot)
    if carriedOrb(bot) then
        return nil
    end

    local lvl = bot:getMainLvl()
    local best, bestCap
    for orb, o in pairs(ORBS) do
        if count(bot, o[1]) >= o[2] then
            for _, b in ipairs(BF.catalog()) do
                if b.orb == orb and fits(b, lvl) then
                    local cap = b.cap > 0 and b.cap or 99
                    if not best or cap > bestCap then
                        best, bestCap = orb, cap
                    end
                end
            end
        end
    end

    return best
end

local function zoneName(zoneId)
    local ok, name = pcall(function()
        return GetZone(zoneId):getName()
    end)
    return ok and name and name:gsub('_', ' ') or 'the circle'
end

-- where the circle is (the entry NPC), or nil
local function entryPos(b)
    local ok, pos = pcall(function()
        local zone = GetZone(b.zone)
        local list = zone and zone:queryEntitiesByName(b.entry)
        local npc = list and list[1]
        return npc and npc:getPos()
    end)
    return ok and pos or nil
end

-----------------------------------
-- forming a group (xi.bots.onTick, every few minutes)
-----------------------------------
local function free(id)
    local bot = GetPlayerByID(id)
    if not bot or not bot:isAlive() or bot:getMainLvl() < MIN_LEVEL or bot:getPartySize() > 1 or bot:isEngaged() then
        return nil
    end

    local st = state and state[id]
    if not st or st.hunt or st.quest or st.task or st.bf then
        return nil
    end

    return bot
end

-- bots with enough seals go to Shami (at most two at a time)
local function orbTrips(onlineIds)
    local sent = 0
    for _, id in ipairs(onlineIds or {}) do
        local bot = free(id)
        local orb = bot and orbToBuy(bot)
        if orb then
            local st = state[id]
            st.life, st.task = nil, nil
            st.bf = { role = 'orb', orb = orb, phase = 'shami', since = now(), startedAt = now() }
            note(string.format('%s takes its seals to Shami for a %s', bot:getName(), ORBS[orb][3]))
            sent = sent + 1
            if sent >= 2 then
                return
            end
        end
    end
end

function BF.tick(onlineIds)
    local t = now()
    if t >= nextOrbCheck then
        nextOrbCheck = t + ORB_EVERY
        orbTrips(onlineIds)
    end

    if t < nextCheck then
        return
    end

    nextCheck = t + CHECK_EVERY + rnd(-120, 120)
    if math.random() > START_CHANCE then
        return
    end

    local list = {}
    for _, id in ipairs(onlineIds or {}) do
        local bot = free(id)
        if bot then
            list[#list + 1] = bot
        end
    end

    if #list < 3 then
        return
    end

    -- only a bot that carries an orb can lead one
    local leaders = {}
    for _, bot in ipairs(list) do
        if carriedOrb(bot) then
            leaders[#leaders + 1] = bot
        end
    end

    if #leaders == 0 then
        return
    end

    local leader = pick(leaders)
    local orb = carriedOrb(leader)
    local lvl = leader:getMainLvl()
    local want = rnd(3, 6)
    -- its linkshell mates first (an endgame shell runs battlefields together)
    local lsOf = leader:getCharVar('[Bot]LS')
    if lsOf > 0 then
        table.sort(list, function(x, y)
            return (x:getCharVar('[Bot]LS') == lsOf and 1 or 0) > (y:getCharVar('[Bot]LS') == lsOf and 1 or 0)
        end)
    end

    local members = {}
    for _, b in ipairs(list) do
        if b:getID() ~= leader:getID() and math.abs(b:getMainLvl() - lvl) <= 3 and #members < want - 1 then
            members[#members + 1] = b
        end
    end

    if #members < 2 then
        return
    end

    local low = lvl
    for _, m in ipairs(members) do
        low = math.min(low, m:getMainLvl())
    end

    local b = choose(orb, low, #members + 1)
    if not b then
        return
    end

    local pos = entryPos(b)
    if not pos then
        return
    end

    BF.start(leader, members, b, pos)
end

function BF.start(leader, members, b, pos)
    local t = now()
    local name = zoneName(b.zone)
    local capText = b.cap > 0 and ('BCNM ' .. b.cap) or 'KSNM'
    BotChat(leader:getID(), 1, pick({
        string.format('LFM %s at %s, %d more', capText, name, #members),
        string.format('%s run at %s, got the orb, need %d', capText, name, #members),
        string.format('going to %s for %s, pst', name, capText),
    }))

    local lst = state[leader:getID()]
    lst.life, lst.task = nil, nil
    lst.bf = { role = 'leader', b = b, pos = pos, phase = 'gather', since = t, members = {}, startedAt = t }
    for _, m in ipairs(members) do
        local mst = state[m:getID()]
        mst.life, mst.task = nil, nil
        mst.bf = { role = 'member', leaderId = leader:getID(), b = b, pos = pos, phase = 'gather', since = t, startedAt = t }
        lst.bf.members[#lst.bf.members + 1] = m:getID()
    end

    runs = runs + 1
    note(string.format('%s leads a battlefield run (%s at %s, %d bots, %s)', leader:getName(), capText, name, #members + 1, ORBS[b.orb] and ORBS[b.orb][3] or ('orb ' .. b.orb)))
    return true
end

-----------------------------------
-- one second of a battlefield run
-----------------------------------
local function partyIds(bot)
    local ids = {}
    for _, m in pairs(bot:getParty() or {}) do
        ids[m:getID()] = m
    end

    return ids
end

local function finish(bot, st, line)
    local bf = st.bf
    st.bf = nil
    BotHeal(bot:getID(), false)
    if bf and bf.role == 'leader' then
        if line then
            BotChat(bot:getID(), 4, line)
        end
    end

    pcall(function()
        if bot:getPartySize() > 1 then
            BotLeaveParty(bot:getID())
        end
    end)
    st.goHome = true
end

-- the leader registers and everybody enters (the same calls the circle's own menu makes)
local function enter(leader, bf)
    local b = bf.b
    local c = b.content
    local maxAreas = 3
    pcall(function()
        maxAreas = xi.battlefield.getMaxAreas(b.zone) or 3
    end)
    local code = xi.battlefield.returnCode or {}
    local area
    for a = 1, maxAreas do
        local ok, result = pcall(function()
            return leader:registerBattlefield(b.id, a, leader:getID(), c)
        end)
        if ok and result == (code.CUTSCENE or 0) then
            area = a
            break
        end
    end

    if not area then
        return false, 'every arena is busy'
    end

    local entered = pcall(function()
        leader:enterBattlefield()
        leader:setEnteredBattlefield(true)
    end)
    if not entered or not leader:getBattlefield() then
        pcall(function()
            leader:delStatusEffect(xi.effect.BATTLEFIELD)
        end)
        return false, 'could not enter'
    end

    pcall(function()
        leader:delItem(b.orb, 1) -- (the orb, used up)
    end)
    local effect = leader:getStatusEffect(xi.effect.BATTLEFIELD)
    for id, m in pairs(partyIds(leader)) do
        if id ~= leader:getID() and m:getZoneID() == leader:getZoneID() and not m:getBattlefield() then
            pcall(function()
                m:copyStatusEffect(effect)
                m:registerBattlefield(b.id, area, leader:getID(), c)
                if BotIsBot(id) then
                    m:enterBattlefield()
                    m:setEnteredBattlefield(true)
                end
            end)
            if not BotIsBot(id) then
                bf.playerInvited = true -- (you enter through the circle yourself, like any member)
            end
        end
    end

    return true, area
end

-- the monsters of this battlefield: the ones it must beat and the adds, else every monster of the zone in that arena
local function battleMobs(bot, battlefield)
    local ok, mobs = pcall(function()
        return battlefield:getMobs(true, true)
    end)
    if ok and type(mobs) == 'table' and #mobs > 0 then
        return mobs
    end

    local out = {}
    pcall(function()
        local area, bid = battlefield:getArea(), battlefield:getID()
        for _, mob in ipairs(bot:getZone():getMobs() or {}) do
            local mb = mob:getBattlefield()
            if mb and mb:getID() == bid and mb:getArea() == area then
                out[#out + 1] = mob
            end
        end
    end)
    return out
end

-- inside: near the monsters (the client's cutscene would carry a player there)
local function intoArena(bot, battlefield)
    local mobs = battleMobs(bot, battlefield)
    local ok = true

    local mob = ok and type(mobs) == 'table' and mobs[1] or nil
    if not mob then
        return false
    end

    local p = mob:getPos()
    local a = math.random() * 2 * math.pi
    if xi.navguard then xi.navguard.setPos(bot, p.x + 6 * math.cos(a), p.y, p.z + 6 * math.sin(a), 0, nil, p) else bot:setPos(p.x + 6 * math.cos(a), p.y, p.z + 6 * math.sin(a), 0) end
    return true
end

local function target(bot, battlefield)
    local mobs = battleMobs(bot, battlefield)
    local mine = partyIds(bot)
    local best, bestD
    local pos = bot:getPos()
    for _, mob in ipairs(mobs) do
        if mob:isAlive() and mob:getZoneID() == bot:getZoneID() then
            local t = mob:getTarget()
            local onUs = t and mine[t:getID()] ~= nil
            local mp = mob:getPos()
            local d = (mp.x - pos.x) ^ 2 + (mp.z - pos.z) ^ 2 - (onUs and 10000 or 0)
            if not best or d < bestD then
                best, bestD = mob, d
            end
        end
    end

    return best
end

-- the trip to Shami: seals for an orb
local function thinkOrb(bot, st)
    local bf = st.bf
    local t = now()
    if bot:getZoneID() ~= SHAMI.zone then
        if xi.navguard then xi.navguard.setPos(bot, SHAMI.x + rnd(-2, 2), SHAMI.y, SHAMI.z + rnd(-2, 2), 0, SHAMI.zone, { x = SHAMI.x, y = SHAMI.y, z = SHAMI.z }) else bot:setPos(SHAMI.x + rnd(-2, 2), SHAMI.y, SHAMI.z + rnd(-2, 2), 0, SHAMI.zone) end
        return 'zoning'
    end

    bf.at = bf.at or (t + rnd(8, 20)) -- (talking to her)
    if t < bf.at then
        return
    end

    local o = ORBS[bf.orb]
    if o and count(bot, o[1]) >= o[2] and bot:getFreeSlotsCount() > 0 then
        -- (one at a time: delItem only takes from one stack, and the seals may be in several)
        local ok = pcall(function()
            for _ = 1, o[2] do
                if bot:delItem(o[1], 1) == false then
                    error('seals')
                end
            end

            bot:addItem(bf.orb, 1)
        end)
        if ok then
            note(string.format('%s traded %d %s for a %s', bot:getName(), o[2], o[1] == SEAL.BEASTMEN and "Beastmen's Seals" or "Kindred's Seals", o[3]))
            if xi.bots and xi.bots.diary then
                xi.bots.diary(bot, 'finally traded my seals for a ' .. o[3]:lower())
            end
            if math.random() < 0.4 then
                BotChat(bot:getID(), 0, pick({ 'finally enough seals for a ' .. o[3]:lower() .. '!', 'got my orb, who wants to bcnm?', 'traded my seals in :)' }))
            end
        end
    end

    st.bf = nil
    st.goHome = true
end

function BF.think(bot, st)
    local bf = st.bf
    local t = now()
    local id = bot:getID()
    if bf.role == 'orb' then
        return thinkOrb(bot, st)
    end
    if t - bf.startedAt > RUN_LIMIT then
        pcall(function()
            if bot:getBattlefield() then
                bot:leaveBattlefield(1)
            end
        end)
        finish(bot, st, 'took too long, calling it')
        return
    end

    -- members follow the leader's run
    if bf.role == 'member' then
        local leader = GetPlayerByID(bf.leaderId)
        local lst = leader and state[bf.leaderId]
        if not leader or not lst or not lst.bf then
            if bot:getBattlefield() then
                pcall(function()
                    bot:leaveBattlefield(1)
                end)
            end

            finish(bot, st)
            return
        end

        if bf.phase == 'gather' then
            if bot:getZoneID() ~= bf.b.zone then
                if xi.navguard then xi.navguard.setPos(bot, bf.pos.x + rnd(-3, 3), bf.pos.y, bf.pos.z + rnd(-3, 3), 0, bf.b.zone, bf.pos) else bot:setPos(bf.pos.x + rnd(-3, 3), bf.pos.y, bf.pos.z + rnd(-3, 3), 0, bf.b.zone) end
                return 'zoning'
            end

            if bot:getBattlefield() then
                bf.phase = 'fight'
                intoArena(bot, bot:getBattlefield())
            end

            return
        end
    end

    if bf.phase == 'gather' then
        if bot:getZoneID() ~= bf.b.zone then
            if xi.navguard then xi.navguard.setPos(bot, bf.pos.x + rnd(-2, 2), bf.pos.y, bf.pos.z + rnd(-2, 2), 0, bf.b.zone, bf.pos) else bot:setPos(bf.pos.x + rnd(-2, 2), bf.pos.y, bf.pos.z + rnd(-2, 2), 0, bf.b.zone) end
            return 'zoning'
        end

        -- invite the members as they arrive
        local inParty = partyIds(bot)
        local here, all = 0, #bf.members
        for _, mid in ipairs(bf.members) do
            local m = GetPlayerByID(mid)
            if m and m:getZoneID() == bot:getZoneID() then
                if not inParty[mid] and (bf.invited or {})[mid] == nil then
                    bf.invited = bf.invited or {}
                    bf.invited[mid] = t
                    BotInvite(id, m)
                end

                if inParty[mid] then
                    here = here + 1
                end
            end
        end

        -- you joined the run: it waits for you at the circle (8 minutes at most)
        local you = bf.player and GetPlayerByID(bf.player)
        local youInParty = you and inParty[bf.player] ~= nil
        local youHere = youInParty and you:getZoneID() == bot:getZoneID()
        if youInParty and not youHere and t - bf.since < 8 * 60 then
            return
        end

        if here >= all or (t - bf.since >= GATHER_WAIT and here >= 2) or (youHere and here >= 1) then
            local ok, why = enter(bot, bf)
            if not ok then
                BotChat(id, 4, why == 'every arena is busy' and 'all arenas taken, lets try later' or 'cant get in, nvm')
                finish(bot, st)
                return
            end

            BotChat(id, 4, bf.playerInvited and 'orb is in! touch the circle to come in, we wait inside' or pick({ 'going in, buff up', 'orb traded, lets do this', 'entering, good luck all' }))
            bf.phase = 'fight'
            bf.since = t
            intoArena(bot, bot:getBattlefield())
        elseif t - bf.since >= GATHER_WAIT * 2 then
            BotChat(id, 4, 'not enough people, cancelling')
            finish(bot, st)
        end

        return
    end

    local battlefield = bot:getBattlefield()
    if not battlefield then
        -- out again: won (and walked out), lost, or the time ran out
        local won = bf.won
        if xi.bots and xi.bots.diary and bf.b then
            local capText = bf.b.cap > 0 and ('BCNM ' .. bf.b.cap) or 'KSNM'
            xi.bots.diary(bot, (won and 'cleared a ' or 'wiped in a ') .. capText .. ' at ' .. zoneName(bf.b.zone), won and bf.role == 'leader')
        end
        if bf.role == 'leader' then
            local capText = bf.b.cap > 0 and ('BCNM ' .. bf.b.cap) or 'KSNM'
            note(string.format('%s\'s battlefield run is over (%s): %s', bot:getName(), capText, won and 'won' or 'not won'))
            bot:setCharVar('[Bot]BCNM', bot:getCharVar('[Bot]BCNM') + (won and 1 or 0))
        end

        if bot:getZoneID() == bf.b.zone and bot:isAlive() then
            if xi.navguard then xi.navguard.setPos(bot, bf.pos.x + rnd(-3, 3), bf.pos.y, bf.pos.z + rnd(-3, 3), 0, nil, bf.pos) else bot:setPos(bf.pos.x + rnd(-3, 3), bf.pos.y, bf.pos.z + rnd(-3, 3), 0) end
        end

        finish(bot, st, won and pick({ 'gg all, thanks!', 'nice run!', 'that went well :)' }) or pick({ 'that was rough, sorry guys', 'well we tried', 'next time...' }))
        return
    end

    local status = battlefield:getStatus()
    local WON = xi.battlefield.status and xi.battlefield.status.WON or 2
    local LOST = xi.battlefield.status and xi.battlefield.status.LOST or 3
    if status == WON then
        if not bf.won then
            bf.won, bf.wonAt = true, t
            if bf.role == 'leader' then
                BotChat(id, 4, pick({ 'we did it!!', 'woo cleared', 'down! check the crate' }))
            end
        end

        -- the leader opens the Armoury Crate (the server's own loot rolls)
        if bf.role == 'leader' and not bf.opened then
            bf.opened = true
            pcall(function()
                local crateId = battlefield:getArmouryCrate()
                if (crateId or 0) == 0 and bf.b.content.armouryCrates then
                    crateId = bf.b.content.armouryCrates[battlefield:getArea()]
                end

                local crate = crateId and crateId ~= 0 and GetNPCByID(crateId)
                if crate then
                    bf.b.content:handleOpenArmouryCrate(bot, crate)
                end
            end)
        end

        if t - bf.wonAt >= LEAVE_AFTER then
            pcall(function()
                bot:leaveBattlefield(1)
            end)
        end

        return
    elseif status == LOST then
        return -- (the server takes them out)
    end

    -- fighting
    local mob = target(bot, battlefield)
    if mob and hunt and hunt.fight then
        BotHeal(id, false)
        hunt.fight(bot, bf, mob)
    elseif not mob then
        bf.attacking = nil
    end
end

-- it joined your party (or something else took over): leave the run
function BF.drop(bot, st)
    if st.bf then
        pcall(function()
            if bot:getBattlefield() then
                bot:leaveBattlefield(1)
            end
        end)
        st.bf = nil
    end
end

function BF.describe(st)
    local bf = st.bf
    if not bf then
        return nil
    end

    if bf.role == 'orb' then
        return 'taking seals to Shami for an orb'
    end

    local capText = bf.b.cap > 0 and ('BCNM ' .. bf.b.cap) or 'KSNM'
    local where = ({ gather = 'getting the party together', fight = 'inside the battlefield' })[bf.phase] or bf.phase
    return string.format('%s at %s (%s)', capText, zoneName(bf.b.zone), where)
end

function BF.runs()
    return runs
end

-- for the tests
BF._reset = function()
    nextCheck, nextOrbCheck, catalogCache, runs = 0, 0, nil, 0
end

BF.SEALS = { SEAL.BEASTMEN, SEAL.KINDRED, 2955, 2956, 2957 } -- (kept, never sold: bots_craft.lua)

return BF
