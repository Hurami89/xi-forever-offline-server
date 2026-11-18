-----------------------------------
-- FFXI Offline: bot players - conversations. Used by bots.lua.
--
-- /tell a bot (or talk in party chat when bots are in your party) and it answers like a player at a keyboard:
--   with your local AI model (the same Ollama model squad chat uses) through bots_chat_ai.py, which runs inside
--   the crowd chat AI helper the launcher starts ("AI chatter" on the Rates page). The bot knows who it is: name,
--   race, job and level, nation, personality, craft, goal, rank, what it is doing right now, and what you two
--   said before (the helper keeps a short memory per bot).
--   No answer from the model within 25 seconds (or AI chatter off): a short line from its own facts instead.
-- Bridge files (server/modules/custom/lua): bots_chat_in.txt (requests, one JSON line each) and
-- bots_chat_out.txt (answers, "<id><TAB><text>" per line). The bots only ever answer: they never start a tell.
-----------------------------------
-- Without the AI (AI chatter off, or the helper not answering: 3 misses in a row = off for 10 minutes, then it is
-- tried again) the bot answers at once with a written line (bots_dialogue.lua) that fits what you said.
-----------------------------------
local B = {}

local IN_FILE   = 'modules/custom/lua/bots_chat_in.txt'
local OUT_FILE  = 'modules/custom/lua/bots_chat_out.txt'
local WAIT      = 25    -- seconds for the model before the bot answers on its own
local MISSES    = 3     -- unanswered requests in a row before the AI counts as not there
local DOWN_FOR  = 600   -- ... for this many seconds, then it is asked again

local dialogueOk, dialogue = pcall(require, 'modules/custom/lua/bots_dialogue')
if not dialogueOk or type(dialogue) ~= 'table' then
    dialogue = nil
end

local misses, downUntil = 0, 0
local TYPE_CPS  = 7     -- characters per second it "types"
local PARTY_CHANCE = 0.3 -- party chat that is not addressed to a bot: chance one bot answers

local info -- function(bot) -> table of facts (from bots.lua)
local pending = {}      -- [request id] = { bot, to, kind, text, deadline }
local outbox = {}       -- lines to send: { at, botId, to, kind, text }
local nextId = 0
local outOffset = nil
local lastFallback = {}
local answered = {}     -- [request id] = { botId, to, kind, last } (a second line of the same answer follows the first)

local function now()
    return os.time()
end

local function rnd(a, b)
    return math.random(a, b)
end

local function pick(list)
    return list[rnd(1, #list)]
end

function B.setup(infoFn)
    info = infoFn
end

-- a tiny JSON writer (strings, numbers, booleans, flat tables)
local function jstr(s)
    s = tostring(s or '')
    s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', ' '):gsub('\r', ' '):gsub('[%c]', ' ')
    return '"' .. s .. '"'
end

local function json(t)
    local parts = {}
    for k, v in pairs(t) do
        local val
        if type(v) == 'table' then
            val = json(v)
        elseif type(v) == 'number' then
            val = tostring(v)
        elseif type(v) == 'boolean' then
            val = v and 'true' or 'false'
        else
            val = jstr(v)
        end

        parts[#parts + 1] = jstr(k) .. ':' .. val
    end

    return '{' .. table.concat(parts, ',') .. '}'
end

-- one answer line from the helper: "<request id><TAB><text>"
local function parseLine(line)
    local id, text = line:match('^(%d+)\t(.*)$')
    return { id = tonumber(id), text = text }
end

-- is the AI there? (AI chatter on in the launcher, and not missing its last answers)
local function aiWanted()
    local ok, c = pcall(require, 'modules/custom/lua/crowds_config')
    if ok and type(c) == 'table' and c.chat_ai == false then
        return false
    end

    return now() >= downUntil
end

local function request(bot, to, kind, text)
    nextId = nextId + 1
    local facts = info and info(bot) or {}
    local ai = aiWanted()
    if ai then
        local f = io.open(IN_FILE, 'a')
        if f then
            f:write(json({ id = nextId, t = now(), bot = bot:getName(), to = to, kind = kind, text = text, info = facts }) .. '\n')
            f:close()
        end
    end

    pending[nextId] = { botId = bot:getID(), bot = bot:getName(), to = to, kind = kind, text = text, deadline = now() + (ai and WAIT or 0),
        facts = facts, ai = ai }
end

-- its own short answer when the model is not there (or too slow)
local function fallback(p)
    if dialogue and GetPlayerByID then
        local bot = GetPlayerByID(p.botId)
        local ok, line = pcall(function()
            return bot and dialogue.reply(bot, p.text, p.facts, p.to)
        end)
        if ok and type(line) == 'string' and line ~= '' then
            return line
        end
    end

    local text = string.lower(p.text or '')
    local f = p.facts or {}
    if text:find('party') or text:find('%f[%a]pt%f[%A]') or text:find('join') or text:find('inv') then
        return f.busy and pick({ 'cant right now sorry, ' .. (f.doing or 'busy'), 'maybe later? busy atm' }) or pick({ 'sure, send an invite', 'ok invite me', 'sure!' })
    elseif text:find('what') and (text:find('doing') or text:find('up')) or text:find('wyd') then
        return pick({ (f.doing or 'not much') .. ' :)', 'just ' .. (f.doing or 'hanging around'), (f.doing or 'chilling') .. ', you?' })
    elseif text:find('level') or text:find('lvl') or text:find('job') then
        return pick({ string.format('%s %d', f.job or 'WAR', f.level or 1), string.format('lv%d %s atm', f.level or 1, f.job or 'WAR') })
    elseif text:find('^%s*h[ie]') or text:find('hello') or text:find('hey') or text:find('o/') then
        return pick({ 'hey', 'o/', 'hi!', 'hey whats up' })
    elseif text:find('thank') or text:find('ty') then
        return pick({ 'np', 'np :)', 'anytime' })
    elseif text:find('?') then
        return pick({ 'hmm not sure', 'no idea sorry', 'good question lol' })
    end

    return pick({ 'lol', 'nice', 'heh', 'yeah', 'sorry, was afk a sec' })
end

local function queueSend(botId, to, kind, text, after)
    local at = now() + (after or 0) + math.max(2, math.floor(#text / TYPE_CPS))
    outbox[#outbox + 1] = { at = at, botId = botId, to = to, kind = kind, text = text }
    return at
end

-- you sent a bot a tell (bots.cpp -> xi.bots.onTell)
function B.onTell(bot, from, text)
    request(bot, from, 'tell', text)
end

-- you said something in party chat with bots in your party (not an order)
function B.onParty(player, text, bots)
    if #bots == 0 then
        return
    end

    local lower = string.lower(text)
    local addressed
    for _, b in ipairs(bots) do
        if lower:find(string.lower(b:getName()), 1, true) then
            addressed = b
        end
    end

    if not addressed and (text:find('?') or math.random() < PARTY_CHANCE) then
        addressed = pick(bots)
    end

    if addressed then
        request(addressed, player:getName(), 'party', text)
    end
end

-- you said something in your bot linkshell: one member may answer
function B.onLs(player, text, members)
    local lower = string.lower(text)
    local addressed
    for _, b in ipairs(members) do
        if lower:find(string.lower(b:getName()), 1, true) then
            addressed = b
        end
    end

    if not addressed and (text:find('?') or math.random() < 0.5) then
        addressed = pick(members)
    end

    if addressed then
        request(addressed, player:getName(), 'ls', text)
    end
end

-- once a second (xi.bots.onTick): answers from the helper, fallbacks, and lines whose "typing" is done
function B.tick()
    local t = now()
    local f = io.open(OUT_FILE, 'r')
    if not f and outOffset == nil then
        outOffset = 0 -- (no answer file yet: everything in it will be new)
    end

    if f then
        local size = f:seek('end')
        if outOffset == nil or size < outOffset then
            outOffset = size -- (new server run, or the file was emptied: old answers are not sent again)
        end

        if size > outOffset then
            f:seek('set', outOffset)
            local data = f:read('*a') or ''
            outOffset = size
            for line in data:gmatch('[^\n]+') do
                local a = parseLine(line)
                local p = a.id and pending[a.id]
                local more = a.id and answered[a.id]
                if p and a.text and a.text ~= '' then
                    pending[a.id] = nil
                    misses = 0
                    local at = queueSend(p.botId, p.to, p.kind, a.text:sub(1, 120))
                    answered[a.id] = { botId = p.botId, to = p.to, kind = p.kind, last = at }
                elseif more and a.text and a.text ~= '' and t - (more.last or t) < 60 then
                    -- the next line of the same answer: typed after the first went out
                    more.last = queueSend(more.botId, more.to, more.kind, a.text:sub(1, 120), math.max(0, more.last - t) + 1)
                end
            end
        end

        f:close()
    end

    for id, a in pairs(answered) do
        if t - (a.last or t) > 120 then
            answered[id] = nil
        end
    end

    for id, p in pairs(pending) do
        if t >= p.deadline then
            pending[id] = nil
            if p.ai then
                misses = misses + 1
                if misses >= MISSES and t >= downUntil then
                    downUntil = t + DOWN_FOR
                    misses = 0
                    print(string.format('[bots] the chat AI did not answer %d times: written answers for %d minutes, then it is asked again', MISSES, DOWN_FOR / 60))
                end
            end
            if (lastFallback[p.botId] or 0) + 5 <= t then
                lastFallback[p.botId] = t
                queueSend(p.botId, p.to, p.kind, fallback(p))
            end
        end
    end

    for i = #outbox, 1, -1 do
        local o = outbox[i]
        if t >= o.at then
            table.remove(outbox, i)
            if BotIsOnline(o.botId) then
                if o.kind == 'tell' then
                    BotTell(o.botId, o.to, o.text)
                elseif o.kind == 'ls' then
                    BotChat(o.botId, 5, o.text)
                    BotChat(o.botId, 27, o.text) -- (linkshell 2: where bots wear their pearl; see bots_ls.lua)
                else
                    BotChat(o.botId, 4, o.text)
                    local e = GetPlayerByID and GetPlayerByID(o.botId)
                    if e and xi.bots and xi.bots.toSquad then
                        pcall(xi.bots.toSquad, e, o.text)
                    end
                end
            end
        end
    end
end

-- for the tests
B._fallback = fallback
B._pending = pending
B._aiState = function()
    return misses, downUntil
end

return B
