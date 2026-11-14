-----------------------------------
-- FFXI Offline: bot players - growing while they are away. Used by bots.lua.
--
-- Each bot remembers when it was last on ([Bot]LastSeen) and how much it plays a day ([Bot]Hours: casual 3-6,
-- regular 6-9, hardcore 9-12). At its next log in it catches up on the time it "played" meanwhile (at most
-- MAX_DAYS days), spent the way its personality likes (bots_craft.lua plan weights + its goal):
--   hunting  -> experience through the server's own exp gain (real level ups; a subjob being levelled gets its share)
--   crafting -> craft skill at an era pace, rank ups at the caps; materials cost gil
--   gathering / fishing / market -> gil and a little fishing skill
--   quests   -> its next quests / nation missions, done with their real rewards (rank ups included)
--   jobs     -> the subjob quest at 18, now and then an advanced job from 30
-- Paces (launcher "Bots grow while you are away", or !bots growth): off / realistic / fast (x3).
-- Now and then a bot stops playing for good and a new one joins the roster (bots_life.lua).
-----------------------------------
local G = {}

local MAX_DAYS = 7
local MIN_AWAY = 3600                 -- seconds: shorter breaks are not counted
local PACE = { off = 0, realistic = 1, fast = 3 }
local HOURS = { { 3, 6, 35 }, { 6, 9, 45 }, { 9, 12, 20 } } -- { from, to, weight }: casual, regular, hardcore
local HOURS_VERSION = 2 -- ([Bot]HoursV: a bot with an older pick picks again)

local craft, quests, jobs, gear
local news = {}                       -- recent events for !bots news: { t, text }
local pace = 'realistic'

function G.setup(craftModule, questsModule, jobsModule, cfg, gearModule)
    craft, quests, jobs, gear = craftModule, questsModule, jobsModule, gearModule
    if cfg and PACE[cfg.growth or ''] then
        pace = cfg.growth
    end
end

function G.setPace(p)
    if PACE[p] then
        pace = p
        return true
    end

    return false
end

function G.pace()
    return pace
end

local function now()
    return os.time()
end

local function rnd(a, b)
    return math.random(a, b)
end

local quiet = false                   -- (during a head start: its history is not news)

local function addNews(text)
    if quiet then
        return
    end

    table.insert(news, 1, { t = now(), text = text })
    if #news > 40 then
        table.remove(news)
    end

    print('[bots] ' .. text)
end

-- something worth telling the server (other modules: a linkshell founded, a battlefield cleared)
function G.addNews(text)
    addNews(text)
end

function G.news(n)
    local out = {}
    for i = 1, math.min(n or 10, #news) do
        out[#out + 1] = news[i].text
    end

    return out
end

-- how many hours a day it plays (chosen once)
local function hoursPerDay(bot)
    local h = bot:getCharVar('[Bot]Hours')
    if bot:getCharVar('[Bot]HoursV') ~= HOURS_VERSION then
        h = 0 -- (picked from the old, shorter days)
    end

    if h == 0 then
        local total = 0
        for _, k in ipairs(HOURS) do
            total = total + k[3]
        end

        local roll = math.random() * total
        for _, k in ipairs(HOURS) do
            roll = roll - k[3]
            if roll <= 0 then
                h = rnd(k[1], k[2])
                break
            end
        end

        h = math.max(1, h)
        bot:setCharVar('[Bot]Hours', h)
        bot:setCharVar('[Bot]HoursV', HOURS_VERSION)
    end

    return h
end

-- era-ish exp per hour of hunting at a level (solo early, parties later)
local function expPerHour(lvl)
    if lvl < 10 then
        return 900
    elseif lvl < 20 then
        return 1800
    elseif lvl < 30 then
        return 3000
    elseif lvl < 50 then
        return 4500
    end

    return 6000
end

local function giveExp(bot, amount)
    local lvl0 = bot:getMainLvl()
    local left = math.floor(amount)
    while left > 0 and bot:getMainLvl() < 75 do
        local chunk = math.min(left, 2000)
        local ok = pcall(function()
            bot:addExp(chunk)
        end)
        if not ok then
            break
        end

        left = left - chunk
    end

    return bot:getMainLvl() - lvl0
end

-- while you play: it is "on", so its clock moves on (called from its brain now and then)
function G.seen(bot)
    bot:setCharVar('[Bot]LastSeen', now())
end

local spend -- (below)

-- at log in: the time away, played out
function G.catchUp(bot)
    local last = bot:getCharVar('[Bot]LastSeen')
    G.seen(bot)
    local mult = PACE[pace] or 0
    if last == 0 or mult == 0 then
        return
    end

    local away = now() - last
    if away < MIN_AWAY then
        return
    end

    local days = math.min(MAX_DAYS, away / 86400)
    local hours = days * hoursPerDay(bot) * mult
    if hours < 0.25 then
        return
    end

    spend(bot, hours, days, nil)
end

-- hours of play spent the way its personality likes. opts.headStart: no experience (the level is set), no job
-- changes and no shopping here (done once afterwards), fewer seals
spend = function(bot, hours, days, opts)
    opts = opts or {}
    local weights = craft and craft.planWeights(bot) or { hunt = 1 }
    local total = 0
    for _, w in pairs(weights) do
        total = total + w
    end

    local function share(k)
        return hours * (weights[k] or 0) / math.max(1, total)
    end

    local name = bot:getName()
    local parts = {}

    -- hunting: experience (a subjob being levelled gets its main share)
    local huntH = share('hunt')
    if huntH > 0 then
        local lvl0 = bot:getMainLvl()
        local exp = huntH * expPerHour(lvl0) * (0.8 + math.random() * 0.4)
        local ups = opts.headStart and 0 or giveExp(bot, exp)
        if ups > 0 then
            parts[#parts + 1] = string.format('%d level%s (now %d)', ups, ups > 1 and 's' or '', bot:getMainLvl())
            addNews(string.format('%s reached level %d while you were away', name, bot:getMainLvl()))
        end

        -- the seals those kills dropped (kept for orbs, bots_bcnm.lua): about one Beastmen's Seal an hour, Kindred's
        -- Seals too from level 50 (the server's own rule: monsters of 50+ drop them)
        local seals = math.floor(huntH + 0.5)
        local kindred = lvl0 >= 50 and math.floor(huntH * 0.4 + 0.5) or 0
        if opts.headStart then
            seals, kindred = math.min(seals, rnd(0, 12)), math.min(kindred, rnd(0, 6)) -- (most were spent or sold long ago)
        end
        for id, n in pairs({ [1126] = seals, [1127] = kindred }) do
            local okFree, freeSlots = pcall(function()
                return bot:getFreeSlotsCount()
            end)
            while n > 0 and okFree and (freeSlots or 0) > 0 do
                local chunk = math.min(n, 99)
                pcall(function()
                    bot:addItem(id, chunk)
                end)
                n = n - chunk
                freeSlots = freeSlots - 1
            end
        end

        if seals + kindred > 0 then
            parts[#parts + 1] = (seals + kindred) .. ' seal' .. (seals + kindred > 1 and 's' or '')
        end
    end

    -- crafting: an era pace (slower the higher it gets), materials cost gil
    local craftH = share('craft')
    if craftH > 0 and craft then
        local c, lvl, skill, craftName = craft.craftOf(bot)
        local gain = craftH * 10 / (1 + lvl / 15) -- tenths of a skill level
        local cost = math.floor(craftH * 150 * (1 + lvl / 10))
        if bot:getGil() > cost + 500 then
            bot:delGil(cost)
            local ok, real = pcall(function()
                return bot:getCharSkillLevel(skill)
            end)
            real = (ok and real) or 0
            local rank = 0
            pcall(function()
                rank = bot:getSkillRank(skill)
            end)
            local cap = (rank + 1) * 100
            local newReal = math.min(cap, real + math.floor(gain))
            for _ = 1, 3 do
                pcall(function()
                    bot:setSkillLevel(skill, newReal)
                end)
                if newReal >= cap and craft.rankUp(bot, c) then
                    rank = rank + 1
                    cap = (rank + 1) * 100
                    newReal = math.min(cap, newReal + math.floor(gain / 3))
                else
                    break
                end
            end

            local newLvl = math.floor(newReal / 10)
            if newLvl > lvl then
                parts[#parts + 1] = string.format('%s %d', craftName, newLvl)
                if math.floor(newLvl / 10) > math.floor(lvl / 10) then
                    addNews(string.format('%s reached %s %d', name, craftName, newLvl))
                end
            end
        end
    end

    -- gathering, fishing, the market: gil (and a bit of fishing skill)
    local gilH = share('gather') + share('market') + share('fish')
    if gilH > 0 then
        local gil = math.floor(gilH * (250 + bot:getMainLvl() * 25) * (0.7 + math.random() * 0.6))
        bot:addGil(gil)
        parts[#parts + 1] = gil .. ' gil'
    end

    local fishH = share('fish')
    if fishH > 0 then
        pcall(function()
            local real = bot:getCharSkillLevel(48)
            if real < 1000 then
                bot:setSkillLevel(48, math.min(1000, real + math.floor(fishH * 6 / (1 + real / 300))))
            end
        end)
    end

    -- quests and missions: about one per 1.5 hours given to them, at most 6 per catch-up
    local questH = share('quest')
    if questH > 0 and quests then
        local n = math.min(6, math.floor(questH / 1.5 + math.random()))
        local done = 0
        local rank0 = 1
        pcall(function()
            rank0 = bot:getRank(bot:getNation())
        end)
        local wantRank = craft and craft.goalName(bot) == 'rank'
        for _ = 1, n do
            if quests.completeNow(bot, wantRank) then
                done = done + 1
            end
        end

        if done > 0 then
            parts[#parts + 1] = done .. ' quest' .. (done > 1 and 's' or '')
        end

        local rank1 = rank0
        pcall(function()
            rank1 = bot:getRank(bot:getNation())
        end)
        if rank1 > rank0 then
            addNews(string.format('%s reached nation rank %d', name, rank1))
        end
    end

    -- jobs: the subjob quest, now and then an advanced job
    if jobs and not opts.headStart then
        local plan = jobs.next(bot)
        if plan == 'limitbreak' and math.random() < math.min(1, days * 0.3) then
            local cap = jobs.limitBreak(bot)
            if cap then
                addNews(string.format('%s passed a limit break (cap %d)', name, cap))
            end
        elseif plan == 'subquest' and math.random() < math.min(1, days * 0.6) then
            jobs.unlockSub(bot)
            addNews(name .. ' unlocked a subjob')
        elseif plan == 'jobquest' and math.random() < math.min(0.6, days * 0.1) then
            local style = craft and craft.styleName(bot) or 'allround'
            local job = jobs.unlockAdvanced(bot, style)
            if job then
                addNews(string.format('%s unlocked %s', name, job))
            end
        elseif plan == 'backtomain' then
            jobs.backToMain(bot)
        end
    end

    if opts.headStart then
        return parts
    end

    -- gear: the upgrades it bought with that gil (bots_gear.lua)
    if gear and (#parts > 0) then
        local ok, n = pcall(gear.catchUp, bot)
        if ok and n and n > 0 then
            parts[#parts + 1] = n .. ' new piece' .. (n > 1 and 's' or '') .. ' of gear'
        end
    end

    if #parts > 0 then
        print(string.format('[bots] %s caught up %.1f hours of play: %s', name, hours, table.concat(parts, ', ')))
        bot:setCharVar('[Bot]Grew', 1) -- (it may mention it when it says hello)
    end

    return parts
end

-----------------------------------
-- The one-time head start (asked for on 2026-11-07): the roster as it was then is given the history of a server that
-- has been running for a few months. Each bot gets a level from the spread below (most 10-30, some 40s and 50s, a
-- handful 60+), the level cap a player of that level has passed, combat and magic skills near the cap for its level,
-- its subjob at half its level from 18, a couple of advanced jobs from 30, and the crafting, gil, quests and missions,
-- seals and gear of the hours that took. It happens once per bot, at its next log in. Bots that join later start at 1.
-- Server var [Bots]HeadStart = the highest bot id it covers (set the first time); char var [Bot]HeadStart = 1 when done.
-----------------------------------
local HEAD_START = {      -- { from level, to level, share in % }
    { 1, 9, 18 }, { 10, 19, 28 }, { 20, 29, 22 }, { 30, 39, 13 }, { 40, 49, 9 }, { 50, 59, 6 }, { 60, 69, 3 }, { 70, 75, 1 },
}
local HEAD_START_MAX_HOURS = 400

local function headStartLevel()
    local total = 0
    for _, b in ipairs(HEAD_START) do
        total = total + b[3]
    end

    local roll = math.random() * total
    for _, b in ipairs(HEAD_START) do
        roll = roll - b[3]
        if roll <= 0 then
            return rnd(b[1], b[2])
        end
    end

    return rnd(10, 19)
end

-- roughly what a level took (era exp tables, a fair hunting pace): hours of hunting from 1 to that level
local function huntHoursTo(level)
    local h = 0
    for l = 1, level - 1 do
        local tnl
        if l < 50 then
            tnl = 500 + 200 * l
        elseif l < 60 then
            tnl = 12000 + 1000 * (l - 50)
        else
            tnl = 22000 + 1500 * (l - 60)
        end

        h = h + tnl / expPerHour(l)
    end

    return h
end

local function headStartLimit()
    local limit = GetServerVariable('[Bots]HeadStart')
    if limit == 0 and BotList then
        for id in pairs(BotList() or {}) do
            limit = math.max(limit, id)
        end

        if limit > 0 then
            SetServerVariable('[Bots]HeadStart', limit)
            print(string.format('[bots] head start: the %d bots up to id %d get a few months of history at their next log in',
                (function() local n = 0 for _ in pairs(BotList() or {}) do n = n + 1 end return n end)(), limit))
        end
    end

    return limit
end

-- combat and magic skills of its main job near the cap for its level (it skilled up on the way)
local function headStartSkills(bot, level)
    local job = bot:getMainJob()
    local n = 0
    for skill = 1, 45 do
        local ok, cap = pcall(function()
            return bot:getMaxSkillLevel(level, job, skill)
        end)
        if ok and cap and cap > 0 then
            local want = math.floor(cap * 10 * (0.85 + math.random() * 0.15))
            local okReal, real = pcall(function()
                return bot:getCharSkillLevel(skill)
            end)
            if not okReal or (real or 0) < want then
                pcall(function()
                    bot:setSkillLevel(skill, want)
                end)
                n = n + 1
            end
        end
    end

    return n
end

-- at log in, once: true when it was given its history
function G.headStart(bot)
    if bot:getCharVar('[Bot]HeadStart') == 1 then
        return false
    end

    local limit = headStartLimit()
    if limit == 0 or bot:getID() > limit then
        return false
    end

    bot:setCharVar('[Bot]HeadStart', 1)
    if bot:getCharVar('[Bot]Main') ~= 0 and jobs then
        pcall(jobs.backToMain, bot) -- (it was levelling a subjob)
    end

    local lvl0 = bot:getMainLvl()
    local level = math.max(lvl0, headStartLevel())
    local name = bot:getName()
    local parts = {}
    if level > lvl0 then
        if level > 50 then
            pcall(function()
                bot:setLevelCap(math.min(75, math.ceil(level / 5) * 5)) -- (the limit breaks a player of that level has done)
            end)
        end

        local ok = pcall(function()
            bot:setLevel(level)
        end)
        if not ok then
            return false
        end

        parts[#parts + 1] = 'level ' .. level
        headStartSkills(bot, level)
        if jobs and jobs.headStart then
            local okJobs, what = pcall(jobs.headStart, bot, level)
            if okJobs and what and what ~= '' then
                parts[#parts + 1] = what
            end
        end
    end

    -- the rest of those days: crafting, gil, quests and missions, seals (in one-day pieces, so the paces stay right)
    local weights = craft and craft.planWeights(bot) or { hunt = 1 }
    local total, huntW = 0, weights.hunt or 0
    for _, w in pairs(weights) do
        total = total + w
    end

    local hours = math.min(HEAD_START_MAX_HOURS, huntHoursTo(level) * math.max(1, total) / math.max(1, huntW) + rnd(2, 20))
    local left = hours
    quiet = true
    while left > 0 do
        local piece = math.min(24, left)
        pcall(spend, bot, piece, 1, { headStart = true })
        left = left - piece
    end
    quiet = false

    if gear then
        local ok, n = pcall(gear.catchUp, bot)
        if ok and n and n > 0 then
            parts[#parts + 1] = n .. ' piece' .. (n > 1 and 's' or '') .. ' of gear'
        end
    end

    print(string.format('[bots] head start for %s: %s (%.0f hours of history), %d gil', name, table.concat(parts, ', '), hours, bot:getGil()))
    if level >= 50 then
        addNews(string.format('%s is a level %d veteran of the server', name, level))
    end

    return true
end

return G
