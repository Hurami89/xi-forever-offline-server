-----------------------------------
-- Door keys and squad weight (XI: Forever Offline, 2026-11-18, Yache's suggestion)
--
-- Some era doors need several people: the Quicksand Caves ornate doors open with enough weight on their plate, the
-- Garlaige Citadel Banishing Gates and the Eldieme Necropolis gates with a party working them together. Playing alone
-- with a squad, that couldn't be done. So:
--  1. Squad mates standing near you count as weight on a Quicksand Caves plate (Galka 3, Tarutaru 1, others 2), the same
--     as party members would.
--  2. The later key items that open these doors for one person are there: Pouch of Weighted Stones (the ??? in Garlaige
--     Citadel) and Loadstone (Lokpix, quest Open Sesame) are un-hidden in this module's zone data. The Magicked
--     Astrolabe (Churano-Shurano, Windurst Waters, 10,000 gil) is sold by trade here: his menu is missing from the era
--     game files, so talking to him only tells you to trade the gil.
--  3. (2026-11-19) Garlaige Citadel Banishing Gates: each gate needs all four of its levers held down at once. When you
--     step on a lever, your squad mates take the other levers: with enough mates out (you + mates = 4, counting anyone
--     already standing on a lever), the gate opens as if four people held them.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('door_keys')

local MATE_RANGE = 6 -- yalms: mates this close to you on the plate count

local function weightOf(entity)
    local race = entity:getRace()
    if race == xi.race.GALKA then
        return 3
    elseif race == xi.race.TARU_M or race == xi.race.TARU_F then
        return 1
    end

    return 2
end

local function matesWeight(player)
    local total = 0
    for _, member in pairs(player:getPartyWithTrusts()) do
        if member:getObjType() == xi.objType.TRUST and member:isAlive() and member:getMaster() ~= nil and
            member:getMaster():getID() == player:getID() and player:checkDistance(member) <= MATE_RANGE then
            total = total + weightOf(member)
        end
    end

    return total
end

m:addOverride('xi.zones.Quicksand_Caves.Zone.onTriggerAreaEnter', function(player, triggerArea)
    local areaId = triggerArea:getTriggerAreaID()
    if player ~= nil and areaId < 30 then
        local ID    = zones[xi.zone.QUICKSAND_CAVES]
        local plate = GetNPCByID(ID.npc.ORNATE_DOOR_OFFSET + areaId)
        local extra = matesWeight(player)
        if plate ~= nil and extra > 0 then
            plate:setLocalVar('weight', plate:getLocalVar('weight') + extra)
            player:setLocalVar('DOOR_MATES_' .. areaId, extra)
        end
    end

    super(player, triggerArea)
end)

m:addOverride('xi.zones.Quicksand_Caves.Zone.onTriggerAreaLeave', function(player, triggerArea)
    super(player, triggerArea)

    local areaId = triggerArea:getTriggerAreaID()
    if player ~= nil and areaId < 30 then
        local extra = player:getLocalVar('DOOR_MATES_' .. areaId)
        local ID    = zones[xi.zone.QUICKSAND_CAVES]
        local plate = GetNPCByID(ID.npc.ORNATE_DOOR_OFFSET + areaId)
        if plate ~= nil and extra > 0 then
            plate:setLocalVar('weight', math.max(0, plate:getLocalVar('weight') - extra))
            player:setLocalVar('DOOR_MATES_' .. areaId, 0)
        end
    end
end)

-- Pouch of Weighted Stones: the ??? hands it over without its cutscene (the era game files may not have that event)
m:addOverride('xi.zones.Garlaige_Citadel.npcs.qm17.onTrigger', function(player, npc)
    if player:hasKeyItem(xi.keyItem.POUCH_OF_WEIGHTED_STONES) then
        local ID = zones[xi.zone.GARLAIGE_CITADEL]
        player:messageSpecial(ID.text.NOTHING_OUT_OF_ORDINARY)
        return
    end

    player:printToPlayer('A pouch of heavy stones lies here. With its weight the Banishing Gates open for you alone.', xi.msg.channel.SYSTEM_3)
    npcUtil.giveKeyItem(player, xi.keyItem.POUCH_OF_WEIGHTED_STONES)
end)

-- Magicked Astrolabe: trade 10,000 gil to Churano-Shurano
local ASTROLABE_COST = 10000

m:addOverride('xi.zones.Windurst_Waters.npcs.Churano-Shurano.onTrigger', function(player, npc)
    if player:hasKeyItem(xi.keyItem.MAGICKED_ASTROLABE) then
        player:printToPlayer('You already have a Magicked Astrolabe. It opens the gates of the Eldieme Necropolis for you.', xi.msg.channel.NS_SAY, npc:getPacketName())
        return
    end

    player:printToPlayer(string.format('A Magicked Astrolabe opens the gates of the Eldieme Necropolis without anyone working the plates. ' ..
        'Trade me %d gil and it is yours.', ASTROLABE_COST), xi.msg.channel.NS_SAY, npc:getPacketName())
end)

m:addOverride('xi.zones.Windurst_Waters.npcs.Churano-Shurano.onTrade', function(player, npc, trade)
    if player:hasKeyItem(xi.keyItem.MAGICKED_ASTROLABE) then
        return
    end

    if trade:getGil() >= ASTROLABE_COST and trade:getItemCount() == 1 then
        player:confirmTrade()
        npcUtil.giveKeyItem(player, xi.keyItem.MAGICKED_ASTROLABE)
    else
        player:printToPlayer(string.format('That is not enough. It costs %d gil.', ASTROLABE_COST), xi.msg.channel.NS_SAY, npc:getPacketName())
    end
end)

-- Garlaige Citadel Banishing Gates: squad mates pull the other levers
local LEVER_MATE_RANGE = 80 -- yalms: mates this close to you run to the other levers (gate #2's levers are ~100 apart)

local function leverMates(player)
    local count = 0
    for _, member in pairs(player:getPartyWithTrusts()) do
        if member:getObjType() == xi.objType.TRUST and member:isAlive() and member:getMaster() ~= nil and
            member:getMaster():getID() == player:getID() and player:checkDistance(member) <= LEVER_MATE_RANGE then
            count = count + 1
        end
    end

    return count
end

m:addOverride('xi.zones.Garlaige_Citadel.Zone.onTriggerAreaEnter', function(player, triggerArea)
    super(player, triggerArea)

    local ID = zones[xi.zone.GARLAIGE_CITADEL]
    local areaId = triggerArea:getTriggerAreaID()
    if player == nil or ID == nil or ID.npc.BANISHING_GATE_OFFSET == nil then
        return
    end

    local gateId = ID.npc.BANISHING_GATE_OFFSET + 9 * math.floor(areaId / 9)
    local gate   = GetNPCByID(gateId)
    if gate == nil or gate:getAnimation() ~= xi.animation.CLOSE_DOOR then
        return
    end

    -- levers still up in this set, and who can take them
    local up = {}
    for i = 1, 4 do
        local lever = GetNPCByID(gateId + i)
        if lever ~= nil and lever:getAnimation() ~= xi.animation.OPEN_DOOR then
            up[#up + 1] = lever
        end
    end

    if #up == 0 or leverMates(player) < #up then
        if #up > 0 and leverMates(player) > 0 then
            player:printToPlayer(string.format('Your squad mates can only hold %d of the %d other levers. Call more mates to open this gate.',
                leverMates(player), #up), xi.msg.channel.SYSTEM_3)
        end

        return
    end

    for _, lever in ipairs(up) do
        lever:setAnimation(xi.animation.OPEN_DOOR)
    end

    player:printToPlayer('Your squad mates run to the other levers and pull them down.', xi.msg.channel.SYSTEM_3)
    super(player, triggerArea) -- the zone's own check now finds all four levers down and opens the gate

    -- the mates let go a moment later (the gate stays open for its usual time)
    gate:timer(3000, function()
        for _, lever in ipairs(up) do
            lever:setAnimation(xi.animation.CLOSE_DOOR)
        end
    end)
end)

-- (2026-11-19, Yache, Tasou: the pouch did nothing) the era module weighted_stones_hint empties the three Banishing Gates'
-- triggers (before 2012 the pouch could not open them). We give the pouch out, so with it the gate opens for you alone again,
-- as in the core scripts: a short delay, open for 15 seconds, from either side.
for _, gateName in ipairs({ '_5k0', '_5k9', '_5ki' }) do
    m:addOverride('xi.zones.Garlaige_Citadel.npcs.' .. gateName .. '.onTrigger', function(player, npc)
        if npc:getAnimation() ~= xi.animation.CLOSE_DOOR then
            return
        end

        local ID = zones[xi.zone.GARLAIGE_CITADEL]
        if player:hasKeyItem(xi.keyItem.POUCH_OF_WEIGHTED_STONES) then
            if ID and ID.text and ID.text.THE_GATE_OPENS_FOR_YOU then
                player:messageSpecial(ID.text.THE_GATE_OPENS_FOR_YOU, xi.keyItem.POUCH_OF_WEIGHTED_STONES)
            end

            npc:timer(1500, function(npcArg)
                npcArg:openDoor(15)
            end)
        else
            player:printToPlayer('The gate is shut fast. Four levers nearby must be held down together, or something heavy might do.', xi.msg.channel.SYSTEM_3)
        end
    end)
end

return m
