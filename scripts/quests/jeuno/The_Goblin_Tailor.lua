-----------------------------------
-- The Goblin Tailor
-----------------------------------
-- Log ID: 3, Quest ID: 42
-- Guttrix : !pos -36.010 4.499 -139.714 245
-----------------------------------

local quest = Quest:new(xi.questLog.JEUNO, xi.quest.id.jeuno.THE_GOBLIN_TAILOR)

local rseTable =
{
    -- [race] = { body, hands, legs, feet }
    [xi.race.HUME_M  ] = { xi.item.CUSTOM_TUNIC,     xi.item.CUSTOM_M_GLOVES,  xi.item.CUSTOM_SLACKS,    xi.item.CUSTOM_M_BOOTS    },
    [xi.race.HUME_F  ] = { xi.item.CUSTOM_VEST,      xi.item.CUSTOM_F_GLOVES,  xi.item.CUSTOM_PANTS,     xi.item.CUSTOM_F_BOOTS    },
    [xi.race.ELVAAN_M] = { xi.item.MAGNA_JERKIN,     xi.item.MAGNA_GAUNTLETS,  xi.item.MAGNA_M_CHAUSSES, xi.item.MAGNA_M_LEDELSENS },
    [xi.race.ELVAAN_F] = { xi.item.MAGNA_BODICE,     xi.item.MAGNA_GLOVES,     xi.item.MAGNA_F_CHAUSSES, xi.item.MAGNA_F_LEDELSENS },
    [xi.race.TARU_M  ] = { xi.item.WONDER_KAFTAN,    xi.item.WONDER_MITTS,     xi.item.WONDER_BRACCAE,   xi.item.WONDER_CLOMPS     },
    [xi.race.TARU_F  ] = { xi.item.WONDER_KAFTAN,    xi.item.WONDER_MITTS,     xi.item.WONDER_BRACCAE,   xi.item.WONDER_CLOMPS     },
    [xi.race.MITHRA  ] = { xi.item.SAVAGE_SEPARATES, xi.item.SAVAGE_GAUNTLETS, xi.item.SAVAGE_LOINCLOTH, xi.item.SAVAGE_GAITERS    },
    [xi.race.GALKA   ] = { xi.item.ELDERS_SURCOAT,   xi.item.ELDERS_BRACERS,   xi.item.ELDERS_BRAGUETTE, xi.item.ELDERS_SANDALS    },
}

-----------------------------------
-- FFXI Solo: do the quest for any race (choose with !rse). By default it is your own race.
--   chosenRace : the race whose gear you are collecting
--   anyDay     : (!rse day) the chests give the Magical Pattern on any day, in any of the three zones
-- Each race keeps its own record of which pieces you already have.
-----------------------------------
local function chosenRace(player)
    local chosen = player:getCharVar('[RSE]ChosenRace')
    if chosen >= 1 and chosen <= 8 then
        return chosen
    end

    return player:getRace()
end

local function gearVar(player)
    if chosenRace(player) == player:getRace() then
        return '[RSE]Gear'
    end

    return '[RSE]Gear' .. chosenRace(player)
end

local function chestGivesPattern(player, location)
    if player:hasKeyItem(xi.keyItem.MAGICAL_PATTERN) then
        return false
    end

    if player:getCharVar('[RSE]AnyDay') == 1 then
        return true
    end

    return VanadielRSELocation() == location and VanadielRSERace() == chosenRace(player)
end

quest.reward =
{
    title = xi.title.GOBLINS_EXCLUSIVE_FASHION_MANNEQUIN,
}

quest.sections =
{
    {
        check = function(player, status, vars)
            return status == xi.questStatus.QUEST_AVAILABLE
        end,

        [xi.zone.LOWER_JEUNO] =
        {
            ['Guttrix'] =
            {
                onTrigger = function(player, npc)
                    if
                        player:getMainLvl() >= 10 and
                        player:getFameLevel(xi.fameArea.JEUNO) >= 3
                    then
                        return quest:progressEvent(10016, VanadielRSELocation(), VanadielRSERace())
                    else
                        return quest:event(10020)
                    end
                end,
            },

            onEventFinish =
            {
                [10016] = function(player, csid, option, npc)
                    quest:begin(player)
                end,
            },
        },
    },

    {
        check = function(player, status, vars)
            return status >= xi.questStatus.QUEST_ACCEPTED
        end,

        [xi.zone.GUSGEN_MINES] =
        {
            ['Treasure_Chest' ] =
            {
                onTrade = function(player, npc, trade)
                    if chestGivesPattern(player, 1) then
                        xi.treasure.onTrade(player, npc, trade, 2, xi.keyItem.MAGICAL_PATTERN)

                        return quest:noAction()
                    end
                end,
            },
        },

        [xi.zone.LOWER_JEUNO] =
        {
            ['Guttrix'] =
            {
                onTrigger = function(player, npc)
                    local rseTracker = player:getCharVar(gearVar(player))
                    if rseTracker == 15 then
                        return quest:event(10019)
                    end

                    if player:getMainLvl() < 10 then
                        return quest:event(10020)
                    end

                    if player:hasKeyItem(xi.keyItem.MAGICAL_PATTERN) then
                        return quest:progressEvent(10018, rseTracker)
                    else
                        return quest:event(10017, VanadielRSELocation(), VanadielRSERace())
                    end
                end,
            },

            onEventFinish =
            {
                [10018] = function(player, csid, option, npc)
                    if not player:hasKeyItem(xi.keyItem.MAGICAL_PATTERN) then
                        return
                    end

                    if option < 1 then
                        return
                    end

                    if option > 4 then
                        return
                    end

                    local rseTracker = player:getCharVar(gearVar(player))
                    if utils.mask.getBit(rseTracker, option - 1) then
                        return
                    end

                    if chosenRace(player) == player:getRace() and player:getFreeSlotsCount() < 2 then
                        -- (XI: Forever Offline) your own race's piece comes with a spare for your squad: room for both
                        player:printToPlayer('Make room for two items (one is a spare for your squad), then talk to Guttrix again.', xi.msg.channel.SYSTEM_3)
                        return
                    end

                    if npcUtil.giveItem(player, rseTable[chosenRace(player)][option]) then
                        player:delKeyItem(xi.keyItem.MAGICAL_PATTERN)
                        player:incrementCharVar(gearVar(player), bit.lshift(1, option - 1))

                        -- XI: Forever Offline: your own race's piece comes with a spare to give your squad
                        -- (trade it to a mate or !squad give). Other races' pieces can be made again, so no spare.
                        if chosenRace(player) == player:getRace() then
                            local piece = rseTable[chosenRace(player)][option]
                            if player:addItem(piece) then
                                player:messageSpecial(zones[player:getZoneID()].text.ITEM_OBTAINED, piece)
                                player:printToPlayer('Guttrix: And a spare one, for that squad of yours!', xi.msg.channel.NS_SAY)
                            end
                        end

                        quest:complete(player)
                        player:addFame(xi.fameArea.SANDORIA, 5)
                        player:addFame(xi.fameArea.BASTOK, 5)
                        player:addFame(xi.fameArea.WINDURST, 5)
                    end
                end,
            },
        },

        [xi.zone.MAZE_OF_SHAKHRAMI] =
        {
            ['Treasure_Chest' ] =
            {
                onTrade = function(player, npc, trade)
                    if chestGivesPattern(player, 2) then
                        xi.treasure.onTrade(player, npc, trade, 2, xi.keyItem.MAGICAL_PATTERN)

                        return quest:noAction()
                    end
                end,
            },
        },

        [xi.zone.ORDELLES_CAVES] =
        {
            ['Treasure_Chest' ] =
            {
                onTrade = function(player, npc, trade)
                    if chestGivesPattern(player, 0) then
                        xi.treasure.onTrade(player, npc, trade, 2, xi.keyItem.MAGICAL_PATTERN)

                        return quest:noAction()
                    end
                end,
            },
        },
    },
}

return quest
