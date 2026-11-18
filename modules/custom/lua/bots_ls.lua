-----------------------------------
-- FFXI Offline: bot players - linkshells that come and go. Used by bots.lua.
--
-- Real linkshells (made the way a Linkshell item makes one; real pearls, real linkshell chat), founded by the bots over
-- time like players did. A sociable bot with some levels and gil buys a Linkshell and starts one of its own kind:
--   social   - chat and company, all levels welcome
--   exp      - levelling together around its founder's level (its members party with each other first)
--   craft    - crafters and merchants
--   endgame  - level 60+, battlefields and KSNMs (founded only by a 60+ bot, recruits only 55+)
-- More linkshells appear as the population grows and levels up (the 5 first ones are the "old" ones). Bots join the one
-- that fits them (bigger shells draw more, up to a size), leave now and then, and a shell whose members have all gone
-- breaks up. The leaders shout to recruit in town. You can join any of them: /tell a member "can I join your ls?".
-- Server variables per slot i: [Bots]LS<i> (linkshell id), LSType<i>, LSGen<i> (which shell holds the slot now),
-- LSCount<i> (members, about), LSLevel<i> (exp shells: its level), LSBorn<i> (day), LSPlayer<i> (you are a member:
-- it never breaks up). Bots: [Bot]LS (slot), [Bot]LSGen, [Bot]LSDay (the last day it thought about linkshells).
-----------------------------------
local LS = {}

local MAX_SLOTS     = 16
local OLD_SLOTS     = 5           -- the first five (made before shells came and went)
local FOUND_EVERY   = 30 * 60     -- seconds between two looks for a bot that founds one
local SHELL_PRICE   = 8000        -- gil for the Linkshell
local JOIN_CHANCE   = 0.45        -- a bot without a linkshell looks for one (at its first log in; later now and then)
local LOOK_AGAIN    = 0.12        -- ... a later day
local LEAVE_CHANCE  = 0.015       -- a member leaves, per day it plays
local SIZE          = { social = 40, exp = 25, craft = 25, endgame = 30 }
local TYPES         = { 'social', 'exp', 'craft', 'endgame' }
local TALK_EVERY    = { 150, 420 } -- seconds between two lines in a linkshell you are in
local RECRUIT_EVERY = { 20 * 60, 45 * 60 } -- seconds between two recruiting shouts (server wide)
local COLORS        = { 0xF0F0, 0x0F0F, 0xF00F, 0xFF00, 0x00FF, 0xF0F8, 0x8F0F, 0x0F8F, 0xFF80, 0x80FF, 0xF880, 0x08FF }

local talk         -- bots_chat.lua (AI answers)
local nextTalk = {}
local nextFound = 0
local nextRecruit = 0
local cache        -- [slot] = { id, name, type, gen, count, level, player }
local lastPlayers = {} -- the real players of the last tick
local hello = {}       -- [player id] = { at, gap }: say hi once the shell has filled up after you logged in

-- written lines (bots_dialogue.lua): chatter, hellos, welcomes, reactions to what really happened
local dialogueOk, dialogue = pcall(require, 'modules/custom/lua/bots_dialogue')
if not dialogueOk or type(dialogue) ~= 'table' then
    dialogue = nil
end

local function pick(list)
    return list[math.random(1, #list)]
end

local function now()
    return os.time()
end

local function today()
    return math.floor(os.time() / 86400)
end

local function note(text)
    print('[bots] ' .. text)
end

local function sv(k, i)
    return GetServerVariable('[Bots]' .. k .. i)
end

local function setSv(k, i, v)
    SetServerVariable('[Bots]' .. k .. i, v)
end

function LS.setup(chatModule)
    talk = chatModule
end

local WORDS1 = { 'Crimson', 'Silver', 'Azure', 'Starlight', 'Moonlit', 'Iron', 'Golden', 'Lucky', 'Wandering', 'Black', 'Hidden', 'Northern' }
local WORDS2 = { 'Wolves', 'Tonberries', 'Knights', 'Lanterns', 'Crabs', 'Chocobos', 'Roses', 'Blades', 'Mandragoras', 'Moogles' }
-- shells founded later get a name of their kind
local KIND1 = {
    social  = { 'Cozy', 'Sunny', 'Happy', 'Sleepy', 'Merry', 'Little', 'Tipsy', 'Friendly' },
    exp     = { 'Swift', 'Rising', 'Valiant', 'Bold', 'Wild', 'Iron', 'Steady', 'Rapid' },
    craft   = { 'Golden', 'Silver', 'Copper', 'Mythril', 'Clever', 'Busy', 'Fine', 'Master' },
    endgame = { 'Eternal', 'Shadow', 'Divine', 'Ancient', 'Crimson', 'Storm', 'Dread', 'Royal' },
}
local KIND2 = {
    social  = { 'Moogles', 'Friends', 'Tavern', 'Teapot', 'Picnic', 'Cottage', 'Hearth', 'Lanterns' },
    exp     = { 'Hunters', 'Blades', 'Wolves', 'Raiders', 'Lancers', 'Rangers', 'Vanguard', 'Pack' },
    craft   = { 'Guild', 'Anvil', 'Artisans', 'Hammers', 'Bazaar', 'Merchants', 'Looms', 'Forge' },
    endgame = { 'Legion', 'Dragons', 'Order', 'Valkyries', 'Paladins', 'Covenant', 'Phalanx', 'Crusade' },
}

local function seed()
    local s = GetServerVariable('[Bots]LSSeed')
    if s == 0 then
        s = math.random(1, 100000)
        SetServerVariable('[Bots]LSSeed', s)
    end

    return s
end

-- the same name every time for slot i of an old shell (picked from the word lists by a fixed seed per server)
function LS.nameFor(i)
    local s = seed()
    local a = WORDS1[((s + i * 7) % #WORDS1) + 1]
    local b = WORDS2[((s * 3 + i * 3) % #WORDS2) + 1]
    return (a .. b):sub(1, 20)
end

-- a new shell's name: of its kind, the same for the same slot and generation
local function newName(i, gen, kind)
    local s = seed() + gen * 131 + i * 17
    local a = KIND1[kind][(s % #KIND1[kind]) + 1]
    local b = KIND2[kind][((s * 7 + gen) % #KIND2[kind]) + 1]
    return (a .. b):sub(1, 20)
end

local function nameOf(i, gen, kind)
    if i <= OLD_SLOTS and gen <= 1 then
        return LS.nameFor(i)
    end

    return newName(i, gen, kind)
end

-----------------------------------
-- the registry
-----------------------------------
local function load()
    if cache then
        return cache
    end

    cache = {}
    for i = 1, MAX_SLOTS do
        local id = sv('LS', i)
        local gen = sv('LSGen', i)
        local kind = TYPES[sv('LSType', i)] or nil
        if i <= OLD_SLOTS and id == 0 and gen == 0 and BotMakeLinkshell then
            -- the first five, made at once (as before): the old shells
            local name = LS.nameFor(i)
            local newId = BotMakeLinkshell(name, COLORS[i] or 0xF0F0)
            if newId and newId ~= 0 then
                id = newId
                setSv('LS', i, newId)
                note(string.format('new linkshell %s (id %d)', name, newId))
            end
        end

        if id ~= 0 then
            if gen == 0 then
                gen = 1
                setSv('LSGen', i, 1)
            end

            if not kind then
                kind = ({ 'social', 'exp', 'social', 'craft', 'exp' })[i] or 'social'
                setSv('LSType', i, i == 2 and 2 or (i == 4 and 3 or (i == 5 and 2 or 1)))
            end

            if sv('LSCount', i) == 0 then
                setSv('LSCount', i, 8) -- (the old shells already had members)
            end

            if sv('LSBorn', i) == 0 then
                setSv('LSBorn', i, today())
            end

            cache[i] = { id = id, gen = gen, type = kind, name = nameOf(i, gen, kind), count = sv('LSCount', i), level = sv('LSLevel', i),
                         player = sv('LSPlayer', i) == 1, born = sv('LSBorn', i) }
        end
    end

    return cache
end

function LS.list()
    return load()
end

-- slot -> name of every shell there is now (for bots.lua, crowds_chat.lua)
function LS.names()
    local out = {}
    for i, s in pairs(load()) do
        out[i] = s.name
    end

    return out
end

local function slotOf(bot)
    local i = bot:getCharVar('[Bot]LS')
    local s = i > 0 and load()[i]
    if not s then
        return nil
    end

    local gen = bot:getCharVar('[Bot]LSGen')
    if gen ~= 0 and gen ~= s.gen then
        return nil -- (its shell broke up; another one holds the slot now)
    end

    return i, s
end

-- its linkshell name, or nil
function LS.of(bot)
    local _, s = slotOf(bot)
    return s and s.name or nil
end

function LS.kindOf(bot)
    local _, s = slotOf(bot)
    return s and s.type or nil
end

function LS.slotOf(bot)
    return (slotOf(bot))
end

local function addCount(i, n)
    local s = load()[i]
    if s then
        s.count = math.max(0, s.count + n)
        setSv('LSCount', i, s.count)
    end
end

-----------------------------------
-- joining, leaving, founding
-----------------------------------
local function fits(bot, s)
    local lvl = bot:getMainLvl()
    if s.count >= (SIZE[s.type] or 30) then
        return false
    elseif s.type == 'endgame' then
        return lvl >= 55
    elseif s.type == 'exp' then
        return s.level == 0 or math.abs(lvl - s.level) <= 12
    elseif s.type == 'craft' then
        return bot:getCharVar('[Bot]Goal') == 2 or bot:getCharVar('[Bot]Style') == 2 or math.random() < 0.3
    end

    return true
end

-- its pearl on (the same packet a player sends from the linkshell menu). Needs the rebuilt server (BotEquipPearl);
-- before that a bot keeps its pearl in its bag. (Never addLinkpearl(name, true): that reloads the whole inventory and
-- leaves what the bot wears pointing at freed items - the cause of the crash at login, 2026-11-07.)
local function wearPearl(bot, s)
    if BotEquipPearl and s and s.id and s.id ~= 0 then
        local ok, worn = pcall(BotEquipPearl, bot:getID(), s.id)
        return ok and worn
    end

    return false
end

-- its old pearls off and away (it left)
local function dropPearls(bot)
    if BotDropPearls then
        pcall(BotDropPearls, bot:getID())
    end
end

local function join(bot, i, s)
    local ok, got = pcall(function()
        if BotHasPearl and BotHasPearl(bot:getID(), s.id) then
            return true
        end

        return bot:addLinkpearl(s.name, false)
    end)
    if ok and got then
        wearPearl(bot, s)
        bot:setCharVar('[Bot]LS', i)
        bot:setCharVar('[Bot]LSGen', s.gen)
        addCount(i, 1)
        if xi.bots and xi.bots.diary and s.count > 1 then
            xi.bots.diary(bot, 'joined the linkshell ' .. s.name)
        end
        return true
    end

    return false
end

local function leave(bot)
    local i, s = slotOf(bot)
    if i then
        addCount(i, -1)
        if xi.bots and xi.bots.diary then
            xi.bots.diary(bot, 'left the linkshell ' .. s.name)
        end
    end

    dropPearls(bot)
    bot:setCharVar('[Bot]LS', -1)
    bot:setCharVar('[Bot]LSGen', 0)
end

-- a shell for this bot: one that fits, the bigger the likelier (people join where people are)
local function choose(bot)
    local options, total = {}, 0
    for i, s in pairs(load()) do
        if fits(bot, s) then
            local w = 2 + math.min(s.count, 20)
            options[#options + 1] = { i = i, s = s, w = w }
            total = total + w
        end
    end

    if total == 0 then
        return nil
    end

    local roll = math.random() * total
    for _, o in ipairs(options) do
        roll = roll - o.w
        if roll <= 0 then
            return o.i, o.s
        end
    end

    return options[#options].i, options[#options].s
end

-- A shell you are in (or were just given a pearl of) must have people in it. Bots only looked for a linkshell at
-- log in, so a newly founded shell - or one whose members happened to be offline - was an empty room: this brings
-- online bots without a linkshell (that fit it) in until at least `want` members are on. Returns how many joined.
local nextFill = {}
function LS.fill(i, want)
    local s = load()[i]
    if not s then
        return 0
    end

    local have = #LS.onlineMembers(i)
    local added = 0
    if have >= want then
        return 0
    end

    for id, row in pairs(BotList()) do
        if have + added >= want then
            break
        end

        if row.online then
            local e = GetPlayerByID(id)
            if e and e:getCharVar('[Bot]LS') <= 0 and fits(e, s) and join(e, i, s) then
                added = added + 1
            end
        end
    end

    if added > 0 then
        note(string.format('%d more member(s) joined the linkshell %s (%d online now)', added, s.name, have + added))
    end

    return added
end

-- at login: a bot may join a shell, look again another day, or leave its own
function LS.onLogin(bot)
    local state = bot:getCharVar('[Bot]LS')
    local day = today()
    local first = state == 0
    -- a member wears its pearl every time it logs in (this was only checked once a day: a bot whose pearl was
    -- still in its bag counted as a member but was never listed in the linkshell or heard in it)
    if state > 0 then
        local wi, ws = slotOf(bot)
        if wi then
            wearPearl(bot, ws)
        end
    end

    if bot:getCharVar('[Bot]LSDay') == day and not first then
        return
    end

    bot:setCharVar('[Bot]LSDay', day)
    if state > 0 then
        local i, s = slotOf(bot)
        if not i then
            dropPearls(bot)
            bot:setCharVar('[Bot]LS', -1) -- (its shell broke up)
            bot:setCharVar('[Bot]LSGen', 0)
        elseif math.random() < LEAVE_CHANCE then
            leave(bot)
        else
            wearPearl(bot, s) -- (a pearl it got before the rebuilt server could put it on)
        end

        return
    end

    if math.random() > (first and JOIN_CHANCE or LOOK_AGAIN) then
        bot:setCharVar('[Bot]LS', -1) -- (decided: no linkshell, for now)
        return
    end

    local i, s = choose(bot)
    if not i or not join(bot, i, s) then
        bot:setCharVar('[Bot]LS', -1)
    end
end

-- how many shells this population carries (more as it grows)
local function target(online)
    return math.min(MAX_SLOTS, 3 + math.floor((online or 0) / 30))
end

-- now and then a bot founds one (from LS.tick): which kind is up to who it is and what is missing
function LS.found(bots, onlineCount)
    local list = load()
    local n = 0
    for _ in pairs(list) do
        n = n + 1
    end

    if n >= target(onlineCount) then
        return nil
    end

    local free
    for i = 1, MAX_SLOTS do
        if not list[i] then
            free = i
            break
        end
    end

    if not free then
        return nil
    end

    local have = {}
    for _, s in pairs(list) do
        have[s.type] = (have[s.type] or 0) + 1
    end

    local candidates = {}
    for _, b in ipairs(bots or {}) do
        local lvl = b:getMainLvl()
        if lvl >= 15 and b:getGil() >= SHELL_PRICE + 2000 and b:isAlive() then
            candidates[#candidates + 1] = b
        end
    end

    if #candidates == 0 then
        return nil
    end

    local founder = pick(candidates)
    local lvl = founder:getMainLvl()
    local kinds = {}
    if lvl >= 60 and (have.endgame or 0) < 1 + math.floor(n / 5) then
        kinds[#kinds + 1] = 'endgame'
        kinds[#kinds + 1] = 'endgame'
    end

    if (have.exp or 0) <= (have.social or 0) then
        kinds[#kinds + 1] = 'exp'
    end

    if (have.craft or 0) < 2 and (founder:getCharVar('[Bot]Goal') == 2 or founder:getCharVar('[Bot]Style') == 2) then
        kinds[#kinds + 1] = 'craft'
    end

    kinds[#kinds + 1] = 'social'
    local kind = pick(kinds)
    local gen = sv('LSGen', free) + 1
    local name = nameOf(free, gen, kind)
    local id = BotMakeLinkshell and BotMakeLinkshell(name, COLORS[((free - 1) % #COLORS) + 1]) or 0
    if not id or id == 0 then
        return nil
    end

    founder:delGil(SHELL_PRICE)
    for k, v in pairs({ LS = id, LSGen = gen, LSType = ({ social = 1, exp = 2, craft = 3, endgame = 4 })[kind], LSCount = 0,
                         LSLevel = kind == 'exp' and lvl or 0, LSBorn = today(), LSPlayer = 0 }) do
        setSv(k, free, v)
    end

    cache = nil
    local s = load()[free]
    if founder:getCharVar('[Bot]LS') > 0 then
        leave(founder)
    end

    join(founder, free, s)
    pcall(LS.fill, free, math.random(4, 7)) -- (it starts with a few friends, not as a shell of one)
    note(string.format('%s founds the linkshell %s (%s%s)', founder:getName(), name, kind, kind == 'exp' and (', around level ' .. lvl) or ''))
    if xi.bots and xi.bots.diary then
        xi.bots.diary(founder, 'started a ' .. kind .. ' linkshell called ' .. name, true)
    end
    if BotChat then
        BotChat(founder:getID(), 1, pick({
            string.format('started a new linkshell, %s! %s', name, ({ social = 'everyone welcome', exp = 'lv ' .. math.max(1, lvl - 8) .. '-' .. (lvl + 8) .. ' for exp', craft = 'crafters and merchants', endgame = '60+ for bcnms and nms' })[kind]),
            string.format('%s is recruiting, pst', name),
        }))
    end

    return free
end

-- once a day: shells whose members are gone break up (never one you are in)
function LS.daily()
    local day = today()
    if GetServerVariable('[Bots]LSDayCheck') == day then
        return
    end

    SetServerVariable('[Bots]LSDayCheck', day)
    for i, s in pairs(load()) do
        if not s.player and s.count <= 1 and day - (s.born or day) >= 3 then
            setSv('LS', i, 0)
            setSv('LSType', i, 0)
            setSv('LSCount', i, 0)
            note(string.format('the linkshell %s broke up (its members are gone)', s.name))
            cache = nil
        end
    end
end

-----------------------------------
-- you and the shells
-----------------------------------
local function playerLs(player)
    return player:getCharVar('[Bots]LS')
end

-- you asked a member for a pearl (in a tell): true when it sent one
function LS.askedPearl(bot, playerName, text)
    local lower = string.lower(text or '')
    if not (lower:find('%f[%a]ls%f[%A]') or lower:find('linkshell') or lower:find('pearl')) then
        return false
    end

    if not (lower:find('join') or lower:find('pearl') or lower:find('invite') or lower:find('can i') or lower:find('let me')) then
        return false
    end

    local i, s = slotOf(bot)
    local player = GetPlayerByName and GetPlayerByName(playerName)
    if not i or not player then
        return false
    end

    if s.type == 'endgame' and player:getMainLvl() < 55 then
        BotTell(bot:getID(), playerName, pick({ 'sorry, we are an endgame ls, 55+ only. come back when you are higher!', 'we only take 55+ atm, sorry' }))
        return true
    end

    local ok, got = pcall(function()
        return player:addLinkpearl(s.name, false) -- (into your bag: equip it from the Linkshell menu)
    end)
    if ok and got then
        player:setCharVar('[Bots]LS', i)
        player:setCharVar('[Bots]LSGen', s.gen)
        player:setCharVar('[Bots]LSNew', 1) -- (your first words in the shell get a welcome)
        setSv('LSPlayer', i, 1)
        s.player = true
        print(string.format('[bots] %s gave %s a pearl of %s', bot:getName(), playerName, s.name))
        pcall(LS.fill, i, 8) -- (never an empty linkshell)
        nextFill[i] = now() + 300
        BotTell(bot:getID(), playerName, pick({ 'sure! sending you a pearl, welcome to ' .. s.name .. ' :)', 'of course, here you go! welcome', 'np, pearl sent, put it on and say hi in ls!' }))
        return true
    end

    return false
end

-- your shell's slot, if it is still that shell
local function yourSlot(player)
    local i = playerLs(player)
    local s = i > 0 and load()[i]
    if not s then
        return 0
    end

    local gen = player:getCharVar('[Bots]LSGen')
    if gen ~= 0 and gen ~= s.gen then
        return 0
    end

    if not s.player then
        s.player = true
        setSv('LSPlayer', i, 1) -- (you are a member: it never breaks up)
    end

    return i
end

-- you said something in linkshell chat: a member may answer (AI)
function LS.onPlayerChat(player, text)
    local i = yourSlot(player)
    if i <= 0 then
        return
    end

    local members = LS.onlineMembers(i)
    if #members == 0 then
        return
    end

    -- your first words after joining: the members welcome you
    if dialogue and player:getCharVar('[Bots]LSNew') == 1 then
        player:setCharVar('[Bots]LSNew', 0)
        local ok, done = pcall(dialogue.onPlayerJoined, player, members)
        if ok and done then
            return
        end
    end

    if talk then
        talk.onLs(player, text, members)
    end
end

function LS.onlineMembers(i)
    local out = {}
    for id, row in pairs(BotList()) do
        if row.online then
            local e = GetPlayerByID(id)
            if e and slotOf(e) == i then
                out[#out + 1] = e
            end
        end
    end

    return out
end

-----------------------------------
-- written dialogue in the shell you are in (bots_dialogue.lua). Nobody talks in a shell no real player hears.
-----------------------------------
local function shellPlayers(i)
    local out = {}
    for _, p in ipairs(lastPlayers) do
        local ok, slot = pcall(yourSlot, p)
        if ok and slot == i then
            out[#out + 1] = p
        end
    end

    return out
end

-- something happened to a bot (bots.lua diary): in a shell you are in, it may say so and the others react
function LS.onBotEvent(bot, text)
    local i = dialogue and slotOf(bot)
    if not i or #shellPlayers(i) == 0 then
        return false
    end

    return dialogue.onBotEvent(bot, text, LS.onlineMembers(i), 'ls' .. i)
end

-- a member logged in / is about to log out while you are on
function LS.onBotLogin(bot)
    local i = dialogue and slotOf(bot)
    local players = i and shellPlayers(i) or {}
    if #players == 0 then
        return false
    end

    return dialogue.onBotLogin(bot, LS.onlineMembers(i), players[1])
end

function LS.onBotLogout(bot)
    local i = dialogue and slotOf(bot)
    local players = i and shellPlayers(i) or {}
    if #players == 0 then
        return false
    end

    return dialogue.onBotLogout(bot, LS.onlineMembers(i), players[1])
end

-- you logged in: once your shell has members on (it fills up on the next tick), they say hi
function LS.onPlayerLogin(player)
    if not dialogue or yourSlot(player) <= 0 then
        return
    end

    local day = today()
    local last = player:getCharVar('[Bots]LSLastDay')
    player:setCharVar('[Bots]LSLastDay', day)
    hello[player:getID()] = { at = now() + math.random(10, 20), gap = last > 0 and (day - last) or 0 }
end

-- !bots dialogue test: a member says something now
function LS.dialogueTest(player)
    local i = yourSlot(player)
    if i <= 0 then
        return 'You are not in a bot linkshell (ask a member for a pearl in a tell).'
    end

    local members = LS.onlineMembers(i)
    if #members == 0 then
        return 'Nobody from your linkshell is on right now.'
    end

    if dialogue and dialogue.lsAmbient(members, player) then
        return 'A member of your linkshell will say something in a few seconds (linkshell 2 if you wear it there).'
    end

    return 'Nothing fresh to say right now (every line was used lately). Try again later.'
end

local RECRUIT = {
    social  = { '%s recruiting! social ls, all levels welcome, pst', 'looking for chill people? %s has room, pst for a pearl', '%s: chat, help, good times. pst' },
    exp     = { '%s (exp ls, lv %d-%d) recruiting, we party a lot, pst', 'join %s if you are around %d and want exp pts, pst' },
    craft   = { '%s recruiting crafters and merchants, pst', '%s: crafting ls, we share mats and tips, pst' },
    endgame = { '%s recruiting 60+ for bcnms, ksnms and nms, pst with job/lvl', 'endgame ls %s looking for active 60+, pst' },
}

-- now and then (called every second from bots.lua): founding, a recruiting shout, and a line in a shell you are in
function LS.tick(players)
    local t = now()
    pcall(LS.daily)
    lastPlayers = players or {}
    if dialogue then
        pcall(dialogue.tick) -- (written lines whose "typing" is done)
    end

    if t >= nextFound then
        nextFound = t + FOUND_EVERY + math.random(-300, 300)
        local bots, n = {}, 0
        for id, row in pairs(BotList()) do
            if row.online then
                n = n + 1
                local e = GetPlayerByID(id)
                if e and math.random() < 0.2 then
                    bots[#bots + 1] = e
                end
            end
        end

        if math.random() < 0.5 then
            pcall(LS.found, bots, n)
        end
    end

    if t >= nextRecruit then
        nextRecruit = t + math.random(RECRUIT_EVERY[1], RECRUIT_EVERY[2])
        local list = {}
        for i, s in pairs(load()) do
            if s.count < (SIZE[s.type] or 30) * 0.7 then
                list[#list + 1] = { i = i, s = s }
            end
        end

        if #list > 0 then
            local o = pick(list)
            local members = LS.onlineMembers(o.i)
            if #members > 0 and BotChat then
                local b = pick(members)
                local lvl = o.s.level > 0 and o.s.level or b:getMainLvl()
                local line = string.format(pick(RECRUIT[o.s.type] or RECRUIT.social), o.s.name, math.max(1, lvl - 8), lvl + 8)
                BotChat(b:getID(), 1, line)
            end
        end
    end

    for _, player in ipairs(players or {}) do
        local i = yourSlot(player)
        if i > 0 then
            -- every 5 minutes: enough members on in your shell (people log out over the evening)
            if t >= (nextFill[i] or 0) then
                nextFill[i] = t + 300
                pcall(LS.fill, i, 6)
            end

            -- you logged in a moment ago: the members on say hi
            local h = hello[player:getID()]
            if h and t >= h.at then
                hello[player:getID()] = nil
                local members = LS.onlineMembers(i)
                if #members > 0 and dialogue then
                    pcall(dialogue.onPlayerLogin, player, members, h.gap)
                    nextTalk[i] = math.max(nextTalk[i] or 0, t + 90) -- (no chatter on top of the hellos)
                end
            end

            nextTalk[i] = nextTalk[i] or (t + math.random(30, 90))
            if t >= nextTalk[i] then
                nextTalk[i] = t + math.random(TALK_EVERY[1], TALK_EVERY[2])
                local members = LS.onlineMembers(i)
                local said = false
                if #members > 0 and dialogue then
                    local ok, done = pcall(dialogue.lsAmbient, members, player)
                    said = ok and done
                end

                if not said and #members > 0 and xi.crowds and xi.crowds.sayLine then
                    local b = pick(members)
                    local JOBS = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP' }
                    local ok, line = pcall(xi.crowds.sayLine, { name = b:getName(), job = JOBS[b:getMainJob()] or 'WAR', lvl = b:getMainLvl() }, b:getZoneID())
                    if ok and type(line) == 'string' and line ~= '' and not (b:getMainLvl() < 70 and (line:lower():find('meri') or line:find('75'))) then
                        -- (bots wear their pearl as linkshell 2, and kind 5 is linkshell 1: every line they said in
                        --  the shell was dropped by the server. Both are sent; the one it does not wear is ignored.)
                        BotChat(b:getID(), 5, line)
                        BotChat(b:getID(), 27, line)
                    end
                end
            end
        end
    end
end

-- for the tests
LS._reset = function()
    cache, nextFound, nextRecruit, nextTalk, nextFill = nil, 0, 0, {}, {}
    lastPlayers, hello = {}, {}
end

return LS
