-----------------------------------
-- Forever Gloves (item 23869, XI: Forever Offline, 2026-11-27)
-- Beta testers' hands, their own item: the Fisherman's Gloves' look in the Forever Beta Shirt's colours (hands model 517;
-- the game files come from FFXISOLO\forever_gloves.py). DEF:1 and Fishing skill +1 while worn (item_mods).
-- Used: a teleport to the Fishermen's Guild in Port Windurst, in front of Babubu's counter. The wait after equipping,
-- the single charge that never runs out and the 10 minutes between uses are in modules/custom/sql/forever_gloves.sql.
-- There is no scripts/items/forever_gloves.lua: the server finds the item's functions in xi.items.<name>.
--
-- Everyone gets one, once (like the shirt, the patch and the track pants):
--   * a new character: in their bags at creation (xi.player.charCreate)
--   * a character that already exists: sent to their delivery box at their next login (xi.player.onGameIn)
--   Bot players never get one. A character that already has one anywhere is only marked. Marker: [FGloves]Given.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('forever_gloves')

local ITEM  = 23869
local GIVEN = '[FGloves]Given'

-- The Fishermen's Guild, Port Windurst: on the floor in front of Babubu's counter (Babubu stands at
-- -175.185, -3.324, 70.445; Degong and Chipmy-Popmy, also in the guild, stand on this floor height).
-- (2026-11-27: placed from the NPC positions; to be checked in game.)
local DEST = { x = -181.000, y = -2.835, z = 67.000, rot = 0, zone = xi.zone.PORT_WINDURST }

-- the same wait as a Warp: the item's own animation plays, then the move
local DELAY_MS = 3000

xi.module.ensureTable('xi.items.forever_gloves')

m:addOverride('xi.items.forever_gloves.onItemCheck', function(target, item, caster)
    return 0
end)

m:addOverride('xi.items.forever_gloves.onItemUse', function(target, user)
    target:timer(DELAY_MS, function(player)
        if player:isDead() then
            return
        end

        player:setPos(DEST.x, DEST.y, DEST.z, DEST.rot, DEST.zone)
    end)
end)

local function isBot(player)
    if player:getCharVar('[Bot]Started') ~= 0 then
        return true
    end

    return BotIsBot ~= nil and BotIsBot(player:getID()) and true or false
end

m:addOverride('xi.player.charCreate', function(player)
    super(player)
    if isBot(player) or player:getCharVar(GIVEN) ~= 0 then
        return
    end

    if not player:hasItem(ITEM) then
        player:addItem(ITEM)
    end

    player:setCharVar(GIVEN, 1)
end)

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    local result = super(player, firstLogin, zoning)
    if zoning or firstLogin or player:getCharVar(GIVEN) ~= 0 or isBot(player) then
        return result
    end

    if player:hasItem(ITEM) then
        player:setCharVar(GIVEN, 1)
        return result
    end

    -- marked first, so a send never repeats; only a clear failure (2-4) is tried again at the next login
    player:setCharVar(GIVEN, 1)
    local code = tonumber(SendItemToDeliveryBox(player:getName(), ITEM, 1, 'Forever Offline'))
    if code ~= nil and code >= 2 then
        player:setCharVar(GIVEN, 0)
        print(string.format('[forever_gloves] delivery box send for %s failed (code %d)', player:getName(), code))
    else
        player:printToPlayer('Another gift from the XI: Forever Offline team is in your delivery box: the Forever Gloves!', xi.msg.channel.SYSTEM_3)
    end

    return result
end)

return m
