dofile('hardcore_harness.lua')
bit = bit or require('bit')
xi.job = { WAR = 1, SMN = 15, PUP = 18 }
xi.magic = { spell = { CARBUNCLE = 296 } }; xi.petType = { AUTOMATON = 2 }; xi.item = { HARLEQUIN_FRAME = 8224, HARLEQUIN_HEAD = 8193 }
local masks = {}
HardcoreSetJobs = function(id, mask) masks[id] = mask; players[id].unlocked = mask; return true end
HardcoreCanSwap = function(id) return id >= 1000 and id < 2000 end
HardcoreLootPool = function(zone) return { 1001, 1002, 1003 } end
HardcoreNMPool = function() return { 1900, 1901 } end
dofile('hardcore.lua')
applyAll()
local H = xi.hardcore
local function check(c, msg) if not c then error('FAIL: ' .. msg, 2) end; print('ok  ' .. msg) end
local f = io.open('modules/custom/lua/hardcore_pending.lua', 'w'); f:write("return { { name = 'Randall', mode = 4 } }"); f:close()
local r = newPlayer(9, 'Randall')
r.unlocked = 0x7E
function r:hasJob(j) return bit.band(self.unlocked, bit.lshift(1, j)) ~= 0 end
function r:unlockJob(j) self.unlocked = bit.bor(self.unlocked, bit.lshift(1, j)); if self.jobs[j] == 0 then self.jobs[j] = 1 end end
function r:changeJob(j) self.mjob = j; self.unlocked = bit.bor(self.unlocked, bit.lshift(1, j)) end
function r:raceChange(a, b, c) self.race = { a, b, c }; return true end
function r:addSpell() self.carb = true end
function r:setPetName() end
function r:unlockAttachment() end
xi.player.onGameIn(r, true, false)
check(H.mode(r) == 4, 'pending Randomized applied')
runTimers(); runTimers()
local rolled = r:getCharVar('[HC]Jobs')
check(rolled ~= 0 and r.mjob >= 1 and r.mjob <= 18 and bit.band(rolled, bit.lshift(1, r.mjob)) ~= 0, 'one era job rolled and set as main: ' .. r.mjob)
check(r.unlocked == rolled, 'only the rolled job is open to the character (mask ' .. r.unlocked .. ')')
check(r.race ~= nil and r.race[1] >= 1 and r.race[1] <= 8, 'random race/face/size')
-- a job quest unlock goes to the squad
r:unlockJob(7); r.msgs = {}
npcUtil.completeQuest(r)
check(bit.band(r:getCharVar('[HC]SquadJobs'), bit.lshift(1, 7)) ~= 0, 'PLD from a quest goes to the squad')
check(bit.band(r.unlocked, bit.lshift(1, 7)) == 0 or bit.band(rolled, bit.lshift(1, 7)) ~= 0, 'and not to the character')
check(H.squadJob(r, 7) and not H.squadJob(iron or newPlayer(50, 'Nobody'), 7), 'squad.lua sees it')
-- grants at 18/33/65
r.jobs[r.mjob] = 18; xi.player.onPlayerLevelUp(r)
local count = 0; for j = 1, 18 do if bit.band(r:getCharVar('[HC]Jobs'), bit.lshift(1, j)) ~= 0 then count = count + 1 end end
check(count == 2 and r:getCharVar('[HC]Grants') == 1, 'second job at 18')
r.jobs[r.mjob] = 70; xi.player.onPlayerLevelUp(r)
count = 0; for j = 1, 18 do if bit.band(r:getCharVar('[HC]Jobs'), bit.lshift(1, j)) ~= 0 then count = count + 1 end end
check(count == 4 and r:getCharVar('[HC]Grants') == 3, 'four jobs in all after 33 and 65')
xi.player.onPlayerLevelUp(r); check(r:getCharVar('[HC]Grants') == 3, 'no fifth job')
check(#sent == 0, 'no cosmetic milestones for Randomized')
-- loot
local mob = { isNM = function() return false end, getZoneID = function() return 100 end }
local nm = { isNM = function() return true end, getZoneID = function() return 100 end }
local got = H.randomLoot(r, mob, 1001)
check(got == 1002 or got == 1003, 'a drop becomes another item from the area pool')
check(H.randomLoot(r, mob, 4096) == 4096, 'a crystal stays a crystal')
local n = H.randomLoot(r, nm, 1500); check(n == 1900 or n == 1901, 'an NM drop comes from the NM pool')
-- death is normal
r.dead = true; xi.player.onPlayerDeath(r); r.dead = false
check(r:getCharVar('[HC]Dead') == 0 and r:getCharVar('[HC]Reset') == 0, 'a Randomized death is a normal death')
check(H.noFastTravel(r) == false, 'Randomized keeps teleports')
print('RANDOM PASSED')
