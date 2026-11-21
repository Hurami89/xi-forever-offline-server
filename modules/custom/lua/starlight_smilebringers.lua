-----------------------------------
-- Starlight Celebration: the Smilebringers (XI: Forever Offline)
-----------------------------------
-- The server's own Starlight script only puts up decorations and plays the Jeuno music. This adds the things to
-- do, ported from AirSkyBoat's Starlight Celebration (github.com/AirSkyBoat/AirSkyBoat, GPL-3.0:
-- scripts/globals/events/starlight_celebrations.lua and its NPC scripts). Many thanks to the AirSkyBoat team.
--
--  * Presents for the children (2007): Charmealaut (Northern San d'Oria), Christina (Bastok Mines) and
--    Atagei-Portagei (Windurst Waters) hand out a Present for the Kiddies once a Vana'diel day. Wear a Dream Hat and
--    trade presents or fireworks to the town children for joy. Full joy earns a Dream Hat +1.
--  * Starlight greetings: a moogle in Southern San d'Oria, Bastok Mines and Windurst Waters sends you to four
--    townsfolk once a Vana'diel day: Snow-Themed Gift Token, then candy, plus fireworks.
--  * Goblin Merrymakers: goblins roam Northern San d'Oria, Bastok Markets and Windurst Waters. Win one over with
--    Goblin Chocolate and it may hand you a present that belongs to someone in town. The moogle there says whose;
--    they pass it on, you deliver it and report back: Dream Pants/Trousers (+1), then a Star-Themed Gift Token.
--  * Smilebringer Boot Camp (2009): a sergeant in East Ronfaure, South Gustaberg and East Sarutabaruta times you
--    around ten Smile Helper checkpoints (under 9 minutes): Jeunoan Tree, then candy and a Bell-Themed Gift Token.
--  * Token moogles in every nation city swap gift tokens for Starlight goods, or all three for a Dream Bell.
--  * Vendor moogles (Northern San d'Oria, Bastok Mines, Windurst Waters): Dream Hat, fireworks, trees, chocolate.
--  * Decorations for Upper/Lower/Port Jeuno and Valkurm Dunes (starlight_data.lua), on top of the city ones.
--
-- Runs when the server's Starlight Celebration runs (December, Japan time), or as the launcher's Seasonal events
-- switch says (events_mode.lua: By date / Always on / Off).
--
-- How it hooks in: the town NPCs keep their own scripts. While the event runs, a wrapper around the game's
-- interaction entry points (InteractionGlobal.onTrigger / onTrade) answers the event NPCs first, by zone and
-- script name (moogles by id), and hands everything else on untouched. The moogles, goblins and Smile Helpers are
-- the retail NPCs already in the zone data (hidden outside the event); the three Boot Camp sergeants are made here
-- (their zone entries are switched off as Wings of the Goddess content).
--
-- NOT FROM RETAIL CAPTURES: dialogue is our own text in the chat log, and choices use the server's menu window,
-- instead of the retail cutscenes and message ids (those differ between game versions and could not be checked
-- against this client). Joy uses the normal fame ranks (rank 9 = full). Check it all in game.
-----------------------------------
require('modules/module_utils')

local m    = Module:new('starlight_smilebringers')
local data = require('modules/custom/lua/starlight_data')

xi = xi or {}
xi.starlight = xi.starlight or {}

local ZONE = xi.zone

local ITEM =
{
    PRESENT          = 1742, -- Present for the Kiddies
    DREAM_HAT        = 15178,
    DREAM_HAT_P1     = 15179,
    DREAM_BELL       = 18863,
    DREAM_BELL_P1    = 18864,
    DREAM_PANTS      = 11967,
    DREAM_PANTS_P1   = 11968,
    DREAM_TROUSERS   = 11965,
    DREAM_TROUSERS_P1 = 11966,
    CANDY_CANE       = 5622,
    CANDY_RING       = 5621,
    ROAST_TURKEY     = 5620,
    JEUNOAN_TREE     = 138,
    GOBLIN_CHOCOLATE = 4495,
}

local PRESENTS  = { [1742] = true, [1743] = true, [1744] = true, [1745] = true }
local FIREWORKS = { 4215, 4216, 4217, 4218, 4167, 4168, 4169 } -- Popstar, Brilliant Snow, Sparkling Hand, Air Rider,
local IS_FIREWORK = {}                                          -- Cracker, Twinkle Shower, Little Comet
for _, id in ipairs(FIREWORKS) do
    IS_FIREWORK[id] = true
end

local JOY_PRESENT  = 128 -- AirSkyBoat's amounts, on the fame scale (rank 9 at 613)
local JOY_FIREWORK = 32
local GIFTS_PER_CHILD = 14 -- per child, per visit to the zone

local KI =
{
    SNOW  = xi.keyItem.SNOW_THEMED_GIFT_TOKEN,
    BELL  = xi.keyItem.BELL_THEMED_GIFT_TOKEN,
    STAR  = xi.keyItem.STAR_THEMED_GIFT_TOKEN,
    RED   = xi.keyItem.RED_PRESENT,
    GREEN = xi.keyItem.GREEN_PRESENT,
    BLUE  = xi.keyItem.BLUE_PRESENT,
}

local CITY_NAME =
{
    [ZONE.SOUTHERN_SAN_DORIA] = "Southern San d'Oria",
    [ZONE.NORTHERN_SAN_DORIA] = "Northern San d'Oria",
    [ZONE.BASTOK_MINES]       = 'Bastok Mines',
    [ZONE.BASTOK_MARKETS]     = 'Bastok Markets',
    [ZONE.WINDURST_WATERS]    = 'Windurst Waters',
    [ZONE.WINDURST_WOODS]     = 'Windurst Woods',
}

-----------------------------------
-- Who is who (script names from the zone data; moogles by id)
-----------------------------------
-- Present givers (they also tell you how much joy you've brought)
local GIVERS =
{
    [ZONE.NORTHERN_SAN_DORIA] = 'Charmealaut',
    [ZONE.BASTOK_MINES]       = 'Christina',
    [ZONE.WINDURST_WATERS]    = 'Atagei-Portagei',
}

-- Children who take presents and fireworks
local CHILDREN =
{
    [ZONE.NORTHERN_SAN_DORIA] = { 'Ailbeche', 'Kuu_Mohzolhi', 'Maurine', 'Taurette' },
    [ZONE.BASTOK_MINES]       = { 'Detzo', 'Gonija', 'Gumbah', 'Roh_Latteh', 'Vaghron', 'Valeri' },
    [ZONE.WINDURST_WATERS]    = { 'Arukoko', 'Buchi_Kohmrijah', 'Clais', 'Diroku-Oroku', 'Hororo', 'Janta-Jonta', 'Majiji',
                                  'Myumimi', 'Pakesse-Myukesse', 'Rabiri-Tabiri', 'Temoe-Amoe', 'Yohra-Ora' },
}

-- Starlight greetings: the moogle and the four people to visit
local GREETINGS =
{
    [ZONE.SOUTHERN_SAN_DORIA] = { moogle = 17719913, people = { 'Ullasa', 'Femitte', 'Chanpau', 'Balasiel' } },
    [ZONE.BASTOK_MINES]       = { moogle = 17736003, people = { 'Tall_Mountain', 'Tami', 'Virnage', 'Christina' } },
    [ZONE.WINDURST_WATERS]    = { moogle = 17752536, people = { 'Kayeel-Payeel', 'Kenapa-Keppa', 'Honoi-Gomoi', 'Angelica' } },
}

-- Goblin Merrymakers: the moogle and the six townsfolk presents go between (goblin ids and routes: starlight_data)
local MERRY =
{
    [ZONE.NORTHERN_SAN_DORIA] = { moogle = 17723808, people = { 'Villion', 'Telmoda', 'Rodaillece', 'Gilipese', 'Coullene', 'Vavegallet' } },
    [ZONE.BASTOK_MARKETS]     = { moogle = 17740170, people = { 'Lame_Deer', 'Epione', 'Pavel', 'Tancredi', 'Red_Canyon', 'Anguysh' } },
    [ZONE.WINDURST_WATERS]    = { moogle = 17752537, people = { 'Bulolo', 'Pulykiki', 'Pia', 'Kobite-Mojite', 'Reh_Hapli', 'Kuesoso' } },
}

-- Token moogles (one per nation city zone)
local TOKEN_MOOGLES =
{
    [ZONE.SOUTHERN_SAN_DORIA] = 17719912,
    [ZONE.NORTHERN_SAN_DORIA] = 17723807,
    [ZONE.BASTOK_MINES]       = 17736002,
    [ZONE.BASTOK_MARKETS]     = 17740169,
    [ZONE.WINDURST_WATERS]    = 17752535,
    [ZONE.WINDURST_WOODS]     = 17764761,
}

-- Vendor moogles: [id] = stock (1 or 2), 0 = the one in the middle who only greets
local VENDORS =
{
    [ZONE.NORTHERN_SAN_DORIA] = { [17723809] = 1, [17723810] = 2, [17723811] = 0 },
    [ZONE.BASTOK_MINES]       = { [17736004] = 1, [17736005] = 2, [17736006] = 0 },
    [ZONE.WINDURST_WATERS]    = { [17752546] = 1, [17752545] = 2, [17752547] = 0 },
}

local STOCK =
{
    {
        { 4215, 40 }, { 4216, 40 }, { 4217, 25 }, { 4218, 100 }, { 4167, 8 }, { 4168, 25 }, { 4169, 25 },
        { ITEM.DREAM_HAT, 500 }, { 86, 10000 }, { 115, 10000 }, { 116, 10000 },
    },
    {
        { 176, 10000 }, { 177, 10000 }, { 178, 10000 }, { 10875, 5000 }, { 6498, 777 }, { ITEM.GOBLIN_CHOCOLATE, 50 },
    },
}

-- Boot Camp: the sergeant (made here) and the ten Smile Helpers (zone data ids)
local CAMPS =
{
    [ZONE.EAST_RONFAURE] =
    {
        key = 'Bison', name = 'Stampeding Bison', record = 230, helpers = { 17191563, 17191572 },
        look = '0x010000088C108C207A30F3408C50006000700000', pos = { 79.690, -59.999, 236.672, 37 },
    },
    [ZONE.SOUTH_GUSTABERG] =
    {
        key = 'Cloud', name = 'Wandering Cloud', record = 270, helpers = { 17216218, 17216227 },
        look = '0x010008088C108C207A30F3408C50006000700000', pos = { 179.934, 0.264, -185.454, 64 },
    },
    [ZONE.EAST_SARUTABARUTA] =
    {
        key = 'Tortoise', name = 'Whispering Tortoise', record = 240, helpers = { 17253114, 17253123 },
        look = '0x01000D088C108C207A30F3408C50006000700000', pos = { -99.551, -4.974, -532.998, 180 },
    },
}

local BOOT_QUALIFY = 540 -- seconds

local TOKENS =
{
    {
        ki = KI.SNOW, name = 'Snow-Themed Gift Token',
        rewards = { 5552, ITEM.DREAM_BELL, 10382, 10383, 5542, 5616, ITEM.CANDY_CANE, ITEM.CANDY_RING, 177, 115 },
    },
    {
        ki = KI.BELL, name = 'Bell-Themed Gift Token',
        rewards = { 5552, ITEM.CANDY_RING, ITEM.DREAM_BELL, 15752, 15753, ITEM.ROAST_TURKEY, 178, 116 },
    },
    {
        ki = KI.STAR, name = 'Star-Themed Gift Token',
        rewards = { 5550, ITEM.CANDY_CANE, ITEM.CANDY_RING, ITEM.DREAM_BELL, 14519, 14520, 5542, ITEM.ROAST_TURKEY, 176, 86 },
    },
}

-----------------------------------
-- State and helpers
-----------------------------------
local state =
{
    active   = nil,
    shown    = {},   -- [npcId] = true for zone-data NPCs this module made visible
    sergeant = {},   -- [zoneId] = dynamic NPC id
}

local channel = function(name, fallback)
    return (xi.msg and xi.msg.channel and xi.msg.channel[name]) or fallback
end

local SAY = channel('NS_SAY', 13)
local SYS = channel('SYSTEM_3', 29)

local function npcName(npc)
    return npc:getPacketName()
end

local function say(player, npc, text)
    player:printToPlayer(text, SAY, type(npc) == 'string' and npc or npcName(npc))
end

local function sys(player, text)
    player:printToPlayer(text, SYS)
end

local function pretty(scriptName)
    return (string.gsub(scriptName, '_', ' '))
end

local function sendMenu(player, menu)
    player:timer(50, function(p)
        p:customMenu(menu)
    end)
end

local function eventsMode()
    if xi.eventsMode and xi.eventsMode.get then
        return xi.eventsMode.get()
    end

    return 'date'
end

local function isActive()
    local mode = eventsMode()
    if mode == 'off' then
        return false
    elseif mode == 'on' then
        return true
    end

    return JstMonth() == 12 -- the server's own Starlight check (starlight_celebration.lua)
end

xi.starlight.isActive = isActive

local function today()
    return VanadielUniqueDay()
end

local function wearsDreamHat(player)
    local head = player:getEquipID(xi.slot.HEAD)
    return head == ITEM.DREAM_HAT or head == ITEM.DREAM_HAT_P1
end

local function zoneText(player, key)
    local ID = zones[player:getZoneID()]
    return ID and ID.text and ID.text[key]
end

local function giveKeyItem(player, ki)
    if player:hasKeyItem(ki) then
        return false
    end

    player:addKeyItem(ki)
    local msg = zoneText(player, 'KEYITEM_OBTAINED')
    if msg then
        player:messageSpecial(msg, ki)
    end

    return true
end

local function takeKeyItem(player, ki)
    if not player:hasKeyItem(ki) then
        return false
    end

    player:delKeyItem(ki)
    local msg = zoneText(player, 'KEYITEM_LOST')
    if msg then
        player:messageSpecial(msg, ki)
    end

    return true
end

local function indexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then
            return i
        end
    end

    return nil
end

-- A new year's celebration starts over (joy and the daily present); the "already explained" flags stay.
local function season(player)
    local year = tonumber(os.date('%Y')) or 0
    if player:getCharVar('[Starlight]Year') ~= year then
        player:setCharVar('[Starlight]Year', year)
        player:setCharVar('[Starlight]Joy', 0)
        player:setCharVar('[Starlight]PresentDay', 0)
    end
end

local function joyRank(player)
    local points = player:getCharVar('[Starlight]Joy')
    if xi.data and xi.data.fame and xi.data.fame.getRankFromPoints then
        return xi.data.fame.getRankFromPoints(points)
    end

    return math.min(9, 1 + math.floor(points / 77))
end

local function addJoy(player, amount)
    player:setCharVar('[Starlight]Joy', player:getCharVar('[Starlight]Joy') + amount)
end

local function isRare(itemId)
    if not GetReadOnlyItem or not (xi.itemFlag and xi.itemFlag.RARE) then
        return true
    end

    local item = GetReadOnlyItem(itemId)
    return item ~= nil and bit.band(item:getFlag(), xi.itemFlag.RARE) ~= 0
end

-----------------------------------
-- Presents for the children
-----------------------------------
local JOY_LINES =
{
    [1] = "You haven't brought any smiles yet, have you? The children are waiting!",
    [2] = 'A few little faces are lighting up. Keep it up!',
    [3] = "Word's getting around that a Smilebringer is in town.",
    [4] = 'The children talk about you at dinner now, you know.',
    [5] = "You're halfway to filling the whole town with smiles!",
    [6] = 'I can hear the laughter from here. Wonderful work!',
    [7] = "Hardly a frown left in town. You're a natural Smilebringer!",
    [8] = 'Just a little more, and every child in town will be smiling!',
}

local THANKS =
{
    'Thank you! Thank you! Thank you!',
    'Whoa! For me? Thanks so much!',
    'A present?! This is the best Starlight ever!',
}

local function giverTrigger(player, npc)
    season(player)

    local day = today()
    if player:getCharVar('[Starlight]PresentDay') ~= day then
        if player:getFreeSlotsCount() < 1 then
            say(player, npc, "Merry Starlight! I've a present for you to pass on, but your bags are full. Make some room!")
            return true
        end

        if player:getCharVar('[Starlight]Intro') == 0 then
            player:setCharVar('[Starlight]Intro', 1)
            say(player, npc, "Merry Starlight! Every year the Smilebringers bring presents to the children of Vana'diel.")
            say(player, npc, "Put on a Dream Hat (the moogles sell them), then hand a present or some fireworks to the children in town.")
            say(player, npc, "Here's a present to start you off. Come and see me again tomorrow, and I'll have another.")
        else
            say(player, npc, "Merry Starlight! Here's today's present for the children. Off you go, Smilebringer!")
        end

        if npcUtil.giveItem(player, ITEM.PRESENT) then
            player:setCharVar('[Starlight]PresentDay', day)
        end

        return true
    end

    if not wearsDreamHat(player) then
        say(player, npc, "Smilebringers wear a Dream Hat, you know! The moogles sell them. I'll have another present for you tomorrow.")
        return true
    end

    local rank = joyRank(player)
    if rank >= 9 then
        if not player:hasItem(ITEM.DREAM_HAT_P1) then
            if player:getFreeSlotsCount() < 1 then
                say(player, npc, "You've filled the whole town with smiles! I have something for you, but your bags are full.")
            else
                say(player, npc, "You've filled the whole town with smiles! A true Smilebringer deserves a hat to match.")
                npcUtil.giveItem(player, ITEM.DREAM_HAT_P1)
            end
        else
            say(player, npc, "Every child in town is smiling, thanks to you. Merry Starlight!")
        end
    else
        say(player, npc, JOY_LINES[rank] or JOY_LINES[1])
        say(player, npc, "I'll have another present for you tomorrow.")
    end

    return true
end

local function childTrade(player, npc, trade)
    if not wearsDreamHat(player) then
        return false
    end

    local item = trade:getItemId()
    if not item or not (PRESENTS[item] or IS_FIREWORK[item]) then
        return false
    end

    if not npcUtil.tradeHasExactly(trade, item) then
        say(player, npc, 'Ooh! Just one at a time, please!')
        return true
    end

    season(player)

    local key   = '[Starlight]Gifts' .. npc:getID()
    local given = player:getLocalVar(key)
    if given >= GIFTS_PER_CHILD or joyRank(player) >= 9 then
        say(player, npc, 'Another present? Sorry, but I only have two hands!')
        return true
    end

    player:tradeComplete()
    player:setLocalVar(key, given + 1)

    local before = joyRank(player)
    local big    = PRESENTS[item] ~= nil
    addJoy(player, big and JOY_PRESENT or JOY_FIREWORK)
    say(player, npc, THANKS[math.random(1, #THANKS)])
    sys(player, big and "You've brought barrelfuls of joy to the children of Vana'diel!" or "You've brought joy to the children of Vana'diel!")

    if before < 9 and joyRank(player) >= 9 then
        local giver = GIVERS[player:getZoneID()]
        sys(player, 'The whole town is smiling! Go and tell ' .. (giver and pretty(giver) or 'the present giver') .. '.')
    end

    return true
end

-----------------------------------
-- Starlight greetings (four people, once a Vana'diel day)
-----------------------------------
local function greetMask(player)
    return player:getCharVar('[Starlight]GreetMask')
end

local function greetMoogle(player, npc)
    local zoneId = player:getZoneID()
    local g      = GREETINGS[zoneId]
    local doing  = player:getCharVar('[Starlight]GreetZone')

    if doing == zoneId then
        local mask = greetMask(player)
        if mask == 15 then
            if player:getFreeSlotsCount() < 2 then
                say(player, npc, "You've delivered every greeting, kupo! Make room in your bags for your thank-you gifts.")
                return true
            end

            say(player, npc, "Everyone got their greetings, kupo! Thank you, Smilebringer. Here's a little something.")
            if not giveKeyItem(player, KI.SNOW) then
                npcUtil.giveItem(player, math.random(1, 2) == 1 and ITEM.CANDY_CANE or ITEM.CANDY_RING)
            end

            npcUtil.giveItem(player, { { FIREWORKS[math.random(1, #FIREWORKS)], 10 } })
            player:setCharVar('[Starlight]GreetZone', 0)
            player:setCharVar('[Starlight]GreetMask', 0)
            player:setCharVar('[Starlight]GreetDone', today())
            return true
        end

        local left = {}
        for i, name in ipairs(g.people) do
            if bit.band(mask, bit.lshift(1, i - 1)) == 0 then
                table.insert(left, pretty(name))
            end
        end

        say(player, npc, 'Still to go, kupo: ' .. table.concat(left, ', ') .. '.')
        return true
    end

    if doing ~= 0 and CITY_NAME[doing] then
        sendMenu(player,
        {
            title   = "You're delivering greetings in " .. CITY_NAME[doing],
            options =
            {
                { 'Keep going there', function(p)
                    say(p, npc, 'Good luck with the deliveries in ' .. CITY_NAME[doing] .. ', kupo!')
                end },
                { 'Start over here instead', function(p)
                    p:setCharVar('[Starlight]GreetZone', 0)
                    p:setCharVar('[Starlight]GreetMask', 0)
                    say(p, npc, 'No problem, kupo! Talk to me again to start.')
                end },
            },
        })
        return true
    end

    if player:getCharVar('[Starlight]GreetDone') == today() then
        say(player, npc, "You've done plenty for today, kupo! Come back tomorrow and I'll have more greetings to deliver.")
        return true
    end

    local names = {}
    for _, name in ipairs(g.people) do
        table.insert(names, pretty(name))
    end

    sendMenu(player,
    {
        title   = 'Deliver Starlight greetings?',
        options =
        {
            { 'Yes, I will help!', function(p)
                p:setCharVar('[Starlight]GreetZone', zoneId)
                p:setCharVar('[Starlight]GreetMask', 0)
                say(p, npc, 'Kupo ho ho! Please wish a merry Starlight to ' .. table.concat(names, ', ') .. '. Then come back to me!')
            end },
            { 'Not right now', function(p)
                say(p, npc, 'Maybe later, kupo! Merry Starlight!')
            end },
        },
    })
    return true
end

local GREET_LINES =
{
    'A Starlight greeting, for me? How thoughtful. Merry Starlight to you too!',
    'Oh my, the moogles remembered me! Thank you, and merry Starlight!',
    'Hah! Starlight greetings already? Thank you kindly.',
    'Why, thank you! Starlight always did bring out the best in folk.',
}

-- true when this person still needed a greeting from this player
local function greetPerson(player, npc)
    local zoneId = player:getZoneID()
    if player:getCharVar('[Starlight]GreetZone') ~= zoneId then
        return false
    end

    local i = indexOf(GREETINGS[zoneId].people, npc:getName())
    if not i then
        return false
    end

    local bitFor = bit.lshift(1, i - 1)
    local mask   = greetMask(player)
    if bit.band(mask, bitFor) ~= 0 then
        return false
    end

    mask = bit.bor(mask, bitFor)
    player:setCharVar('[Starlight]GreetMask', mask)
    say(player, npc, GREET_LINES[i] or GREET_LINES[1])

    local done = 0
    for b = 0, 3 do
        if bit.band(mask, bit.lshift(1, b)) ~= 0 then
            done = done + 1
        end
    end

    sys(player, string.format('Starlight greetings delivered: %d of 4.%s', done, done == 4 and ' Go back to the moogle!' or ''))
    return true
end

-----------------------------------
-- Token moogles
-----------------------------------
local function pickReward(player, list)
    local pool = {}
    for _, id in ipairs(list) do
        if not (player:hasItem(id) and isRare(id)) then
            table.insert(pool, id)
        end
    end

    if #pool == 0 then
        pool = { ITEM.CANDY_CANE, ITEM.CANDY_RING }
    end

    return pool[math.random(1, #pool)]
end

local function tokenMoogle(player, npc)
    if player:getCharVar('[Starlight]TokenIntro') == 0 then
        player:setCharVar('[Starlight]TokenIntro', 1)
        say(player, npc, "Merry Starlight, kupo! Bring me gift tokens and I'll swap them for Starlight treats.")
        say(player, npc, 'Snow tokens come from the greetings moogles, Star tokens from the Goblin Merrymakers, Bell tokens from the Smilebringer Boot Camp.')
        say(player, npc, 'Bring all three at once and I can make you something extra special, kupo!')
        return true
    end

    local options = {}
    local owned   = 0
    for _, token in ipairs(TOKENS) do
        if player:hasKeyItem(token.ki) then
            owned = owned + 1
            table.insert(options, { 'Swap the ' .. token.name, function(p)
                if p:getFreeSlotsCount() < 1 then
                    say(p, npc, 'Your bags are full, kupo!')
                    return
                end

                if takeKeyItem(p, token.ki) then
                    npcUtil.giveItem(p, pickReward(p, token.rewards))
                    say(p, npc, 'Kupo ho ho! Enjoy!')
                end
            end })
        end
    end

    if owned == 3 then
        table.insert(options, 1, { 'Swap all three for a Dream Bell', function(p)
            local hq   = p:hasItem(ITEM.DREAM_BELL_P1)
            local need = hq and 3 or 1
            if p:getFreeSlotsCount() < need then
                say(p, npc, 'Your bags are full, kupo!')
                return
            end

            for _, token in ipairs(TOKENS) do
                takeKeyItem(p, token.ki)
            end

            if hq then
                npcUtil.giveItem(p, { ITEM.ROAST_TURKEY, ITEM.CANDY_RING, ITEM.CANDY_CANE })
            elseif p:hasItem(ITEM.DREAM_BELL) then
                npcUtil.giveItem(p, ITEM.DREAM_BELL_P1)
            else
                npcUtil.giveItem(p, ITEM.DREAM_BELL)
            end

            say(p, npc, 'All three! You really are a Smilebringer, kupo!')
        end })
    end

    if owned == 0 then
        say(player, npc, 'No gift tokens yet, kupo? Snow: greetings moogles. Star: Goblin Merrymakers. Bell: Smilebringer Boot Camp.')
        return true
    end

    table.insert(options, { 'Never mind', function(p)
    end })
    sendMenu(player, { title = 'Swap gift tokens', options = options })
    return true
end

-----------------------------------
-- Vendor moogles
-----------------------------------
local function vendorMoogle(player, npc)
    local stock = VENDORS[player:getZoneID()][npc:getID()]
    if stock == 0 then
        say(player, npc, 'Merry Starlight, kupo! My friends here have festive wares for every Smilebringer.')
        return true
    end

    say(player, npc, 'Come one, come all, kupo!')
    xi.shop.general(player, STOCK[stock])
    return true
end

-----------------------------------
-- Goblin Merrymakers
-----------------------------------
-- [MerryMakers] vars: Started, Trust (goblin npc id), Stage, Zone, Sender, Receiver (indexes into MERRY[zone].people)
-- Stage 1 present from a goblin, 2 moogle named the owner, 3 owner passed it on, 4 delivered, 5 owner told: reward
local function mmGet(player, key)
    return player:getCharVar('[MerryMakers]' .. key)
end

local function mmSet(player, key, value)
    player:setCharVar('[MerryMakers]' .. key, value)
end

local function heldPresent(player)
    for _, ki in ipairs({ KI.RED, KI.GREEN, KI.BLUE }) do
        if player:hasKeyItem(ki) then
            return ki
        end
    end

    return nil
end

local function mmReset(player)
    for _, key in ipairs({ 'Stage', 'Zone', 'Sender', 'Receiver' }) do
        mmSet(player, key, 0)
    end
end

local function personName(zoneId, index)
    local g = MERRY[zoneId]
    return g and g.people[index] and pretty(g.people[index]) or 'someone in town'
end

local function merryReward(player, npc)
    if player:getFreeSlotsCount() < 1 then
        say(player, npc, 'Your bags are full, kupo! Make some room and talk to me again.')
        return
    end

    local male    = player:getGender() == 1
    local nq      = male and ITEM.DREAM_TROUSERS or ITEM.DREAM_PANTS
    local hq      = male and ITEM.DREAM_TROUSERS_P1 or ITEM.DREAM_PANTS_P1
    say(player, npc, "The present made it home, kupo! That's the Starlight spirit. Here's your reward!")
    if not player:hasItem(nq) and not player:hasItem(hq) then
        npcUtil.giveItem(player, nq)
    elseif not player:hasItem(hq) then
        npcUtil.giveItem(player, hq)
    elseif not giveKeyItem(player, KI.STAR) then
        npcUtil.giveItem(player, male and ITEM.CANDY_RING or ITEM.CANDY_CANE)
    end

    mmReset(player)
end

local function merryMoogle(player, npc)
    local zoneId = player:getZoneID()
    local g      = MERRY[zoneId]

    if mmGet(player, 'Started') == 0 then
        mmSet(player, 'Started', 1)
        say(player, npc, 'Kupo! Goblin Merrymakers are running all over town, sniffing out "happy toys".')
        say(player, npc, "They've a soft spot for Goblin Chocolate, kupo. The vendor moogles sell it. Trade one a piece, then chat with it.")
        say(player, npc, 'If a goblin shows you a present, bring it to me. I bet it belongs to somebody in town!')
        return true
    end

    local stage = mmGet(player, 'Stage')
    if stage >= 2 and mmGet(player, 'Zone') ~= zoneId then
        local city = CITY_NAME[mmGet(player, 'Zone')] or 'another town'
        say(player, npc, "You're in the middle of a delivery in " .. city .. ', kupo! Finish that one first.')
        return true
    end

    if stage == 5 then
        merryReward(player, npc)
    elseif stage == 4 then
        say(player, npc, 'Delivered? Wonderful, kupo! Let ' .. personName(zoneId, mmGet(player, 'Sender')) .. ' know it arrived safely.')
    elseif stage == 3 then
        say(player, npc, 'Please take the present to ' .. personName(zoneId, mmGet(player, 'Receiver')) .. ', kupo!')
    elseif stage == 2 then
        say(player, npc, 'That present has ' .. personName(zoneId, mmGet(player, 'Sender')) .. "'s name on it, kupo. Take it to them!")
    elseif stage == 1 or heldPresent(player) then
        local sender = math.random(1, #g.people)
        mmSet(player, 'Stage', 2)
        mmSet(player, 'Zone', zoneId)
        mmSet(player, 'Sender', sender)
        say(player, npc, "A goblin gave you this? Kupo... look at the tag. It belongs to " .. personName(zoneId, sender) .. '!')
        say(player, npc, 'Please bring it back to them, kupo.')
    else
        say(player, npc, 'Win a Goblin Merrymaker over with Goblin Chocolate, then chat with it. Bring me any present it shows you, kupo!')
    end

    return true
end

local PERSON_LINES =
{
    passOn   = "My present! A goblin had it? Well, I never. Actually... it was meant for %s. Would you take it to them?",
    remind   = 'Please, take the present to %s.',
    received = 'For me? From %s? Oh, how wonderful! Please thank them for me.',
    thanked  = "You're back! It arrived? That's good news indeed. Thank you, Smilebringer. Do tell the moogle.",
}

-- true when this person has a part to play in the player's delivery
local function merryPerson(player, npc)
    local zoneId = player:getZoneID()
    if mmGet(player, 'Started') == 0 or mmGet(player, 'Zone') ~= zoneId then
        return false
    end

    local me = indexOf(MERRY[zoneId].people, npc:getName())
    if not me then
        return false
    end

    local stage    = mmGet(player, 'Stage')
    local sender   = mmGet(player, 'Sender')
    local receiver = mmGet(player, 'Receiver')

    if stage == 2 and me == sender then
        local choices = {}
        for i = 1, #MERRY[zoneId].people do
            if i ~= sender then
                table.insert(choices, i)
            end
        end

        receiver = choices[math.random(1, #choices)]
        mmSet(player, 'Receiver', receiver)
        mmSet(player, 'Stage', 3)
        say(player, npc, string.format(PERSON_LINES.passOn, personName(zoneId, receiver)))
        return true
    elseif stage == 3 and me == sender then
        say(player, npc, string.format(PERSON_LINES.remind, personName(zoneId, receiver)))
        return true
    elseif stage == 3 and me == receiver then
        local present = heldPresent(player)
        if present then
            takeKeyItem(player, present)
        end

        mmSet(player, 'Stage', 4)
        say(player, npc, string.format(PERSON_LINES.received, personName(zoneId, sender)))
        return true
    elseif stage == 4 and me == sender then
        mmSet(player, 'Stage', 5)
        say(player, npc, PERSON_LINES.thanked)
        return true
    end

    return false
end

local GOBLIN_LINES =
{
    idle    = 'Happy toy, happy toy, where be me happy toy?',
    sing    = "Ev'ry girl, ev'ry boy, ev'rybody, happy toy!",
    ask     = 'Sniff sniff... you smell like yum-yums. You got yum-yums for me tum-tum?',
    trade   = 'Yum-yums for me? Gobbies remember... till our tummies forget!',
    blech   = 'Blech. What this yucky thing? Me want upgurgle.',
    friend  = 'You have friend, you do? We gobbies have friend too! You is one!',
    wahh    = 'Waaah! It you! You give yum-yums for me tum-tum. Gobbie happy!',
    give    = 'Not for us, not for me? Me give it back. Now you have it, you take it home!',
    no      = 'No no no no no! Go away! Nose holes busy sniffing for happy toy!',
    mumble  = '...',
}

local function goblinTrigger(player, npc)
    if mmGet(player, 'Started') == 0 then
        say(player, npc, GOBLIN_LINES.mumble)
        return true
    end

    if mmGet(player, 'Trust') ~= npc:getID() then
        say(player, npc, GOBLIN_LINES.ask)
        return true
    end

    local roll = math.random(0, 3)
    if roll == 0 then
        mmSet(player, 'Trust', 0)
        say(player, npc, GOBLIN_LINES.no)
    elseif roll == 1 then
        say(player, npc, GOBLIN_LINES.friend)
    elseif roll == 2 then
        say(player, npc, GOBLIN_LINES.wahh)
    elseif mmGet(player, 'Stage') == 0 and not heldPresent(player) then
        local kis = { KI.RED, KI.GREEN, KI.BLUE }
        giveKeyItem(player, kis[math.random(1, 3)])
        mmSet(player, 'Stage', 1)
        mmSet(player, 'Trust', 0)
        say(player, npc, GOBLIN_LINES.give)
        sys(player, 'Take the present to the moogle in town.')
    else
        say(player, npc, GOBLIN_LINES.no)
    end

    return true
end

local function goblinTrade(player, npc, trade)
    if mmGet(player, 'Started') == 0 then
        say(player, npc, GOBLIN_LINES.mumble)
        return true
    end

    if npcUtil.tradeHasExactly(trade, ITEM.GOBLIN_CHOCOLATE) then
        player:tradeComplete()
        mmSet(player, 'Trust', npc:getID())
        say(player, npc, GOBLIN_LINES.trade)
    else
        say(player, npc, GOBLIN_LINES.blech)
    end

    return true
end

-- Walking: the start route to the hub, then a random route out and back (AirSkyBoat's Goblin_Merrymaker scripts)
local COORDS  = (xi.path and xi.path.flag and xi.path.flag.COORDS) or 64
local REVERSE = (xi.path and xi.path.flag and xi.path.flag.REVERSE) or 4
local pointCache = {}

local function points(route)
    local cached = pointCache[route]
    if not cached then
        cached = {}
        for _, p in ipairs(route) do
            table.insert(cached, { x = p[1], y = p[2], z = p[3] })
        end

        pointCache[route] = cached
    end

    return cached
end

local function chirp(npc)
    local zone = npc:getZone()
    if not zone or math.random(1, 3) ~= 1 then
        return
    end

    local line = math.random(1, 2) == 1 and GOBLIN_LINES.idle or GOBLIN_LINES.sing
    for _, p in pairs(zone:getPlayers()) do
        if p:checkDistance(npc) <= 15 then
            say(p, npc, line)
        end
    end
end

local function goblinWalk(npc, zoneId, index)
    local g = data.goblins[zoneId]
    if npc:getLocalVar('[Starlight]Ai') == 0 then
        npc:initNpcAi()
        npc:setLocalVar('[Starlight]Ai', 1)
    end

    local route = g.start[index] or g.routes[1]
    local first = route[1]
    npc:setPos(first[1], first[2], first[3])
    npc:setLocalVar('[Starlight]Est', 0)
    npc:setLocalVar('[Starlight]Path', 0)
    npc:pathThrough(points(route), COORDS)
end

local function goblinPathComplete(npc)
    if not state.active then
        return
    end

    local g = data.goblins[npc:getZoneID()]
    if not g then
        return
    end

    local est  = npc:getLocalVar('[Starlight]Est')
    local path = npc:getLocalVar('[Starlight]Path')
    local nextRoute, flags = 1, COORDS

    if est ~= 0 then                       -- back at the hub after a branch: walk the main route
        npc:setLocalVar('[Starlight]Est', 0)
    elseif path == 0 then                  -- on the main route: pick a branch
        nextRoute = math.random(1, #g.routes)
        npc:setLocalVar('[Starlight]Path', nextRoute)
    else                                   -- end of a branch: walk it back
        nextRoute = path
        flags     = bit.bor(COORDS, REVERSE)
        npc:setLocalVar('[Starlight]Path', 0)
        npc:setLocalVar('[Starlight]Est', 1)
    end

    npc:timer(1500, function(n)
        if state.active then
            chirp(n)
            n:pathThrough(points(g.routes[nextRoute]), flags)
        end
    end)
end

-----------------------------------
-- Smilebringer Boot Camp
-----------------------------------
-- Local vars (a run ends if you leave the zone): [BootCamp]Start, Visits, MissedFlee, CP<helper id>
local function fmtTime(seconds)
    return string.format('%d:%02d', math.floor(seconds / 60), seconds % 60)
end

local function recordFor(zoneId)
    local camp = CAMPS[zoneId]
    local time = GetServerVariable('[Starlight]BootRecord' .. zoneId)
    if time <= 0 then
        return camp.record, 'Smilebringer'
    end

    local holder = GetPlayerByID(GetServerVariable('[Starlight]BootHolder' .. zoneId))
    return time, holder and holder:getName() or 'a Smilebringer'
end

local function helperIds(zoneId)
    local range = CAMPS[zoneId].helpers
    local ids   = {}
    for id = range[1], range[2] do
        table.insert(ids, id)
    end

    return ids
end

local function campReset(player, zoneId)
    player:setLocalVar('[BootCamp]Start', 0)
    player:setLocalVar('[BootCamp]Visits', 0)
    player:setLocalVar('[BootCamp]MissedFlee', 0)
    for _, id in ipairs(helperIds(zoneId)) do
        player:setLocalVar('[BootCamp]CP' .. id, 0)
    end
end

local function giveFlee(player)
    player:addStatusEffect(xi.effect.FLEE, 100, 0, 30)
end

local function sergeantTrigger(player, npc)
    if not state.active then
        return
    end

    local zoneId = player:getZoneID()
    local camp   = CAMPS[zoneId]
    local total  = #helperIds(zoneId)
    local start  = player:getLocalVar('[BootCamp]Start')

    if start ~= 0 then
        local elapsed = os.time() - start
        local visits  = player:getLocalVar('[BootCamp]Visits')
        if visits < total then
            say(player, npc, string.format("Keep running! %d checkpoints to go. Time: %s.", total - visits, fmtTime(elapsed)))
            sendMenu(player,
            {
                title   = 'Boot Camp: ' .. fmtTime(elapsed),
                options =
                {
                    { 'Keep going', function(p)
                    end },
                    { 'Give up this run', function(p)
                        campReset(p, zoneId)
                        say(p, npc, 'No shame in it, recruit. Try again any time today.')
                    end },
                },
            })
            return
        end

        if elapsed > BOOT_QUALIFY then
            campReset(player, zoneId)
            say(player, npc, string.format('%s... too slow, recruit! You need to finish under %s. Try again!', fmtTime(elapsed), fmtTime(BOOT_QUALIFY)))
            return
        end

        local hasTree = player:hasItem(ITEM.JEUNOAN_TREE)
        if player:getFreeSlotsCount() < 1 then
            say(player, npc, 'Fine running! Make room in your bags and report to me again for your reward.')
            return
        end

        local record = recordFor(zoneId)
        say(player, npc, string.format('All ten checkpoints in %s! Now that is a Smilebringer!', fmtTime(elapsed)))
        if elapsed < record then
            SetServerVariable('[Starlight]BootRecord' .. zoneId, elapsed)
            SetServerVariable('[Starlight]BootHolder' .. zoneId, player:getID())
            sys(player, 'New Boot Camp record for ' .. camp.name .. "'s course!")
        end

        campReset(player, zoneId)
        player:setCharVar('[SmileBootCamp]Completed', today())
        if hasTree then
            npcUtil.giveItem(player, ITEM.CANDY_CANE)
            giveKeyItem(player, KI.BELL)
        else
            npcUtil.giveItem(player, ITEM.JEUNOAN_TREE)
        end

        return
    end

    if player:getCharVar('[SmileBootCamp]Completed') == today() then
        say(player, npc, "You've trained hard today, recruit. Rest up and come back tomorrow!")
        return
    end

    local recordTime, holder = recordFor(zoneId)
    sendMenu(player,
    {
        title   = string.format('Boot Camp (record %s, %s)', fmtTime(recordTime), holder),
        options =
        {
            { 'Start training!', function(p)
                campReset(p, zoneId)
                p:setLocalVar('[BootCamp]Start', os.time())
                say(p, npc, string.format('Ready-steady? Visit all %d Smile Helpers in this area and report back in under %s. GO!', total, fmtTime(BOOT_QUALIFY)))
            end },
            { 'How does it work?', function(p)
                say(p, npc, 'Smilebringers must be quick on their feet! Smile Helpers wait at checkpoints all over this area.')
                say(p, npc, string.format('Talk to all %d, then report to me in under %s. They may cheer you on with a burst of speed.', total, fmtTime(BOOT_QUALIFY)))
                say(p, npc, 'First finish of the day earns a Jeunoan Tree. After that, a candy and a Bell-Themed Gift Token.')
            end },
            { 'Never mind', function(p)
            end },
        },
    })
end

local function helperTrigger(player, npc)
    local zoneId  = player:getZoneID()
    local camp    = CAMPS[zoneId]
    local start   = player:getLocalVar('[BootCamp]Start')

    if start == 0 then
        say(player, npc, 'This is a checkpoint for the Smilebringer Boot Camp. Talk to ' .. camp.name .. ' to start training!')
        return true
    end

    local elapsed = fmtTime(os.time() - start)
    local key     = '[BootCamp]CP' .. npc:getID()
    if player:getLocalVar(key) ~= 0 then
        say(player, npc, 'You already cleared this checkpoint! Time: ' .. elapsed .. '.')
        return true
    end

    local visits = player:getLocalVar('[BootCamp]Visits') + 1
    local total  = #helperIds(zoneId)
    player:setLocalVar(key, 1)
    player:setLocalVar('[BootCamp]Visits', visits)

    if visits >= total then
        say(player, npc, string.format('All checkpoints cleared! Time: %s. Report back to %s!', elapsed, camp.name))
        giveFlee(player)
        return true
    end

    local missed = player:getLocalVar('[BootCamp]MissedFlee')
    if player:hasStatusEffect(xi.effect.FLEE) or visits == 1 or missed == 1 or math.random(0, 5) == 3 then
        player:setLocalVar('[BootCamp]MissedFlee', 0)
        say(player, npc, string.format('Checkpoint %d cleared! Time: %s. Go go go!', visits, elapsed))
        giveFlee(player)
    else
        player:setLocalVar('[BootCamp]MissedFlee', 1)
        say(player, npc, string.format('Checkpoint %d cleared. Time: %s.', visits, elapsed))
    end

    return true
end

-----------------------------------
-- Handler tables: [zoneId] = { byName = {}, byId = {} }
-----------------------------------
local triggers = {}
local trades   = {}

local function add(set, zoneId, how, key, fn)
    set[zoneId] = set[zoneId] or { byName = {}, byId = {} }
    set[zoneId][how][key] = fn
end

for zoneId, name in pairs(GIVERS) do
    add(triggers, zoneId, 'byName', name, function(player, npc)
        if GREETINGS[zoneId] and greetPerson(player, npc) then -- Christina is also on the Bastok Mines greetings list
            return true
        end

        return giverTrigger(player, npc)
    end)
end

for zoneId, list in pairs(CHILDREN) do
    for _, name in ipairs(list) do
        add(trades, zoneId, 'byName', name, childTrade)
    end
end

for zoneId, g in pairs(GREETINGS) do
    add(triggers, zoneId, 'byId', g.moogle, greetMoogle)
    for _, name in ipairs(g.people) do
        if GIVERS[zoneId] ~= name then
            add(triggers, zoneId, 'byName', name, greetPerson)
        end
    end
end

for zoneId, id in pairs(TOKEN_MOOGLES) do
    add(triggers, zoneId, 'byId', id, tokenMoogle)
end

for zoneId, list in pairs(VENDORS) do
    for id in pairs(list) do
        add(triggers, zoneId, 'byId', id, vendorMoogle)
    end
end

for zoneId, g in pairs(MERRY) do
    add(triggers, zoneId, 'byId', g.moogle, merryMoogle)
    for _, name in ipairs(g.people) do
        add(triggers, zoneId, 'byName', name, merryPerson)
    end

    add(triggers, zoneId, 'byName', 'Goblin_Merrymaker', goblinTrigger)
    add(trades, zoneId, 'byName', 'Goblin_Merrymaker', goblinTrade)
end

for zoneId in pairs(CAMPS) do
    add(triggers, zoneId, 'byName', 'Smile_Helper', helperTrigger)
end

xi.starlight.triggers = triggers
xi.starlight.trades   = trades

local function findHandler(set, npc)
    local zh = set[npc:getZoneID()]
    if not zh then
        return nil
    end

    return zh.byId[npc:getID()] or zh.byName[npc:getName()]
end

local function run(handler, ...)
    local ok, handled = pcall(handler, ...)
    if not ok then
        print('[starlight] ' .. tostring(handled))
        return false
    end

    return handled == true
end

-- Wraps the game's interaction entry points once (they are plain globals the map server calls on every click/trade)
local function wrapInteraction()
    if type(InteractionGlobal) ~= 'table' or InteractionGlobal.starlightWrapped then
        return
    end

    local originalTrigger = InteractionGlobal.onTrigger
    local originalTrade   = InteractionGlobal.onTrade

    InteractionGlobal.onTrigger = function(player, npc, fallbackFn)
        if state.active and player and npc then
            local handler = findHandler(triggers, npc)
            if handler and run(handler, player, npc) then
                return 0
            end
        end

        return originalTrigger(player, npc, fallbackFn)
    end

    InteractionGlobal.onTrade = function(player, npc, trade, fallbackFn)
        if state.active and player and npc and trade then
            local handler = findHandler(trades, npc)
            if handler and run(handler, player, npc, trade) then
                return
            end
        end

        return originalTrade(player, npc, trade, fallbackFn)
    end

    InteractionGlobal.starlightWrapped = true
end

-----------------------------------
-- Showing and hiding
-----------------------------------
local ZONE_SCRIPT =
{
    [ZONE.SOUTHERN_SAN_DORIA] = 'Southern_San_dOria',
    [ZONE.NORTHERN_SAN_DORIA] = 'Northern_San_dOria',
    [ZONE.BASTOK_MINES]       = 'Bastok_Mines',
    [ZONE.BASTOK_MARKETS]     = 'Bastok_Markets',
    [ZONE.WINDURST_WATERS]    = 'Windurst_Waters',
    [ZONE.WINDURST_WOODS]     = 'Windurst_Woods',
    [ZONE.EAST_RONFAURE]      = 'East_Ronfaure',
    [ZONE.SOUTH_GUSTABERG]    = 'South_Gustaberg',
    [ZONE.EAST_SARUTABARUTA]  = 'East_Sarutabaruta',
}

-- The goblins have no script file: their walking callback lives where the map server looks for it
local function bindGoblinScripts()
    for zoneId in pairs(data.goblins) do
        local zoneName = ZONE_SCRIPT[zoneId]
        xi.zones = xi.zones or {}
        xi.zones[zoneName] = xi.zones[zoneName] or {}
        xi.zones[zoneName].npcs = xi.zones[zoneName].npcs or {}
        xi.zones[zoneName].npcs.Goblin_Merrymaker = xi.zones[zoneName].npcs.Goblin_Merrymaker or {}
        xi.zones[zoneName].npcs.Goblin_Merrymaker.onPathComplete = goblinPathComplete
    end
end

local function zoneNpcIds(zoneId)
    local ids = {}
    local function addId(id)
        if id then
            table.insert(ids, id)
        end
    end

    if GREETINGS[zoneId] then
        addId(GREETINGS[zoneId].moogle)
    end

    if MERRY[zoneId] then
        addId(MERRY[zoneId].moogle)
    end

    addId(TOKEN_MOOGLES[zoneId])
    for id in pairs(VENDORS[zoneId] or {}) do
        addId(id)
    end

    if CAMPS[zoneId] then
        for _, id in ipairs(helperIds(zoneId)) do
            addId(id)
        end
    end

    return ids
end

local function spawnSergeant(zone)
    local zoneId = zone:getID()
    local camp   = CAMPS[zoneId]
    if state.sergeant[zoneId] then
        return GetNPCByID(state.sergeant[zoneId])
    end

    local npc = zone:insertDynamicEntity({
        objtype    = xi.objType.NPC,
        name       = 'StarlightSergeant' .. camp.key,
        packetName = camp.name,
        look       = camp.look,
        x          = camp.pos[1],
        y          = camp.pos[2],
        z          = camp.pos[3],
        rotation   = camp.pos[4],
        widescan   = 1,
        onTrigger  = sergeantTrigger,
    })
    if npc then
        state.sergeant[zoneId] = npc:getID()
    end

    return npc
end

local function applyZone(zoneId, on)
    local zone = GetZone(zoneId)
    if not zone then
        return
    end

    local shownStatus  = xi.status.NORMAL
    local hiddenStatus = xi.status.DISAPPEAR

    for _, id in ipairs(zoneNpcIds(zoneId)) do
        local npc = GetNPCByID(id)
        if npc then
            if on then
                npc:setStatus(shownStatus)
                state.shown[id] = true
            elseif state.shown[id] then
                npc:setStatus(hiddenStatus)
                state.shown[id] = nil
            end
        end
    end

    local g = data.goblins[zoneId]
    if g then
        for index, id in ipairs(g.ids) do
            local npc = GetNPCByID(id)
            if npc then
                if on then
                    npc:setStatus(shownStatus)
                    state.shown[id] = true
                    goblinWalk(npc, zoneId, index)
                elseif state.shown[id] then
                    npc:setStatus(hiddenStatus)
                    state.shown[id] = nil
                end
            end
        end
    end

    if CAMPS[zoneId] then
        if on then
            local npc = spawnSergeant(zone)
            if npc then
                npc:setStatus(shownStatus)
            end
        elseif state.sergeant[zoneId] then
            local npc = GetNPCByID(state.sergeant[zoneId])
            if npc then
                npc:setStatus(hiddenStatus)
            end
        end
    end
end

local function refresh(force)
    local on = isActive()
    if on == state.active and not force then
        return
    end

    state.active = on
    print("[starlight] Smilebringers are " .. (on and 'in town' or 'away'))
    for zoneId in pairs(ZONE_SCRIPT) do
        applyZone(zoneId, on)
    end
end

-- Decorations for the zones the server's own script leaves bare (it puts them up and takes them down itself)
local function addDecorations()
    local sc = xi.events and xi.events.starlightCelebration
    if not sc or type(sc.data) ~= 'table' then
        return
    end

    for zoneId, list in pairs(data.decorations) do
        if sc.data[zoneId] == nil then
            sc.data[zoneId] = list
        end
    end
end

-----------------------------------
-- Hooks
-----------------------------------
bindGoblinScripts()
wrapInteraction()
addDecorations()

for zoneId, zoneName in pairs(ZONE_SCRIPT) do
    m:addOverride('xi.zones.' .. zoneName .. '.Zone.onInitialize', function(zone)
        super(zone)
        bindGoblinScripts()
        if state.active == nil then
            state.active = isActive()
        end

        if state.active then
            applyZone(zoneId, true)
        end
    end)
end

m:addOverride('xi.server.onServerStart', function()
    addDecorations()
    super()
    bindGoblinScripts()
    wrapInteraction()
    refresh(true)
end)

m:addOverride('xi.server.onJSTMidnight', function()
    super()
    wrapInteraction()
    refresh(false)
end)

local NOTICE_ZONES =
{
    [ZONE.NORTHERN_SAN_DORIA] = true, [ZONE.SOUTHERN_SAN_DORIA] = true, [ZONE.BASTOK_MINES] = true,
    [ZONE.BASTOK_MARKETS] = true, [ZONE.WINDURST_WATERS] = true, [ZONE.WINDURST_WOODS] = true,
}

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if not state.active or not NOTICE_ZONES[player:getZoneID()] then
        return
    end

    local day = tonumber(os.date('%Y%m%d')) or 0
    if player:getCharVar('[Starlight]Notice') ~= day then
        player:setCharVar('[Starlight]Notice', day)
        sys(player, "The Starlight Celebration is here! The Smilebringers need help: see Charmealaut (Northern San d'Oria), " ..
            'Christina (Bastok Mines) or Atagei-Portagei (Windurst Waters). Festive moogles are in every nation city.')
    end
end)

return m
