-----------------------------------
-- XI: Forever Offline (2026-11-27, the user: "a command like betagifts ... so players can spawn these any time, even
-- non-GM, like a starting gear command")
-- !betagifts gives back the beta testers' Forever gifts a character does not have: the Forever Beta Shirt (25725), the
-- Forever Patch (23867), the Forever Track Pants (23868) and the Forever Gloves (23869).
--   * Every player, any time, on their own character. Free.
--   * Only what is missing: they are Rare (one each), so one the character already has anywhere (bags, Mog Safe,
--     wardrobes, worn) is skipped. One still waiting in the delivery box is NOT seen by the game's check, so the
--     reply says to take those out first; giving a second one there would be refused by the Rare rule anyway.
--   * Into the inventory only, one free slot each; with no room it says how many slots to free.
--   * A gift whose item is not on this server (its SQL file not loaded) is skipped with a line.
--   * Each gift's own "given once" marker is set too, so its log in gift does not send another one later.
--   * Charges arrive full (a new item), like the gift at log in.
-- A command and nothing else, so there is no Module:new here (a module with no overrides is an error line in the map
-- log at every start). Loaded with the rest of custom/late (modules/init.txt lists the folder).
-----------------------------------
require('modules/module_utils')

local GIFTS =
{
    { id = 25725, name = 'Forever Beta Shirt',  marker = '[FBShirt]Given' },
    { id = 23867, name = 'Forever Patch',       marker = '[FPatch]Given'  },
    { id = 23868, name = 'Forever Track Pants', marker = '[FJeans]Given'  },
    { id = 23869, name = 'Forever Gloves',      marker = '[FGloves]Given' },
}

local function say(player, text)
    player:printToPlayer(text, xi.msg.channel.SYSTEM_3)
end

local function exists(id)
    return GetItemByID == nil or GetItemByID(id) ~= nil
end

local command = {}
command.cmdprops = { permission = 0, parameters = '' } -- every player, on their own character

command.onTrigger = function(player)
    local missing = {}
    local unknown = {}
    for _, gift in ipairs(GIFTS) do
        if not player:hasItem(gift.id) then
            if exists(gift.id) then
                table.insert(missing, gift)
            else
                table.insert(unknown, gift.name)
            end
        end
    end

    for _, name in ipairs(unknown) do
        say(player, string.format('%s is not on this server yet (it comes with an update).', name))
    end

    if #missing == 0 then
        say(player, 'You already have every Forever gift. (One waiting in your delivery box counts once you take it out.)')
        return
    end

    local free = player:getFreeSlotsCount()
    if free < #missing then
        say(player, string.format('You need %d free inventory slot%s for your Forever gifts; you have %d. Make room and try !betagifts again.',
            #missing, #missing == 1 and '' or 's', free))
        return
    end

    local given = {}
    for _, gift in ipairs(missing) do
        if player:addItem(gift.id) then
            player:setCharVar(gift.marker, 1)
            table.insert(given, gift.name)
        else
            say(player, string.format('%s could not be given (if one is waiting in your delivery box, take it out first).', gift.name))
        end
    end

    if #given > 0 then
        say(player, 'From the XI: Forever Offline team: ' .. table.concat(given, ', ') .. '.')
    end
end

xi.module.registerCommand('betagifts', command)
