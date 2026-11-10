# Changelog: Traditional Preservation (Core)

## 0.1.0 (in development, not released)
- Tooling (2026-11-10 review, group E: R28, R29). No change to the game's files:
  - `tp install` and `tp status` warn when the installed TP Core is missing or not the source's, so a mod isn't
    tested in game against an old core.
  - New `tp package MOD... [--out DIR]`: the Workshop upload folder (`Contents/mods/<Mod>`) with `42/`, `common/`,
    README, guide and CHANGELOG only; tests, tools, DEVHELP and WORKSHOP.txt stay out.
  - Harness: `H.checkConsole` (a Dev console loads only in debug mode, and its `help()` matches its commands),
    `H.player`, and for menu tests `H.installMenus`, `H.menu`, `H.vessel`, `H.class`.
  - New tests: `test_console.lua` (TPC) and `test_hearth_menu.lua` (the Hearth's menu: status line, pour in, fill,
    bank and stoke, vanilla's submenu, the controller's probe, the pick-up rule; 31 checks).
  - Template: `tests/test_console.lua`, so a new mod starts with its console tested. Fixed there: `here()` passed a
    square to `placeOf` and would have thrown, as Yeast's did (R7).
- Core consolidation (2026-11-10 review, group C: R14-R23), so each mod stops carrying its own copy:
  - **One weather for the series** (R18). The last reading and the season's means (temperature, and humidity for
    Fish) live once in the core's ModData (`Weather.shared`, the ledger the Hearth already had). `Weather.record`
    is now one ten-minute handler that takes the reading first and then runs each mod's recorder, and
    `Weather.advance` copies the series' mean instead of growing one per mod (`Weather.season`). A mod added to a
    running save agrees with the others about the temperature under a roof from its first day. Save keys stay;
    tools and tests, which have no shared state, work as before (goldens unchanged).
  - `UI`: menu helpers `findItems`, `tooltip`, `disable`, `litres`, `degrees`, `hoursText`, `fluidName` (R17);
    `UI.keepInPlace(test)` is the one wrap of the pick-up check and its cursor line (R17);
    `UI.progressTooltips` makes a slot's popup once, not at every list update (R20).
  - `InfoWindow.clickOpens(test, open)` is the one wrap of `ISObjectClickHandler.doClickSpecificObject` (R15);
    notes are wrapped once and kept until their text or the window's width changes (R20).
  - `Station.kinds(prefix, faces, bases)`: which station an object is by a table lookup on its sprite's name (R19).
    `Station.tracker{ scan = true }` and `Station.players()`: the look round each player for stations built or put
    down this session, one pass for every tracker that asks (R16). The Hearth uses both.
  - New `TraditionalPreservationCore/Action` (R21): `duration` honours the instant-actions cheat, `pourDuration`
    holds the pouring speed four actions each spelt out. New `TraditionalPreservationCore/Log` (R22): console lines
    only in debug mode. `Container.fluidIn` (R17). `Weather.sensitivity` and `SENSITIVITY_SCALES` (R20).
  - Timed actions are `TPHearthCopper` and `TPHearthFire` (were `IS...`), file and class (R21).
  - Removed `World.hearths` (never called) and the Hearth's own weather recorder (R23, R18).
  - DEVGUIDE: "What the core already does", the `TP` prefix for timed actions, the wrap table. 9 new checks in
    `test_core.lua` for the series' weather.
- Review fixes (2026-11-10 review, R1, R6, R11, R12):
  - Fixed: a cold item read as low as -86 C (milk from a powered fridge, in the copper, the pour menus and Dairy's
    crock). Below room heat `Hearth.heatCelsius` now uses a gentler scale: the engine's floor of 0.2 (fridge or
    freezer) reads 4 C (`Hearth.COLD_HEAT`, `Hearth.COLD_C`), and nothing reads colder. `Hearth.itemHeat` is its
    mirror, so a cold copper's fill keeps its temperature, down to that floor.
  - Fixed: the Hearth's menu answers vanilla's controller probe (`ISWorldObjectContextMenu.setTest()`).
  - `UI.slotRules` asks a mod's `station()` only about world objects (`instanceof IsoObject`): an item that is a
    crafting entity has no sprite to read and goes straight to vanilla.
  - `Weather.getLedger` starts a new ledger on the weather there is, so a new game or a mod added to a save no
    longer reads 0 C (10 C under a roof) for its first ten minutes.
  - Tests: lower bound and cold round trip in `test_hearth.lua`; ledger seeding and the item-entity case in
    `test_core.lua`.
- New `TraditionalPreservationCore/Container` (review R9): a bucket that a chain of recipes turns into other items
  comes back as the bucket it was. `Container.note` (first recipe's OnCreate), `Container.pass` (a recipe in
  between) and `Container.giveBack` (last recipe: swaps the script's placeholder for the noted type). The note is
  the modData key `condition:tpContainer`, because the engine's cooking swap (`ReplaceOnCooked`) carries over only
  keys starting with `condition:`. Used by Salt and Vinegar. 12 checks in `tests/test_container.lua`.
- DEVGUIDE: the wrap table names every mod that wraps the pick-up and click handlers; the layout table drops the
  `Core/` row.
- TP Core is now a mod that the TP mods require (`require=\TraditionalPreservationCore`). Its Lua moved from `lua/`
  to `42/media/lua/<side>/TraditionalPreservationCore/` and is loaded as `require "TraditionalPreservationCore/Weather"`
  (also `Station`, `UI`). Dairy and new mods (`tp new`) use it; Salt, Fish, Yeast and Vinegar keep a `tp sync` copy
  until they move over.
- `tp`: the core counts as a mod (`tp test Core`, `tp install Core`, which ships only `42/`); `tp sync` reads the new
  path and copies only into mods that still carry a copy; `tp new` no longer syncs a copy. The harness's
  `H.useModPaths()` also finds the core's Lua.
- The Hearth moves into the core (S2, part a: rules and world; art, menus and Hearth Info follow). New
  `TraditionalPreservationCore/Hearth`: the copper (one fluid, heats over a lit fire, cools in the stone), item heat,
  the opt-in "by a fire" place (28 C, any lit fire within two tiles, never a stove; `Weather.placeOf` never returns
  it), and hooks (`heatOf`, `taken`, `filled`) so a mod can follow fluid in and out of the copper. Save key
  `tpHearth`. `HearthWorld` (server) tracks every Hearth, keeps its copper up to date on the core's own weather
  ledger and swaps its look. Timed action `ISHearthCopper` (Pour into / Fill from the Copper). `tp sync` never
  copies these (`REQUIRED_ONLY`). 27 checks in `tests/test_hearth.lua`.
- The Hearth is built from TP Core (S2b): entity `TraditionalPreservationCore.TP_Hearth` (still Pottery 2, 12 clay
  bricks, 4 clay, a copper sheet; recipes get one balance pass after Dairy), its own tileset
  (`traditionalpreservationcore`, tiledef 5173, `tools/build_tileset.py`, the art as it was in Dairy), build icon
  and mod icon. Client `HearthUI`: the Hearth submenu inside vanilla's (copper status, Hearth Info, Pour into / Fill
  from the Copper), the pick-up block while lit or holding fluid, Hearth Info (fire, fuel, copper, holds, heat, and a
  Steaming row for any fluid), `HearthUI.addNotes` for a mod's own notes. Client `InfoWindow`: the base of every
  info window (rows, bars, notes, closes out of reach, one at a time across mods), from Dairy's Pot Info.
  Translations under `TraditionalPreservationCore`. Hearths built in older test saves are gone: rebuild them.
- Left-clicking a Hearth opens Hearth Info (user, after test H), as an incubator's click opens Incubator Info.
- Banked fire (S3): "Bank the Fire" / "Stoke the Fire" on a lit Hearth's menu (timed action `ISHearthFire`). Banked,
  it burns a third of the wood, the copper settles at 50 C (never steams) and food in the firebox cooks a third as
  fast. Vanilla's fireplace has one speed, so the core keeps its own reckoning (`Hearth.reckonFuel`,
  `Hearth.bankedCooking`) and sets vanilla's fuel and each food's cooking time back to it, and lights the fire again
  if vanilla burnt it out at full speed while its area was unloaded. Putting it out or burning down ends banking.
  New opt-in place `Hearth.EMBERS` (24 C) by a banked Hearth; `Hearth.fireC`, `Hearth.isFirePlace`; a lit fire nearby
  wins over a banked one. Hearth Info shows Fire "Banked", the burn time left and a banked note. Flames, light and
  room heat stay vanilla's. Save fields under `tpHearth`: banked, fuel, fuelAt, fuelSet.
- Debug console `TPC` (`client/TraditionalPreservationCoreDev.lua`, debug mode only): `TPC.hearth()` (shows banked
  and the reckoned fuel), `TPC.copper(l, c, fluid)`, `TPC.fuel(min)`, `TPC.hot()`, `TPC.kit()` (a Hearth's materials).
  Moved from Dairy's `TPD`, since the Hearth is the core's.
- Core split finished: Yeast, Fish, Vinegar and Salt require TP Core (none carries a copy). DEVGUIDE says so and adds
  the test require-stub rule; `tp sync` refuses a mod that requires TP Core.
