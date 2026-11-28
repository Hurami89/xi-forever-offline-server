-----------------------------------
-- XI: Forever Offline: the beta testers' Forever gifts (2026-11-27)
-- The gifts: the Forever Beta Shirt (25725), the Forever Patch (23867), the Forever Track Pants (23868) and the Forever
-- Gloves (23869). Each one's own file (custom/lua/forever_*.lua) still gives it once: in the bags of a new character,
-- in the delivery box of one that already exists. This file adds two things:
--
-- 1. !betagifts (the user: "a command like betagifts ... so players can spawn these any time, even non-GM, like a
--    starting gear command") gives back the gifts a character does not have.
--   * Every player, any time, on their own character. Free.
--   * Only what is missing: they are Rare (one each), so one the character already has anywhere (bags, Mog Safe,
--     wardrobes, worn) is skipped. One still waiting in the delivery box is NOT seen by the game's check, so the
--     reply says to take those out first; giving a second one there would be refused by the Rare rule anyway.
--   * Into the inventory only, one free slot each; with no room it says how many slots to free.
--   * A gift whose item is not on this server (its SQL file not loaded) is skipped with a line.
--   * Each gift's own "given once" marker is set too, so its log in gift does not send another one later.
--
-- 2. The squad has them from the start (the user: "by default can these be unlocked by all squad mates"). At every log
--    in, and after !betagifts, any of the four the character's squad collection lacks is added to it, the same
--    collection a trade to a mate fills (squad.lua xi.squad.onTrade: UnlockSquadItem). Every mate can then wear them;
--    nothing is taken from the player. Not for Iron, Steel and Silver characters: in those modes squad gear is only
--    what was traded (the user's hardcore rule), so a hardcore player trades a gift to a mate as before (it is
--    one-of-a-kind, so they keep theirs). Randomized squads get them. Bot players never.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('betagifts')

local GIFTS =
{
    { id = 25725, name = 'Forever Beta Shirt',  marker = '[FBShirt]Given' },
    { id = 23867, name = 'Forever Patch',       marker = '[FPatch]Given'  },
    { id = 23868, name = 'Forever Track Pants', marker = '[FJeans]Given'  },
    { id = 23869, name = 'Forever Gloves',      marker = '[FGloves]Given' },
}
local TOLD = '[FGifts]SquadTold' -- the one-time line about the squad having them

local function say(player, text)
    player:printToPlayer(text, xi.msg.channel.SYSTEM_3)
end

local function exists(id)
    return GetItemByID == nil or GetItemByID(id) ~= nil
end

local function isBot(player)
    if player:getCharVar('[Bot]Started') ~= 0 then
        return true
    end

    return BotIsBot ~= nil and BotIsBot(player:getID()) and true or false
end

local function tradedGearOnly(player)
    local H = xi.hardcore
    if not (H and type(H.mode) == 'function') then
        return false
    end

    local mode = H.mode(player)
    return mode == H.IRON or mode == H.STEEL or mode == H.SILVER
end

-- adds the gifts the squad collection lacks; returns how many were added (nil when the squad functions are missing)
local function unlockForSquad(player)
    if UnlockSquadItem == nil or GetSquadUnlocks == nil or isBot(player) or tradedGearOnly(player) then
        return nil
    end

    local ok, unlocked = pcall(GetSquadUnlocks, player:getID())
    if not ok or type(unlocked) ~= 'table' then
        return nil
    end

    local added = 0
    for _, gift in ipairs(GIFTS) do
        if not unlocked[gift.id] and exists(gift.id) then
            if pcall(UnlockSquadItem, player:getID(), gift.id) then
                added = added + 1
            end
        end
    end

    return added
end

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    local result = super(player, firstLogin, zoning)
    if zoning then
        return result
    end

    local added = unlockForSquad(player)
    if added and added > 0 and player:getCharVar(TOLD) == 0 then
        player:setCharVar(TOLD, 1)
        say(player, 'Your squad can wear the Forever gifts too: every mate has them in the squad collection. (!betagifts gives you back any you are missing.)')
    end

    return result
end)

local command = {}
command.cmdprops = { permission = 0, parameters = '' } -- every player, on their own character

command.onTrigger = function(player)
    unlockForSquad(player)

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

return m
