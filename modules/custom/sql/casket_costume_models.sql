-- XI: Forever Offline: model numbers for golden casket costumes that the base game data leaves at 0
-- (MId 0 = "not implemented", the piece draws nothing when worn).
--
-- How the numbers were found (2026-11-19): the client's FTABLE/VTABLE tables give the game file for
-- every model number (armor models 320-575 and 576-607 sit in fixed blocks per race and slot, and the block
-- layout agrees with 3,164 pieces whose numbers are already known). Each number below points at a real
-- model file for all 7 race models, and the file is the one model viewers list under that item's name
-- (or, for Knit Cap and Alliance Boots, the number its +1 / set partners already use).
-- The Era-DATs replace none of these files.
--
-- Safe to run again: only rows still at 0 are changed, so a number Phoenix/LandSandBoat fills in later wins.
-- Loaded through modules/init.txt, and the launcher re-imports module SQL on every update.

UPDATE item_equipment SET MId = 476 WHERE itemId = 23802 AND MId = 0; -- Aucuba Crown (head)
UPDATE item_equipment SET MId = 479 WHERE itemId = 23806 AND MId = 0; -- Vaquero Hat (head)
UPDATE item_equipment SET MId = 481 WHERE itemId = 23810 AND MId = 0; -- Knit Cap (head, same as Knit Cap +1)
UPDATE item_equipment SET MId = 589 WHERE itemId = 26516 AND MId = 0; -- Citrullus Shirt (body)
UPDATE item_equipment SET MId = 311 WHERE itemId = 28324 AND MId = 0; -- Alliance Boots (feet, same as Alliance Shirt/Pants)

-- Round 2 (same day): pieces whose model is a recolour of known gear. The candidate model files were matched
-- by colour and by the texture they share with an existing piece (texture name in the model file):
-- Sapphire set = model 483 (5 slots, body texture shared with Ares's Cuirass)
UPDATE item_equipment SET MId = 483 WHERE itemId = 23812 AND MId = 0; -- Sapphire Mask
UPDATE item_equipment SET MId = 483 WHERE itemId = 23813 AND MId = 0; -- Sapphire Platemail
UPDATE item_equipment SET MId = 483 WHERE itemId = 23814 AND MId = 0; -- Sapphire Gauntlets
UPDATE item_equipment SET MId = 483 WHERE itemId = 23815 AND MId = 0; -- Sapphire Trousers
UPDATE item_equipment SET MId = 483 WHERE itemId = 23816 AND MId = 0; -- Sapphire Leggings
-- Jadeite set = model 484 (5 slots, body texture shared with Skadi's Cuirie)
UPDATE item_equipment SET MId = 484 WHERE itemId = 23817 AND MId = 0; -- Jadeite Visor
UPDATE item_equipment SET MId = 484 WHERE itemId = 23818 AND MId = 0; -- Jadeite Cuirie
UPDATE item_equipment SET MId = 484 WHERE itemId = 23819 AND MId = 0; -- Jadeite Gloves
UPDATE item_equipment SET MId = 484 WHERE itemId = 23820 AND MId = 0; -- Jadeite Chausses
UPDATE item_equipment SET MId = 484 WHERE itemId = 23821 AND MId = 0; -- Jadeite Jambeaux
-- Diamond set = model 485 (5 slots, body texture shared with Usukane Haramaki)
UPDATE item_equipment SET MId = 485 WHERE itemId = 23822 AND MId = 0; -- Diamond Somen
UPDATE item_equipment SET MId = 485 WHERE itemId = 23823 AND MId = 0; -- Diamond Haramaki
UPDATE item_equipment SET MId = 485 WHERE itemId = 23824 AND MId = 0; -- Diamond Kote
UPDATE item_equipment SET MId = 485 WHERE itemId = 23825 AND MId = 0; -- Diamond Hizayoroi
UPDATE item_equipment SET MId = 485 WHERE itemId = 23826 AND MId = 0; -- Diamond Sune-Ate
-- Emerald set = model 486 (5 slots, body texture shared with Marduk's Jubbah)
UPDATE item_equipment SET MId = 486 WHERE itemId = 23827 AND MId = 0; -- Emerald Tiara
UPDATE item_equipment SET MId = 486 WHERE itemId = 23828 AND MId = 0; -- Emerald Jubbah
UPDATE item_equipment SET MId = 486 WHERE itemId = 23829 AND MId = 0; -- Emerald Dastanas
UPDATE item_equipment SET MId = 486 WHERE itemId = 23830 AND MId = 0; -- Emerald Shalwar
UPDATE item_equipment SET MId = 486 WHERE itemId = 23831 AND MId = 0; -- Emerald Crackows
-- Ruby set = model 487 (5 slots, body texture shared with Morrigan's Robe)
UPDATE item_equipment SET MId = 487 WHERE itemId = 23832 AND MId = 0; -- Ruby Coronal
UPDATE item_equipment SET MId = 487 WHERE itemId = 23833 AND MId = 0; -- Ruby Robe
UPDATE item_equipment SET MId = 487 WHERE itemId = 23834 AND MId = 0; -- Ruby Cuffs
UPDATE item_equipment SET MId = 487 WHERE itemId = 23835 AND MId = 0; -- Ruby Slops
UPDATE item_equipment SET MId = 487 WHERE itemId = 23836 AND MId = 0; -- Ruby Pigaches
-- Boudox's set = model 482 (body texture shared with Goblin Suit, Boudox is the goblin of the TVR epilogue)
UPDATE item_equipment SET MId = 482 WHERE itemId = 23862 AND MId = 0; -- Boudox's Masque
UPDATE item_equipment SET MId = 482, rslot = 448 WHERE itemId = 23863 AND MId = 0; -- Boudox's Suit (cannot equip hand, leg or footgear)
-- Magh Bihu's set = model 472 (texture shared with Mandragora Suit / Adenium Suit, from the Mandragora Warden)
UPDATE item_equipment SET MId = 472 WHERE itemId = 23864 AND MId = 0; -- Magh Bihu's Masque
UPDATE item_equipment SET MId = 472, rslot = 448 WHERE itemId = 23865 AND MId = 0; -- Magh Bihu's Suit (cannot equip hand, leg or footgear)
UPDATE item_equipment SET MId = 488 WHERE itemId = 23866 AND MId = 0; -- Yule Talisman (same texture as Tidal Talisman)
UPDATE item_equipment SET MId = 459 WHERE itemId = 23737 AND MId = 0; -- Byakko Masque (Tiger Helm texture, white tiger)
UPDATE item_equipment SET MId = 519 WHERE itemId = 24273 AND MId = 0; -- Sobu Houou Kabuto (Shobuhouou Kabuto texture)
UPDATE item_equipment SET MId = 442 WHERE itemId = 26522 AND MId = 0; -- Tajawwul (Sipahi Jawshan texture)
UPDATE item_equipment SET MId = 497 WHERE itemId = 25851 AND MId = 0; -- Ashen Subligar (subligar texture: Triplus/Dashing Subligar)
