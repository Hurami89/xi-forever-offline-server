-- Crystal Boy items (written by install_crystalboy_items.py). Listed in modules/init.txt so dbtool
-- puts them back after a server update. Flags: CanUse, CanTradeNPC, NoAuction, NoSale, NoDelivery, Ex, Rare.
-- No item scripts: the Crystal Boy addon handles 'Use' in the game window, so nothing is used up.

REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8100,0,'crystal_boy','crystal_boy','Crystal Boy',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8100,'crystal_boy',1,0,0,0,0,0,0,0);
REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8101,0,'ffa_cartridge','ffa_cartridge','Mana Recollection',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8101,'ffa_cartridge',1,0,0,0,0,0,0,0);
REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8102,0,'tower_recollection','tower_recollection','Tower Recollection',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8102,'tower_recollection',1,0,0,0,0,0,0,0);
REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8103,0,'magi_recollection','magi_recollection','Magi Recollection',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8103,'magi_recollection',1,0,0,0,0,0,0,0);
REPLACE INTO `item_basic` (`itemid`,`subid`,`name`,`sortname`,`name_jp`,`type`,`stackSize`,`flags`,`aH`,`BaseSell`) VALUES (8104,0,'time_recollection','time_recollection','Time Recollection',5,1,63040,0,0);
REPLACE INTO `item_usable` (`itemid`,`name`,`validTargets`,`activation`,`animation`,`animationTime`,`maxCharges`,`useDelay`,`reuseDelay`,`aoe`) VALUES (8104,'time_recollection',1,0,0,0,0,0,0,0);

-- Anniversary Ring: not Rare, so Recollection rewards can give more than one
UPDATE `item_basic` SET `flags` = `flags` & ~32768 WHERE `itemid` = 15793;
