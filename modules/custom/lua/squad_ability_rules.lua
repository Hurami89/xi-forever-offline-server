-----------------------------------
-- Gambits v2 U13: which job abilities a player's squad mate may use (XI: Forever Offline).
--
-- One set of rules for every way a squad mate gets a job ability from Lua: the built-in job rules (squad.lua addJA),
-- the launcher-edited job rules and the Rule Sets (squad.lua applyRules / squad_rulesets.lua). They all pass through
-- squad.lua addGambit, which asks allowGambit() here. (Abilities asked for in chat go through squad.cpp
-- trySquadAbility, which applies the same rules in C++.)
--
-- The trust engine itself checks none of this for a trust (ability_state.cpp CanUseAbility only checks players), so
-- these are the rules charutils.cpp BuildingCharAbilityTable / CheckAbilityAddtype use for players:
--   main job: the ability's job at its level; never a pet ability (id >= ABILITY_HEALING_RUBY 512) or PET_COMMANDS (55)
--   sub job:  the same, and never a level-0 ability (two-hours) or an ADDTYPE_MAIN_ONLY one (Afflatus Solace, Spirit Link, ...)
--   merit:    an ADDTYPE_MERIT ability (Martyr, Devotion, ...) needs that merit unlocked by the mate's OWNER (the player),
--             whatever job the owner has on now: SquadOwnerMerit(owner, meritId) from squad.cpp reads the upgrade count
-- Other player conditions (learned rolls, pets present, Arts, quests) are NOT applied here (U13 scope).
--
-- Everything fails closed: no table, an old or broken table, a row missing, or (for merit abilities) no
-- SquadOwnerMerit, and the ability is not used. Bots are not affected: a bot's profile (xi.squad.profileFor) has no
-- player owner, and bots act through the server's own player checks with their own character data.
-- The data is squad_ja_jobs_data.lua, made from sql/abilities.sql by dev/gambits-v2-squad/make_squad_ja_jobs.py.
-- This file defines no globals.
-----------------------------------
local A = {}

A.DATA_MODULE       = 'modules/custom/lua/squad_ja_jobs_data'
A.TABLE_VERSION     = 3    -- version 3 has the merit ids; older tables are refused
A.FIRST_PET_ABILITY = 512  -- ABILITY_HEALING_RUBY (ability.h): from here on the abilities are the pets' own
A.PET_COMMANDS      = 55   -- ABILITY_PET_COMMANDS: a menu entry, not an ability

local abilities = nil  -- the table once it was read correctly (kept for the server run)
local lastProblem = nil
local logged = {}      -- reasons already printed, so the same refusal is printed once per server run

local function isWhole(value, low, high)
    return type(value) == 'number' and value == math.floor(value) and value >= low and value <= high
end

local function readTable()
    if abilities ~= nil then
        return abilities
    end

    package.loaded[A.DATA_MODULE] = nil
    local ok, data = pcall(require, A.DATA_MODULE)
    package.loaded[A.DATA_MODULE] = nil
    local problem = nil
    if not ok then
        problem = 'squad_ja_jobs_data.lua is missing or unreadable (' .. tostring(data) .. ')'
    elseif type(data) ~= 'table' or data.version ~= A.TABLE_VERSION or type(data.abilities) ~= 'table' or next(data.abilities) == nil then
        problem = string.format('squad_ja_jobs_data.lua is not a version %d ability table', A.TABLE_VERSION)
    end

    if problem then
        if problem ~= lastProblem then
            print('[squad] Ability rules: ' .. problem .. '; squad mates use no job abilities from their rules until it is fixed')
        end

        lastProblem = problem
        return nil
    end

    lastProblem = nil
    abilities = data.abilities
    return abilities
end

-- Forgets the table so the next check reads it again (after it was regenerated; also used by the tests)
function A.reload()
    abilities, lastProblem, logged = nil, nil, {}
end

-- The id of a job ability name (xi.ja), or nil
function A.idOf(name)
    local jaIds = type(xi) == 'table' and rawget(xi, 'ja') or nil
    return type(jaIds) == 'table' and type(name) == 'string' and jaIds[name] or nil
end

local function nameOf(id)
    local jaIds = type(xi) == 'table' and rawget(xi, 'ja') or nil
    if type(jaIds) == 'table' then
        for name, value in pairs(jaIds) do
            if value == id then
                return name
            end
        end
    end

    return 'ability ' .. tostring(id)
end

-- info, or false (the table has no valid row for it), or nil (no table)
-- info = { job, level, sp, mainOnly, merit (id or nil), pet }
function A.info(id)
    local t = readTable()
    if t == nil or id == nil then
        return nil
    end

    local row = t[id]
    if type(row) ~= 'table' or not isWhole(row[1], 0, 255) or not isWhole(row[2], 0, 255)
        or (row.sp ~= nil and type(row.sp) ~= 'boolean') or (row.main ~= nil and type(row.main) ~= 'boolean')
        or (row.merit ~= nil and not isWhole(row.merit, 1, 65535)) then
        return false
    end

    return { job = row[1], level = row[2], sp = row.sp == true or row[2] == 0, mainOnly = row.main == true,
             merit = row.merit, pet = id >= A.FIRST_PET_ABILITY or id == A.PET_COMMANDS }
end

-- How many upgrades the owner has in a merit: count, or nil and why it cannot be told (fail closed)
function A.ownerMerit(owner, meritId)
    local query = rawget(_G, 'SquadOwnerMerit')
    if type(query) ~= 'function' then
        return nil, 'this server cannot check merits (SquadOwnerMerit is missing: it needs the rebuilt map server)'
    end

    if owner == nil or type(owner) == 'number' then
        return nil, 'the squad mate has no owner to check the merit against'
    end

    local ok, count = pcall(query, owner, meritId)
    if not ok or type(count) ~= 'number' then
        return nil, 'the merit check failed (' .. tostring(count) .. ')'
    end

    return count
end

-- Why a mate cannot use a job ability, or nil when it can.
-- m = { job, level, subJob, subLevel, owner }; id = the ability id (name only for the two-hour list and messages)
function A.reason(m, id, name)
    name = name or nameOf(id)
    if id == nil then
        return 'unknown job ability ' .. tostring(name)
    end

    local info = A.info(id)
    if info == nil then
        return name .. ': the job ability table (squad_ja_jobs_data.lua) is not available'
    elseif info == false then
        return name .. ' is not in the job ability table'
    elseif info.pet then
        return name .. ' is a pet ability or the pet command menu'
    end

    local twoHour = info.sp or (SQUAD_TWO_HOURS ~= nil and SQUAD_TWO_HOURS[name]) or false
    local subJob, subLevel = m.subJob or 0, m.subLevel or 0
    local asMain = info.job == m.job and info.level <= (m.level or 0)
    local asSub = subJob ~= 0 and info.job == subJob and not twoHour and not info.mainOnly and info.level <= subLevel
    if not asMain and not asSub then
        if info.job ~= m.job and info.job ~= subJob then
            return string.format('%s is not a job ability of its main or sub job', name)
        elseif info.job == subJob and info.job ~= m.job and twoHour then
            return string.format('%s is a two-hour ability and only works as the main job', name)
        elseif info.job == subJob and info.job ~= m.job and info.mainOnly then
            return string.format('%s only works as the main job', name)
        end

        return string.format('%s needs level %d', name, info.level)
    end

    if info.merit ~= nil then
        local count, why = A.ownerMerit(m.owner, info.merit)
        if count == nil then
            return string.format('%s needs a merit, and %s', name, why)
        elseif count <= 0 then
            return string.format('%s needs its merit (%d) unlocked by the squad\'s owner', name, info.merit)
        end
    end

    return nil
end

-- The owner of a squad mate, or nil (a bot's profile recorder, or a mob without a player master)
function A.ownerOf(mob)
    local master = mob:getMaster()
    if master == nil or type(master) == 'number' or type(master) == 'boolean' then
        return nil
    end

    local objType = type(xi) == 'table' and rawget(xi, 'objType') or nil
    if objType ~= nil and objType.PC ~= nil and master:getObjType() ~= objType.PC then
        return nil
    end

    return master
end

-- squad.lua addGambit: false = leave this job ability gambit out. Only for a player's squad mate; anything else
-- (a bot's profile) is not checked here.
function A.allowGambit(mob, abilityId)
    local owner = A.ownerOf(mob)
    if owner == nil then
        return true
    end

    local m = { job = mob:getMainJob(), level = mob:getMainLvl(), subJob = mob:getSubJob() or 0,
                subLevel = mob:getSubLvl() or 0, owner = owner }
    local why = A.reason(m, abilityId)
    if why == nil then
        return true
    end

    local key = string.format('%d/%d %d/%d %s', m.job, m.level, m.subJob, m.subLevel, why)
    if not logged[key] then
        logged[key] = true
        print(string.format('[squad] Ability rules: left out for a squad mate (job %d level %d, sub job %d level %d): %s',
            m.job, m.level, m.subJob, m.subLevel, why))
    end

    return false
end

return A
