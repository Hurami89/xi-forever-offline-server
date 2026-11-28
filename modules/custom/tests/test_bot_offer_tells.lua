-- bots_trade.lua: which tells are about a bot's selling / buying offer (2026-11-27, SprinklesAK: a bot with something
-- in its bazaar answered every tell with its sale line). The real file is loaded; its other modules are not needed
-- for this (it asks for them with pcall).
--   luajit test_bot_offer_tells.lua <server folder>
local SERVER = arg[1]
assert(SERVER, 'usage: test_bot_offer_tells.lua <server folder>')
local passed, failed = 0, 0
local function check(c, label) if c then passed = passed + 1 else failed = failed + 1 io.write('FAIL: ', label, '\n') end end
local function section(n) io.write('\n== ', n, '\n') end

package.path = SERVER .. '/?.lua;' .. package.path
xi = xi or {}
local M = assert(loadfile(SERVER .. '/modules/custom/lua/bots_trade.lua'))()
check(type(M.aboutOffer) == 'function' and type(M.onTell) == 'function', 'the module loads and has aboutOffer and onTell')

local function offer(name) return { name = name or 'Scorpion Harness', kind = 'sell', price = 2000000 } end
local function about(o, text, at, from) return M.aboutOffer(o, from or 'Sprinkles', text, at or 1000) end

section('ordinary chat goes to the bot\'s own answers')
for _, text in ipairs({ 'hey, what are you up to?', 'do you have time to party later?', 'want to party?', 'where do you level at 30?',
                        'i forgot my signet again', 'lets go together', 'thanks so much!', 'nice to meet you', '?', 'lol',
                        'what job are you', 'got any tips for a new whm?', 'is that mine or yours', 'whats the big deal with jeuno' }) do
    check(about(offer(), text) == false, 'not about the offer: "' .. text .. '"')
end

section('talk about the offer')
for _, text in ipairs({ 'how much?', 'How much for the harness', 'still selling?', 'is the Scorpion Harness still there', 'price?',
                        'wtb that', 'ill take it', "I'll take it", 'whats the cost', 'i want to buy it', 'can i see your bazaar',
                        'where are you?', '2m gil? too high', 'interested', 'harness?' }) do
    check(about(offer(), text) == true, 'about the offer: "' .. text .. '"')
end
check(about(offer('Astral Ring'), 'nice ring') == false, 'a short common word of the item name ("ring") alone is not enough')
check(about(offer('Astral Ring'), 'is the astral one real?') == true, 'a longer word of the item name is')

section('follow-ups, only after talk about the offer')
do
    local o = offer()
    check(about(o, 'where?', 1000) == false, '"where?" out of nowhere: not about the offer')
    check(about(o, 'how much?', 1000) == true, 'the price is asked')
    check(about(o, 'where?', 1060) == true, '"where?" a minute later: about the offer')
    check(about(o, 'ok', 1100) == true and about(o, 'still have it?', 1150) == true and about(o, '?', 1200) == true, '"ok", "still have it?" and "?" follow up too')
    check(about(o, 'anyway, what job are you', 1210) == false, 'a change of subject is not a follow-up')
    check(about(o, 'where?', 1200 + 181) == false, 'three minutes after the last line about it, "where?" is ordinary chat again')
    check(about(o, 'where?', 1060, 'Someone') == false, 'another player\'s "where?" is not a follow-up to your talk')
end

section('onTell itself')
do
    -- no offer for this bot (or the trading functions are missing in this server build): it never takes the tell
    local bot = { getID = function() return 77 end }
    check(M.onTell(bot, 'Sprinkles', 'how much?') == false, 'a bot without an offer does not answer about one')
end

io.write(string.format('\n%d passed, %d failed\n', passed, failed))
os.exit(failed == 0 and 0 or 1)
