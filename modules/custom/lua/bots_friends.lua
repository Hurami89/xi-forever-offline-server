-----------------------------------
-- XI: Forever Offline: bot players on your friend list (loaded by bots.lua).
--
-- The friend list is the game's own (Social > Friend List). xi_profile keeps it; bots.cpp answers the requests you
-- send to bot players (xi.bots.onFriendRequest, every 10 seconds) and drops you from a bot's list when you remove it;
-- xi_profile shows a bot friend logging in and out like anyone else (PresenceManager::pollBots).
--
-- This file is how a bot feels about you:
--   - a friendship score per player, kept on the bot (char var '[BotF]<your name>'): a point a minute in your party
--     (two while you fight), three when it gets raised with you, one for a chat by tell (at most every 5 minutes);
--   - each bot has its own nature (always the same, from its name): about a third accept anyone, most want to have
--     met you first, a few are picky. A request it is not ready for waits: it tells you so (once a day at most) and
--     accepts by itself once you have partied enough. Being in the same linkshell counts as having met;
--   - a bot that had a good time in your party sends you a real friend request when the party ends (the game's
--     own request; you accept or turn it down as usual), and answers "can I add you?" by sending you one;
--   - the game's mail (bots.cpp writes it in PlayOnline's own format, xi_profile lights up your message icon): it
--     answers the accepted request ("accepted", so your list updates at once), friends leave you a message or two
--     you find when you come back after a few days away, and a message you send a bot gets an answer (by tell when
--     you are on, by mail when you are off);
--   - friends say hi now and then when they log in or you do, cheer your level ups (every 5th level, and from 70),
--     tell you about their own (every 10th), and sometimes offer to come and help while you fight with room in your
--     party ("sure" / "no thanks" by tell answers them);
--   - friends never stop playing (bots_life.lua turnover), and while you are on they log in more, mostly at their
--     own usual hours (each has a play time: evenings, late nights, daytime...).
--
-- !bots friends shows your bot friends, the requests waiting and the bots that know you best.
-----------------------------------
local F = {}

local REFRESH_S        = 15                -- seconds between two looks at the friend list (BotFriendList)
local POINT_CAP        = 1000
local NEED             = { 0, 3, 15 }      -- points before it accepts: easygoing, most bots, picky
local NATURE_SHARE     = { 30, 85 }        -- (name hash % 100) below 30: easygoing, below 85: most, else picky
local OFFER_AT         = 25                -- points: it asks you to add it when your party with it ends
local OFFER_AGAIN      = 7 * 86400         -- it asks again at most this often (if you did not add it)
local OFFER_VALID      = 14 * 86400        -- after it asked (or said "send me a request"), a request is accepted
local NOT_YET_AGAIN    = 86400             -- "do I know you?" for a waiting request, at most once a day
local CHAT_POINT_GAP   = 5 * 60
local HELLO_GAP        = 4 * 3600          -- a friend's "just got on" tell, at most this often per bot
local HELLO_CHANCE     = 0.4
local LONG_TIME        = 3 * 86400         -- "long time no see" after this long without a hello
local GREET_GAP        = 2 * 3600          -- your log in: one friend online may say hi, at most this often
local GREET_CHANCE     = 0.5
local CHEER_CHANCE     = 0.5
local MILESTONE_CHANCE = 0.5
local HELP_CHECK_S     = 60
local HELP_CHANCE      = 0.25
local HELP_GAP         = 45 * 60           -- the same friend offers to help at most this often
local HELP_PLAYER_GAP  = 20 * 60           -- any friend offering you help, at most this often
local HELP_LEVELS      = 4                 -- a friend offers help within this many levels of you
local HELP_WAIT        = 180               -- seconds the offer stands
local UNASKED_GAP      = 90                -- seconds between two unasked friend tells to the same player
local SENT_TELL_CHANCE = 0.5               -- after sending you a request, it also says so by tell
local DECLINED_WAIT    = 30 * 86400        -- you turned its request down: it does not ask again for this long
local AWAY_MAIL_AFTER  = 2 * 86400         -- you were away this long: friends may have left you mail
local AWAY_MAIL_MAX    = 2
local AWAY_MAIL_CHANCE = 0.5
local SEEN_EVERY       = 600               -- seconds between two notes of "we were both on" (for "long time no see")
local LOGIN_REST       = 45 * 60           -- a friend logged in by preferLogin rests this long before the next time
local LOGIN_CHANCE     = { 0.5, 0.08 }     -- per login slot, a friend at / outside its usual hours
-- usual play hours (local time, end may pass midnight: 27 = 3 am); on weekends they start 3 hours earlier
local HOURS            = { { 18, 24 }, { 20, 27 }, { 9, 17 }, { 6, 13 }, { 12, 22 }, { 15, 23 } }
local JOB_NAMES        = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP' }

-- what they say: { casual, polite } (the polite one for bots whose dialogue pack personality is polite)
local LINES = {
    accept = {
        { 'accepted your friend request :)', 'I accepted your friend request. Good to have you on my list.' },
        { 'added you back!', 'I have added you back. Feel free to send me a tell.' },
        { 'hey, accepted! hit me up anytime', 'Accepted. Send me a tell whenever you like.' },
        { 'friend request accepted o/', 'Friend request accepted. Nice to meet you properly.' },
        { 'sure, added :)', 'Of course. You are on my list now.' },
    },
    acceptLater = {
        { 'ok you grew on me, accepted your request :)', 'I accepted your friend request. It was good adventuring with you.' },
        { 'accepted! good partying with you', 'Your request is accepted. I enjoyed our party.' },
        { 'finally accepted your request lol, we should do that again', 'I have accepted your request at last. We should party again sometime.' },
    },
    notYet = {
        { 'do I know you? :P party with me sometime and I\'ll accept', 'Hello. I do not think we have met yet. Let us adventure together first.' },
        { 'got your friend request, but we haven\'t even partied yet lol', 'I received your friend request. I would like to party with you first, if you do not mind.' },
        { 'hmm I don\'t really know you yet. maybe after a party? :)', 'I prefer to get to know someone before adding them. Perhaps after a party?' },
    },
    offer = {
        { 'that was fun! add me to your friend list if you want, I\'m on a lot', 'That was a good party. Feel free to add me to your friend list.' },
        { 'good party! send me a friend request, let\'s do that again sometime', 'Thank you for the party. Send me a friend request if you would like to team up again.' },
        { 'ty for the pt :) add me if you want, I\'ll accept', 'Thanks for the party. If you add me, I will accept.' },
    },
    askYes = {
        { 'sure! send me a request, I\'ll accept', 'Of course. Send me a request and I will accept it.' },
        { 'yeah of course, add me :)', 'I would like that. Please add me.' },
    },
    askNotYet = {
        { 'maybe after we party sometime :)', 'Perhaps after we have adventured together.' },
        { 'let\'s party first, then sure!', 'I would like to party with you first.' },
    },
    askAlready = {
        { 'we\'re already friends silly :)', 'We are already friends.' },
        { 'you\'re already on my list :D', 'You are already on my friend list.' },
    },
    hello = {
        { 'hey {name}! just got on', 'Hello, {name}. I just logged in.' },
        { 'o/ on for a bit', 'Good to see you on, {name}. I will be around for a while.' },
        { 'hiya {name}, what are you up to?', 'Hello, {name}. What are you working on today?' },
        { 'back on! need anything?', 'I am back on. Let me know if you need anything.' },
    },
    helloBack = {
        { 'long time no see {name}!', 'It has been a while, {name}. Good to see you.' },
        { 'hey stranger :) been a while', 'Hello, {name}. We have not spoken in some time.' },
    },
    greet = {
        { 'hey {name} o/', 'Hello, {name}.' },
        { 'oh hey {name}!', 'Welcome back, {name}.' },
        { 'yo {name}, good to see you on', 'Good to see you online, {name}.' },
    },
    cheer = {
        { 'grats on {lvl}!!', 'Congratulations on level {lvl}!' },
        { 'gz {name}! {lvl} already', 'Congratulations, {name}. Level {lvl} already.' },
        { 'nice, {lvl}! :D', 'Well done on reaching level {lvl}.' },
    },
    milestone = {
        { 'finally {lvl} on {job}!!', 'I reached level {lvl} on {job} today.' },
        { 'just hit {lvl} {job} :D', 'I just reached level {lvl} as a {job}.' },
    },
    help = {
        { 'hey, want a hand? I\'m free, can come to you', 'Would you like some help? I am free and can come to you.' },
        { 'need help? I\'m not doing anything rn', 'If you need help, I am free at the moment.' },
        { 'want me to join you? just say sure', 'I can join you if you like. Just say so.' },
    },
    sentRequest = {
        { 'sent you a friend request :)', 'I have sent you a friend request.' },
        { 'just sent you a friend request!', 'I sent you a friend request. I hope you do not mind.' },
    },
    askSent = {
        { 'sure! sent you one :)', 'Of course. I have sent you a friend request.' },
        { 'yeah! just sent you a request', 'Gladly. Please check your friend requests.' },
    },
    thanks = {
        { 'yay thanks for adding me :)', 'Thank you for accepting my request.' },
        { 'ty for accepting! :D', 'Thank you. I am glad to be on your list.' },
    },
    mailMilestone = {
        { 'finally hit {lvl} on {job}!! we should party sometime', 'I reached level {lvl} on {job} today. We should adventure together soon.' },
        { 'guess who\'s {lvl} {job} now :D', 'Some news: I am a level {lvl} {job} now.' },
    },
    mailMissed = {
        { 'haven\'t seen you around lately! hope you\'re ok. let\'s party when you\'re back', 'I have not seen you in a while. I hope all is well. Let us party when you return.' },
        { 'hey, been a while! send me a tell when you\'re on', 'It has been some time. Send me a tell when you are back online.' },
        { 'where\'d you go? :P the camps feel empty without you', 'I noticed you have been away. I hope to see you back soon.' },
    },
    mailReply = {
        { 'got your message :) see you around!', 'Thank you for your message. I hope to see you soon.' },
        { 'thanks for the msg! I\'ll be on later', 'Thank you for writing. I will be online again later.' },
    },
    helpNo = {
        { 'ok np! have fun', 'Understood. Good luck.' },
        { 'np, ping me if you need me', 'No problem. Send me a tell if you change your mind.' },
    },
}

local env = {}       -- from bots.lua: state, join (joinAskedParty), dialogue, linkshells, life
local cache = { at = nil, byBot = {}, byName = {}, entry = {} }
local flagged = {}   -- [bot id] = true: its [Bot]Friend was set by us
local lastLogin = {} -- [bot id] = time it last logged in
local lastUnasked = {} -- [player name lower] = time of the last unasked friend tell
local players = {}   -- [player name lower] = { lvl, job, best = {[job] = lvl}, helpCheck, helpAt, greetAt }
local helpOffers = {} -- [bot id] = { to = name, untill = time }
local helpAt = {}    -- [bot id] = time it last offered help
local chatAt = {}    -- [bot id .. '|' .. name lower] = time of the last chat point

local function now()
    return os.time()
end

local function rnd(a, b)
    return math.random(a, b)
end

local function lower(s)
    return string.lower(s or '')
end

local function hash(s)
    local h = 7
    for i = 1, #s do
        h = (h * 31 + s:byte(i)) % 2147483647
    end

    return h
end

local function isBot(id)
    return BotIsBot ~= nil and BotIsBot(id)
end

local function botOnline(id)
    if BotIsOnline then
        return BotIsOnline(id)
    end

    return GetPlayerByID(id) ~= nil
end

local function playerNamed(name)
    if not GetPlayerByName or not name or name == '' then
        return nil
    end

    local p = GetPlayerByName(name)
    if p and not isBot(p:getID()) then
        return p
    end

    return nil
end

-----------------------------------
-- the friend list as it is (BotFriendList, bots.cpp)
-----------------------------------
local function refresh(force)
    local t = now()
    if not BotFriendList or (not force and cache.at and t - cache.at < REFRESH_S) then
        return cache
    end

    local ok, rows = pcall(BotFriendList)
    if not ok or type(rows) ~= 'table' then
        cache.at = t
        return cache
    end

    local c = { at = t, byBot = {}, byName = {}, entry = {} }
    for _, r in ipairs(rows) do
        if r.name and r.name ~= '' and r.bot then
            c.entry[r.bot .. '|' .. lower(r.name)] = r
            if r.mutual then
                c.byBot[r.bot] = c.byBot[r.bot] or {}
                table.insert(c.byBot[r.bot], r.name)
                c.byName[lower(r.name)] = c.byName[lower(r.name)] or {}
                table.insert(c.byName[lower(r.name)], r.bot)
            end
        end
    end

    cache = c

    -- [Bot]Friend (its AI chat facts, squad chat's "your bot friends online") follows the list
    for id in pairs(c.byBot) do
        local bot = GetPlayerByID(id)
        if bot and bot:getCharVar('[Bot]Friend') ~= 1 then
            bot:setCharVar('[Bot]Friend', 1)
        end

        flagged[id] = true
    end

    for id in pairs(flagged) do
        if not c.byBot[id] then
            local bot = GetPlayerByID(id)
            if bot then
                bot:setCharVar('[Bot]Friend', 0)
                flagged[id] = nil
            end
        end
    end

    return c
end

local function entry(botId, name)
    return refresh().entry[botId .. '|' .. lower(name)]
end

local function mutual(botId, name)
    local e = entry(botId, name)
    return e ~= nil and e.mutual == true
end

-----------------------------------
-- how it feels about you
-----------------------------------
local function points(bot, name)
    return bot:getCharVar('[BotF]' .. name)
end

local function addPoints(bot, name, n)
    local v = math.min(POINT_CAP, points(bot, name) + n)
    bot:setCharVar('[BotF]' .. name, v)
    return v
end

local function nature(bot)
    local h = hash(bot:getName()) % 100
    if h < NATURE_SHARE[1] then
        return 1
    elseif h < NATURE_SHARE[2] then
        return 2
    end

    return 3
end

local function need(bot)
    return NEED[nature(bot)]
end

-- in the same bot linkshell as you (counts as having met)
local function shareLs(bot, name)
    local ls = env.linkshells
    local p = playerNamed(name)
    if not (ls and ls.slotOf and p) then
        return false
    end

    local ok, slot = pcall(ls.slotOf, bot)
    return ok and slot ~= nil and slot > 0 and p:getCharVar('[Bots]LS') == slot
end

-- it asked you to add it, or said "send me a request", lately
local function invited(bot, name)
    local at = bot:getCharVar('[BotFO]' .. name)
    return at > 0 and now() - at <= OFFER_VALID
end

local function ready(bot, name)
    return points(bot, name) >= need(bot) or invited(bot, name) or shareLs(bot, name)
end

-----------------------------------
-- saying it (a tell, after a moment of "typing")
-----------------------------------
local function polite(bot)
    local d = env.dialogue
    if not (d and d.persona) then
        return false
    end

    local ok, p = pcall(d.persona, bot)
    return ok and type(p) == 'table' and p.reg == 'polite'
end

local function line(bot, which, vars)
    local list = LINES[which]
    local l = list[rnd(1, #list)]
    local text = polite(bot) and l[2] or l[1]
    return (text:gsub('{(%a+)}', function(k)
        return vars and vars[k] ~= nil and tostring(vars[k]) or ''
    end))
end

-- unasked: a tell you did not ask for (at most one every UNASKED_GAP to the same player)
local function say(bot, to, which, vars, delay, unasked)
    if unasked then
        local k = lower(to)
        if now() - (lastUnasked[k] or -1e9) < UNASKED_GAP then
            return false
        end

        lastUnasked[k] = now()
    end

    local text = line(bot, which, vars)
    bot:timer((delay or rnd(4, 12)) * 1000, function(b)
        if BotTell and botOnline(b:getID()) then
            BotTell(b:getID(), to, text)
        end
    end)

    return true
end

-----------------------------------
-- your friend request (bots.cpp, every 10 seconds while it waits): true = accept, nil = not yet
-----------------------------------
function F.onRequest(bot, from)
    if not from or from == '' then
        return true -- (nobody to answer: accepted, as before)
    end

    if ready(bot, from) then
        local waited = bot:getCharVar('[BotFR]' .. from) > 0
        bot:setCharVar('[Bot]Friend', 1)
        bot:setCharVar('[BotFR]' .. from, 0)
        flagged[bot:getID()] = true
        cache.at = nil -- (look at the list again on the next tick)
        print(string.format('[bots] %s accepts a friend request from %s (%d points, needs %d)', bot:getName(), from, points(bot, from), need(bot)))
        say(bot, from, waited and 'acceptLater' or 'accept', { name = from }, rnd(4, 15))
        return true
    end

    -- not yet: it says so (once a day at most) and the request waits
    local told = bot:getCharVar('[BotFR]' .. from)
    if now() - told >= NOT_YET_AGAIN then
        bot:setCharVar('[BotFR]' .. from, now())
        print(string.format('[bots] %s is not ready to be friends with %s yet (%d of %d points)', bot:getName(), from, points(bot, from), need(bot)))
        say(bot, from, 'notYet', { name = from }, rnd(6, 20))
    end

    return nil
end

-----------------------------------
-- once a second per bot (bots.lua think): time with you, being raised, its own level ups
-----------------------------------
local function maybeOffer(bot, name)
    if points(bot, name) < OFFER_AT or entry(bot:getID(), name) ~= nil or not playerNamed(name) then
        return -- (not enough yet, already on your list either way, or you are gone)
    end

    local at = bot:getCharVar('[BotFO]' .. name)
    if at > 0 and now() - at < OFFER_AGAIN then
        return
    end

    bot:setCharVar('[BotFO]' .. name, now())
    if not BotFriendRequest then
        if say(bot, name, 'offer', { name = name }, rnd(8, 25), true) then
            print(string.format('[bots] %s asks %s to add it as a friend (%d points)', bot:getName(), name, points(bot, name)))
        end

        return
    end

    -- a real friend request a little after the party (the game shows it like any other), sometimes with a tell
    bot:timer(rnd(8, 25) * 1000, function(b)
        if not botOnline(b:getID()) or not playerNamed(name) then
            return
        end

        local ok, why = BotFriendRequest(b:getID(), name)
        if ok then
            print(string.format('[bots] %s sends %s a friend request (%d points)', b:getName(), name, points(b, name)))
            if math.random() < SENT_TELL_CHANCE then
                say(b, name, 'sentRequest', { name = name }, rnd(4, 10), true)
            end
        elseif why ~= 'listed' and why ~= 'blocked' and why ~= 'asked' then
            say(b, name, 'offer', { name = name }, rnd(4, 10), true) -- (could not send one: it asks by tell)
        end
    end)
end

local function milestone(bot, lvl)
    local names = refresh().byBot[bot:getID()]
    for _, name in ipairs(names or {}) do
        local p = playerNamed(name)
        local together = false
        for _, m in pairs(p and bot:getParty() or {}) do
            if m:getID() == p:getID() then
                together = true
            end
        end

        local vars = { name = name, lvl = lvl, job = JOB_NAMES[bot:getMainJob()] or '' }
        if p and not together and math.random() < MILESTONE_CHANCE then
            say(bot, name, 'milestone', vars, rnd(5, 20), true)
        elseif not p and BotSendMessage and math.random() < MILESTONE_CHANCE then
            BotSendMessage(bot:getID(), name, line(bot, 'mailMilestone', vars)) -- (you are off: a message you find later)
        end
    end
end

function F.notice(bot, st)
    if type(st) ~= 'table' then
        return
    end

    local t = now()
    local f = st.friendship or {}
    st.friendship = f

    -- the real players in its party (here: in its area, where the points are earned)
    local members, here = {}, {}
    if bot:getPartySize() > 1 then
        for _, m in pairs(bot:getParty() or {}) do
            if m:getObjType() == xi.objType.PC and not isBot(m:getID()) then
                members[m:getName()] = true
                if m:getZoneID() == bot:getZoneID() then
                    here[#here + 1] = m:getName()
                end
            end
        end
    end

    -- raised with you
    if bot:isDead() then
        f.dead = true
    elseif f.dead then
        f.dead = nil
        for _, name in ipairs(here) do
            addPoints(bot, name, 3)
        end
    end

    if next(members) then
        f.since = f.since or t
        f.fought = f.fought or bot:isEngaged()
        if t - f.since >= 60 then
            for _, name in ipairs(here) do
                addPoints(bot, name, f.fought and 2 or 1)
            end

            f.since, f.fought = t, false
        end

        -- someone left the party: it may ask them to add it
        for name in pairs(f.members or {}) do
            if not members[name] then
                maybeOffer(bot, name)
            end
        end

        f.members = members
    else
        -- the party with you is over: a bot that had a good time may ask you to add it
        for name in pairs(f.members or {}) do
            maybeOffer(bot, name)
        end

        f.members, f.since, f.fought = nil, nil, false
    end

    -- its own milestones: its friends hear about them
    local lvl, job = bot:getMainLvl(), bot:getMainJob()
    if f.lvl and f.job == job and lvl == f.lvl + 1 and (lvl % 10 == 0 or lvl == 75) then
        milestone(bot, lvl)
    end

    f.lvl, f.job = lvl, job
end

-----------------------------------
-- tells to it: chatting counts a little, "can I add you?", and its offer to come and help
-----------------------------------
local function has(text, word)
    return text:find('%f[%w]' .. word .. '%f[%W]') ~= nil
end

local function yes(text)
    for _, w in ipairs({ 'y', 'yes', 'yea', 'yeah', 'yep', 'sure', 'ok', 'okay', 'k', 'please', 'pls', 'plz', 'come', 'ty', 'thanks' }) do
        if has(text, w) then
            return true
        end
    end

    return false
end

local function no(text)
    for _, w in ipairs({ 'no', 'nah', 'nope', 'later', 'busy', 'im good', "i'm good", 'all good', 'im fine', "i'm fine" }) do
        if has(text, w) then
            return true
        end
    end

    return false
end

local function asksFriend(text)
    if has(text, 'add me') or has(text, 'add you') or has(text, 'add u') or has(text, 'fl') then
        return true
    end

    if text:find('friend', 1, true) then
        return text:find('?', 1, true) ~= nil or has(text, 'be') or has(text, 'wanna') or has(text, 'want') or has(text, 'can')
            or text:find('request', 1, true) ~= nil
    end

    return false
end

function F.onTell(bot, from, text)
    if not from or from == '' then
        return false
    end

    local t = now()
    local id = bot:getID()
    local lowered = lower(text)

    local k = id .. '|' .. lower(from)
    if t - (chatAt[k] or -1e9) >= CHAT_POINT_GAP then
        chatAt[k] = t
        addPoints(bot, from, 1)
    end

    -- its offer to come and help
    local offer = helpOffers[id]
    if offer and lower(offer.to) == lower(from) then
        if t > offer.untill then
            helpOffers[id] = nil
        elseif no(lowered) then
            helpOffers[id] = nil
            say(bot, from, 'helpNo', { name = from }, rnd(3, 8))
            return true
        elseif yes(lowered) then
            helpOffers[id] = nil
            if env.join then
                local ok, handled = pcall(env.join, bot, from)
                if ok and handled then
                    return true
                end
            end

            return false
        end
    end

    -- "can I add you?" / "wanna be friends?"
    if asksFriend(lowered) then
        if mutual(id, from) then
            say(bot, from, 'askAlready', { name = from }, rnd(3, 8))
        elseif ready(bot, from) or nature(bot) == 1 then
            bot:setCharVar('[BotFO]' .. from, t) -- (your request is accepted at once)
            local ok, why = false, nil
            if BotFriendRequest and playerNamed(from) then
                ok, why = BotFriendRequest(id, from)
            end

            if why == 'asked' then
                return true -- (you already sent one: bots.cpp accepts it on its next look, with a word)
            end

            say(bot, from, (ok or why == 'listed') and 'askSent' or 'askYes', { name = from }, rnd(3, 8))
        else
            say(bot, from, 'askNotYet', { name = from }, rnd(3, 8))
        end

        return true
    end

    return false
end

-----------------------------------
-- logging in: a friend says hi (now and then); you log in: a friend online may say hi
-----------------------------------
function F.onLogin(bot)
    local id = bot:getID()
    lastLogin[id] = now()
    local c = refresh()

    -- [Bot]Friend follows the list (it may have been removed while it was away)
    if c.byBot[id] then
        bot:setCharVar('[Bot]Friend', 1)
        flagged[id] = true
    elseif bot:getCharVar('[Bot]Friend') == 1 and BotFriendList then
        bot:setCharVar('[Bot]Friend', 0)
    end

    local names = c.byBot[id]
    if not names or math.random() >= HELLO_CHANCE or now() - bot:getCharVar('[BotFH]') < HELLO_GAP then
        return
    end

    local online = {}
    for _, name in ipairs(names) do
        if playerNamed(name) then
            online[#online + 1] = name
        end
    end

    if #online == 0 then
        return
    end

    local name = online[rnd(1, #online)]
    local seen = bot:getCharVar('[BotFS]' .. name)
    local which = seen > 0 and now() - seen > LONG_TIME and 'helloBack' or 'hello'
    if say(bot, name, which, { name = name }, rnd(20, 60), true) then
        bot:setCharVar('[BotFH]', now())
        bot:setCharVar('[BotFS]' .. name, now())
    end
end

-- back after days away: a friend or two left you a message (the game's mail: you see it come in, as in the era)
local function awayMail(player, ids)
    local name = player:getName()
    local seen = player:getCharVar('[BotF]Seen')
    player:setCharVar('[BotF]Seen', now())
    if not BotSendMessage or seen <= 0 or now() - seen < AWAY_MAIL_AFTER then
        return
    end

    local list = {}
    for _, id in ipairs(ids) do
        list[#list + 1] = id
    end

    for i = #list, 2, -1 do
        local j = rnd(1, i)
        list[i], list[j] = list[j], list[i]
    end

    local sent = 0
    for _, id in ipairs(list) do
        if sent >= AWAY_MAIL_MAX then
            break
        end

        if math.random() < AWAY_MAIL_CHANCE then
            local bot = GetPlayerByID(id) -- (nil when it is off: the casual voice then)
            local which = LINES.mailMissed[rnd(1, #LINES.mailMissed)]
            local text = (bot and polite(bot)) and which[2] or which[1]
            if BotSendMessage(id, name, text) then
                sent = sent + 1
            end
        end
    end

    if sent > 0 then
        print(string.format('[bots] %d bot friend(s) left %s a message (away %d days)', sent, name, math.floor((now() - seen) / 86400)))
    end
end

function F.onPlayerLogin(player)
    local name = player:getName()
    local mem = players[lower(name)] or {}
    players[lower(name)] = mem
    local ids = refresh(true).byName[lower(name)] or {}
    awayMail(player, ids)
    if now() - (mem.greetAt or -1e9) < GREET_GAP or math.random() >= GREET_CHANCE then
        return
    end

    local on = {}
    for _, id in ipairs(ids) do
        local bot = botOnline(id) and GetPlayerByID(id) or nil
        if bot then
            on[#on + 1] = bot
        end
    end

    if #on == 0 then
        return
    end

    local bot = on[rnd(1, #on)]
    if say(bot, name, 'greet', { name = name }, rnd(20, 90), true) then
        mem.greetAt = now()
        bot:setCharVar('[BotFS]' .. name, now())
    end
end

-----------------------------------
-- the friend list's answers and mail (bots.cpp reads a bot's mailbox while it is on)
-----------------------------------
-- your answer to its friend request
function F.onReply(bot, from, accepted)
    if not from or from == '' then
        return
    end

    cache.at = nil
    if accepted then
        bot:setCharVar('[Bot]Friend', 1)
        flagged[bot:getID()] = true
        if playerNamed(from) and math.random() < 0.7 then
            say(bot, from, 'thanks', { name = from }, rnd(4, 15))
        end
    else
        bot:setCharVar('[BotFO]' .. from, now() + DECLINED_WAIT - OFFER_AGAIN) -- (no new request for a month)
    end
end

-- a message you sent it while you are off now (bots.lua answers one from a player who is on by tell)
function F.onMessage(bot, from, text)
    if not from or from == '' then
        return
    end

    local k = bot:getID() .. '|' .. lower(from)
    if now() - (chatAt[k] or -1e9) >= CHAT_POINT_GAP then
        chatAt[k] = now()
        addPoints(bot, from, 1)
    end

    if not BotSendMessage or not mutual(bot:getID(), from) then
        return
    end

    bot:timer(rnd(30, 120) * 1000, function(b)
        BotSendMessage(b:getID(), from, line(b, 'mailReply', { name = from }))
    end)
end

-----------------------------------
-- once a second (bots.lua onTick) with the real players on: cheers, offers to help
-----------------------------------
local function friendBotsOf(player)
    local out = {}
    for _, id in ipairs(refresh().byName[lower(player:getName())] or {}) do
        local bot = botOnline(id) and GetPlayerByID(id) or nil
        if bot then
            out[#out + 1] = bot
        end
    end

    return out
end

local function inParty(bot, player)
    for _, m in pairs(player:getParty() or {}) do
        if m:getID() == bot:getID() then
            return true
        end
    end

    return false
end

local function cheer(player, lvl)
    local name = player:getName()
    local max = lvl % 10 == 0 and 2 or 1
    local list = friendBotsOf(player)
    local done = 0
    for i = #list, 2, -1 do
        local j = rnd(1, i)
        list[i], list[j] = list[j], list[i]
    end

    for _, bot in ipairs(list) do
        if done >= max then
            break
        end

        if not inParty(bot, player) and math.random() < CHEER_CHANCE then
            local delay = rnd(5, 30) + done * rnd(5, 15)
            local text = line(bot, 'cheer', { name = name, lvl = lvl })
            bot:timer(delay * 1000, function(b)
                if BotTell and botOnline(b:getID()) then
                    BotTell(b:getID(), name, text)
                end
            end)
            done = done + 1
        end
    end

    if done > 0 then
        lastUnasked[lower(name)] = now()
    end
end

local function busy(bot)
    local st = env.state and env.state[bot:getID()] or {}
    return st.bf ~= nil or st.quest ~= nil or st.task ~= nil
end

local function roomIn(player)
    local ok, n = pcall(function()
        return #player:getPartyWithTrusts()
    end)
    return not ok or type(n) ~= 'number' or n < 6
end

local function offerHelp(player, mem)
    local t = now()
    if t - (mem.helpAt or -1e9) < HELP_PLAYER_GAP or not player:isAlive() or not player:isEngaged() or not roomIn(player) then
        return
    end

    if math.random() >= HELP_CHANCE then
        return
    end

    local plvl = player:getMainLvl()
    local options = {}
    for _, bot in ipairs(friendBotsOf(player)) do
        if bot:isAlive() and bot:getPartySize() <= 1 and not busy(bot) and math.abs(bot:getMainLvl() - plvl) <= HELP_LEVELS
            and t - (helpAt[bot:getID()] or -1e9) >= HELP_GAP then
            options[#options + 1] = bot
        end
    end

    if #options == 0 then
        return
    end

    local bot = options[rnd(1, #options)]
    local name = player:getName()
    if say(bot, name, 'help', { name = name }, rnd(4, 12), true) then
        mem.helpAt = t
        helpAt[bot:getID()] = t
        helpOffers[bot:getID()] = { to = name, untill = t + HELP_WAIT }
        print(string.format('[bots] %s offers to come and help %s', bot:getName(), name))
    end
end

function F.tick(list)
    refresh()
    local t = now()
    for _, p in ipairs(list or {}) do
        local k = lower(p:getName())
        local mem = players[k] or { best = {} }
        mem.best = mem.best or {}
        players[k] = mem

        -- a real level up (not a job change, not the end of a level sync): friends may cheer
        local lvl, job = p:getMainLvl(), p:getMainJob()
        if mem.job == job and mem.lvl and lvl == mem.lvl + 1 and lvl > (mem.best[job] or 0)
            and (lvl % 5 == 0 or lvl >= 70) then
            cheer(p, lvl)
        end

        mem.lvl, mem.job = lvl, job
        mem.best[job] = math.max(mem.best[job] or 0, lvl)

        if t >= (mem.helpCheck or 0) then
            mem.helpCheck = t + HELP_CHECK_S
            offerHelp(p, mem)
        end

        -- every 10 minutes: you were on (for the mail after days away), and with which friends (for "long time no see")
        if t >= (mem.seenAt or 0) then
            mem.seenAt = t + SEEN_EVERY
            p:setCharVar('[BotF]Seen', t)
            for _, bot in ipairs(friendBotsOf(p)) do
                bot:setCharVar('[BotFS]' .. p:getName(), t)
            end
        end
    end
end

-----------------------------------
-- bots_life.lua: friends never stop playing, and log in more while you are on, at their usual hours
-----------------------------------
function F.isFriendBot(id)
    return refresh().byBot[id] ~= nil
end

local function usualHours(id, hour, weekend)
    local w = HOURS[id % #HOURS + 1]
    local from, to = w[1] - (weekend and 3 or 0), w[2]
    return (hour >= from and hour < to) or (hour + 24 >= from and hour + 24 < to)
end

function F.pickLogin(offline)
    local c = refresh()
    if not next(c.byBot) then
        return nil
    end

    local t = now()
    local hour = tonumber(os.date('%H')) or 12
    local wday = tonumber(os.date('%w')) or 1
    local weekend = wday == 0 or wday == 6
    local eligible = {}
    for _, id in ipairs(offline or {}) do
        local names = c.byBot[id]
        if names and t - (lastLogin[id] or -1e9) >= LOGIN_REST then
            local someoneOn = false
            for _, name in ipairs(names) do
                someoneOn = someoneOn or playerNamed(name) ~= nil
            end

            local chance = usualHours(id, hour, weekend) and LOGIN_CHANCE[1] or LOGIN_CHANCE[2]
            if someoneOn and math.random() < chance then
                eligible[#eligible + 1] = id
            end
        end
    end

    if #eligible == 0 then
        return nil
    end

    local id = eligible[rnd(1, #eligible)]
    lastLogin[id] = t
    return id
end

-----------------------------------
-- !bots friends
-----------------------------------
function F.report(player)
    local c = refresh(true)
    local name = player:getName()
    local key = lower(name)
    local out = {}

    local list = BotList and BotList() or {}
    local friends, waiting = {}, {}
    for _, e in pairs(c.entry) do
        if lower(e.name) == key then
            local bot = GetPlayerByID(e.bot)
            local row = list[e.bot]
            local label = (row and row.name) or (bot and bot:getName()) or tostring(e.bot)
            if e.mutual then
                if bot and botOnline(e.bot) then
                    label = string.format('%s (on, %s%d)', label, JOB_NAMES[bot:getMainJob()] or '', bot:getMainLvl())
                else
                    label = label .. ' (off)'
                end

                friends[#friends + 1] = label
            elseif e.asked then
                if bot then
                    label = string.format('%s %d/%d', label, points(bot, name), need(bot))
                end

                waiting[#waiting + 1] = label
            end
        end
    end

    table.sort(friends)
    table.sort(waiting)
    out[#out + 1] = 'Bot friends: ' .. (#friends > 0 and table.concat(friends, ', ') or 'none yet (Social > Friend List > Add, while the bot is on)')
    if #waiting > 0 then
        out[#out + 1] = 'Requests waiting (points / needed, a point a minute partying): ' .. table.concat(waiting, ', ')
    end

    local known = {}
    for id, r in pairs(list) do
        if r.online then
            local bot = GetPlayerByID(id)
            local p = bot and points(bot, name) or 0
            if p > 0 and not mutual(id, name) then
                known[#known + 1] = { n = r.name or bot:getName(), p = p }
            end
        end
    end

    table.sort(known, function(a, b) return a.p > b.p end)
    if #known > 0 then
        local parts = {}
        for i = 1, math.min(6, #known) do
            parts[#parts + 1] = string.format('%s %d', known[i].n, known[i].p)
        end

        out[#out + 1] = 'Bots online who know you (points): ' .. table.concat(parts, ', ')
    end

    return out
end

function F.setup(e)
    env = e or {}
    if env.life then
        env.life.keep = F.isFriendBot
        env.life.preferLogin = F.pickLogin
    end
end

-- (tests)
F._lines = LINES
F._reset = function()
    cache = { at = nil, byBot = {}, byName = {}, entry = {} }
    flagged, lastLogin, lastUnasked, players, helpOffers, helpAt, chatAt = {}, {}, {}, {}, {}, {}, {}
end
F._nature = nature
F._need = need

return F
