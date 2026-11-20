# Traditional Preservation (__NAME__) — Build 42 prototype (v0.0.1)

Made by `tp new` on __DATE__ from `~/MODS/TraditionalPreservationCore/template`. TEMPLATE: everything below describes the skeleton;
rewrite it as the mod takes shape. Settle the questions in `~/MODS/WIP/TPCore/SERIES.md` ("Designing a new mod") first.

## Install

`tp install __NAME__` copies the mod to `~/Zomboid/mods/__MOD__` after its tests pass.

## How it works (skeleton)

1. **Build a __STATION__** (Build menu, Furniture): 4 planks + 8 nails + any hammer, Carpentry 2.
2. Right-click it and put up to 4 Raw __NAME__ Batches in (**Put Raw Batches In**, One or All), or drag them onto
   the cells in **__STATION__ Info**. Each put-in is a batch with its own clock.
3. After 3 in-game days at the best temperature, take out the Finished __NAME__ Batches (**Take Done**). Anything in
   the station keeps it where it is.

A batch works by the temperature where the station stands (open air, under an open roof, indoors, in a basement), through the
shared weather ledger, and keeps working while the area is unloaded. **__STATION__ Info** shows each batch's progress and
time left, the place and its temperature.

`luajit tools/season_report.lua` prints the days a batch takes by month and place (golden-checked by `tp test`).

## Rebuilding the tileset

`python3 tools/build_tileset.py` (needs Pillow) paints the station and writes `42/media/__LOWER__.tiles`,
`42/media/texturepacks/__LOWER__.pack`, the icons and the generated `42/media/lua/shared/__MOD__/Tiles.lua`
(don't edit it by hand). `luajit tests/test_tiles.lua` checks the entity scripts against it.

## Debug commands

In debug mode, `__SHORT__.help()` in the Lua console lists commands for testing this mod. See `DEVHELP.md`.

## Engineering notes

- The shared core (Weather, Station, UI) is the required TP Core mod (`~/MODS/TraditionalPreservationCore`), loaded as `require "TraditionalPreservationCore/Weather"`. Edit it there.
- `tiledef` __TILEDEF__ was picked by `tp new` as the next free number.
- A piece-record station (Core DEVGUIDE, "Which kind of station?"): no crafting window, the batches live in the
  station's movableData.
- Save keys: the ledger lives in global ModData under `__MOD__` (totals `process<Place>`), and the station's batches
  under `__LOWER__Station` (`batches`: `id`, `count`, `work`; `nextId`). Never rename them once the mod is out.
- Singleplayer only for now.
