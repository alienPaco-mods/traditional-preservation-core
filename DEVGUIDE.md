# Traditional Preservation: development guide

How to work on the TP mods (Salt, Fish, Yeast, Vinegar, and every new one) and on FuelBarrel. What the mods are and
how they fit together: `~/MODS/WIP/TPCore/SERIES.md`. The plan for the shared core is in `~/MODS/WIP/TPCore/ROADMAP.md`
(local notes, not in git). Verified engine facts are in `~/MODS/_pzdev/ENGINE_NOTES.md`.

Tip: `alias tp=~/MODS/TraditionalPreservationCore/tp` (the examples below use it).

## Where things live

| Path | What it is |
|---|---|
| `~/MODS/<Mod>` | The source. Each mod is its own git repo. Edit here. |
| `~/Zomboid/mods/<Mod>` | The installed copy the game loads. Only `tp install` writes here. |
| `~/MODS/TraditionalPreservationCore` | TP Core, the mod itself (`42/`, `README.md`, `DEVHELP.md`, `WORKSHOP.txt`, its player guide `6_Core_Guide.md`), and the shared tooling: `tp`, the test harness, the golden results, this guide. |
| `~/MODS/guides` | The player guides. The copy inside each mod is made from these by `tp guides`. |
| `~/MODS/_pzdev` | Engine notes and `jdis.py` for reading the game's classes. |

## The everyday loop

1. Edit in `~/MODS/<Mod>`.
2. `tp test <Mod>`: the mod's tests, then its golden checks.
3. `tp install <Mod>`: runs the same checks again and copies the mod only if they all pass.
4. Restart the game (Lua or scripts changed) or reload to the main menu (translations only), then follow the in-game test steps.
5. Commit in the mod's repo.

`tp status` shows every mod at a glance: uncommitted changes, whether the installed copy matches, whether the guide copy matches.

`tp install` and `tp status` warn when the installed TP Core is not the source's: a mod tested in game against an
old core passes or fails for the wrong reasons. `tp install Core` clears it.

## Balance changes and the golden results

Some tools print a whole season or a whole batch: Fish's drying table and storage model, Vinegar's souring table and
its batch simulation. Their current output is recorded in `golden/<Mod>/`, and `golden/golden.json` lists which
tools are checked.

**`tp test` and `tp install` compare the tools with those recordings. Any difference fails the check, and `tp install`
then installs nothing.** That is on purpose: it catches a change nobody meant to make, such as a refactor that shifts
a rate.

When you change a number on purpose (souring days, a drying rate, a temperature curve):

1. Run `tp golden <Mod>` and read what changed. Only the numbers you meant to change should move.
2. Record the new results: `tp golden <Mod> --update`. Name the mod, so other mods' recordings stay as they are.
3. Commit the updated files in `TraditionalPreservationCore` along with the change in the mod, so the two stay together.
4. Install as usual: `tp install <Mod>`.

`tp install <Mod> --skip-tests` skips **every** check, tests included. Keep it for emergencies.

To record a new tool, add it to `golden/golden.json` and run `tp golden <Mod>`. A missing recording is created on the
first run. A golden tool must give the same output every run: no randomness, no time of day, and loops over tables
in sorted order (`pairs` order changes between runs).

## Hand edits and installing

`tp install` keeps each file's time when it copies. If you edit a file in the **installed** copy, that file is newer
than the source, and the next install stops and lists it. It also stops for files that exist only in the installed
copy. Bring the edit into `~/MODS/<Mod>` first, or pass `--force` to overwrite. Mods must be real copies, never
symlinks: the game doesn't follow them reliably.

## Tests

Tests are plain Lua files in `<Mod>/tests/`, run with `luajit` from the mod folder. Each one starts and ends like this:

```lua
-- What this checks. Run from the mod folder: luajit tests/test_example.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
...
check("a cask sours in 35 days", near(days, 35))
...
H.done()
```

The harness only adds what a test asks for, so a test keeps its own stubs where it needs different behaviour:

| Helper | What it gives |
|---|---|
| `H.check(name, ok)` | Prints `ok` or `FAIL` and stops at the first failure. |
| `H.near(a, b, tolerance)` | Float comparison, default tolerance 1e-6. |
| `H.list(items)` | A Java-style list: `size()`, `get(i)` from 0. |
| `H.installClock(hours)`, `H.setHours(h)` | `getGameTime():getWorldAgeHours()`. |
| `H.installModData()` | `ModData.getOrCreate`, one table per key in `H.modData`. |
| `H.installEvents()`, `H.fire(name, ...)` | `Events.<Any>.Add`, and firing the handlers added. |
| `H.useModPaths()` | `require` finds the mod's own Lua and TP Core's as the game does, e.g. `require "TraditionalPreservationCore/Weather"`. |
| `H.installGetText()` | `getText` with the mod's real EN translations. Notes the game formatter's `%` errors in `H.textWarnings`. |
| `H.player{ x, y, z, outside }` | A player for a console or a menu: a square, an inventory, and the full types it was given in `.given`. |
| `H.checkConsole(path, name)` | Loads a Dev console as debug mode does: it stays out of a normal game, and `help()` lists every command it has and none it hasn't. Returns the console and `run("command", ...)`, which gives back what the command printed. |
| `H.installMenus()` | What a right-click menu file touches: vanilla's classes, the inventory in reach, the action queue, the pick-up check. Returns the record (`.carried` to set; `.queued`, `.moved`, `.probes`, `.walks` to read). |
| `H.menu()`, `H.vessel(name, fluid, litres, capacity)`, `H.class(name)` | A context menu that keeps its options and submenus, an item with a fluid container, a vanilla class to derive from. |

**How things are named** (2026-11-12; display text only, ids and save keys never follow):

- A state the same piece passes through goes in brackets after its name, as vanilla's do (`Basil (Dried)`, `Clay Jar
  (Unfired)`), several joined by commas: `Walleye (Salt Cured)`, `Steak (Corned)`, `Beef (Hot Smoked)`, `Lard
  (Melted)`, `Cow's Milk (Soured)`, `Yogurt Pot (Unfired)`. Vanilla adds its own `(Fresh)` or `(Rotten)` after.
- A finished product with a trade name is named, fish or animal first: `Walleye Stockfish`, `Beef Charque`,
  `Bresaola`, `Country Ham`. What happens to it later is a bracket again: `(Matured)`, `(Aged)`, `(Soaked)`.
- A part cut from it is a noun after the name: `Walleye Half`, `Walleye Head`, `Beef Slice (Hot Smoked)`.
- `Gutted` is the one prefix (a fish that went through Gut Fish).
- No hyphen in a state: Hot Smoked, Dry Cured, Salt Dried. Vanilla's spelling where it has one: Yogurt.
- Containers read `Pot of X`, `Bucket of X`, `Crock of X`. A name must not read like another thing's plain
  description (Salt's item on the heat is a `Bucket of Boiling Brine`; "a bucket of brine" is a bucket holding Brine).
- A recipe is named for what it gives: `Soak Fish` gives `(Soaked)`.

**The console convention** (2026-11-12; every TP mod, and the template):

| Command | Means |
|---|---|
| `help()` | One line a command; the test fails if a command isn't listed or a listed one is missing. |
| `weather()` | The temperature by place and the mod's rates there. `TPC.weather()` is the series' own reading. |
| `here()` | The weather place the player stands in. Never anything else (Salt's lick tile is `TPS.tile()`). |
| `age(hours)` | Every station of the mod on by that many good hours. Stored food has its own verb, in days where its clock is days (`TPFM.mature(days)`, `TPFM.keep(days)`, `TPD.sour(hours)`). |
| `fast(hours)` | A test timer where the sandbox sets a time; no number goes back to the sandbox. |
| `give(name, n, option)` | Spawns things by a short name; no name lists them. The count always follows the name. A thing with many kinds and stages gets its own command of the same shape: `TPFM.fish(name, n, weight, stage)`, `TPFM.meat(name, n, stage)`, with `"all"` for one of each. |
| `kit(kind)` | What a test or a build needs in one go; `kit("?")` lists the kinds. |

A noun looks and a verb changes (`cask()`, `setCask()`); singular is the nearest station, plural every loaded one
(`pallet()`, `pots()`). Hours for stations, days for stored food, and the help line says which. A renamed or
removed command is changed in four places: the Dev file, `tests/test_console.lua`, `DEVHELP.md` and the guide's
Tester's Toolkit (edit `~/MODS/guides`, then `tp guides`).

Every mod has a `tests/test_console.lua`: it calls each console command its stand-ins can carry, so a command can't
break unseen (Yeast's `TPY.here()` did). Add a line there with each new command. A file with a right-click menu
gets a menu test on `H.installMenus` (`TraditionalPreservationCore/tests/test_hearth_menu.lua`, Dairy's
`tests/test_menu.lua`): build the menu on stand-in stations and read the options, their hovers and what choosing
one queues.

`luajit tests/test_harness.lua`, run from `TraditionalPreservationCore` (or `tp test` with no mod), tests the harness itself, and checks
every mod's translation files for a literal `%`.

## The shared core

`~/MODS/TraditionalPreservationCore` is itself a mod, **TP Core** (id `TraditionalPreservationCore`), that every TP
mod requires (decided 2026-11-10, before the first Workshop release). Its Lua is
`42/media/lua/shared/TraditionalPreservationCore/Weather.lua`, `.../Station.lua`, `.../Container.lua` (a bucket
that comes back as the bucket it was), `.../Recipes.lua` (more fluids for a vanilla recipe's fluid line, at
`OnInitWorld`), `.../FluidAgeing.lua` (fluids that go off), `.../Hearth.lua` (the Hearth and its copper),
`.../Action.lua`, `.../Log.lua`, `.../Portions.lua` (food eaten from a vessel by the portion, and the one wrap of
vanilla's eat action), `.../Handcraft.lua` (the one wrap of `ISHandcraftAction.performRecipe`) and `.../Pour.lua` (the one
wrap of `ISFluidTransferAction`), with `42/media/lua/client/TraditionalPreservationCore/UI.lua`, `InfoWindow.lua`, `StationInfo.lua`,
`HearthUI.lua`, `FluidAgeingUI.lua` and `Transfer.lua` (the one wrap of vanilla's `transferItem`: a mod that needs to
see items moved adds `Transfer.before` or `Transfer.after` instead of wrapping it again), and the server's `HearthWorld.lua` and `FluidAgeingWorld.lua`. A mod that uses it says so in its mod.info:

```
require=\TraditionalPreservationCore
loadModAfter=\TraditionalPreservationCore
```

```lua
local Weather = require "TraditionalPreservationCore/Weather"
```

1. Edit the core only here, and run `tp test Core` (or `luajit tests/test_core.lua` from this folder).
2. `tp install Core` ships only its `42/` folder; the rest of this folder is tooling and private notes.
3. **Every TP mod requires TP Core** (Dairy first; Yeast, Fish, Vinegar and Salt moved over 2026-11-10). None
   carries a copy under `<Mod>/Core/` any more. `tp sync` is left for a mod that would want a copy again, and refuses
   a mod whose mod.info requires TP Core. FuelBarrel isn't TP and doesn't require it (its tests and builder only
   borrow the core's harness and `pzart`). A test with its own `require` stub (e.g. `name:find("^TraditionalPreservation<Mod>/")`)
   must also let `^TraditionalPreservationCore/` through, or use `H.useModPaths()`.
4. **Modules only the required mod has:** `Hearth` (the Hearth and its copper, save key `tpHearth`, the opt-in "by
   a fire" place, hooks), its `Tiles`, the server's `HearthWorld`, and the client's `HearthUI` and `InfoWindow` are
   never copied by `tp sync` (`REQUIRED_ONLY` in `tp`): they own a tileset, a save key, a World and menus, which two
   mods can't both ship. A mod that wants them requires TP Core. Core's art: `tools/build_tileset.py` (tiledef 5173).
5. **Info windows:** derive `TraditionalPreservationCore/InfoWindow` (rows, bars, notes, closes out of reach, one
   window at a time across every mod); see its header and Dairy's Incubator Info. `InfoWindow.clickOpens(test, open)`
   makes a click on the station open it.
   **Info inside vanilla's crafting window:** `TraditionalPreservationCore/StationInfo`, `StationInfo.add(provider)`:
   `provider(entity)` returns `{ rows, bars, notes }` for the mod's station and nil for anything else, and the block
   shows under In Progress, Done and Take All (Fish & Meat's `...Info.lua`). For a station with a vanilla window; a
   station without one keeps an InfoWindow.
6. **What the core already does, so a mod doesn't write it again:**
   - Menus (`UI`): `findItems`, `tooltip`, `disable`, `litres`, `degrees`, `hoursText`, `fluidName`, and
     `keepInPlace(test)` for a station that mustn't be picked up while it holds something.
   - Stations (`Station`): `kinds(prefix, faces, bases)` tells a mod's stations by one lookup on the sprite's name
     (never cut the name apart), and the tracker's `scan = true` finds one built or put down this session at once.
   - Weather: `Weather.sensitivity(option)` for the sandbox's Temperature Sensitivity. The reading and the season's
     means are kept once for the series (`Weather.shared`, in the core's ModData); every mod's ledger copies them
     at each `Weather.record`, so never grow a season mean of your own (`Weather.season`, not `seasonMean`).
   - Timed actions (`Action`): `duration(character, ticks)` honours the instant-actions cheat, `pourDuration` is the
     series' one pouring speed. Every `getDuration` goes through one of them.
   - `Container.fluidIn(fluidContainer)`: the one fluid a container holds, or nil for none or a mixture.
   - `Hearth.blend("A", "B")`: fluids that may share the copper. `Hearth.partsIn(fluidContainer)` is then what a
     container holds by fluid (one fluid or such a blend, nil for any other mixture); a store's own blend is `fluid`
     (the largest share) plus `parts`, kept with `Hearth.addParts` and read with `Hearth.partsOf`.
   - `Hearth.turnsHot(from, to, hours)`, `Hearth.goesOff(from, to)` + `Hearth.offBy(copper, hour)` and
     `Hearth.staysIn(name)`: a fluid the copper changes when kept steaming, one that goes off at an hour, and one
     that can't be filled out (Fish & Meat's raw fat is all three). `HearthUI.addMenu(fn)` and `HearthUI.addNotes(fn)`
     put a mod's rows on the Hearth's menu and its lines in Hearth Info.
   - The Firebox (`Hearth.isFirebox`; `Hearth.isFire` is a Hearth or a Firebox): the Hearth's fire with no copper, in
     the same state table (`tpHearth`). `Hearth.setFlue(state, "Pipe"|"Stones", "Back"|"Left"|"Right")` joins its
     flue (nil caps it); `Hearth.flueSideTo(firebox, square)` is the side a square is on (nil for the door's side or
     not beside it), `Hearth.flueSquare(firebox, side)` the square on a side; `Hearth.FLUE_SIDES` matches the tile
     builder's. `HearthUI.addFireboxMenu(fn)` and `HearthUI.addFireboxNotes(fn)` as for the Hearth.
   - `FluidAgeing.register{ kind, rate, turnHours, spoilHours, fresh, spoiled, scalded, scaldHeat, sealed, ... }`: a
     kind of fluid that goes off (Dairy's milk). The core keeps the age record (`tpFluidAge`) on whatever holds
     it, swaps the fluid when it turns and spoils, and hands the age on through pours and the copper.
   - `Recipes.addFluids(recipe, extra, tag)`: more fluids for a vanilla recipe's fluid line.
   - `Station.near(square, radius, test)` and `Station.nearAt(x, y, z, radius, test)`: what stands round a square,
     nearest first. Never write the double loop over squares again (`Hearth.near` is it at the fire's reach).
   - `Hearth.catchUpRun(modData, ledger, kind, place, rateAt)` and `Hearth.updateRun(craftRecipeData, ledger, kind,
     place, rateAt, speed)`: a weather-timed craft run's catch-up and its bar. A mod keeps only its own place
     default and old-save migration (Yeast, Vinegar, the template).
   - `Portions`: food eaten from a vessel a portion at a time. `set`, `left`, `text`, `name`, `label` and `used` do
     the sums, the name ("Jar of Yogurt (3 portions)", the core's text), the weight and the empty vessel;
     `Portions.onEat(fullType, before, after)` hangs a mod's handlers on the one wrap of the eat action.
   - `Handcraft.around(before, after)` / `Handcraft.after(after)`: handlers on the one wrap of the hand craft
     action, for a mod that gives something back for what a craft used up.
   - `Pour.before(name, fn)` / `Pour.after(name, fn)` (name is `start`, `stop` or `complete`) and `Pour.owner`:
     handlers on the one wrap of the fluid transfer, for what rides along with a fluid.
   - `Container.ml(container)` and `Container.isEmptyVessel(item)`; `Recipes.created(craftRecipeData, wanted)` and
     `Recipes.consumed(...)`: an OnCreate's own items as a Lua list, by full type or a set of them.
   - `Log`: `log("TPV", "format", ...)` prints only in debug mode. Lines the test steps read go through it; a
     normal game's console stays clean.

Core modules return a local table and never set a global.

## How a mod is laid out in code

Every TP mod splits the same way (`tp new` makes this layout), under `42/media/lua/`:

| File | Side | What it holds |
|---|---|---|
| `shared/<Mod>.lua` | both | The public table (`TraditionalPreservationFishMeat`, ...): constants, sandbox, rate curves, ledger, recipe hooks (`OnStart`/`OnUpdate`/`OnTest`/`OnCreate` named by the scripts). No UI, no tracking. |
| `shared/<Mod>/Tiles.lua` | both | Generated by the builder. Never edit. |
| `shared/TimedActions/TP*.lua` | both | The mod's own timed actions, file and class named alike with a `TP` prefix (`TPBottleVinegar`): the game loads one file per Lua path across all mods, so a generic name could be replaced by another mod's. |
| `server/<Mod>World.lua` | server | The station tracker (`Station.tracker`), sprites and overlays, the weather recorder. Public as `<Mod>World` (`track`, `refresh`) so the UI can start tracking a station built this session. Yeast calls it `...Shelf`. |
| `client/<Mod>UI.lua` | client | Popups, slot rules, context menus, and the mod's own vanilla wraps. Salt's is `...Menu`, Yeast's `...ShelfUI`. |
| `client/<Mod>Dev.lua` | client | The Dev console (`TPFM`, `TPS`, `TPV`, `TPY`, `TPD`), documented by its `help()` and DEVHELP. Vinegar also has `...Debug.lua`, debug-mode only. TP Core's is `TPC` (`TraditionalPreservationCoreDev.lua`): the Hearth's commands, whichever mods are on. |

Extra shared files hold a separate piece of the game that stands on its own: Fish's `...Evolved` (stock pots), Salt's
`...Shaker`, Vinegar's `...Bottles`.

**The local alias.** Each file starts with `local F = TraditionalPreservationFishMeat` (`S`, `V`, `Y`; the template
uses `M`) and uses the short name throughout. Public names are always set on the table (`function F.carry`), never
as plain globals, so the Dev console, the tests and other files can reach them. The world file is the only other
global.

**Comments.** Every file opens with a line or two on what it is for. Every public function has a comment saying what
it does, and why when that isn't plain, unless its name and a one-line body say it all (`V.litres`). Exempt:
timed-action lifecycle methods (`isValid`, `start`, `perform`, ...) and Dev console commands. A comment says what
the code does now; history goes in the CHANGELOG, except for an old-save migration, which says what it migrates.

**Vanilla wraps.** A wrap saves the vanilla function in a local (`vanilla...`), replaces it, and calls the saved
one for anything that isn't the mod's. Its comment says why vanilla's isn't enough. After every B42 patch, check
each one below against the new vanilla Lua (`_pzdev`, ENGINE_NOTES); the copied add loop in `UI.slotRules` most
of all:

| Wrapped vanilla function | Where | Why |
|---|---|---|
| `ISWidgetCraftLogicOutputProgress.updateProgressItems` | core `UI.onProgressSlot` (Fish, Vinegar, Yeast, template through `progressTooltips`) | Weather-aware popups on running batches; Fish's salt badge |
| `ISCraftLogicPanel.ItemSlotAddItems` (add loop copied) | core `UI.slotRules` (Fish, Vinegar, Yeast, template) | Each station's own input rules |
| `ISItemSlot.defaultVerifyItem`, `ISItemSlot.onMouseUp` | core `UI.slotRules` | Slot border and refusal halo agree with the rules |
| `ISWidgetCraftLogicControl.startCraft` | core `UI.slotRules` with `recipeRefusal` (Fish & Meat) | Craft refuses stored inputs the selected recipe can't take |
| `ISMoveableSpriteProps.canPlaceMoveable` | core `UI.outdoorOnly` (Salt), `UI.notInRooms` (Fish) | Outdoor stations can't be carried indoors (or into a room) |
| `ISMoveableSpriteProps.canPlaceMoveable` | core `UI.keepDoorsFree` (Hearth, Firebox; Fish's beams and Smokehouse) | A station with a door (`Doors.register`) needs its front tile free, and none is put down in front of one's door; the build menu asks `TraditionalPreservationCore.doorFits` (`OnIsValid`) |
| `ISMoveableSpriteProps.canPlaceMoveable` | core `UI.offAppliances` (Dairy's crock) | Table-top stations refuse stoves, fridges, freezers, washers and dryers (vanilla lets an IsTableTop tile onto any IsTable square) |
| `ISAddItemInRecipe.complete`, `ISAddItemInRecipe.checkName` | Fish `...Evolved` | Single-icon stand-ins in a dish's ingredient list; stock pot names |
| `ISHandcraftAction.performRecipe` | core `Handcraft` only; handlers: Salt `...Shaker`, Vinegar `...Bottles` | Empty shakers and the right bottles come back |
| `ISCraftLogicPanel.createChildren` | Vinegar `...UI` | Fluid tank columns in the vessel's window |
| `ISWidgetCraftLogicInputControl.updateOutputItems` | Vinegar `...UI` | Hides the marker item in the vessel's output preview |
| `ISWidgetCraftLogicInputControl.createChildren` (wrapped on the first `UI.outputTooltips`) | core `UI.outputTooltips` (Fish & Meat) | The Output slot's popup lists every end of a recipe whose OnCreate swaps its output (the Hang recipes); remakes the output slots, which copy the panel's drawTooltip. Other recipes keep vanilla's |
| `ISWidgetCraftLogicControl.startCraft` | Vinegar `...UI` | Says why the vessel can't start, and stops a second run |
| `ISMoveableSpriteProps.canPickUpMoveable`, `.getInfoPanelFlagsPerTile` | core `UI.keepInPlace` (Vinegar, the Hearth) | A station holding liquid, a running batch or a hose can't be picked up, nor a Hearth that is lit, banked or holds fluid, and the cursor says why |
| `ISObjectClickHandler.doClickSpecificObject` (wrapped on `OnGameStart`) | core `InfoWindow.clickOpens` (Vinegar, Dairy, the Hearth) | Clicking a cask, a Hearth, an incubator or a crock opens its info window |
| `ISWidgetCraftLogicOutputProgress.createDynamicChildren`, `.calculateLayout` (wrapped on the first `StationInfo.add`) | core `StationInfo` (Fish & Meat) | A station's info block under Take All; the widget grows by its height. Other stations pass straight through |
| `ISWorldMenuElements.ContextEntity` | Vinegar `...UI` | Station icons in the right-click menu |
| `ISFluidTransferAction.start`, `stop`, `complete` | core `Pour` only; handlers: core `FluidAgeingWorld`, Dairy `World` | Poured fluid takes the source's age (older wins) and both ends are looked at as it ends, so names change at once (core); poured milk carries its heat record (`tpdCarry`) over, mixed by volume (Dairy) |
| `ISInventoryTransferAction.transferItem` | core `Transfer` only; handlers: core `FluidAgeingUI`, Dairy `UI`, Fish & Meat `UI`, Salt `BrineUI` | Looked at while still on the heat: hot milk scalds (core); milk off a stove or fire keeps a heat record (Dairy); a crock moved counts its time (Fish & Meat); a bucket of brine into the heat becomes the boiling item and back (Salt) |
| `ISToolTipInv.render` | Salt `BrineUI` | A bucket of brine and the boiling item show their strength and the salt they boil to (the item's Tooltip text for the one draw) |
| `ISMilkAnimal.milk` | core `FluidAgeingWorld` | A container whose milk is all gone forgets its age before new milk goes in |
| `ISEatFoodAction.complete`, `serverStop` | core `Portions` only; handlers: Dairy `...Yoghurt`, Fish & Meat `...Potted` | A Jar of Yogurt or a Crock of Potted Meat eaten from is relabelled with its portions and weight, and the last bite gives the empty jar, Clay Jar or Clay Pot back; a crock's first portion opens it |
| `ISCampingMenu.doLightFireOption` | core `HearthUI` | A banked Hearth's vanilla fire is out: Put out Fire (unbank) instead of Light Fire, in the right-click and controller menus |
| `ISLootWindowObjectControlHandler_LightFireOption.shouldBeVisible`, `ISLootWindowObjectControlHandler_PutOut.shouldBeVisible`, `.perform` | core `HearthLootControls` | The same in the loot window's buttons |
| `ISTakeGenerator.isValid` | FuelBarrel `ISFuelBarrelHose` | A generator with a barrel can't be picked up |
| `ISGeneratorInfoWindow.getRichText` | FuelBarrel `...Menu` | Barrel level in the generator's info |

Two mods wrapping the same function each call the one before, so load order doesn't matter. A new wrap goes in this
table. **When a second mod needs a vanilla function a first one wraps, the wrap moves to the core** and both add
handlers (`Transfer`, `Portions`, `Handcraft`, `Pour`): one place to compare with vanilla after a game update.

## Tile numbers: the generated Tiles.lua

Each mod's art builder (`tools/build_tileset.py`, Yeast's `tools/build_shelf_tileset.py`) is the one place tile
numbers live. Every run writes `42/media/lua/shared/<Mod>/Tiles.lua` (header: generated, don't edit), and the Lua
reads it: `local Tiles = require "<Mod>/Tiles"`. Every Tiles.lua has `SHEETS` (prefix and tile count of each
tileset), `STATIONS` (the sprite names of every workstation face, which the station tracker registers), and where they
apply `PREFIX`, `FACE_COUNT` and `OUTDOOR` (a set for `UI.outdoorOnly` or `UI.notInRooms`); the rest is the mod's own: station bases,
overlays, stages, styles, hangers.

1. To renumber or add tiles, change the builder's constants (and its `lua_tiles()` if a new name is needed) and
   rerun it. Never edit Tiles.lua.
2. Entity scripts stay hand written. `tests/test_tiles.lua` (`H.checkTiles`) fails if a script names a tile the
   builder didn't make, or a station sprite has no script.
3. The writer is `pzart.write_lua_tiles` in `TraditionalPreservationCore/tools/pzart.py`; builders import it from `TraditionalPreservationCore` (or
   `TPCORE`). Builders are deterministic: a rerun with no change gives byte-identical art.
4. `pzart.py` also holds everything two builders share: the pack and .tiles writers, sprite extraction, icons,
   layers, noise, weathering, staves and hoops. Change it only with a byte-identical check: rebuild every mod in a
   scratch copy before and after (FuelBarrel too) and compare every output file.

## Rules that keep saves and the game happy

- **Never rename a save key.** Ledger fields and object modData keys stay as they are, and old-save migrations stay in.
- **No literal `%` in translation text**, and no `%` followed by a letter in a value passed to `getText`. The game's
  formatter throws on both. Write "percent", or pass plain tokens and swap the values in with `gsub` (the `say`
  pattern).
- **Unique `tiledef` numbers.** mod.info is the record: `tp new` takes the next number above every mod.info in
  `~/MODS` and the installed mods, and `tp status` warns on a duplicate. A tileset holds at most 512 tiles.
- **Every workstation needs its own sprite**, or the world won't load. Style names can't contain `_`.
- **A station tracked from Lua must check it is really loaded.** `getSquare()` and `getObjectIndex()` aren't enough:
  an unloaded object passes both until its chunk has been saved. Compare `getCell():getGridSquare(x, y, z)` with its
  square (see ENGINE_NOTES, "Chunk unload and generators").
- `mod.info`: `author=alienPaco`.

## FAQ: why the series does it this way

For other modders reading the code. Each answer is the reason we chose it, not the only way it could be done.

**Why a weather ledger in global ModData, and not a timer on each object?**
A station's chunk is unloaded most of the time, and nothing on it runs then. The weather is the same for every
station, so one set of running totals (work done per place, recorded every 10 in-game minutes) is enough for all of
them. A station only keeps the totals it last saw; when it loads again, the difference is exactly the work it missed,
however long it was away. That costs one small table per mod, never grows with the number of stations, and needs no
catch-up simulation. The reading itself and the season's means are kept once, in TP Core's ModData, and copied into
each mod's ledger: a mod added to a save in July then agrees with the others about the cellar at once.

**Why six places (Open, Covered, Sheltered, Loft, Basement, Enclosed), and why a 240-hour season mean?**
They are what a survivor can actually choose, and each behaves the way a real cellar or shed does. Open goes by the
day's weather. A roof doesn't follow the hour: walls follow the season, so Covered (a roof, not a room) and Sheltered
(a room) are the mean of the last ten days or so, as an unheated house is; vanilla's own unpowered rooms start from
the outdoor temperature. While the grid is on a room is 22 C (`Weather.GRID_ROOM_C`, vanilla's figure; the ledger
copies `gridOn` from the series' weather). A basement swings two fifths as far as the ground from 10 C
(`basementTemperature`); the ground is the season mean's own 30-day mean (`GROUND_HOURS`, `groundTemperature` in the
series' weather and copied into each ledger by `Weather.season`), so a cellar is coldest in March and warmest in August.
Season tools start from `Weather.settledMeans` (the sampled year gone round twice), not a cold 1 January. Ten days is long enough that one warm afternoon in January does
nothing, and short enough that spring arrives within a fortnight. Until 2026-11 a room was the mean + 10 C (capped at
28) and a basement 15 C flat: a heated house, which most players don't keep (consistency sweep, step C).
A loft (sweep step H, 2026-11-12) is the basement's mirror: the top storey, a room at z >= 1 whose square above is in
no room (so a middle storey of a tall building and a bungalow's ground floor stay Sheltered). It reads the season's
mean plus `LOFT_LIFT` (0.3) of what the season is above `LOFT_ANCHOR` (10 C), the sun on the roof, and 22 C while the
grid is on. It came from the Stockfish Pallet, which had a loft of its own.
Enclosed (step J, 2026-11-12; the player's word *In a shed*) is a closed shed in the outside air: out of the rain and
wind, but a box of planks with no thermal mass, so it reads the day's temperature as Open does, and the grid doesn't
warm it. No square can tell it from a room, so `Weather.placeOf` never returns it: a station claims it in its World
entry. Only Fish & Meat's Smokehouse does (user, 2026-11-12); the Yeast, Vinegar and Dairy season reports show no
column for it.
**One place, one temperature (user, 2026-11-12):** a station or a stored item reads a place's temperature from
`Weather.placeTemperature` and nowhere else. If a process comes out wrong there, change the process's own numbers
(its curve, its hours), never the temperature it is given.
**Exceptions (user, 2026-11-12):** an exception to that rule must rest on **realism**, and must **keep every process's
path open** (no process shut out of the year by the place model; stockfish keeps its winter in the open and a longer
season under a roof). Write each one down here with its reason. The ones there are (Fish & Meat, sweep step I; the
Smokehouse's day's temperature was one until it became the Enclosed place, step J):
- **Dry curing is spared the muggy-season spoiling** that salt fish and charque take by their place: country hams
  were aged through the summer heat on purpose.
- **Salt fish's and charque's muggy spoiling reads the ten-day mean**, not the day's temperature, in the open air
  and in the Smokehouse (`F.saltSpoilPlace` returns "" for both; user, 2026-11-13): mould and rancid fat come of
  days of damp warmth, not of one hot afternoon. By the day's temperature July's muggy hours would go from 78 to
  about 220 and a stack hung all July would lose near half its keeping, where it loses a sixth.
- **Unsalted fish's warm rot is weighted by its wetness squared** (a process number, not a temperature: a dried skin
  protects the flesh), which keeps open-air stockfish possible from November to February while it reads the day's
  temperature as the open air must.
More places (north wall, near the stove) would ask the player to learn rules the game can't show them. Covered
and Sheltered read the same temperature but for a room's winter lift (`Weather.roomTemperature`: +2 C at a season of
10 C or below, none from 18; realism pass 1b) off the grid (a room is 22 C on it; a generator does not count, as in
vanilla); Fish & Meat tells them apart for its drying rates (moving air and shade).
By a fire and by banked embers are `Weather.FIRE_PLACES` that Hearth registers, indoors at a fixed 28 / 24 C, and
under an open roof or in the open (`HearthCovered`, `HearthOpen`, `EmbersCovered`, `EmbersOpen`) at that place's air
plus `Hearth.FIRE_LIFT` / `EMBERS_LIFT`, capped at the indoor heat (realism pass L1, user 2026-11-13). The ledger keeps
no totals for them, so `Hearth.catchUp` counts them by the clock until the fuel noted by `Hearth.noteFire` runs out, then gives the
place under the fire its share of the gap by time. A station's World calls `Hearth.notePlace`, which catches a run up
at its old place before writing the new one.

**Which kind of station? (the station rule, consistency sweep step F)**
Three kinds, by what the station holds:
- **Counted items in, items out, in batches that may overlap: a `CraftLogic` station** (Yeast's Shelf, Vinegar's
  Floor, Salt's Vat, Fish & Meat's Tub; `DryingCraftLogic` for a frame of stacks: the Frame, Beams, Gantry and
  Smokehouse). It gives slots, the vanilla window, Take All, a bar and each run's save and load. The timer is always
  set from Lua (`OnStart` / `OnUpdate`, below). It is read by **an info block in the crafting window**
  (`StationInfo.block`: place, temperature, working rate, a bar a batch) and a hover popup on each running batch.
- **A measured liquid, one continuous pool, or a state that depends on its own past: Lua state and right-click
  timed actions** (the Orleans Cask, the Hearth and Firebox, Dairy's Incubator and Crock). The engine can't be
  trusted with fluid amounts in a station (ENGINE_NOTES "Fluids"), a cask is one pool with no batch, and the
  incubator's milk cools from what it was. It is read by **an Info window on click** (`InfoWindow.clickOpens`) and
  its right-click line.
- **Storage that only changes how a finished item keeps or ripens: a container or the item's own clock**, no run at
  all (the Stockfish Pallet and Bale, the Crock of Potted Meat, maturing and ageing). It is read by the item's name
  and tooltip, and a right-click line where the place matters (the Pallet's speed).
Vinegar's Fermentation Vessel is the one hybrid: a `CraftLogic` run of a marker item while Lua moves the wort. A
new station picks its kind by this rule and is read the way its kind is.

**Why override the craft timers?**
The engine's craft timers tick at the speed of a 60-minute day whatever Day Length says, and stop while the area is
unloaded. So a recipe's `OnStart` notes where the run begins, and `OnUpdate` sets the elapsed time from the game clock
(plain timers) or from the work in the ledger (weather timers). The recipe's `time` is overwritten from the sandbox
options at load with `recipe:Load()`, so the window's Duration matches the real time.

**Why layer attached sprites instead of using SpriteOverlayConfig?**
SpriteOverlayConfig shows one overlay, for the first batch only. A shelf with five cultures or a frame with eight
stacks needs one sprite per batch, each at its own stage, and a station waiting to start or holding a finished batch
needs a look too. So the tracker reads the station and lays its own sprites with `addAttachedAnimSpriteByName`, only
redrawing when a signature of the state changes.

**Why custom popups and slot rules instead of vanilla's?**
Vanilla's progress popup goes by the recipe's time and its own temperature curve, so it shows the wrong time left
for a weather timer. Ours shows progress, real time left at today's rate, the temperature, the place and the rate.
Vanilla's slots take any item and only limit by free slots, so a wrong item leaves Craft greyed with no reason, and a
station that limits by weight or by stacks can't be expressed. Our slot rules check before the item goes in, and the
same check sets the slot's green border, so it never promises what adding then refuses. It is one core function,
`UI.slotRules`, whose add loop is a copy of vanilla's: compare that one copy with vanilla after a game update.
A rule that depends on the **selected recipe** goes in `recipeRefusal(slot, item)` (slot.recipe is the recipe's
short name, read from the station's `CraftLogic:getCurrentRecipe()`, which the window sets when a recipe is selected): the border turns red and a drop says
why, and because the recipe can change after loading, Craft refuses to start while a stored input fails it. Vanilla
alone would start the recipe on the inputs its OnTest passes and leave the rest in the slots, with Craft enabled.
Fish & Meat's tub uses it: Corn Salted Meat refuses a Leg of Pork.

**Why is the core one required mod instead of a copy in each mod?**
It began as a copy in each mod, so a player could subscribe to one with no dependency (PZ loads only one file per Lua
path, so each copy lived under its mod's own path). That changed on 2026-11-10: the series now shares *stations*,
not only code (the Hearth, a fire with a copper, is wanted by Dairy and later by cheese and others), and a station
needs one tileset, one save key and one set of timed actions. Two mods can't both ship it. One required mod also
means one copy of each fix, and one place for multiplayer's network code later. Its modules still return a local
table; the only globals are what the engine needs by name: `TraditionalPreservationCore.OnCreateHearth`
(the entity script), the `TPHearthCopper` and `TPHearthFire` timed actions, and `TPC`, the debug console. FuelBarrel is not a TP mod and does not require it.

**Why the extra check that a station is loaded?**
An unloaded object keeps its square and its index until its chunk has been saved and reused, so `getSquare()` and
`getObjectIndex()` both say it's fine. Writing to it then is lost, or worse, writes into a stale chunk. The cell stops
returning that square the moment the chunk unloads, so `getCell():getGridSquare(x, y, z) == square` is the real test.
FuelBarrel found this first; every tracker uses it through `Station.isLoaded`.

**Why no literal `%` in translations?**
The game's translator reads a finished line again as a format pattern. "40% soured" makes it throw, and so does a
line with `%1` given no values. So translations take plain tokens (`@1@`) through `UI.say`, and the values are swapped
in afterwards with `gsub`. `test_harness.lua` checks every mod's translations for a stray `%`.

**Why do saves never lose a key?**
Players keep saves for months. A renamed ledger field or modData key silently resets every running batch, so names
are fixed once and old-save migrations (Vinegar's `lastOpen/lastSheltered`, `vinegarMl`, Yeast's
`fermentStartHour`) stay in the code with a test each.

## Starting a new mod

Settle the design questions in `~/MODS/WIP/TPCore/SERIES.md` first, then:

```
tp new Dairy --station "Cheese Press"     # --short TPX to pick the console name
```

It renders `TraditionalPreservationCore/template/` into `~/MODS/TraditionalPreservationDairy`: one floor station (S and E faces, a
placeholder crate painted by `tools/build_tileset.py`), a placeholder item in and out, a weather-weighted timer on the
core, the popup, the Dev console (`TPD`, or the first free `TP` + letters), sandbox options, translations,
`test_process.lua`, `test_console.lua` and `test_tiles.lua`, a golden `tools/season_report.lua` (added to `golden/golden.json` and
recorded), README, DEVHELP, WORKSHOP, and a guide stub as the next number in `guides/`. It picks the tiledef, syncs
the core, builds the art, runs `git init` and the tests. Nothing is committed or installed.

The station name needs two or more words: the engine names a moveable by GroupName (all but the last word) and
CustomName (the last). Every placeholder is marked `TEMPLATE`; `grep -rn TEMPLATE <Mod>` lists what is left.
When a pattern in the mods changes, change the template too (it is not tested on its own: try `tp new` with
`TP_MODS` and `TP_INSTALLED` pointing at a scratch folder, then put `golden/golden.json` back).

## Guides and Workshop pages

- `tp package <Mod>` writes the folder to upload, `~/MODS/_package/<Mod>/Contents/mods/<Mod>` (`--out DIR` for
  another place): `42/`, `common/`, README, guide and CHANGELOG, and nothing a player has no use for (tests, tools,
  DEVHELP, WORKSHOP.txt). It runs the tests first, replaces only the mod's own folder (a `workshop.txt` and
  `preview.png` beside `Contents` stay), warns if the repo isn't a clean commit and names the mods to list as
  required items. Don't point `--out` at `~/Zomboid/Workshop` while the mod is also in `~/Zomboid/mods`: the game
  loads both.

- Edit player guides in `~/MODS/guides`, then run `tp guides`. It copies each guide into its mod and rebuilds the
  collection zip. It refuses if a copy inside a mod was edited more recently than the guide in `guides/`.
- Guides read like an old-school game manual: stat tables, margin notes, real-world notes, and a Tester's Toolkit
  appendix copied from the mod's `DEVHELP.md`. Change both together.
- Each mod keeps `README.md` (for developers), `WORKSHOP.txt` (Steam BBCode) and `DEVHELP.md` (debug console
  commands) in step with the guide.
