-----------------------------------
-- Teleport shouts (XI: Forever Offline, 2026-11-17; AerynGunn's suggestion, the user's design)
--
-- 1) Bots who want a teleport. In the Jeuno areas and Aht Urhgan Whitegate, now and then a bot player shouts for a
--    Teleport ("LF Tele-Holla! 800g"). A white mage who knows that spell answers the era way: /tell the bot (or invite
--    it). It joins your party; cast the Teleport; once it arrives it pays you (500-2,000 gil, era prices) and leaves
--    your party. It shouts more often while you are a WHM who can teleport. The bot gets the crag's gate crystal
--    (the spell needs it on whoever is teleported).
-- 2) You shouting for a teleport. Shout (or yell) for one anywhere, e.g. "need tele holla" or "LF Teleport-Mea".
--    If a bot white mage who can cast it is online and free, it answers by /tell with its price, comes to you and
--    invites you. Accept, stay next to it while it casts, and you pay it when you arrive. You need the crag's gate
--    crystal (touch the crag once), the gil, and room in your party. No white mage free: nobody answers.
--
-- Loaded by bots.lua (tele.setup, tele.tick once a second, tele.onTell, tele.onInvite, tele.playerShout).
-- bots.cpp passes your shouts and yells to xi.bots.playerShout (needs the server rebuild of 2026-11-17).
-----------------------------------
local T = {}

local state, helpers = {}, {}

-- the six Teleport spells: WHM level, MP, the crag's area and the gate crystal the teleported person needs
local DEST =
{
    holla = { spell = 'TELEPORT_HOLLA', ki = 'HOLLA_GATE_CRYSTAL',   zone = 102, name = 'Holla', lvl = 36, mp = 75 },
    dem   = { spell = 'TELEPORT_DEM',   ki = 'DEM_GATE_CRYSTAL',     zone = 108, name = 'Dem',   lvl = 36, mp = 75 },
    mea   = { spell = 'TELEPORT_MEA',   ki = 'MEA_GATE_CRYSTAL',     zone = 117, name = 'Mea',   lvl = 36, mp = 75 },
    yhoat = { spell = 'TELEPORT_YHOAT', ki = 'YHOATOR_GATE_CRYSTAL', zone = 124, name = 'Yhoat', lvl = 38, mp = 100 },
    altep = { spell = 'TELEPORT_ALTEP', ki = 'ALTEPA_GATE_CRYSTAL',  zone = 114, name = 'Altep', lvl = 38, mp = 100 },
    vahzl = { spell = 'TELEPORT_VAHZL', ki = 'VAHZL_GATE_CRYSTAL',   zone = 112, name = 'Vahzl', lvl = 42, mp = 100 },
}
local ORDER = { 'holla', 'dem', 'mea', 'yhoat', 'altep', 'vahzl' }

-- where bots shout for teleports: Ru'Lude Gardens, Upper / Lower / Port Jeuno, Aht Urhgan Whitegate
local TOWNS = { [243] = true, [244] = true, [245] = true, [246] = true, [50] = true }

local WHM = 3
local PRICE = { 5, 20 }               -- x100 gil: 500 - 2,000 (era: most paid 500 - 2k)
local OFFER_S = 300                   -- a shout stays open this long
local RESHOUT_S = 140                 -- nobody answered: it shouts once more
local JOINED_S = 300                  -- in your party and no teleport by then: it gives up
local NEXT_CAN = { 240, 480 }         -- seconds between shouts in an area while you can teleport there
local NEXT_CANNOT = { 900, 1500 }     -- ... and while you can't (flavour only)

local offers = {}                     -- [bot id] = bot wants a teleport (you are the WHM)
local deals = {}                      -- [bot id] = a bot WHM teleports you
local nextShout = {}                  -- [zone id] = os.time() of the next customer shout there
local shoutCooldown = {}              -- [player id] = no new teleport request before this time

local function now()
    return os.time()
end

local function spellId(d)
    return xi.magic.spell[d.spell]
end

local function kiId(d)
    return xi.keyItem[d.ki]
end

local function gilText(n)
    if n % 1000 == 0 then
        return tostring(math.floor(n / 1000)) .. 'k'
    end

    return tostring(n) .. 'g'
end

local function sys(player, text)
    player:printToPlayer(text, (xi.msg and xi.msg.channel and xi.msg.channel.SYSTEM_3) or 29)
end

local function botEntity(id)
    local ok, b = pcall(GetPlayerByID, id)
    return ok and b or nil
end

-- free for a teleport errand: online, alive, not fighting, no party, not out hunting / crafting / questing
local function idle(bot)
    if not bot or bot:isDead() or bot:isEngaged() or bot:getPartySize() > 1 then
        return false
    end

    local st = state[bot:getID()]
    return not (st and (st.hunt or st.task or st.quest or st.bf)) and not offers[bot:getID()] and not deals[bot:getID()]
end

-- the destination named in a line of chat ("tele holla", "teleport-mea", "LF tele dem"...)
local function destIn(lower)
    for _, key in ipairs(ORDER) do
        if lower:find('%f[%a]' .. key) then
            return key
        end
    end

    if lower:find('yhoator', 1, true) then
        return 'yhoat'
    elseif lower:find('altepa', 1, true) then
        return 'altep'
    end

    return nil
end

local function canCast(player, d)
    local sid = spellId(d)
    return player:getMainJob() == WHM and player:getMainLvl() >= d.lvl and sid ~= nil and player:hasSpell(sid)
end

local function inParty(a, b)
    for _, m in pairs(a:getParty() or {}) do
        if m:getID() == b:getID() then
            return true
        end
    end

    return false
end

-----------------------------------
-- 1) a bot wants a teleport
-----------------------------------
local SHOUTS =
{
    'LF Tele-%s! %s',
    'Tele %s please, paying %s!',
    'Any WHM? Need Teleport-%s, %s',
    'Seeking tele to %s ~ %s, /t me',
    'tele %s plz, will pay %s',
}

-- which crag a bot of this level would want (low levels: the three crags; higher: the far ones too)
local function pickDest(bot, whmPlayer, zoneId)
    local lvl = bot:getMainLvl()
    local pool
    if lvl < 30 and zoneId ~= 50 then
        pool = { 'holla', 'dem', 'mea' }
    elseif lvl < 50 then
        pool = { 'holla', 'dem', 'mea', 'yhoat', 'altep' }
    else
        pool = { 'yhoat', 'altep', 'vahzl', 'holla', 'dem', 'mea' }
    end

    -- mostly a crag the white mage around can actually do
    if whmPlayer and math.random() < 0.75 then
        local known = {}
        for _, key in ipairs(pool) do
            if canCast(whmPlayer, DEST[key]) then
                known[#known + 1] = key
            end
        end

        if #known > 0 then
            pool = known
        end
    end

    return pool[math.random(1, #pool)]
end

local function customerShout(bot, offer)
    local d = DEST[offer.key]
    local line = SHOUTS[math.random(1, #SHOUTS)]
    BotChat(bot:getID(), 1, string.format(line, d.name, gilText(offer.price)))
end

local function startCustomer(zoneId, players)
    local whm = nil
    for _, p in ipairs(players) do
        for _, key in ipairs(ORDER) do
            if canCast(p, DEST[key]) then
                whm = p
                break
            end
        end
    end

    local candidates = {}
    for id, row in pairs(BotList()) do
        if row.online and row.zone == zoneId then
            local b = botEntity(id)
            if b and idle(b) and b:getZoneID() == zoneId then
                candidates[#candidates + 1] = b
            end
        end
    end

    if #candidates == 0 then
        return
    end

    local bot = candidates[math.random(1, #candidates)]
    local key = pickDest(bot, whm, zoneId)
    local ki = kiId(DEST[key])
    if ki and not bot:hasKeyItem(ki) then
        bot:addKeyItem(ki) -- (it has been to that crag before: the spell needs the gate crystal on the one teleported)
    end

    local offer = { key = key, price = math.random(PRICE[1], PRICE[2]) * 100, zone = zoneId, stage = 'shouted',
                    untilT = now() + OFFER_S, reshoutAt = now() + RESHOUT_S }
    offers[bot:getID()] = offer
    customerShout(bot, offer)
    print(string.format('[bots] tele: %s shouts for Teleport-%s (%d gil) in zone %d', bot:getName(), DEST[key].name, offer.price, zoneId))
end

-- the white mage answers: by /tell (any text) or an invite
local function customerAnswered(bot, offer, fromName, byInvite)
    local player = GetPlayerByName(fromName)
    local d = DEST[offer.key]
    if not player then
        return false
    end

    if not canCast(player, d) then
        BotTell(bot:getID(), fromName, string.format('ah, I need someone who can cast Teleport-%s - thanks though!', d.name))
        return true
    end

    local room = #(player:getParty() or {})
    local okT, total = pcall(function()
        return #player:getPartyWithTrusts()
    end)
    if okT and type(total) == 'number' then
        room = total
    end

    if not byInvite and room >= 6 then
        BotTell(bot:getID(), fromName, 'your party is full - invite me when there is room?')
        return true
    end

    if byInvite then
        offer.stage, offer.player, offer.untilT = 'joined', fromName, now() + JOINED_S
    elseif helpers.join and helpers.join(bot, fromName) then
        offer.stage, offer.player, offer.untilT = 'joined', fromName, now() + JOINED_S
    else
        return false
    end

    local id = bot:getID()
    bot:timer(3500, function(b)
        BotTell(id, fromName, string.format('ty!! Teleport-%s please, I pay %s when we get there', d.name, gilText(offer.price)))
    end)

    return true
end

-- arrived at the crag with you: pays, thanks you, leaves your party (and goes about its day there)
local function customerArrived(bot, offer)
    local player = offer.player and GetPlayerByName(offer.player)
    local id = bot:getID()
    offers[id] = nil
    if not player or player:getZoneID() ~= bot:getZoneID() then
        return
    end

    if bot:getGil() >= offer.price then
        bot:delGil(offer.price)
    end

    player:addGil(offer.price)
    sys(player, string.format('%s pays you %d gil for the teleport.', bot:getName(), offer.price))
    print(string.format('[bots] tele: %s paid %s %d gil (Teleport-%s)', bot:getName(), player:getName(), offer.price, DEST[offer.key].name))
    BotTell(id, player:getName(), ({ 'thanks a lot! here you go', 'ty!! sent the gil', 'perfect, thank you o/', 'ty for the tele!' })[math.random(1, 4)])
    bot:timer(5000, function(b)
        BotLeaveParty(id)
        local st = state[id]
        if st then
            st.mode = 'follow'
        end
    end)
end

-----------------------------------
-- 2) you shout for a teleport: a bot white mage answers
-----------------------------------
local function whiteMages(d, zoneId)
    local same, other = {}, {}
    for id, row in pairs(BotList()) do
        if row.online then
            local b = botEntity(id)
            if b and b:getMainJob() == WHM and b:getMainLvl() >= d.lvl and idle(b) then
                if b:getZoneID() == zoneId then
                    same[#same + 1] = b
                elseif TOWNS[b:getZoneID()] then
                    other[#other + 1] = b
                end
            end
        end
    end

    if #same > 0 then
        return same[math.random(1, #same)]
    elseif #other > 0 then
        return other[math.random(1, #other)]
    end

    return nil
end

local function playerShout(player, text)
    if not player or (BotIsBot and BotIsBot(player:getID())) then
        return
    end

    local lower = string.lower(text or '')
    if not (lower:find('tele', 1, true) or lower:find('%f[%a]tp%f[%A]')) then
        return
    end

    local key = destIn(lower)
    if not key then
        return
    end

    local pid = player:getID()
    if now() < (shoutCooldown[pid] or 0) then
        return
    end

    for _, deal in pairs(deals) do
        if deal.player == player:getName() then
            return -- (one at a time)
        end
    end

    shoutCooldown[pid] = now() + 30
    local d = DEST[key]
    local bot = whiteMages(d, player:getZoneID())
    if not bot then
        print(string.format('[bots] tele: %s asks for Teleport-%s, no bot white mage is free', player:getName(), d.name))
        return -- nobody free: nobody answers (as it was)
    end

    local id, name = bot:getID(), player:getName()
    local price = math.random(PRICE[1], PRICE[2]) * 100
    deals[id] = { key = key, price = price, player = name, stage = 'answering', untilT = now() + 150 }

    -- a few seconds to "read" the shout
    bot:timer(math.random(5, 12) * 1000, function(b)
        local p = GetPlayerByName(name)
        local deal = deals[id]
        if not p or not deal then
            deals[id] = nil
            return
        end

        local ki = kiId(d)
        if ki and not p:hasKeyItem(ki) then
            BotTell(id, name, string.format('I can do Teleport-%s, but you need the %s gate crystal first (touch the crag once)', d.name, d.name))
            deals[id] = nil
            return
        end

        if p:getGil() < deal.price then
            BotTell(id, name, string.format('Teleport-%s is %s from me - /shout again when you have it', d.name, gilText(deal.price)))
            deals[id] = nil
            return
        end

        local room = #(p:getParty() or {})
        local okT, total = pcall(function()
            return #p:getPartyWithTrusts()
        end)
        if okT and type(total) == 'number' then
            room = total
        end

        if room >= 6 then
            BotTell(id, name, string.format('I can tele you to %s for %s, but your party is full', d.name, gilText(deal.price)))
            deals[id] = nil
            return
        end

        -- it comes to you (from another area if it has to: a new character object after the zone change)
        if b:getZoneID() ~= p:getZoneID() then
            local pos = p:getPos()
            deal.stage, deal.untilT = 'coming', now() + 150
            BotTell(id, name, string.format('I can tele you to %s for %s - on my way!', d.name, gilText(deal.price)))
            b:setPos(pos.x + 2, pos.y, pos.z + 2, pos.rot, p:getZoneID())
            return
        end

        deal.stage, deal.untilT = 'invited', now() + 120
        BotTell(id, name, string.format('I can tele you to %s for %s - sending an invite!', d.name, gilText(deal.price)))
        BotInvite(id, p)
    end)
end

-- the bot white mage, every second: invite (after coming over), wait for you, cast, get paid
local function dealTick(id, deal)
    local bot = botEntity(id)
    local d = DEST[deal.key]
    local p = GetPlayerByName(deal.player)

    if not bot then
        if now() > deal.untilT then
            deals[id] = nil
        end

        return
    end

    if now() > deal.untilT then
        if p and deal.stage ~= 'cast' then
            BotTell(id, deal.player, ({ 'no worries, maybe later o/', 'gotta go, sorry - shout again anytime' })[math.random(1, 2)])
        end

        if bot:getPartySize() > 1 then
            BotLeaveParty(id)
        end

        deals[id] = nil
        return
    end

    if not p then
        return
    end

    if deal.stage == 'coming' and bot:getZoneID() == p:getZoneID() then
        deal.stage, deal.untilT = 'invited', now() + 120
        BotInvite(id, p)
        return
    end

    if deal.stage == 'invited' and inParty(bot, p) then
        deal.stage, deal.untilT, deal.castAt = 'joined', now() + 240, now() + 4
        BotChat(id, 4, string.format('stay close, casting Teleport-%s in a sec', d.name))
        return
    end

    -- you arrived at the crag (checked first: it must never cast again once there): you pay
    if deal.stage == 'joined' and p:getZoneID() == d.zone then
        deals[id] = nil
        local fee = math.min(deal.price, p:getGil())
        if fee > 0 then
            p:delGil(fee)
            bot:addGil(fee)
        end

        sys(p, string.format('You pay %s %d gil for the teleport.', bot:getName(), fee))
        print(string.format('[bots] tele: %s teleported %s to %s for %d gil', bot:getName(), p:getName(), d.name, fee))
        BotTell(id, deal.player, ({ 'here we are, have fun!', 'ty! good luck out there o/', 'enjoy the hunt!' })[math.random(1, 3)])
        bot:timer(4000, function()
            BotLeaveParty(id)
            local st = state[id]
            if st then
                st.goHome = true -- (back to town)
            end
        end)
        return
    end

    if deal.stage == 'joined' and inParty(bot, p) and bot:getZoneID() == p:getZoneID() and now() >= (deal.castAt or 0) then
        if bot:checkDistance(p) > 8 or bot:isEngaged() or p:isEngaged() or xi.bots.isCasting(bot) then
            return -- (it follows you: wait until it is next to you)
        end

        if p:getGil() < deal.price then
            BotChat(id, 4, string.format('you need %s for it, sorry', gilText(deal.price)))
            deal.untilT = now()
            return
        end

        local sid = spellId(d)
        if not bot:hasSpell(sid) then
            bot:addSpell(sid, { silentLog = true })
        end

        if bot:getMP() < d.mp then
            pcall(function()
                bot:setMP(bot:getMaxMP())
            end)
        end

        deal.castAt = now() + 25 -- (a 20 s cast: tried again if something cut it off)
        if BotCast(id, sid, bot) then
            deal.casting = true
        end

        return
    end

end

-----------------------------------
-- the hooks bots.lua calls
-----------------------------------
function T.setup(st, h)
    state = st or {}
    helpers = h or {}
end

function T.tick(players)
    local t = now()

    -- bots who want a teleport: one at a time per area, only where you are
    local byZone = {}
    for _, p in ipairs(players or {}) do
        local z = p:getZoneID()
        if TOWNS[z] then
            byZone[z] = byZone[z] or {}
            table.insert(byZone[z], p)
        end
    end

    for z, list in pairs(byZone) do
        local busy = false
        for _, offer in pairs(offers) do
            if offer.zone == z then
                busy = true
            end
        end

        if not nextShout[z] then
            nextShout[z] = t + math.random(60, 180)
        elseif not busy and t >= nextShout[z] then
            local can = false
            for _, p in ipairs(list) do
                for _, key in ipairs(ORDER) do
                    if canCast(p, DEST[key]) then
                        can = true
                    end
                end
            end

            local span = can and NEXT_CAN or NEXT_CANNOT
            nextShout[z] = t + math.random(span[1], span[2])
            pcall(startCustomer, z, list)
        end
    end

    for id, offer in pairs(offers) do
        local bot = botEntity(id)
        if not bot then
            if t > offer.untilT then
                offers[id] = nil
            end
        elseif offer.stage == 'shouted' then
            if t > offer.untilT or bot:getZoneID() ~= offer.zone then
                offers[id] = nil
            elseif offer.reshoutAt and t >= offer.reshoutAt then
                offer.reshoutAt = nil
                customerShout(bot, offer)
            end
        elseif offer.stage == 'joined' then
            if bot:getZoneID() == DEST[offer.key].zone then
                customerArrived(bot, offer)
            elseif t > offer.untilT then
                offers[id] = nil
                if offer.player then
                    BotTell(id, offer.player, 'nvm, I will walk - thanks anyway!')
                end

                BotLeaveParty(id)
            end
        end
    end

    for id, deal in pairs(deals) do
        local ok, err = pcall(dealTick, id, deal)
        if not ok then
            print('[bots] tele: ' .. tostring(err))
            deals[id] = nil
        end
    end
end

-- a /tell to a bot: true when this module answered it
function T.onTell(bot, from, text)
    local offer = offers[bot:getID()]
    if offer and offer.stage == 'shouted' and from then
        return customerAnswered(bot, offer, from, false)
    end

    return false
end

-- an invite to a bot (it accepts invites anyway): a WHM inviting a bot that shouted for a teleport takes the job
function T.onInvite(bot, inviterName)
    local offer = offers[bot:getID()]
    if offer and offer.stage == 'shouted' and inviterName then
        pcall(customerAnswered, bot, offer, inviterName, true)
    end
end

-- after a zone change (a new character object): a bot that wanted a teleport and arrived pays from tick()
function T.onZoneIn(bot)
end

T.playerShout = playerShout

-- (for tests and !bots: what is going on)
function T.status()
    return offers, deals
end

return T
