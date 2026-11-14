-----------------------------------
-- !rse : choose which race's gear "The Goblin Tailor" quest gives you
--
--   !rse               shows your choice, today's race and where the chest is
--   !rse <race>        humem humef elvaanm elvaanf tarum taruf mithra galka   (or: own = your own race)
--   !rse day           chests give the Magical Pattern on any day, in any of the three zones (press again to switch it off)
--
-- The quest itself (scripts/quests/Jeuno/The_Goblin_Tailor.lua) reads these choices. Each race keeps its own record of
-- which of the four pieces you already have.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('rse_choice')

local RACES =
{
    humem   = 1, humef   = 2,
    elvaanm = 3, elvaanf = 4,
    tarum   = 5, taruf   = 6,
    mithra  = 7, galka   = 8,
}

local RACE_NAMES =
{
    [1] = 'Hume (male)',   [2] = 'Hume (female)',
    [3] = 'Elvaan (male)', [4] = 'Elvaan (female)',
    [5] = 'Tarutaru (male)', [6] = 'Tarutaru (female)',
    [7] = 'Mithra', [8] = 'Galka',
}

local LOCATIONS = { [0] = "Ordelle's Caves", [1] = 'Gusgen Mines', [2] = 'Maze of Shakhrami' }

local PIECES = { 'body', 'hands', 'legs', 'feet' }

local function say(player, text)
    player:printToPlayer(text)
end

local function chosenRace(player)
    local chosen = player:getCharVar('[RSE]ChosenRace')
    if chosen >= 1 and chosen <= 8 then
        return chosen
    end

    return player:getRace()
end

local function gearVar(player)
    if chosenRace(player) == player:getRace() then
        return '[RSE]Gear'
    end

    return '[RSE]Gear' .. chosenRace(player)
end

local function status(player)
    local race    = chosenRace(player)
    local tracker = player:getCharVar(gearVar(player))

    local have, missing = {}, {}
    for index, piece in ipairs(PIECES) do
        if bit.band(tracker, bit.lshift(1, index - 1)) ~= 0 then
            have[#have + 1] = piece
        else
            missing[#missing + 1] = piece
        end
    end

    say(player, string.format('Goblin Tailor gear: %s%s.', RACE_NAMES[race], race == player:getRace() and ' (your own race)' or ''))
    say(player, string.format('Pieces you have: %s.   Still to get: %s.', #have > 0 and table.concat(have, ', ') or 'none', #missing > 0 and table.concat(missing, ', ') or 'none'))

    if player:getCharVar('[RSE]AnyDay') == 1 then
        say(player, 'Schedule: ignored. The chests in Ordelle\'s Caves, Gusgen Mines and the Maze of Shakhrami all work, any day.')
    else
        say(player, string.format('Today the gear is for %s, from the chest in %s.', RACE_NAMES[VanadielRSERace()] or 'unknown', LOCATIONS[VanadielRSELocation()] or 'unknown'))
    end
end

local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = 's',
}

commandObj.onTrigger = function(player, arg)
    arg = arg and string.lower(arg) or nil

    if arg == nil then
        status(player)
        say(player, 'Choose a race: !rse humem humef elvaanm elvaanf tarum taruf mithra galka   (own = your race)   |   !rse day')
        return
    end

    if arg == 'day' then
        local now = player:getCharVar('[RSE]AnyDay') == 1 and 0 or 1
        player:setCharVar('[RSE]AnyDay', now)
        say(player, now == 1 and 'The daily schedule is ignored now: any chest works any day.' or 'The daily schedule is back on.')
        return
    end

    if arg == 'own' then
        player:setCharVar('[RSE]ChosenRace', 0)
        status(player)
        return
    end

    local race = RACES[arg]
    if race == nil then
        say(player, 'I do not know that race. Use: humem humef elvaanm elvaanf tarum taruf mithra galka (or own, or day).')
        return
    end

    player:setCharVar('[RSE]ChosenRace', race)
    status(player)
end

xi.module.registerCommand('rse', commandObj)

return m
