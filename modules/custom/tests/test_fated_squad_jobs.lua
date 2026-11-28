-- squad.lua: with the random squad on, a mate may take the jobs fate gave it even when the player has not unlocked
-- them (2026-11-27, Noxaru, Hasuko: a Randomized player's mates were stuck on one job and had no support job).
-- The real jobUnlocked function and the two real command branches are cut out of squad.lua and run on stand-ins.
--   luajit test_fated_squad_jobs.lua <server folder>
local SERVER = arg[1]
assert(SERVER, 'usage: test_fated_squad_jobs.lua <server folder>')
local passed, failed = 0, 0
local function check(c, label) if c then passed = passed + 1 else failed = failed + 1 io.write('FAIL: ', label, '\n') end end
local function section(n) io.write('\n== ', n, '\n') end

local f = assert(io.open(SERVER .. '/modules/custom/lua/squad.lua', 'rb'))
local source = f:read('*a')
f:close()

local function cut(from, to)
    local a = assert(source:find(from, 1, true), 'not found: ' .. from)
    local b = assert(source:find(to, a, true), 'not found: ' .. to)
    return source:sub(a, b - 1)
end

section('the rule itself (jobUnlocked, as it is in squad.lua)')
local chunk = 'local STARTER_JOB_MAX = 6\n' .. cut('local function jobUnlocked(player, job, mate)', 'local function lockedMessage(player, job)') .. '\nreturn jobUnlocked'
local jobUnlocked = assert(loadstring(chunk, 'jobUnlocked'))()

local COR, MNK, BLU, BST, RNG, WAR, PLD = 17, 2, 16, 9, 11, 1, 7
local function player(jobs) return { jobs = jobs or {}, hasJob = function(self, job) return self.jobs[job] == true end } end
local function world(randomSquad, rolled, squadJobs)
    xi = { hardcore = {
        randomSquadOn = function(p) return randomSquad end,
        randomSquadJobAllowed = function(p, mate, job) if not randomSquad or job == nil or job == 0 then return true end return (rolled[mate.id] or {})[job] == true end,
        squadJob = function(p, job) return (squadJobs or {})[job] == true end,
    } }
end

local hasuko = player({ [BST] = true, [RNG] = true })   -- a Randomized player with two jobs of its own
local mate = { id = 5, mjob = MNK, sjob = 0 }
world(true, { [5] = { [COR] = true, [MNK] = true } })
check(jobUnlocked(hasuko, COR, mate) == true, 'random squad: the mate may go back to its own Corsair, a job the player never unlocked')
check(jobUnlocked(hasuko, COR) == false, 'asked without the mate (a new mate, a GM level): the old rule, unchanged')
check(jobUnlocked(hasuko, BLU, mate) == false, 'a job that is neither the mate\'s nor the player\'s stays locked')
check(jobUnlocked(hasuko, BST, mate) == true and jobUnlocked(hasuko, WAR, mate) == true, 'the player\'s own jobs and the starting six pass this rule as before')
world(true, { [5] = { [COR] = true } }, { [PLD] = true })
check(jobUnlocked(hasuko, PLD, mate) == true, 'a job a quest unlocked for the squad still passes')
world(false, { [5] = { [COR] = true } })
check(jobUnlocked(hasuko, COR, mate) == false, 'random squad off: an advanced job needs the player\'s unlock, as always')
xi = {}
check(jobUnlocked(hasuko, COR, mate) == false and jobUnlocked(hasuko, BST, mate) == true, 'without the hardcore module: no error, the old rule')

section('!squad job and !squad sub (the real branches)')
-- the two branches, from "elseif action == 'job' then" up to "elseif action == 'look' then", wrapped in a function
local branches = cut("    elseif action == 'job' then", "    elseif action == 'look' then")
local wrapped = [[
local STARTER_JOB_MAX = 6
local jobNames, jobList, said = ...
]] .. cut('local function jobUnlocked(player, job, mate)', 'local function lockedMessage(player, job)') .. [[
local function lockedMessage(player, job) return 'LOCKED ' .. tostring(job) end
local function say(player, text) said[#said + 1] = text end
local function parseJob(text) for id, name in pairs(jobNames) do if name == text then return id end end end
local function decodeBehavior() return 0 end
local function chatSend() end
return function(player, mate, action, arg2)
    if false then
]] .. branches .. [[
    end
    return true
end
]]
local names = { [WAR] = 'WAR', [MNK] = 'MNK', [BST] = 'BST', [RNG] = 'RNG', [BLU] = 'BLU', [COR] = 'COR', [PLD] = 'PLD' }
local said = {}
package.preload['modules/custom/lua/squad_jobs'] = function() return { roleKeptHint = function() return nil end } end
local run = assert(loadstring(wrapped, 'branches'))(names, 'WAR MNK ...', said)
local function try(p, m, action, arg2)
    for i = #said, 1, -1 do said[i] = nil end
    p.getCharVar = function() return 0 end
    p.getName = function() return 'Hasuko' end
    return run(p, m, action, arg2), said[1]
end

world(true, { [5] = { [COR] = true, [MNK] = true }, [6] = { [BLU] = true, [BST] = true } })
local cor = { id = 5, name = 'Dusty', mjob = MNK, sjob = 0 }
local done, line = try(hasuko, cor, 'job', 'COR')
check(done == true and cor.mjob == COR and line == nil, 'Noxaru: the mate goes back to Corsair (' .. tostring(line) .. ')')
done, line = try(hasuko, cor, 'sub', 'MNK')
check(done == true and cor.sjob == MNK and line == nil, 'and takes its other fated job as support job')
local blu = { id = 6, name = 'Azure', mjob = BST, sjob = 0 }
done, line = try(hasuko, blu, 'sub', 'BLU')
check(done == true and blu.sjob == BLU and line == nil, 'Hasuko: the Blue Mage that became a Beastmaster takes Blue Mage as support job (' .. tostring(line) .. ')')
done, line = try(hasuko, blu, 'job', 'COR')
check(done == nil and blu.mjob == BST and line ~= nil and line:find('LOCKED', 1, true) ~= nil, 'another mate\'s job is still refused')
done, line = try(hasuko, blu, 'job', 'WAR')
check(done == nil and blu.mjob == BST and line ~= nil and line:find('fate gave', 1, true) ~= nil, 'a job fate did not give is refused with the random squad line')
done, line = try(hasuko, blu, 'sub', 'RNG')
check(done == nil and blu.sjob == BLU and line ~= nil and line:find('fate gave', 1, true) ~= nil, 'the player\'s own job is not the mate\'s: refused as support job too')

world(false, {})
local plain = { id = 7, name = 'Plain', mjob = WAR, sjob = 0 }
done, line = try(hasuko, plain, 'job', 'COR')
check(done == nil and plain.mjob == WAR and line ~= nil and line:find('LOCKED', 1, true) ~= nil, 'random squad off: Corsair needs the player\'s unlock')
done, line = try(hasuko, plain, 'job', 'BST')
check(done == true and plain.mjob == BST, 'random squad off: the player\'s own advanced job is fine')
done, line = try(hasuko, plain, 'sub', 'MNK')
check(done == true and plain.sjob == MNK, 'random squad off: a starting job as support job is fine')

io.write(string.format('\n%d passed, %d failed\n', passed, failed))
os.exit(failed == 0 and 0 or 1)
