-----------------------------------
-- Weapon skills for finished weapon skill quests (XI: Forever Offline, 2026-11-27)
--
-- Craig: "after doing a char. transfer ... quested weapon skills (e.g. Steel Cyclone) don't show up as a weapon skill
-- even though the actual quest shows as completed".
--
-- Each of the fourteen weapon skill quests teaches its weapon skill at the moment it is finished here
-- (player:addLearnedWeaponskill in scripts/quests), and what a character has learned is kept apart from the quest
-- log (chars.weaponskills). A character whose quest log arrived finished another way never learned the weapon skill:
-- one transferred from another server (char_import.py brings the quest log; the learned weapon skills are not in the
-- snapshot), or a quest completed with a GM command. And a finished quest cannot be done again.
-- At log in, a finished weapon skill quest whose weapon skill is not learned teaches it, and one line says which.
-- Weapon skills are only added, never taken away. The mythic weapon skills (the Unlocking a Myth quests) are not in
-- the list.
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('quested_weaponskills')

-- quest log, quest table, quest, weapon skill (xi.wsUnlock), its name in the game
local quests =
{
    { 'BASTOK',   'bastok',   'THE_WALLS_OF_YOUR_MIND',          'ASURAN_FISTS',   'Asuran Fists'   },
    { 'OUTLANDS', 'outlands', 'CLOAK_AND_DAGGER',                'EVISCERATION',   'Evisceration'   },
    { 'SANDORIA', 'sandoria', 'OLD_WOUNDS',                      'SAVAGE_BLADE',   'Savage Blade'   },
    { 'BASTOK',   'bastok',   'INHERITANCE',                     'GROUND_STRIKE',  'Ground Strike'  },
    { 'JEUNO',    'jeuno',    'AXE_THE_COMPETITION',             'DECIMATION',     'Decimation'     },
    { 'BASTOK',   'bastok',   'THE_WEIGHT_OF_YOUR_LIMITS',       'STEEL_CYCLONE',  'Steel Cyclone'  },
    { 'SANDORIA', 'sandoria', 'SOULS_IN_SHADOW',                 'SPIRAL_HELL',    'Spiral Hell'    },
    { 'SANDORIA', 'sandoria', 'METHODS_CREATE_MADNESS',          'IMPULSE_DRIVE',  'Impulse Drive'  },
    { 'OUTLANDS', 'outlands', 'BUGI_SODEN',                      'BLADE_KU',       'Blade: Ku'      },
    { 'OUTLANDS', 'outlands', 'THE_POTENTIAL_WITHIN',            'TACHI_KASHA',    'Tachi: Kasha'   },
    { 'WINDURST', 'windurst', 'ORASTERY_WOES',                   'BLACK_HALO',     'Black Halo'     },
    { 'WINDURST', 'windurst', 'BLOOD_AND_GLORY',                 'RETRIBUTION',    'Retribution'    },
    { 'WINDURST', 'windurst', 'FROM_SAPLINGS_GROW',              'EMPYREAL_ARROW', 'Empyreal Arrow' },
    { 'BASTOK',   'bastok',   'SHOOT_FIRST_ASK_QUESTIONS_LATER', 'DETONATOR',      'Detonator'      },
}

local function teach(player)
    local taught = {}
    for _, entry in ipairs(quests) do
        local log = xi.questLog[entry[1]]
        local ids = xi.quest.id[entry[2]]
        local id  = ids and ids[entry[3]]
        local ws  = xi.wsUnlock[entry[4]]
        if
            log and id and ws and
            player:getQuestStatus(log, id) == xi.questStatus.QUEST_COMPLETED and
            not player:hasLearnedWeaponskill(ws)
        then
            player:addLearnedWeaponskill(ws)
            taught[#taught + 1] = entry[5]
        end
    end

    if #taught > 0 then
        player:printToPlayer(
            'Your finished weapon skill quests count here now. Learned: ' .. table.concat(taught, ', ') .. '.',
            xi.msg.channel.SYSTEM_3)
    end
end

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    local result = super(player, firstLogin, zoning)

    if zoning or not player or not player:isPC() then
        return result
    end

    -- a mistake here must never break what the other modules do at log in
    local ok, err = pcall(teach, player)
    if not ok then
        print('[quested_weaponskills] ' .. tostring(err))
    end

    return result
end)

return m
