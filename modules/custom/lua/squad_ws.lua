-----------------------------------
-- Gambits weapon skill settings for squad mates (XI: Forever Offline, Gambits WAR/PLD/RDM/WS batch, 2026-11-20).
--
-- Per squad mate AND main job, separate from Rule Sets. Stored on the player as ONE char var
--   SQUAD_WSC_<mate id>_<job id> = 1 + control*2 + mode*4 + tpIndex*32 + wsId*128
-- bit 0 is always set for a stored setting, so the three states never mix:
--   0 (or no var)        no Gambits setting: the older per-mate !squad ws vars (SQUAD_WSTP_/SQUAD_WS_) apply, as before
--   odd, control 0       "Squad default", chosen in Gambits: the automatic skillchain roles and every weapon skill, even
--                        when !squad ws holds an older setting (the stored mode/TP/weapon skill are kept for later)
--   odd, control 1       Custom: mode, TP threshold and weapon skill below
-- mode: 1 Open, 2 Close, 3 Open + Close, 4 Independent (engine triggers OPEN_AT_TP, CLOSE_ONLY, OPEN_CLOSE_AT_TP, AT_TP);
-- tpIndex 0-3 = 1000/1500/2000/3000 (not used by Close); wsId 0 = Best (the engine's HIGHEST: the best closer when a
-- skillchain is open, otherwise the last weapon skill of the mate's list), else that weapon skill. A chosen weapon skill
-- the mate cannot use now (weapon, skill level, quest) is kept as saved; the mate then uses Best and the player is told
-- (once per call) and Gambits shows a warning. It applies again by itself when the mate can use it.
--
-- A Custom mate keeps its own setting: squad.lua's skillchainRoles and squad_chain.lua leave it alone (SQUAD_SC_ROLE
-- 1000 + mode), but a mate that closes (Close, Open + Close; Independent at its own TP) counts as a closer for them, and
-- the engine counts party members with TP as closers for a Custom opener (gambits_container.cpp PotentialCloserReady).
-- Needs the map server of the same batch (the new engine triggers): without it Custom is refused and acts as Squad default.
-- This file defines no globals; squad.lua and gambits_squad.lua load it with require.
-----------------------------------
local W = {}

W.VAR_PREFIX = 'SQUAD_WSC_'
W.TPS        = { 1000, 1500, 2000, 3000 }
W.MODES      = { OPEN = 1, CLOSE = 2, OPEN_CLOSE = 3, INDEPENDENT = 4 }
W.MODE_NAMES = { 'Open', 'Close', 'Open + Close', 'Independent' }
W.ROLE_BASE  = 1000   -- SQUAD_SC_ROLE of a Custom mate (the automatic roles are 1-3, !squad ws 100-130)
W.MAX_WS     = 4095
W.DEFAULTS   = { control = 0, mode = 3, tp = 1000, ws = 0 }

local function whole(v)
    return type(v) == 'number' and v == math.floor(v)
end

local function tpIndex(tp)
    for i, v in ipairs(W.TPS) do
        if v == tp then
            return i - 1
        end
    end

    return nil
end

-- the engine trigger of a mode (nil: this server's scripts/globals/gambits.lua does not have it)
function W.trigger(mode)
    local tp = ai and ai.tp
    if tp == nil then
        return nil
    end

    return ({ tp.OPEN_AT_TP, tp.CLOSE_ONLY, tp.OPEN_CLOSE_AT_TP, tp.AT_TP })[mode]
end

-- true when xi_map and gambits.lua have the batch's triggers (squad.cpp of the same build registers SquadApplyWeaponSkills)
function W.engineReady()
    return type(rawget(_G, 'SquadApplyWeaponSkills')) == 'function' and W.trigger(4) ~= nil
end

-- { control, mode, tp, ws } -> the char var value, or nil + why
function W.encode(s)
    if type(s) ~= 'table' then
        return nil, 'no setting'
    end

    local idx = tpIndex(s.tp)
    if s.control ~= 0 and s.control ~= 1 then
        return nil, 'control must be 0 (Squad default) or 1 (Custom)'
    elseif not whole(s.mode) or s.mode < 1 or s.mode > 4 then
        return nil, 'mode must be 1-4 (Open, Close, Open + Close, Independent)'
    elseif idx == nil then
        return nil, 'the TP threshold must be 1000, 1500, 2000 or 3000'
    elseif not whole(s.ws) or s.ws < 0 or s.ws > W.MAX_WS then
        return nil, 'the weapon skill must be 0 (Best) or a weapon skill id'
    end

    return 1 + s.control * 2 + s.mode * 4 + idx * 32 + s.ws * 128
end

-- the char var value -> { control, mode, tp, ws } | nil (no Gambits setting). A damaged value reads as Squad default.
function W.decode(v)
    if not whole(v) or v <= 0 or v % 2 ~= 1 then
        return nil
    end

    local control = math.floor(v / 2) % 2
    local mode    = math.floor(v / 4) % 8
    local idx     = math.floor(v / 32) % 4
    local ws      = math.floor(v / 128)
    if mode < 1 or mode > 4 or ws > W.MAX_WS then
        return { control = 0, mode = W.DEFAULTS.mode, tp = W.DEFAULTS.tp, ws = 0, damaged = true }
    end

    return { control = control, mode = mode, tp = W.TPS[idx + 1], ws = ws }
end

function W.varName(mateId, jobId)
    return string.format('%s%d_%d', W.VAR_PREFIX, mateId, jobId)
end

-- What applies to a mate in a job: { source = 'custom' | 'default' | 'legacy', control, mode, tp, ws, value,
-- legacyTp, legacyWs }. A Custom setting on a server without the batch's engine acts as Squad default (noEngine = true).
function W.resolve(player, mateId, jobId)
    local value = player:getCharVar(W.varName(mateId, jobId))
    local s = W.decode(value)
    local out = s or { control = W.DEFAULTS.control, mode = W.DEFAULTS.mode, tp = W.DEFAULTS.tp, ws = W.DEFAULTS.ws }
    out.value    = s and value or 0
    out.legacyTp = player:getCharVar('SQUAD_WSTP_' .. mateId)
    out.legacyWs = player:getCharVar('SQUAD_WS_' .. mateId)
    if s == nil then
        out.source = 'legacy'
    elseif s.control == 1 and W.engineReady() then
        out.source = 'custom'
    else
        out.source = 'default'
        out.noEngine = s.control == 1
    end

    return out
end

-- the weapon skill a call narrows the mate to (squad.cpp limitWeaponSkills: 0 = all)
function W.effectiveWs(s)
    if s.source == 'custom' then
        return s.ws
    elseif s.source == 'legacy' then
        return s.legacyWs
    end

    return 0
end

function W.spawnWs(player, mate)
    return W.effectiveWs(W.resolve(player, mate.id, mate.mjob))
end

-- the ids of the weapon skills a called mate can use now (nil: not known - the mate is not called, or an older server)
function W.usableIds(trust)
    local fn = rawget(_G, 'GetSquadWeaponSkillIds')
    if trust == nil or type(fn) ~= 'function' then
        return nil
    end

    local ok, list = pcall(fn, trust)
    if not ok or type(list) ~= 'table' then
        return nil
    end

    return list
end

-- true / false: the weapon skill is in the mate's list now; nil: cannot tell
function W.isUsable(trust, wsId)
    local list = W.usableIds(trust)
    if list == nil then
        return nil
    end

    for _, e in ipairs(list) do
        if e.id == wsId then
            return true
        end
    end

    return false
end

-- Puts a setting on a called mate: the local vars squad.lua and squad_chain.lua read, and (Custom) the engine's trigger.
-- The weapon skill list itself is set by the call (spawn) or by SquadApplyWeaponSkills (live apply).
function W.applyLocal(trust, s)
    trust:setLocalVar('SQUAD_WSC_WS', W.effectiveWs(s))
    if s.source == 'custom' then
        local closeTp = (s.mode == W.MODES.CLOSE or s.mode == W.MODES.OPEN_CLOSE) and 1000
            or (s.mode == W.MODES.INDEPENDENT and s.tp) or 0
        trust:setLocalVar('SQUAD_WSTP', 0)
        trust:setLocalVar('SQUAD_WSC', s.value)
        trust:setLocalVar('SQUAD_WSC_CLOSE_TP', closeTp)
        trust:setLocalVar('SQUAD_CH_MODE', 0)
        trust:setLocalVar('SQUAD_SC_ROLE', W.ROLE_BASE + s.mode)
        trust:setTrustTPSkillSettings(W.trigger(s.mode), ai.s.HIGHEST, s.tp)
        return
    end

    -- Squad default / !squad ws: what a fresh call has; squad.lua's skillchainRoles gives the role at its next run
    trust:setLocalVar('SQUAD_WSC', 0)
    trust:setLocalVar('SQUAD_WSC_CLOSE_TP', 0)
    trust:setLocalVar('SQUAD_WSTP', s.source == 'legacy' and s.legacyTp or 0)
end

-- tells the player once per call (not on every tick) that a chosen weapon skill cannot be used now
local function warnUnusable(player, trust, s)
    if s.source ~= 'custom' or s.ws == 0 then
        return
    end

    local usable = W.isUsable(trust, s.ws)
    local key = 'SQUAD_WSW_' .. trust:getLocalVar('SQUAD_ID')
    if usable == false then
        if player:getLocalVar(key) ~= s.ws then
            player:setLocalVar(key, s.ws)
            player:printToPlayer(string.format('%s cannot use the chosen weapon skill now (weapon, skill level or quest): '
                .. 'it uses its best one until it can. Your choice is kept.', trust:getPacketName()),
                (xi.msg and xi.msg.channel and xi.msg.channel.SYSTEM_3) or 0)
        end
    elseif usable == true then
        player:setLocalVar(key, 0)
    end
end

-- squad.lua, right after a mate was called
function W.onSpawn(player, trust, mate)
    local s = W.resolve(player, mate.id, mate.mjob)
    W.applyLocal(trust, s)
    pcall(warnUnusable, player, trust, s)
    return s
end

-- Gambits "Apply": the saved setting on the called mate now, without calling it again. Returns the resolved setting.
function W.liveApply(player, mate, trust)
    local s = W.resolve(player, mate.id, trust:getMainJob())
    local applyWs = rawget(_G, 'SquadApplyWeaponSkills')
    if type(applyWs) == 'function' then
        pcall(applyWs, trust, W.effectiveWs(s))
    end

    if s.source ~= 'custom' then
        -- back to what a fresh call has: the engine default, then the automatic roles (squad.lua) at their next run
        trust:setTrustTPSkillSettings(ai.tp.ASAP, ai.s.HIGHEST, 0)
        trust:setLocalVar('SQUAD_SC_ROLE', 0)
        trust:setLocalVar('SQUAD_CH_MODE', 0)
    end

    W.applyLocal(trust, s)
    player:setLocalVar('SQUAD_WSW_' .. mate.id, 0)
    pcall(warnUnusable, player, trust, s)
    return s
end

-- Does the called mate run the saved setting? true / false; nil = not called
function W.applied(player, mate, trust)
    if trust == nil then
        return nil
    end

    local s = W.resolve(player, mate.id, trust:getMainJob())
    if trust:getLocalVar('SQUAD_WSC_WS') ~= W.effectiveWs(s) then
        return false
    end

    if s.source == 'custom' then
        return trust:getLocalVar('SQUAD_WSC') == s.value
    end

    return trust:getLocalVar('SQUAD_WSC') == 0 and trust:getLocalVar('SQUAD_WSTP') == (s.source == 'legacy' and s.legacyTp or 0)
end

-- squad.lua !squad ws: the extra line when a Gambits setting for the mate's current job takes precedence
function W.legacyNote(player, mate)
    local s = W.resolve(player, mate.id, mate.mjob)
    if s.source == 'legacy' then
        return nil
    end

    return string.format('Note: %s\'s weapon skills as %s are set in Gambits (%s), which comes first. This !squad ws setting is '
        .. 'kept and used only for a job without a Gambits setting.', mate.name, mate.jobName or 'this job',
        s.source == 'custom' and 'Custom' or 'Squad default')
end

return W
