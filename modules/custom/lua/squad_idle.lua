-----------------------------------
-- Squad IDLE (Jon + Deed, 2026-11-21): ONE switch that stops every squad mate.
--   !idle on    every mate: no engaging, following or range keeping (the engine reads SQUAD_IDLE, see trust_controller.cpp),
--               it lets go of the fight and its auto attack is off. New mates called while it is on are stopped too.
--   !idle off   everything back to Hurami's stock behavior
--   !idle       says which it is
-- What it does NOT touch: spells and abilities from Gambits (the per-mate switches decide those: !squad sw <slot> all off,
-- then dismiss and call again). Needs the xi_map.exe built with squad_idle_engine.patch; without it only the disengage and the
-- auto attack part work.
-- One init.txt line: custom/lua/squad_idle.lua
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('squad_idle')

SQUAD_IDLE_MOD = SQUAD_IDLE_MOD or {}
local I = SQUAD_IDLE_MOD
I.every = 2000 -- ms between passes while it is on

local function mates(player)
    local out = {}
    local ok, party = pcall(function() return player:getPartyWithTrusts() end)
    for _, e in pairs(ok and party or {}) do
        if e:getObjType() == xi.objType.TRUST and e:getLocalVar('SQUAD_ID') ~= 0 then
            out[#out + 1] = e
        end
    end

    return out
end

local function apply(player, on)
    for _, e in ipairs(mates(player)) do
        if on then
            e:setLocalVar('SQUAD_IDLE', 1)
            pcall(function() e:setAutoAttackEnabled(false) end)
            if e:isEngaged() then
                pcall(function() e:disengage() end)
            end
        elseif e:getLocalVar('SQUAD_IDLE') ~= 0 then
            e:setLocalVar('SQUAD_IDLE', 0)
            pcall(function() e:setAutoAttackEnabled(true) end)
        end
    end
end

local function pass(player)
    if player == nil or player:getCharVar('SQUAD_IDLE_ALL') ~= 1 then
        return
    end

    player:setLocalVar('SQUAD_IDLE_RUN', os.time())
    apply(player, true)
    player:timer(I.every, pass)
end

-- (2026-11-21, Hurami) !idle on outlives a zone change: the check starts again when you arrive, so mates called back
-- after zoning are stopped too (the timestamp keeps it to one running check)
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    if player:getCharVar('SQUAD_IDLE_ALL') == 1 then
        player:timer(4000, function(playerArg)
            if playerArg ~= nil and os.time() - playerArg:getLocalVar('SQUAD_IDLE_RUN') > 3 then
                pass(playerArg)
            end
        end)
    end
end)

if xi ~= nil and xi.module ~= nil and xi.module.registerCommand ~= nil then
    pcall(function()
        local command = { cmdprops = { permission = 0, parameters = 's' } }
        command.onTrigger = function(player, arg)
            local word = string.lower(string.match(tostring(arg or ''), '^%s*(%S*)') or '')
            if word == 'on' then
                player:setCharVar('SQUAD_IDLE_ALL', 1)
                apply(player, true)
                player:timer(I.every, pass)
                player:printToPlayer('[idle] ON: the squad does nothing until you say !idle off')
            elseif word == 'off' then
                player:setCharVar('SQUAD_IDLE_ALL', 0)
                apply(player, false)
                player:printToPlayer('[idle] OFF: the squad acts as usual again')
            else
                player:printToPlayer('[idle] ' .. (player:getCharVar('SQUAD_IDLE_ALL') == 1 and 'ON' or 'off') .. '   (!idle on | !idle off)')
            end
        end

        xi.module.registerCommand('idle', command)
    end)
end

return m
