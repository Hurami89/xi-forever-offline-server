-----------------------------------
-- Hardcore cosmetic wardrobe (XI: Forever Offline, 2026-11-27, the user)
--
-- With classic bags (CONFIG > Rates, full bags off) a hardcore character (Iron, Steel, Silver, Randomized) has Mog
-- Wardrobe 8 open at 80 slots from the start, for costumes and event gear only. Wardrobe 8 is the one no mission or
-- quest opens (Phoenix's wardrobe unlocks open 1-4), so nothing a hardcore player earns is given away early.
-- The C++ half (custom/cpp/hardcore_wardrobe.cpp) refuses anything else moved into it.
-- With full bags every wardrobe is already open at 80 for everyone, so this does nothing.
--
-- The list: Phoenix's cosmetic wardrobe list (modules/phoenix/lua/data/cosmetic_wardrobe_items.lua), the hardcore
-- milestone cosmetics (xi.hardcore.cosmeticPool) and the Forever items below.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('hardcore_wardrobe')

local EXTRA =
{
    23867, -- Forever Patch
    23868, -- Forever Jeans
    25725, -- Forever Beta Shirt
}

local function classicBags()
    local ok, cfg = pcall(require, 'modules/custom/lua/storage_config')
    return ok and type(cfg) == 'table' and cfg.full_bags == false
end

local function buildList()
    local allowed, count = {}, 0
    local function add(itemId)
        if type(itemId) == 'number' and not allowed[itemId] and
            (type(GetReadOnlyItem) ~= 'function' or GetReadOnlyItem(itemId) ~= nil)
        then
            allowed[itemId] = true
            count = count + 1
        end
    end

    local ok, list = pcall(require, 'modules/phoenix/lua/data/cosmetic_wardrobe_items')
    if ok and type(list) == 'table' then
        for _, itemId in pairs(list) do
            add(itemId)
        end
    end

    if xi.hardcore and type(xi.hardcore.cosmeticPool) == 'function' then
        for _, itemId in ipairs(xi.hardcore.cosmeticPool()) do
            add(itemId)
        end
    end

    for _, itemId in ipairs(EXTRA) do
        add(itemId)
    end

    return allowed, count
end

m:addOverride('xi.server.onServerStart', function()
    -- published before super(), as Phoenix's cosmetic wardrobe does: another module's error must not leave it unset
    xi.hardcore = xi.hardcore or {}
    if classicBags() then
        local allowed, count = buildList()
        xi.hardcore.cosmeticWardrobe = allowed
        print(string.format('hardcore_wardrobe: Mog Wardrobe 8 is the hardcore cosmetic wardrobe (%d items allowed)', count))
    else
        xi.hardcore.cosmeticWardrobe = nil
    end

    super()
end)

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    local result = super(player, firstLogin, zoning)
    if zoning or not (xi.hardcore and xi.hardcore.cosmeticWardrobe) or xi.hardcore.isHub then
        return result
    end

    if (BotIsBot and BotIsBot(player:getID())) or type(xi.hardcore.mode) ~= 'function' or xi.hardcore.mode(player) == 0 then
        return result
    end

    local size = player:getContainerSize(xi.inv.WARDROBE8)
    if size < 80 then
        player:changeContainerSize(xi.inv.WARDROBE8, 80 - size)
        player:printToPlayer('Your Mog Wardrobe 8 is open: 80 slots for costumes and event gear (hardcore cosmetic wardrobe).', xi.msg.channel.SYSTEM_3)
    end

    return result
end)

return m
