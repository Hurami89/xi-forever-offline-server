-----------------------------------
-- FFXI Offline: bot players - gear. Used by bots.lua (and bots_growth.lua).
--
-- Like players of the era, a bot upgrades its gear as it levels: now and then in town (after a level up, a job change,
-- or every hour or so) it looks at what it wears against what its job wants at its level (bots_gear_data.lua, built by
-- build_bots_gear.py from the server's item tables and the HorizonXI market prices), wears the best it already owns,
-- and buys the upgrades it can afford: a weapon of its job's usual type, a shield (or a second katana for a Ninja),
-- armor, neck, waist, two earrings, two rings and a back piece. Real items, real gil (spent), worn for real (/check).
-- It only buys a piece that is a clear step up, and spends at most part of its gil: a thrifty or poor bot wears
-- older gear for longer, a rich one shines.
-----------------------------------
local GR = {}

local DATA_PATH   = 'modules/custom/lua/bots_gear_data'
local JOBS        = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP' }
local SLOT_ORDER  = { 0, 1, 5, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 }
local PAIR        = { [12] = 11, [14] = 13 } -- the second earring / ring: a different piece than the first
local SPEND_SHARE = 0.45      -- of its gil, at most, on one shopping trip
local KEEP_GIL    = 500       -- never below this
local STEP_UP     = 1.15      -- a new piece must be this much better (and at least +1 score) to be worth buying
local EVERY       = 3600      -- seconds between two looks at the auction house (sooner after a level up / job change)

local data -- false when the file is missing

local function gearData()
    if data == nil then
        local ok, d = pcall(require, DATA_PATH)
        data = (ok and type(d) == 'table') and d or false
        if not data then
            print('[bots] bot gear is off: bots_gear_data.lua is missing (run build_bots_gear.py): ' .. tostring(d))
        end
    end

    return data or nil
end

function GR.available()
    return gearData() ~= nil
end

local function note(text)
    print('[bots] ' .. text)
end

local function listFor(bot, slot)
    local d = gearData()
    local job = JOBS[bot:getMainJob()]
    return d and job and d[job] and d[job][slot] or nil
end

local function entryOf(list, id)
    if not list or not id or id == 0 then
        return nil
    end

    for _, e in ipairs(list) do
        if e[1] == id then
            return e
        end
    end

    return nil
end

local function equipped(bot, slot)
    local ok, id = pcall(function()
        return bot:getEquipID(slot)
    end)
    return (ok and id) or 0
end

local function owns(bot, id)
    local ok, has = pcall(function()
        return bot:hasItem(id, 0)
    end)
    return ok and has
end

local function canDualWield(bot)
    return JOBS[bot:getMainJob()] == 'NIN' and bot:getMainLvl() >= 10
end

-- the plan for every slot: { slot, id, buy (true when it has to be bought), price, score }
-- budget: gil it may spend (0: only what it owns)
function GR.plan(bot, budget)
    local lvl = bot:getMainLvl()
    local left = budget or 0
    local out, chosen = {}, {}
    local twoHanded = false
    for _, slot in ipairs(SLOT_ORDER) do
        local list = listFor(bot, slot)
        local skip = not list or (slot == 1 and (twoHanded or (JOBS[bot:getMainJob()] == 'NIN' and not canDualWield(bot))))
        if not skip then
            local except = PAIR[slot] and chosen[PAIR[slot]] or nil
            local current = equipped(bot, slot)
            local curEntry = entryOf(list, current)
            local curScore = curEntry and current ~= except and curEntry[3] or 0
            local owned, buy = nil, nil
            for _, e in ipairs(list) do
                if e[2] <= lvl and e[1] ~= except and not (slot == 1 and e[1] == chosen[0]) then
                    if (not owned or e[3] > owned[3]) and (e[1] == current or owns(bot, e[1])) then
                        owned = e
                    end

                    if e[4] <= left and (not buy or e[3] > buy[3]) then
                        buy = e
                    end
                end
            end

            -- (nearly as good for much less: a player takes the cheaper one)
            if buy then
                local top = buy[3]
                for _, e in ipairs(list) do
                    if e[2] <= lvl and e[1] ~= except and e[4] < buy[4] and e[3] >= top * 0.9 and not (slot == 1 and e[1] == chosen[0]) then
                        buy = e
                    end
                end
            end

            local have = math.max(curScore, owned and owned[3] or 0)
            local pick, buying = nil, false
            if buy and not (owned and owned[1] == buy[1]) and buy[3] >= have * STEP_UP and buy[3] >= have + 1 then
                pick, buying = buy, true
                left = left - buy[4]
            elseif owned and owned[3] > curScore then
                pick = owned
            elseif curEntry and current ~= except then
                pick = curEntry
            end

            if pick then
                chosen[slot] = pick[1]
                if slot == 0 then
                    twoHanded = pick[5] == 1
                end

                if buying or pick[1] ~= current then
                    out[#out + 1] = { slot = slot, id = pick[1], buy = buying, price = pick[4], score = pick[3], two = pick[5] == 1 }
                end
            elseif slot == 0 and curEntry == nil and current ~= 0 then
                twoHanded = false -- (a weapon we do not know: leave it be)
            end
        end
    end

    return out
end

local function wear(bot, slot, id, two)
    pcall(function()
        if slot == 0 and two then
            bot:unequipItem(1) -- (a shield cannot stay with a two-handed weapon)
        end

        bot:equipItem(id, 0, slot)
    end)
end

-- wears what the plan says, buying what it must (gil spent, the item bought "at the auction house")
local function carryOut(bot, plan, quiet)
    local spent, bought, names = 0, 0, {}
    for _, p in ipairs(plan) do
        if p.buy then
            if bot:getFreeSlotsCount() < 1 or bot:getGil() < p.price + KEEP_GIL then
                break
            end

            local ok = pcall(function()
                bot:delGil(p.price)
                bot:addItem(p.id, 1)
            end)
            if ok then
                spent, bought = spent + p.price, bought + 1
                names[#names + 1] = tostring(p.id)
            end
        end

        if not p.buy or owns(bot, p.id) then
            wear(bot, p.slot, p.id, p.two)
        end
    end

    if bought > 0 and not quiet then
        note(string.format('%s bought %d piece%s of gear for %d gil (Lv%d %s): items %s', bot:getName(), bought, bought > 1 and 's' or '',
            spent, bot:getMainLvl(), JOBS[bot:getMainJob()] or '?', table.concat(names, ', ')))
    end

    return bought, spent
end

-- wears the best it owns (after a job change, at log in)
function GR.equipOwned(bot)
    if not gearData() then
        return 0
    end

    return select(1, carryOut(bot, GR.plan(bot, 0), true))
end

-- in town: time for new gear? (level up, job change, or a while since the last look); true when it bought something
function GR.check(bot, force)
    if not gearData() then
        return false
    end

    local now = os.time()
    local key = bot:getMainJob() * 100 + bot:getMainLvl()
    local fresh = bot:getCharVar('[Bot]GearKey') ~= key
    if not force and not fresh and bot:getCharVar('[Bot]GearAt') + EVERY > now then
        return false
    end

    bot:setCharVar('[Bot]GearKey', key)
    bot:setCharVar('[Bot]GearAt', now)
    local budget = math.max(0, math.floor(math.min(bot:getGil() - KEEP_GIL, bot:getGil() * SPEND_SHARE)))
    local bought = carryOut(bot, GR.plan(bot, budget), false)
    if bought > 0 and math.random() < 0.35 and BotChat then
        local lines = { 'finally upgraded my gear :)', 'new gear!! feels good', 'spent all my gil on gear again lol', 'got some upgrades at the ah' }
        BotChat(bot:getID(), 0, lines[math.random(1, #lines)])
    end

    return bought > 0
end

-- for bots_growth.lua: shopping it did while you were away (quiet, no chat)
function GR.catchUp(bot)
    if not gearData() then
        return 0
    end

    local budget = math.max(0, math.floor(math.min(bot:getGil() - KEEP_GIL, bot:getGil() * SPEND_SHARE)))
    bot:setCharVar('[Bot]GearKey', bot:getMainJob() * 100 + bot:getMainLvl())
    bot:setCharVar('[Bot]GearAt', os.time())
    return select(1, carryOut(bot, GR.plan(bot, budget), true))
end

-- gear worth keeping: a piece of its job's list it can wear within a few levels and that beats what it has there now
function GR.useful(bot, id)
    if not gearData() then
        return false
    end

    local lvl = bot:getMainLvl()
    for _, slot in ipairs(SLOT_ORDER) do
        local list = listFor(bot, slot)
        local e = entryOf(list, id)
        if e and e[2] <= lvl + 5 then
            local cur = entryOf(list, equipped(bot, slot))
            if not cur or e[3] > cur[3] then
                return true
            end
        end
    end

    return false
end

-- how well geared it is for its level (for !bots where and its chat): 'well geared', 'ok gear', 'old gear'
function GR.describe(bot)
    if not gearData() then
        return nil
    end

    local have, best = 0, 0
    for _, slot in ipairs({ 0, 4, 5, 6, 7, 8 }) do
        local list = listFor(bot, slot)
        if list then
            local e = entryOf(list, equipped(bot, slot))
            have = have + (e and e[3] or 0)
            local top = 0
            for _, x in ipairs(list) do
                if x[2] <= bot:getMainLvl() and x[3] > top then
                    top = x[3]
                end
            end

            best = best + top
        end
    end

    if best <= 0 then
        return nil
    end

    local r = have / best
    return r >= 0.8 and 'well geared' or (r >= 0.5 and 'ok gear' or 'old gear')
end

-- for the tests
GR._setData = function(d)
    data = d
end

return GR
