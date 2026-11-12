# Changelog: Traditional Preservation (Core)

## 0.1.0 (in development, not released)
- Docs (2026-11-12, consistency sweep): the guide and DEVGUIDE use the series' new names (Yogurt, Lard (Melted)).
- **`StationInfo`: a station's info inside vanilla's crafting window** (2026-11-12, for Fish & Meat 0.4.19): new client
  module `TraditionalPreservationCore/StationInfo`. `StationInfo.add(provider)`; `provider(entity)` returns
  `{ rows = { { labelKey, value } }, bars = { { text, share, value, colour } }, notes = { ... } }` or nil. The block
  sits under In Progress, Done and Take All, asks its provider again twice a second and has the window laid out
  again when its height changes. Wraps `ISWidgetCraftLogicOutputProgress.createDynamicChildren` and
  `.calculateLayout`, only once a mod adds a provider; a window with no block goes straight to vanilla's.
  `InfoWindow.wrapped` is shared with it. Tests in `tests/test_station_info.lua`.
- **One wrap of `ISInventoryTransferAction.transferItem` for every mod** (2026-11-12, user's pick): new client module
  `TraditionalPreservationCore/Transfer`, `Transfer.before(fn)` (the item still where it was) and `Transfer.after(fn)`
  (once vanilla has moved it), `fn(action, item)`, run in the order added. FluidAgeing's look and Dairy's heat stamp
  moved onto it; Salt's brine swap (step 2) will use `after`. Fish & Meat's crock wrap is still its own (roadmap §7).
  Test: `test_transfer`.
- **Slot rules by recipe** (Fish & Meat 6a): `UI.slotRules{ recipeRefusal = fn(slot, item) }`, optional. `slot.recipe`
  is the short name of the window's selected recipe (the station's `CraftLogic:getCurrentRecipe()`). A refused item gets the red border and a halo on drop,
  as with `refusal`; and Craft (`ISWidgetCraftLogicControl.startCraft`, wrapped only when a mod passes the rule)
  refuses to start while any stored input fails it, since the recipe can change after loading. Found in game: with
  OnTest alone, vanilla started the recipe and left the refused item in its slot.
- **The fire's record** (Smokehouse 5c): `Hearth.logFire(state, now, mode, ends)`, run from HearthWorld's update,
  keeps on each Hearth and Firebox the hours of stoked and banked fire (`stokedHours`, `bankedHours`) and the stoked
  session now running (`session`, `sessionBase`, `stokedLast`; `Hearth.sessionHours`): unbroken stoking, a gap of up to
  `SESSION_GRACE` (1 h) kept. Hours count only up to when the fire was due to go out (`fireEnds`), because vanilla burns
  a lit fire's away time in one go when its chunk loads (ENGINE_NOTES). `fireId` tells a rebuilt fire's record apart.
- **Doors keep their front free** (user, Smokehouse 5b-2b test): `Doors` (shared) registers tiles with a door or
  fire mouth and the way it opens: the Hearth's mouth and the Firebox's door, every look; mods add theirs (Fish & Meat's
  Smokehouse). None is built or put down with something in front of its door (an object that blocks placing, or a
  wall between), and nothing checked stands on a tile in front of one's door. Build menu: the entities'
  `OnIsValid = TraditionalPreservationCore.doorFits`; putting down: `UI.keepDoorsFree(sprites)` (extra station
  sprites a mod wants kept out of door fronts). Vanilla furniture isn't checked. Test `test_doors.lua`. Dev:
  `TPC.doors()` says what blocks a tile.
- **A moved Hearth or Firebox rotates again:** the engine links a moveable's facings only for a small GroupName +
  CustomName group (IsoWorld.LoadTileDefinitions; the Hearth's 6 and the Firebox's 14 tiles were left unlinked), so
  only the plain look (empty copper, capped flue: the ones that pick up) keeps `GroupName = Stone`. Tiles rebuilt.
- **Firebox** (Fish & Meat's Smokehouse, ROADMAP §7 phase 5b): the Hearth's fire without the copper, a low stone box
  with an iron door; build menu, Masonry 2, 8 Clay Bricks, 2 Clay, trowel kept. Swapped for a vanilla fireplace as
  the Hearth is (`OnCreateFirebox`), so it cooks like an oven and warms stations within 2 tiles; Bank / Stoke, the
  fuel count, the loot-window button and Firebox Info as the Hearth's. `Hearth.isFirebox`, `Hearth.isFire` (either).
  Its flue: capped, or a clay pipe from the top or a stone-roofed trench from the foot to its back or either flank,
  never the door's side (`Hearth.setFlue(state, flue, side)`, state `flue` / `flueSide`, `Hearth.FLUE_SIDES`,
  `Hearth.flueSideTo`, `Hearth.flueSquare`); its tile is picked by facing, flue and side, as Fuel Barrel picks its
  barrel's, and its glow shows through the door's vents, with smoke round the door while capped.
  `HearthUI.addFireboxMenu`, `HearthUI.addFireboxNotes`, `HearthUI.fireIcon`. Art: tiles 10-31, page 1024;
  the Hearth's tiles unchanged. Console `TPC.fireboxKit()`, `TPC.firebox()`, `TPC.flue(kind, side)`, `TPC.fuel` on either fire; tests.
- The copper can change a fluid for a mod (Fish & Meat's fat): `Hearth.turnsHot(from, to, hours)` (kept at 85 C
  or more for that long in all, `hot` in the copper's state), `Hearth.goesOff(from, to)` with `Hearth.offBy(copper,
  hour)` (`offAt`), and `Hearth.staysIn(name)` for a fluid no container can be filled with (Fill from Copper is
  greyed with the reason). `Hearth.hoursToTurn`, `Hearth.poursOut`. `HearthUI.addMenu(fn)` adds a mod's rows to the
  Hearth's menu.
- Tooling: Fish is now Fish & Meat (`TraditionalPreservationFishMeat`, console `TPFM`). `tp` takes `FishMeat`, and
  still `Fish` as an alias; the golden folder and `golden.json` entry are renamed, the recorded output is unchanged.
- `Weather.placeOf(object, withCovered)`: a caller that asks gets "Covered" for a roof over a square that isn't in
  a room (`not square:isInARoom()`: no map room and no player-built room, i.e. walled all round and fully roofed).
  Other callers still get "Sheltered" there, so Yeast, Vinegar, Dairy and Salt are unchanged. Fish asks.
- `UI.notInRooms(sprites)`: like `UI.outdoorOnly`, but refuses only a square in a room, so a station may go under a
  porch or open-shed roof (Fish's Beam and Gantry).
- `Weather.showClock` takes an optional speed, for a clock run shorter than its recipe's time (Fish's press by
  the heaviest fish). Default 1, so Salt's leaching is unchanged.
- A bigger copper (user 2026-11-11, for realism): `Hearth.COPPER_ML` 20 L -> 60 L (real ones 40 to 100 L). Same build
  cost; heating still by the cube root of what is in it, so 10 L is unchanged and a full copper steams in about 2.75 h.
- Water boils (user 2026-11-11): water or tainted water alone heats towards `WATER_FIRE_C` (110) and holds at
  `BOIL_C` (100); tainted water at the boil for `BOIL_HOURS` (10 min) turns to water. New key `boiled` in `tpHearth`
  (hours at the boil; cleared when the fire goes out, fluid is poured in or the copper is emptied). Milk and every
  other fluid still top out at 95 C. Water, let boil, steams sooner than milk. `TPC.hearth()` shows the minutes at
  the boil.
- `UI.itemName(item)` and `UI.nameHook(fn)`: an item's name in a menu, vanilla's unless a mod has a say. The Hearth's
  Pour into and Fill from the Copper menus use it (Dairy names wrapped pots).
- `Station.hotContainers(square, radius, heat, fn)`: every item container at a vanilla temperature or hotter near a
  square. `FluidAgeing.lookOnHeat` uses it; Dairy uses it to burn wraps left on the heat.
- Banked Hearth (user 2026-11-11): vanilla's fire is put out while banked, since its room heat and light reach 8 tiles
  whatever the fuel. In its place the mod adds its own heat source (2 tiles, 25 C), a faint light (radius 1) and a hot
  firebox (custom container temperature 1.8, cooking slowed to a third as before); none is saved by the game, so each
  refresh puts them back, and they are taken away when the area unloads (`Station.tracker` option `dropped`). The fuel
  is the mod's count on the clock, set on vanilla's; burnt down, the fire goes out. `Hearth.isBurning` (lit or banked)
  replaces `isLit` in every check: by a fire, fuel hours, Hearth Info, the menus, the pick-up rule. Vanilla's Light
  Fire (menu and loot window) gives way to Put out Fire on a banked Hearth, which unbanks it (`TPHearthFire` mode
  "out"); vanilla's fuel line says Banked. Logic in `HearthWorld.setFire`; test `test_hearth_world.lua`.
  A banked firebox's cooking is set back every tick, not each refresh: the cooking bar climbed and snapped back
  (in-game step 52).
- Debug: `TPC.probe` and `TPC.unprobe` removed (the build replaces them); `TPC.probeRead` is now `TPC.warmth`.
- Bank the Fire / Stoke the Fire as a button in the loot window, beside vanilla's Put out Fire, while a Hearth burns
  (`HearthLootControls`, a vanilla loot-window handler; controller menu too). Same action as the right-click menu.
- Debug only: `TPC.probe(r, c)`, `TPC.unprobe()`, `TPC.probeRead()` try the banked-Hearth design in game (vanilla
  fire out, a Lua heat source and light, the firebox kept hot by a custom temperature). Not a feature.
- Empty the Copper (user 2026-11-11): the Hearth's menu pours whatever the copper holds away in one go, with its
  age record (rotten milk above all; before, it went out a container at a time). `TPHearthCopper` mode "empty", no
  item; the time grows with the litres, as a pour does. Hover: how much of what.
- Docs: TP Core has its own `README.md` (the Hearth, the copper, banking, by a fire, places, fluids that go off),
  `DEVHELP.md` (the `TPC` console), `WORKSHOP.txt` and a player guide, `6_Core_Guide.md`. The Hearth was documented
  only in Dairy's. The collection guide (0) is rewritten for five mods and Core.
- Docs (2026-11-11 pass against the code): `TPC.help()` and `TPC.kit()` say the Hearth is Masonry 2 (said Pottery
  2); DEVGUIDE lists every core module, `FluidAgeing.register` and `Recipes.addFluids`, Dairy's `ISEatFoodAction`
  wrap and the core's real globals.
- The Hearth's copper holds 20 L (was 10). Heating and cooling times are still set for 10 L and grow with the cube root
  of the volume (`Hearth.TAU_ML`): 10 L steam in about 1.5 hours as before, 20 L in about 2.
- Scalding on a stove or a fire (`FluidAgeing`, `scaldHeat`): a kind may name a vanilla item heat it scalds at. A
  fluid item seen that hot is scalded from then on, as vanilla's boiling makes tainted water clean. It is checked
  when a loot window shows it, as it is moved (`ISInventoryTransferAction.transferItem`, read while still on the
  heat), and every game minute in any hot container within 8 tiles of a player (`lookOnHeat`). Both ends of a vanilla
  pour are looked at as it ends (or is stopped), so mixed milk is renamed at once.
- Scalded twins (`FluidAgeing`, D9 step 2b): a kind may name a scalded fluid for each fresh one (`scalded`). A scalded
  fresh record goes by it, in containers and in the copper (renamed as it steams), and back to the plain fluid when
  raw is mixed in; it spoils to the fresh fluid's spoiled one. A container first seen holding only scalded fluid is
  scalded; `markScalded` renames at once. The record's flag is `scalded` (was `steamed` in test builds, still read).
- More fluids for a vanilla recipe (`Recipes.addFluids`, D9 step 2): at `OnInitWorld` a mod widens a vanilla craft
  recipe's fluid line (Dairy: every milk, fresh or soured, in cake batter, muffins and cereal). A script copy of the recipe can't do it,
  as the game adds a copy's inputs to the original's. A line that names the fluids already is left alone.
- Fluids that go off (`FluidAgeing`, D9): a mod registers a kind of fluid (Dairy: milk) with a twin for each fresh fluid,
  a spoiled fluid and a rate curve; the core keeps an age record (`tpFluidAge`) on the item or object holding it, counted on
  the mod's weather ledger by place (a powered fridge by the clock at 4 C, a freezer not at all), and swaps the fluid
  when it turns and when it spoils. What players carry is checked every ten minutes and loot windows check what they
  show. Pouring hands the age on (the older wins), milking into an emptied container starts afresh, and the Hearth's
  copper keeps the age of what is in it and ages it at the Hearth's place: turned or spoiled milk is renamed in
  the copper too, so the incubator and the crock refuse it there; milk in a steaming copper is scalded from then on. Sealed items a mod names (store
  milk) never age until poured out.
- `tp test` lints each mod's shipped Lua for calls the game's Lua lacks though luajit has them (`next`), which
  tests can't catch.
- Fixed: the debug `here()` commands (`TPD.here()`, `TPY.here()`, ...) said "Open" under a roof with no walls, where
  every station and the game's rain count it as sheltered. `Weather.placeOf` now asks the square, not the object
  (a player's `isOutside()` only means "not in a room"). Stations behave as before.
- `tp new` gives the new mod a CHANGELOG.md (a 0.0.1 entry naming its station), as every TP mod keeps one.
- Menu icons: the copper's options show a copper (empty for the status line and Pour into Copper, full of milk for
  Fill from Copper), Bank Fire shows the Hearth banked and Stoke Fire the Hearth lit (both showed the Hearth
  logo). Each container row shows the item as the inventory draws it, so a bucket of milk is white and one of water
  blue (was the bare item icon). The icons are drawn by `tools/build_tileset.py`.
- New Hearth art (was a grey placeholder): a waist-high block of split fieldstone, as vanilla's kilns are built,
  with a lime-rendered top, an arched fire mouth on the side it faces, and a hammered copper pan set in it, empty,
  full or steaming. The mouth glows while the fire burns and shows only dull embers when it is banked (the
  hearth's overlay sprite, as vanilla lights its kilns). The stone has hard edges; the steam and the glow are soft.
  `pzart.hard_edges` is shared now (Dairy used its own copy).
- Balance (series pass, F1): the Hearth is laid brick, so it is Masonry 2, gives Masonry XP and sits in the
  Masonry build category (was Pottery 2, Pottery XP, Pottery).
- New `UI.offAppliances(sprites)`: a table-top station refuses a square holding a stove, a fridge or freezer, or a
  washer or dryer, when built and when put down. Vanilla lets a table-top tile onto any table surface, electric
  stoves and chest freezers included.
- The copper takes fluids that blend: a mod names a group with `Hearth.blend(...)` (Dairy: cow's and sheep's milk)
  and those share the copper, a blend going in and out in its shares (`Hearth.partsIn`, `partsOf`, `addParts`,
  `share`; `Hearth.take` returns the ml by fluid as a fourth value, and the `filled` hook gets `parts`). Anything
  else is still one fluid at a time. The Hearth's menu and Hearth Info name each fluid of a blend.
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
