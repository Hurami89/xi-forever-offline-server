-----------------------------------
-- FFXI Offline: bot players - inviting you, the way players did. Used by bots.lua.
--
-- Only when you ask for it: turn on Seek Party (the party menu / the flag /sea shows). Then a bot party that has room
-- and a job like yours missing (no healer, no tank, short of damage) may send you a short tell, the way leaders did
-- ("hey, exp party at Valkurm Dunes, need a healer, lv 19-23, interested?") and an invite a few seconds later.
-- Accept it and you are in their party: the leader tells you where the camp is and they wait there, pulling as they
-- go. Ignore or decline it and that party leaves you alone for a while. A battlefield run looking for members may
-- ask you too ("got a Sky Orb, BCNM 30 at Waughroon Shrine, want in?"); once you are at the circle the leader puts
-- the orb in, and you enter by touching the circle yourself.
-- Never: while you have trusts or squad mates out (they cannot share a party with players), while you fight, while you
-- are in a party, or after !bots invites off.
-----------------------------------
local I = {}

local CHECK_EVERY   = 45          -- seconds between two looks
local ASK_GAP       = 15 * 60     -- seconds between two invites to you (any party)
local SAME_PARTY    = 40 * 60     -- the same leader does not ask you again for this long
local INVITE_AFTER  = { 6, 14 }   -- seconds between its tell and the invite
local LEVEL_RANGE   = 3
local SYNC_SPAN     = 10          -- a Level Sync party: everyone within 10 levels of each other (10+)

local JOBS = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP' }
local ROLE = { WAR = 'tank', PLD = 'tank', NIN = 'tank', WHM = 'healer', RDM = 'healer', BRD = 'support', SMN = 'support', COR = 'support' }
-- what a job can fill when a party asks (a Warrior or Ninja tanks or deals damage, a Red Mage heals, supports or melees)
local CAN_FILL = { WAR = { 'tank', 'damage' }, NIN = { 'tank', 'damage' }, RDM = { 'healer', 'support', 'damage' }, DRK = { 'damage' },
                   BLU = { 'damage', 'support' }, COR = { 'support', 'damage' } }

local state
local nextCheck = 0
local lastAsk = {}     -- [player id] = time of the last invite to them
local asked = {}       -- ['leader:player'] = time
local pending = {}     -- [player id] = { leader id, kind, at }
local welcomed = {}    -- [player id] = leader id it already welcomed

local function now()
    return os.time()
end

local function rnd(a, b)
    return math.random(a, b)
end

local function pick(list)
    return list[rnd(1, #list)]
end

function I.setup(brainState)
    state = brainState
end

local function roleOf(e)
    return ROLE[JOBS[e:getMainJob()] or 'WAR'] or 'damage'
end

local function jobOf(e)
    return JOBS[e:getMainJob()] or 'WAR'
end

local function zoneName(zoneId)
    local ok, name = pcall(function()
        return GetZone(zoneId):getName()
    end)
    return ok and name and (name:gsub('_', ' ')) or 'the field'
end

-- you, ready to be asked?
local function seeking(player)
    if player:getCharVar('[Bots]NoInvites') == 1 then
        return false
    end

    local ok, seeks = pcall(function()
        return player:isSeekingParty()
    end)
    if not ok or not seeks or player:isEngaged() or not player:isAlive() then
        return false
    end

    for _, m in pairs(player:getPartyWithTrusts() or {}) do
        if m:getID() ~= player:getID() then
            return false -- (already grouped, or trusts / squad mates out)
        end
    end

    return true
end

-- what the party lacks that you would bring
local function need(leader)
    local have = { tank = 0, healer = 0, support = 0, damage = 0 }
    local members = 0
    for _, m in pairs(leader:getParty() or {}) do
        if m:getObjType() == xi.objType.PC then
            members = members + 1
            local r = roleOf(m)
            have[r] = have[r] + 1
        end
    end

    return have, members
end

local function fitsRole(have, role)
    if role == 'healer' then
        return have.healer == 0
    elseif role == 'tank' then
        return have.tank == 0
    elseif role == 'support' then
        return have.support == 0
    end

    return have.damage < 3
end

local NEED_WORDS = { healer = { 'a healer', 'a whm or rdm', 'someone to heal' }, tank = { 'a tank', 'a pld/nin', 'someone to tank' },
                     support = { 'a support job', 'brd/smn', 'support' }, damage = { 'one more dd', 'a damage dealer', 'dd' } }

-- the real levels in a party (Level Sync lowers what getMainLvl says): lowest, highest
local function realSpan(leader)
    local lo, hi = 99, 0
    for _, m in pairs(leader:getParty() or {}) do
        if m:getObjType() == xi.objType.PC then
            local ok, l = pcall(function()
                return m:getJobLevel(m:getMainJob())
            end)
            l = (ok and l and l > 0) and l or m:getMainLvl()
            lo, hi = math.min(lo, l), math.max(hi, l)
        end
    end

    return lo, hi
end

-- would you fit this party, level-wise? (a sync party: within 10 of everyone, and 10+)
local function levelFits(leader, st, plvl, kind)
    if kind == 'exp' and st.hunt and st.hunt.sync then
        local lo, hi = realSpan(leader)
        return plvl >= 10 and plvl >= hi - SYNC_SPAN and plvl <= lo + SYNC_SPAN
    end

    return math.abs(leader:getMainLvl() - plvl) <= LEVEL_RANGE
end

-- the parties that could ask you: bot exp parties at their camp, battlefield runs gathering members
local function openings(player)
    local out = {}
    local plvl = player:getMainLvl()
    for id, st in pairs(state or {}) do
        local leader = GetPlayerByID(id)
        if leader and leader:isAlive() and BotIsBot(id) then
            local kind
            if st.hunt and st.hunt.leaderOf and leader:getZoneID() == st.hunt.zone and not st.hunt.invite then
                kind = 'exp'
            elseif st.bf and st.bf.role == 'leader' and st.bf.phase == 'gather' and #(st.bf.members or {}) + 1 < (st.bf.b.max or 6) then
                kind = 'bf'
            end

            if kind and levelFits(leader, st, plvl, kind) and (asked[id .. ':' .. player:getID()] or 0) + SAME_PARTY < now() then
                local have, members = need(leader)
                local fill
                for _, r in ipairs(CAN_FILL[jobOf(player)] or { roleOf(player) }) do
                    if not fill and fitsRole(have, r) then
                        fill = r
                    end
                end

                if members < 6 and (kind == 'bf' or fill) then
                    out[#out + 1] = { leader = leader, kind = kind, st = st, have = have, members = members, fill = fill or roleOf(player) }
                end
            end
        end
    end

    return out
end

local function ask(player, o)
    local leader = o.leader
    local lid, pid = leader:getID(), player:getID()
    local lvl = leader:getMainLvl()
    local zone = zoneName(o.kind == 'bf' and o.st.bf.b.zone or o.st.hunt.zone)
    local text
    if o.kind == 'exp' and o.st.hunt.sync then
        local what = pick(NEED_WORDS[o.fill or roleOf(player)])
        local lo, hi = realSpan(leader)
        text = pick({
            string.format('hey, sync party at %s, need %s, we are %d-%d (synced to the lowest). interested?', zone, what, lo, hi),
            string.format('level sync exp in %s, need %s, %d/6. want to join?', zone, what, o.members),
            string.format('%s %d? we sync at %s, need you, inv?', jobOf(player), player:getMainLvl(), zone),
        })
    elseif o.kind == 'exp' then
        local what = pick(NEED_WORDS[o.fill or roleOf(player)])
        text = pick({
            string.format('hey, exp party at %s, need %s, lv %d-%d. interested?', zone, what, lvl - 2, lvl + 2),
            string.format('looking for %s for exp in %s (%d/6), want to join?', what, zone, o.members),
            string.format('hi! we need %s, camping %s. inv?', what, zone),
            string.format('%s %d? need you at %s, come exp with us', jobOf(player), player:getMainLvl(), zone),
        })
    else
        local b = o.st.bf.b
        local capText = b.cap > 0 and ('BCNM ' .. b.cap) or 'KSNM'
        text = pick({
            string.format('got an orb, %s at %s, want in?', capText, zone),
            string.format('%s run at %s, %d/%d, come along?', capText, zone, o.members, b.max or 6),
        })
    end

    asked[lid .. ':' .. pid] = now()
    lastAsk[pid] = now()
    BotTell(lid, player:getName(), text)
    pending[pid] = { leader = lid, kind = o.kind, at = now() }
    print(string.format('[bots] %s asks %s to join (%s at %s)', leader:getName(), player:getName(), o.kind, zone))
    leader:timer(rnd(INVITE_AFTER[1], INVITE_AFTER[2]) * 1000, function(b)
        local p = GetPlayerByID(pid)
        if p and b:isAlive() and seeking(p) then
            BotInvite(b:getID(), p)
        end
    end)
end

-- once a second from xi.bots.onTick, with the real players who are on
function I.tick(players)
    local t = now()

    -- you joined: the leader says where to go (once)
    for pid, p in pairs(pending) do
        local player = GetPlayerByID(pid)
        local leader = GetPlayerByID(p.leader)
        if not player or not leader or t - p.at > 300 then
            pending[pid] = nil
        else
            local pl = player:getPartyLeader()
            if pl and pl:getID() == p.leader and welcomed[pid] ~= p.leader then
                welcomed[pid] = p.leader
                pending[pid] = nil
                local lst = state[p.leader]
                if p.kind == 'exp' and lst and lst.hunt then
                    BotChat(p.leader, 4, pick({
                        string.format('welcome! we are at %s, come find us', zoneName(lst.hunt.zone)),
                        string.format('o/ camp is in %s, we pull while you get here', zoneName(lst.hunt.zone)),
                    }))
                    lst.hunt.untilT = math.max(lst.hunt.untilT or 0, t + 60 * 60) -- (it does not break up the party right away)
                    -- a sync party and you are its lowest now: the leader syncs to you once you are at camp
                    if lst.hunt.sync then
                        local okLvl, yours = pcall(function()
                            return player:getJobLevel(player:getMainJob())
                        end)
                        yours = (okLvl and yours) or player:getMainLvl()
                        local lo = realSpan(leader)
                        if yours <= lo then
                            lst.hunt.syncTo, lst.hunt.syncAt, lst.hunt.syncTries = pid, t + 5, 0
                            lst.hunt.huntLvl = yours
                        end
                    end
                elseif p.kind == 'bf' and lst and lst.bf then
                    lst.bf.player = pid
                    BotChat(p.leader, 4, pick({
                        string.format('welcome! meet us at the circle in %s, we wait for you', zoneName(lst.bf.b.zone)),
                        string.format('come to %s, we go in when you get here', zoneName(lst.bf.b.zone)),
                    }))
                end
            end
        end
    end

    if t < nextCheck then
        return
    end

    nextCheck = t + CHECK_EVERY
    for _, player in ipairs(players or {}) do
        local pid = player:getID()
        if (lastAsk[pid] or 0) + ASK_GAP <= t and not pending[pid] and seeking(player) then
            local list = openings(player)
            if #list > 0 and math.random() < 0.7 then
                ask(player, pick(list))
            end
        end
    end
end

-- !bots invites on|off
function I.setEnabled(player, on)
    player:setCharVar('[Bots]NoInvites', on and 0 or 1)
end

function I.enabled(player)
    return player:getCharVar('[Bots]NoInvites') ~= 1
end

-- for the tests
I._reset = function()
    nextCheck, lastAsk, asked, pending, welcomed = 0, {}, {}, {}, {}
end

return I
