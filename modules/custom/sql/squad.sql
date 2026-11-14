-- Squad mates (v0.5): persistent, customizable Trust-style party members.
-- Each squad mate has its own level and exp for every job, like a real character.
-- (The v0.1 table `char_squad` is no longer used.)

CREATE TABLE IF NOT EXISTS `squad_mate` (
  `id`       int(10) unsigned NOT NULL AUTO_INCREMENT,
  `charid`   int(10) unsigned NOT NULL,
  `slot`     tinyint(3) unsigned NOT NULL,
  `name`     varchar(15) NOT NULL DEFAULT 'Squad',
  `race`     tinyint(3) unsigned NOT NULL DEFAULT 0,  -- 0 = use the template trust's look, 1-8 = player races
  `face`     tinyint(3) unsigned NOT NULL DEFAULT 0,  -- 0-15 (faces 1A-8B)
  `nation`   tinyint(3) unsigned NOT NULL DEFAULT 0,
  `mjob`     tinyint(3) unsigned NOT NULL DEFAULT 1,
  `sjob`     tinyint(3) unsigned NOT NULL DEFAULT 0,
  `template` smallint(5) unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `charid_slot` (`charid`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `squad_job` (
  `squad_id` int(10) unsigned NOT NULL,
  `job`      tinyint(3) unsigned NOT NULL,
  `level`    tinyint(3) unsigned NOT NULL DEFAULT 1,
  `exp`      int(10) unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`squad_id`, `job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Equipment: one outfit per squad mate per job. slot = equipment slot index
-- (0 main, 1 sub, 2 ranged, 3 ammo, 4 head, 5 body, 6 hands, 7 legs, 8 feet, 9 neck, 10 waist, 11-12 ears, 13-14 rings, 15 back)
CREATE TABLE IF NOT EXISTS `squad_equip` (
  `squad_id` int(10) unsigned NOT NULL,
  `job`      tinyint(3) unsigned NOT NULL,
  `slot`     tinyint(3) unsigned NOT NULL,
  `itemid`   smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`squad_id`, `job`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Shared collection: an item given to your squad once can be worn by any squad mate (it is not used up again)
CREATE TABLE IF NOT EXISTS `squad_unlock` (
  `charid` int(10) unsigned NOT NULL,
  `itemid` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`charid`, `itemid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
