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
| `~/MODS/TraditionalPreservationCore` | Shared tooling: `tp`, the test harness, the golden results, this guide, the roadmap. |
| `~/MODS/guides` | The player guides. The copy inside each mod is made from these by `tp guides`. |
| `~/MODS/_pzdev` | Engine notes and `jdis.py` for reading the game's classes. |

## The everyday loop

1. Edit in `~/MODS/<Mod>`.
2. `tp test <Mod>`: the mod's tests, then its golden checks.
3. `tp install <Mod>`: runs the same checks again and copies the mod only if they all pass.
4. Restart the game (Lua or scripts changed) or reload to the main menu (translations only), then follow the in-game test steps.
5. Commit in the mod's repo.

`tp status` shows every mod at a glance: uncommitted changes, whether the installed copy matches, whether the guide copy matches.

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

`luajit tests/test_harness.lua`, run from `TraditionalPreservationCore` (or `tp test` with no mod), tests the harness itself, and checks
every mod's translation files for a literal `%`.

## The shared core

`~/MODS/TraditionalPreservationCore` is itself a mod, **TP Core** (id `TraditionalPreservationCore`), that every TP
mod requires (decided 2026-11-10, before the first Workshop release). Its Lua is
`42/media/lua/shared/TraditionalPreservationCore/Weather.lua`, `.../Station.lua` and
`42/media/lua/client/TraditionalPreservationCore/UI.lua`. A mod that uses it says so in its mod.info:

```
require=\TraditionalPreservationCore
loadModAfter=\TraditionalPreservationCore
```

```lua
local Weather = require "TraditionalPreservationCore/Weather"
```

1. Edit the core only here, and run `tp test Core` (or `luajit tests/test_core.lua` from this folder).
2. `tp install Core` ships only its `42/` folder; the rest of this folder is tooling and private notes.
3. **Moving over, one mod per session:** Dairy and new mods (`tp new`) require TP Core. Salt, Fish, Yeast and Vinegar
   still carry their own copy under `<Mod>/Core/`, kept identical by `tp sync` (each copy starts with a "Copied from
   ... Edit it there" line; sync refuses to overwrite a copy edited by hand, `--force` overrides). `tp test <Mod>` and
   `tp install <Mod>` fail while a copy is out of date. To move a mod over: delete its `Core/` folders, change
   `"<Mod>/Core/X"` to `"TraditionalPreservationCore/X"`, add the two mod.info lines, `tp install <Mod> --force`
   (the installed copy still has the old files).
4. **Modules only the required mod has:** `Hearth` (the Hearth and its copper, save key `tpHearth`, the opt-in "by
   a fire" place, hooks), its `Tiles`, the server's `HearthWorld`, and the client's `HearthUI` and `InfoWindow` are
   never copied by `tp sync` (`REQUIRED_ONLY` in `tp`): they own a tileset, a save key, a World and menus, which two
   mods can't both ship. A mod that wants them requires TP Core. Core's art: `tools/build_tileset.py` (tiledef 5173).
5. **Info windows:** derive `TraditionalPreservationCore/InfoWindow` (rows, bars, notes, closes out of reach, one
   window at a time across every mod); see its header and Dairy's Incubator Info.

Core modules return a local table and never set a global, and never require each other.

## How a mod is laid out in code

Every TP mod splits the same way (`tp new` makes this layout), under `42/media/lua/`:

| File | Side | What it holds |
|---|---|---|
| `shared/<Mod>.lua` | both | The public table (`TraditionalPreservationFish`, ...): constants, sandbox, rate curves, ledger, recipe hooks (`OnStart`/`OnUpdate`/`OnTest`/`OnCreate` named by the scripts). No UI, no tracking. |
| `shared/<Mod>/Tiles.lua` | both | Generated by the builder. Never edit. |
| `shared/<Mod>/Core/` | both, client | Only in mods not yet moved onto TP Core: the synced core. Never edit here. |
| `shared/TimedActions/IS*.lua` | both | The mod's own timed actions. |
| `server/<Mod>World.lua` | server | The station tracker (`Station.tracker`), sprites and overlays, the weather recorder. Public as `<Mod>World` (`track`, `refresh`) so the UI can start tracking a station built this session. Yeast calls it `...Shelf`. |
| `client/<Mod>UI.lua` | client | Popups, slot rules, context menus, and the mod's own vanilla wraps. Salt's is `...Menu`, Yeast's `...ShelfUI`. |
| `client/<Mod>Dev.lua` | client | The Dev console (`TPF`, `TPS`, `TPV`, `TPY`), documented by its `help()` and DEVHELP. Vinegar also has `...Debug.lua`, debug-mode only. |

Extra shared files hold a separate piece of the game that stands on its own: Fish's `...Evolved` (stock pots), Salt's
`...Shaker`, Vinegar's `...Bottles`.

**The local alias.** Each file starts with `local F = TraditionalPreservationFish` (`S`, `V`, `Y`; the template
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
| `ISMoveableSpriteProps.canPlaceMoveable` | core `UI.outdoorOnly` (Fish, Salt) | Outdoor stations can't be carried indoors |
| `ISAddItemInRecipe.complete`, `ISAddItemInRecipe.checkName` | Fish `...Evolved` | Single-icon stand-ins in a dish's ingredient list; stock pot names |
| `ISHandcraftAction.performRecipe` | Salt `...Shaker`, Vinegar `...Bottles` | Empty shakers and the right bottles come back |
| `ISCraftLogicPanel.createChildren` | Vinegar `...UI` | Fluid tank columns in the vessel's window |
| `ISWidgetCraftLogicInputControl.updateOutputItems` | Vinegar `...UI` | Hides the marker item in the vessel's output preview |
| `ISWidgetCraftLogicControl.startCraft` | Vinegar `...UI` | Says why the vessel can't start, and stops a second run |
| `ISMoveableSpriteProps.canPickUpMoveable`, `.getInfoPanelFlagsPerTile` | Vinegar `...UI` | A station holding liquid, a running batch or a hose can't be picked up, and the cursor says why |
| `ISObjectClickHandler.doClickSpecificObject` (wrapped on `OnGameStart`) | Vinegar `...UI` | Clicking the cask opens Cask Info |
| `ISWorldMenuElements.ContextEntity` | Vinegar `...UI` | Station icons in the right-click menu |
| `ISTakeGenerator.isValid` | FuelBarrel `ISFuelBarrelHose` | A generator with a barrel can't be picked up |
| `ISGeneratorInfoWindow.getRichText` | FuelBarrel `...Menu` | Barrel level in the generator's info |

Two mods wrapping the same function each call the one before, so load order doesn't matter. A new wrap goes in this
table.

## Tile numbers: the generated Tiles.lua

Each mod's art builder (`tools/build_tileset.py`, Yeast's `tools/build_shelf_tileset.py`) is the one place tile
numbers live. Every run writes `42/media/lua/shared/<Mod>/Tiles.lua` (header: generated, don't edit), and the Lua
reads it: `local Tiles = require "<Mod>/Tiles"`. Every Tiles.lua has `SHEETS` (prefix and tile count of each
tileset), `STATIONS` (the sprite names of every workstation face, which the station tracker registers), and where they
apply `PREFIX`, `FACE_COUNT` and `OUTDOOR` (a set for `UI.outdoorOnly`); the rest is the mod's own: station bases,
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
catch-up simulation.

**Why three places (Open, Sheltered, Basement), and why a 240-hour season mean?**
They are what a survivor can actually choose, and each behaves the way a real cellar or shed does. Open goes by the
day's weather. A roof doesn't follow the hour: thick walls follow the season, so Sheltered is the mean of the last ten
days or so plus 10 C, capped at 28 C. A basement is near the year's average all year, so 15 C. Ten days is long
enough that one warm afternoon in January does nothing, and short enough that spring arrives within a fortnight.
More places (north wall, attic, near the stove) would ask the player to learn rules the game can't show them.

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

**Why is the core one required mod instead of a copy in each mod?**
It began as a copy in each mod, so a player could subscribe to one with no dependency (PZ loads only one file per Lua
path, so each copy lived under its mod's own path). That changed on 2026-11-10: the series now shares *stations*,
not only code (the Hearth, a fire with a copper, is wanted by Dairy and later by cheese and others), and a station
needs one tileset, one save key and one set of timed actions. Two mods can't both ship it. One required mod also
means one copy of each fix, and one place for multiplayer's network code later. Its modules still return a local
table; the only globals are what the engine needs by name: `TraditionalPreservationCore.OnCreateHearth`
(the entity script) and the `ISHearthCopper` timed action. FuelBarrel is not a TP mod and does not require it.

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
`test_process.lua` and `test_tiles.lua`, a golden `tools/season_report.lua` (added to `golden/golden.json` and
recorded), README, DEVHELP, WORKSHOP, and a guide stub as the next number in `guides/`. It picks the tiledef, syncs
the core, builds the art, runs `git init` and the tests. Nothing is committed or installed.

The station name needs two or more words: the engine names a moveable by GroupName (all but the last word) and
CustomName (the last). Every placeholder is marked `TEMPLATE`; `grep -rn TEMPLATE <Mod>` lists what is left.
When a pattern in the mods changes, change the template too (it is not tested on its own: try `tp new` with
`TP_MODS` and `TP_INSTALLED` pointing at a scratch folder, then put `golden/golden.json` back).

## Guides and Workshop pages

- Edit player guides in `~/MODS/guides`, then run `tp guides`. It copies each guide into its mod and rebuilds the
  collection zip. It refuses if a copy inside a mod was edited more recently than the guide in `guides/`.
- Guides read like an old-school game manual: stat tables, margin notes, real-world notes, and a Tester's Toolkit
  appendix copied from the mod's `DEVHELP.md`. Change both together.
- Each mod keeps `README.md` (for developers), `WORKSHOP.txt` (Steam BBCode) and `DEVHELP.md` (debug console
  commands) in step with the guide.
