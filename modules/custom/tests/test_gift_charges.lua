-- late/gift_charges.lua: a gift item that !deliverybox left without charges is swapped for a new one at log in
-- (2026-11-27, Quaiton: his Forever Track Pants showed <0/1>).
-- The file is loaded the way the map server loads a module file (the real modules/module_utils.lua), its override is
-- put on xi.player.onGameIn the way the loader does it, and stand-in players log in with stand-in bags.
-- No server, no database; nothing is written.
--   luajit test_gift_charges.lua <server folder>
local SERVER = arg[1]
assert(SERVER, 'usage: test_gift_charges.lua <server folder>')

local passed, failed = 0, 0
local function check(c, label) if c then passed = passed + 1 else failed = failed + 1 io.write('FAIL: ', label, '\n') end end
local function section(n) io.write('\n== ', n, '\n') end

package.path = SERVER .. '/?.lua;' .. package.path
xi    = { settings = { main = { RESTRICT_CONTENT = 1 } }, msg = { channel = { SYSTEM_3 = 29 } } }
utils = { splitStr = function() return {} end }

assert(loadfile(SERVER .. '/modules/module_utils.lua'))()                       -- as the loader does first
package.loaded['modules/module_utils'] = true                                   -- the file's own require
assert(loadfile(SERVER .. '/modules/custom/late/gift_charges.lua'))()

section('what the file registers')
check(#xi.module.registry == 1 and #xi.module.commandRegistry == 0, 'one module, no command')
local module = xi.module.registry[1]
check(module.name == 'gift_charges' and module.enabled == true, 'it is switched on')
check(#module.overrides == 1 and module.overrides[1].name == 'xi.player.onGameIn' and module.overrides[1].enabled == true,
    'one override, on xi.player.onGameIn (log in)')

local superCalls = 0
xi.player = { onGameIn = function() superCalls = superCalls + 1 return 'from the game' end }
applyOverride(xi.player, 'onGameIn', module.overrides[1].func, 'xi.player.onGameIn', 'gift_charges.lua')

local SHIRT, PATCH, PANTS, CUDGEL = 25725, 23867, 23868, 17040
local FULL = { [SHIRT] = 5, [PATCH] = 5, [PANTS] = 1, [CUDGEL] = 30 }
local INVENTORY, WARDROBE = 0, 8

-- an item's data as the server keeps it: 24 bytes, 0-indexed. Byte 1 = charges left, bytes 4-7 = time of the last use
local function data(charges, lastUse, signed)
    local d = {}
    for i = 0, 23 do d[i] = 0 end
    d[1] = charges
    if lastUse then d[4], d[5], d[6], d[7] = 0x10, 0x32, 0x54, 0x06 end
    if signed then d[12], d[13] = 0x41, 0x42 end
    return d
end
local function newItem(id, where, slot, d, wornIn)
    local it = { id = id, where = where, slot = slot, data = d, wornIn = wornIn, alive = true }
    function it:getID() assert(self.alive, 'an item that was removed is still being read') return self.id end
    function it:getLocationID() assert(self.alive, 'an item that was removed is still being read') return self.where end
    function it:getSlotID() assert(self.alive, 'an item that was removed is still being read') return self.slot end
    function it:getCurrentCharges() assert(self.alive, 'an item that was removed is still being read') return self.data[1] end
    function it:getExDataRaw() assert(self.alive, 'an item that was removed is still being read') local c = {} for i = 0, 23 do c[i] = self.data[i] end return c end
    return it
end
local function emptyItem(id, where, slot, wornIn) return newItem(id, where, slot, data(0, false), wornIn) end

local function newPlayer(items, o)
    local p = { items = items or {}, said = {}, calls = {}, boxed = {}, free = 5, bot = 0, pc = true, name = 'Tester', delFails = false }
    for k, v in pairs(o or {}) do p[k] = v end
    function p:isPC() return self.pc end
    function p:getName() return self.name end
    function p:getCharVar(name) if name == '[Bot]Started' then return self.bot end return 0 end
    function p:findItems(id)
        local out = {}
        for _, it in ipairs(self.items) do if it.alive and it.id == id then out[#out + 1] = it end end
        return out
    end
    function p:getEquippedItem(equipSlot)
        for _, it in ipairs(self.items) do if it.alive and it.wornIn == equipSlot then return it end end
        return nil
    end
    function p:unequipItem(equipSlot)
        self.calls[#self.calls + 1] = 'unequip ' .. equipSlot
        for _, it in ipairs(self.items) do if it.wornIn == equipSlot then it.wornIn = nil end end
    end
    function p:delItemAt(id, quantity, where, slot)
        self.calls[#self.calls + 1] = string.format('del %d x%d at %d/%d', id, quantity, where, slot)
        if self.delFails then return false end
        for _, it in ipairs(self.items) do
            if it.alive and it.id == id and it.where == where and it.slot == slot then
                if it.wornIn ~= nil then return false end          -- the game does not take a worn item
                it.alive = false
                if where == INVENTORY then self.free = self.free + 1 end
                return true
            end
        end
        return false
    end
    function p:addItem(id)
        self.calls[#self.calls + 1] = 'add ' .. tostring(id)
        if self.free <= 0 then return nil end
        self.free = self.free - 1
        local it = newItem(id, INVENTORY, 70 + #self.items, data(FULL[id], false))
        self.items[#self.items + 1] = it
        return it
    end
    function p:printToPlayer(text, channel) self.said[#self.said + 1] = text self.channel = channel end
    return p
end
local sent = {}
SendItemToDeliveryBox = function(name, id, quantity, sender) sent[#sent + 1] = { name, id, quantity, sender } return 0 end

local function login(p, zoning) return xi.player.onGameIn(p, false, zoning or false) end
local function holds(p, id)
    local out = {}
    for _, it in ipairs(p.items) do if it.alive and it.id == id then out[#out + 1] = it end end
    return out
end
local function did(p, what) for _, c in ipairs(p.calls) do if c == what then return true end end return false end

section('the pants !deliverybox emptied')
do
    local p = newPlayer({ emptyItem(PANTS, INVENTORY, 12) })
    local result = login(p)
    local now = holds(p, PANTS)
    check(#now == 1 and now[1].data[1] == 1, 'one pair afterwards, with its charge (<1/1>)')
    check(did(p, 'del 23868 x1 at 0/12') and did(p, 'add 23868'), 'the old pair removed from its own place, a new one added')
    check(#p.said == 1 and p.said[1] == 'A bug in !deliverybox had left your Forever Track Pants without charges. Here is a new one.' and p.channel == 29,
        'the line: ' .. tostring(p.said[1]))
    check(result == 'from the game', 'the game\'s own answer is passed on')
    login(p)
    login(p)
    check(#holds(p, PANTS) == 1 and #p.said == 1, 'later log ins: nothing more')
end

section('what is left alone')
do
    local p = newPlayer({ newItem(PANTS, INVENTORY, 3, data(1, false)) })
    login(p)
    check(#p.calls == 0 and #p.said == 0, 'pants with their charge, never used: untouched')
    p = newPlayer({ newItem(PANTS, INVENTORY, 3, data(1, true)) })
    login(p)
    check(#p.calls == 0, 'pants with their charge, used before: untouched')
    p = newPlayer({ newItem(PATCH, INVENTORY, 4, data(0, true)) })
    login(p)
    check(#p.calls == 0 and #p.said == 0 and #holds(p, PATCH) == 1, 'a patch that was really used up (no charges, but a last use): stays used up')
    p = newPlayer({ newItem(SHIRT, WARDROBE, 9, data(3, true)) })
    login(p)
    check(#p.calls == 0, 'a shirt with three charges left: untouched')
    p = newPlayer({ emptyItem(CUDGEL, INVENTORY, 20) })
    login(p)
    check(#p.calls == 0 and #p.said == 0, 'another charged item with empty data: not one of the three gifts, untouched')
    p = newPlayer({})
    login(p)
    check(#p.calls == 0 and #p.said == 0, 'no gift at all: nothing')
    -- the charges are asked for on their own as well: should the raw item data ever come back empty, an item that
    -- still has charges must not be taken for an emptied one (it would be swapped at every log in)
    local blind = newItem(PATCH, INVENTORY, 4, data(4, true))
    function blind:getExDataRaw() return {} end
    p = newPlayer({ blind })
    login(p)
    check(#p.calls == 0 and #p.said == 0, 'a patch with charges whose item data cannot be read: untouched')
end

section('the shirt and the patch too, and both at once')
do
    local p = newPlayer({ emptyItem(SHIRT, INVENTORY, 1), emptyItem(PATCH, INVENTORY, 2), newItem(PANTS, INVENTORY, 3, data(1, false)) })
    login(p)
    check(#holds(p, SHIRT) == 1 and holds(p, SHIRT)[1].data[1] == 5, 'the shirt: a new one with 5 charges')
    check(#holds(p, PATCH) == 1 and holds(p, PATCH)[1].data[1] == 5, 'the patch: a new one with 5 charges')
    check(#holds(p, PANTS) == 1 and holds(p, PANTS)[1].slot == 3, 'the pants that were fine are the same pair as before')
    check(#p.said == 1 and p.said[1] == 'A bug in !deliverybox had left your Forever Beta Shirt and your Forever Patch without charges. Here are new ones.',
        'one line for both: ' .. tostring(p.said[1]))
end

section('worn, in another bag, a full inventory')
do
    local p = newPlayer({ emptyItem(PANTS, WARDROBE, 7, 7) })           -- worn on the legs (equipment slot 7), kept in a wardrobe
    login(p)
    check(did(p, 'unequip 7') and did(p, 'del 23868 x1 at 8/7'), 'a worn pair is taken off first, then removed from the wardrobe')
    check(#holds(p, PANTS) == 1 and holds(p, PANTS)[1].where == INVENTORY and holds(p, PANTS)[1].data[1] == 1, 'the new pair is in the inventory')
    local unequipAt, delAt
    for i, c in ipairs(p.calls) do if c == 'unequip 7' then unequipAt = i elseif c:find('^del ') then delAt = i end end
    check(unequipAt ~= nil and delAt ~= nil and unequipAt < delAt, 'taken off before it is removed')

    p = newPlayer({ emptyItem(PANTS, WARDROBE, 7), newItem(SHIRT, INVENTORY, 1, data(5, false), 5) })
    login(p)
    check(not did(p, 'unequip 5') and not did(p, 'unequip 7'), 'nothing else that is worn is taken off')

    sent = {}
    p = newPlayer({ emptyItem(PATCH, WARDROBE, 4) }, { free = 0 })
    login(p)
    check(#holds(p, PATCH) == 0 and #sent == 1 and sent[1][1] == 'Tester' and sent[1][2] == PATCH and sent[1][3] == 1,
        'inventory full, the patch was in a wardrobe: the new one goes to the delivery box')
    check(#p.said == 1 and p.said[1]:find('Your inventory is full: look in your delivery box.', 1, true) ~= nil, 'and the line says so: ' .. tostring(p.said[1]))

    sent = {}
    p = newPlayer({ emptyItem(PANTS, INVENTORY, 12) }, { free = 0 })
    login(p)
    check(#holds(p, PANTS) == 1 and #sent == 0, 'inventory full, the pair was in it: its own place is free again, the new pair goes there')

    sent = {}
    p = newPlayer({ emptyItem(PANTS, INVENTORY, 12) }, { delFails = true })
    login(p)
    check(#holds(p, PANTS) == 1 and holds(p, PANTS)[1].data[1] == 0 and not did(p, 'add 23868') and #sent == 0 and #p.said == 0,
        'the game refuses to remove it: nothing is added, nothing is said (never two pairs)')
end

section('only what was emptied: a signature does not count as use')
do
    local p = newPlayer({ newItem(PANTS, INVENTORY, 12, data(0, false, true)) })
    login(p)
    check(#holds(p, PANTS) == 1 and holds(p, PANTS)[1].data[1] == 1, 'no charges, no last use, only a signature: mended')
end

section('only at log in, only for players, never a bot')
do
    local before = superCalls
    local p = newPlayer({ emptyItem(PANTS, INVENTORY, 12) })
    local result = login(p, true)
    check(#p.calls == 0 and result == 'from the game' and superCalls == before + 1, 'changing areas (zoning): nothing, the game\'s own function ran')
    p = newPlayer({ emptyItem(PANTS, INVENTORY, 12) }, { bot = 1 })
    login(p)
    check(#p.calls == 0, 'a bot player: nothing')
    p = newPlayer({ emptyItem(PANTS, INVENTORY, 12) }, { pc = false })
    login(p)
    check(#p.calls == 0, 'not a player: nothing')
    check(pcall(xi.player.onGameIn, nil, false, false) == true, 'no player at all: no error')
end

section('a mistake inside never breaks the log in of the other modules')
do
    local p = newPlayer({ emptyItem(PANTS, INVENTORY, 12) })
    function p:findItems() error('the bags are away') end
    local realPrint, printed = print, {}
    print = function(...) printed[#printed + 1] = table.concat({ ... }, ' ') end
    local ok, result = pcall(xi.player.onGameIn, p, false, false)
    print = realPrint
    check(ok and result == 'from the game', 'an error while reading the bags: the log in goes on, the game\'s answer is passed on')
    check(#printed == 1 and printed[1]:find('[gift_charges]', 1, true) ~= nil and printed[1]:find('the bags are away', 1, true) ~= nil,
        'and the map log gets one line with the reason')
end

io.write(string.format('\n%d passed, %d failed\n', passed, failed))
os.exit(failed == 0 and 0 or 1)
