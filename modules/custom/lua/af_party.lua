-----------------------------------
-- Artifact armor quests: a party mate's job counts
--
-- The AF quests only start for a player whose own main job is the quest's job. With this module, if one of your summoned
-- party mates (a squad mate) is on that job, the quest starts and carries on for you, as if you were that job.
--   * The job comes from the mate. The level rule (AF1_QUEST_LEVEL and so on) is checked against YOU, unless
--     LEVEL_FROM_MATE is set to true below.
--   * It only ever adds ways to pass a check. A check that passes for you passes exactly as before, and anything that
--     fails for another reason (the quest is already done, not started, ...) still fails.
--   * The quest reward comes to you. Trade it to the mate (!squad) to unlock it for the squad.
-- The list of AF quests is written by install-af-party.ps1 from your own server files (af_quest_list.lua).
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('af_party_job')

local LEVEL_FROM_MATE = false -- false: the quest's level rule is checked against you. true: against the mate.

local listOk, questList = pcall(require, 'modules/custom/lua/af_quest_list')
if not listOk or type(questList) ~= 'table' then
    print('[af_party] af_quest_list.lua not found - run install-af-party.ps1 again')
    questList = {}
end

-- The summoned mates in the player's party (not the player)
local function matesOf(player)
    local mates = {}
    local party = player:getPartyWithTrusts()
    if party == nil then
        return mates
    end

    local selfId = player:getID()
    for _, member in ipairs(party) do
        if member:getID() ~= selfId then
            local ok, isTrust = pcall(function()
                return member:getObjType() == xi.objType.TRUST
            end)

            if not ok or isTrust then
                mates[#mates + 1] = member
            end
        end
    end

    return mates
end

-- Something that looks like the player to a quest check, but answers "main job" (and maybe level) with the mate's
local function standIn(player, mate)
    local overrides =
    {
        getMainJob = function()
            return mate:getMainJob()
        end,

        getSubJob = function()
            return mate:getSubJob()
        end,
    }

    if LEVEL_FROM_MATE then
        overrides.getMainLvl = function()
            return mate:getMainLvl()
        end
    end

    return setmetatable({}, {
        __index = function(_, key)
            if overrides[key] ~= nil then
                return overrides[key]
            end

            local value = player[key]
            if type(value) == 'function' then
                return function(_, ...)
                    return value(player, ...)
                end
            end

            return value
        end,
    })
end

-- The original check first. Only if it fails is it asked again for each mate.
local function wrapCheck(original)
    return function(player, ...)
        local ok, result = pcall(original, player, ...)
        if ok and result then
            return result
        end

        for _, mate in ipairs(matesOf(player)) do
            local mateOk, mateResult = pcall(original, standIn(player, mate), ...)
            if mateOk and mateResult then
                return mateResult
            end
        end

        return ok and result or false
    end
end

m:addOverride('xi.server.onServerStart', function()
    super()

    local wrapped, failed = 0, 0
    for _, path in ipairs(questList) do
        local ok = pcall(function()
            xi.module.modifyInteractionEntry(path, function(quest)
                for _, section in ipairs(quest.sections) do
                    if type(section.check) == 'function' then
                        section.check = wrapCheck(section.check)
                    end
                end
            end)
        end)

        if ok then
            wrapped = wrapped + 1
        else
            failed = failed + 1
        end
    end

    print(string.format('[af_party] a party mate\'s job now counts for %d artifact quests (%d could not be changed)', wrapped, failed))
end)

return m
