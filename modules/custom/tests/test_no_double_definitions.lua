-- No function is defined twice at the top level of a custom module (2026-11-27, SprinklesAK).
-- bots.lua had two "xi.bots.partyOrder = function": the second, added for !squad attack / !squad stop, replaced the
-- party chat handler, so from 2026-11-23 on bot players in your party did not talk back in party chat, did not take
-- "follow" / "stay" / "release" and did not cast what you asked for. Lua says nothing when that happens.
--   luajit test_no_double_definitions.lua <server folder>
local SERVER = arg[1]
assert(SERVER, 'usage: test_no_double_definitions.lua <server folder>')
local passed, failed = 0, 0
local function check(c, label) if c then passed = passed + 1 else failed = failed + 1 io.write('FAIL: ', label, '\n') end end
local function section(n) io.write('\n== ', n, '\n') end

local function read(path)
    local f = io.open(path, 'rb')
    if not f then return nil end
    local text = f:read('*a')
    f:close()
    return text
end

local function list(folder)
    local windows = package.config:sub(1, 1) == '\\'
    local cmd = windows and ('dir /b "' .. folder:gsub('/', '\\') .. '\\*.lua" 2>nul') or ('ls "' .. folder .. '" 2>/dev/null')
    local names = {}
    local p = io.popen(cmd)
    if p then
        for name in p:lines() do
            if name:match('%.lua$') then names[#names + 1] = name end
        end
        p:close()
    end
    table.sort(names)
    return names
end

-- the names defined at the top level of a file (column 0): "xi.a.b = function", "function xi.a.b(", "local function a("
local function definitions(text)
    local seen, twice = {}, {}
    local n = 0
    for line in (text .. '\n'):gmatch('(.-)\r?\n') do
        n = n + 1
        local name = line:match('^([%a_][%w_]*%.[%w_%.]+)%s*=%s*function[%s%(]') or line:match('^function%s+([%a_][%w_%.:]+)%s*%(')
        local localName = line:match('^local%s+function%s+([%a_][%w_]*)%s*%(')
        name = name or (localName and ('local ' .. localName))
        if name then
            if seen[name] then twice[#twice + 1] = string.format('%s (lines %d and %d)', name, seen[name], n) end
            seen[name] = n
        end
    end
    return seen, twice
end

section('the check sees a double definition (made-up text)')
do
    local _, twice = definitions('xi.bots.partyOrder = function(player, text)\nend\n\n    xi.bots.inside = function() end\nxi.bots.partyOrder = function(player, word, mob)\nend\n')
    check(#twice == 1 and twice[1]:find('xi.bots.partyOrder', 1, true) ~= nil, 'two definitions of one name are found')
    _, twice = definitions('function xi.a.b(x)\nend\nxi.a.b = function(y)\nend\nlocal function helper()\nend\nlocal function helper()\nend\n')
    check(#twice == 2, 'both ways of writing a definition count, and local functions too')
    _, twice = definitions('xi.a.b = function()\nend\nxi.a.c = function()\nend\nif x then\n    xi.a.b = function() end\nend\n')
    check(#twice == 0, 'different names, and an indented (conditional) definition, are fine')
end

section('every custom module')
local files = 0
for _, folder in ipairs({ 'modules/custom/lua', 'modules/custom/late' }) do
    for _, name in ipairs(list(SERVER .. '/' .. folder)) do
        local text = read(SERVER .. '/' .. folder .. '/' .. name)
        if text then
            files = files + 1
            local _, twice = definitions(text)
            check(#twice == 0, folder .. '/' .. name .. ': defined twice: ' .. table.concat(twice, ', '))
        end
    end
end
check(files >= 100, 'the modules were found (' .. files .. ' files)')

section('party chat for bot players')
do
    local bots = read(SERVER .. '/modules/custom/lua/bots.lua') or ''
    local squad = read(SERVER .. '/modules/custom/lua/squad.lua') or ''
    local cpp = read(SERVER .. '/modules/custom/cpp/bots.cpp') or ''
    local seen = definitions(bots)
    check(seen['xi.bots.partyOrder'] ~= nil and bots:find('xi.bots.partyOrder = function(player, text)', 1, true) ~= nil,
        'xi.bots.partyOrder is the party chat handler: (player, text)')
    check(seen['xi.bots.squadOrder'] ~= nil and bots:find('xi.bots.squadOrder = function(player, word, mob)', 1, true) ~= nil,
        '!squad attack / !squad stop have their own function: xi.bots.squadOrder(player, word, mob)')
    check(bots:find('talk.onParty(player, text', 1, true) ~= nil, 'the party chat handler still hands talk to the bots (talk.onParty)')
    check(squad:find("pcall(xi.bots.squadOrder, player, 'stop')", 1, true) ~= nil and squad:find("pcall(xi.bots.squadOrder, player, 'attack', mob)", 1, true) ~= nil,
        'squad.lua sends its attack and stop orders through xi.bots.squadOrder')
    check(squad:find("pcall(xi.bots.partyOrder, player, 'attack', mob)", 1, true) == nil, 'and no longer through the party chat handler with a monster')
    if cpp ~= '' then
        check(cpp:find('"partyOrder"', 1, true) ~= nil, 'bots.cpp sends your party chat to partyOrder')
    end
end

io.write(string.format('\n%d passed, %d failed\n', passed, failed))
os.exit(failed == 0 and 0 or 1)
