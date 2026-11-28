-----------------------------------
-- XI: Forever Offline (2026-11-27, the user: a Randomized player with two jobs could not make them trade places)
-- !dropsub takes a Randomized character's support job off for a while.
--
-- A Randomized character only has the jobs fate gave it. With two of them, one is the main job and the other the
-- support job. The player who reported it could not make the two trade places at the Moogle, and there is no third
-- job to park the support job on. !dropsub clears the support job. The other job can then be picked as the main job,
-- and the first one as the support job, both at the Moogle as usual.
--   * Randomized characters only: everyone else has the six starting jobs to move a support job through.
--   * Only where jobs are changed: in your own Mog House, or in an area with a Nomad Moogle.
--   * Only with a support job set. (The game's call below also marks the support job as unlocked; with one set it
--     is unlocked already, so nothing is given away.)
--   * Nothing is lost: the job, its level and the right to a support job stay. Only "which job is the support job" is
--     cleared, until you pick one again. A second weapon that was held through the support job's Dual Wield comes off.
--   * One thing does go, for a Blue Mage as the MAIN job: the game's call below takes its set blue magic off and saves
--     that, so it has to be set again later. Such a character is told first and has to type "!dropsub yes".
--     (Blue Mage as the support job is fine: its set comes back when the job is picked again.)
-- A command and nothing else, so there is no Module:new here: a module that declares no overrides is an error line
-- in the map log at every start.
-----------------------------------
require('modules/module_utils')

local function say(player, text)
    player:printToPlayer(text, xi.msg.channel.SYSTEM_3)
end

local function jobName(job)
    local entry = xi.jobName and xi.jobName[job]
    if type(entry) == 'table' and entry[2] then
        return entry[2]
    end

    for name, id in pairs(xi.job or {}) do
        if id == job then
            return name
        end
    end

    return 'job ' .. tostring(job)
end

local command = {}
command.cmdprops = { permission = 0, parameters = 's' } -- every player, on their own character

command.onTrigger = function(player, answer)
    local hardcore = xi.hardcore
    if not (hardcore and type(hardcore.mode) == 'function' and hardcore.mode(player) == hardcore.RANDOM) then
        say(player, '!dropsub is for Randomized characters. At your Moogle, set another support job first, then change your main job.')
        return
    end

    local sub = player:getSubJob()
    if sub == nil or sub == 0 then
        say(player, 'You have no support job set. At your Moogle, change your main job, then pick your support job.')
        return
    end

    if not (player:inMogHouse(xi.mogHouse.OWN) or player:canUseMisc(xi.zoneMisc.MOGMENU)) then
        say(player, 'Use !dropsub where you change jobs: in your own Mog House or next to a Nomad Moogle.')
        return
    end

    if player:getMainJob() == xi.job.BLU and string.lower(tostring(answer or '')) ~= 'yes' then
        say(player, 'You are a Blue Mage: taking the support job off this way also takes off the blue magic you have set, and you set it again afterwards. Type !dropsub yes to go on.')
        return
    end

    if player:hasPet() then
        player:despawnPet() -- a pet the support job brought (the GM's !changesjob sends it away too)
    end

    player:changesJob(xi.job.NONE)

    -- The game checks the gear before it rebuilds the traits, so a second weapon held through the support job's
    -- Dual Wield would stay on. Shields and grips stay.
    local off = player:getEquippedItem(xi.slot.SUB)
    if
        off ~= nil and
        not off:isShield() and
        off:getSkillType() ~= xi.skill.NONE and
        not player:hasTrait(xi.trait.DUAL_WIELD)
    then
        player:unequipItem(xi.slot.SUB)
    end

    say(player, string.format('Your support job (%s) is off. At the Moogle, change your main job now, then pick your support job again.', jobName(sub)))
end

xi.module.registerCommand('dropsub', command)
