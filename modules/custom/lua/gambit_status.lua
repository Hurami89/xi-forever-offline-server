-----------------------------------
-- !gambit status <entity id> <nonce>
-- Answers the Gambits addon (dualbox character) with the status effects of one of its party members,
-- so it can see buffs on squad mates and Trusts (the game client only shows buffs of real players).
-- Reply (hidden by the addon): TGST|nonce|targetId|zone|dispellable(0/1/!)|maxMP|id,id,... or '-' or '!'
-- Only party/alliance members in the same zone are answered; anything else gets '!' (unknown).
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('gambit_status')

local function channel()
    return (xi.msg and xi.msg.channel and xi.msg.channel.SYSTEM_3) or 0
end

local function findMember(player, targetId)
    if player:getID() == targetId then
        return player
    end

    for _, member in pairs(player:getPartyWithTrusts()) do
        if member:getID() == targetId and member:getZoneID() == player:getZoneID() then
            return member
        end
    end

    for _, member in pairs(player:getAlliance()) do
        if member:getID() == targetId and member:getZoneID() == player:getZoneID() then
            return member
        end
    end

    return nil
end

local command = {}
command.cmdprops = { permission = 0, parameters = 'sss' }

command.onTrigger = function(player, action, targetArg, nonceArg)
    if action ~= 'status' then
        return
    end

    local targetId = tonumber(targetArg)
    local nonce    = tonumber(nonceArg)
    if targetId == nil or nonce == nil then
        return
    end

    local zoneId = player:getZoneID()
    local member = findMember(player, targetId)
    if member == nil or not member:isAlive() then
        player:printToPlayer(string.format('TGST|%d|%d|%d|!|0|!', nonce, targetId, zoneId), channel())
        return
    end

    local ids = {}
    for _, effect in pairs(member:getStatusEffects() or {}) do
        local id = effect:getEffectType()
        if id ~= nil and id > 0 and id < 1023 and #ids < 32 then
            ids[#ids + 1] = tostring(id)
        end
    end

    local payload = #ids > 0 and table.concat(ids, ',') or '-'
    player:printToPlayer(string.format('TGST|%d|%d|%d|0|%d|%s', nonce, targetId, zoneId, member:getMaxMP(), payload), channel())
end

xi.module.registerCommand('gambit', command)

return m
