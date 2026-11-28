-- squad.lua auto-equip: a piece that takes other slots away (rslot: a robe the head, Track Pants the feet) leaves them
-- empty and is never chosen over a locked piece in them (2026-11-27, R1PFake: a hat on a mate in a robe).
-- The real squadAutoEquip is cut out of squad.lua and run on stand-ins.   luajit test_squad_covered_slots.lua <server folder>
local SERVER = assert(arg[1], 'usage: test_squad_covered_slots.lua <server folder>')
local passed, failed = 0, 0
local function check(c, label) if c then passed = passed + 1 else failed = failed + 1 io.write('FAIL: ', label, '\n') end end
local f = assert(io.open(SERVER .. '/modules/custom/lua/squad.lua', 'rb')); local source = f:read('*a'); f:close()
local a = assert(source:find('function squadAutoEquip(player, mate)', 1, true))
local b = assert(source:find("-- (2026-11-19, from Jon Tanta's Squad Update) once a second", a, true))
local S = 2 ^ 4 -- slot bits: head 4, body 5, hands 6, legs 7, feet 8
local HEAD, BODY, HANDS, LEGS, FEET = 2 ^ 4, 2 ^ 5, 2 ^ 6, 2 ^ 7, 2 ^ 8
ITEMS, UNLOCKS, LOCKS, SET = {}, {}, 0, {}
function hasBit(mask, n) return math.floor((mask or 0) / (2 ^ n)) % 2 == 1 end
function levelsFor() return 50 end
function GetSquadUnlocks() return UNLOCKS end
function GetSquadItemInfo(id) return ITEMS[id] end
function squadAllGear() return false end
function squadGearLocks() return LOCKS end
function squadWeaponType() return 0, 0 end
function squadSubConflict() return nil end
function squadCanDualWield() return false end
SQUAD_TWO_HANDED = {}
function SetSquadEquip(id, job, slot, item) SET[slot] = item end
assert(loadstring(source:sub(a, b - 1), 'squadAutoEquip'))()
local function item(level, slot, rslot) return { valid = true, level = level, jobs = 0xFFFFFF, slot = slot, rslot = rslot } end
local function run(items, worn, locks)
    ITEMS, UNLOCKS, LOCKS, SET = items, {}, locks or 0, {}
    SQUAD_ITEM_INFO = {}       -- (auto-equip keeps what an item is for the whole run: each case has its own items)
    for id in pairs(items) do UNLOCKS[id] = true end
    local mate = { id = 1, mjob = 4, equip = { [4] = worn or {} } }
    squadAutoEquip({ getID = function() return 1 end }, mate)
    return mate.equip[4]
end

-- a robe (covers the head) and a hat: the robe is the better body, so no hat
local e = run({ [100] = item(40, BODY, HEAD), [200] = item(45, HEAD, 0), [300] = item(30, HANDS, 0) })
check(e[5] == 100 and e[4] == nil and e[6] == 300, 'a robe that covers the head: no hat beside it (hands still chosen)')
-- the same without rslot (an xi_map that does not send it): as before, both
e = run({ [100] = item(40, BODY, nil), [200] = item(45, HEAD, 0) })
check(e[5] == 100 and e[4] == 200, 'no rslot sent: hat and robe as before')
-- Track Pants (cover the feet) and boots
e = run({ [10] = item(1, LEGS, FEET), [11] = item(20, FEET, 0) })
check(e[7] == 10 and e[8] == nil, 'pants that cover the feet: no boots')
-- a hat locked on: a robe is never chosen, the best plain body is
e = run({ [100] = item(40, BODY, HEAD), [101] = item(20, BODY, 0), [200] = item(45, HEAD, 0) }, { [4] = 200 }, 2 ^ 4)
check(e[4] == 200 and e[5] == 101, 'a locked hat: the robe is passed over for a body that leaves the head free')
-- a locked robe: the head stays empty even with a hat to give
e = run({ [100] = item(40, BODY, HEAD), [200] = item(45, HEAD, 0) }, { [5] = 100 }, 2 ^ 5)
check(e[5] == 100 and e[4] == nil, 'a locked robe: no hat is put on')
-- a robe worn with a hat from before the fix: the hat comes off
e = run({ [100] = item(40, BODY, HEAD), [200] = item(45, HEAD, 0) }, { [4] = 200, [5] = 100 })
check(e[5] == 100 and e[4] == nil and SET[4] == 0, 'an old hat under a robe is taken off')
io.write(string.format('passed %d, failed %d\n', passed, failed))
os.exit(failed == 0 and 0 or 1)
