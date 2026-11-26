-----------------------------------
-- func: skip <what> [yes] (any player)
-- desc: (2026-11-25, XI: Forever Offline; the user: "commands so that players can skip missions on whatever character
--       they want ... skip all, skip promy ... max rank, fame") skips story missions on the character using it, for
--       players who have done them before and want to get on with it. Every skipped mission is marked done (it shows
--       in the mission log), and the key items those missions hand out are given (the same work as !skipmissions).
--         !skip                 what can be skipped
--         !skip nation yes      your nation's missions, and rank 10
--         !skip rank yes        rank 10 only
--         !skip fame yes        the highest fame in San d'Oria, Bastok, Windurst and Norg (Jeuno follows from them)
--         !skip zilart yes      Rise of the Zilart
--         !skip promy yes       Chains of Promathia up to and including the three Promyvions (next: An Invitation West)
--         !skip cop yes         all of Chains of Promathia
--         !skip toau yes        Treasures of Aht Urhgan
--         !skip wotg yes        Wings of the Goddess
--         !skip all yes         nation + rank + fame + Zilart + Promathia + Aht Urhgan
--       Without "yes" it only says what it would do. Final rewards (rings, gear) are not given.
--       Hardcore characters (Iron, Steel, Silver, Randomized) can't skip: they earn everything themselves
--       (main.lua XIFO_SKIP_HARDCORE = true allows it). A world can turn the command off for everyone
--       (main.lua XIFO_PLAYER_SKIP = false). It is off in The Hub unless its main.lua says XIFO_PLAYER_SKIP = true.
-----------------------------------
---@type TCommand
local commandObj = {}

commandObj.cmdprops =
{
    permission = 0,
    parameters = 'ss'
}

local NONE = 65535
local NATIONS = { [0] = "San d'Oria", [1] = 'Bastok', [2] = 'Windurst' }

local function line(player, text)
    player:printToPlayer(text, xi.msg.channel.SYSTEM_3)
end

local function help(player)
    line(player, 'Skip story missions you have done before (marked done, key items given). Add "yes" to do it:')
    line(player, '  !skip nation | rank | fame | zilart | promy | cop | toau | wotg | all')
    line(player, '  e.g. !skip promy yes    (Promathia up to and including the Promyvions)')
end

local function setting(name, default)
    local v = xi.settings.main[name]
    if v == nil then
        return default
    end

    return v
end

local skipper = nil
local function skipLog(player, logId, missionId)
    if skipper == nil then
        skipper = require('scripts/commands/skipmissions')
    end

    return skipper.skip(player, logId, missionId)
end

local function maxFame(player)
    local top = xi.data.fame.rankPoints[9]
    for _, area in ipairs({ xi.fameArea.SANDORIA, xi.fameArea.BASTOK, xi.fameArea.WINDURST, xi.fameArea.NORG }) do
        if area ~= nil and player:getFame(area) < top then
            player:setFame(area, top)
        end
    end
end

-- what each word does: a short description and the work
local function plan(player)
    local nation = player:getNation()
    local cop = xi.mission.log_id.COP
    return {
        nation = { string.format('%s missions done and rank 10', NATIONS[nation] or 'your nation'),
            function() skipLog(player, nation, NONE); player:setRank(10) end },
        rank   = { 'rank 10', function() player:setRank(10) end },
        fame   = { "the highest fame in San d'Oria, Bastok, Windurst and Norg", function() maxFame(player) end },
        zilart = { 'Rise of the Zilart done', function() skipLog(player, xi.mission.log_id.ZILART, NONE) end },
        promy  = { 'Chains of Promathia up to and including the Promyvions (next: An Invitation West)',
            function() skipLog(player, cop, xi.mission.id.cop.AN_INVITATION_WEST) end },
        cop    = { 'Chains of Promathia done', function() skipLog(player, cop, NONE) end },
        toau   = { 'Treasures of Aht Urhgan done', function() skipLog(player, xi.mission.log_id.TOAU, NONE) end },
        wotg   = { 'Wings of the Goddess done', function() skipLog(player, xi.mission.log_id.WOTG, NONE) end },
    }
end

local ALL = { 'nation', 'fame', 'zilart', 'cop', 'toau' }

commandObj.onTrigger = function(player, what, yes)
    -- on by default, but off in The Hub (the shared, official world: xi.hardcore.isHub) unless main.lua says true
    local onByDefault = not (xi.hardcore and xi.hardcore.isHub)
    if setting('XIFO_PLAYER_SKIP', onByDefault) == false then
        line(player, 'Skipping missions is turned off in this world.')
        return
    end

    if what == nil or what == '' then
        help(player)
        return
    end

    what = string.lower(what)
    local mode = player:getCharVar('[HC]Mode')
    if mode > 0 and not setting('XIFO_SKIP_HARDCORE', false) then
        line(player, 'Hardcore characters earn their story themselves: skipping is for regular characters.')
        return
    end

    local steps = plan(player)
    local todo = {}
    if what == 'all' then
        for _, k in ipairs(ALL) do
            todo[#todo + 1] = k
        end
    elseif steps[what] then
        todo[1] = what
    else
        line(player, string.format('Nothing called "%s" to skip.', what))
        help(player)
        return
    end

    if string.lower(yes or '') ~= 'yes' then
        line(player, string.format('!skip %s would give %s:', what, player:getName()))
        for _, k in ipairs(todo) do
            line(player, '  - ' .. steps[k][1])
        end

        line(player, string.format('It can\'t be undone. Type !skip %s yes to do it.', what))
        return
    end

    for _, k in ipairs(todo) do
        local ok, err = pcall(steps[k][2])
        if ok then
            line(player, 'Done: ' .. steps[k][1] .. '.')
        else
            line(player, string.format('Could not skip %s (%s).', k, tostring(err)))
        end
    end

    line(player, 'Zone (or log out and in) once so the mission log and key items show.')
end

return commandObj
