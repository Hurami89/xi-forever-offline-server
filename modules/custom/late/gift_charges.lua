-----------------------------------
-- Gift items that lost their charges to !deliverybox (XI: Forever Offline, 2026-11-27)
--
-- Quaiton: "timer was unuseable when i got them": his Forever Track Pants showed <0/1>.
--
-- !deliverybox handed a charged item over with no charges when the delivery box entry carried no item data of its
-- own, which is every entry the server makes itself: the gifts, an auction house purchase. (custom/cpp/
-- delivery_take.cpp copied an empty block over the new item's own data; taken by hand, the game leaves a new item as
-- it is.) That file is corrected, which takes a new map server; this file mends what it had already done.
-- An item that went through it has nothing in its item data: no charges and no time of a last use. One that was
-- really used up still has the time of its last use. So at log in, a gift (Forever Beta Shirt, Forever Patch, Forever
-- Track Pants) with no charges and no last use is swapped for a new one: taken off if it is worn, removed, and a new
-- one put in the inventory, or sent to the delivery box when the inventory is full. Nothing else is touched.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('gift_charges')

local gifts =
{
    { 25725, 'Forever Beta Shirt' },
    { 23867, 'Forever Patch' },
    { 23868, 'Forever Track Pants' },
}

-- the first twelve bytes of an item's data: its charges, flags and the time of its last use (after them comes a
-- crafter's signature, which says nothing about use)
local TIMER_BYTES = 12

local function emptied(item)
    if item:getCurrentCharges() ~= 0 then
        return false
    end

    local data = item:getExDataRaw()
    for index = 0, TIMER_BYTES - 1 do
        if (data[index] or 0) ~= 0 then
            return false
        end
    end

    return true
end

local function takeOff(player, id, where, slot)
    for equipSlot = 0, 15 do
        local worn = player:getEquippedItem(equipSlot)
        if worn ~= nil and worn:getID() == id and worn:getLocationID() == where and worn:getSlotID() == slot then
            player:unequipItem(equipSlot)
        end
    end
end

local function mend(player)
    local mended, boxed = {}, false
    for _, gift in ipairs(gifts) do
        local id, name = gift[1], gift[2]
        for _, item in pairs(player:findItems(id)) do
            if emptied(item) then
                local where, slot = item:getLocationID(), item:getSlotID()
                takeOff(player, id, where, slot)
                if player:delItemAt(id, 1, where, slot) then
                    if player:addItem(id) == nil then
                        SendItemToDeliveryBox(player:getName(), id, 1, 'Forever Offline')
                        boxed = true
                    end

                    mended[#mended + 1] = name
                end
            end
        end
    end

    if #mended > 0 then
        local text = 'A bug in !deliverybox had left your ' .. table.concat(mended, ' and your ') .. ' without charges. ' ..
            (#mended == 1 and 'Here is a new one.' or 'Here are new ones.')
        if boxed then
            text = text .. ' Your inventory is full: look in your delivery box.'
        end

        player:printToPlayer(text, xi.msg.channel.SYSTEM_3)
    end
end

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    local result = super(player, firstLogin, zoning)

    if zoning or not player or not player:isPC() or player:getCharVar('[Bot]Started') ~= 0 then
        return result
    end

    -- a mistake here must never break what the other modules do at log in
    local ok, err = pcall(mend, player)
    if not ok then
        print('[gift_charges] ' .. tostring(err))
    end

    return result
end)

return m
