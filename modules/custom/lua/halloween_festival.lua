-----------------------------------
-- Harvest Festival visibility
-----------------------------------
-- The stock event only changes a handful of stationary NPCs into costumes,
-- and there are no city decorations. Re-apply those costumes when a player
-- enters San d'Oria and print a one-per-day notice so the festival is easy
-- to find. No core scripts are changed.
-----------------------------------

local m = Module:new('halloween_festival')

local function announce(player)
    local festival = xi.events.harvestFestival
    if not festival or type(festival.isHalloweenEnabled) ~= 'function' or festival.isHalloweenEnabled() == 0 then
        return
    end

    -- Safe on every zone-in: the stock function only swaps NPC looks.
    local zoneId = player:getZoneID()
    if zones[zoneId] and zones[zoneId].npc and type(festival.applyHalloweenNpcCostumes) == 'function' then
        festival.applyHalloweenNpcCostumes(zoneId)
    end

    local today = tonumber(os.date('%Y%m%d')) or 0
    if player:getCharVar('harvestFestNotice') == today then
        return
    end
    player:setCharVar('harvestFestNotice', today)

    local hints =
    {
        [xi.zone.NORTHERN_SAN_DORIA] = "In Northern San d'Oria, look for Vichuel (F-4), Antonian (J-8), and Attarena (M-9).",
        [xi.zone.SOUTHERN_SAN_DORIA] = "In Southern San d'Oria, look for Machielle (G-9) and the other costumed townsfolk around the auction house and gates.",
    }
    local hint = hints[zoneId] or 'Costumed townsfolk are waiting in the starting cities.'
    player:printToPlayer('The Harvest Festival is underway! ' .. hint .. ' Trade them a sweet for a trick.', xi.msg.channel.SYSTEM_3)
end

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    announce(player)
end)

for _, zoneName in ipairs({ 'Southern_San_dOria', 'Northern_San_dOria' }) do
    m:addOverride('xi.zones.' .. zoneName .. '.Zone.onZoneIn', function(player, prevZone)
        local result = super(player, prevZone)
        announce(player)
        return result
    end)
end

return m
