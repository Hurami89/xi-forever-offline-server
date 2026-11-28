-- late/drop_subjob.lua: !dropsub, a Randomized character's support job off for a while (2026-11-27).
-- The file is loaded the way the map server loads a module file (with the real modules/module_utils.lua and the real
-- enum files), then the command is run on stand-in players. No server, no database; nothing is written.
--   luajit test_drop_subjob.lua <server folder>
local SERVER = arg[1]
assert(SERVER, 'usage: test_drop_subjob.lua <server folder>')

local passed, failed = 0, 0
local function check(c, label) if c then passed = passed + 1 else failed = failed + 1 io.write('FAIL: ', label, '\n') end end
local function section(n) io.write('\n== ', n, '\n') end

package.path = SERVER .. '/?.lua;' .. package.path
xi    = { settings = { main = { RESTRICT_CONTENT = 1 } }, msg = { channel = { SYSTEM_3 = 29 } } }
utils = { splitStr = function() return {} end }
for _, name in ipairs({ 'job.codegen', 'job_name', 'slot', 'trait', 'skill.codegen', 'mog_house.codegen', 'zone_misc.codegen' }) do
    assert(loadfile(SERVER .. '/scripts/enum/' .. name .. '.lua'))()
end

assert(loadfile(SERVER .. '/modules/module_utils.lua'))()                       -- as the loader does first
package.loaded['modules/module_utils'] = true                                   -- the file's own require
assert(loadfile(SERVER .. '/modules/custom/late/drop_subjob.lua'))()

section('what the file registers')
check(#xi.module.registry == 0, 'no module without overrides (that is an error line at every server start)')
check(#xi.module.commandRegistry == 1 and xi.module.commandRegistry[1].name == 'dropsub', 'one command, !dropsub')
local command = xi.module.commandRegistry[1].command
check(command.cmdprops.permission == 0 and command.cmdprops.parameters == 's', 'every player may use it (permission 0), with one word after it')
check(xi.job.NONE == 0 and xi.slot.SUB == 1 and xi.zoneMisc.MOGMENU == 0x20 and xi.mogHouse.OWN == 1 and xi.trait.DUAL_WIELD == 18,
    'the enum values the file uses are the server\'s')

-- a stand-in player. Dual Wield: Ninja 10+ as main job, or as support job at half the main level, as in the game.
local RANDOM = 4
xi.hardcore = { RANDOM = RANDOM, mode = function(p) return p.mode end }
local function newPlayer(o)
    local p = { mode = RANDOM, main = xi.job.WAR, mainLvl = 30, sub = xi.job.MNK, subLvl = 15, ownHouse = true, anyHouse = true,
                nomad = false, pet = false, off = nil, said = {}, calls = {}, unlockedSupport = true }
    for k, v in pairs(o or {}) do p[k] = v end
    function p:getSubJob() return self.sub end
    function p:getMainJob() return self.main end
    function p:inMogHouse(kind) if kind == xi.mogHouse.OWN then return self.ownHouse end return self.anyHouse end
    function p:canUseMisc(flag) return flag == xi.zoneMisc.MOGMENU and self.nomad end
    function p:hasPet() return self.pet end
    function p:despawnPet() self.pet = false self.calls[#self.calls + 1] = 'despawnPet' end
    function p:changesJob(job)
        self.calls[#self.calls + 1] = 'changesJob ' .. tostring(job)
        self.unlockedSupport = true           -- what the game's call does: jobs.unlocked |= (1 << job), and job 0 is that bit
        self.sub = job
    end
    function p:hasTrait(trait)
        if trait ~= xi.trait.DUAL_WIELD then return false end
        return (self.main == xi.job.NIN and self.mainLvl >= 10) or (self.sub == xi.job.NIN and self.subLvl >= 10)
    end
    function p:getEquippedItem(slot) if slot == xi.slot.SUB then return self.off end end
    function p:unequipItem(slot) self.calls[#self.calls + 1] = 'unequip ' .. tostring(slot) if slot == xi.slot.SUB then self.off = nil end end
    function p:printToPlayer(text, channel) self.said[#self.said + 1] = text self.channel = channel end
    return p
end
local function item(shield, skill) return { isShield = function() return shield end, getSkillType = function() return skill end } end
local function did(p, what) for _, c in ipairs(p.calls) do if c == what then return true end end return false end
local function run(o) local p = newPlayer(o) local ok, err = pcall(command.onTrigger, p) return p, ok, err end

section('who may use it')
for mode, name in pairs({ [0] = 'a regular character', [1] = 'Iron', [2] = 'Steel', [3] = 'Silver' }) do
    local p, ok = run({ mode = mode })
    check(ok and p.sub == xi.job.MNK and #p.calls == 0, name .. ': refused, nothing changed')
    check(#p.said == 1 and p.said[1]:find('Randomized', 1, true) ~= nil, name .. ': told that it is for Randomized characters')
end
do
    local saved = xi.hardcore
    xi.hardcore = nil
    local p, ok = run()
    check(ok and p.sub == xi.job.MNK and #p.calls == 0, 'without the hardcore module: refused, no error')
    xi.hardcore = saved
end

section('a Randomized character')
do
    local p, ok = run({ sub = 0, unlockedSupport = false })
    check(ok and #p.calls == 0 and p.unlockedSupport == false, 'no support job set: nothing is called, so the support job is not unlocked by the back door')
    check(#p.said == 1 and p.said[1]:find('no support job', 1, true) ~= nil, 'no support job set: says so')

    p, ok = run({ ownHouse = false, anyHouse = false })
    check(ok and p.sub == xi.job.MNK and #p.calls == 0, 'out in the field: refused')
    check(p.said[1]:find('Mog House', 1, true) ~= nil, 'out in the field: told where to use it')

    p, ok = run({ ownHouse = false, anyHouse = true })
    check(ok and p.sub == xi.job.MNK and #p.calls == 0, 'in someone else\'s Mog House: refused (jobs cannot be changed there)')

    p, ok = run()
    check(ok and p.sub == 0 and did(p, 'changesJob 0'), 'in its own Mog House: the support job is off')
    check(#p.said == 1 and p.said[1]:find('Monk', 1, true) ~= nil and p.said[1]:find('Moogle', 1, true) ~= nil, 'the line names the job and says what to do next: ' .. tostring(p.said[1]))
    check(p.channel == 29, 'the line goes to the system channel')
    check(p.main == xi.job.WAR and p.mainLvl == 30, 'the main job is untouched')

    p, ok = run({ ownHouse = false, anyHouse = false, nomad = true })
    check(ok and p.sub == 0, 'beside a Nomad Moogle: the support job is off')

    p, ok = run({ pet = true })
    check(ok and p.pet == false and p.calls[1] == 'despawnPet' and p.calls[2] == 'changesJob 0', 'a pet is sent away first')

    local second = newPlayer()
    command.onTrigger(second)
    command.onTrigger(second)
    check(#second.calls == 1 and #second.said == 2 and second.said[2]:find('no support job', 1, true) ~= nil, 'used twice: the second time only says there is none')
end

section('a Blue Mage as the main job is asked first')
do
    -- the game's call takes a Blue Mage main job's set blue magic off and saves that (blueutils::UnequipAllBlueSpells)
    local p = run({ main = xi.job.BLU })
    check(p.sub == xi.job.MNK and #p.calls == 0, 'Blue Mage main, plain !dropsub: nothing is changed')
    check(#p.said == 1 and p.said[1]:find('!dropsub yes', 1, true) ~= nil and p.said[1]:find('blue magic', 1, true) ~= nil, 'and it is told what goes and how to go on')

    local q = newPlayer({ main = xi.job.BLU })
    command.onTrigger(q, 'YES')
    check(q.sub == 0 and did(q, 'changesJob 0'), '!dropsub yes: the support job is off')

    local r = newPlayer({ main = xi.job.WAR, sub = xi.job.BLU })
    command.onTrigger(r)
    check(r.sub == 0, 'Blue Mage as the support job needs no "yes" (its set comes back with the job)')

    local outside = newPlayer({ main = xi.job.BLU, ownHouse = false, anyHouse = false })
    command.onTrigger(outside)
    check(outside.said[1]:find('Mog House', 1, true) ~= nil, 'out in the field a Blue Mage is told where to go first, not asked for "yes"')
end

section('the second weapon')
do
    local p = run({ sub = xi.job.NIN, off = item(false, xi.skill.SWORD) })
    check(p.off == nil and did(p, 'unequip 1'), 'held through the support job\'s Dual Wield: it comes off')

    p = run({ main = xi.job.NIN, sub = xi.job.WAR, off = item(false, xi.skill.KATANA) })
    check(p.off ~= nil and not did(p, 'unequip 1'), 'a Ninja main keeps its second weapon')

    p = run({ off = item(true, 255) })      -- (a shield is no weapon: the game answers 255 for its skill type)
    check(p.off ~= nil, 'a shield stays')

    p = run({ off = item(false, xi.skill.NONE) })
    check(p.off ~= nil, 'a grip stays')

    p = run({ off = nil })
    check(p.sub == 0 and not did(p, 'unequip 1'), 'an empty hand is fine')
end

io.write(string.format('\n%d passed, %d failed\n', passed, failed))
os.exit(failed == 0 and 0 or 1)
