-- Stand-in test for modules/wedding/lua/wedding_romance.lua and the ceremony with a squad mate or bot
-- (run: luajit test_wedding_romance.lua <server dir>)
local server = arg[1] or '.'
local checks, failed = 0, 0
local function ok(cond, what)
    checks = checks + 1
    if not cond then
        failed = failed + 1
        print('FAIL: ' .. what)
    end
end

local now = 1795000000
local queue = {}
local function schedule(ms, fn, ent) queue[#queue + 1] = { at = now + ms / 1000, fn = fn, ent = ent } end
local function advance(seconds)
    local target = now + seconds
    while true do
        table.sort(queue, function(a, b) return a.at < b.at end)
        local nxt = queue[1]
        if not nxt or nxt.at > target then break end
        table.remove(queue, 1)
        now = nxt.at
        nxt.fn(nxt.ent)
    end
    now = target
end
os.time = function() return math.floor(now) end
math.random = function(a, b) return a or 1 end -- first line of every pool

bit = bit or require('bit')
xi = {
    zone = { CHATEAU_DORAGUILLE = 233, METALWORKS = 237, HEAVENS_TOWER = 242, SELBINA = 248, LOWER_JEUNO = 245,
             UPPER_JEUNO = 244, PORT_JEUNO = 246, RULUDE_GARDENS = 243, WINDURST_WALLS = 239, WINDURST_WOODS = 241,
             NORTHERN_SAN_DORIA = 231, BASTOK_MARKETS = 235, KAZHAM = 250, NORG = 252, RABAO = 247,
             AHT_URHGAN_WHITEGATE = 50, BUBURIMU_PENINSULA = 118, LA_THEINE_PLATEAU = 102, WEST_RONFAURE = 100 },
    item = { MATRIMONY_RING = 15847, MATRIMONY_BAND = 15848, WEDDING_RING = 15845, LILAC = 900, RUBY = 901,
             FIRE_CRYSTAL = 4096, BOLT_OF_SILK = 902, BIRD_FEATHER = 903, CHOCOLATE_CAKE = 904, IRON_ORE = 905,
             SAN_DORIAN_MARRIAGE_CERTIFICATE = 345, BASTOKAN_MARRIAGE_CERTIFICATE = 346, WINDURSTIAN_MARRIAGE_CERTIFICATE = 347 },
    inv = { INVENTORY = 0 },
    slot = { RING1 = 13, RING2 = 14 },
    msg = { channel = { SAY = 0, TELL = 3, PARTY = 4, SYSTEM_3 = 29 }, area = { SYSTEM = 0, SAY = 1, SHOUT = 2 } },
    musicSlot = { ZONE_DAY = 0, ZONE_NIGHT = 1, COMBAT_SOLO = 2, COMBAT_PARTY = 3 },
    action = { category = { ITEM_FINISH = 5 } },
    emote = { BOW = 1, CHEER = 2, CLAP = 3, JOY = 4, PRAISE = 5 },
    emoteMode = { MOTION = 2 },
    wedding = {},
    hardcore = { shareOnline = false },
    module = {},
}
zones = { [233] = { text = { ITEM_OBTAINED = 6000 } } }
utils = {
    rotationToAngle = function(r) return r / 256 * 2 * math.pi end,
    getNearPosition = function(o, off, rad) return { x = o.x + off, y = o.y, z = o.z } end,
    getWorldRotation = function() return 7 end,
}
local commands = {}
xi.module.registerCommand = function(name, t) commands[name] = t end
xi.wedding.onTrigger = function() end

local said, told = {}, {}
local function newEntity(name, opts)
    local e = { name = name, id = opts.id, zone = opts.zone or 233, vars = {}, locals = {}, rings = opts.rings or {},
                pos = { x = 0, y = 0, z = 0 }, party = {}, pc = opts.pc ~= false, menus = {}, bag = opts.bag or {},
                engaged = false }
    function e:getName() return self.name end
    function e:getPacketName() return self.name end
    function e:getID() return self.id end
    function e:getZoneID() return self.zone end
    function e:isPC() return self.pc end
    function e:getCharVar(k) return self.vars[k] or 0 end
    function e:setCharVar(k, v) self.vars[k] = v end
    function e:getLocalVar(k) return self.locals[k] or 0 end
    function e:setLocalVar(k, v) self.locals[k] = v end
    function e:getMaster() return self.master end
    function e:getEquipID(s) return self.rings[s] or 0 end
    function e:getParty() local out = {} for _, p in ipairs(self.party) do if p.pc then out[#out + 1] = p end end return out end
    function e:getPartyWithTrusts() return self.party end
    function e:isEngaged() return self.engaged end
    function e:checkDistance() return 2 end
    function e:printToPlayer(t, ch, who) if who then said[#said + 1] = who .. ':' .. ch .. ':' .. t else told[#told + 1] = t end end
    function e:printToArea(t, ch, area, who) said[#said + 1] = (who or '?') .. ':area:' .. t end
    function e:timer(ms, fn) schedule(ms, fn, self) end
    function e:setFreezeFlag() end
    function e:customMenu(t) self.menus[#self.menus + 1] = t end
    function e:changeMusic() end
    function e:sendEmote() end
    function e:getPos() return self.pos end
    function e:setPos(x, y, z, r) self.pos = { x = x, y = y, z = z } end
    function e:getRotPos() return 0 end
    function e:injectActionPacket() end
    function e:hasItem(id) return (self.bag[id] or 0) > 0 end
    function e:delItem(id, n) if (self.bag[id] or 0) >= n then self.bag[id] = self.bag[id] - n return true end return false end
    function e:delItemAt(id, n) return self:delItem(id, n) end
    function e:addItem(id) self.bag[id] = (self.bag[id] or 0) + 1 return true end
    function e:getFreeSlotsCount() return 10 end
    function e:messageSpecial() end
    return e
end

-- names with a known nature (the same hash as the module)
local function hash(text) local h = 5381 for i = 1, #text do h = (h * 33 + text:byte(i)) % 2147483647 end return h end
local function nameWith(lo, hi, prefix)
    for i = 1, 5000 do local n = prefix .. i if hash(n) % 100 >= lo and hash(n) % 100 < hi then return n end end
end
local QUICK, MOST, NEVER = nameWith(0, 20, 'Quick'), nameWith(20, 65, 'Most'), nameWith(85, 100, 'Never')

local A = newEntity('Hurami', { id = 1, rings = { [13] = 15848 } })
local mate = newEntity(QUICK, { id = 9001, pc = false }); mate.master = A; mate.locals.SQUAD_ID = 77
local bot = newEntity(MOST, { id = 5000 })
local shy = newEntity(NEVER, { id = 9002, pc = false }); shy.master = A; shy.locals.SQUAD_ID = 78
local players = { A, bot }
A.party = { A, mate, bot, shy }

GetPlayerByName = function(n) for _, p in ipairs(players) do if p.name == n then return p end end end
GetNPCByID = function(id) return id == 17731673 and newEntity('Rembard', { id = 17731673, pc = false }) or nil end
GetZone = function() return { getPlayers = function() return players end, getBackgroundMusicDay = function() return 1 end,
    getBackgroundMusicNight = function() return 2 end, getSoloBattleMusic = function() return 3 end, getPartyBattleMusic = function() return 4 end } end
BotIsBot = function(id) return id == 5000 end
BotEmote = function() end
local squadExp = {}
AddSquadExp = function(id, job, gain) squadExp[#squadExp + 1] = { id, gain } return { gained = gain } end

local overrides = {}
Module = { new = function() return { addOverride = function(_, path, fn) overrides[path] = overrides[path] or {} table.insert(overrides[path], fn) end } end }
local realRequire = require
require = function(p) if p:match('^modules/') or p:match('^scripts/') then return true end return realRequire(p) end

-- base functions the overrides wrap
local trades, gifts = {}, 0
xi.squad = { onTrade = function(player, trust, items) trades[#trades + 1] = #items end }
xi.bots = { onGift = function() gifts = gifts + 1 end }
xi.player = { onGameIn = function() end }
xi.experiencePoints = { calculate = function() return { exp = 100 } end }

local function load(file)
    local src = assert(io.open(server .. '/modules/wedding/lua/' .. file)):read('*a')
    assert(loadstring(src, file))()
end
load('wedding_romance.lua')
load('wedding_ceremony.lua')
local function apply(path, base)
    local f = base
    for _, o in ipairs(overrides[path] or {}) do
        local old = f
        setfenv(o, setmetatable({ super = old }, { __index = _G }))
        f = o
    end
    return f
end
local onTrade = apply('xi.squad.onTrade', xi.squad.onTrade)
local onGift = apply('xi.bots.onGift', xi.bots.onGift)
local onGameIn = apply('xi.player.onGameIn', xi.player.onGameIn)
local calc = apply('xi.experiencePoints.calculate', xi.experiencePoints.calculate)
local trigger = apply('xi.wedding.onTrigger', xi.wedding.onTrigger)
local R = xi.romance
local function has(list, text) for _, l in ipairs(list) do if l:find(text, 1, true) then return true end end return false end
local function pick(e, label)
    local mnu = table.remove(e.menus, 1)
    if not mnu then return false end
    for _, o in ipairs(mnu.options) do if o[1]:find(label, 1, true) then o[2](e) return true end end
    return false
end
local pMate = R.partnerOf(A, mate)
local pBot = R.partnerOf(A, bot)
local pShy = R.partnerOf(A, shy)

-- natures and tastes
ok(R.nature(pMate) == 'quick' and R.nature(pBot) == 'most' and R.nature(pShy) == 'never', 'natures come from the name')
local counts = { quick = 0, most = 0, slow = 0, never = 0 }
for i = 1, 2000 do counts[R.nature({ name = 'N' .. i })] = counts[R.nature({ name = 'N' .. i })] + 1 end
ok(counts.never > 200 and counts.never < 400 and counts.most > 800, 'about 15% never, most take a while')
local t = R.tastes(pMate)
local loved, disliked = 0, 0
for k, v in pairs(t) do if v == 'loved' then loved = loved + 1 elseif v == 'disliked' then disliked = disliked + 1 end end
ok(loved == 2 and disliked == 1, 'two loved kinds, one disliked')
ok(t.sweets == nil, 'squad mates never care for sweets (food is a meal for them)')
ok(R.kindOf(900) == 'flowers' and R.kindOf(901) == 'gems' and R.kindOf(4096) == 'crystals' and R.kindOf(902) == 'cloth'
   and R.kindOf(903) == 'feathers' and R.kindOf(904) == 'sweets' and R.kindOf(905) == nil, 'gift kinds from item names')
ok(R.partnerOf(A, A) == nil and R.partnerOf(A, newEntity('Stranger', { id = 2 })) == nil, 'only your mates and bots')

-- registered
ok(commands.date and commands.date.cmdprops.permission == 0, '!date for everyone')

-- time together: once a minute, capped a day
onGameIn(A, false, false)
advance(60)
ok(R.points(A, pMate) == 1 and R.points(A, pBot) == 1, 'a point a minute together')
A.engaged = true
advance(60)
ok(R.points(A, pMate) == 3, 'two a minute while fighting')
advance(3600)
ok(R.points(A, pMate) == 60, 'at most 60 a day from time together')
advance(86400 - 3600 - 120)
A.engaged = false
advance(60)
ok(R.points(A, pMate) == 120, 'a new day, more time counts (another 60)')

-- stages from affection
ok(R.stage(A, pMate) >= R.STAGE.FRIEND, 'a quick one is a friend already')

-- gifts to a mate (through the trade hook): the loved kind, a plain one, the disliked one
local lovedKind, hatedKind
for k, v in pairs(R.tastes(pMate)) do if v == 'loved' and not lovedKind then lovedKind = k elseif v == 'disliked' then hatedKind = k end end
local idOf = { flowers = 900, gems = 901, crystals = 4096, cloth = 902, feathers = 903 }
local plainKind
for k in pairs(idOf) do if R.tastes(pMate)[k] == nil then plainKind = k end end
A.bag = { [idOf[lovedKind]] = 5, [idOf[plainKind]] = 5, [idOf[hatedKind]] = 5, [16000] = 1 }
local before = R.points(A, pMate)
said = {}
onTrade(A, mate, { { itemId = idOf[lovedKind], slot = 1 }, { itemId = 16000, slot = 2 } })
ok(R.points(A, pMate) == before + 25, 'a loved gift is worth 25')
ok(trades[#trades] == 1, 'the rest of the trade (gear, food...) goes on to the squad as before')
ok(A.bag[idOf[lovedKind]] == 4, 'the gift leaves the bag')
ok(has(said, QUICK .. ':4:'), 'the mate answers in party chat')
local status = table.concat(R.status(A, pMate), ' ')
ok(status:find('They love:', 1, true) ~= nil, 'after a loved gift you know what they love')
onTrade(A, mate, { { itemId = idOf[plainKind], slot = 1 } })
ok(R.points(A, pMate) == before + 33, 'a plain gift is worth 8')
onTrade(A, mate, { { itemId = idOf[hatedKind], slot = 1 } })
ok(R.points(A, pMate) == before + 23, 'a disliked gift costs 10')
said = {}
onTrade(A, mate, { { itemId = idOf[lovedKind], slot = 1 } })
ok(R.points(A, pMate) == before + 23 and has(said, 'spoiling'), 'three gifts a day at most')
local tradesBefore = #trades
onTrade(A, mate, { { itemId = 16000, slot = 1 } })
ok(#trades == tradesBefore + 1, 'a trade with no gift in it is the squad\'s as before')

-- gifts to a bot (bots.cpp passes the items)
said = {}
local botBefore = R.points(A, pBot)
onGift(bot, { from = 'Hurami', items = { { id = 904, qty = 1 } } })
ok(gifts == 1, 'the bot still thanks you as before (friendship)')
ok(R.points(A, pBot) ~= botBefore, 'and the gift counts for romance')
ok(has(said, MOST .. ':3:'), 'the bot answers by tell')
onGift(bot, { from = 'Hurami' })
ok(gifts == 2, 'an old-style gift (no items) still works')

-- asking out
A.vars['[Love]PM77'] = 100
said = {}
ok(not R.askOut(A, pMate) and has(said, 'know you well enough'), 'too soon: not yet')
A.vars['[Love]PM77'] = 160 -- quick: 250 x 0.6 = 150
said = {}
ok(R.askOut(A, pMate) and R.stage(A, pMate) == R.STAGE.DATING, 'enough affection: they say yes')
A.vars['[Love]PM78'] = 900
said = {}
ok(not R.askOut(A, pShy) and has(said, 'as a friend'), 'some will only ever be friends')
ok(R.stage(A, pShy) == R.STAGE.CLOSE, 'and stay close friends')

-- dates
A.zone = 100
said, told = {}, {}
ok(not R.date(A, pMate) and has(told, 'not much of a place'), 'not every place is for a date')
A.zone = 248
local p0 = R.points(A, pMate)
ok(R.date(A, pMate) and R.points(A, pMate) == p0 + 40, 'a date in Selbina')
ok(has(said, 'sea breeze'), 'they talk about the place')
ok(not R.date(A, pMate), 'not the same spot twice a day')
advance(21 * 3600)
ok(R.date(A, pMate), 'the same spot the next day')
A.zone = 245
ok(R.date(A, pMate), 'another spot')
ok(A.vars['[Love]NM77'] == 3, 'three dates')
ok(not R.date(A, pBot), 'no dates with someone you are not dating')

-- proposing
A.bag[15847] = nil; A.bag[15848] = nil
told = {}
ok(not R.propose(A, pMate) and has(told, 'need a Matrimony Ring'), 'a ring is needed')
A.bag[15847] = 1
A.vars['[Love]PM77'] = 200
said = {}
ok(not R.propose(A, pMate) and has(said, 'too soon') and A.bag[15847] == 1, 'too soon: they give it back')
A.vars['[Love]PM77'] = 500 -- quick: 600 x 0.6 = 360
A.vars['[Love]NM77'] = 2
said = {}
ok(not R.propose(A, pMate) and has(said, 'too soon') and A.bag[15847] == 1, 'enough affection but only two dates: too soon')
A.vars['[Love]NM77'] = 3
ok(R.propose(A, pMate) and A.bag[15847] == 0, 'engaged; the ring is theirs now')
ok(R.stage(A, pMate) == R.STAGE.ENGAGED and R.engagedPartner(A).id == 77, 'engaged')

-- the ceremony with the mate
A.zone = 233
A.party = { A, mate }
told, said = {}, {}
trigger(A, GetNPCByID(17731673))
ok(#A.menus == 1 and A.menus[1].options[1][1]:find(QUICK, 1, true), 'the Master offers a ceremony with the engaged mate')
pick(A, 'now')
ok(xi.weddingCeremony.state[233] and xi.weddingCeremony.state[233].bKind == 'mate', 'a ceremony with a squad mate')
advance(20)
pick(A, 'I do')
advance(10)
ok(has(said, QUICK .. ':area:I do.'), 'the mate says I do by itself')
advance(30)
ok(A.vars['[Wedding]SpouseMate'] == 77, 'married to the squad mate')
ok(R.stage(A, pMate) == R.STAGE.MARRIED, 'stage married')
ok(A.bag[345] == 1, 'the marriage certificate (San d\'Oria)')
ok(R.married(A), 'one spouse per character')
A.vars['[Love]PB5000'] = 900
told = {}
ok(not R.askOut(A, pBot) and has(told, 'already married'), 'a married character cannot date someone else')

-- the spouse's 5%
AddSquadExp(77, 1, 1000)
AddSquadExp(55, 1, 1000)
ok(squadExp[#squadExp - 1][2] == 1050 and squadExp[#squadExp][2] == 1000, 'the married mate earns 5% more, others not')
bot.vars.WeddingSpouse = 1
ok(calc(bot, nil, {}).exp == 105, 'a married bot earns 5% more')
ok(calc(A, nil, {}).exp == 100, 'the player gets nothing extra')

-- own world only
xi.hardcore.isHub = true
ok(not R.allowed(A), 'not on The Hub')
xi.hardcore.isHub = false
xi.coop = { isGuest = function() return true end }
ok(not R.allowed(A), 'not while visiting')
local before2 = #trades
onTrade(A, mate, { { itemId = 900, slot = 1 } })
ok(#trades == before2 + 1, 'visiting: a trade is the squad\'s as before')
xi.coop = nil

print(string.format('test_wedding_romance: %d checks, %d failed', checks, failed))
os.exit(failed == 0 and 0 or 1)
