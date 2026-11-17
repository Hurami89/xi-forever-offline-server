-----------------------------------
-- Module: Anniversary Ring for New Characters
-- Hands out an Anniversary Ring with the Adventurer's Coupon at the end of the opening cutscene.
-- Changing nations replays that cutscene, so only a character's first viewing grants the ring.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('anniversary_ring')
local GIVEN_VAR = '[AnniRing]Given'

local introEvents =
{
    [xi.zone.BASTOK_MARKETS]     = 7,
    [xi.zone.BASTOK_MINES]       = 1,
    [xi.zone.PORT_BASTOK]        = 1,
    [xi.zone.NORTHERN_SAN_DORIA] = 535,
    [xi.zone.SOUTHERN_SAN_DORIA] = 503,
    [xi.zone.PORT_SAN_DORIA]     = 500,
    [xi.zone.WINDURST_WATERS]    = 531,
    [xi.zone.WINDURST_WOODS]     = 367,
    [xi.zone.PORT_WINDURST]      = 305,
}

m:addOverride('xi.server.onServerStart', function()
    super()

    xi.module.modifyInteractionEntry('scripts/quests/hiddenQuests/New_Character_Cutscenes', function(quest)
        for zoneId, eventId in pairs(introEvents) do
            local zoneSection = quest.sections[1][zoneId]
            local baseHandler = zoneSection and zoneSection.onEventFinish[eventId]

            -- A missing handler would leave the whole cutscene unregistered, taking the coupon with it.
            if baseHandler then
                zoneSection.onEventFinish[eventId] = function(player, csid, option, npc)
                    -- The base handler marks the nation, so the first viewing is read ahead of it.
                    local firstViewing = quest:getVar(player, 'nations') == 0
                    local result       = baseHandler(player, csid, option, npc)

                    if firstViewing and player:getCharVar(GIVEN_VAR) == 0 and npcUtil.giveItem(player, xi.item.ANNIVERSARY_RING) then
                        player:setCharVar(GIVEN_VAR, 1)
                    end

                    return result
                end
            end
        end
    end)
end)

-- Everyone gets the ring once, cutscene watched or skipped (XI: Forever Offline, 2026-11-17): at log in or after a
-- zone, a character that never had it is handed one. A brand-new character waits until after the opening
-- cutscene, which gives it the usual way; a full bag tries again next time.
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    local result = super(player, firstLogin, zoning)
    if BotIsBot and BotIsBot(player:getID()) then
        return result
    end

    if player:getCharVar(GIVEN_VAR) ~= 0 then
        return result
    end

    if player:hasItem(xi.item.ANNIVERSARY_RING) then
        player:setCharVar(GIVEN_VAR, 1)
    elseif firstLogin and xi.settings.main.NEW_CHARACTER_CUTSCENE == 1 then
        return result -- (the opening cutscene hands it out; skipped, it comes at the next zone or log in)
    else
        player:timer(3000, function(p)
            if p:getCharVar(GIVEN_VAR) == 0 and not p:hasItem(xi.item.ANNIVERSARY_RING) and npcUtil.giveItem(p, xi.item.ANNIVERSARY_RING) then
                p:setCharVar(GIVEN_VAR, 1)
            end
        end)
    end

    return result
end)

return m
