-----------------------------------
-- Era pages only in the Fields of Valor / Grounds of Valor books (FFXI Offline)
--
-- The books list every training page of the zone, including pages added after the 75 era for monsters of level 76-99
-- (King Ranperre's Tomb, for example, has pages 6-8 for level 77-83 monsters). This hides every page whose lowest
-- monster level is above MAX_LEVEL, using the book's own "which pages to show" bitmask. Everything else is exactly what
-- scripts/globals/regimes.lua does (this is its bookOnTrigger with the extra pages hidden).
-- The page list is read from regimes.lua itself, so new pages from a Phoenix update are covered.
-----------------------------------
require('modules/module_utils')
require('scripts/globals/regimes')
-----------------------------------
local m = Module:new('regime_era_pages')

local MAX_LEVEL = 75

-- regimes.lua keeps its page list in a local table; borrow it from the function that uses it
local regimeInfo = nil
local function findRegimeInfo(fn)
    if regimeInfo ~= nil or type(fn) ~= 'function' or debug == nil or debug.getupvalue == nil then
        return regimeInfo
    end

    for i = 1, 200 do
        local name, value = debug.getupvalue(fn, i)
        if name == nil then
            break
        end

        if name == 'regimeInfo' and type(value) == 'table' then
            regimeInfo = value
            break
        end
    end

    return regimeInfo
end

findRegimeInfo(xi.regime.bookOnTrigger)
if regimeInfo == nil then
    print('[regime_era_pages] could not read the page list from regimes.lua - the books are left as they are')
end

m:addOverride('xi.regime.bookOnTrigger', function(player, regimeType)
    local all  = findRegimeInfo(super)
    local book = all and all[regimeType]
    local info = book and book.zone and book.zone[player:getZoneID()]
    if
        info == nil or
        player:getCharVar('[hunt]status') >= 1 or
        not ((regimeType == xi.regime.type.FIELDS and xi.settings.main.ENABLE_FIELD_MANUALS == 1) or
             (regimeType == xi.regime.type.GROUNDS and xi.settings.main.ENABLE_GROUNDS_TOMES == 1))
    then
        return super(player, regimeType)
    end

    local cipher = 0 -- Trust Alter Ego Extravaganza
    local active = xi.extravaganza.campaignActive()
    if active == xi.extravaganza.campaign.SPRING_FALL or active == xi.extravaganza.campaign.BOTH then
        cipher = 3
    end

    -- arg2: a bit for each page NOT to show (bit i = page i): pages that do not exist, and pages above the era's levels
    local pages = #info.page
    local arg2  = 0
    for i = 1, 10 do
        local page = info.page[i]
        if i > pages or (page ~= nil and (page[5] or 0) > MAX_LEVEL) then
            arg2 = arg2 + 2 ^ i
        end
    end

    local arg4 = player:hasKeyItem(xi.keyItem.RHAPSODY_IN_WHITE) and 1 or 0

    player:startEvent(info.event, 0, arg2, cipher, arg4, 0, 0, player:getCurrency('valor_point'), player:getCharVar('[regime]id'))
end)
