-----------------------------------
-- XI: Forever Offline: the Warp Ring for conquest points (2026-11-23, Yumainai; the user: yes, as an option)
--
-- The Conquest Overseers' list is drawn by the game client from its own files, and our era files have no Warp Ring
-- on it. With main.CONQUEST_WARP_RING = 1 (the launcher's "Warp Ring for conquest points", off by default) an
-- overseer in your nation's towns first asks: the Warp Ring for WARP_RING_CP conquest points, or the usual list.
-- One Warp Ring at a time (it is Rare).
-----------------------------------
require('modules/module_utils')
require('scripts/globals/conquest')
-----------------------------------
local function on()
    local v = xi.settings and xi.settings.main and xi.settings.main.CONQUEST_WARP_RING
    return v == true or (type(v) == 'number' and v ~= 0)
end

local m = Module:new('xifo_warp_ring', on())

local WARP_RING    = 28540
local WARP_RING_CP = 5000

local function commas(n)
    local s = tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return (s:gsub('^,', ''))
end

local function buy(player)
    if player:hasItem(WARP_RING) then
        player:printToPlayer('You already have a Warp Ring.', xi.msg.channel.SYSTEM_3)
    elseif player:getCP() < WARP_RING_CP then
        player:printToPlayer(string.format('The Warp Ring costs %s conquest points and you have %s.', commas(WARP_RING_CP), commas(player:getCP())),
            xi.msg.channel.SYSTEM_3)
    elseif player:getFreeSlotsCount() == 0 then
        player:printToPlayer('Your inventory is full.', xi.msg.channel.SYSTEM_3)
    else
        player:delCP(WARP_RING_CP)
        player:addItem(WARP_RING)
        player:messageSpecial(zones[player:getZoneID()].text.ITEM_OBTAINED, WARP_RING)
    end
end

m:addOverride('xi.conquest.overseerOnTrigger', function(player, npc, guardNation, guardType, guardEvent, guardRegion)
    -- only your own nation's town guards, and not while a garrison or expeditionary force talk needs the guard
    if guardNation ~= player:getNation() or guardType > xi.conquest.guard.FOREIGN or player:getLocalVar('[WarpRing]Usual') == 1 then
        player:setLocalVar('[WarpRing]Usual', 0)
        return super(player, npc, guardNation, guardType, guardEvent, guardRegion)
    end

    player:setFreezeFlag(true)
    player:customMenu({
        title = string.format('Conquest points: %s', commas(player:getCP())),
        options =
        {
            { string.format('Warp Ring - %s points', commas(WARP_RING_CP)), function(playerArg)
                buy(playerArg)
            end },
            { 'The usual list.', function(playerArg)
                playerArg:timer(250, function(entity)
                    entity:setLocalVar('[WarpRing]Usual', 1)
                    xi.conquest.overseerOnTrigger(entity, npc, guardNation, guardType, guardEvent, guardRegion)
                end)
            end },
        },
        onCancelled = function(playerArg)
            playerArg:setFreezeFlag(false)
        end,
        onEnd = function(playerArg)
            playerArg:setFreezeFlag(false)
        end,
    })
end)

return m
