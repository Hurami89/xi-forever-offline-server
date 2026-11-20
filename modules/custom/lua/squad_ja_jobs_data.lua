-- Gambits v2 M1.1: the job, level and sub-job restrictions of each job ability, for squad_rulesets.lua.
-- MADE BY dev/gambits-v2-squad/make_squad_ja_jobs.py FROM sql/abilities.sql - do not edit by hand, run the script again.
-- [ability id (= xi.ja value)] = { job id, level, sp = true (level 0: never from the sub job),
--                                  main = true (addType ADDTYPE_MAIN_ONLY: never from the sub job),
--                                  merit = id (addType ADDTYPE_MERIT: the owner must have unlocked that merit) }
return
{
    version = 3,
    abilities =
    {
        [16] = { 1, 0, sp = true }, -- mighty_strikes
        [17] = { 2, 0, sp = true }, -- hundred_fists
        [18] = { 3, 0, sp = true }, -- benediction
        [19] = { 4, 0, sp = true }, -- manafont
        [20] = { 5, 0, sp = true }, -- chainspell
        [21] = { 6, 0, sp = true }, -- perfect_dodge
        [22] = { 7, 0, sp = true }, -- invincible
        [23] = { 8, 0, sp = true }, -- blood_weapon
        [24] = { 9, 0, sp = true }, -- familiar
        [25] = { 10, 0, sp = true }, -- soul_voice
        [26] = { 11, 0, sp = true }, -- eagle_eye_shot
        [27] = { 12, 0, sp = true }, -- meikyo_shisui
        [28] = { 13, 0, sp = true }, -- mijin_gakure
        [29] = { 14, 0, sp = true }, -- spirit_surge
        [30] = { 15, 0, sp = true }, -- astral_flow
        [31] = { 1, 15 }, -- berserk
        [32] = { 1, 35 }, -- warcry
        [33] = { 1, 25 }, -- defender
        [34] = { 1, 45 }, -- aggressor
        [35] = { 1, 5 }, -- provoke
        [36] = { 2, 25 }, -- focus
        [37] = { 2, 15 }, -- dodge
        [38] = { 2, 35 }, -- chakra
        [39] = { 2, 5 }, -- boost
        [40] = { 2, 45 }, -- counterstance
        [41] = { 6, 5 }, -- steal
        [42] = { 6, 25 }, -- flee
        [43] = { 6, 45 }, -- hide
        [44] = { 6, 15 }, -- sneak_attack
        [45] = { 6, 35 }, -- mug
        [46] = { 7, 15 }, -- shield_bash
        [47] = { 7, 5 }, -- holy_circle
        [48] = { 7, 30 }, -- sentinel
        [49] = { 8, 30 }, -- souleater
        [50] = { 8, 5 }, -- arcane_circle
        [51] = { 8, 15 }, -- last_resort
        [52] = { 9, 1 }, -- charm
        [53] = { 9, 10 }, -- gauge
        [54] = { 9, 30 }, -- tame
        [55] = { 9, 1 }, -- pet_commands
        [56] = { 11, 10 }, -- scavenge
        [57] = { 11, 40 }, -- shadowbind
        [58] = { 11, 20 }, -- camouflage
        [59] = { 11, 1 }, -- sharpshot
        [60] = { 11, 30 }, -- barrage
        [61] = { 14, 1, main = true }, -- call_wyvern
        [62] = { 12, 15 }, -- third_eye
        [63] = { 12, 30 }, -- meditate
        [64] = { 12, 5 }, -- warding_circle
        [65] = { 14, 5 }, -- ancient_circle
        [66] = { 14, 10 }, -- jump
        [67] = { 14, 35 }, -- high_jump
        [68] = { 14, 50 }, -- super_jump
        [69] = { 9, 1 }, -- fight
        [70] = { 9, 10 }, -- heel
        [71] = { 9, 35 }, -- leave
        [72] = { 9, 25 }, -- sic
        [73] = { 9, 15 }, -- stay
        [74] = { 3, 15 }, -- divine_seal
        [75] = { 4, 15 }, -- elemental_seal
        [76] = { 6, 30 }, -- trick_attack
        [77] = { 8, 20 }, -- weapon_bash
        [78] = { 9, 12 }, -- reward
        [79] = { 7, 35 }, -- cover
        [80] = { 14, 25, main = true }, -- spirit_link
        [82] = { 2, 41 }, -- chi_blast
        [83] = { 5, 40 }, -- convert
        [84] = { 6, 65 }, -- accomplice
        [85] = { 9, 23 }, -- call_beast
        [86] = { 11, 51 }, -- unlimited_shot
        [87] = { 14, 1, main = true }, -- dismiss
        [88] = { 15, 1 }, -- assault
        [89] = { 15, 1 }, -- retreat
        [90] = { 15, 1 }, -- release
        [91] = { 15, 1 }, -- blood_pact_rage
        [92] = { 7, 62 }, -- rampart
        [93] = { 16, 0, sp = true }, -- azure_lore
        [94] = { 16, 40 }, -- chain_affinity
        [95] = { 16, 25 }, -- burst_affinity
        [96] = { 17, 0, sp = true }, -- wild_card
        [97] = { 17, 5 }, -- phantom_roll
        [98] = { 17, 49 }, -- fighters_roll
        [99] = { 17, 31 }, -- monks_roll
        [100] = { 17, 20 }, -- healers_roll
        [101] = { 17, 58 }, -- wizards_roll
        [102] = { 17, 46 }, -- warlocks_roll
        [103] = { 17, 43 }, -- rogues_roll
        [104] = { 17, 55 }, -- gallants_roll
        [105] = { 17, 14 }, -- chaos_roll
        [106] = { 17, 34 }, -- beast_roll
        [107] = { 17, 26 }, -- choral_roll
        [108] = { 17, 11 }, -- hunters_roll
        [109] = { 17, 37 }, -- samurai_roll
        [110] = { 17, 8 }, -- ninja_roll
        [111] = { 17, 23 }, -- drachen_roll
        [112] = { 17, 40 }, -- evokers_roll
        [113] = { 17, 17 }, -- maguss_roll
        [114] = { 17, 5 }, -- corsairs_roll
        [115] = { 17, 52 }, -- puppet_roll
        [116] = { 17, 61 }, -- dancers_roll
        [117] = { 17, 64 }, -- scholars_roll
        [118] = { 17, 76 }, -- bolters_roll
        [119] = { 17, 79 }, -- casters_roll
        [120] = { 17, 81 }, -- coursers_roll
        [121] = { 17, 83 }, -- blitzers_roll
        [122] = { 17, 86 }, -- tacticians_roll
        [123] = { 17, 5 }, -- double-up
        [124] = { 17, 40 }, -- quick_draw
        [125] = { 17, 40 }, -- fire_shot
        [126] = { 17, 40 }, -- ice_shot
        [127] = { 17, 40 }, -- wind_shot
        [128] = { 17, 40 }, -- earth_shot
        [129] = { 17, 40 }, -- thunder_shot
        [130] = { 17, 40 }, -- water_shot
        [131] = { 17, 40 }, -- light_shot
        [132] = { 17, 40 }, -- dark_shot
        [133] = { 17, 50 }, -- random_deal
        [135] = { 18, 0, sp = true }, -- overdrive
        [136] = { 18, 1 }, -- activate
        [137] = { 18, 15 }, -- repair
        [138] = { 18, 1 }, -- deploy
        [139] = { 18, 1 }, -- deactivate
        [140] = { 18, 10 }, -- retrieve
        [141] = { 18, 1 }, -- fire_maneuver
        [142] = { 18, 1 }, -- ice_maneuver
        [143] = { 18, 1 }, -- wind_maneuver
        [144] = { 18, 1 }, -- earth_maneuver
        [145] = { 18, 1 }, -- thunder_maneuver
        [146] = { 18, 1 }, -- water_maneuver
        [147] = { 18, 1 }, -- light_maneuver
        [148] = { 18, 1 }, -- dark_maneuver
        [149] = { 1, 75, merit = 2048 }, -- warriors_charge
        [150] = { 1, 75, merit = 2050 }, -- tomahawk
        [151] = { 2, 75, merit = 2112 }, -- mantra
        [152] = { 2, 75, merit = 2114 }, -- formless_strikes
        [153] = { 3, 75, merit = 2176 }, -- martyr
        [154] = { 3, 75, merit = 2178 }, -- devotion
        [155] = { 6, 75, merit = 2368 }, -- assassins_charge
        [156] = { 6, 75, merit = 2370 }, -- feint
        [157] = { 7, 75, merit = 2432 }, -- fealty
        [158] = { 7, 75, merit = 2434 }, -- chivalry
        [159] = { 8, 75, merit = 2496 }, -- dark_seal
        [160] = { 8, 75, merit = 2498 }, -- diabolic_eye
        [161] = { 9, 75, merit = 2560 }, -- feral_howl
        [162] = { 9, 75, merit = 2562 }, -- killer_instinct
        [163] = { 10, 75, merit = 2624 }, -- nightingale
        [164] = { 10, 75, merit = 2626 }, -- troubadour
        [165] = { 11, 75, merit = 2688 }, -- stealth_shot
        [166] = { 11, 75, merit = 2690 }, -- flashy_shot
        [167] = { 12, 75, merit = 2752 }, -- shikikoyo
        [168] = { 12, 75, merit = 2754 }, -- blade_bash
        [169] = { 14, 75, merit = 2880 }, -- deep_breathing
        [170] = { 14, 75, merit = 2882 }, -- angon
        [171] = { 13, 75, merit = 2816 }, -- sange
        [172] = { 15, 1 }, -- blood_pact_ward
        [173] = { 12, 25 }, -- hasso
        [174] = { 12, 35 }, -- seigan
        [175] = { 16, 75, merit = 3008 }, -- convergence
        [176] = { 16, 75, merit = 3010 }, -- diffusion
        [177] = { 17, 75, merit = 3072 }, -- snake_eye
        [178] = { 17, 75, merit = 3074 }, -- fold
        [179] = { 18, 75, merit = 3136 }, -- role_reversal
        [180] = { 18, 75, merit = 3138 }, -- ventriloquy
        [181] = { 19, 0, sp = true }, -- trance
        [182] = { 19, 5 }, -- sambas
        [183] = { 19, 15 }, -- waltzes
        [184] = { 19, 5 }, -- drain_samba
        [185] = { 19, 35 }, -- drain_samba_ii
        [186] = { 19, 65 }, -- drain_samba_iii
        [187] = { 19, 25 }, -- aspir_samba
        [188] = { 19, 60 }, -- aspir_samba_ii
        [189] = { 19, 45 }, -- haste_samba
        [190] = { 19, 15 }, -- curing_waltz
        [191] = { 19, 30 }, -- curing_waltz_ii
        [192] = { 19, 45 }, -- curing_waltz_iii
        [193] = { 19, 70 }, -- curing_waltz_iv
        [194] = { 19, 35 }, -- healing_waltz
        [195] = { 19, 25 }, -- divine_waltz
        [196] = { 19, 25 }, -- spectral_jig
        [197] = { 19, 55 }, -- chocobo_jig
        [198] = { 19, 25 }, -- jigs
        [199] = { 19, 20 }, -- steps
        [200] = { 19, 20 }, -- flourishes_i
        [201] = { 19, 20 }, -- quickstep
        [202] = { 19, 30 }, -- box_step
        [203] = { 19, 40 }, -- stutter_step
        [204] = { 19, 20 }, -- animated_flourish
        [205] = { 19, 30 }, -- desperate_flourish
        [206] = { 19, 40 }, -- reverse_flourish
        [207] = { 19, 45 }, -- violent_flourish
        [208] = { 19, 50 }, -- building_flourish
        [209] = { 19, 60 }, -- wild_flourish
        [210] = { 20, 0, sp = true }, -- tabula_rasa
        [211] = { 20, 10 }, -- light_arts
        [212] = { 20, 10 }, -- dark_arts
        [213] = { 19, 40 }, -- flourishes_ii
        [214] = { 20, 65 }, -- modus_veritas
        [215] = { 20, 10 }, -- penury
        [216] = { 20, 25 }, -- celerity
        [217] = { 20, 55 }, -- rapture
        [218] = { 20, 40 }, -- accession
        [219] = { 20, 10 }, -- parsimony
        [220] = { 20, 25 }, -- alacrity
        [221] = { 20, 55 }, -- ebullience
        [222] = { 20, 40 }, -- manifestation
        [223] = { 20, 10 }, -- stratagems
        [224] = { 11, 45, main = true }, -- velocity_shot
        [225] = { 9, 45 }, -- snarl
        [226] = { 1, 60 }, -- retaliation
        [227] = { 2, 65 }, -- footwork
        [228] = { 6, 77 }, -- despoil
        [229] = { 10, 20 }, -- pianissimo
        [230] = { 12, 40 }, -- sekkanoki
        [232] = { 15, 50 }, -- elemental_siphon
        [233] = { 20, 35 }, -- sublimation
        [234] = { 20, 10 }, -- addendum_white
        [235] = { 20, 30 }, -- addendum_black
        [236] = { 6, 65 }, -- collaborator
        [237] = { 19, 75, merit = 3200 }, -- saber_dance
        [238] = { 19, 75, merit = 3202 }, -- fan_dance
        [239] = { 19, 75, merit = 3204 }, -- no_foot_rise
        [240] = { 20, 75, merit = 3264 }, -- altruism
        [241] = { 20, 75, merit = 3266 }, -- focalization
        [242] = { 20, 75, merit = 3268 }, -- tranquility
        [243] = { 20, 75, merit = 3270 }, -- equanimity
        [244] = { 20, 75, merit = 3272 }, -- enlightenment
        [245] = { 3, 40, main = true }, -- afflatus_solace
        [246] = { 3, 40, main = true }, -- afflatus_misery
        [247] = { 5, 50, main = true }, -- composure
        [248] = { 13, 40, main = true }, -- yonin
        [249] = { 13, 40, main = true }, -- innin
        [250] = { 15, 55 }, -- avatars_favor
        [251] = { 9, 25 }, -- ready
        [252] = { 1, 77 }, -- restraint
        [253] = { 2, 79 }, -- perfect_counter
        [254] = { 4, 76 }, -- mana_wall
        [255] = { 7, 78 }, -- divine_emblem
        [256] = { 8, 78 }, -- nether_void
        [257] = { 11, 79 }, -- double_shot
        [258] = { 12, 77 }, -- sengikori
        [259] = { 13, 77 }, -- futae
        [260] = { 14, 77 }, -- spirit_jump
        [261] = { 19, 77 }, -- presto
        [262] = { 19, 78 }, -- divine_waltz_ii
        [263] = { 19, 80 }, -- flourishes_iii
        [264] = { 19, 80 }, -- climactic_flourish
        [265] = { 20, 76 }, -- libra
        [266] = { 18, 79 }, -- tactical_switch
        [267] = { 1, 87 }, -- blood_rage
        [269] = { 2, 88 }, -- impetus
        [270] = { 3, 83 }, -- divine_caress
        [271] = { 3, 95 }, -- sacrosanctity
        [272] = { 4, 87 }, -- enmity_douse
        [273] = { 4, 95 }, -- manawell
        [274] = { 5, 83 }, -- saboteur
        [275] = { 5, 95 }, -- spontaneity
        [276] = { 6, 87, main = true }, -- conspirator
        [277] = { 7, 87 }, -- sepulcher
        [278] = { 7, 95 }, -- palisade
        [279] = { 8, 87 }, -- arcane_crest
        [280] = { 8, 95 }, -- scarlet_delirium
        [281] = { 9, 83 }, -- spur
        [282] = { 9, 93 }, -- run_wild
        [283] = { 10, 83 }, -- tenuto
        [284] = { 10, 95 }, -- marcato
        [285] = { 11, 87 }, -- bounty_shot
        [286] = { 11, 95 }, -- decoy_shot
        [287] = { 12, 87 }, -- hamanoha
        [288] = { 12, 95 }, -- hagakure
        [291] = { 13, 95 }, -- issekigan
        [292] = { 14, 87 }, -- dragon_breaker
        [293] = { 14, 85 }, -- soul_jump
        [295] = { 14, 95 }, -- steady_wing
        [296] = { 15, 87 }, -- mana_cede
        [297] = { 16, 83 }, -- efflux
        [298] = { 16, 95 }, -- unbridled_learning
        [301] = { 17, 87 }, -- triple_shot
        [302] = { 17, 89 }, -- allies_roll
        [303] = { 17, 92 }, -- misers_roll
        [304] = { 17, 95 }, -- companions_roll
        [305] = { 17, 97 }, -- avengers_roll
        [309] = { 18, 95 }, -- cooldown
        [310] = { 18, 5 }, -- deus_ex_automata
        [311] = { 19, 87 }, -- curing_waltz_v
        [312] = { 19, 83 }, -- feather_step
        [313] = { 19, 89 }, -- striking_flourish
        [314] = { 19, 93 }, -- ternary_flourish
        [316] = { 20, 87 }, -- perpetuance
        [317] = { 20, 87 }, -- immanence
        [318] = { 14, 90 }, -- smiting_breath
        [319] = { 14, 90 }, -- restoring_breath
        [320] = { 12, 65 }, -- konzen-ittai
        [321] = { 6, 93, main = true }, -- bully
        [322] = { 18, 30 }, -- maintenance
        [323] = { 1, 96 }, -- brazen_rush
        [324] = { 2, 96 }, -- inner_strength
        [325] = { 3, 96 }, -- asylum
        [326] = { 4, 96 }, -- subtle_sorcery
        [327] = { 5, 96 }, -- stymie
        [328] = { 6, 96 }, -- larceny
        [329] = { 7, 96 }, -- intervene
        [330] = { 8, 96 }, -- soul_enslavement
        [331] = { 9, 96 }, -- unleash
        [332] = { 10, 96 }, -- clarion_call
        [333] = { 11, 96 }, -- overkill
        [334] = { 12, 96 }, -- yaegasumi
        [335] = { 13, 96 }, -- mikage
        [336] = { 14, 96 }, -- fly_high
        [337] = { 15, 96 }, -- astral_conduit
        [338] = { 16, 96 }, -- unbridled_wisdom
        [339] = { 17, 96 }, -- cutting_cards
        [340] = { 18, 96 }, -- heady_artifice
        [341] = { 19, 96, main = true }, -- grand_pas
        [342] = { 20, 96 }, -- caper_emissarius
        [343] = { 21, 1, main = true }, -- bolster
        [344] = { 22, 25 }, -- swipe
        [345] = { 21, 5 }, -- full_circle
        [346] = { 21, 25 }, -- lasting_emanation
        [347] = { 21, 25 }, -- ecliptic_attrition
        [348] = { 21, 40 }, -- collimated_fervor
        [349] = { 21, 50 }, -- life_cycle
        [350] = { 21, 60 }, -- blaze_of_glory
        [351] = { 21, 70 }, -- dematerialize
        [352] = { 21, 80 }, -- theurgic_focus
        [353] = { 21, 90 }, -- concentric_pulse
        [354] = { 21, 75 }, -- mending_halation
        [355] = { 21, 75 }, -- radial_arcana
        [356] = { 22, 0, sp = true }, -- elemental_sforzo
        [357] = { 22, 5 }, -- rune_enchantment
        [358] = { 22, 5 }, -- ignis
        [359] = { 22, 5 }, -- gelus
        [360] = { 22, 5 }, -- flabra
        [361] = { 22, 5 }, -- tellus
        [362] = { 22, 5 }, -- sulpor
        [363] = { 22, 5 }, -- unda
        [364] = { 22, 5 }, -- lux
        [365] = { 22, 5 }, -- tenebrae
        [366] = { 22, 10 }, -- vallation
        [367] = { 22, 20 }, -- swordplay
        [368] = { 22, 25 }, -- lunge
        [369] = { 22, 40 }, -- pflug
        [370] = { 22, 60 }, -- embolden
        [371] = { 22, 50 }, -- valiance
        [372] = { 22, 70 }, -- gambit
        [373] = { 22, 85 }, -- liement
        [374] = { 22, 95 }, -- one_for_all
        [375] = { 22, 75, merit = 3458 }, -- rayke
        [376] = { 22, 75, merit = 3456 }, -- battuta
        [377] = { 21, 96 }, -- widened_compass
        [378] = { 22, 96 }, -- odyllic_subterfuge
        [379] = { 22, 1 }, -- ward
        [380] = { 22, 1 }, -- effusion
        [381] = { 19, 70 }, -- chocobo_jig_ii
        [382] = { 23, 1 }, -- relinquish
        [383] = { 22, 65 }, -- vivacious_pulse
        [384] = { 19, 50 }, -- contradance
        [385] = { 15, 70 }, -- apogee
        [386] = { 21, 75 }, -- entrust
        [387] = { 9, 23 }, -- bestial_loyalty
        [388] = { 4, 85 }, -- cascade
        [389] = { 8, 55 }, -- consume_mana
        [390] = { 17, 67 }, -- naturalists_roll
        [391] = { 17, 70 }, -- runeists_roll
        [392] = { 17, 95 }, -- crooked_cards
        [393] = { 14, 65 }, -- spirit_bond
        [394] = { 7, 70 }, -- majesty
        [512] = { 15, 1 }, -- healing_ruby
        [513] = { 15, 5 }, -- poison_nails
        [514] = { 15, 24 }, -- shining_ruby
        [515] = { 15, 44 }, -- glittering_ruby
        [516] = { 15, 55 }, -- meteorite
        [517] = { 15, 65 }, -- healing_ruby_ii
        [518] = { 15, 1 }, -- searing_light
        [519] = { 15, 76 }, -- holy_mist
        [520] = { 15, 94 }, -- soothing_ruby
        [521] = { 15, 1 }, -- regal_scratch
        [522] = { 15, 25 }, -- mewing_lullaby
        [523] = { 15, 55 }, -- eerie_eye
        [524] = { 15, 75 }, -- level_X_holy
        [525] = { 15, 15 }, -- raise_ii
        [526] = { 15, 30 }, -- reraise_ii
        [527] = { 15, 1 }, -- altana_s_favor
        [528] = { 15, 5 }, -- moonlit_charge
        [529] = { 15, 10 }, -- crescent_fang
        [530] = { 15, 21 }, -- lunar_cry
        [531] = { 15, 32 }, -- lunar_roar
        [532] = { 15, 43 }, -- ecliptic_growl
        [533] = { 15, 54 }, -- ecliptic_howl
        [534] = { 15, 65 }, -- eclipse_bite
        [536] = { 15, 1 }, -- howling_moon
        [537] = { 15, 78 }, -- lunar_bay
        [538] = { 15, 96 }, -- heavenward_howl
        [539] = { 15, 99 }, -- impact
        [544] = { 15, 1 }, -- punch
        [545] = { 15, 10 }, -- fire_ii
        [546] = { 15, 23 }, -- burning_strike
        [547] = { 15, 30 }, -- double_punch
        [548] = { 15, 38 }, -- crimson_howl
        [549] = { 15, 60 }, -- fire_iv
        [550] = { 15, 70 }, -- flaming_crush
        [551] = { 15, 75, merit = 2944 }, -- meteor_strike
        [552] = { 15, 1 }, -- inferno
        [553] = { 15, 88 }, -- inferno_howl
        [554] = { 15, 99 }, -- conflag_strike
        [560] = { 15, 1 }, -- rock_throw
        [561] = { 15, 10 }, -- stone_ii
        [562] = { 15, 21 }, -- rock_buster
        [563] = { 15, 35 }, -- megalith_throw
        [564] = { 15, 46 }, -- earthen_ward
        [565] = { 15, 60 }, -- stone_iv
        [566] = { 15, 70 }, -- mountain_buster
        [567] = { 15, 75, merit = 2950 }, -- geocrush
        [568] = { 15, 1 }, -- earthen_fury
        [569] = { 15, 82 }, -- earthen_armor
        [570] = { 15, 99 }, -- crag_throw
        [576] = { 15, 1 }, -- barracuda_dive
        [577] = { 15, 10 }, -- water_ii
        [578] = { 15, 26 }, -- tail_whip
        [579] = { 15, 47 }, -- spring_water
        [580] = { 15, 33 }, -- slowga
        [581] = { 15, 60 }, -- water_iv
        [582] = { 15, 70 }, -- spinning_dive
        [583] = { 15, 75, merit = 2954 }, -- grand_fall
        [584] = { 15, 1 }, -- tidal_wave
        [585] = { 15, 84 }, -- tidal_roar
        [586] = { 15, 99 }, -- soothing_current
        [592] = { 15, 1 }, -- claw
        [593] = { 15, 10 }, -- aero_ii
        [594] = { 15, 36 }, -- whispering_wind
        [595] = { 15, 48 }, -- hastega
        [596] = { 15, 25 }, -- aerial_armor
        [597] = { 15, 60 }, -- aero_iv
        [598] = { 15, 70 }, -- predator_claws
        [599] = { 15, 75, merit = 2948 }, -- wind_blade
        [600] = { 15, 1 }, -- aerial_blast
        [601] = { 15, 86 }, -- fleet_wind
        [602] = { 15, 99 }, -- hastega_ii
        [608] = { 15, 1 }, -- axe_kick
        [609] = { 15, 10 }, -- blizzard_ii
        [610] = { 15, 28 }, -- frost_armor
        [611] = { 15, 39 }, -- sleepga
        [612] = { 15, 50 }, -- double_slap
        [613] = { 15, 60 }, -- blizzard_iv
        [614] = { 15, 70 }, -- rush
        [615] = { 15, 75, merit = 2946 }, -- heavenly_strike
        [616] = { 15, 1 }, -- diamond_dust
        [617] = { 15, 90 }, -- diamond_storm
        [618] = { 15, 99 }, -- crystal_blessing
        [624] = { 15, 1 }, -- shock_strike
        [625] = { 15, 10 }, -- thunder_ii
        [626] = { 15, 31 }, -- rolling_thunder
        [627] = { 15, 19 }, -- thunderspark
        [628] = { 15, 42 }, -- lightning_armor
        [629] = { 15, 60 }, -- thunder_iv
        [630] = { 15, 70 }, -- chaotic_strike
        [631] = { 15, 75, merit = 2952 }, -- thunderstorm
        [632] = { 15, 1 }, -- judgment_bolt
        [633] = { 15, 92 }, -- shock_squall
        [634] = { 15, 99 }, -- volt_strike
        [639] = { 0, 80 }, -- healing_breath_iv
        [640] = { 0, 1 }, -- healing_breath
        [641] = { 0, 20 }, -- healing_breath_ii
        [642] = { 0, 40 }, -- healing_breath_iii
        [643] = { 0, 1 }, -- remove_poison
        [644] = { 0, 20 }, -- remove_blindness
        [645] = { 0, 40 }, -- remove_paralysis
        [646] = { 0, 1 }, -- flame_breath
        [647] = { 0, 1 }, -- frost_breath
        [648] = { 0, 1 }, -- gust_breath
        [649] = { 0, 1 }, -- sand_breath
        [650] = { 0, 1 }, -- lightning_breath
        [651] = { 0, 1 }, -- hydro_breath
        [652] = { 0, 50 }, -- super_climb
        [653] = { 0, 60 }, -- remove_curse
        [654] = { 0, 80 }, -- remove_disease
        [656] = { 15, 1 }, -- camisado
        [657] = { 15, 20 }, -- somnolence
        [658] = { 15, 29 }, -- nightmare
        [659] = { 15, 37 }, -- ultimate_terror
        [660] = { 15, 49 }, -- noctoshield
        [661] = { 15, 56 }, -- dream_shroud
        [662] = { 15, 65 }, -- nether_blast
        [664] = { 15, 1 }, -- ruinous_omen
        [665] = { 15, 80 }, -- night_terror
        [666] = { 15, 98 }, -- pavor_nocturnus
        [667] = { 15, 99 }, -- blindside
        [668] = { 15, 75 }, -- deconstruction
        [669] = { 15, 75 }, -- chronoshift
        [671] = { 15, 75 }, -- perfect_defense
        [672] = { 9, 25 }, -- foot_kick
        [673] = { 9, 25 }, -- dust_cloud
        [674] = { 9, 25 }, -- whirl_claws
        [675] = { 9, 25 }, -- head_butt
        [676] = { 9, 25 }, -- dream_flower
        [677] = { 9, 25 }, -- wild_oats
        [678] = { 9, 25 }, -- leaf_dagger
        [679] = { 9, 25 }, -- scream
        [680] = { 9, 25 }, -- roar
        [681] = { 9, 25 }, -- razor_fang
        [682] = { 9, 25 }, -- claw_cyclone
        [683] = { 9, 25 }, -- tail_blow
        [684] = { 9, 25 }, -- fireball
        [685] = { 9, 25 }, -- blockhead
        [686] = { 9, 25 }, -- brain_crush
        [687] = { 9, 25 }, -- infrasonics
        [688] = { 9, 25 }, -- secretion
        [689] = { 9, 25 }, -- lamb_chop
        [690] = { 9, 25 }, -- rage
        [691] = { 9, 25 }, -- sheep_charge
        [692] = { 9, 25 }, -- sheep_song
        [693] = { 9, 25 }, -- bubble_shower
        [694] = { 9, 25 }, -- bubble_curtain
        [695] = { 9, 25 }, -- big_scissors
        [696] = { 9, 25 }, -- scissor_guard
        [697] = { 9, 25 }, -- metallic_body
        [698] = { 9, 25 }, -- needleshot
        [699] = { 9, 25 }, -- random_needles
        [700] = { 9, 25 }, -- frogkick
        [701] = { 9, 25 }, -- spore
        [702] = { 9, 25 }, -- queasyshroom
        [703] = { 9, 25 }, -- numbshroom
        [704] = { 9, 25 }, -- shakeshroom
        [705] = { 9, 25 }, -- silence_gas
        [706] = { 9, 25 }, -- dark_spore
        [707] = { 9, 25 }, -- power_attack
        [708] = { 9, 25 }, -- hi-freq_field
        [709] = { 9, 25 }, -- rhino_attack
        [710] = { 9, 25 }, -- rhino_guard
        [711] = { 9, 25 }, -- spoil
        [712] = { 9, 25 }, -- cursed_sphere
        [713] = { 9, 25 }, -- venom
        [714] = { 9, 25 }, -- sandblast
        [715] = { 9, 25 }, -- sandpit
        [716] = { 9, 25 }, -- venom_spray
        [717] = { 9, 25 }, -- mandibular_bite
        [718] = { 9, 25 }, -- soporific
        [719] = { 9, 25 }, -- gloeosuccus
        [720] = { 9, 25 }, -- palsy_pollen
        [721] = { 9, 25 }, -- geist_wall
        [722] = { 9, 25 }, -- numbing_noise
        [723] = { 9, 25 }, -- nimble_snap
        [724] = { 9, 25 }, -- cyclotail
        [725] = { 9, 25 }, -- toxic_spit
        [726] = { 9, 25 }, -- double_claw
        [727] = { 9, 25 }, -- grapple
        [728] = { 9, 25 }, -- spinning_top
        [729] = { 9, 25 }, -- filamented_hold
        [730] = { 9, 25 }, -- chaotic_eye
        [731] = { 9, 25 }, -- blaster
        [732] = { 9, 25 }, -- suction
        [733] = { 9, 25 }, -- drainkiss
        [734] = { 9, 25 }, -- snow_cloud
        [735] = { 9, 25 }, -- wild_carrot
        [736] = { 9, 25 }, -- sudden_lunge
        [737] = { 9, 25 }, -- spiral_spin
        [738] = { 9, 25 }, -- noisome_powder
        [740] = { 10, 25 }, -- acid_mist
        [741] = { 10, 25 }, -- tp_drainkiss
        [743] = { 9, 26 }, -- scythe_tail
        [744] = { 9, 26 }, -- ripper_fang
        [745] = { 9, 25 }, -- chomp_rush
        [746] = { 9, 26 }, -- charged_whisker
        [747] = { 9, 25 }, -- purulent_ooze
        [748] = { 9, 25 }, -- corrosive_ooze
        [749] = { 9, 25 }, -- back_heel
        [750] = { 9, 25 }, -- jettatura
        [751] = { 9, 25 }, -- choke_breath
        [752] = { 9, 25 }, -- fantod
        [753] = { 9, 25 }, -- tortoise_stomp
        [754] = { 9, 25 }, -- harden_shell
        [755] = { 9, 25 }, -- aqua_breath
        [756] = { 9, 25 }, -- wing_slap
        [757] = { 9, 25 }, -- beak_lunge
        [758] = { 9, 25 }, -- intimidate
        [759] = { 9, 25 }, -- recoil_dive
        [760] = { 9, 25 }, -- water_wall
        [761] = { 9, 25 }, -- sensilla_blades
        [762] = { 9, 25 }, -- tegmina_buffet
        [763] = { 9, 25 }, -- molting_plumage
        [764] = { 9, 25 }, -- swooping_frenzy
        [765] = { 9, 25 }, -- sweeping_gouge
        [766] = { 9, 25 }, -- zealous_snort
        [767] = { 9, 25 }, -- pentapeck
        [768] = { 9, 25 }, -- tickling_tendrils
        [769] = { 9, 25 }, -- stink_bomb
        [770] = { 9, 25 }, -- nectarous_deluge
        [771] = { 9, 25 }, -- nepenthic_plunge
        [772] = { 9, 25 }, -- somersault
        [773] = { 15, 99 }, -- pacifying_ruby
        [774] = { 9, 25 }, -- foul_waters
        [775] = { 9, 25 }, -- pestilent_plume
        [776] = { 9, 25 }, -- pecking_flurry
        [777] = { 9, 25 }, -- sickle_slash
        [778] = { 9, 25 }, -- acid_spray
        [779] = { 9, 25 }, -- spider_web
        [781] = { 9, 25 }, -- infected_leech
        [782] = { 9, 25 }, -- gloom_spray
        [786] = { 9, 25 }, -- disembowel
        [787] = { 9, 25 }, -- extirpating_salvo
        [788] = { 9, 25 }, -- venom_shower
        [789] = { 9, 25 }, -- mega_scissors
        [790] = { 9, 25 }, -- frenzied_rage
        [791] = { 9, 25 }, -- rhinowrecker
        [792] = { 9, 25 }, -- fluid_toss
        [793] = { 9, 25 }, -- fluid_spread
        [794] = { 9, 25 }, -- digest
        [795] = { 9, 25 }, -- crossthrash
        [796] = { 9, 25 }, -- predatory_glare
        [797] = { 9, 25 }, -- hoof_volley
        [798] = { 9, 25 }, -- nihility_song
        [960] = { 15, 1 }, -- clarsach_call
        [961] = { 15, 1 }, -- welt
        [964] = { 15, 25 }, -- roundhouse
        [967] = { 15, 65 }, -- sonic_buffet
        [968] = { 15, 75 }, -- tornado_ii
        [970] = { 15, 99 }, -- hysteric_assault
    },
}
