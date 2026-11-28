-- XI: Forever Offline wedding module (2026-11-27). Ported from KiplingFFXI/server, branch Retail-Wedding-System
-- (commit fe6bd2bd98, "Implement the retail wedding system", GPLv3). Thanks Kipling.
-- The 2009 wedding service is out of era (ASA); Hurami chose to have it anyway. Core tags these recipes 'ASA',
-- which ENABLE_ASA = 0 would hide, so here they carry no tag. Listed in modules/init.txt ('wedding'), so dbtool
-- puts them back after a server update. Popper II (2022) is left out: the era chest stock does not sell it.
-- 77674/77675: Goldsmithing 65, fire crystal, 2 platinum ingots + diamond(s) -> Matrimony Ring / Band.
-- 77676/77677: cyclone crystal + the ring or band -> the same, engraved with the couple's names (no skill needed).
REPLACE INTO `synth_recipes` VALUES (77674,0,0,0,0,65,0,0,0,0,0,4096,4238,746,746,787,0,0,0,0,0,15847,15847,15847,15847,1,1,1,1,'Matrimony Ring',NULL);
REPLACE INTO `synth_recipes` VALUES (77675,0,0,0,0,65,0,0,0,0,0,4096,4238,746,746,787,787,787,787,787,0,15848,15848,15848,15848,1,1,1,1,'Matrimony Band',NULL);
REPLACE INTO `synth_recipes` VALUES (77676,0,0,0,0,1,0,0,0,0,0,4098,4240,15847,0,0,0,0,0,0,0,15847,15847,15847,15847,1,1,1,1,'Matrimony Ring',NULL);
REPLACE INTO `synth_recipes` VALUES (77677,0,0,0,0,1,0,0,0,0,0,4098,4240,15848,0,0,0,0,0,0,0,15848,15848,15848,15848,1,1,1,1,'Matrimony Band',NULL);
