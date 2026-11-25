-----------------------------------
-- Squad Summoners, the full job (2026-11-24, Hurami: "yes go ahead")
--
-- Used by squad.lua's pet loop (petTick / squadPetId) and by squad_logic.lua's party chat.
--   * Which avatar: per mate, chosen by you (!squad avatar <mate> <avatar|auto>, or party chat "Ayame Ifrit"),
--     or Auto: the avatar whose element the target takes the most damage from (swaps when a new fight starts).
--     Char var on you: SQUAD_AVATAR_<mate id> = index in S.AVATARS, 0 = Auto.
--   * Ward pacts (own 60 s timer): heals first (Healing Ruby / II, Whispering Wind, Spring Water), then
--     debuffs on the target (Slowga, Lunar Cry), then buffs you are missing (Shining Ruby, Hastega, Aerial Armor,
--     Earthen Ward, Frost Armor, Rolling Thunder, Lightning Armor, Crimson Howl, Ecliptic Growl/Howl, Glittering Ruby).
--   * Rage pacts stay in squad.lua (strongest for the level, own 60 s timer).
--   * Astral Flow: by itself on a notorious monster under 70% (once per 2 hours a mate, char var SQUAD_AF_<mate id>),
--     or when you say "2hr" / "Ayame 2hr"; the avatar then uses its own Astral Flow pact (Inferno, Earthen Fury...).
--   * "release": the avatar leaves for a minute (saves MP); "<mate> auto" goes back to Auto.
-- MP: the pact scripts charge the mate their real cost (job_utils/summoner.lua); here we only check it can pay.
-- Everything is pcall'd by the callers: a fault here never stops a mate.
-----------------------------------
local S = {}

S.AVATARS = { 'CARBUNCLE', 'IFRIT', 'TITAN', 'LEVIATHAN', 'GARUDA', 'SHIVA', 'RAMUH', 'FENRIR' }
S.LEVEL   = { CARBUNCLE = 1, IFRIT = 10, TITAN = 10, LEVIATHAN = 10, GARUDA = 10, SHIVA = 10, RAMUH = 10, FENRIR = 60 }
S.ELEMENT = { CARBUNCLE = 'LIGHT', IFRIT = 'FIRE', TITAN = 'EARTH', LEVIATHAN = 'WATER', GARUDA = 'WIND', SHIVA = 'ICE',
              RAMUH = 'THUNDER', FENRIR = 'DARK' }
S.ASTRAL  = { CARBUNCLE = 'SEARING_LIGHT', IFRIT = 'INFERNO', TITAN = 'EARTHEN_FURY', LEVIATHAN = 'TIDAL_WAVE',
              GARUDA = 'AERIAL_BLAST', SHIVA = 'DIAMOND_DUST', RAMUH = 'JUDGMENT_BOLT', FENRIR = 'HOWLING_MOON' }

S.WARD_SECONDS   = 60
S.SWAP_SECONDS   = 45
S.RELEASE_SECONDS = 60
S.AF_SECONDS     = 7200

-- kind: heal1 (one member under 50%), healall (2+ under 60% or one under 40%), debuff (target lacks effect),
-- buff (you lack effect), timed (every `every` seconds in a fight). cost = the pact's base MP (job_utils/summoner.lua).
S.WARDS =
{
    CARBUNCLE = {
        { 65, 'HEALING_RUBY_II', 'healall', cost = 124 },
        { 1,  'HEALING_RUBY',    'heal1',   cost = 6 },
        { 24, 'SHINING_RUBY',    'buff',    cost = 44, effect = 'SHINING_RUBY', idle = true },
        { 44, 'GLITTERING_RUBY', 'timed',   cost = 62, every = 300 },
    },
    IFRIT     = { { 38, 'CRIMSON_HOWL', 'buff', cost = 84, effect = 'WARCRY' } },
    TITAN     = { { 46, 'EARTHEN_WARD', 'buff', cost = 92, effect = 'STONESKIN' } },
    LEVIATHAN = {
        { 47, 'SPRING_WATER', 'healall', cost = 99 },
        { 33, 'SLOWGA',       'debuff',  cost = 48, effect = 'SLOW' },
    },
    GARUDA    = {
        { 36, 'WHISPERING_WIND', 'healall', cost = 119 },
        { 48, 'HASTEGA',         'buff',    cost = 129, effect = 'HASTE', idle = true },
        { 25, 'AERIAL_ARMOR',    'buff',    cost = 92,  effect = 'BLINK' },
    },
    SHIVA     = { { 28, 'FROST_ARMOR', 'buff', cost = 63, effect = 'ICE_SPIKES' } },
    RAMUH     = {
        { 31, 'ROLLING_THUNDER', 'buff', cost = 52, effect = 'ENTHUNDER' },
        { 42, 'LIGHTNING_ARMOR', 'buff', cost = 91, effect = 'SHOCK_SPIKES' },
    },
    FENRIR    = {
        { 21, 'LUNAR_CRY',      'debuff', cost = 41, effect = 'ACCURACY_DOWN' },
        { 54, 'ECLIPTIC_HOWL',  'buff',   cost = 57, effect = 'ACCURACY_BOOST' },
        { 43, 'ECLIPTIC_GROWL', 'timed',  cost = 46, every = 300 },
    },
}

local function petIdOf(name)
    return xi.petId and xi.petId[name] or nil
end

local function ability(name)
    return xi.jobAbility and xi.jobAbility[name] or nil
end

function S.nameOfPet(petId)
    for _, name in ipairs(S.AVATARS) do
        if petIdOf(name) == petId then
            return name
        end
    end

    return nil
end

function S.indexOf(word)
    word = string.upper(tostring(word or ''))
    for i, name in ipairs(S.AVATARS) do
        if name == word then
            return i
        end
    end

    return nil
end

local function pretty(name)
    return name:sub(1, 1) .. name:sub(2):lower()
end

-- can this summoner call `name`? has(name) = you have the pact (nil = every avatar its level allows)
function S.allowed(name, level, has)
    if not S.LEVEL[name] or level < S.LEVEL[name] or not petIdOf(name) then
        return false, string.format('%s needs level %d', pretty(name), S.LEVEL[name] or 99)
    end

    if has ~= nil and name ~= 'CARBUNCLE' and not has(name) then
        return false, string.format('you have no pact with %s yet (win its trial fight)', pretty(name))
    end

    return true
end

-- damage taken multiplier of the target against an element (1.0 = normal); nil if it can't be read
local function weakness(target, element)
    if not (xi.combat and xi.combat.damage and xi.combat.damage.magicalElementSDT and xi.element and xi.element[element]) then
        return nil
    end

    local ok, v = pcall(xi.combat.damage.magicalElementSDT, target, xi.element[element])
    return ok and tonumber(v) or nil
end

-- the best allowed avatar against the target (nil = nothing stands out)
function S.bestFor(target, level, has)
    local best, bestV = nil, 1.05
    for _, name in ipairs(S.AVATARS) do
        if S.allowed(name, level, has) then
            local v = weakness(target, S.ELEMENT[name])
            if v and v > bestV then
                best, bestV = name, v
            end
        end
    end

    return best, bestV
end

function S.choiceVar(mateId)
    return 'SQUAD_AVATAR_' .. tostring(mateId)
end

-- the pet id squadPetId should summon: your choice when it is allowed, else nil (= the old random pick)
function S.pickId(mob, master, level, has)
    if master == nil then
        return nil
    end

    local idx = master:getCharVar(S.choiceVar(mob:getLocalVar('SQUAD_ID')))
    local name = S.AVATARS[idx]
    if name and S.allowed(name, level, has) then
        return petIdOf(name)
    end

    return nil
end

-- swap the mate's avatar now (next pet tick summons it)
local function swapTo(mob, name, now)
    mob:setLocalVar('SQUAD_PET_PICK', petIdOf(name))
    mob:setLocalVar('SQUAD_PET_NEXT', 0)
    mob:setLocalVar('SMN_SWAP_NEXT', now + S.SWAP_SECONDS)
    pcall(function() mob:despawnPet() end)
end

local function members(master)
    local out = {}
    local ok, list = pcall(function() return master:getPartyWithTrusts() end)
    for _, m in pairs(ok and list or {}) do
        if m ~= nil and m:isAlive() then
            out[#out + 1] = m
        end
    end

    return out
end

local function hasEffect(entity, effect)
    local id = xi.effect and xi.effect[effect]
    return id ~= nil and entity:hasStatusEffect(id)
end

-- the ward to use now, or nil: abilityId, target, entry
function S.chooseWard(mob, pet, master, target, level, name, now)
    local list = S.WARDS[name]
    if not list then
        return nil
    end

    local party = members(master)
    local lowest, low60, low40 = nil, 0, false
    for _, m in ipairs(party) do
        local hpp = m:getHPP()
        if lowest == nil or hpp < lowest:getHPP() then
            lowest = m
        end
        if hpp < 60 then low60 = low60 + 1 end
        if hpp < 40 then low40 = true end
    end

    local fighting = target ~= nil and target:isAlive()
    local mp = mob:getMP()
    local order = { 'healall', 'heal1', 'debuff', 'buff', 'timed' }
    for _, kind in ipairs(order) do
        for _, w in ipairs(list) do
            local id = ability(w[2])
            if w[3] == kind and level >= w[1] and id and mp >= (w.cost or 0) then
                if kind == 'healall' and (low60 >= 2 or low40) then
                    return id, master, w
                elseif kind == 'heal1' and lowest ~= nil and lowest:getHPP() < 50 then
                    return id, lowest, w
                elseif kind == 'debuff' and fighting and target:isMob() and not hasEffect(target, w.effect) then
                    return id, target, w
                elseif kind == 'buff' and (fighting or w.idle) and master:isAlive() and not hasEffect(master, w.effect) then
                    return id, master, w
                elseif kind == 'timed' and fighting and now >= mob:getLocalVar('SMN_T_' .. w[2]) then
                    mob:setLocalVar('SMN_T_' .. w[2], now + (w.every or 300))
                    return id, master, w
                end
            end
        end
    end

    return nil
end

-- the pet loop for a Summoner mate. Returns true when it used a pact this tick (squad.lua then skips its Rage).
function S.tick(mob, pet, master, target, level, now, has)
    local name = S.nameOfPet(pet:getPetID())
    if name == nil or master == nil then
        return false
    end

    local mateId = mob:getLocalVar('SQUAD_ID')
    local fighting = target ~= nil and target:isAlive()

    -- Auto: a new fight against something weak to another element brings that avatar
    if fighting and master:getCharVar(S.choiceVar(mateId)) == 0 then
        local tid = target:getID()
        if mob:getLocalVar('SMN_LAST_TGT') ~= tid then
            mob:setLocalVar('SMN_LAST_TGT', tid)
            local best, v = S.bestFor(target, level, has)
            local mine = weakness(target, S.ELEMENT[name]) or 1
            if best and best ~= name and v >= mine + 0.15 and now >= mob:getLocalVar('SMN_SWAP_NEXT') then
                swapTo(mob, best, now)
                return true
            end
        end
    end

    -- Astral Flow: asked for ("2hr" gives the mate the effect) or by itself on a notorious monster under 70%
    local afId = xi.effect and xi.effect.ASTRAL_FLOW
    if afId and fighting then
        local flowing = mob:hasStatusEffect(afId)
        if not flowing and target:isMob() and target:isNM() and target:getHPP() <= 70
            and os.time() >= master:getCharVar('SQUAD_AF_' .. mateId) then
            master:setCharVar('SQUAD_AF_' .. mateId, os.time() + S.AF_SECONDS)
            mob:addStatusEffect(afId, { power = 1, duration = 180, origin = mob })
            flowing = true
        end

        if flowing and mob:getLocalVar('SMN_AF_USED') == 0 then
            local pact = ability(S.ASTRAL[name])
            if pact then
                mob:setLocalVar('SMN_AF_USED', 1)
                pet:usePetAbility(pact, target)
                return true
            end
        end
    elseif afId and not mob:hasStatusEffect(afId) then
        mob:setLocalVar('SMN_AF_USED', 0)
    end

    -- Ward pacts on their own timer
    if now >= mob:getLocalVar('SQUAD_WARD_NEXT') then
        local id, who = S.chooseWard(mob, pet, master, target, level, name, now)
        if id then
            mob:setLocalVar('SQUAD_WARD_NEXT', now + S.WARD_SECONDS)
            pet:usePetAbility(id, who)
            return true
        end
    end

    return false
end

-- set a mate's avatar (nil index = Auto); swaps right away if the mate is out. Returns the message to show.
function S.setChoice(player, mateId, mateName, idx, outMate, has)
    player:setCharVar(S.choiceVar(mateId), idx or 0)
    if idx == nil then
        return string.format('%s picks the avatar by itself (Auto).', mateName)
    end

    local name = S.AVATARS[idx]
    if outMate ~= nil then
        local ok, why = S.allowed(name, outMate:getMainLvl(), has)
        if not ok then
            return string.format('%s will bring %s when it can (%s).', mateName, pretty(name), why)
        end

        swapTo(outMate, name, GetSystemTime and GetSystemTime() or os.time())
    end

    return string.format('%s will bring %s.', mateName, pretty(name))
end

-- party chat: "Ayame Ifrit", "Ifrit" (the first Summoner out), "all Shiva", "release", "Ayame auto", "avatar auto".
-- words = the line after the mate's name was taken off. true = handled.
function S.chat(player, askedMates, everyone, named, words, has)
    local smns = {}
    for _, m in ipairs(askedMates) do
        if m:getMainJob() == xi.job.SMN then
            smns[#smns + 1] = m
        end
    end

    if #smns == 0 or #words == 0 or #words > 2 then
        return false
    end

    local line = table.concat(words, ' ')
    local idx, auto, release = S.indexOf(words[#words]), false, false
    if line == 'avatar auto' or (named and line == 'auto') then
        auto = true
    elseif line == 'release' or line == 'release avatar' then
        release = true
    elseif idx == nil or (#words == 2 and words[1] ~= 'avatar' and words[1] ~= 'summon' and words[1] ~= 'call') then
        return false
    end

    local targets = everyone and smns or { smns[1] }
    for _, m in ipairs(targets) do
        local mateName = m:getPacketName()
        if release then
            m:setLocalVar('SQUAD_PET_NEXT', (GetSystemTime and GetSystemTime() or os.time()) + S.RELEASE_SECONDS)
            pcall(function() m:despawnPet() end)
            player:printToPlayer(string.format('%s releases the avatar for a minute.', mateName))
        else
            player:printToPlayer(S.setChoice(player, m:getLocalVar('SQUAD_ID'), mateName, (not auto) and idx or nil, m, has))
        end
    end

    return true
end

-- !squad avatar [mate] [avatar|auto]
function S.command(player, squad, mateWord, avatarWord, outMates, has)
    local function list()
        local parts = {}
        for _, mate in ipairs(squad or {}) do
            if mate.mjob == xi.job.SMN then
                local idx = player:getCharVar(S.choiceVar(mate.id))
                parts[#parts + 1] = string.format('%s: %s', mate.name, S.AVATARS[idx] and pretty(S.AVATARS[idx]) or 'Auto')
            end
        end
        return #parts > 0 and table.concat(parts, ', ') or 'No Summoner in your squad.'
    end

    if mateWord == nil or mateWord == '' then
        player:printToPlayer('Avatars: ' .. list() .. '. Use !squad avatar <mate> <carbuncle|ifrit|titan|leviathan|garuda|shiva|ramuh|fenrir|auto>.')
        return
    end

    local mate = nil
    for _, m in ipairs(squad or {}) do
        if string.lower(m.name) == string.lower(mateWord) then
            mate = m
        end
    end

    if mate == nil then
        player:printToPlayer('No squad mate called ' .. mateWord .. '.')
        return
    end

    local word = string.lower(avatarWord or '')
    local idx = S.indexOf(word)
    if word ~= 'auto' and idx == nil then
        player:printToPlayer('Pick one of: carbuncle, ifrit, titan, leviathan, garuda, shiva, ramuh, fenrir, auto.')
        return
    end

    local out = outMates and outMates[mate.id] or nil
    player:printToPlayer(S.setChoice(player, mate.id, mate.name, idx, out, has))
end

return S
