-----------------------------------
-- FFXI Offline: which pet a pet job has at which level, and which Blood Pact an avatar uses.
-- Shared by squad.lua (squad mates) and bots_pets.lua (bot players). Not listed in init.txt: it is require()d.
--
-- Jug pets: the classic familiars, the best tier the master's level allows (Courier Carrie before the first tier).
-- Avatars: Carbuncle from level 1; the six elementals from 10; Fenrir joins at 60.
-- Blood Pact: Rage - the strongest physical pact of that avatar the level allows.
-----------------------------------
local D = {}

local function id(name)
    return xi.petId and xi.petId[name] or nil
end

local JUGS = {
    { 1,  { 'COURIER_CARRIE', 'HARE_FAMILIAR', 'SHEEP_FAMILIAR', 'CRAB_FAMILIAR' } },
    { 28, { 'TIGER_FAMILIAR', 'FLOWERPOT_BILL', 'FLYTRAP_FAMILIAR' } },
    { 33, { 'LIZARD_FAMILIAR', 'MAYFLY_FAMILIAR', 'EFT_FAMILIAR' } },
    { 38, { 'BEETLE_FAMILIAR', 'ANTLION_FAMILIAR' } },
    { 43, { 'MITE_FAMILIAR', 'KEENEARED_STEFFI', 'LULLABY_MELODIA' } },
    { 51, { 'FLOWERPOT_BEN', 'SABER_SIRAVARDE' } },
    { 53, { 'SHELLBUSTER_OROB', 'COLDBLOOD_COMO', 'VORACIOUS_AUDREY' } },
    { 58, { 'AMBUSHER_ALLIE' } },
    { 63, { 'PANZER_GALAHAD', 'LIFEDRINKER_LARS', 'CHOPSUEY_CHUCKY' } },
    { 75, { 'AMIGO_SABOTENDER' } },
}

local AVATARS = {
    { 1,  { 'CARBUNCLE' } },
    { 10, { 'IFRIT', 'TITAN', 'LEVIATHAN', 'GARUDA', 'SHIVA', 'RAMUH', 'CARBUNCLE' } },
    { 60, { 'IFRIT', 'TITAN', 'LEVIATHAN', 'GARUDA', 'SHIVA', 'RAMUH', 'CARBUNCLE', 'FENRIR' } },
}

-- { level, job ability name } lowest first
local RAGE = {
    CARBUNCLE = { { 5, 'POISON_NAILS' }, { 55, 'METEORITE' } },
    IFRIT     = { { 1, 'PUNCH' }, { 23, 'BURNING_STRIKE' }, { 30, 'DOUBLE_PUNCH' }, { 70, 'FLAMING_CRUSH' } },
    TITAN     = { { 1, 'ROCK_THROW' }, { 21, 'ROCK_BUSTER' }, { 35, 'MEGALITH_THROW' }, { 70, 'MOUNTAIN_BUSTER' } },
    LEVIATHAN = { { 1, 'BARRACUDA_DIVE' }, { 26, 'TAIL_WHIP' }, { 70, 'SPINNING_DIVE' } },
    GARUDA    = { { 1, 'CLAW' }, { 70, 'PREDATOR_CLAWS' } },
    SHIVA     = { { 1, 'AXE_KICK' }, { 50, 'DOUBLE_SLAP' }, { 70, 'RUSH' } },
    RAMUH     = { { 1, 'SHOCK_STRIKE' }, { 19, 'THUNDERSPARK' }, { 70, 'CHAOTIC_STRIKE' } },
    FENRIR    = { { 5, 'MOONLIT_CHARGE' }, { 10, 'CRESCENT_FANG' }, { 65, 'ECLIPSE_BITE' } },
}

-- the best tier for a level, one of its names at random that this server knows -> pet id, name
local function fromTiers(tiers, level)
    local best
    for _, tier in ipairs(tiers) do
        if level >= tier[1] then
            best = tier[2]
        end
    end

    if not best then
        return nil
    end

    local known = {}
    for _, name in ipairs(best) do
        if id(name) then
            known[#known + 1] = name
        end
    end

    if #known == 0 then
        return nil
    end

    local name = known[math.random(1, #known)]
    return id(name), name
end

function D.jugFor(level)
    return fromTiers(JUGS, level)
end

function D.avatarFor(level)
    return fromTiers(AVATARS, level)
end

local nameOfId
-- the avatar's name ('IFRIT') for a pet id
function D.avatarName(petId)
    if not nameOfId then
        nameOfId = {}
        for name in pairs(RAGE) do
            if id(name) then
                nameOfId[id(name)] = name
            end
        end
    end

    return nameOfId[petId]
end

-- the Blood Pact: Rage (job ability id) an avatar uses at this level, or nil
function D.rageFor(petId, level)
    local list = RAGE[D.avatarName(petId) or '']
    local best
    for _, e in ipairs(list or {}) do
        if level >= e[1] and xi.jobAbility and xi.jobAbility[e[2]] then
            best = xi.jobAbility[e[2]]
        end
    end

    return best
end

-- Carbuncle's healing ward (job ability id), or nil for another avatar
function D.wardFor(petId)
    if D.avatarName(petId) == 'CARBUNCLE' and xi.jobAbility then
        return xi.jobAbility.HEALING_RUBY
    end

    return nil
end

return D
