-----------------------------------
-- XI: Forever Offline: romancing squad mates and bot players (2026-11-27, Hurami: "they won't just marry you").
-- Part of modules/wedding (dev launcher switch: Era > Out-of-era content > Weddings). Your own world only: never on
-- The Hub and never while you visit someone else's world.
--
-- How it works (a small dating game):
--   * Affection, separate from friendship. It grows while the two of you party (more while you fight; at most
--     MAX_TIME_PER_DAY a day, so it stays slow and organic), with gifts, a chat now and then, and dates.
--   * Everyone has their own nature, always the same (from the name): quick to fall, most take a while, some take a
--     long time, and some will only ever be friends (they tell you kindly). You can't see which until you try.
--   * Gifts: trade them something. Each one loves two kinds of gift and dislikes one (flowers, gems, crystals,
--     cloth, feathers; bots also sweets). A loved gift is worth a lot, a disliked one costs a little; you learn what
--     they love by trying. Squad mates keep their gear, food, juice, medicine and scroll trades as before.
--   * Stages: acquaintance -> friend -> close (from affection alone) -> dating (you ask them out) -> engaged (you
--     propose with a Matrimony Ring or Band, after some dates) -> married (the ceremony, wedding_ceremony.lua).
--   * Dates: with a partner you are dating, at a special spot (Selbina, the Jeuno districts, Windurst Walls, ...):
--     once a day per spot, worth a lot, and they say something about the place.
--   * !date opens it all (with them in your party): how they feel (stars), chat, ask out, a date here, propose.
--   * Married: one spouse per character; the spouse earns 5% more experience (a squad mate on its own exp, a bot
--     on its kills).
-- Everything is kept on your own character (char vars '[Love]...'), keyed M<mate id> or B<bot id>.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('wedding_romance')

xi = xi or {}
xi.romance = xi.romance or {}
local R = xi.romance

R.STAGE = { ACQUAINTANCE = 0, FRIEND = 1, CLOSE = 2, DATING = 3, ENGAGED = 4, MARRIED = 5 }
local STAGE_NAMES = { [0] = 'Acquaintance', 'Friend', 'Close', 'Dating', 'Engaged', 'Married' }

-- affection needed (a "most" nature; quick x0.6, slow x1.6)
local FRIEND_AT, CLOSE_AT, ASK_AT, PROPOSE_AT, MAX_POINTS = 40, 120, 250, 600, 1000
local DATES_TO_PROPOSE = 3
local MAX_TIME_PER_DAY = 60        -- affection a day from time together
local GIFTS_PER_DAY = 3
local CHAT_GAP = 3600              -- seconds between two chats that count
local DATE_GAP = 20 * 3600         -- the same spot again
local NEGLECT_AFTER = 14 * 86400   -- nobody likes being forgotten: after two weeks apart, a little affection fades
local GIFT_LOVED, GIFT_PLAIN, GIFT_DISLIKED = 25, 8, -10
local SPOUSE_EXP = 1.05
local SPOUSE_VAR = 'WeddingSpouse'          -- a real character's or a bot's id (the certificate code uses it too)
local SPOUSE_MATE_VAR = '[Wedding]SpouseMate' -- a squad mate's id
R.spouseMates = R.spouseMates or {} -- mate ids married to someone (their 5%)

local NATURES = { 'quick', 'most', 'slow', 'never' }
local NATURE_PACE = { quick = 0.6, most = 1, slow = 1.6, never = 1 }

local KINDS = { 'flowers', 'gems', 'crystals', 'cloth', 'feathers', 'sweets' }
local KIND_WORDS =
{
    flowers  = { 'ROSE', 'LILY', 'VIOLET', 'TULIP', 'LILAC', 'FLOWER', 'PETAL', 'BLOSSOM', 'CARNATION', 'AMARYLLIS',
                 'ORCHID', 'IRIS', 'LOTUS', 'DAISY', 'SUNFLOWER', 'HIBISCUS', 'CLOVER', 'LAUREL', 'MAPLE_LEAF' },
    gems     = { 'RUBY', 'SAPPHIRE', 'EMERALD', 'DIAMOND', 'TOPAZ', 'AMETHYST', 'AQUAMARINE', 'GARNET', 'PERIDOT',
                 'ONYX', 'OPAL', 'JADEITE', 'TURQUOISE', 'LAPIS_LAZULI', 'MOONSTONE', 'SUNSTONE', 'ZIRCON', 'TOURMALINE',
                 'CHRYSOBERYL', 'SARDONYX', 'PEARL', 'CORAL_FRAGMENT', 'LIGHT_OPAL', 'AMBER_STONE', 'SPINEL', 'PAINITE' },
    crystals = { '_CRYSTAL', '_CLUSTER' },
    cloth    = { 'BOLT_OF_', 'SILK', 'VELVET', 'LINEN', 'WOOL_THREAD', 'RAINBOW_CLOTH' },
    feathers = { 'FEATHER', 'PLUME', 'QUILL' },
    sweets   = { 'CAKE', 'COOKIE', 'CREPE', 'TART', '_PIE', 'CANDY', 'CHOCOLATE', 'PUDDING', 'MUFFIN', 'DONUT',
                 'BISCUIT', 'COOKIE', 'MACARON', 'PARFAIT', 'SHORTCAKE' },
}
local KIND_NAMES = { flowers = 'flowers', gems = 'gemstones', crystals = 'crystals', cloth = 'fine cloth',
                     feathers = 'feathers', sweets = 'sweets' }

-- date spots: a few words of their own when you bring someone there
R.SPOTS =
{
    { zone = 'SELBINA',              name = "Selbina's harbor",   line = 'The sea breeze, the gulls... and you. I could stay here all day.' },
    { zone = 'MHAURA',               name = 'Mhaura',             line = 'Look at the ships coming in. Where would you sail, if we could go anywhere?' },
    { zone = 'LOWER_JEUNO',          name = 'Lower Jeuno',        line = 'The lanterns are lovely tonight. Thank you for bringing me.' },
    { zone = 'UPPER_JEUNO',          name = 'Upper Jeuno',        line = 'Shall we walk by the cathedral? I like how quiet it is up here.' },
    { zone = 'PORT_JEUNO',           name = 'Port Jeuno',         line = 'Every airship leaving makes me want to take one with you.' },
    { zone = 'RULUDE_GARDENS',       name = "Ru'Lude Gardens",    line = 'All these flowers... none of them as nice as today.' },
    { zone = 'WINDURST_WALLS',       name = 'Windurst Walls',     line = 'The stars look so close from here. Make a wish with me?' },
    { zone = 'WINDURST_WOODS',       name = 'Windurst Woods',     line = 'Everything smells of rain and flowers here. I love it.' },
    { zone = 'NORTHERN_SAN_DORIA',   name = 'Northern San d\'Oria', line = 'The fountain, the old stones... it feels like a story, being here with you.' },
    { zone = 'BASTOK_MARKETS',       name = 'Bastok Markets',     line = 'Let\'s get something warm to eat and just watch the city go by.' },
    { zone = 'KAZHAM',               name = 'Kazham',             line = 'Pineapples, sunshine and you. Is this a dream?' },
    { zone = 'NORG',                 name = 'Norg',               line = 'A pirate hideout for a date? I think I like the way you think.' },
    { zone = 'RABAO',                name = 'Rabao',              line = 'Out here in the desert, it feels like we are the only two in the world.' },
    { zone = 'AHT_URHGAN_WHITEGATE', name = 'Whitegate',          line = 'The smell of spice, the music... Aht Urhgan suits us, don\'t you think?' },
    { zone = 'BUBURIMU_PENINSULA',   name = 'Buburimu Peninsula', line = 'The view from these cliffs... I\'m glad it is you I\'m seeing it with.' },
    { zone = 'LA_THEINE_PLATEAU',    name = 'La Theine Plateau',  line = 'The waterfalls, the open sky... let\'s just sit for a while.' },
}

-- what they say (gender-neutral, sweet, never more than FFXI would show)
R.LINES =
{
    chat =
    {
        [0] = { 'Hello there.', 'Good to see you.', 'Oh, it\'s you. Hi.' },
        [1] = { 'Hey, partner! Ready for another day out there?', 'You always know where the good camps are.', 'I had fun last time. Let\'s do it again.' },
        [2] = { 'I was hoping you\'d come by.', 'Is it strange that I look forward to our hunts?', 'You\'ve been on my mind lately. Just... in a good way.' },
        [3] = { 'I missed you. Is that silly?', 'Every adventure is better with you.', 'Hold still... there. You had a leaf in your hair.' },
        [4] = { 'I keep looking at this ring and smiling.', 'Our wedding... I still can\'t believe it.', 'Have you thought about which palace?' },
        [5] = { 'There you are, my dear.', 'Home is wherever you are.', 'Every day with you is my favorite day.' },
    },
    never = { 'You mean a lot to me, truly... but as a friend. I hope that\'s all right.',
              'I\'m flattered, I really am. But my heart doesn\'t work that way. Friends?',
              'You\'re one of my dearest friends. Let\'s keep it that way, please.' },
    notYet = { 'Oh! I... I don\'t know you well enough yet. Ask me again someday?',
               'That\'s sweet of you. Let\'s get to know each other a little more first.',
               'Maybe... not yet. But don\'t give up on me.' },
    yes = { 'Yes! I was hoping you would ask.', 'I... yes. I\'d really like that.', 'Finally! I thought you\'d never ask.' },
    proposeYes = { 'Yes! Yes, a thousand times yes!', 'I\'ll wear it always. Yes!', '...I\'m crying. Of course I will marry you!' },
    proposeSoon = { 'It\'s beautiful... but it\'s too soon. Keep it for me, and ask me again?',
                    'My heart says yes, but let\'s have a few more days like the good ones first.' },
    giftLoved = { 'For me? I love these! Thank you!', 'Oh, how did you know? This is perfect.', 'You remembered what I like... thank you.' },
    giftPlain = { 'Thank you, that\'s kind of you.', 'Oh, a present? Thanks!', 'I\'ll keep it safe.' },
    giftDisliked = { 'Oh... um. Thank you, I suppose.', 'That\'s... not really my thing. But thanks.', 'Hm. Well, it\'s the thought that counts.' },
    giftEnough = { 'You\'re spoiling me! Save some for another day.', 'No more today, really! You\'ve given me plenty.' },
    married = { 'Good to have you back, my love.', 'I\'m right here, dear.' },
}

-----------------------------------
-- small helpers
-----------------------------------
local function tell(player, text)
    player:printToPlayer(text, xi.msg.channel.SYSTEM_3)
end

local function pick(list)
    return list[math.random(1, #list)]
end

local function hash(text)
    local h = 5381
    for i = 1, #text do
        h = (h * 33 + text:byte(i)) % 2147483647
    end

    return h
end

local function today()
    return math.floor(os.time() / 86400)
end

local function isBot(entity)
    return BotIsBot ~= nil and BotIsBot(entity:getID()) == true
end

local function stars(value, top)
    local filled = math.max(0, math.min(5, math.floor(value / top * 5 + 0.5)))
    return string.rep('\129\154', filled) .. string.rep('\129\153', 5 - filled) -- (Shift-JIS stars)
end

-- romance belongs to your own world
R.allowed = function(player)
    if xi.hardcore and xi.hardcore.isHub then
        return false, 'Romance is for your own world, not The Hub.'
    end

    local coop = rawget(xi, 'coop')
    if type(coop) == 'table' and type(coop.isGuest) == 'function' and coop.isGuest(player) then
        return false, 'Romance is for your own world, not while you visit.'
    end

    return true
end

-----------------------------------
-- partners: a squad mate of yours, out with you, or a bot player in your party
-----------------------------------
-- { kind = 'mate'|'bot', id, name, key, entity }
local function partnerOf(player, entity)
    if entity == nil or entity:getID() == player:getID() then
        return nil
    end

    local mateId = entity:getLocalVar('SQUAD_ID')
    if mateId ~= 0 then
        local master = entity:getMaster()
        if master and master:getID() == player:getID() then
            return { kind = 'mate', id = mateId, name = entity:getPacketName(), key = 'M' .. mateId, entity = entity }
        end

        return nil
    end

    if entity:isPC() and isBot(entity) then
        return { kind = 'bot', id = entity:getID(), name = entity:getName(), key = 'B' .. entity:getID(), entity = entity }
    end

    return nil
end

R.partners = function(player)
    local out = {}
    for _, member in ipairs(player:getPartyWithTrusts()) do
        local p = partnerOf(player, member)
        if p then
            out[#out + 1] = p
        end
    end

    return out
end

R.partnerOf = partnerOf

local function var(player, name, p)
    return player:getCharVar('[Love]' .. name .. p.key)
end

local function setVar(player, name, p, value)
    player:setCharVar('[Love]' .. name .. p.key, value)
end

R.nature = function(p)
    local roll = hash(p.name) % 100
    if roll < 20 then
        return 'quick'
    elseif roll < 65 then
        return 'most'
    elseif roll < 85 then
        return 'slow'
    end

    return 'never'
end

-- two kinds they love, one they dislike, always the same (squad mates never get sweets: food is a squad meal for them)
R.tastes = function(p)
    local kinds = {}
    for _, k in ipairs(KINDS) do
        if not (p.kind == 'mate' and k == 'sweets') then
            kinds[#kinds + 1] = { k, hash(p.name .. '#' .. k) }
        end
    end

    table.sort(kinds, function(a, b)
        return a[2] < b[2]
    end)

    return { [kinds[1][1]] = 'loved', [kinds[2][1]] = 'loved', [kinds[#kinds][1]] = 'disliked' }
end

local itemNames = nil
R.kindOf = function(itemId)
    if itemNames == nil then
        itemNames = {}
        for name, id in pairs(xi.item or {}) do
            if type(id) == 'number' then
                itemNames[id] = name
            end
        end
    end

    local name = itemNames[itemId]
    if not name then
        return nil
    end

    for _, kind in ipairs(KINDS) do
        for _, word in ipairs(KIND_WORDS[kind]) do
            if name:find(word, 1, true) then
                return kind
            end
        end
    end

    return nil
end

R.points = function(player, p)
    return var(player, 'P', p)
end

R.stage = function(player, p)
    local stage = var(player, 'S', p)
    local points = R.points(player, p)
    local pace = NATURE_PACE[R.nature(p)]
    if stage < R.STAGE.DATING then
        -- the first steps come from affection alone; "never" stops at close friends
        if points >= CLOSE_AT * pace then
            stage = R.STAGE.CLOSE
        elseif points >= FRIEND_AT * pace then
            stage = R.STAGE.FRIEND
        else
            stage = R.STAGE.ACQUAINTANCE
        end
    end

    return stage
end

local function say(player, p, text)
    if p.kind == 'mate' then
        player:printToPlayer(text, xi.msg.channel.PARTY, p.name) -- in party chat, as the squad's own lines
    else
        player:printToPlayer(text, xi.msg.channel.TELL, p.name)  -- a tell from the bot
    end
end

R.say = say

local function addPoints(player, p, n)
    -- nobody likes being forgotten: after two weeks apart, a little fades (never below where the stage began)
    local last = var(player, 'T', p)
    local now = os.time()
    if last > 0 and now - last > NEGLECT_AFTER then
        local days = math.floor((now - last - NEGLECT_AFTER) / 86400)
        local floor = 0
        local stage = var(player, 'S', p)
        if stage >= R.STAGE.DATING then
            floor = ASK_AT * NATURE_PACE[R.nature(p)]
        end

        setVar(player, 'P', p, math.max(floor, R.points(player, p) - days * 3))
    end

    setVar(player, 'T', p, now)
    setVar(player, 'P', p, math.max(0, math.min(MAX_POINTS, R.points(player, p) + n)))
end

R.addPoints = addPoints

local function married(player)
    return player:getCharVar(SPOUSE_VAR) ~= 0 or player:getCharVar(SPOUSE_MATE_VAR) ~= 0
end

R.married = married

-----------------------------------
-- time together (every minute while logged in)
-----------------------------------
R.tick = function(player)
    if not R.allowed(player) then
        return
    end

    local partners = R.partners(player)
    if #partners == 0 then
        return
    end

    local fighting = player:isEngaged()
    for _, p in ipairs(partners) do
        local day = today()
        local used = var(player, 'D', p)
        local count = (math.floor(used / 1000) == day) and used % 1000 or 0
        local add = math.min(fighting and 2 or 1, MAX_TIME_PER_DAY - count)
        if add > 0 then
            setVar(player, 'D', p, day * 1000 + count + add)
            addPoints(player, p, add)
        end
    end
end

local tickSerial = 0
local function startTicks(player)
    tickSerial = tickSerial + 1
    local token = tickSerial
    player:setLocalVar('[Love]Tick', token)
    local function again(entity)
        if entity:getLocalVar('[Love]Tick') ~= token then
            return
        end

        pcall(R.tick, entity)
        entity:timer(60000, again)
    end

    player:timer(60000, again)
end

R.startTicks = startTicks

-----------------------------------
-- gifts
-----------------------------------
-- an item given (already taken from the player); returns true when it counted as a gift
R.gift = function(player, p, itemId)
    local okHere = R.allowed(player)
    if not okHere then
        return false
    end

    local kind = R.kindOf(itemId)
    local day = today()
    local given = var(player, 'G', p)
    local count = (math.floor(given / 10) == day) and given % 10 or 0
    if count >= GIFTS_PER_DAY then
        say(player, p, pick(R.LINES.giftEnough))
        return true
    end

    setVar(player, 'G', p, day * 10 + count + 1)
    local taste = kind and R.tastes(p)[kind] or nil
    if taste == 'loved' then
        addPoints(player, p, GIFT_LOVED)
        say(player, p, pick(R.LINES.giftLoved))
        -- they love these: now you know
        local idx = 0
        for i, k in ipairs(KINDS) do
            if k == kind then
                idx = i
            end
        end

        local known = var(player, 'K', p)
        setVar(player, 'K', p, bit.bor(known, bit.lshift(1, idx)))
    elseif taste == 'disliked' then
        addPoints(player, p, GIFT_DISLIKED)
        say(player, p, pick(R.LINES.giftDisliked))
    else
        addPoints(player, p, GIFT_PLAIN)
        say(player, p, pick(R.LINES.giftPlain))
    end

    return true
end

R.giftable = function(p, itemId)
    local kind = R.kindOf(itemId)
    if kind == nil then
        return false
    end

    return not (p.kind == 'mate' and kind == 'sweets')
end

-----------------------------------
-- the !date steps
-----------------------------------
R.chat = function(player, p)
    local now = os.time()
    if now - player:getLocalVar('[Love]Chat' .. p.key) >= CHAT_GAP then
        player:setLocalVar('[Love]Chat' .. p.key, now)
        addPoints(player, p, 3)
    end

    local stage = R.stage(player, p)
    say(player, p, pick(R.LINES.chat[stage] or R.LINES.chat[0]))
end

R.askOut = function(player, p)
    local stage = R.stage(player, p)
    if stage >= R.STAGE.DATING then
        tell(player, string.format('You and %s are already together.', p.name))
        return false
    end

    if married(player) then
        tell(player, 'You are already married.')
        return false
    end

    if R.nature(p) == 'never' and stage >= R.STAGE.CLOSE then
        say(player, p, pick(R.LINES.never))
        return false
    end

    if R.points(player, p) < ASK_AT * NATURE_PACE[R.nature(p)] or R.nature(p) == 'never' then
        say(player, p, pick(R.LINES.notYet))
        return false
    end

    setVar(player, 'S', p, R.STAGE.DATING)
    say(player, p, pick(R.LINES.yes))
    tell(player, string.format('You and %s are now dating!', p.name))
    return true
end

R.spotHere = function(player)
    local zoneId = player:getZoneID()
    for i, spot in ipairs(R.SPOTS) do
        if xi.zone[spot.zone] == zoneId then
            return i, spot
        end
    end

    return nil
end

R.date = function(player, p)
    if R.stage(player, p) < R.STAGE.DATING then
        tell(player, string.format('You and %s are not dating yet.', p.name))
        return false
    end

    local index, spot = R.spotHere(player)
    if not index then
        tell(player, 'This is not much of a place for a date. Try Selbina\'s harbor, the Jeuno districts, Windurst Walls...')
        return false
    end

    local key = 'Spot' .. index
    local last = var(player, key, p)
    if last > 0 and os.time() - last < DATE_GAP then
        say(player, p, 'We were just here! Let\'s find somewhere new, or come back another day.')
        return false
    end

    setVar(player, key, p, os.time())
    setVar(player, 'N', p, var(player, 'N', p) + 1)
    addPoints(player, p, 40)
    say(player, p, spot.line)
    tell(player, string.format('A date with %s in %s.', p.name, spot.name))
    return true
end

local function ringInBag(player)
    for _, id in ipairs({ xi.item.MATRIMONY_RING, xi.item.MATRIMONY_BAND }) do
        if player:hasItem(id, xi.inv.INVENTORY) then
            return id
        end
    end

    return nil
end

R.propose = function(player, p)
    if R.stage(player, p) ~= R.STAGE.DATING then
        tell(player, string.format('You can only propose to someone you are dating (%s is not).', p.name))
        return false
    end

    if married(player) then
        tell(player, 'You are already married.')
        return false
    end

    local ring = ringInBag(player)
    if not ring then
        tell(player, 'You need a Matrimony Ring or Band in your bag (the Matrimonial Coffer in the palaces sells them).')
        return false
    end

    if p.kind == 'bot' and p.entity:getCharVar(SPOUSE_VAR) ~= 0 and p.entity:getCharVar(SPOUSE_VAR) ~= player:getID() then
        say(player, p, 'I... I am already married. I\'m sorry.')
        return false
    end

    if R.points(player, p) < PROPOSE_AT * NATURE_PACE[R.nature(p)] or var(player, 'N', p) < DATES_TO_PROPOSE then
        say(player, p, pick(R.LINES.proposeSoon))
        return false
    end

    if not player:delItem(ring, 1, xi.inv.INVENTORY) then
        return false
    end

    setVar(player, 'S', p, R.STAGE.ENGAGED)
    setVar(player, 'R', p, ring) -- the ring they now wear
    say(player, p, pick(R.LINES.proposeYes))
    tell(player, string.format('You and %s are engaged! Hold your ceremony with a Wedding Master (wear your own ring too).', p.name))
    return true
end

-- the engaged partner out with you now (for the ceremony)
R.engagedPartner = function(player)
    if not R.allowed(player) then
        return nil
    end

    for _, p in ipairs(R.partners(player)) do
        if var(player, 'S', p) == R.STAGE.ENGAGED then
            return p
        end
    end

    return nil
end

-- the ceremony is over (wedding_ceremony.lua)
R.marry = function(player, p)
    setVar(player, 'S', p, R.STAGE.MARRIED)
    if p.kind == 'mate' then
        player:setCharVar(SPOUSE_MATE_VAR, p.id)
        R.spouseMates[p.id] = true
    else
        player:setCharVar(SPOUSE_VAR, p.id)
        if p.entity then
            p.entity:setCharVar(SPOUSE_VAR, player:getID())
        end
    end
end

R.status = function(player, p)
    local stage = R.stage(player, p)
    local lines = { string.format('%s: %s  %s', p.name, STAGE_NAMES[stage], stars(R.points(player, p), MAX_POINTS)) }
    local known, likes = var(player, 'K', p), {}
    for i, k in ipairs(KINDS) do
        if bit.band(known, bit.lshift(1, i)) ~= 0 then
            likes[#likes + 1] = KIND_NAMES[k]
        end
    end

    if #likes > 0 then
        lines[#lines + 1] = 'They love: ' .. table.concat(likes, ', ') .. '.'
    elseif stage >= R.STAGE.FRIEND then
        lines[#lines + 1] = 'You don\'t know yet what gifts they love.'
    end

    if stage == R.STAGE.DATING then
        lines[#lines + 1] = string.format('Dates so far: %d.', var(player, 'N', p))
    end

    return lines
end

-----------------------------------
-- the menu: !date
-----------------------------------
local function menu(player, title, options)
    player:setFreezeFlag(true)
    player:customMenu({
        title = title,
        options = options,
        onCancelled = function(e)
            e:setFreezeFlag(false)
        end,
        onEnd = function(e)
            e:setFreezeFlag(false)
        end,
    })
end

local function later(player, func)
    player:timer(250, func)
end

R.open = function(player, p)
    local stage = R.stage(player, p)
    local options =
    {
        { 'How do they feel?', function(e)
            for _, line in ipairs(R.status(e, p)) do
                tell(e, line)
            end
        end },
        { 'Chat', function(e)
            R.chat(e, p)
        end },
    }

    if stage < R.STAGE.DATING then
        options[#options + 1] = { 'Ask them out', function(e)
            R.askOut(e, p)
        end }
    elseif stage == R.STAGE.DATING then
        options[#options + 1] = { 'A date here', function(e)
            R.date(e, p)
        end }
        options[#options + 1] = { 'Propose (a Matrimony Ring or Band)', function(e)
            R.propose(e, p)
        end }
    end

    menu(player, string.format('%s (%s)', p.name, STAGE_NAMES[stage]), options)
end

local command =
{
    cmdprops = { permission = 0, parameters = '' },
    onTrigger = function(player)
        local ok, why = R.allowed(player)
        if not ok then
            tell(player, why)
            return
        end

        local partners = R.partners(player)
        if #partners == 0 then
            tell(player, '!date: call a squad mate, or party with a bot player, first. Trade them gifts to win their heart.')
            return
        end

        if #partners == 1 then
            R.open(player, partners[1])
            return
        end

        local options = {}
        for _, p in ipairs(partners) do
            options[#options + 1] = { string.format('%s (%s)', p.name, STAGE_NAMES[R.stage(player, p)]), function(e)
                later(e, function(x)
                    R.open(x, p)
                end)
            end }
        end

        menu(player, 'Who?', options)
    end,
}

xi.module.registerCommand('date', command)

-----------------------------------
-- hooks: gifts to mates and bots, the minute ticks, the spouse's experience
-----------------------------------
m:addOverride('xi.squad.onTrade', function(player, trust, items)
    local p = R.allowed(player) and partnerOf(player, trust) or nil
    if not p or type(items) ~= 'table' then
        return super(player, trust, items)
    end

    local rest = {}
    for _, offer in ipairs(items) do
        if R.giftable(p, offer.itemId) and player:delItemAt(offer.itemId, 1, xi.inv.INVENTORY, offer.slot) then
            R.gift(player, p, offer.itemId)
        else
            rest[#rest + 1] = offer
        end
    end

    if #rest > 0 then
        return super(player, trust, rest)
    end
end)

m:addOverride('xi.bots.onGift', function(bot, t)
    super(bot, t)
    if type(t) ~= 'table' or type(t.from) ~= 'string' or type(t.items) ~= 'table' then
        return
    end

    local player = GetPlayerByName and GetPlayerByName(t.from) or nil
    if not player or not R.allowed(player) then
        return
    end

    local p = { kind = 'bot', id = bot:getID(), name = bot:getName(), key = 'B' .. bot:getID(), entity = bot }
    for _, row in ipairs(t.items) do
        if R.giftable(p, row.id) then
            R.gift(player, p, row.id)
            return -- one gift per trade
        end
    end
end)

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if isBot(player) then
        return
    end

    R.wrapSquadExp()
    local mate = player:getCharVar(SPOUSE_MATE_VAR)
    if mate ~= 0 then
        R.spouseMates[mate] = true
    end

    startTicks(player)
end)

-- a married bot earns 5% more from its kills
m:addOverride('xi.experiencePoints.calculate', function(member, mob, data)
    local result = super(member, mob, data)
    if type(result) == 'table' and tonumber(result.exp) and member and isBot(member) and member:getCharVar(SPOUSE_VAR) ~= 0 then
        result.exp = math.floor(result.exp * SPOUSE_EXP)
    end

    return result
end)

-- a married squad mate earns 5% more (kills and pages both go through AddSquadExp)
R.wrapSquadExp = function()
    if R.wrappedSquadExp or type(rawget(_G, 'AddSquadExp')) ~= 'function' then
        return
    end

    R.wrappedSquadExp = true
    local addSquadExp = rawget(_G, 'AddSquadExp')
    rawset(_G, 'AddSquadExp', function(squadId, job, gain, maxLevel)
        if R.spouseMates[squadId] and tonumber(gain) and gain > 0 then
            gain = math.floor(gain * SPOUSE_EXP)
        end

        return addSquadExp(squadId, job, gain, maxLevel)
    end)
end

R.wrapSquadExp() -- (again at log in, in case the squad module registers it later)

return m
