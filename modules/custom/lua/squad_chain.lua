-----------------------------------
-- Squad CHAIN: the skillchain wait (from Jon Tanta's Squad Update, 2026-11-19; merged into XI: Forever Offline).
-- squadTeamTick (squad.lua) calls SQUAD_CHAIN.tick every second per mate. Lines are printed as "[chain] ..." when C.debug is on.
-- Tune live: SQUAD_CHAIN.chain.on = false (off)
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('squad_chain')

SQUAD_CHAIN = SQUAD_CHAIN or {}
local C = SQUAD_CHAIN
C.debug = false

local print = function(text)
    if C.debug then
        _G.print(text)
    end
end

-- Skillchain timing. squad.lua gives the melee mates roles (SQUAD_SC_ROLE: 1 opener, 2 closer): the opener weapon skills at 1000 TP and the
-- closers close inside the window. That fails when the closers have no TP yet: the window passes and the opener's skill is wasted. So the
-- opener waits (holds its TP) until at least C.chain.need closer has 1000 TP, then opens; it goes anyway at 2200 TP or after C.chain.maxWait
-- seconds at 1000 TP, so nobody waits forever. Lines: "[chain] ...". Tune live: SQUAD_ADAPT.chain.maxWait = 8, SQUAD_ADAPT.chain.on = false
C.chain = C.chain or { on = true, need = 1, maxWait = 12, hold = 3000, force = 2200 }
-- 2026-11-19: the opener no longer opens on a timer or at a TP of its own: it opens when a closer has the TP, and only goes alone at a full 3000 TP
C.chain.maxWait = 600
C.chain.force = 3000

local function chainTick(mob, boss, fighting, now)
    if not C.chain.on or mob:getLocalVar('SQUAD_SC_ROLE') ~= 1 or not fighting then
        if mob:getLocalVar('SQUAD_CH_MODE') ~= 0 and mob:getLocalVar('SQUAD_SC_ROLE') ~= 1 then
            mob:setLocalVar('SQUAD_CH_MODE', 0)
        end

        if not fighting then
            mob:setLocalVar('SQUAD_CH_RDY', 0)
        end

        return
    end

    local ready, closers = 0, 0
    for _, m in pairs(boss:getPartyWithTrusts() or {}) do
        if m:getID() ~= mob:getID() and m:getObjType() == xi.objType.TRUST and m:isAlive() and m:getLocalVar('SQUAD_SC_ROLE') == 2 then
            closers = closers + 1
            if m:getTP() >= 1000 then
                ready = ready + 1
            end
        end
    end

    if closers == 0 then
        return
    end

    local tp = mob:getTP()
    local rdy = mob:getLocalVar('SQUAD_CH_RDY')
    if tp >= 1000 and rdy == 0 then
        rdy = now
        mob:setLocalVar('SQUAD_CH_RDY', now)
    elseif tp < 1000 then
        rdy = 0
        mob:setLocalVar('SQUAD_CH_RDY', 0)
    end

    -- mode: 1 = hold the TP, 2 = open (0 = the roles' own setting, which is open)
    local want = 1
    if tp >= 1000 and (ready >= C.chain.need or tp >= C.chain.force or now - rdy >= C.chain.maxWait) then
        want = 2
    end

    local mode = mob:getLocalVar('SQUAD_CH_MODE')
    if want == 1 and tp >= 1000 and rdy == now and mob:getLocalVar('SQUAD_CH_SAID') ~= now then
        mob:setLocalVar('SQUAD_CH_SAID', now)
        print(string.format('[chain] %s has %d TP and waits for a closer (%d of %d have 1000 TP)', mob:getPacketName(), tp, ready, closers))
    end

    -- 2026-11-19: a Thief goes through her macro first (behind the foe, Sneak Attack, then the weapon skill is let go): squadThfPrime
    local thief = (mob:getMainJob() == 6 or mob:getSubJob() == 6) and squadThfPrime ~= nil
    if want == mode or (want == 2 and mode == 0 and not thief) then
        return
    end

    if want == 2 and thief then
        local okP, res = pcall(squadThfPrime, mob)
        if okP and res == 'wait' then
            return -- (still holding her TP: getting behind the foe)
        end
    end

    mob:setLocalVar('SQUAD_CH_MODE', want)
    pcall(function()
        if want == 1 then
            mob:setTrustTPSkillSettings(ai.tp.CLOSER_UNTIL_TP, ai.s.HIGHEST, C.chain.hold)
        else
            mob:setTrustTPSkillSettings(ai.tp.OPENER, ai.s.HIGHEST, 1000)
        end
    end)

    if want == 2 then
        print(string.format('[chain] %s opens at %d TP (%d of %d closers have 1000 TP)', mob:getPacketName(), tp, ready, closers))
    elseif tp >= 1000 or mode ~= 0 then
        print(string.format('[chain] %s holds its weapon skill for the closers (%d of %d have 1000 TP)', mob:getPacketName(), ready, closers))
    end
end


C.tick = function(mob, boss, foe, fighting, now)
    chainTick(mob, boss, fighting, now)
end

return m
