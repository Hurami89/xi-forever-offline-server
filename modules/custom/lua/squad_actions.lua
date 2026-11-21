-----------------------------------
-- Squad ACTIONS (Jon + Deed, 2026-11-21): the Squads window's "Actions OFF" button means OFF OFF for that one mate.
-- A mate whose four switches (melee, ranged, abilities, magic) are all off does NOTHING: no engaging, following, Thief tick (Sneak Attack),
-- eating or casting. The switch value is the only truth (`!squad sw <slot> all off|on`, or the Squads window button): this module
-- checks it every 2 seconds for every called mate, so a dismissed and recalled mate, or a restart, always matches what the window shows.
--   !actions   checks now and lists the slots that are off
-- Same flag as !idle (SQUAD_IDLE, read by the engine and by squad.lua), but per mate.
-- One init.txt line: custom/lua/squad_actions.lua
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('squad_actions')

SQUAD_ACTIONS = SQUAD_ACTIONS or {}
local A = SQUAD_ACTIONS
A.every = 2000

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

local function setOff(e, off)
    local was = e:getLocalVar('SQUAD_ACT_OFF') == 1
    if off then
        e:setLocalVar('SQUAD_IDLE', 1)
        pcall(function() e:setAutoAttackEnabled(false) end)
        pcall(function() e:setMagicCastingEnabled(false) end)
        if e:isEngaged() then
            pcall(function() e:disengage() end)
        end
    elseif was then
        e:setLocalVar('SQUAD_IDLE', 0)
        pcall(function() e:setAutoAttackEnabled(true) end)
        pcall(function() e:setMagicCastingEnabled(true) end)
    end

    e:setLocalVar('SQUAD_ACT_OFF', off and 1 or 0)
end

-- the truth is the stock switch value: "Actions OFF" = all four switches off (stored as mask + 1, so 1). Nothing else is remembered.
local function isOff(player, e)
    return tonumber(player:getCharVar('SQUAD_SW_' .. e:getLocalVar('SQUAD_ID'))) == 1
end

local function bardCheck(player, list)
    for _, e in ipairs(list) do
        if e:getMainJob() == 10 and e:getLocalVar('SQUAD_ACT_OFF') ~= 1 then
            if SQUAD_BARD_WALK ~= nil and SQUAD_BARD_WALK.ensure ~= nil then
                pcall(SQUAD_BARD_WALK.ensure, player)
            end

            return
        end
    end
end

local function pass(player)
    if player == nil then
        return
    end

    player:setLocalVar('SQUAD_ACT_RUN', os.time())
    local list = mates(player)
    for _, e in ipairs(list) do
        local off = isOff(player, e)
        local key = off and 1 or 2
        if e:getLocalVar('SQUAD_ACT_SEEN') ~= key then
            e:setLocalVar('SQUAD_ACT_SEEN', key)
            print(string.format('[actions] %s (slot %d): switches %s (raw %s)', e:getPacketName(), e:getLocalVar('SQUAD_ID'), off and 'ALL OFF -> stopped' or 'not all off -> released',
                tostring(player:getCharVar('SQUAD_SW_' .. e:getLocalVar('SQUAD_ID')))))
        end

        if off or e:getLocalVar('SQUAD_ACT_OFF') == 1 then
            setOff(e, off)
        end
    end

    if #list > 0 then
        bardCheck(player, list)
    end

    player:timer(A.every, pass)      -- keeps going with no mates out too, so a squad called later is caught within 2 seconds
end

function A.ensure(player)
    if os.time() - player:getLocalVar('SQUAD_ACT_RUN') > 3 then
        player:timer(100, pass)
    end
end

local function stamp(player)
    player:setLocalVar('SQUAD_ACT_RUN', os.time())
end

-- starts by itself when the player enters the game or a zone; `!actions` also starts it
m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)
    player:timer(4000, function(playerArg)
        A.ensure(playerArg)
    end)
end)

if xi ~= nil and xi.module ~= nil and xi.module.registerCommand ~= nil then
    pcall(function()
        local command = { cmdprops = { permission = 0, parameters = 's' } }
        command.onTrigger = function(player, arg)
            -- `!actions` (any text) only makes the server check the switches now and keep checking; the switches themselves are
            -- set by !squad sw <slot> all on|off, which the Squads window sends first.
            stamp(player)
            pass(player)
            local list = {}
            for _, e in ipairs(mates(player)) do
                if isOff(player, e) then list[#list + 1] = tostring(e:getLocalVar('SQUAD_ID')) end
            end

            player:printToPlayer('[actions] off (all four switches off): ' .. (#list > 0 and table.concat(list, ', ') or 'none'))
        end

        xi.module.registerCommand('actions', command)
    end)
end

return m
