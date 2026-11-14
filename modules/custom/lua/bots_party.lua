-----------------------------------
-- FFXI Offline: bot players - playing their job in a party (step 4.3). Used by bots.lua and bots_hunt.lua.
--
-- A bot uses the same job profiles as your squad mates (squad.lua: the gambit lists for each job and level,
-- main job + sub job, including your own Gambits sheet rules), read through xi.squad.profileFor. Each line is
-- "target / condition / action": cure a party member under 75% HP, Protect whoever lacks it, Provoke when the
-- monster is not on the tank, Berserk when it is not up, Dia on the target, and so on. The bot checks them in
-- order (about every 2 seconds) and does the first one that fits, through the same packets a player sends
-- (spells it really knows, its MP, its job abilities). Weapon skills and skillchains stay with the fight brain.
-- Mages that do not melee (WHM, BLM, SMN, BRD) stay behind you instead of running to the monster.
-----------------------------------
local P = {}

local CHECK_EVERY = 2      -- seconds between two decisions
local CAST_WAIT   = 5      -- seconds after a spell before the next action
local JA_WAIT     = 2
local JA_RECAST   = 60     -- seconds before the same job ability is tried again (the server refuses earlier ones anyway)
local RANGE       = 20     -- yalms: party members it helps

local NO_MELEE = { [3] = true, [4] = true, [10] = true, [15] = true } -- WHM, BLM, BRD, SMN
local TANKS = { [1] = true, [7] = true, [13] = true }                 -- WAR, PLD, NIN
local CASTERS = { [3] = true, [4] = true, [5] = true, [10] = true, [15] = true, [16] = true }

local profiles = {}        -- ['job:lvl:sub:sublvl'] = gambit list
local families             -- [family id] = { spell ids, best last }

local function now()
    return os.time()
end

local function dist2(a, b)
    local pa, pb = a:getPos(), b:getPos()
    return (pa.x - pb.x) ^ 2 + (pa.z - pb.z) ^ 2
end

function P.available()
    return xi.squad ~= nil and type(xi.squad.profileFor) == 'function' and ai ~= nil and ai.c ~= nil
end

function P.stayBack(bot)
    return NO_MELEE[bot:getMainJob()] == true
end

local function profileOf(bot)
    local key = string.format('%d:%d:%d:%d', bot:getMainJob(), bot:getMainLvl(), bot:getSubJob(), bot:getSubLvl())
    if not profiles[key] then
        local ok, list = pcall(xi.squad.profileFor, bot:getMainJob(), bot:getMainLvl(), bot:getSubJob(), bot:getSubLvl())
        profiles[key] = (ok and type(list) == 'table') and list or {}
    end

    return profiles[key]
end

-- every spell of a family, lowest first (once)
local function familySpells(fam)
    if not families then
        families = {}
        for id = 1, 1023 do
            local ok, f = pcall(function()
                local s = GetSpell(id)
                return s and s:getSpellFamily() or nil
            end)
            if ok and f and f ~= 0 then
                families[f] = families[f] or {}
                table.insert(families[f], id)
            end
        end
    end

    return families[fam] or {}
end

local function mpCost(id)
    local ok, c = pcall(function()
        return GetSpell(id):getMPCost()
    end)
    return (ok and c) or 0
end

local function canCast(bot, id)
    return bot:hasSpell(id) and bot:getMP() >= mpCost(id)
end

-----------------------------------
-- conditions
-----------------------------------
local function hasTop(entity, mob)
    if not mob then
        return false
    end

    local t = mob:getTarget()
    return t ~= nil and t:getID() == entity:getID()
end

local check -- forward

local function one(c, who, ctx)
    local kind, value = c[1], c[2] or 0
    local C = ai.c
    if kind == C.ALWAYS then
        return true
    elseif kind == C.HPP_LT then
        return who:getHPP() < value
    elseif kind == C.HPP_GTE then
        return who:getHPP() >= value
    elseif kind == C.MPP_LT then
        return who:getMaxMP() > 0 and who:getMPP() < value
    elseif kind == C.MPP_GTE then
        return who:getMaxMP() > 0 and who:getMPP() >= value
    elseif kind == C.TP_LT then
        return who:getTP() < value
    elseif kind == C.TP_GTE then
        return who:getTP() >= value
    elseif kind == C.LVL_LT then
        return who:getMainLvl() < value
    elseif kind == C.LVL_GTE then
        return who:getMainLvl() >= value
    elseif kind == C.STATUS then
        return who:hasStatusEffect(value)
    elseif kind == C.NOT_STATUS then
        return not who:hasStatusEffect(value)
    elseif kind == C.HAS_TOP_ENMITY then
        return hasTop(who, ctx.mob)
    elseif kind == C.NOT_HAS_TOP_ENMITY then
        return ctx.mob ~= nil and not hasTop(who, ctx.mob)
    elseif kind == C.RANDOM then
        return math.random(100) <= value
    elseif kind == C.PT_HAS_TANK then
        return ctx.tank ~= nil
    elseif kind == C.NOT_PT_HAS_TANK then
        return ctx.tank == nil
    elseif kind == C.HP_MISSING then
        return (who:getMaxHP() - who:getHP()) >= value
    end

    return false -- (conditions a bot cannot judge: skipped)
end

check = function(c, who, ctx)
    if type(c) ~= 'table' then
        return false
    end

    if c.logic ~= nil and c.conditions then -- ai.logic.OR(...)
        for _, sub in ipairs(c.conditions) do
            if check(sub, who, ctx) then
                return true
            end
        end

        return false
    end

    if type(c[1]) == 'table' then -- both(a, b)
        for _, sub in ipairs(c) do
            if not check(sub, who, ctx) then
                return false
            end
        end

        return true
    end

    return one(c, who, ctx)
end

-----------------------------------
-- targets and actions
-----------------------------------
local function candidates(bot, target, ctx)
    local T = ai.t
    if target == T.SELF or target == T.TRIGGER_TARGET_ACTION_SELF then
        return { bot }
    elseif target == T.TARGET or target == T.TRIGGER_SELF_ACTION_TARGET then
        return ctx.mob and { ctx.mob } or {}
    elseif target == T.MASTER then
        return ctx.leader and { ctx.leader } or {}
    elseif target == T.TANK then
        return ctx.tank and { ctx.tank } or {}
    elseif target == T.TOP_ENMITY then
        local t = ctx.mob and ctx.mob:getTarget()
        return t and { t } or {}
    end

    local out = {}
    for _, m in ipairs(ctx.members) do
        local job = m:getMainJob()
        if target == T.PARTY or target == T.PARTY_MULTI or (target == T.MELEE and not CASTERS[job]) or (target == T.CASTER and CASTERS[job]) then
            out[#out + 1] = m
        end
    end

    return out
end

local function doAction(bot, st, action, who)
    local R, S = ai.r, ai.s
    local id = bot:getID()
    if action[1] == R.MA then
        local spell
        if action[2] == S.SPECIFIC then
            spell = canCast(bot, action[3]) and action[3] or nil
        else
            local list = familySpells(action[3])
            for i = #list, 1, -1 do
                if canCast(bot, list[i]) then
                    spell = list[i]
                    break
                end
            end
        end

        if spell then
            BotCast(id, spell, who)
            st.partyWait = now() + CAST_WAIT
            return true
        end
    elseif action[1] == R.JA and action[2] == S.SPECIFIC then
        st.jaUsed = st.jaUsed or {}
        if now() >= (st.jaUsed[action[3]] or 0) then
            st.jaUsed[action[3]] = now() + JA_RECAST
            BotAbility(id, action[3], who)
            st.partyWait = now() + JA_WAIT
            return true
        end
    end

    return false
end

-- one decision for a bot in a party (with you or with other bots); mob = the monster being fought (or nil).
-- Returns true when it did something.
function P.act(bot, st, leader, mob)
    if not P.available() or bot:isDead() or now() < (st.partyWait or 0) or now() < (st.partyCheck or 0) then
        return false
    end

    st.partyCheck = now() + CHECK_EVERY
    local ctx = { leader = leader, mob = (mob and mob:isAlive()) and mob or nil, members = {} }
    for _, m in pairs(bot:getParty() or {}) do
        if m:getZoneID() == bot:getZoneID() and m:isAlive() and dist2(m, bot) <= RANGE * RANGE then
            ctx.members[#ctx.members + 1] = m
            if not ctx.tank and TANKS[m:getMainJob()] then
                ctx.tank = m
            end
        end
    end

    for _, g in ipairs(profileOf(bot)) do
        if type(g.action) == 'table' and (g.action[1] == ai.r.MA or g.action[1] == ai.r.JA) then
            local list = candidates(bot, g.target, ctx)
            -- for HP conditions: the most hurt first
            table.sort(list, function(a, b)
                return a:getHPP() < b:getHPP()
            end)
            for _, who in ipairs(list) do
                local subject = who
                if g.target == ai.t.TRIGGER_SELF_ACTION_TARGET then
                    subject = bot
                elseif g.target == ai.t.TRIGGER_TARGET_ACTION_SELF then
                    subject, who = ctx.mob, bot
                end

                if subject and check(g.condition, subject, ctx) and doAction(bot, st, g.action, who) then
                    return true
                end
            end
        end
    end

    return false
end

-- for the tests
P._check = check

return P
