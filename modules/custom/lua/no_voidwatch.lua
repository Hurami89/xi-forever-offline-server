-- Written by make_no_voidwatch.py from this server's own zone data: 457 Voidwatch NPCs in 90 zones.
-- Voidwatch is not implemented here, so its NPCs only stand around doing nothing. This makes them invisible when you zone in.
-- Remove it with:  python make_no_voidwatch.py --undo
-----------------------------------
require('modules/module_utils')
-----------------------------------
local m = Module:new('no_voidwatch')

local HIDDEN =
{
    [4] = { 16794038, 16794039, 16794040, 16794041, 16794042, 16794043 },   -- Planar Rift, Riftworn Pyxis
    [5] = { 16798145, 16798146, 16798147, 16798148, 16798149, 16798150 },   -- Planar Rift, Riftworn Pyxis
    [7] = { 16806377, 16806378, 16806379, 16806380, 16806381, 16806382 },   -- Planar Rift, Riftworn Pyxis
    [24] = { 16875911, 16875912, 16875913, 16875914, 16875915, 16875916 },   -- Planar Rift, Riftworn Pyxis
    [25] = { 16879990, 16879991, 16879992, 16879993, 16879994, 16879995 },   -- Planar Rift, Riftworn Pyxis
    [26] = { 16883890, 16883892 },   -- Atmacite Refiner, Owain
    [48] = { 16974394, 16974406, 16974407 },   -- Sujyahn, Voidwatch Purveyor
    [50] = { 16982636 },   -- Voidwatch Purveyor
    [51] = { 16986841 },   -- Atmacite Refiner
    [53] = { 16994438 },   -- Voidwatch Purveyor
    [54] = { 16999069, 16999070, 16999071, 16999072, 16999073, 16999074 },   -- Planar Rift, Riftworn Pyxis
    [61] = { 17027622, 17027623, 17027624, 17027625, 17027626, 17027627 },   -- Planar Rift, Riftworn Pyxis
    [65] = { 17044053, 17044054, 17044055, 17044056, 17044057, 17044058 },   -- Planar Rift, Riftworn Pyxis
    [68] = { 17056475, 17056476, 17056477, 17056478, 17056479, 17056480 },   -- Planar Rift, Riftworn Pyxis
    [79] = { 17101393, 17101394, 17101395, 17101396, 17101397, 17101398 },   -- Planar Rift, Riftworn Pyxis
    [80] = { 17105695, 17105696, 17105697 },   -- Atmacite Refiner, Voidwatch Officer, Voidwatch Purveyor
    [81] = { 17109851, 17109852, 17109853, 17109854, 17109855, 17109856 },   -- Planar Rift, Riftworn Pyxis
    [82] = { 17114041, 17114042, 17114043, 17114044, 17114045, 17114046 },   -- Planar Rift, Riftworn Pyxis
    [83] = { 17118043, 17118044, 17118045, 17118046, 17118047, 17118048 },   -- Planar Rift, Riftworn Pyxis
    [84] = { 17122256, 17122257, 17122258, 17122259, 17122260, 17122261, 17122262, 17122263 },   -- Atmacite Refiner, Planar Rift, Riftworn Pyxis, Voidwatch Officer
    [87] = { 17134277, 17134278, 17134279 },   -- Atmacite Refiner, Voidwatch Officer, Voidwatch Purveyor
    [88] = { 17138607, 17138608, 17138609, 17138610, 17138611, 17138612 },   -- Planar Rift, Riftworn Pyxis
    [89] = { 17142619, 17142620, 17142621, 17142622, 17142623, 17142624 },   -- Planar Rift, Riftworn Pyxis
    [90] = { 17146652, 17146653, 17146654, 17146655, 17146656, 17146657, 17146658 },   -- Planar Rift, Riftworn Pyxis, Veridical Conflux
    [91] = { 17150837, 17150838, 17150839, 17150840, 17150841, 17150842 },   -- Planar Rift, Riftworn Pyxis
    [94] = { 17163019, 17163020, 17163021 },   -- Atmacite Refiner, Voidwatch Officer, Voidwatch Purveyor
    [95] = { 17167320, 17167321, 17167322, 17167323, 17167324, 17167325 },   -- Planar Rift, Riftworn Pyxis
    [96] = { 17171281, 17171282, 17171283, 17171284, 17171285, 17171286 },   -- Planar Rift, Riftworn Pyxis
    [97] = { 17175423, 17175424, 17175425, 17175426, 17175427, 17175428 },   -- Planar Rift, Riftworn Pyxis
    [98] = { 17179517, 17179518, 17179519, 17179520, 17179521, 17179522, 17179523, 17179524 },   -- Atmacite Refiner, Planar Rift, Riftworn Pyxis, Voidwatch Officer
    [100] = { 17187554, 17187555, 17187556, 17187557, 17187558, 17187559 },   -- Planar Rift, Riftworn Pyxis
    [101] = { 17191577, 17191578, 17191579, 17191580, 17191581, 17191582 },   -- Planar Rift, Riftworn Pyxis
    [102] = { 17195690, 17195691, 17195692, 17195693, 17195694, 17195695 },   -- Planar Rift, Riftworn Pyxis
    [103] = { 17199764, 17199765, 17199766, 17199767, 17199768, 17199769 },   -- Planar Rift, Riftworn Pyxis
    [104] = { 17203939, 17203940, 17203941, 17203942, 17203943, 17203944 },   -- Planar Rift, Riftworn Pyxis
    [105] = { 17207936, 17207937, 17207938, 17207939, 17207940, 17207941, 17207942, 17207943 },   -- Atmacite Refiner, Planar Rift, Riftworn Pyxis, Voidwatch Officer
    [106] = { 17212116, 17212117, 17212118, 17212119, 17212120, 17212121 },   -- Planar Rift, Riftworn Pyxis
    [107] = { 17216194, 17216195, 17216196, 17216197, 17216198, 17216199 },   -- Planar Rift, Riftworn Pyxis
    [108] = { 17220178, 17220179, 17220180, 17220181, 17220182, 17220183 },   -- Planar Rift, Riftworn Pyxis
    [109] = { 17224371, 17224372, 17224373, 17224374, 17224375, 17224376 },   -- Planar Rift, Riftworn Pyxis
    [110] = { 17228390, 17228391, 17228392, 17228393, 17228394, 17228395, 17228396, 17228397 },   -- Atmacite Refiner, Planar Rift, Riftworn Pyxis, Voidwatch Officer
    [111] = { 17232315, 17232316, 17232317, 17232318, 17232319, 17232320 },   -- Planar Rift, Riftworn Pyxis
    [115] = { 17248914, 17248915, 17248916, 17248917, 17248918, 17248919 },   -- Planar Rift, Riftworn Pyxis
    [116] = { 17253091, 17253092, 17253093, 17253094, 17253095, 17253096 },   -- Planar Rift, Riftworn Pyxis
    [117] = { 17257088, 17257089, 17257090, 17257091, 17257092, 17257093 },   -- Planar Rift, Riftworn Pyxis
    [118] = { 17261219, 17261220, 17261221, 17261222, 17261223, 17261224 },   -- Planar Rift, Riftworn Pyxis
    [119] = { 17265315, 17265316, 17265317, 17265318, 17265319, 17265320 },   -- Planar Rift, Riftworn Pyxis
    [120] = { 17269275, 17269276, 17269277, 17269278, 17269279, 17269280, 17269281, 17269282 },   -- Atmacite Refiner, Planar Rift, Riftworn Pyxis, Voidwatch Officer
    [121] = { 17273429, 17273430, 17273431, 17273432, 17273433, 17273434 },   -- Planar Rift, Riftworn Pyxis
    [122] = { 17277250, 17277251, 17277252, 17277253, 17277254, 17277255 },   -- Planar Rift, Riftworn Pyxis
    [123] = { 17281667, 17281668, 17281669, 17281670, 17281671, 17281672 },   -- Planar Rift, Riftworn Pyxis
    [125] = { 17289810, 17289811, 17289812, 17289813, 17289814, 17289815 },   -- Planar Rift, Riftworn Pyxis
    [126] = { 17293808, 17293809, 17293810, 17293811, 17293812, 17293813, 17293814, 17293815 },   -- Atmacite Refiner, Planar Rift, Riftworn Pyxis, Voidwatch Officer
    [127] = { 17297502, 17297503, 17297504, 17297505, 17297506, 17297507 },   -- Planar Rift, Riftworn Pyxis
    [130] = { 17310115, 17310116, 17310117, 17310118, 17310119, 17310120 },   -- Planar Rift, Riftworn Pyxis
    [153] = { 17404408, 17404409, 17404410, 17404411, 17404412, 17404413 },   -- Planar Rift, Riftworn Pyxis
    [159] = { 17429023, 17429024, 17429025, 17429026, 17429027, 17429028 },   -- Planar Rift, Riftworn Pyxis
    [164] = { 17449564, 17449565, 17449566, 17449567, 17449568, 17449569 },   -- Planar Rift, Riftworn Pyxis
    [171] = { 17478370, 17478371, 17478372, 17478373, 17478374, 17478375 },   -- Planar Rift, Riftworn Pyxis
    [174] = { 17490320, 17490321, 17490322, 17490323, 17490324, 17490325 },   -- Planar Rift, Riftworn Pyxis
    [175] = { 17494789, 17494790, 17494791, 17494792, 17494793, 17494794 },   -- Planar Rift, Riftworn Pyxis
    [177] = { 17502701, 17502702, 17502703, 17502704, 17502705, 17502706 },   -- Planar Rift, Riftworn Pyxis
    [178] = { 17506821, 17506822, 17506823, 17506824, 17506825, 17506826 },   -- Planar Rift, Riftworn Pyxis
    [184] = { 17531227, 17531228, 17531229, 17531230, 17531231, 17531232 },   -- Planar Rift, Riftworn Pyxis
    [190] = { 17556021, 17556022, 17556023, 17556024, 17556025, 17556026 },   -- Planar Rift, Riftworn Pyxis
    [191] = { 17559930, 17559931, 17559932, 17559933, 17559934, 17559935 },   -- Planar Rift, Riftworn Pyxis
    [193] = { 17568199, 17568200, 17568201, 17568202, 17568203, 17568204 },   -- Planar Rift, Riftworn Pyxis
    [194] = { 17572304, 17572305, 17572306, 17572307, 17572308, 17572309 },   -- Planar Rift, Riftworn Pyxis
    [195] = { 17576434, 17576435, 17576436, 17576437, 17576438, 17576439 },   -- Planar Rift, Riftworn Pyxis
    [196] = { 17580411, 17580412, 17580413, 17580414, 17580415, 17580416 },   -- Planar Rift, Riftworn Pyxis
    [197] = { 17584499, 17584500, 17584501, 17584502, 17584503, 17584504 },   -- Planar Rift, Riftworn Pyxis
    [198] = { 17588783, 17588784, 17588785, 17588786, 17588787, 17588788 },   -- Planar Rift, Riftworn Pyxis
    [200] = { 17596860, 17596861, 17596862, 17596863, 17596864, 17596865 },   -- Planar Rift, Riftworn Pyxis
    [205] = { 17617262, 17617263, 17617264, 17617265, 17617266, 17617267 },   -- Planar Rift, Riftworn Pyxis
    [208] = { 17629773, 17629774, 17629775, 17629776, 17629777, 17629778 },   -- Planar Rift, Riftworn Pyxis
    [222] = { 17686643 },   -- Planar Rift
    [230] = { 17719634, 17719635, 17719636, 17719637 },   -- Atmacite Refiner, Voidwatch Officer, Voidwatch Purveyor
    [231] = { 17723671 },   -- Voidwatch Purveyor
    [234] = { 17735871 },   -- Voidwatch Purveyor
    [235] = { 17739950, 17739951, 17739952 },   -- Atmacite Refiner, Voidwatch Officer, Voidwatch Purveyor
    [236] = { 17744057 },   -- Voidwatch Purveyor
    [238] = { 17752373, 17752374, 17752375 },   -- Atmacite Refiner, Voidwatch Officer, Voidwatch Purveyor
    [240] = { 17760468 },   -- Voidwatch Purveyor
    [241] = { 17764602 },   -- Voidwatch Purveyor
    [244] = { 17776885 },   -- Voidwatch Purveyor
    [245] = { 17780980 },   -- Voidwatch Purveyor
    [246] = { 17784986 },   -- Voidwatch Purveyor
    [247] = { 17789012, 17789016 },   -- Atmacite Refiner, Gushing Spring
    [250] = { 17801352, 17801354 },   -- Atmacite Refiner, Hildegard
    [252] = { 17809529, 17809534 },   -- Atmacite Refiner, Kieran
}

-- The server's own events hide NPCs with INVISIBLE (a note in starlight_celebration.lua says DISAPPEAR did not work there)
local function hide(zoneId)
    local hidden = xi.status.INVISIBLE or xi.status.DISAPPEAR
    for _, id in ipairs(HIDDEN[zoneId] or {}) do
        local npc = GetNPCByID(id)
        if npc then
            npc:setStatus(hidden)
        end
    end
end

m:addOverride('xi.player.onGameIn', function(player, firstLogin, zoning)
    super(player, firstLogin, zoning)

    local zoneId = player:getZoneID()
    if HIDDEN[zoneId] then
        hide(zoneId)
        if player.timer then
            player:timer(3000, function() hide(zoneId) end)    -- again a moment later, in case something shows them once the zone has started
        end
    end
end)

return m
