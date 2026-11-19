-- Crystal Boy items (written by install_crystalboy_items.py). Listed in modules/init.txt so dbtool
-- puts them back after a server update. Flags: CanUse, CanTradeNPC, NoAuction, NoSale, NoDelivery, Ex, Rare.
-- No item scripts: the Crystal Boy addon handles 'Use' in the game window, so nothing is used up.

REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8100,0,'crystal_boy','crystal_boy','Crystal Boy',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8100,'crystal_boy',1,0,0,0,0,0,0,0);
REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8101,0,'ffa_cartridge','ffa_cartridge','Jueno Recollection I',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8101,'ffa_cartridge',1,0,0,0,0,0,0,0);
REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8102,0,'tower_recollection','tower_recollection','Jueno Recollection II',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8102,'tower_recollection',1,0,0,0,0,0,0,0);
REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8103,0,'magi_recollection','magi_recollection','Jueno Recollection III',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8103,'magi_recollection',1,0,0,0,0,0,0,0);
REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8104,0,'time_recollection','time_recollection','Jueno Recollection IV',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8104,'time_recollection',1,0,0,0,0,0,0,0);
REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8105,0,'dragonland1','dragonland1','Dragonland I',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8105,'dragonland1',1,0,0,0,0,0,0,0);
REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8106,0,'dragonland2','dragonland2','Dragonland II',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8106,'dragonland2',1,0,0,0,0,0,0,0);
REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8107,0,'dragonland3','dragonland3','Dragonland III',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8107,'dragonland3',1,0,0,0,0,0,0,0);
REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8108,0,'dragonland4','dragonland4','Dragonland IV',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8108,'dragonland4',1,0,0,0,0,0,0,0);
REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8109,0,'dragonland5','dragonland5','Dragonland V',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8109,'dragonland5',1,0,0,0,0,0,0,0);

-- Anniversary Ring: not Rare, so Recollection rewards can give more than one
UPDATE `item_basic` SET `flags` = `flags` & ~32768 WHERE `itemid` = 15793;
