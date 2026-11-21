-----------------------------------
-- Squad: the Gambits job expansion (2026-11-21). Required by squad.lua (not listed in init.txt).
--
-- Gambits (the mate's chosen Rule Set) decides WHAT a mate does; the squad keeps doing HOW it moves, positions and
-- looks after its pet. This file connects the two for the jobs that need it:
--  - J.analyse(mob, rules): what a mate's chosen Rule Set asks for, set on the mate for the engine
--    (gambits_container.cpp, battle_entity.cpp) and for the squad's own loops:
--      SQUAD_SATA_MANAGED  the rules use Sneak Attack / Trick Attack: the engine only requests them until the squad
--                          has moved the thief into place (J.thiefManaged); without such rules squadThiefTick decides
--                          on its own, as before
--      SQUAD_SATA_WSHOLD   such a rule needs TP (TP_GTE): the weapon skill may wait a moment for it (HoldWeaponSkill)
--      SQUAD_SONG_ROLES    the rules sing songs for party roles (TANK, MELEE, CASTER, RANGED targets): each song
--                          reaches only those roles (xi.squad.songRecipient); songs for PARTY/SELF reach everyone
--  - J.applyRoles(mob): the party roles set with !squad partyrole <slot|name|me>, on the mates and on you, for the engine's TANK,
--    MELEE, CASTER and RANGED targets (local var SQUAD_ROLE; 0 = by main job, as before)
--  - J.petCare(mob, pet, now): a Beastmaster's pet follows its master's target; a Dragoon uses Spirit Link when its
--    wyvern is badly hurt (only when the mate's Rule Set does not use Spirit Link itself)
-- Everything here needs the job expansion's xi_map (squad.cpp registers SquadJobExpansionEngine); without it, nothing is
-- set and every mate behaves as before.
-----------------------------------
local J = {}

J.ROLE      = { auto = 0, tank = 1, melee = 2, mage = 3, caster = 3, ranged = 4 }
J.ROLE_NAME = { [0] = 'by job', 'tank', 'melee', 'mage', 'ranged' }
J.TARGET_ROLE = { TANK = 1, MELEE = 2, CASTER = 3, RANGED = 4 }

J.SA, J.TA = 44, 76          -- xi.ja.SNEAK_ATTACK, xi.ja.TRICK_ATTACK (ability.h)
J.REQUEST_SECS = 8           -- a Sneak/Trick Attack request the squad could not place in time is cancelled ...
J.BACKOFF_SECS = 10          -- ... and new requests are refused for this long (no endless retries)
J.SPIRIT_LINK_SECS = 5       -- at most one Spirit Link try this often

J.songs = {}                 -- [bard entity id] = { [song family id] = { all = bool, roles = { [role] = true } } }
J.uses  = {}                 -- [mate entity id] = { [job ability name] = true } (the abilities its Rule Set uses)

function J.engine2()
    return type(rawget(_G, 'SquadJobExpansionEngine')) == 'function'
end

-- the job groups of gambits_container.cpp (TANK = PLD/RUN, MELEE = melee_jobs, CASTER = caster_jobs, RANGED = RNG/COR)
local MELEE  = { [1] = true, [2] = true, [6] = true, [7] = true, [8] = true, [9] = true, [12] = true, [13] = true, [14] = true,
                 [16] = true, [18] = true, [19] = true, [22] = true }
local CASTER = { [3] = true, [4] = true, [5] = true, [10] = true, [15] = true, [16] = true, [20] = true, [21] = true, [22] = true }

-- is this member of that role (1 tank, 2 melee, 3 caster, 4 ranged)? An explicit party role decides; else the main job
function J.inRole(member, role)
    local own = member:getLocalVar('SQUAD_ROLE')
    if own ~= 0 then
        return own == role
    end

    local job = member:getMainJob()
    if role == 1 then
        return job == 7 or job == 22
    elseif role == 2 then
        return MELEE[job] == true
    elseif role == 3 then
        return CASTER[job] == true
    elseif role == 4 then
        return job == 11 or job == 17
    end

    return false
end

-- the buff songs (xi.magic.spellFamily names); enfeebling songs (Elegy, Requiem, Lullaby) go to the enemy and are never filtered
J.SONG_FAMILIES = { 'VALOR_MINUET', 'MARCH', 'KNIGHTS_MINNE', 'ARMYS_PAEON', 'MAGES_BALLAD', 'MADRIGAL', 'PRELUDE', 'MAMBO',
                    'OPERETTA', 'STR_ETUDE', 'DEX_ETUDE', 'VIT_ETUDE', 'AGI_ETUDE', 'INT_ETUDE', 'MND_ETUDE', 'CHR_ETUDE',
                    'FIRE_CAROL', 'ICE_CAROL', 'WIND_CAROL', 'EARTH_CAROL', 'LIGHTNING_CAROL', 'WATER_CAROL', 'LIGHT_CAROL',
                    'DARK_CAROL' }

local function familyIds()
    local fam = xi and xi.magic and xi.magic.spellFamily
    local out = {}
    if type(fam) == 'table' then
        for _, name in ipairs(J.SONG_FAMILIES) do
            if fam[name] ~= nil then
                out[fam[name]] = true
            end
        end
    end

    return out
end

-- the spell family of a rule's action, or nil
local function actionFamily(action)
    if type(action) ~= 'table' then
        return nil
    end

    if action[1] == 'family' then
        local fam = xi and xi.magic and xi.magic.spellFamily
        return type(fam) == 'table' and fam[action[2]] or nil
    elseif action[1] == 'spell' then
        local ids = xi and xi.magic and xi.magic.spell
        local id = type(ids) == 'table' and ids[action[2]] or nil
        local get = rawget(_G, 'GetSpell')
        if id and type(get) == 'function' then
            local ok, s = pcall(get, id)
            if ok and s then
                local okF, f = pcall(function() return s:getSpellFamily() end)
                return okF and f or nil
            end
        end
    end

    return nil
end
J.actionFamily = actionFamily

local function hasTpCondition(rule)
    for _, c in ipairs({ rule.cond, rule.cond2 }) do
        if type(c) == 'table' and c[1] == 'TP_GTE' then
            return true
        end
    end

    return false
end

-- What the chosen Rule Set (rules, or nil for none) asks for; sets the mate's local vars. Called when a mate is called.
function J.analyse(mob, rules)
    local id = mob:getID()
    J.songs[id], J.uses[id] = nil, nil
    mob:setLocalVar('SQUAD_SATA_MANAGED', 0)
    mob:setLocalVar('SQUAD_SATA_WSHOLD', 0)
    mob:setLocalVar('SQUAD_SONG_ROLES', 0)
    for _, k in ipairs({ 'SQUAD_SATA_REQ', 'SQUAD_SATA_REQ_AT', 'SQUAD_SATA_READY', 'SQUAD_SATA_TGT', 'SQUAD_SATA_BLOCK',
                         'SQUAD_WS_HOLD_UNTIL' }) do
        mob:setLocalVar(k, 0)
    end

    if type(rules) ~= 'table' or not J.engine2() then
        return
    end

    local uses, songs, songIds, limited = {}, {}, familyIds(), false
    local managed, hold = false, false
    for _, rule in ipairs(rules) do
        if type(rule) == 'table' and rule.on ~= false and type(rule.action) == 'table' then
            if rule.action[1] == 'ja' and type(rule.action[2]) == 'string' then
                uses[rule.action[2]] = true
                if rule.action[2] == 'SNEAK_ATTACK' or rule.action[2] == 'TRICK_ATTACK' then
                    managed = true
                    hold = hold or hasTpCondition(rule)
                end
            end

            local fam = actionFamily(rule.action)
            if fam and songIds[fam] then
                local entry = songs[fam] or { all = false, roles = {} }
                songs[fam] = entry
                local role = J.TARGET_ROLE[rule.target or '']
                if role then
                    entry.roles[role] = true
                    limited = true
                else
                    entry.all = true -- (SELF, PARTY, MASTER ...: the whole party around the Bard, as always)
                end
            end
        end
    end

    J.uses[id] = uses
    if managed then
        mob:setLocalVar('SQUAD_SATA_MANAGED', 1)
        mob:setLocalVar('SQUAD_SATA_WSHOLD', hold and 1 or 0)
    end

    if limited then
        J.songs[id] = songs
        mob:setLocalVar('SQUAD_SONG_ROLES', 1)
    end
end

-- battle_entity.cpp: does this member of the party around a squad Bard get this song? (only asked for a Bard whose rules
-- sing for party roles; anything not set up that way: yes)
function J.songRecipient(caster, target, spellId)
    local map = caster and J.songs[caster:getID()]
    if map == nil or target == nil then
        return true
    end

    local fam
    local get = rawget(_G, 'GetSpell')
    if type(get) == 'function' then
        local ok, s = pcall(get, spellId)
        if ok and s then
            local okF, f = pcall(function() return s:getSpellFamily() end)
            fam = okF and f or nil
        end
    end

    local entry = fam and map[fam]
    if entry == nil or entry.all then
        return true
    end

    for role in pairs(entry.roles) do
        if J.inRole(target, role) then
            return true
        end
    end

    return false
end

xi = xi or {}
xi.squad = xi.squad or {}
xi.squad.songRecipient = function(caster, target, spellId)
    local ok, yes = pcall(J.songRecipient, caster, target, spellId)
    return not ok or yes == true -- (an error never takes a song away)
end

-- ---------------------------------------------------------------- party roles (!squad partyrole)
local function roleVar(mateId)
    return mateId and ('SQUAD_PROLE_' .. mateId) or 'SQUAD_PROLE_ME'
end
J.roleVar = roleVar

-- the roles you set, on the mate being called and on you (both read by the engine while the squad is out)
function J.applyRoles(mob)
    local master = mob:getMaster()
    if master == nil then
        return
    end

    local mateId = mob:getLocalVar('SQUAD_ID')
    mob:setLocalVar('SQUAD_ROLE', mateId ~= 0 and master:getCharVar(roleVar(mateId)) or 0)
    master:setLocalVar('SQUAD_ROLE', master:getCharVar(roleVar(nil)))
end

-- !squad partyrole                       list
-- !squad partyrole <slot|name|me> <tank|melee|mage|ranged|auto>
J.PARTYROLE_USAGE = '!squad partyrole <slot|name|me> tank|melee|mage|ranged|auto  (slot = the [number] in !squad list)'

-- the squad mate a chat argument names: its slot number (chat arguments are strings; findMate compares numbers), else
-- its name in any case - the same lookup as the other !squad commands (camp)
function J.mateFor(squad, who, findMate)
    local mate = findMate(squad, tonumber(who) or -1)
    if mate == nil and who ~= nil then
        local name = string.lower(tostring(who))
        for _, m in ipairs(squad) do
            if mate == nil and type(m.name) == 'string' and string.lower(m.name) == name then
                mate = m
            end
        end
    end

    return mate
end

function J.partyRoleCommand(player, squad, who, role, h)
    local say = h.say
    if who == nil then
        local lines = { 'Party roles (who a Rule Set\'s Tank/Melee/Mage/Ranged targets mean): you ' ..
            J.ROLE_NAME[player:getCharVar(roleVar(nil))] }
        for _, m in ipairs(squad) do
            lines[#lines + 1] = string.format('[%d] %s %s', m.slot or 0, m.name,
                J.ROLE_NAME[player:getCharVar(roleVar(m.id))] or 'by job')
        end

        say(player, table.concat(lines, ', '))
        say(player, J.PARTYROLE_USAGE)
        say(player, '(auto = by main job: PLD/RUN tank, RNG/COR ranged ...)')
        return
    end

    local value = J.ROLE[string.lower(role or '')]
    if value == nil then
        say(player, J.PARTYROLE_USAGE)
        return
    end

    if string.lower(who) == 'me' then
        player:setCharVar(roleVar(nil), value)
        player:setLocalVar('SQUAD_ROLE', value)
        say(player, string.format('You count as %s for your squad\'s Rule Sets now.', J.ROLE_NAME[value]))
        return
    end

    local mate = J.mateFor(squad, who, h.findMate)
    if mate == nil then
        say(player, 'No squad mate ' .. tostring(who) .. ' (see !squad list).')
        say(player, J.PARTYROLE_USAGE)
        return
    end

    player:setCharVar(roleVar(mate.id), value)
    say(player, string.format('%s counts as %s for Rule Sets. Call it again (or !squad reapply) to apply it.', mate.name,
        J.ROLE_NAME[value]))
end

-- ---------------------------------------------------------------- Sneak Attack / Trick Attack under the Rule Set
-- squadThiefTick's branch for a thief whose Rule Set uses SA/TA. The engine asks (SQUAD_SATA_REQ = the ability) when a
-- rule decides to use one; this moves the thief (SQUAD_FLANK, the trust controller), says when the position is right
-- (SQUAD_SATA_READY), keeps the position until the hit or weapon skill used the effect, and cancels a request that cannot
-- be served (no target, target changed or dead, the thief took the enemy's attention, no tank for Trick Attack, too long).
-- Returns the flank (0 none, 1 behind the target, 2 behind the tank).
function J.thiefManaged(mob, lvl, target, now)
    local req, ready, flank = mob:getLocalVar('SQUAD_SATA_REQ'), 0, 0
    local tank      = target and target:getTarget() or nil
    local tanking   = tank ~= nil and tank:getID() == mob:getID()
    local otherTank = tank ~= nil and not tanking and tank:isAlive()

    local function cancel(backoff)
        req = 0
        mob:setLocalVar('SQUAD_SATA_REQ', 0)
        mob:setLocalVar('SQUAD_SATA_TGT', 0)
        if backoff then
            mob:setLocalVar('SQUAD_SATA_BLOCK', now + J.BACKOFF_SECS)
        end
    end

    if target == nil or not target:isAlive() then
        cancel(false)
    elseif mob:hasStatusEffect(xi.effect.SNEAK_ATTACK) then
        flank = tanking and 0 or 1 -- (keep the place behind until the hit used it)
        cancel(false)
    elseif mob:hasStatusEffect(xi.effect.TRICK_ATTACK) then
        flank = (otherTank and mob:checkDistance(target) <= 4) and 2 or 0
        cancel(false)
    elseif req ~= 0 and mob:hasRecast(xi.recast.ABILITY, req) then
        cancel(false) -- (used meanwhile, or on recast: nothing to prepare; trust recasts are kept by ability id)
    elseif req ~= 0 then
        local tgt = mob:getLocalVar('SQUAD_SATA_TGT')
        if tgt == 0 then
            mob:setLocalVar('SQUAD_SATA_TGT', target:getID())
            tgt = target:getID()
        end

        if now < mob:getLocalVar('SQUAD_SATA_BLOCK') or tgt ~= target:getID() then
            cancel(false)
        elseif now - mob:getLocalVar('SQUAD_SATA_REQ_AT') > J.REQUEST_SECS then
            cancel(true)
        elseif req == J.SA then
            if lvl < 15 or tanking then
                cancel(true) -- (the enemy faces us: there is no getting behind it)
            else
                flank = 1
                if mob:isBehind(target) and mob:checkDistance(target) < 4 then
                    ready = J.SA
                end
            end
        elseif req == J.TA then
            if lvl < 30 or not otherTank then
                cancel(true)
            else
                flank = 2
                if mob:checkDistance(tank) < 2 and mob:checkDistance(target) <= 4 and target:checkDistance(tank) < target:checkDistance(mob) then
                    ready = J.TA
                end
            end
        else
            cancel(false)
        end
    end

    mob:setLocalVar('SQUAD_SATA_READY', ready)

    -- the weapon skill hold (HoldWeaponSkill): ended early when nothing is being prepared any more, or when the thief has
    -- the enemy's attention; started again after the next weapon skill (TP below 1000)
    if mob:getLocalVar('SQUAD_SATA_WSHOLD') ~= 0 then
        local holding = mob:getLocalVar('SQUAD_WS_HOLD_UNTIL')
        if mob:getTP() < 1000 then
            if holding ~= 0 then
                mob:setLocalVar('SQUAD_WS_HOLD_UNTIL', 0)
            end
        elseif holding > now then
            -- (the hold is 8 s from its start; the rules get one evaluation, 2-3 s, to ask for Sneak/Trick Attack)
            local startedAt = holding - 8
            local preparing = req ~= 0 or mob:hasStatusEffect(xi.effect.SNEAK_ATTACK) or mob:hasStatusEffect(xi.effect.TRICK_ATTACK)
            if tanking or (not preparing and now - startedAt >= 4) then
                mob:setLocalVar('SQUAD_WS_HOLD_UNTIL', 1) -- (over: the weapon skill may go)
            end
        end
    end

    return flank
end

-- ---------------------------------------------------------------- pets
-- After the squad's own pet actions (squad.lua petTick), every combat tick
function J.petCare(mob, pet, target, now)
    if pet == nil or not J.engine2() then
        return
    end

    local job = mob:getMainJob()
    if job == 9 and target ~= nil and target:isAlive() then
        -- Beastmaster: the pet fights what its master fights (SquadPetAttack only sends an idle pet)
        local petTarget = pet:getTarget()
        if petTarget ~= nil and petTarget:getID() ~= target:getID() then
            pcall(function() mob:petAttack(target) end)
        end
    elseif job == 14 and mob:getMainLvl() >= 25 then
        -- Dragoon: Spirit Link (gives the wyvern HP) when the wyvern is badly hurt and the dragoon can spare it; not when
        -- the mate's Rule Set uses Spirit Link (the rule decides then)
        local uses = J.uses[mob:getID()]
        if (uses == nil or not uses.SPIRIT_LINK) and pet:getHPP() > 0 and pet:getHPP() < 40 and mob:getHPP() >= 60
            and now >= mob:getLocalVar('SQUAD_SLINK_NEXT') then
            local id = xi.ja and xi.ja.SPIRIT_LINK
            mob:setLocalVar('SQUAD_SLINK_NEXT', now + J.SPIRIT_LINK_SECS)
            if id and not mob:hasRecast(xi.recast.ABILITY, id) and type(rawget(_G, 'SquadUseAbility')) == 'function' then
                pcall(SquadUseAbility, mob:getMaster(), mob, id)
            end
        end
    end
end

return J
