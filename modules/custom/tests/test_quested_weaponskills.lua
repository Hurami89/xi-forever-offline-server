-- late/quested_weaponskills.lua: a finished weapon skill quest teaches its weapon skill at log in (2026-11-27, Craig:
-- a transferred character had The Weight of Your Limits finished and no Steel Cyclone).
-- The file is loaded the way the map server loads a module file (the real modules/module_utils.lua, the real enum
-- files and the real scripts/globals/quests.lua), its override is put on xi.player.onGameIn the way the loader does
-- it, and stand-in players log in. The module's list is also compared with the quest scripts themselves.
-- No server, no database; nothing is written.
--   luajit test_quested_weaponskills.lua <server folder>
local SERVER = arg[1]
assert(SERVER, 'usage: test_quested_weaponskills.lua <server folder>')

local passed, failed = 0, 0
local function check(c, label) if c then passed = passed + 1 else failed = failed + 1 io.write('FAIL: ', label, '\n') end end
local function section(n) io.write('\n== ', n, '\n') end

package.path = SERVER .. '/?.lua;' .. package.path
xi    = { settings = { main = { RESTRICT_CONTENT = 1 } }, msg = { channel = { SYSTEM_3 = 29 } } }
utils = { splitStr = function() return {} end }
for _, name in ipairs({ 'quest_log.codegen', 'quest_status', 'ws_unlock.codegen' }) do
    assert(loadfile(SERVER .. '/scripts/enum/' .. name .. '.lua'))()
end
assert(loadfile(SERVER .. '/scripts/globals/quests.lua'))()

assert(loadfile(SERVER .. '/modules/module_utils.lua'))()                       -- as the loader does first
package.loaded['modules/module_utils'] = true                                   -- the file's own require
assert(loadfile(SERVER .. '/modules/custom/late/quested_weaponskills.lua'))()

section('what the file registers')
check(#xi.module.registry == 1 and #xi.module.commandRegistry == 0, 'one module, no command')
local module = xi.module.registry[1]
check(module.name == 'quested_weaponskills' and module.enabled == true, 'it is switched on')
check(#module.overrides == 1 and module.overrides[1].name == 'xi.player.onGameIn' and module.overrides[1].enabled == true,
    'one override, on xi.player.onGameIn (log in)')

-- the game's own function underneath, then the override on top of it, as the loader applies it
local superCalls = {}
xi.player = { onGameIn = function(player, firstLogin, zoning)
    superCalls[#superCalls + 1] = { player, firstLogin, zoning }
    return 'from the game'
end }
applyOverride(xi.player, 'onGameIn', module.overrides[1].func, 'xi.player.onGameIn', 'quested_weaponskills.lua')

-- a stand-in player: quest states by "log:id", learned weapon skills by xi.wsUnlock number
local DONE, ACCEPTED, AVAILABLE = xi.questStatus.QUEST_COMPLETED, xi.questStatus.QUEST_ACCEPTED, xi.questStatus.QUEST_AVAILABLE
local function newPlayer(o)
    local p = { quests = {}, learned = {}, added = {}, removed = {}, said = {}, pc = true }
    for k, v in pairs(o or {}) do p[k] = v end
    function p:isPC() return self.pc end
    function p:getQuestStatus(log, id) return self.quests[log .. ':' .. id] or AVAILABLE end
    function p:hasLearnedWeaponskill(ws) return self.learned[ws] == true end
    function p:addLearnedWeaponskill(ws) self.learned[ws] = true self.added[#self.added + 1] = ws end
    function p:delLearnedWeaponskill(ws) self.learned[ws] = nil self.removed[#self.removed + 1] = ws end
    function p:printToPlayer(text, channel) self.said[#self.said + 1] = text self.channel = channel end
    return p
end
local function key(logName, tableName, questName) return xi.questLog[logName] .. ':' .. xi.quest.id[tableName][questName] end
local function login(p, firstLogin, zoning) return xi.player.onGameIn(p, firstLogin or false, zoning or false) end

-- the fourteen quests as the quest scripts themselves have them: file, quest log, quest table, quest, weapon skill
-- (read from the scripts below, so a pair that is wrong in the module's list shows up here)
local FILES =
{
    'bastok/Inheritance', 'bastok/Shoot_First_Ask_Questions_Later', 'bastok/The_Walls_of_Your_Mind',
    'bastok/The_Weight_of_Your_Limits', 'jeuno/Axe_the_Competition', 'outlands/Bugi_Soden', 'outlands/Cloak_and_Dagger',
    'outlands/The_Potential_Within', 'sandoria/Methods_Create_Madness', 'sandoria/Old_Wounds', 'sandoria/Souls_in_Shadow',
    'windurst/Blood_and_Glory', 'windurst/From_Saplings_Grow', 'windurst/Orastery_Woes',
}
local fromScripts = {}
for _, name in ipairs(FILES) do
    local handle = assert(io.open(SERVER .. '/scripts/quests/' .. name .. '.lua', 'r'))
    local text = handle:read('*a')
    handle:close()
    local log, tableName, quest = text:match('Quest:new%(xi%.questLog%.([%u_]+),%s*xi%.quest%.id%.(%a+)%.([%u_]+)%)')
    local ws, more = nil, 0
    for found in text:gmatch('addLearnedWeaponskill%(xi%.wsUnlock%.([%u_]+)%)') do ws, more = found, more + 1 end
    check(log ~= nil and ws ~= nil and more == 1, name .. ': one quest and one weapon skill found in the script')
    fromScripts[#fromScripts + 1] = { file = name, log = log, tableName = tableName, quest = quest, ws = ws }
end

section('the list is the quest scripts\' own: each finished quest teaches its own weapon skill, and only that one')
local seenWs = {}
for _, q in ipairs(fromScripts) do
    local wsId = xi.wsUnlock[q.ws]
    check(xi.questLog[q.log] ~= nil and xi.quest.id[q.tableName] ~= nil and xi.quest.id[q.tableName][q.quest] ~= nil and wsId ~= nil,
        q.file .. ': the names exist in the server\'s tables')
    seenWs[wsId] = true
    local p = newPlayer({ quests = { [key(q.log, q.tableName, q.quest)] = DONE } })
    local result = login(p)
    check(#p.added == 1 and p.added[1] == wsId and p.learned[wsId] == true, q.file .. ': finished, so ' .. q.ws .. ' is learned (and nothing else)')
    check(#p.said == 1 and p.channel == 29, q.file .. ': one line says so')
    check(result == 'from the game', q.file .. ': the game\'s own answer is passed on')
end
local distinct = 0
for _ in pairs(seenWs) do distinct = distinct + 1 end
check(#fromScripts == 14 and distinct == 14, 'fourteen quests, fourteen different weapon skills')

section('the line names the weapon skill as the game does')
do
    local p = newPlayer({ quests = { [key('BASTOK', 'bastok', 'THE_WEIGHT_OF_YOUR_LIMITS')] = DONE } })
    login(p)
    check(p.added[1] == 6 and xi.wsUnlock.STEEL_CYCLONE == 6, 'The Weight of Your Limits (Bastok quest 66): weapon skill 6, Steel Cyclone')
    check(p.said[1] == 'Your finished weapon skill quests count here now. Learned: Steel Cyclone.', 'the line: ' .. tostring(p.said[1]))
    local q = newPlayer({ quests = { [key('OUTLANDS', 'outlands', 'BUGI_SODEN')] = DONE, [key('OUTLANDS', 'outlands', 'THE_POTENTIAL_WITHIN')] = DONE } })
    login(q)
    check(#q.said == 1 and q.said[1]:find('Blade: Ku, Tachi: Kasha', 1, true) ~= nil, 'two at once: one line, both names (' .. tostring(q.said[1]) .. ')')
end

section('nothing for a quest that is not finished, and nothing twice')
do
    local k = key('SANDORIA', 'sandoria', 'OLD_WOUNDS')
    local p = newPlayer({ quests = { [k] = ACCEPTED } })
    login(p)
    check(#p.added == 0 and #p.said == 0, 'accepted, not finished: nothing learned, nothing said')
    p = newPlayer()
    login(p)
    check(#p.added == 0 and #p.said == 0, 'no quest at all (a new character): nothing')
    p = newPlayer({ quests = { [k] = DONE }, learned = { [xi.wsUnlock.SAVAGE_BLADE] = true } })
    login(p)
    check(#p.added == 0 and #p.said == 0, 'finished and already learned (a character made here): nothing, no line')
    p = newPlayer({ quests = { [k] = DONE } })
    login(p)
    login(p)
    login(p)
    check(#p.added == 1 and #p.said == 1, 'three log ins after a transfer: learned once, said once')
    -- a finished quest that is not a weapon skill quest
    p = newPlayer({ quests = { [xi.questLog.SANDORIA .. ':' .. xi.quest.id.sandoria.A_SENTRYS_PERIL] = DONE } })
    login(p)
    check(#p.added == 0 and #p.said == 0, 'another finished quest: nothing')
end

section('only at log in, only for players, never takes anything away')
do
    local all = {}
    for _, q in ipairs(fromScripts) do all[key(q.log, q.tableName, q.quest)] = DONE end
    local p = newPlayer({ quests = all })
    local before = #superCalls
    local result = login(p, false, true)
    check(#p.added == 0 and #p.said == 0 and result == 'from the game', 'changing areas (zoning): nothing, the game\'s answer passed on')
    check(#superCalls == before + 1 and superCalls[#superCalls][1] == p and superCalls[#superCalls][3] == true, 'the game\'s own function ran, with the same values')
    p = newPlayer({ quests = all, pc = false })
    login(p)
    check(#p.added == 0, 'not a player: nothing')
    p = newPlayer({ quests = all, learned = { [60] = true, [1] = true } })
    login(p)
    check(#p.added == 13 and #p.removed == 0 and p.learned[60] == true and #p.said == 1, 'everything finished, one already learned: the other thirteen, nothing removed, one line')
    check(pcall(xi.player.onGameIn, nil, false, false) == true, 'no player at all: no error')
end

section('a mistake inside never breaks the log in of the other modules')
do
    local p = newPlayer({ quests = { [key('JEUNO', 'jeuno', 'AXE_THE_COMPETITION')] = DONE } })
    function p:getQuestStatus() error('the database is away') end
    local realPrint, printed = print, {}
    print = function(...) printed[#printed + 1] = table.concat({ ... }, ' ') end
    local ok, result = pcall(xi.player.onGameIn, p, false, false)
    print = realPrint
    check(ok and result == 'from the game', 'an error while reading the quest log: the log in goes on, the game\'s answer is passed on')
    check(#printed == 1 and printed[1]:find('[quested_weaponskills]', 1, true) ~= nil and printed[1]:find('the database is away', 1, true) ~= nil,
        'and the map log gets one line with the reason')
end

section('every weapon skill a quest script teaches is in the list')
do
    -- on a full server folder this finds a quest script that was added later; needs grep (skipped where there is none)
    local handle = io.popen('grep -rlE "addLearnedWeaponskill\\(xi\\.wsUnlock\\." "' .. SERVER .. '/scripts/quests" 2>/dev/null')
    local found = {}
    if handle then
        for line in handle:lines() do found[#found + 1] = line end
        handle:close()
    end
    if #found == 0 then
        io.write('   (no grep here: skipped)\n')
    else
        local known = {}
        for _, name in ipairs(FILES) do known[name .. '.lua'] = true end
        local unknown = {}
        for _, path in ipairs(found) do
            local tail = path:gsub('\\', '/'):match('scripts/quests/(.+)$')
            if not known[tail] then unknown[#unknown + 1] = tail end
        end
        check(#found >= 14, 'the fourteen quest scripts were found (' .. #found .. ')')
        check(#unknown == 0, 'no other quest script teaches a named weapon skill' .. (#unknown > 0 and (': ' .. table.concat(unknown, ', ')) or ''))
    end
end

io.write(string.format('\n%d passed, %d failed\n', passed, failed))
os.exit(failed == 0 and 0 or 1)
