-----------------------------------
-- XI: Forever Offline: town and outpost chatter from the dialogue pack (the Living World pack's crowd section, built
-- into bots_dialogue_data.lua by C:\FFXISOLO\dialogue\build_dialogue.py). Used by crowds_chat.lua, for the crowds and
-- for the bot players standing in town: small talk, two-line exchanges, camp chatter at outposts, greetings, answers
-- when you target someone, and shouts. The old hand-written templates (crowds_chat_data.lua) and, with AI chatter on,
-- the AI pool still come up too.
--
-- A line is only used where it fits: its place (Jeuno, Whitegate, a nation city, a small town, a port with a ferry),
-- the speaker's level and job, and the time of day for a few. Each speaker has one of the pack's personalities (from
-- its name, the same one it has everywhere): polite ones type the polite version, a few type very short.
-- The same line does not come back until about half of the lines that fit have been used.
-----------------------------------
local C = {}

local DATA_PATH = 'modules/custom/lua/bots_dialogue_data'

local PLACE = {
    [243] = 'jeuno', [244] = 'jeuno', [245] = 'jeuno', [246] = 'jeuno',
    [230] = 'sandoria', [231] = 'sandoria', [232] = 'sandoria', [233] = 'sandoria',
    [234] = 'bastok', [235] = 'bastok', [236] = 'bastok', [237] = 'bastok',
    [238] = 'windurst', [239] = 'windurst', [240] = 'windurst', [241] = 'windurst', [242] = 'windurst',
    [50] = 'whitegate', [48] = 'whitegate',
    [247] = 'small_town', [248] = 'small_town', [249] = 'small_town', [250] = 'small_town', [252] = 'small_town',
    [26] = 'small_town', [53] = 'small_town',
}
local FERRY  = { [248] = true, [249] = true, [53] = true, [50] = true } -- Selbina, Mhaura, Nashmau, Whitegate
local NATION = { sandoria = true, bastok = true, windurst = true }

local data, byCat
local loaded = false
local recent = {} -- [category] = { line ids, oldest first }
local persona     -- bots_dialogue.persona, when it is there

local function ensure()
    if loaded then
        return data ~= nil
    end

    loaded = true
    local ok, d = pcall(require, DATA_PATH)
    if not ok or type(d) ~= 'table' or type(d.crowd) ~= 'table' then
        return false
    end

    data = d.crowd
    byCat = {}
    for _, l in ipairs(data.lines or {}) do
        byCat[l.cat] = byCat[l.cat] or {}
        table.insert(byCat[l.cat], l)
    end

    local okD, D = pcall(require, 'modules/custom/lua/bots_dialogue')
    if okD and type(D) == 'table' and D.persona then
        persona = D.persona
    end

    return true
end

function C.available()
    return ensure()
end

local function placeOk(place, zoneId)
    local here = PLACE[zoneId or 0]
    if place == 'any' or place == 'outpost' or place == nil or place == '' then
        return true
    elseif place == 'upper_jeuno' then
        return zoneId == 244
    elseif place == 'notjeuno' then
        return here ~= 'jeuno'
    elseif place == 'nation' then
        return NATION[here or ''] == true
    elseif place == 'ferry' then
        return FERRY[zoneId or 0] == true
    end

    return here == place
end

local function whenOk(when)
    if not when or when == '' then
        return true
    end

    local hour = tonumber(os.date('%H')) or 12
    if when == 'night' then
        return hour >= 22 or hour < 4
    elseif when == 'evening' then
        return hour >= 17 and hour < 24
    elseif when == 'morning' then
        return hour >= 5 and hour < 11
    end

    return true
end

local function jobOk(jobs, job)
    if not jobs or #jobs == 0 then
        return true
    end

    for _, j in ipairs(jobs) do
        if j == job then
            return true
        end
    end

    return false
end

-- how this speaker types: 'polite', 'casual' or 'terse' (from its personality)
function C.register(name)
    if persona and name then
        local ok, p = pcall(persona, name)
        if ok and p and p.reg then
            return p.reg
        end
    end

    return 'casual'
end

local function voiced(casual, polite, name)
    local reg = C.register(name)
    if reg == 'polite' and polite and polite ~= '' then
        return polite
    end

    local text = casual
    if reg == 'terse' then
        text = text:gsub('%.$', '')
        text = text:sub(1, 1):lower() .. text:sub(2)
    end

    return text
end

-- remember a use; skip lines used lately (about half of those that fit)
local function fresh(cat, list)
    local r = recent[cat] or {}
    recent[cat] = r
    local seen = {}
    for _, id in ipairs(r) do
        seen[id] = true
    end

    local out = {}
    for _, l in ipairs(list) do
        if not seen[l.id] then
            out[#out + 1] = l
        end
    end

    return #out > 0 and out or list
end

local function use(cat, id, eligible)
    local r = recent[cat] or {}
    recent[cat] = r
    table.insert(r, id)
    local keep = math.max(1, math.min(60, math.floor(eligible / 2)))
    while #r > keep do
        table.remove(r, 1)
    end
end

-- one line (its fields not filled yet) for this speaker: who = { name, job }, lvl = its level. nil = none fits.
function C.line(cat, who, zoneId, lvl)
    if not ensure() then
        return nil
    end

    local list = {}
    for _, l in ipairs(byCat[cat] or {}) do
        if (lvl or 1) >= l.lo and (lvl or 1) <= l.hi and jobOk(l.jobs, who and who.job) and placeOk(l.place, zoneId) and whenOk(l.when) then
            list[#list + 1] = l
        end
    end

    if #list == 0 then
        return nil
    end

    local pool = fresh(cat, list)
    local l = pool[math.random(1, #pool)]
    use(cat, l.id, #list)
    return voiced(l.ca, l.po, who and who.name)
end

-- a two-line exchange in town: the first speaker's line and the second one's answer, each in its own voice
function C.pair(whoName, otherName, zoneId, lvl)
    if not ensure() then
        return nil
    end

    local list = {}
    for _, p in ipairs(data.pairs or {}) do
        if (lvl or 1) >= p.lo and (lvl or 1) <= p.hi and placeOk(p.place, zoneId) then
            list[#list + 1] = p
        end
    end

    if #list == 0 then
        return nil
    end

    local pool = fresh('pair', list)
    local p = pool[math.random(1, #pool)]
    use('pair', p.id, #list)
    return voiced(p.a, p.ap, whoName), voiced(p.b, p.bp, otherName)
end

-- crowds_chat.lua shout groups -> pack categories
C.SHOUT = { lfp = 'shout_lfp', lfp_heal = 'shout_lfp_heal', lfm = 'shout_lfm', selling = 'shout_selling', buying = 'shout_buying',
            ls = 'shout_ls', help = 'shout_help', endgame = 'shout_endgame', ai = 'shout_misc', misc = 'shout_misc' }

-- for the tests
C._reset = function()
    recent = {}
end

return C
