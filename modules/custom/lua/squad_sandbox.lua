-----------------------------------
-- squad_sandbox.lua  (Deed + Jon, 2026-11-21)
-- Training grounds for squad / gambit tests: !sandbox   (version 1.0.1)
-- Rolanberry Fields, by the Lower Jeuno exit. Dummies take real damage, never die and do not attack.
-- You place each one yourself, so you choose the open ground and the spacing for every positioning test.
--   !sandbox here <level>   put the dummy of that level where you stand (levels 1,10,20..70,75,80,90,99); again moves it
--   !sandbox clear [level]  remove one dummy, or all
--   !sandbox go <level>     walk to that dummy
--   !sandbox status         which dummies are up, where, and their HP
--   !sandbox hate           who each dummy has hate on right now (the dummy also turns to face that one, and logs every change)
--   !sandbox save           keep where every dummy stands (squad_sandbox_spots.lua, next to this file)
--   !sandbox load           put every saved dummy back (also tried by itself when the server starts)
--   !sandbox log on|off     write [sandbox] lines to the server log
-----------------------------------
require('modules/module_utils')
SQUAD_SANDBOX = SQUAD_SANDBOX or {}
local S = SQUAD_SANDBOX

-- (2026-11-21, Hurami) off unless the launcher's "Training dummies" switch is on (squad_config.lua training_dummies):
-- a testing tool, so ordinary worlds never see dummies in Rolanberry Fields.
function S.enabled()
    local ok, c = pcall(function()
        package.loaded['modules/custom/lua/squad_config'] = nil
        return require('modules/custom/lua/squad_config')
    end)
    return ok and type(c) == 'table' and c.training_dummies == true
end
S.VERSION = '1.0.1'

S.ZONE    = 110                                      -- Rolanberry Fields
S.NAME    = 'Dummy'                                  -- each dummy is named this plus its level: Dummy Lv. 75 (the game cuts names near 15 letters)
S.LEVELS  = { 1, 10, 20, 30, 40, 50, 60, 70, 75, 80, 90, 99 }
S.GROUP   = S.GROUP or { groupId = 1, groupZoneId = 110 }      -- a mob group in this zone for the dynamic entity
S.mobs    = S.mobs or {}                             -- level -> live dummy
S.spots   = S.spots or {}                            -- level -> { x, y, z, r }, kept for this server run
S.logOn   = S.logOn == nil and true or S.logOn

local function say(player, text)
    if player and player.printToPlayer then player:printToPlayer(text, 0, 'Sandbox') end
end

local function log(text)
    if S.logOn then print('[sandbox] ' .. text) end
end

local function validLevel(level)
    for _, l in ipairs(S.LEVELS) do if l == level then return true end end
    return false
end

-- who this dummy has hate on: its battle target, with the enmity list as a fallback
local function hateTarget(mob)
    local t = nil
    pcall(function() t = mob:getTarget() end)
    if t ~= nil then return t end
    pcall(function()
        local list = mob:getEnmityList()
        local best, top = nil, -1
        for _, e in pairs(list or {}) do
            local v = (e.ce or 0) + (e.ve or 0)
            if e.entity ~= nil and v > top then best, top = e.entity, v end
        end
        t = best
    end)
    return t
end

-- keeps a dummy alive and harmless, turns it to face whoever has its hate, and logs when that changes
local function keepUp(mob)
    if mob:getHPP() < 60 then mob:setHP(mob:getMaxHP()) end
    local t = hateTarget(mob)
    local id = t and t:getID() or 0
    if t ~= nil then pcall(function() mob:lookAt(t:getPos()) end) end
    if id ~= mob:getLocalVar('SBX_HATE') then
        mob:setLocalVar('SBX_HATE', id)
        log(string.format('%s hate on %s', mob:getName(), t and t:getName() or 'nobody'))
    end
end

local function dress(mob, level)
    mob:setMobLevel(level)
    -- same calls Macro_Test uses, minus its "take no damage" mods: damage lands, the dummy just cannot die
    local ok, err = pcall(function() mob:setUnkillable(true) end)
    if not ok then log('setUnkillable failed: ' .. tostring(err)) end
    pcall(function() mob:setMobMod(xi.mobMod.NO_MOVE, 1) end)
    pcall(function() mob:setAutoAttackEnabled(false) end)
    pcall(function() mob:setMobAbilityEnabled(false) end)
    pcall(function() mob:setMagicCastingEnabled(false) end)
    pcall(function() mob:setMobMod(xi.mobMod.NO_DROPS, 1) end)
    pcall(function() mob:setMobMod(xi.mobMod.GIL_MAX, -1) end)
    pcall(function() mob:setMobMod(xi.mobMod.EXP_BONUS, -100) end)
    pcall(function() mob:setHP(mob:getMaxHP()) end)
    -- top up after every kind of hit (the same listener names Macro_Test uses), not only on the fight tick
    local function topUp(m) pcall(function() if m:getHPP() < 60 then m:setHP(m:getMaxHP()) end end) end
    pcall(function() mob:addListener('ATTACKED', 'SBX_ATTACKED', function(m) topUp(m) end) end)
    pcall(function() mob:addListener('ABILITY_TAKE', 'SBX_ABILITY', function(m) topUp(m) end) end)
    pcall(function() mob:addListener('MAGIC_TAKE', 'SBX_MAGIC', function(m) topUp(m) end) end)
    pcall(function() mob:addListener('WEAPONSKILL_TAKE', 'SBX_WS', function(m) topUp(m) end) end)
end

-- saved spots live in squad_sandbox_spots.lua next to this file; the patch carries it
local function here()
    local src = debug.getinfo(1, 'S').source or ''
    local dir = src:sub(1, 1) == '@' and src:sub(2):match('^(.*[/\\])') or nil
    return dir or 'modules/custom/lua/'
end

function S.spotsPath() return here() .. 'squad_sandbox_spots.lua' end                 -- yours, written by !sandbox save
function S.defaultSpotsPath() return here() .. 'squad_sandbox_spots.default.lua' end  -- ships with the module; used until you save your own

function S.save()
    local f, err = io.open(S.spotsPath(), 'w')
    if not f then return false, tostring(err) end
    f:write('-- saved by !sandbox save (' .. os.date('%Y-%m-%d %H:%M') .. ')\nreturn {\n')
    local n = 0
    for _, l in ipairs(S.LEVELS) do
        local sp = S.spots[l]
        if sp then
            f:write(string.format('    [%d] = { x = %.2f, y = %.2f, z = %.2f, r = %d },\n', l, sp.x, sp.y, sp.z, sp.r or 0))
            n = n + 1
        end
    end
    f:write('}\n'); f:close()
    return true, n
end

function S.load()
    local ok, data = pcall(dofile, S.spotsPath())
    if not ok or type(data) ~= 'table' then
        ok, data = pcall(dofile, S.defaultSpotsPath())
    end
    if not ok or type(data) ~= 'table' then return 0 end
    local n = 0
    for _, l in ipairs(S.LEVELS) do
        local sp = data[l]
        if sp and S.place(l, sp.x, sp.y, sp.z, sp.r) then n = n + 1 end
    end
    return n
end

function S.remove(level)
    local mob = S.mobs[level]
    if mob then pcall(function() DespawnMob(mob:getID()) end) end
    S.mobs[level] = nil
end

-- one dummy of this level at this spot; a second call for the same level moves it
function S.place(level, x, y, z, r)
    S.remove(level)
    local zone = GetZone(S.ZONE)
    if zone == nil then return false, 'Rolanberry Fields is not loaded' end
    local ok, mob = pcall(function()
        return zone:insertDynamicEntity({
            objtype = xi.objType.MOB,
            name = S.NAME .. ' Lv. ' .. level,
            minLevel = level, maxLevel = level,           -- without these the server defaults to level 255
            x = x, y = y, z = z, rotation = r,
            groupId = S.GROUP.groupId, groupZoneId = S.GROUP.groupZoneId,
            releaseIdOnDisappear = true,
            onMobSpawn = function(m) dress(m, level) end,
            onMobFight = function(m) keepUp(m) end,
        })
    end)
    if not (ok and mob) then
        log('could not place dummy Lv' .. level .. ': ' .. tostring(mob))
        return false, tostring(mob)
    end
    mob:setSpawn(x, y, z, r)
    mob:spawn()
    S.mobs[level] = mob
    S.spots[level] = { x = x, y = y, z = z, r = r }
    log(string.format('dummy Lv%d at %.1f,%.1f,%.1f', level, x, y, z))
    return true
end

function S.handle(player, line)
    if not S.enabled() then
        say(player, 'Training dummies are off. Turn on "Training dummies" in the launcher (Rates tab, Squad and AI), then STOP and PLAY.')
        return
    end
    local w = {}
    for word in string.gmatch(line or '', '%S+') do w[#w + 1] = string.lower(word) end
    local act = w[1] or 'status'
    local level = tonumber(w[2] or '')

    if act == 'here' then
        if not validLevel(level) then say(player, 'Use !sandbox here <level>. Levels: ' .. table.concat(S.LEVELS, ', ')) return end
        if player:getZoneID() ~= S.ZONE then say(player, 'Go to Rolanberry Fields first.') return end
        local ok, why = S.place(level, player:getXPos(), player:getYPos(), player:getZPos(), player:getRotPos())
        say(player, ok and ('Lv' .. level .. ' dummy placed where you stand. It cannot die and does not attack.')
                       or ('Could not place it: ' .. tostring(why) .. ' (see the server log).'))
    elseif act == 'clear' then
        if level and validLevel(level) then S.remove(level); S.spots[level] = nil; say(player, 'Lv' .. level .. ' dummy removed.')
        else for _, l in ipairs(S.LEVELS) do S.remove(l); S.spots[l] = nil end say(player, 'All dummies removed.') end
    elseif act == 'go' then
        local spot = level and S.spots[level]
        if spot == nil then say(player, 'No Lv' .. tostring(level) .. ' dummy placed yet.') return end
        player:setPos(spot.x - 4, spot.y, spot.z, spot.r); say(player, 'At the Lv' .. level .. ' dummy.')
    elseif act == 'hate' then
        local n = 0
        for _, l in ipairs(S.LEVELS) do
            local mob = S.mobs[l]
            if mob then
                n = n + 1
                local t = hateTarget(mob)
                say(player, string.format('Lv%d  hate on %s', l, t and t:getName() or 'nobody'))
            end
        end
        if n == 0 then say(player, 'No dummies up. Use !sandbox load.') end
    elseif act == 'save' then
        local ok, n = S.save()
        say(player, ok and (n .. ' dummy spots saved. Run the patch export to put them in the patch.') or ('Could not save: ' .. tostring(n)))
    elseif act == 'load' then
        local n = S.load()
        say(player, n > 0 and (n .. ' dummies placed from the saved spots.') or 'No saved or default spots (or Rolanberry is not loaded). Place them with !sandbox here <level>, then !sandbox save.')
    elseif act == 'log' then
        S.logOn = w[2] ~= 'off'; say(player, 'Sandbox log ' .. (S.logOn and 'on' or 'off') .. '.')
    else
        local n = 0
        for _, l in ipairs(S.LEVELS) do
            local mob = S.mobs[l]
            if mob then
                n = n + 1
                local sp = S.spots[l]
                say(player, string.format('Lv%d  HP %d%%  at %.0f, %.0f', l, mob:getHPP(), sp.x, sp.z))
            end
        end
        if n == 0 then say(player, 'No dummies. Stand where you want one and type !sandbox here <level>.') end
    end
end

-- put saved dummies back when Rolanberry Fields starts; if this server has no such hook, !sandbox load does the same by hand
pcall(function()
    if Module and Module.new then
        local m = Module:new('squad_sandbox')
        -- (2026-11-21) this server hands the original to an override as the global super(), not as an argument
        m:addOverride('xi.zones.Rolanberry_Fields.Zone.onInitialize', function(zone)
            super(zone)
            if S.enabled() then
                pcall(S.load)
            end
        end)
        S.module = m
    end
end)

if xi and xi.module and xi.module.registerCommand then
    local command = { cmdprops = { permission = 0, parameters = 's' } }
    command.onTrigger = function(player, line)
        local ok, err = pcall(S.handle, player, line)
        if not ok then print('[sandbox] failed: ' .. tostring(err)); say(player, 'Sandbox command failed (see the server log).') end
    end
    xi.module.registerCommand('sandbox', command)
end

return S
