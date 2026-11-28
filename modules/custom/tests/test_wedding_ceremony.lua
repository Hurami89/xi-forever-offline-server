-- Stand-in test for modules/wedding/lua/wedding_ceremony.lua (run: luajit test_wedding_ceremony.lua <server dir>)
local server = arg[1] or '.'
local checks, failed = 0, 0
local function ok(cond, what)
    checks = checks + 1
    if not cond then
        failed = failed + 1
        print('FAIL: ' .. what)
    end
end

-- a clock and timers
local now = 1000000
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

-- the world
local ZONE = 233
xi = {
    zone = { CHATEAU_DORAGUILLE = 233, METALWORKS = 237, HEAVENS_TOWER = 242 },
    item = { MATRIMONY_RING = 15847, MATRIMONY_BAND = 15848, WEDDING_RING = 15845 },
    slot = { RING1 = 13, RING2 = 14 },
    msg = { channel = { SAY = 0, SYSTEM_3 = 29 }, area = { SYSTEM = 0, SAY = 1, SHOUT = 2 } },
    musicSlot = { ZONE_DAY = 0, ZONE_NIGHT = 1, COMBAT_SOLO = 2, COMBAT_PARTY = 3 },
    action = { category = { ITEM_FINISH = 5 } },
    emote = { BOW = 1, CHEER = 2, CLAP = 3, JOY = 4, PRAISE = 5 },
    emoteMode = { MOTION = 2 },
    wedding = {},
    hardcore = { shareOnline = true, worldName = 'Test World' },
}
utils = {
    rotationToAngle = function(r) return r / 256 * 2 * math.pi end,
    getNearPosition = function(o, off, rad) return { x = o.x + math.cos(2 * math.pi - rad) * off, y = o.y, z = o.z + math.sin(2 * math.pi - rad) * off } end,
    getWorldRotation = function(a, b) return 7 end,
}
local certificateCalls = 0
xi.wedding.onTrigger = function(player, npc) certificateCalls = certificateCalls + 1 end

local lines, worldLines, music, emotes, shows = {}, {}, {}, {}, 0
local players, nextId = {}, 1
local function newEntity(name, opts)
    local e = { name = name, id = opts.id or nextId, zone = opts.zone or ZONE, vars = {}, rings = opts.rings or {},
                pos = { x = 0, y = 0, z = 0, rot = 0 }, party = {}, pc = opts.pc ~= false, menus = {}, frozen = false }
    nextId = nextId + 1
    function e:getName() return self.name end
    function e:getID() return self.id end
    function e:getZoneID() return self.zone end
    function e:isPC() return self.pc end
    function e:getCharVar(k) return self.vars[k] or 0 end
    function e:setCharVar(k, v) self.vars[k] = v end
    function e:getEquipID(slot) return self.rings[slot] or 0 end
    function e:getParty() return self.party end
    function e:checkDistance(o) return self.far and 40 or 2 end
    function e:printToPlayer(t) lines[#lines + 1] = self.name .. '| ' .. t end
    function e:printToArea(t, ch, area, who)
        if area == xi.msg.area.SYSTEM then worldLines[#worldLines + 1] = t else lines[#lines + 1] = (who or '?') .. ': ' .. t end
    end
    function e:timer(ms, fn) schedule(ms, fn, self) end
    function e:setFreezeFlag(v) self.frozen = v end
    function e:customMenu(t) self.menus[#self.menus + 1] = t end
    function e:changeMusic(slot, track) music[self.name] = music[self.name] or {}; music[self.name][slot] = track end
    function e:sendEmote(to, em) emotes[#emotes + 1] = self.name .. '>' .. (to and to.name or '') .. ':' .. em end
    function e:getPos() return self.pos end
    function e:setPos(x, y, z, r) self.pos = { x = x, y = y, z = z, rot = r } end
    function e:getRotPos() return 0 end
    function e:injectActionPacket() shows = shows + 1 end
    return e
end

local npc = newEntity('Rembard', { id = 17731673, pc = false })
local A = newEntity('Hurami', { rings = { [13] = 15848 } })
local B = newEntity('Kurami', { rings = { [14] = 15847 } })
local bot = newEntity('Humef', { id = 5000 })
players = { A, B, bot }
local function partyUp(...) local list = { ... }; for _, p in ipairs(list) do p.party = list end end
partyUp(A, B)

GetPlayerByName = function(n) for _, p in ipairs(players) do if p.name == n then return p end end end
GetNPCByID = function(id) return id == npc.id and npc or nil end
GetZone = function(id)
    return { getPlayers = function() local out = {} for _, p in ipairs(players) do if p.zone == id then out[#out + 1] = p end end return out end,
             getBackgroundMusicDay = function() return 101 end, getBackgroundMusicNight = function() return 102 end,
             getSoloBattleMusic = function() return 103 end, getPartyBattleMusic = function() return 104 end }
end
BotIsBot = function(id) return id == 5000 end
local botEmotes = 0
BotEmote = function() botEmotes = botEmotes + 1 end

-- module loading: Module:new / addOverride with super
local overrides = {}
Module = { new = function(_, name) return { addOverride = function(self, path, fn) overrides[path] = fn end } end }
local realRequire = require
require = function(p) if p:match('^modules/module_utils') or p:match('^scripts/') then return true end return realRequire(p) end

-- the out file goes to a temp path
local tmp = os.tmpname()
local src = assert(io.open(server .. '/modules/wedding/lua/wedding_ceremony.lua')):read('*a')
src = src:gsub("'modules/custom/lua/hardcore_out.txt'", "'" .. tmp .. "'")
local chunk = assert(loadstring(src, 'wedding_ceremony.lua'))
chunk()
local override = overrides['xi.wedding.onTrigger']
ok(type(override) == 'function', 'override registered on xi.wedding.onTrigger')
setfenv(override, setmetatable({ super = xi.wedding.onTrigger }, { __index = _G }))
local W = xi.weddingCeremony

local function pick(player, label)
    local m = table.remove(player.menus, 1)
    if not m then return false end
    for _, o in ipairs(m.options) do
        if o[1]:find(label, 1, true) then o[2](player); if m.onEnd then m.onEnd(player) end return true end
    end
    return false
end
local function has(list, text) for _, l in ipairs(list) do if l:find(text, 1, true) then return true end end return false end

-- 1. no partner: straight to the certificates
partyUp(A)
override(A, npc)
ok(certificateCalls == 1 and #A.menus == 0, 'no partner in party: the certificate event as before')
partyUp(A, B)

-- 2. no ring: refused
B.rings = {}
override(A, npc)
ok(pick(A, 'now'), 'menu offers a ceremony now')
ok(has(lines, 'wear your ring'), 'a missing ring is explained')
ok(W.state[ZONE] == nil, 'nothing booked without rings')
B.rings = { [14] = 15847 }

-- 3. partner says not yet
lines = {}
override(A, npc); pick(A, 'now')
ok(#B.menus == 1, 'partner is asked')
pick(B, 'Not yet')
ok(has(lines, 'would like to wait'), 'asker hears the partner wants to wait')
ok(W.state[ZONE] == nil, 'nothing booked after not yet')

-- 4. full ceremony now
lines, worldLines = {}, {}
override(A, npc); pick(A, 'now'); pick(B, 'Yes')
ok(W.state[ZONE] and W.state[ZONE].started, 'ceremony starts at once')
ok(music.Hurami and music.Hurami[0] == 153 and music.Kurami[3] == 153, 'Prelude for everyone in the room, all four slots')
ok(not music.Humef, 'bots get no music packets')
ok(A.pos.rot == 128 and B.pos.rot == 128, 'couple placed facing the Master')
-- someone else talks to the Master meanwhile
local C = newEntity('Gio', {}); players[#players + 1] = C; partyUp(C)
override(C, npc)
ok(has(lines, 'under way'), 'others hear a ceremony is under way')
ok(certificateCalls == 1, 'and get no certificate event in the middle of it')
advance(20)
ok(has(lines, 'gathered here'), 'opening words')
ok(#A.menus == 1, 'first vow asked of Hurami')
pick(A, 'I do')
ok(has(lines, 'Hurami: I do.'), 'Hurami says I do')
advance(5)
ok(#B.menus == 1, 'second vow asked of Kurami')
pick(B, 'I do')
advance(30)
ok(has(lines, 'partners for life'), 'pronounced')
ok(music.Hurami[0] == 214, 'Eternal Oath after the vows')
ok(#emotes >= 2, 'the couple bow to each other')
ok(shows == 4, 'four fireworks')
ok(botEmotes >= 1, 'the bot nearby cheers')
ok(A.vars.WeddingSpouse == B.id and B.vars.WeddingSpouse == A.id, 'married: one spouse each')
ok(has(worldLines, 'were married in Chateau'), 'the world hears it')
ok(W.state[ZONE] == nil, 'the palace is free again')
ok(has(lines, 'marriage certificates'), 'told to come back for the certificates')
local out = io.open(tmp):read('*a')
ok(out:find('|wedding|Hurami|Wedding|SAN|0|Kurami|Test World', 1, true) ~= nil, 'online line for the announcer')
advance(130)
ok(music.Hurami[0] == 101 and music.Hurami[3] == 104, 'the area music comes back afterwards')
ok(not A.frozen and not B.frozen, 'nobody left frozen')

-- 5. one spouse per character
local D = newEntity('Kasumi', { rings = { [13] = 15848 } }); players[#players + 1] = D
A.rings = { [13] = 15848 }
partyUp(A, D); lines = {}
override(A, npc); pick(A, 'now')
ok(has(lines, 'already married'), 'a married character cannot marry someone else')
-- renewing vows with the same partner is fine
partyUp(A, B); lines = {}
override(A, npc); pick(A, 'now'); pick(B, 'Yes')
ok(W.state[ZONE] and W.state[ZONE].started, 'the same couple may renew their vows')
-- stopping during a vow
advance(20); pick(A, 'need a moment')
ok(has(lines, 'no hurry') and W.state[ZONE] == nil, 'a vow can stop the ceremony kindly')
ok(music.Hurami[0] == 101, 'music back after a stopped ceremony')

-- 6. in 10 minutes, then one leaves
lines, worldLines = {}, {}
override(A, npc); pick(A, '10 minutes'); pick(B, 'Yes')
ok(W.state[ZONE] and not W.state[ZONE].started, 'booked for later')
ok(has(worldLines, 'will be married in Chateau'), 'the booking is announced')
override(C, npc)
ok(has(lines, 'will be married here at'), 'others see the booking time')
advance(300)
ok(has(lines, 'begins in 5 minutes'), '5-minute reminder')
B.zone = 230
advance(301)
ok(has(lines, 'not here') and W.state[ZONE] == nil, 'called off when the partner is not there')
B.zone = ZONE

-- 7. in 10 minutes, begin early
lines = {}
override(A, npc); pick(A, '10 minutes'); pick(B, 'Yes')
override(A, npc)
ok(pick(A, 'Begin now'), 'the couple can begin early')
ok(W.state[ZONE].started, 'early start runs the ceremony')
-- partner leaves mid-ceremony
B.zone = 230
advance(20)
ok(has(lines, 'has left us') and W.state[ZONE] == nil, 'leaving mid-ceremony calls it off')
B.zone = ZONE

-- 8. a partner who does not answer
lines = {}
override(A, npc); pick(A, 'now'); B.menus = {}
advance(61)
ok(has(lines, 'did not answer') and W.state[ZONE] == nil, 'no answer in a minute: nothing booked')

-- 9. a partner too far away, a bot in the party
B.far = true; lines = {}
override(A, npc)
ok(certificateCalls == 2, 'partner far away: certificates as before (no ceremony menu)')
B.far = false
partyUp(A, B, bot)
override(A, npc)
ok(pick(A, 'now'), 'a bot player in the party does not count as a third person')
B.menus = {}

-- 9b. three real players in the party: no ceremony, and a ring wearer hears why
partyUp(A, B, C); lines = {}
local before = certificateCalls
override(A, npc)
ok(#A.menus == 0 and certificateCalls == before + 1, 'three real players: no ceremony menu, certificates as before')
ok(has(lines, 'Only the two of you'), 'the ring wearer is told why')
partyUp(C); lines = {}
C.rings = {}
override(C, npc)
ok(not has(lines, 'For a wedding ceremony'), 'someone without a ring is not told about ceremonies')

-- 10. the certificate choice reaches the old code
partyUp(A, B)
override(A, npc); pick(A, 'certificates'); advance(1)
ok(certificateCalls == 5, 'Marriage certificates opens the retail event')

os.remove(tmp)
print(string.format('test_wedding_ceremony: %d checks, %d failed', checks, failed))
os.exit(failed == 0 and 0 or 1)
