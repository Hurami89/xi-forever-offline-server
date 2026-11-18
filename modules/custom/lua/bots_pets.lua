-----------------------------------
-- FFXI Offline: bot players - pets. Used by bots.lua and bots_hunt.lua (not listed in init.txt).
--
-- A bot on a pet job has its pet out when it fights, in the field (never in town):
--   Dragoon       its wyvern
--   Beastmaster   a jug pet for its level (pets_data.lua); the pet is tended when it is hurt (as Reward does)
--   Summoner      an avatar for its level; it uses a Blood Pact: Rage when it can (the real ability: MP and
--                 the Blood Pact timer apply), and the avatar is released while the bot rests (it costs MP)
--   Puppetmaster  its automaton (the Harlequin head and frame, as the job quest gives)
-- A bot loses its pet when it changes area (it has no game window to carry it over): it calls it again at camp.
-----------------------------------
local Pets = {}

local BST, DRG, SMN, PUP = 9, 14, 15, 18
local RETRY      = 45    -- seconds between two tries to call a pet
local BP_EVERY   = 20    -- seconds between two Blood Pact tries (the server's own timer decides)
local TEND_EVERY = 90    -- seconds between two times a Beastmaster tends its pet
local SUMMON_MPP = 50    -- a Summoner needs this much MP (%) to call its avatar

local okData, data = pcall(require, 'modules/custom/lua/pets_data')
if not okData or type(data) ~= 'table' then
    print('[bots] pets are off: pets_data.lua could not be loaded: ' .. tostring(data))
    data = nil
end

local function now()
    return os.time()
end

local function petOf(bot)
    local ok, pet = pcall(function()
        return bot:getPet()
    end)
    return ok and pet or nil
end

function Pets.hasPetJob(bot)
    local job = bot:getMainJob()
    return job == BST or job == DRG or job == SMN or job == PUP
end

-- A Puppetmaster's automaton: a random frame and head, chosen once per bot and kept ([Bot]Puppet), the way a
-- player settles on a build. Bots unlock the job without doing the quest, so the parts are unlocked here.
local FRAMES = { 'HARLEQUIN', 'VALOREDGE', 'SHARPSHOT', 'STORMWAKER' }
local HEADS  = { 'HARLEQUIN', 'VALOREDGE', 'SHARPSHOT', 'STORMWAKER', 'SOULSOOTHER', 'SPIRITREAVER' }

-- its attachments, by frame (item ids from sql/item_puppet.sql; names in item_basic aren't unique, so ids):
-- what a player of that build would fit first. The game refuses ones the head and frame have no element room for.
local ATTACH = {
    VALOREDGE  = { 8449, 8545, 8451, 8450, 8453, 8546, 8577, 8454, 8641, 8609, 8610, 8643 },            -- tank
    HARLEQUIN  = { 8449, 8450, 8451, 8453, 8513, 8514, 8577, 8641, 8673, 8545, 8546, 8456 },            -- all-round
    SHARPSHOT  = { 8514, 8450, 8451, 8453, 8513, 8577, 8641, 8517, 8673, 8456, 8528, 8519 },            -- ranged
    STORMWAKER = { 8482, 8481, 8485, 8673, 8641, 8609, 8675, 8483, 8497, 8643, 8610, 8486 },            -- magic
}
local attachedKey = {}

-- how many it wants fitted by now: a couple at the start, all twelve by the 70s
local function attachCount(level)
    return math.min(12, 2 + math.floor(level / 7))
end

local function pupLevel(bot)
    return bot:getMainJob() == xi.job.PUP and bot:getMainLvl() or bot:getSubLvl()
end

local function frameOf(bot)
    local build = bot:getCharVar('[Bot]Puppet')
    return FRAMES[math.floor(build / 10)] or 'HARLEQUIN'
end

-- the attachments of its list that it owns, in its order
local function owned(bot, frame)
    local out = {}
    for _, id in ipairs(ATTACH[frame] or ATTACH.HARLEQUIN) do
        if bot:hasAttachment(id) then
            out[#out + 1] = id
        end
    end

    return out
end

-- fits what it owns (BotSetAttachments, bots.cpp), up to its count for its level; again only when that changes
local function fitAttachments(bot, frame)
    if not BotSetAttachments then
        return
    end

    local have = owned(bot, frame)
    local key = frame .. ':' .. attachCount(pupLevel(bot)) .. ':' .. #have
    if attachedKey[bot:getID()] == key then
        return
    end

    attachedKey[bot:getID()] = key
    BotSetAttachments(bot:getID(), have, attachCount(pupLevel(bot)))
end

-- in town now and then (with its gear shopping, bots.lua): a Puppetmaster buys the next attachments on its list it
-- doesn't own yet, up to its count for its level, when it can spare the gil (about the shop price; keeps half its
-- gil). They are fitted the next time it calls its automaton. Returns how many it bought.
function Pets.buyAttachments(bot)
    if bot:getMainJob() ~= xi.job.PUP and bot:getSubJob() ~= xi.job.PUP then
        return 0
    end

    local frame = frameOf(bot)
    local want = attachCount(pupLevel(bot)) - #owned(bot, frame)
    local bought = 0
    for _, id in ipairs(ATTACH[frame] or ATTACH.HARLEQUIN) do
        if bought >= math.min(want, 2) then
            break
        end

        if not bot:hasAttachment(id) then
            local okP, price = pcall(function()
                return GetItemByID(id):getBasePrice()
            end)
            price = (okP and tonumber(price) and price > 0) and price or 1500
            if bot:getGil() < price * 2 then
                break -- (saves up for this one before the next)
            end

            bot:delGil(price)
            bot:unlockAttachment(id)
            bought = bought + 1
        end
    end

    return bought
end

local function automatonReady(bot)
    return pcall(function()
        if bot:getAutomatonName() == '' then
            bot:setPetName(xi.petType.AUTOMATON, xi.petName.MK_IV)
        end

        local build = bot:getCharVar('[Bot]Puppet')
        if build == 0 then
            build = math.random(1, #FRAMES) * 10 + math.random(1, #HEADS)
            bot:setCharVar('[Bot]Puppet', build)
        end

        local frame = FRAMES[math.floor(build / 10)] or 'HARLEQUIN'
        local head = HEADS[build % 10] or 'HARLEQUIN'
        for _, item in ipairs({ frame .. '_FRAME', head .. '_HEAD' }) do
            if xi.item[item] and not bot:hasAttachment(xi.item[item]) then
                bot:unlockAttachment(xi.item[item])
            end
        end

        if bot:getAutomatonFrame() ~= xi.automaton.frame[frame] then
            bot:setAutomatonFrame(xi.automaton.frame[frame])
        end

        if bot:getAutomatonHead() ~= xi.automaton.head[head] then
            bot:setAutomatonHead(xi.automaton.head[head])
        end

        fitAttachments(bot, frame)
    end)
end

-- calls its pet when it has none (st: the table the fight keeps its timers in)
function Pets.ensure(bot, st)
    if not data or not Pets.hasPetJob(bot) or bot:isDead() or petOf(bot) then
        return
    end

    local t = now()
    if t < (st.petNext or 0) then
        return
    end

    st.petNext = t + RETRY
    st.petTarget = nil
    local job, lvl = bot:getMainJob(), bot:getMainLvl()
    local petId
    if job == DRG then
        petId = xi.petId and xi.petId.WYVERN
    elseif job == BST then
        petId = data.jugFor(lvl)
    elseif job == SMN then
        if bot:getMaxMP() == 0 or bot:getMPP() < SUMMON_MPP then
            return
        end

        petId = data.avatarFor(lvl)
    elseif job == PUP then
        if not automatonReady(bot) then
            st.petNext = t + 3600
            return
        end

        petId = xi.petId and xi.petId.AUTOMATON
    end

    if not petId then
        return
    end

    local ok, err = pcall(function()
        bot:spawnPet(petId)
    end)
    if not ok then
        st.petNext = t + 3600
        print(string.format('[bots] %s could not call its pet (%s): %s', bot:getName(), tostring(petId), tostring(err)))
    end
end

-- one fighting turn: the pet is out, it goes for the target, and the job's own pet actions
function Pets.fight(bot, st, target)
    if not data or not Pets.hasPetJob(bot) or not target then
        return
    end

    Pets.ensure(bot, st)
    local pet = petOf(bot)
    if not pet then
        return
    end

    local t = now()
    local tid = target:getID()
    -- (sent again every 10 s: a pet that was only just called may miss the first order)
    if st.petTarget ~= tid or t >= (st.petOrderAt or 0) then
        st.petTarget, st.petOrderAt = tid, t + 10
        pcall(function()
            bot:petAttack(target)
        end)
    end

    local job = bot:getMainJob()
    if job == SMN and t >= (st.bpNext or 0) then
        st.bpNext = t + BP_EVERY
        local okId, pid = pcall(function()
            return pet:getPetID()
        end)
        local pact = okId and data.rageFor(pid, bot:getMainLvl()) or nil
        if pact and BotAbility then
            BotAbility(bot:getID(), pact, target)
        end
    elseif job == BST and t >= (st.tendNext or 0) then
        local okHp, hpp = pcall(function()
            return pet:getHPP()
        end)
        if okHp and hpp and hpp > 0 and hpp < 50 then
            st.tendNext = t + TEND_EVERY
            pcall(function()
                pet:addHP(math.floor(pet:getMaxHP() * 0.3))
            end)
        end
    end
end

-- resting: an avatar costs MP every tick, so a Summoner lets it go
function Pets.rest(bot, st)
    if bot:getMainJob() == SMN and petOf(bot) then
        pcall(function()
            bot:despawnPet()
        end)
        st.petNext, st.petTarget = 0, nil
    end
end

return Pets
