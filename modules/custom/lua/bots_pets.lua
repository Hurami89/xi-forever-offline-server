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
