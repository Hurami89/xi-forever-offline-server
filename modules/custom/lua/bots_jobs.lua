-----------------------------------
-- FFXI Offline: bot players - subjobs and more jobs. Used by bots.lua (through bots_quests.lua trips).
--
-- Like players of the era:
--   level 18: the subjob quest (a trip, like the other quests) -> its subjob is unlocked.
--   it picks a subjob that fits its main job (WAR/THF, WHM/BLM, RDM/WHM, PLD/WAR ...), changes to that job and
--     levels it to half its main level (real fights), then changes back with the subjob set.
--   level 30+: now and then the quest for an advanced job (PLD, DRK, BST, BRD, RNG, SAM, NIN, DRG, SMN, BLU, COR,
--     PUP) -> that job is unlocked; an adventurous bot (hunter / all-rounder) may make it its new main job.
-- The job changes are the server's own (changeJob / changesJob / unlockJob); levels come only from real exp.
-- Char vars: [Bot]Main (its real main job while it levels a subjob), [Bot]Sub (the subjob it wants).
-----------------------------------
local J = {}

local JOB = { WAR = 1, MNK = 2, WHM = 3, BLM = 4, RDM = 5, THF = 6, PLD = 7, DRK = 8, BST = 9, BRD = 10, RNG = 11,
              SAM = 12, NIN = 13, DRG = 14, SMN = 15, BLU = 16, COR = 17, PUP = 18 }
local NAMES = {}
for k, v in pairs(JOB) do
    NAMES[v] = k
end

local SUB_FOR = {
    WAR = { 'MNK', 'THF', 'NIN' }, MNK = { 'WAR', 'THF', 'NIN' }, WHM = { 'BLM', 'RDM' }, BLM = { 'WHM', 'RDM' },
    RDM = { 'WHM', 'BLM', 'NIN' }, THF = { 'WAR', 'NIN' }, PLD = { 'WAR', 'WHM', 'NIN' }, DRK = { 'WAR', 'THF', 'SAM' },
    BST = { 'WHM', 'NIN' }, BRD = { 'WHM', 'NIN' }, RNG = { 'WAR', 'NIN', 'SAM' }, SAM = { 'WAR', 'THF', 'NIN' },
    NIN = { 'WAR', 'THF' }, DRG = { 'WAR', 'WHM', 'SAM' }, SMN = { 'WHM', 'RDM' }, BLU = { 'WAR', 'NIN', 'RDM' },
    COR = { 'NIN', 'RNG', 'WAR' }, PUP = { 'WAR', 'WHM', 'THF' },
}
local ADVANCED = { 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP' }
local TOAU = { BLU = true, COR = true, PUP = true }

local function pick(list)
    return list[math.random(1, #list)]
end

local function hasJob(bot, job)
    if job <= 6 then
        return true -- the six starting jobs
    end

    local ok, has = pcall(function()
        return bot:hasJob(job)
    end)
    return ok and has
end

local function subUnlocked(bot)
    return bot:getCharVar('[Bot]SubOK') == 1
end

-- its real main job (while it levels a subjob it plays that one)
function J.realMain(bot)
    local m = bot:getCharVar('[Bot]Main')
    return m ~= 0 and m or bot:getMainJob()
end

local function wantedSub(bot)
    local sub = bot:getCharVar('[Bot]Sub')
    if sub ~= 0 then
        return sub
    end

    local options = {}
    for _, name in ipairs(SUB_FOR[NAMES[J.realMain(bot)]] or { 'WAR' }) do
        if hasJob(bot, JOB[name]) and JOB[name] ~= J.realMain(bot) then
            options[#options + 1] = JOB[name]
        end
    end

    if #options == 0 then
        return 0
    end

    sub = pick(options)
    bot:setCharVar('[Bot]Sub', sub)
    return sub
end

-- never the same job as main and sub (the game does not allow WHM/WHM): after a main job change the old subjob may be
-- the new main. Then the sub becomes `instead` (its real main while it levels a subjob), or another fitting one, or none.
local function keepSubApart(bot, instead)
    local ok, main, sub = pcall(function()
        return bot:getMainJob(), bot:getSubJob()
    end)
    if not ok or main ~= sub or main == 0 then
        return false
    end

    local new = instead or 0
    if new == 0 or new == main then
        new = 0
        for _, name in ipairs(SUB_FOR[NAMES[main]] or {}) do
            if new == 0 and JOB[name] ~= main and hasJob(bot, JOB[name]) and bot:getJobLevel(JOB[name]) > 0 then
                new = JOB[name]
            end
        end
    end

    pcall(function()
        bot:changesJob(new)
    end)
    return true
end

-- at log in: a bot left as WHM/WHM (by an older version) gets a proper subjob
function J.fixSub(bot)
    local levelling = bot:getCharVar('[Bot]Main')
    return keepSubApart(bot, levelling ~= 0 and levelling or nil)
end

-- what it could do about its jobs right now: 'limitbreak', 'subquest', 'levelsub', 'backtomain', 'jobquest' or nil
function J.next(bot)
    local main = J.realMain(bot)
    local mainLvl = bot:getJobLevel(main)
    if bot:getCharVar('[Bot]Main') ~= 0 then
        -- levelling its subjob: back to its main job at half its level
        if bot:getMainLvl() >= math.floor(mainLvl / 2) then
            return 'backtomain'
        end

        return nil -- (it keeps hunting on the subjob)
    end

    -- at its level cap (50, 55 ... 70): the limit break quest, as players do
    local okCap, cap = pcall(function()
        return bot:getLevelCap()
    end)
    if okCap and cap and cap < 75 and bot:getMainLvl() >= cap and bot:getMainJob() == main then
        return 'limitbreak'
    end

    if mainLvl >= 18 and not subUnlocked(bot) then
        return 'subquest'
    end

    if subUnlocked(bot) then
        local sub = wantedSub(bot)
        if sub ~= 0 and bot:getJobLevel(sub) < math.floor(mainLvl / 2) - 2 then
            return 'levelsub'
        end
    end

    if mainLvl >= 30 then
        local locked = 0
        for _, name in ipairs(ADVANCED) do
            if not hasJob(bot, JOB[name]) then
                locked = locked + 1
            end
        end

        if locked > 0 and bot:getCharVar('[Bot]JobQuestAt') + 6 * 3600 < os.time() then
            return 'jobquest'
        end
    end

    return nil
end

local function say(bot, list)
    if math.random() < 0.6 then
        BotChat(bot:getID(), 0, pick(list))
    end
end

-- after the subjob quest trip
function J.unlockSub(bot)
    pcall(function()
        bot:unlockJob(0) -- (job 0 = the subjob flag)
    end)
    bot:setCharVar('[Bot]SubOK', 1)
    local sub = wantedSub(bot)
    if sub ~= 0 and bot:getJobLevel(sub) > 0 then
        pcall(function()
            bot:changesJob(sub)
        end)
    end

    print(string.format('[bots] %s unlocked its subjob', bot:getName()))
    say(bot, { 'finally got my subjob!', 'subjob unlocked :)', 'time to level a sub' })
end

-- after an advanced job quest trip: which job (or nil)
function J.unlockAdvanced(bot, style)
    local options = {}
    for _, name in ipairs(ADVANCED) do
        if not hasJob(bot, JOB[name]) and (not TOAU[name] or bot:getJobLevel(J.realMain(bot)) >= 30) then
            options[#options + 1] = name
        end
    end

    bot:setCharVar('[Bot]JobQuestAt', os.time())
    if #options == 0 then
        return nil
    end

    local name = pick(options)
    pcall(function()
        bot:unlockJob(JOB[name])
    end)
    print(string.format('[bots] %s unlocked %s', bot:getName(), name))
    say(bot, { 'got ' .. name .. '!', name .. ' unlocked, so happy', 'finally ' .. name })
    -- an adventurous bot starts over on its new job (the old one stays, it can come back to it)
    if (style == 'hunter' or style == 'allround') and math.random() < 0.35 then
        pcall(function()
            bot:changeJob(JOB[name])
        end)
        keepSubApart(bot) -- (its subjob may have been that job)
        print(string.format('[bots] %s changes its main job to %s', bot:getName(), name))
    end

    return name
end

-- changes to the subjob it wants to level (in town, before going hunting)
function J.startLevelling(bot)
    local sub = wantedSub(bot)
    if sub == 0 then
        return false
    end

    local main = bot:getMainJob()
    bot:setCharVar('[Bot]Main', main)
    pcall(function()
        bot:changeJob(sub)
    end)
    keepSubApart(bot, main) -- (levelling WHM as a RDM: WHM/RDM, never WHM/WHM)
    print(string.format('[bots] %s levels its subjob %s', bot:getName(), NAMES[sub] or '?'))
    say(bot, { 'leveling my ' .. (NAMES[sub] or 'sub') .. ' sub, wish me luck', 'sub job grind time' })
    return true
end

function J.backToMain(bot)
    local main = bot:getCharVar('[Bot]Main')
    local sub = bot:getMainJob()
    if main == 0 then
        return
    end

    pcall(function()
        bot:changeJob(main)
        bot:changesJob(sub)
    end)
    bot:setCharVar('[Bot]Main', 0)
    print(string.format('[bots] %s is back on %s with %s as subjob', bot:getName(), NAMES[main] or '?', NAMES[sub] or '?'))
    say(bot, { 'sub is done, back to my main', NAMES[main] .. '/' .. NAMES[sub] .. ' finally' })
end

-- after a limit break quest: 5 more levels
function J.limitBreak(bot)
    local ok, cap = pcall(function()
        return bot:getLevelCap()
    end)
    if not ok or not cap or cap >= 75 then
        return nil
    end

    pcall(function()
        bot:setLevelCap(math.min(75, cap + 5))
    end)
    print(string.format('[bots] %s passed a limit break: level cap %d', bot:getName(), math.min(75, cap + 5)))
    say(bot, { 'limit break done, cap is ' .. math.min(75, cap + 5) .. ' now!', 'finally beat maat... j/k, but cap up :)', 'genkai done!' })
    return math.min(75, cap + 5)
end

-- the one-time head start (bots_growth.lua): what a player of this level had done about jobs, quietly (no chat).
-- From 18 its subjob, at about half its level; from 30 one or two advanced jobs unlocked (more from 50).
function J.headStart(bot, level)
    local out = {}
    if level >= 18 and not subUnlocked(bot) then
        pcall(function()
            bot:unlockJob(0)
        end)
        bot:setCharVar('[Bot]SubOK', 1)
        local sub = wantedSub(bot)
        if sub ~= 0 then
            local ok = pcall(function()
                bot:changesJob(sub)
                bot:setsLevel(math.max(1, math.floor(level / 2) - math.random(0, 2)))
            end)
            if ok then
                out[#out + 1] = '/' .. (NAMES[sub] or '?')
            end
        end
    end

    if level >= 30 then
        local n = level >= 50 and math.random(1, 4) or math.random(0, 2)
        for _ = 1, n do
            local options = {}
            for _, name in ipairs(ADVANCED) do
                if not hasJob(bot, JOB[name]) then
                    options[#options + 1] = name
                end
            end

            if #options == 0 then
                break
            end

            local name = pick(options)
            pcall(function()
                bot:unlockJob(JOB[name])
            end)
            out[#out + 1] = name .. ' unlocked'
        end

        bot:setCharVar('[Bot]JobQuestAt', os.time())
    end

    return table.concat(out, ', ')
end

function J.jobName(id)
    return NAMES[id] or '?'
end

return J
