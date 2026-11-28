# Weddings (XI: Forever Offline)

The November 2009 wedding service, ported from KiplingFFXI/server (`Retail-Wedding-System`, fe6bd2bd98, GPLv3).
Out of era on purpose: a fun extra, on by default.

- Wedding Masters: Rembard (Chateau d'Oraguille), Cloud Walker (Metalworks), Pompi-Rompi (Heavens Tower).
  A party of exactly the two of you, both level 20+, standing by the Master, one wearing a Matrimony Ring and
  the other a Matrimony Band (or an old Wedding Ring): each gets that nation's Marriage Certificate (furnishing).
- Matrimonial Coffer (rings and bands) and Celebratory Chest (fireworks, Serinettes, wedding goods) in the three palaces.
- Goldsmithing: Matrimony Ring / Band, and engraving the couple's names with a cyclone crystal.

Core files changed (from Kipling): `scripts/globals/wedding.lua`, `matrimonialcoffer.lua`, `shop.lua`, the palace NPC
scripts, `scripts/enum/item.lua`, `src/map/utils/synthutils.cpp`, `src/map/lua/lua_base_entity.cpp/.h`, `src/map/items.h`,
`modules/era/lua/globals/celebratory_chest_stock.lua`, tests in `scripts/tests/systems/`. The C++ needs a map server build.

This folder: `data/zones/*/npcs.yaml` shows the nine NPCs (core tags them as a later expansion), and
`sql/wedding_recipes.sql` adds the four recipes without the ASA tag.

Turn off: put `#` before the `wedding` line in `modules/init.txt` and restart the server (the NPCs disappear).
