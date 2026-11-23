-----------------------------------
-- Casino Dealer (XI: Forever Offline, 2026-11-21, idea by The-Yache)
-- A dealer in Southern San d'Oria, Bastok Markets, Windurst Woods and Lower Jeuno. Trade gil, pick "Roll", and you and
-- the dealer each roll 0-999 (the same range as /random). Roll higher and you get double your bet back; a tie gives the
-- bet back; roll lower and the bet is gone.
--
-- Why the NPC rolls for the player: the server's /random is answered inside the map server and never reaches a script,
-- and /random is blocked while an NPC event is open, so a script cannot read the player's own /random.
--
-- Safety: the trade is never confirmed, so nothing is taken until "Roll" is chosen; the gil is checked again at that
-- moment, taken, and the result paid at once. Closing the menu or leaving costs nothing.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('casino_dealer')

local MAX_ROLL = 1000 -- rolls are 0-999

local dealers =
{
    { zone = 'Southern_San_dOria', x = 47.5,   y = 2,   z = -34.5, rot = 170 },
    { zone = 'Bastok_Markets',     x = -325.0, y = -12, z = -33.0, rot = 128 },
    { zone = 'Windurst_Woods',     x = 12.0,   y = -2,  z = 0.0,   rot = 128 },
    { zone = 'Lower_Jeuno',        x = 21.0,   y = -1,  z = 54.0,  rot = 128 },
}

local DEALER_NAME = 'Lucky Dealer'
local LOOK        = '0x0100020500101120003000400050006000700000' -- a Hume (m), same format as the examples in test_npcs_in_gm_home.lua

local function say(player, npc, text)
    player:printToPlayer(text, 0, npc:getPacketName())
end

local function gilText(n)
    local s = tostring(n)
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return (out:gsub('^,', ''))
end

-- Change the player's gil by one amount in ONE step (not "take the bet, then pay double"), then check the balance
-- really moved. Returns true when it did. If add/del did not take, it sets the balance directly as a fallback.
local function changeGil(player, delta)
    local before = player:getGil()

    if delta > 0 then
        player:addGil(delta)
    elseif delta < 0 then
        player:delGil(-delta)
    end

    if player:getGil() == before + delta then
        return true
    end

    player:setGil(before + delta)

    if player:getGil() == before + delta then
        print(string.format('[casino_dealer] add/del did not change gil for %s; set it directly instead', player:getName()))
        return true
    end

    print(string.format('[casino_dealer] could not change gil for %s by %d (had %d, has %d)', player:getName(), delta, before, player:getGil()))
    return false
end

local function play(player, npc, bet)
    player:setFreezeFlag(false)

    if bet <= 0 or player:getGil() < bet then
        say(player, npc, 'You do not have that much gil any more.')
        return
    end

    local mine   = math.random(0, MAX_ROLL - 1)
    local theirs = math.random(0, MAX_ROLL - 1)

    -- what the bet does to the player's gil: win +bet (the bet is kept and doubled), tie 0, lose -bet
    local delta = 0
    if mine > theirs then
        delta = bet
    elseif mine < theirs then
        delta = -bet
    end

    if delta ~= 0 and not changeGil(player, delta) then
        say(player, npc, 'Something went wrong with the gil, so the bet is off. Nothing was taken.')
        return
    end

    say(player, npc, string.format('Dice Roll! %s rolls %d.', player:getName(), mine))
    say(player, npc, string.format('Dice Roll! %s rolls %d.', DEALER_NAME, theirs))

    if delta > 0 then
        say(player, npc, string.format('You win! Your %s gil is doubled: you now have %s gil more.', gilText(bet), gilText(bet)))
    elseif delta == 0 then
        say(player, npc, 'A tie! Your bet is returned.')
    else
        say(player, npc, string.format('The house wins. You lose %s gil.', gilText(bet)))
    end
end

local function offerBet(player, npc, bet)
    player:setFreezeFlag(true)
    player:customMenu({
        title = string.format('Bet %s gil?', gilText(bet)),
        options =
        {
            {
                'Roll the dice!',
                function(playerArg)
                    -- run after the menu closes
                    playerArg:timer(50, function(entity)
                        play(entity, npc, bet)
                    end)
                end,
            },
            {
                'Never mind.',
                function(playerArg)
                    playerArg:setFreezeFlag(false)
                end,
            },
        },
        onCancelled = function(playerArg)
            playerArg:setFreezeFlag(false)
        end,
        onEnd = function(playerArg)
            playerArg:setFreezeFlag(false)
        end,
    })
end

local function onTrade(player, npc, trade)
    local bet = trade:getGil()

    -- gil in a trade takes one slot, so a gil-only trade has an item count of 1 (like other gil trades in the scripts)
    if bet > 0 and trade:getItemCount() == 1 then
        -- nothing is taken yet: the trade is not confirmed, the gil stays with the player
        offerBet(player, npc, bet)
    else
        say(player, npc, 'Gil only, please. Trade me the amount you want to bet.')
    end
end

local function onTrigger(player, npc)
    say(player, npc, 'Feeling lucky? Trade me the gil you want to bet. We each roll 0 to 999. Roll higher and I double your gil; a tie gives it back.')
end

local spawned = {}

local function spawnDealer(zone, d)
    local npc = zone:insertDynamicEntity({
        objtype    = xi.objType.NPC,
        name       = 'CasinoDealer_' .. d.zone,
        packetName = DEALER_NAME,
        look       = LOOK,
        x          = d.x,
        y          = d.y,
        z          = d.z,
        rotation   = d.rot,
        widescan   = 1,
        onTrade    = onTrade,
        onTrigger  = onTrigger,
    })

    if npc then
        spawned[d.zone] = npc:getID()
    end
end

for _, d in ipairs(dealers) do
    local dealer = d

    m:addOverride('xi.zones.' .. dealer.zone .. '.Zone.onInitialize', function(zone)
        super(zone)

        local ok, err = pcall(spawnDealer, zone, dealer)
        if not ok then
            print('[casino_dealer] ' .. dealer.zone .. ': ' .. tostring(err))
        end
    end)
end

return m
