-- Forever Gloves (item 23869): beta testers' hands, their own item, made from the Fisherman's Gloves (14070), which
-- are not changed. (2026-11-27, the user)
-- Look: hands model 517 (the game files are made by FFXISOLO\forever_gloves.py). Listed in modules/init.txt so dbtool
-- puts it back after a server update. Use: modules/custom/lua/forever_gloves.lua.
-- Stats: DEF:1, Fishing skill +1 (mod 127). Use: teleport to the Fishermen's Guild in Port Windurst. Like the Forever
-- Track Pants: must be worn 8 seconds, one charge that never runs out (maxCharges 1), 10 minutes between uses.
-- Flags as the other gifts: NoAuction, CanTradeNPC, CanEquip, NoSale, NoDelivery, Ex, Rare (64576).

REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (23869,0,'forever_gloves','forever_gloves','Forever Gloves',6,1,64576,0,0);
REPLACE INTO `item_equipment` (`itemId`,`name`,`level`,`ilevel`,`jobs`,`MId`,`shieldSize`,`scriptType`,`slot`,`rslot`,`rslotlook`,`su_level`) VALUES (23869,'forever_gloves',1,0,4194303,517,0,0,64,0,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (23869,'forever_gloves',1,8,80,3,1,8,600,0);
DELETE FROM `item_mods` WHERE `itemId` = 23869;
INSERT INTO `item_mods` (`itemId`,`modId`,`value`) VALUES (23869,1,1),(23869,127,1);
