-----------------------------------
-- Quest waits (XI: Forever Offline, 2026-11-18; Frost, Miniberg, Yache asked)
--
-- A launcher switch (CONFIG > Rates, "Short quest waits", on by default) shortens waits that only make sense on a
-- busy retail server. Off = the era waits again. The launcher writes modules/custom/lua/quest_waits_config.lua.
--   * Chocobo's Wounds: era = one Vana'diel day between feedings (about 58 minutes, six times); short = 1 minute.
--   * Forge Your Destiny (SAM, Mumeito): era = three Vana'diel days at the forge (about 2.9 hours); short = 1 hour.
-- Both store the wait as a real time (seconds), so switching mid-quest never leaves anyone stuck.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('quest_waits')

local function shortWaits()
    package.loaded['modules/custom/lua/quest_waits_config'] = nil
    local ok, cfg = pcall(require, 'modules/custom/lua/quest_waits_config')
    if ok and type(cfg) == 'table' and cfg.short ~= nil then
        return cfg.short == true
    end

    return true -- (no file yet: the default)
end

-- seconds until the next Vana'diel day starts (a Vana'diel hour = 144 s, a minute = 2.4 s)
local function toNextVanaDay()
    return math.max(60, math.floor((24 - VanadielHour()) * 144 - VanadielMinute() * 2.4))
end

m:addOverride('xi.server.onServerStart', function()
    super()

    local short = shortWaits()

    -- Chocobo's Wounds: take the retail quest (real-time Timer) and set the wait after each feeding ourselves. The era
    -- module had replaced it with a Vana'diel day check; this keeps that wait in era mode, measured in real seconds.
    local okC, errC = pcall(xi.module.modifyInteractionEntry, 'scripts/quests/jeuno/Chocobos_Wounds', function(quest)
        local finish = quest.sections[2][xi.zone.UPPER_JEUNO].onEventFinish
        for _, csid in ipairs({ 57, 58, 59, 60, 99 }) do
            local original = finish[csid]
            if original then
                finish[csid] = function(player, ...)
                    original(player, ...)
                    quest:setVar(player, 'Timer', GetSystemTime() + (short and 60 or toNextVanaDay()))
                end
            end
        end
    end)
    if not okC then
        print('[quest_waits] Chocobo\'s Wounds not changed: ' .. tostring(errC))
    end

    -- Forge Your Destiny: the forging wait after trading the Bomb Steel and Sacred Branch
    local okF, errF = pcall(xi.module.modifyInteractionEntry, 'scripts/quests/outlands/Forge_Your_Destiny', function(quest)
        for _, section in ipairs(quest.sections) do
            for _, zoneTable in pairs(section) do
                if type(zoneTable) == 'table' and type(zoneTable.onEventFinish) == 'table' and zoneTable.onEventFinish[27] and
                    zoneTable['Jaucribaix'] then
                    local original = zoneTable.onEventFinish[27]
                    zoneTable.onEventFinish[27] = function(player, ...)
                        original(player, ...)
                        if short then
                            quest:setVar(player, 'waitTime', GetSystemTime() + 3600)
                        end
                    end
                end
            end
        end
    end)
    if not okF then
        print('[quest_waits] Forge Your Destiny not changed: ' .. tostring(errF))
    end

    print(string.format('[quest_waits] %s waits (Chocobo\'s Wounds, Forge Your Destiny)', short and 'short' or 'era'))
end)

return m
