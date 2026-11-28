-----------------------------------
-- XI: Forever Offline: wedding ceremonies (2026-11-27, Hurami). Part of modules/wedding (switch: dev launcher,
-- Era > Out-of-era content > Weddings).
--
-- Retail never had a ceremony in the game (Square Enix staff ran them live), so this one is our own. At a Wedding
-- Master (Rembard, Cloud Walker, Pompi-Rompi) two real characters who are in the same party and both wear a
-- Matrimony Ring, Matrimony Band or Wedding Ring can hold their ceremony, now or in 10 minutes (so friends can come).
-- Every world: your own, co-op, home-hosted, the Hub. One ceremony at a time per palace.
--
-- The ceremony: the room hears Prelude, the couple stand before the Master, the Master speaks, each one says "I do"
-- (a menu), the rings, bows, then Eternal Oath (the game's wedding song), fireworks and bots nearby cheering. After it
-- the two are married (one spouse per character: WeddingSpouse, the variable the certificate code already uses) and
-- the world hears of it; with online sharing on (the hardcore announcer) the Hub and Stinkshell do too. The marriage
-- certificates are the retail part: the couple then speak to the Master together, as before.
-----------------------------------
require('modules/module_utils')
require('scripts/globals/wedding')
-----------------------------------
local m = Module:new('wedding_ceremony')

xi = xi or {}
xi.weddingCeremony = xi.weddingCeremony or {}
local W = xi.weddingCeremony

local SPOUSE_VAR   = 'WeddingSpouse'
local PRELUDE      = 153             -- Serene Serinette's track
local ETERNAL_OATH = 214             -- Joyous Serinette's track: the wedding song
local NEAR_MASTER  = 15              -- yalms: the couple must be this close to start
local WAIT_S       = 10 * 60         -- "in 10 minutes"
local ANSWER_S     = 60              -- the partner's answer, each vow
local MUSIC_BACK_S = 120             -- after the vows the song plays on this long, then the area's music comes back
local OUT_FILE     = 'modules/custom/lua/hardcore_out.txt'   -- the launcher's announcer sends these lines online

local PLACES =
{
    [xi.zone.CHATEAU_DORAGUILLE] = { master = 'Rembard',     place = "Chateau d'Oraguille", code = 'SAN' },
    [xi.zone.METALWORKS]         = { master = 'Cloud Walker', place = 'the Metalworks',     code = 'BAS' },
    [xi.zone.HEAVENS_TOWER]      = { master = 'Pompi-Rompi',  place = 'Heavens Tower',      code = 'WIN' },
}

local RINGS =
{
    [xi.item.MATRIMONY_RING] = true,
    [xi.item.MATRIMONY_BAND] = true,
    [xi.item.WEDDING_RING]   = true,
}

W.state = W.state or {}      -- zone id -> the ceremony booked or under way there
local serial = 0

-----------------------------------
-- small helpers
-----------------------------------
local function tell(player, text)
    player:printToPlayer(text, xi.msg.channel.SYSTEM_3)
end

local function byName(name)
    if not name or not GetPlayerByName then
        return nil
    end

    local ok, found = pcall(GetPlayerByName, name)
    return ok and found or nil
end

-- the partner of a ceremony: a real character or a bot (by name), or the engaged squad mate out with the player
local function partnerEntity(st, a)
    if st.bKind ~= 'mate' then
        return byName(st.b)
    end

    a = a or byName(st.a)
    if not a then
        return nil
    end

    for _, member in ipairs(a:getPartyWithTrusts()) do
        if member:getLocalVar('SQUAD_ID') == st.bMateId then
            return member
        end
    end

    return nil
end

local function wearsRing(player)
    return RINGS[player:getEquipID(xi.slot.RING1)] == true or RINGS[player:getEquipID(xi.slot.RING2)] == true
end

local function spouseOf(player)
    return player:getCharVar(SPOUSE_VAR)
end

local function isBot(entity)
    return BotIsBot ~= nil and BotIsBot(entity:getID()) == true
end

local function inParty(player, other)
    for _, member in ipairs(player:getParty()) do
        if member:getID() == other:getID() then
            return true
        end
    end

    return false
end

local function menu(player, title, options)
    player:setFreezeFlag(true)
    player:customMenu({
        title = title,
        options = options,
        onCancelled = function(p)
            p:setFreezeFlag(false)
        end,
        onEnd = function(p)
            p:setFreezeFlag(false)
        end,
    })
end

local function clock(when)
    return os.date('%H:%M', when)
end

-- The Master speaks: shown as the Master's own words to everyone in the palace room (sent through the couple).
local function masterSays(st, text)
    local speaker = byName(st.a) or (st.bKind == 'pc' and byName(st.b)) or nil
    if speaker and speaker:getZoneID() == st.zone then
        speaker:printToArea(text, xi.msg.channel.SAY, xi.msg.area.SHOUT, PLACES[st.zone].master)
    end
end

local function playersHere(zoneId)
    local zone = GetZone and GetZone(zoneId) or nil
    return zone and zone:getPlayers() or {}
end

local function setMusic(zoneId, track)
    for _, p in ipairs(playersHere(zoneId)) do
        if not isBot(p) then
            for _, slot in ipairs({ xi.musicSlot.ZONE_DAY, xi.musicSlot.ZONE_NIGHT, xi.musicSlot.COMBAT_SOLO, xi.musicSlot.COMBAT_PARTY }) do
                p:changeMusic(slot, track)
            end
        end
    end
end

local function musicBack(zoneId)
    local zone = GetZone and GetZone(zoneId) or nil
    if not zone then
        return
    end

    local tracks =
    {
        [xi.musicSlot.ZONE_DAY]     = zone:getBackgroundMusicDay(),
        [xi.musicSlot.ZONE_NIGHT]   = zone:getBackgroundMusicNight(),
        [xi.musicSlot.COMBAT_SOLO]  = zone:getSoloBattleMusic(),
        [xi.musicSlot.COMBAT_PARTY] = zone:getPartyBattleMusic(),
    }
    for _, p in ipairs(zone:getPlayers()) do
        if not isBot(p) then
            for slot, track in pairs(tracks) do
                if tonumber(track) then
                    p:changeMusic(slot, track)
                end
            end
        end
    end
end

-- A line for the whole world, and (online sharing on) for the Hub and Stinkshell through the hardcore announcer.
local function announce(st, text, kind)
    local speaker = byName(st.a) or (st.bKind == 'pc' and byName(st.b)) or nil
    if speaker then
        pcall(function()
            speaker:printToArea(string.format('\129\154 %s \129\154', text), xi.msg.channel.SYSTEM_3, xi.msg.area.SYSTEM, '', false)
        end)
    end

    local H = xi.hardcore
    if H and H.shareOnline == false then
        return
    end

    local handle = io.open(OUT_FILE, 'a')
    if handle then
        handle:write(string.format('%d|%s|%s|Wedding|%s|0|%s|%s\n', os.time(), kind, st.a, PLACES[st.zone].code, st.b,
                                   (H and H.worldName or ''):gsub('[|\r\n]', ' ')))
        handle:close()
    end
end

-----------------------------------
-- can these two hold a ceremony here?
-----------------------------------
local function partnerFor(player, npc)
    local found = nil
    for _, member in ipairs(player:getParty()) do
        if member:getID() ~= player:getID() and member:isPC() and not isBot(member) then
            if found then
                return nil, 'Only the two of you may be in the party (squad mates are fine).'
            end

            found = member
        end
    end

    if not found then
        return nil, 'Come with your partner: the two of you in one party.'
    end

    if found:getZoneID() ~= player:getZoneID() or found:checkDistance(npc) > NEAR_MASTER then
        return nil, string.format('%s should stand here with you.', found:getName())
    end

    return found
end

local function why(player, partner)
    if not wearsRing(player) or not wearsRing(partner) then
        return 'Both of you should wear your ring: a Matrimony Ring, a Matrimony Band or a Wedding Ring.'
    end

    local sa, sb = spouseOf(player), spouseOf(partner)
    if (sa ~= 0 and sa ~= partner:getID()) or (sb ~= 0 and sb ~= player:getID()) then
        return 'One of you is already married to someone else.'
    end

    return nil
end

-----------------------------------
-- the ceremony
-----------------------------------
local function release(st)
    if W.state[st.zone] == st then
        W.state[st.zone] = nil
    end
end

local function callOff(st, text)
    if st.done then
        return
    end

    st.done = true
    if text then
        masterSays(st, text)
    end

    if st.started then
        musicBack(st.zone)
    end

    release(st)
end

-- the next step after ms, only while this ceremony is still the one going on and both are still here
local function after(st, ms, func)
    local speaker = byName(st.a) or (st.bKind == 'pc' and byName(st.b)) or nil
    if not speaker then
        callOff(st)
        return
    end

    speaker:timer(ms, function()
        if st.done or W.state[st.zone] ~= st then
            return
        end

        local a = byName(st.a)
        local b = partnerEntity(st, a)
        if not a or not b or a:getZoneID() ~= st.zone or b:getZoneID() ~= st.zone then
            callOff(st, 'One of the two has left us... We will wait for another day.')
            return
        end

        func(a, b)
    end)
end

local function bow(who, to)
    pcall(function()
        if isBot(who) and BotEmote then
            BotEmote(who:getID(), to, xi.emote.BOW, (xi.emoteMode and xi.emoteMode.MOTION) or 2)
        else
            who:sendEmote(to, xi.emote.BOW, xi.emoteMode.MOTION, false)
        end
    end)
end

local function fireworks(st)
    local npc = st.npcId and GetNPCByID(st.npcId) or nil
    if not npc then
        return
    end

    -- the item-use animations of Wedding Bell, Popstar, Brilliant Snow and Ouka Ranman
    local shows = { { 4170, 46 }, { 4215, 51 }, { 4216, 52 }, { 4256, 56 } }
    for i, show in ipairs(shows) do
        npc:timer(i * 1500, function(n)
            n:injectActionPacket(n:getID(), xi.action.category.ITEM_FINISH, show[2], 0, 0, 0, show[1], 0)
        end)
    end
end

local function guestsCheer(st)
    if not BotEmote then
        return
    end

    local npc = st.npcId and GetNPCByID(st.npcId) or nil
    for _, p in ipairs(playersHere(st.zone)) do
        if isBot(p) and (not npc or p:checkDistance(npc) <= 30) then
            local cheer = ({ 'CHEER', 'CLAP', 'JOY', 'PRAISE' })[math.random(1, 4)]
            local id = p:getID()
            p:timer(math.random(300, 3500), function()
                if xi.emote and xi.emote[cheer] then
                    BotEmote(id, nil, xi.emote[cheer], (xi.emoteMode and xi.emoteMode.MOTION) or 2)
                end
            end)
        end
    end
end

-- the couple before the Master, side by side, facing the Master
local function placeCouple(st, a, b)
    local npc = st.npcId and GetNPCByID(st.npcId) or nil
    if not npc then
        return
    end

    local origin = npc:getPos()
    local facing = utils.rotationToAngle(npc:getRotPos())
    local front = utils.getNearPosition(origin, 3, facing)
    local left  = utils.getNearPosition(front, 0.9, facing + math.pi / 2)
    local right = utils.getNearPosition(front, 0.9, facing - math.pi / 2)
    local towardMaster = (npc:getRotPos() + 128) % 256
    a:setPos(left.x, origin.y, left.z, towardMaster)
    b:setPos(right.x, origin.y, right.z, towardMaster)
end

local function faceEachOther(a, b)
    local pa, pb = a:getPos(), b:getPos()
    a:setPos(pa.x, pa.y, pa.z, utils.getWorldRotation(pa, pb))
    b:setPos(pb.x, pb.y, pb.z, utils.getWorldRotation(pb, pa))
end

local function vow(st, who, other, nextStep)
    local answered = false
    local whoName = who == 'B' and st.b or st.a
    local otherName = who == 'B' and st.a or st.b
    masterSays(st, string.format('%s, will you walk beside %s in all the days to come, through every land and every storm?',
                                 whoName, otherName))
    if who == 'B' and st.bKind ~= 'pc' then
        -- the squad mate or bot answers for itself
        after(st, 3500, function(a, b)
            local words = (xi.romance and xi.romance.vow and st.romance) and xi.romance.vow(st.romance) or 'I do.'
            a:printToArea(words, xi.msg.channel.SAY, xi.msg.area.SHOUT, st.b)
            nextStep()
        end)
        return
    end

    after(st, 2500, function(a, b)
        local me = who == 'A' and a or b
        menu(me, string.format('Your vow to %s', otherName), {
            { 'I do.', function(p)
                if answered or st.done then
                    return
                end

                answered = true
                p:printToArea('I do.', xi.msg.channel.SAY, xi.msg.area.SAY, p:getName())
                nextStep()
            end },
            { 'I... need a moment. (stop the ceremony)', function(p)
                if answered then
                    return
                end

                answered = true
                callOff(st, 'There is no hurry. Come back to me when your hearts are ready.')
            end },
        })
        me:timer(ANSWER_S * 1000, function(p)
            if not answered and not st.done then
                answered = true
                callOff(st, 'There is no hurry. Come back to me when your hearts are ready.')
            end
        end)
    end)
end

local CERTIFICATES = { SAN = 'SAN_DORIAN_MARRIAGE_CERTIFICATE', BAS = 'BASTOKAN_MARRIAGE_CERTIFICATE', WIN = 'WINDURSTIAN_MARRIAGE_CERTIFICATE' }

local function finish(st, a, b)
    st.done = true
    local place = PLACES[st.zone].place
    if st.bKind == 'pc' then
        a:setCharVar(SPOUSE_VAR, b:getID())
        b:setCharVar(SPOUSE_VAR, a:getID())
        announce(st, string.format('%s and %s were married in %s! Congratulations!', st.a, st.b, place), 'wedding')
        masterSays(st, string.format('Come and speak with me together, and I will prepare your marriage certificates.'))
    else
        st.romance.entity = b
        xi.romance.marry(a, st.romance)
        announce(st, string.format('%s and %s were married in %s! Congratulations!', st.a, st.b, place), 'wedding')
        local cert = xi.item[CERTIFICATES[PLACES[st.zone].code]]
        if cert and not a:hasItem(cert) and a:getFreeSlotsCount() > 0 then
            a:addItem(cert)
            a:messageSpecial(zones[st.zone].text.ITEM_OBTAINED, cert)
        end

        masterSays(st, 'Here is your marriage certificate. May the Crystals light your way, together.')
        local happy = xi.romance.written and xi.romance.written('afterWedding')
        if happy then
            a:timer(4000, function(e)
                xi.romance.say(e, st.romance, xi.romance.fill(happy, { name = e:getName() }))
            end)
        end
    end
    release(st)
    a:timer(MUSIC_BACK_S * 1000, function()
        if not W.state[st.zone] then
            musicBack(st.zone)
        end
    end)
end

local function run(st)
    st.started = true
    local a = byName(st.a)
    local b = partnerEntity(st, a)
    if not a or not b then
        callOff(st)
        return
    end

    placeCouple(st, a, b)
    setMusic(st.zone, PRELUDE)
    local place = PLACES[st.zone].place
    after(st, 3000, function()
        masterSays(st, string.format('Friends, we are gathered here in %s to celebrate the union of %s and %s.', place, st.a, st.b))
    end)
    after(st, 9000, function()
        masterSays(st, 'Their journey across Vana\'diel has brought them here, side by side, before the Crystals.')
    end)
    after(st, 15000, function()
        vow(st, 'A', 'B', function()
            after(st, 2000, function()
                vow(st, 'B', 'A', function()
                    after(st, 2500, function(p, q)
                        masterSays(st, 'Then let these rings be the sign of your vows.')
                        faceEachOther(p, q)
                        bow(p, q)
                        p:timer(1500, function()
                            local other = partnerEntity(st)
                            if other then
                                bow(other, p)
                            end
                        end)
                    end)
                    after(st, 7000, function(p, q)
                        setMusic(st.zone, ETERNAL_OATH)
                        masterSays(st, string.format('By the light of the Crystals, I now pronounce %s and %s partners for life!', st.a, st.b))
                        fireworks(st)
                        guestsCheer(st)
                    end)
                    after(st, 13000, function(p, q)
                        finish(st, p, q)
                    end)
                end)
            end)
        end)
    end)
end

-----------------------------------
-- booking: the partner says yes, then now or in 10 minutes
-----------------------------------
local function book(player, partner, npc, delay, romance)
    local zoneId = player:getZoneID()
    serial = serial + 1
    local st = { id = serial, zone = zoneId, a = player:getName(), b = romance and romance.name or partner:getName(), npcId = npc:getID(),
                 startAt = os.time() + delay, done = false, started = false,
                 bKind = romance and romance.kind or 'pc', bMateId = romance and romance.kind == 'mate' and romance.id or nil,
                 romance = romance }
    W.state[zoneId] = st

    if delay <= 0 then
        run(st)
        return
    end

    local place = PLACES[zoneId].place
    announce(st, string.format('%s and %s will be married in %s at %s (in 10 minutes). All are welcome!',
                               st.a, st.b, place, clock(st.startAt)), 'wedding_soon')
    masterSays(st, string.format('Wonderful! Your ceremony begins at %s. Be here, both of you, and wear your rings.', clock(st.startAt)))

    local function remind(msLeftText, ms)
        npc:timer(ms, function()
            if W.state[zoneId] == st and not st.started and not st.done then
                for _, name in ipairs({ st.a, st.b }) do
                    local p = byName(name)
                    if p then
                        tell(p, string.format('Your wedding ceremony in %s begins in %s.', place, msLeftText))
                    end
                end
            end
        end)
    end

    remind('5 minutes', (delay - 300) * 1000)
    remind('1 minute', (delay - 60) * 1000)
    npc:timer(delay * 1000, function(n)
        if W.state[zoneId] ~= st or st.started or st.done then
            return
        end

        local a = byName(st.a)
        local b = partnerEntity(st, a)
        local reason = nil
        if not a or not b or a:getZoneID() ~= zoneId or b:getZoneID() ~= zoneId then
            reason = 'The couple is not here... the ceremony will have to wait for another day.'
        elseif a:checkDistance(n) > NEAR_MASTER or b:checkDistance(n) > NEAR_MASTER then
            reason = 'The couple should stand before me. Speak to me again when you are both here.'
        elseif st.bKind == 'pc' and why(a, b) then
            reason = why(a, b)
        elseif st.bKind ~= 'pc' and not wearsRing(a) then
            reason = 'Wear your ring for the ceremony.'
        end

        if reason then
            callOff(st, reason)
            return
        end

        run(st)
    end)
end

local function ask(player, partner, npc, delay)
    local answered = false
    tell(player, string.format('You ask %s. Waiting for an answer...', partner:getName()))
    menu(partner, string.format('%s: your wedding ceremony %s?', player:getName(), delay > 0 and 'in 10 minutes' or 'now'), {
        { 'Yes!', function(p)
            if answered then
                return
            end

            answered = true
            local a = byName(player:getName())
            if not a or W.state[p:getZoneID()] then
                tell(p, 'The Master is busy just now.')
                return
            end

            local reason = why(a, p)
            if reason then
                tell(a, reason)
                tell(p, reason)
                return
            end

            book(a, p, npc, delay)
        end },
        { 'Not yet.', function(p)
            if answered then
                return
            end

            answered = true
            local a = byName(player:getName())
            if a then
                tell(a, string.format('%s would like to wait a little.', p:getName()))
            end
        end },
    })
    partner:timer(ANSWER_S * 1000, function()
        if not answered then
            answered = true
            local a = byName(player:getName())
            if a then
                tell(a, string.format('%s did not answer.', partner:getName()))
            end
        end
    end)
end

-----------------------------------
-- the Wedding Master
-----------------------------------
m:addOverride('xi.wedding.onTrigger', function(player, npc)
    local zoneId = player:getZoneID()
    local here = PLACES[zoneId]
    local st = W.state[zoneId]

    if here and st and not st.done then
        local mine = player:getName() == st.a or player:getName() == st.b
        if st.started then
            tell(player, mine and 'Your ceremony is under way!' or string.format('The wedding of %s and %s is under way.', st.a, st.b))
            return
        end

        if not mine then
            tell(player, string.format('%s and %s will be married here at %s. You are welcome to stay!', st.a, st.b, clock(st.startAt)))
            return
        end

        menu(player, string.format('Your ceremony: %s', clock(st.startAt)), {
            { 'Begin now (we are both here)', function(p)
                local a = byName(st.a)
                local b = partnerEntity(st, a)
                local n = GetNPCByID(st.npcId)
                if not a or not b or not n or a:getZoneID() ~= zoneId or b:getZoneID() ~= zoneId or
                    a:checkDistance(n) > NEAR_MASTER or b:checkDistance(n) > NEAR_MASTER then
                    tell(p, 'You should both stand here first.')
                    return
                end

                run(st)
            end },
            { 'Call it off', function(p)
                callOff(st, 'As you wish. Come back to me whenever you are ready.')
            end },
            { 'Marriage certificates', function(p)
                p:timer(250, function(e)
                    super(e, npc)
                end)
            end },
        })
        return
    end

    local partner, problem = nil, nil
    if here then
        partner, problem = partnerFor(player, npc)
    end

    local engaged = here and not partner and xi.romance and xi.romance.engagedPartner and xi.romance.engagedPartner(player) or nil
    if engaged and engaged.entity and engaged.entity:checkDistance(npc) <= NEAR_MASTER then
        local function start(p, delay)
            if not wearsRing(p) then
                tell(p, 'Wear your own Matrimony Ring or Band (or a Wedding Ring) for the ceremony.')
                return
            end

            if W.state[p:getZoneID()] then
                tell(p, 'The Master is busy just now.')
                return
            end

            xi.romance.say(p, engaged, delay > 0 and 'In ten minutes? I\'ll be counting every one of them.' or 'Now? Yes... yes, let\'s!')
            book(p, engaged.entity, npc, delay, engaged)
        end

        menu(player, string.format('%s, Wedding Master', here.master), {
            { string.format('Hold our wedding ceremony now (with %s)', engaged.name), function(p)
                start(p, 0)
            end },
            { 'Hold it in 10 minutes (friends can come)', function(p)
                start(p, WAIT_S)
            end },
            { 'Marriage certificates', function(p)
                p:timer(250, function(e)
                    super(e, npc)
                end)
            end },
        })
        return
    end

    if not here or not partner then
        if here and problem and wearsRing(player) then
            tell(player, string.format('For a wedding ceremony: %s', problem))
        end

        super(player, npc)
        return
    end

    menu(player, string.format('%s, Wedding Master', here.master), {
        { string.format('Hold our wedding ceremony now (with %s)', partner:getName()), function(p)
            local reason = why(p, partner)
            if reason then
                tell(p, reason)
                return
            end

            ask(p, partner, npc, 0)
        end },
        { 'Hold it in 10 minutes (friends can come)', function(p)
            local reason = why(p, partner)
            if reason then
                tell(p, reason)
                return
            end

            ask(p, partner, npc, WAIT_S)
        end },
        { 'Marriage certificates', function(p)
            p:timer(250, function(e)
                super(e, npc)
            end)
        end },
    })
end)

return m
