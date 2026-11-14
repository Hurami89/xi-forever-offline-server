-----------------------------------
-- !nmcheck <monster name>     (any character)
-- Tells you whether a monster (usually a notorious monster) in your current area is up right now, and where.
-- When it is not up, it says how it spawns (lottery chance and cooldown, read from the server's zone data)
-- and how long ago it was last killed, so you know whether the cooldown is still running.
-- Example: !nmcheck Fungus Beetle
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('nmcheck')

local lastDeath = {} -- [mob id] = os.time() of its last death since the server started

local function channel()
    return (xi.msg and xi.msg.channel and xi.msg.channel.SYSTEM_3) or 0
end

local function tell(player, text)
    player:printToPlayer(text, channel())
end

local function minutes(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds < 60 then
        return string.format('%d s', seconds)
    end

    return string.format('%d min %02d s', math.floor(seconds / 60), seconds % 60)
end

-- "fungus beetle" -> "Fungus_Beetle" (the server's internal names use capitals and underscores)
local function internalNames(text)
    local plain = string.gsub(text, '%s+', '_')
    local titled = string.gsub(string.lower(text), "(%a)([%w']*)", function(first, rest)
        return string.upper(first) .. rest
    end)
    titled = string.gsub(titled, '%s+', '_')
    local out = { plain, titled }
    -- small words stay lower case in names like "Bubbly_of_Ronfaure"
    out[#out + 1] = string.gsub(titled, '_(Of|The|De|La)_', function(word) return '_' .. string.lower(word) .. '_' end)
    return out
end

local function findMobs(zone, text)
    for _, name in ipairs(internalNames(text)) do
        local found = zone:queryEntitiesByName(name)
        local mobs = {}
        for _, entity in ipairs(found or {}) do
            if entity:isMob() then
                mobs[#mobs + 1] = entity
            end
        end

        if #mobs > 0 then
            return mobs
        end
    end

    return {}
end

-- Lottery settings of one spawn, from data/zones/<zone>/mobs.yaml:   17187047: {chance: 15, cooldown: 900}
local slotCache = {}
local function slotInfo(zoneName, mobId)
    local key = string.lower(zoneName)
    if slotCache[key] == nil then
        local info = {}
        local file = io.open(string.format('data/zones/%s/mobs.yaml', key), 'r')
        if file then
            for line in file:lines() do
                local id, rest = string.match(line, '^%s+(%d+):%s*(%b{})')
                if id and rest then
                    info[tonumber(id)] = {
                        chance   = tonumber(string.match(rest, 'chance:%s*(%d+)')),
                        cooldown = tonumber(string.match(rest, 'cooldown:%s*(%d+)')),
                    }
                end
            end

            file:close()
        end

        slotCache[key] = info
    end

    return slotCache[key][mobId]
end

local function describe(player, mob)
    local name = string.gsub(mob:getName(), '_', ' ')
    if mob:isSpawned() and mob:isAlive() then
        local pos = mob:getPos()
        tell(player, string.format('%s is UP: %d yalms from you (x %.0f, z %.0f), HP %d%%.',
            name, math.floor(player:checkDistance(mob)), pos.x, pos.z, mob:getHPP()))
        return
    end

    local now   = os.time()
    local slot  = slotInfo(player:getZoneName(), mob:getID())
    local died  = lastDeath[mob:getID()]
    local since = died and (now - died) or nil

    local how = ''
    if slot and slot.chance then
        how = string.format(' It has a %d%% chance to appear each time its placeholder dies.', slot.chance)
    end

    local wait = ''
    if slot and slot.cooldown and slot.cooldown > 0 then
        if since and since < slot.cooldown then
            wait = string.format(' Killed %s ago: cooldown still running, ready in %s.', minutes(since), minutes(slot.cooldown - since))
        elseif since then
            wait = string.format(' Killed %s ago: the %s cooldown is over, it can pop now.', minutes(since), minutes(slot.cooldown))
        else
            wait = ' Not killed since the server started: no cooldown, it can pop now.'
        end
    elseif since then
        wait = string.format(' Last killed %s ago.', minutes(since))
    end

    tell(player, string.format('%s is not up.%s%s', name, how, wait))
end

m:addOverride('xi.mob.onMobDeathEx', function(mob, player, isKiller, isWeaponSkillKill)
    super(mob, player, isKiller, isWeaponSkillKill)

    if isKiller then
        lastDeath[mob:getID()] = os.time()
    end
end)

local command = {}
command.cmdprops = { permission = 0, parameters = 'ssssss' }

command.onTrigger = function(player, ...)
    local words = {}
    for _, word in ipairs({ ... }) do
        if word ~= nil and word ~= '' then
            words[#words + 1] = word
        end
    end

    if #words == 0 then
        tell(player, 'Usage: !nmcheck <monster name>   for example  !nmcheck Fungus Beetle   (checks the area you are in)')
        return
    end

    local text = table.concat(words, ' ')
    local zone = player:getZone()
    local mobs = zone and findMobs(zone, text) or {}
    if #mobs == 0 then
        tell(player, string.format('No monster called "%s" in %s. Check the spelling, or go to its area first.', text, player:getZoneName()))
        return
    end

    for _, mob in ipairs(mobs) do
        describe(player, mob)
    end
end

xi.module.registerCommand('nmcheck', command)

return m
