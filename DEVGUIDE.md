# Traditional Preservation: development guide

How to work on the TP mods (Salt, Fish, Yeast, Vinegar, and every new one) and on FuelBarrel. What each mod does is
in its own README. For the engine's side, read the Umbrella stubs (the classes' signatures) and a decompile of the
game's jar (their bodies); a fact the code relies on is noted where it is used.

The examples run `tp`, the script at the top of this folder (`TraditionalPreservationCore/tp`, Python 3; tests need
`luajit`). It expects the mod repos side by side in one folder: `TP_MODS` names it (default `~/MODS`), and
`TP_INSTALLED` the game's mod folder (default `~/Zomboid/mods`).

## Where things live

| Path | What it is |
|---|---|
| `<TP_MODS>/<Mod>` | The source. Each mod is its own git repo. Edit here. |
| `~/Zomboid/mods/<Mod>` | The installed copy the game loads. Only `tp install` writes here. |
| `<TP_MODS>/TraditionalPreservationCore` | TP Core, the mod itself (`42/`, `README.md`, `DEVHELP.md`, `WORKSHOP.txt`, its player guide `6_Core_Guide.md`), and the shared tooling: `tp`, the test harness, the golden results, this guide. |
| `<TP_MODS>/guides` | The player guides' source (not in any mod's repo). The copy inside each mod is made from these by `tp guides`. |

## The everyday loop

1. Edit in `<TP_MODS>/<Mod>`.
2. `tp test <Mod>`: the mod's tests, then its golden checks. Before the tests it lints the shipped files: Lua calling
   what Kahlua lacks, translation JSON the game would refuse (not valid, or a key given twice), and translation keys
   written whole in Lua that no EN file has (the mod's, TP Core's or the game's; a key finished with `..` isn't
   checked). The game's files are found under `TP_GAME` (default the Steam install); without them keys are skipped.
   It also fails on a vanilla function replaced in place instead of through `Wrap`, and on a function two places in
   the series wrap.
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
copy. Bring the edit into `<TP_MODS>/<Mod>` first, or pass `--force` to overwrite. Mods must be real copies, never
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
| `H.useModPaths()` | `require` finds the mod's own Lua and TP Core's as the game does, e.g. `require "TraditionalPreservationCore/Weather"`. Also runs `H.preloadVanilla()`. |
| `TPCoreTesting` | Set by the harness: `Wrap` puts a wrap in at once instead of waiting for the game to start, so a test stubs the vanilla function before requiring the file that wraps it. A stand-in missing a function the code wraps is skipped, as in game; give the stand-in the method. |
| `H.preloadVanilla()` | The vanilla files TP code `require`s before wrapping them (`H.VANILLA`) load as nothing, so the action's global stays the test's stub, or nil and the wrap is skipped. A new plain `require` of a vanilla file goes in `H.VANILLA`. |
| `H.installGetText()` | `getText` with the mod's real EN translations. Notes the game formatter's `%` errors in `H.textWarnings`. |
| `H.player{ x, y, z, outside }` | A player for a console or a menu: a square, an inventory, and the full types it was given in `.given`. |
| `H.checkConsole(path, name)` | Loads a Dev console as debug mode does: it stays out of a normal game, and `help()` lists every command it has and none it hasn't. Returns the console and `run("command", ...)`, which gives back what the command printed. |
| `H.installMenus()` | What a right-click menu file touches: vanilla's classes, the inventory in reach, the action queue, the pick-up check. Returns the record (`.carried` to set; `.queued`, `.moved`, `.probes`, `.walks` to read). |
| `H.menu()`, `H.vessel(name, fluid, litres, capacity)`, `H.class(name)` | A context menu that keeps its options and submenus, an item with a fluid container, a vanilla class to derive from. |

**How things are named** (display text only, ids and save keys never follow):

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

**How code is named** (variables, parameters, functions, table fields, modData and ledger keys, console commands):

1. A name says what the thing is in game: `station`, `fire`, `cauldron`, `jar`, `fish`. Words that need a comment
   to decode are out: `object`, `entry`, `data`, `record`, `info`, `spec`, `thing`, `value`, `t`, `result`.
2. The most specific name every caller shares: a Core function that takes any mod's station says `station`, a
   Yeast-only one `shelf`.
3. One word, one meaning across the series. The words below mean that and nothing else.
4. A name tells saved from not saved: what goes in modData or a ledger says it is kept; what lives only while the
   game runs says so too (`sessionState`).
5. Vanilla's names stay as vanilla spells them: `modData`, `craftData`, `uiLogic` (a `CraftLogicUILogic`),
   `playerObj`, the Java getters.
6. Short names only where Lua expects them: `i`, `j` for indexes, `_` for a value not used.
7. A rename is a refactor (see Refactoring rules): same tests and golden results, a version bump, renamed by
   meaning and never by search-and-replace.

The example: `Station.uiLogic(station, sessionState, logic)` gives the station's `CraftLogicUILogic` (the name
says what comes back, in vanilla's word), kept in the station's session state.

| Word | Means |
|---|---|
| `station` | Any mod's placed object the series tracks: a vessel, a shelf, a tub, a fire. |
| `sessionState` | The table a station tracker keeps for one station while it is loaded: sprites drawn, hanger, heat and light, the cached `uiLogic`. Never saved. |
| `logic` | The station's `CraftLogic` component. |

**The console convention** (every TP mod, and the template):

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
Tester's Toolkit (edit the guides' source, then `tp guides`).

Every mod has a `tests/test_console.lua`: it calls each console command its stand-ins can carry, so a command can't
break unseen (Yeast's `TPY.here()` did). Add a line there with each new command. A file with a right-click menu
gets a menu test on `H.installMenus` (`TraditionalPreservationCore/tests/test_fire_menu.lua`, Dairy's
`tests/test_menu.lua`): build the menu on stand-in stations and read the options, their hovers and what choosing
one queues.

`luajit tests/test_harness.lua`, run from `TraditionalPreservationCore` (or `tp test` with no mod), tests the harness itself, and checks
every mod's translation files for a literal `%`.

## The shared core

This folder is itself a mod, **TP Core** (id `TraditionalPreservationCore`), that every TP mod requires. Its Lua is
`42/media/lua/shared/TraditionalPreservationCore/Weather.lua` (places, temperatures, the season's means, ledgers; the one name callers use, passing on the next), `.../CraftClock.lua` (a craft recipe's bar and clock: `startRun`, `showProgress`, `setRecipeHours`, `recipeHours`, `startClock`, `showClock`, `batchStatus`), `.../Station.lua`, `.../Container.lua` (a bucket
that comes back as the bucket it was), `.../Recipes.lua` (craft recipes: more fluids for a vanilla recipe's fluid
line, or more items for a mod's item line, at `OnInitWorld`; the OnCreate helpers; teaching from a magazine and by research), `.../ItemFluid.lua` (fluid that turns, goes off, burns or stays in a pot or saucepan: the cauldron's rules for an item; `ItemFluidUI.addPieces` puts pieces in as a fluid), `.../OnHeat.lua` (food kept
hot after it was made), `.../Season.lua` (seasoning a food afterwards), `.../FluidAgeing.lua` (fluids that go off), `.../PlaceKeeping.lua` (food that keeps by place), `.../DryingCloth.lua` (the Drying Cloth: lots of what mods register, drying by place), `.../FluidTreat.lua` (treating them by hand), `.../Fire.lua` (any fire the mods bank and stoke: kinds, banking, fuel, attachments; passes on the next two), `.../FireConnect.lua` (connections), `.../Fireside.lua` (by a fire as a place, and the work done there), `.../StoneHearth.lua` (the Stone Hearth, the first kind of fire: its tiles, hole, door, `StoneHearth.cooksOn`, the build), `.../Cauldron.lua` (the Forged Cauldron, the first attachment: `Cauldron.ID`, `Cauldron.ITEM`, `Cauldron.state`, `Cauldron.of`), `.../CauldronFluid.lua` (what the cauldron holds: heating, boiling, blends, the pour hooks; called by its own name), `.../Smokehouse.lua` (the
Smokehouse every mod smokes in; the one name callers use, passing on
`.../SmokehouseStacks.lua`, a stack's fire counters),
`.../Action.lua`, `.../Appliances.lua` (stoves, fridges and washers, and the table-top build check), `.../Log.lua`, `.../Wrap.lua` (every wrap of a vanilla function: late, guarded, one each), `.../Portions.lua` (food eaten from a vessel by the portion, and the one wrap of
vanilla's eat action), `.../Handcraft.lua` (the one wrap of `ISHandcraftAction.performRecipe`), `.../Pour.lua` (the one
wrap of `ISFluidTransferAction`), `.../Drink.lua` (fluids that ease food sickness, the one wrap of
`ISDrinkFluidAction.updateEat`) and `.../Cooldown.lua` (cooldowns kept on a player), with `42/media/lua/client/TraditionalPreservationCore/UI.lua` (text, menus and window popups; the one name callers use, passing on `SlotRules.lua`, a station's input rules, and `Placement.lua`, where stations may be put down or picked up), `InfoWindow.lua` (with `PieceList.lua`, its scrolling list), `StationInfo.lua`,
`FireUI.lua`, `CauldronUI.lua`, `SmokehouseUI.lua`, `FluidAgeingUI.lua`, `FluidTreatUI.lua` (the treat menu),
`SeasonUI.lua`, `PlaceKeepingUI.lua` (looks at kept food), `DryingClothUI.lua` (the cloth's menu and Cloth Info) and `Transfer.lua` (the one wrap of vanilla's `transferItem`: a mod that needs to
see items moved adds `Transfer.before` or `Transfer.after` instead of wrapping it again), and the server's `FireWorld.lua`, `SmokehouseWorld.lua`, `FluidAgeingWorld.lua`, `DryingClothWorld.lua` and `Loot.lua` (a mod's item into vanilla's loot lists). A mod that uses it says so in its mod.info:

```
require=\TraditionalPreservationCore
loadModAfter=\TraditionalPreservationCore
```

```lua
local Weather = require "TraditionalPreservationCore/Weather"
```

1. Edit the core only here, and run `tp test Core` (or `luajit tests/test_core.lua` from this folder).
2. `tp install Core` ships only its `42/` folder; the rest of this folder is tooling.
3. **Every TP mod requires TP Core**, and none carries a copy of it. `tp sync` copies the core under `<Mod>/Core/` for
   a mod that wants its own copy, and refuses a mod whose mod.info requires TP Core. FuelBarrel isn't TP and doesn't require it (its tests and builder only
   borrow the core's harness and `pzart`). A test with its own `require` stub (e.g. `name:find("^TraditionalPreservation<Mod>/")`)
   must also let `^TraditionalPreservationCore/` through, or use `H.useModPaths()`.
4. **Modules only the required mod has:** `Fire` (the Stone Hearth and its cauldron, save key `tpFire`, the opt-in "by
   a fire" place, hooks) and `Cauldron`, its `Tiles`, the server's `FireWorld`, and the client's `FireUI`, `CauldronUI`, `InfoWindow` and `PieceList` are
   never copied by `tp sync` (`REQUIRED_ONLY` in `tp`): they own a tileset, a save key, a World and menus, which two
   mods can't both ship; the Smokehouse's four files too. A mod that wants them requires TP Core. Core's art: `tools/build_tileset.py` (tiledef 5173), the Smokehouse's four tiles and overlays in `tools/smokehouse_tiles.py`.
5. **Info windows:** derive `TraditionalPreservationCore/InfoWindow` (rows, bars, notes, closes out of reach, one
   window at a time across every mod); see its header and Dairy's Incubator Info. `InfoWindow.clickOpens(test, open)`
   makes a click on the station open it. A station holding many pieces lists them with `self:pieceList(y, label,
   rows)` (`PieceList.lua`): a scrolling list under a header with a sort switch (furthest along first, least
   along first, or by process: rows grouped by their `group`, which every row has), one row a piece (icon, name, a bar and its text, a line under it if given) and the row's popup on
   hover, drawn as a crafting slot's (`UI.drawTooltip`). The window builds a new rows table in refresh; the list
   sorts it again only then. `TPC.pieceList(n)` opens a sample.
   **Info inside vanilla's crafting window:** `TraditionalPreservationCore/StationInfo`, `StationInfo.add(provider)`:
   `provider(entity)` returns `{ rows, bars, notes }` for the mod's station and nil for anything else, and the block
   shows under In Progress, Done and Take All (Fish & Meat's `...Info.lua`). For a station with a vanilla window; a
   station without one keeps an InfoWindow. Both draw with InfoWindow's `drawRow`, `drawBar` and `drawNoteLines`
   (one look, one set of colours: `InfoWindow.LABEL_COLOUR` and the rest); running batches are listed furthest along
   first, ties by recipe name then count (`StationInfo.batchBefore`).
6. **What the core already does, so a mod doesn't write it again:**
   - Menus (`UI`): `findItems`, `tooltip`, `disable`, `litres`, `degrees`, `hoursText`, `durationText` (hours up to two days, then "about N days"), `fluidName`, and
     `keepInPlace(test)` for a station that mustn't be picked up while it holds something (every station that keeps its state in movableData uses it, so nothing is carried mid-process; vanilla already refuses a station whose slots or container hold items) (test returns true for vanilla's *Has items* line, or an `InfoPanelFlags` name such as `"tooHot"`).
   - Stations (`Station`): `kinds(prefix, faces, bases)` tells a mod's stations by one lookup on the sprite's name
     (never cut the name apart), and the tracker's `scan = true` finds one built or put down this session at once.
   - Weather: `Weather.sensitivity(option)` for the sandbox's Temperature Sensitivity, and `Weather.rate(curve,
     celsius, sensitivity, minRate, freezeC)` for a stage's speed (0 frozen, else the curve after the sensitivity,
     never under minRate). The reading and the season's means are kept once for the series (`Weather.weatherModData()`, in the
     core's ModData); every mod's ledger copies them at each `Weather.onReading`, so never grow a season mean of your
     own (`Weather.seasonTemperature`, `Weather.seasonHumidity`). A ledger process that `Weather.advance` can total
     (one rate a place) goes through it, never a copy of its loop. `Weather.DEFAULT_PLACE` is where something
     stands when nothing says (a room).
   - Timed actions (`Action`): `duration(character, ticks)` honours the instant-actions cheat, `pourDuration` is the
     series' one pouring speed. Every `getDuration` goes through one of them.
   - `Container.fluidIn(fluidContainer)`: the one fluid a container holds, or nil for none or a mixture.
   - `CauldronFluid.taints(tainting, tainted)`: `tainting` taints `tainted`; poured in together, either way round, the lot
     becomes `tainting` (Core names vanilla's `TaintedWater` and `Water`). `CauldronFluid.taintedBy(cauldron, fluid)` says what a pour
     would make; `CauldronFluid.partsIn` reads a container holding both as all `tainting`. Each fluid in one taint only.
   - `CauldronFluid.blend("A", "B")`: fluids that may share the cauldron. `CauldronFluid.partsIn(fluidContainer)` is then what a
     container holds by fluid (one fluid or such a blend, nil for any other mixture); a store's own blend is `fluid`
     (the largest share) plus `parts`, kept with `CauldronFluid.addParts` and read with `CauldronFluid.partsOf`.
   - `CauldronFluid.turnsHot(from, to, hours)`, `CauldronFluid.goesOff(from, to)` + `CauldronFluid.offBy(cauldron, hour)` and
     `CauldronFluid.staysIn(name)`: a fluid the cauldron changes when kept steaming, one that goes off at an hour, and one
     that can't be filled out (Fish & Meat's raw fat is all three). `CauldronUI.addMenu(fn)` and `CauldronUI.addNotes(fn)`
     put a mod's rows on the Stone Hearth (Cauldron)'s menu and its lines in Stone Hearth Info (`fireView.part` is the
     cauldron's modData; `FireUI.notes(fireView)` builds every Info note, so a test can read them).
   - **Attachments** (`Fire.attach{ id, name, fit, canRemove, look, sprite, overlay, heats, onFire, display, status, menu, rows, notes }`):
     what is fitted on a fire, one at a time; the Forged Cauldron (`Cauldron.lua`, `CauldronUI.lua`,
     its simmer in `FireWorld`) is the first, written against the registry alone. Calling `attach` again with the
     same id adds fields, so rules go in shared Lua and the menu in client Lua. Its modData is its own table under its
     id in `tpFire` (`Fire.partModData(modData, id)`; the cauldron's is `Cauldron.cauldronModData(modData)`, and
     `Cauldron.of(fire)` brings it up to now). `Fire.attachmentOf(fire)` gives the attachment and its modData;
     `Fire.canRemove(fire)` refuses while the fire burns, then asks the attachment (the cauldron: only empty);
     its `removeText` gives Remove's hover for its own reasons.
     `Fire.fireModDataNow(fire)` is the fire's own modData brought up to now. Each field's arguments are in
     `Fire.lua` above `Fire.attach`; `attach` and `connect` share `Fire.registry`, which refuses one without an
     id and a field given again as something else. Fit / Remove are Core's (`TPFireFit`, by the attachment's `fit`).
   - **Connections** (`Fire.connect{ id, kitNames, kits, blocks, finds, joined, refusal, onChange, connectText,
     disconnectText, disconnectHelp, icon, notes, smoke }`): what is built onto a fire in
     its second slot, one at a time; the Smokehouse's flue is the first (`Smokehouse.ID`, in `Smokehouse.lua`, its notes
     in `SmokehouseUI`). Its modData is `connected` (the id) and `{ kitName, side }` under the id in `tpFire`
     (`Fire.join(fireModData, id, kitName, side)`, `Fire.unjoin(fireModData)`, `Fire.connectedTo(fireModData)`,
     `Fire.joinOf(fireModData)`,
     `Fire.connectionOf(fire)`). `blocks` is `"connection"` (the default) or `"both"`: then Fit is refused while it
     is joined and Connect while something is fitted. Each kit is `{ tool, items, back, ticks, removeTicks, xp, anim,
     text, help, name, toolText }`: Connect uses its items, Disconnect gives back the `back` items, the tool is kept.
     Core enforces one connection a fire, never the door's side, never while the fire burns (`Fire.connectRefusal`,
     after the connection's own `refusal`), builds it with the timed action `TPFireConnect` and puts Connect /
     Disconnect on the fire's menu (`FireUI.addConnect`, `FireUI.addDisconnect`, which the joined thing's own
     menu may call too). A joined fire can't be picked up. **A connection owns its sprites:** it draws itself on its own
     object (the Smokehouse's entry overlay draws the whole flue, `Smokehouse.entrySprite`; `onChange` redraws it),
     never on the stone, which has no flue tiles. `smoke = true` (the Smokehouse's) says it takes the fire's smoke: the
     bare Stone Hearth's hole is lidded and its glow goes up the flue.
   - **Kinds of fire** (`Fire.kind{ id, is, face, sprites, showing, fittedByTile, display, refusals, fireboxCapacity }`): a vanilla fireplace by
     its tiles that Fire banks, stokes and keeps attachments and connections on; the Stone Hearth (`StoneHearth.lua`)
     is the first, and Fire names no stone. `Fire.isFire(object)` is any kind, `Fire.kindOf(object)` which,
     `Fire.faceOf(fire)` its facing, `Fire.sprites()` every kind's tiles (FireWorld's tracker; it requires
     `StoneHearth` first). A kind's `display` is how it shows bare (icon, title, Info row, Bank / Stoke icons) with
     `help = { out, lit, banked }`, its Info's first note; `refusals = { joined, door }` are Connect's refusals in its
     words. `fireboxCapacity` (optional) is its fire box's capacity: the game saves a container's capacity with the object,
     so FireWorld raises a fire built with less (the Stone Hearth's is 15, `StoneHearth.FIREBOX_CAPACITY`: a full bucket of
     brine, 11, but not two). `Fire.kind` refuses a kind missing any of these but `fittedByTile` and `fireboxCapacity` before keeping it. FireUI is the
     kind-free menu and Info window (`FireWindow`), with `FireUI.addMenu(fn)` and `FireUI.addNotes(fn)` for rows and
     notes on any fire.
     `StoneHearth.isStoneHearth` is the stone alone (the Smokehouse's chamber looks for it).
   - A bare fire (`Fire.isBare`, "bare" in the code; `Fire.isFitted(fire, id)` is one with that attachment fitted,
     any with no id; `Fire.fittedNear(square, id)` those near). A fitted one shows as its attachment's `display` says
     (icon, title, Info row, Bank / Stoke icons; its kind's if left out), a bare one as its kind's: the same fire with
     nothing fitted, in the same state table (`tpFire`). An attachment draws itself on the fire with its `sprite`
     and optional `overlay` (the cauldron's: `StoneHearth.cauldronSprite`, `StoneHearth.liquidOverlay`). Its tiles are whole-hearth tiles, the stone with it fitted;
     a mod's live in its own tileset and become Stone Hearth tiles with `StoneHearth.fittedTiles(id, sprites, faces)` in
     shared Lua (tracked, facing and door known, and shown fitted when put down with nothing noted; the cauldron's go
     the same way). `Fire.flueSideTo(fire, square)` is the side a square is on (nil for the
     door's side or not beside it), `Fire.flueSquare(fire, side)` the square on a side; `FireConnect.FLUE_SIDES`
     matches the tile builder's.
   - `FluidAgeing.register{ process, rate, turnHours, spoilHours, fresh, spoiled, states, scaldHeat, sealed, ... }`: a
     kind of fluid that goes off (Dairy's milk). The core keeps the fluid's age (`fluidAge`, saved as `tpFluidAge`) on whatever holds
     it, swaps the fluid when it turns and spoils, and hands the age on through pours and the cauldron. `states` are
     variants of the fresh fluid that never turn (Fish & Meat's Cured blood, done by hand; Dairy's Scalded milk,
     `heat = true`, made by `scaldHeat` and `scaldHold`). One state at a time: heat leaves a fluid in a state as it
     is, a treatment by hand replaces the heat state. `FluidAgeing.inState(fluidAge, name)` asks.
   - `Recipes.addFluids(recipe, extra, tag)`: more fluids for a vanilla recipe's fluid line.
     `Recipes.addItems(recipe, extra, tag)`: more items for a plain item line, so a mod's recipe takes another mod's
     item only when that mod is on (check the item with `getScriptManager():FindItem` first). A script never names
     another mod's item: Fish & Meat's Potted Meat takes Dairy's Clarified Butter this way.
     `Recipes.teach(magazineType, recipeName, tag)` and `Recipes.researchable(itemType, recipeName, tag)`: a mod's
     recipe from a vanilla magazine and by research; each says *Could not find* in the console when a name is wrong.
   - The Smokehouse (`Smokehouse`): a mod's smoking recipes carry the tag `Smokehouse`; a stack's OnStart calls
     `Smokehouse.startCounters(modData, owner, hotSmokeHoursNeeded)`, and the mod's World tracks `Tiles.CHAMBERS` and steps only
     the stacks it owns (`Smokehouse.owns`) with `Smokehouse.fireStep(modData, Smokehouse.fireOf(tile), coolShare)`.
     Its `UI.slotRules` passes `owns(entity, item)`, so in the shared shed it judges only its own items. Core's README
     ("The Smokehouse") has the details; Fish & Meat is the worked example.
   - `Station.near(square, radius, test)` and `Station.nearAt(x, y, z, radius, test)`: what stands round a square,
     nearest first. Never write the double loop over squares again (`Fire.near` is it at the fire's reach).
     `Station.squareAt(square, dx, dy)`: the square beside one, on its level. `Station.eachPlayer(fn)`: every player
     here. `Station.onHeatNear(heat, fn)`: `fn(container, now, object)` each game minute for every container at `heat` or
     hotter within `Station.HEAT_NEAR` (8) of a player, one look shared by every caller (`heat` a number, or a
     function giving one or nil). FluidAgeing's scalding, OnHeat and Dairy's wrap burning use it; never add a second minute look.
   - `UI.selectedItems(items, wanted)` and `UI.firstSelected(items, wanted)`: an inventory context menu's selected
     items, each once (a collapsed stack lists its first item twice), or the first wanted one, a stack by its first
     item. `UI.disable(option, text)` greys an option with its reason; **`UI.refuse(option, text)`** shows a submenu
     row in red with its reason (`notAvailable`), still there to read.
   - `Action`: a timed action's time (`duration`, `pourDuration`) and a kit's parts: `hasTool(character, tag)`,
     `kitItems(character, needs)` (the items, all from the main inventory, or nil), `takeItems`, `giveItems(character,
     needs)`, `addXp(character, { perk, amount })`. Fit and Connect at the Stone Hearth use them.
     **`Action.startClock(action)`** in an action's start and **`Action.clockProgress(action, item, minutes)`** in its
     update run it on the game clock (getDuration -1): the item's job bar follows, done at the minutes (Salt's Dig, Fill).
     **`Action.removeItem(item)`** takes an item out of whatever holds it (a bag too); **`Action.replaceItem(old, new)`** puts new where old is, in a container or on the ground. `Fire.redraw(fire)`
     redraws a Stone Hearth after an action changed it (nothing where the World doesn't run).
   - `Fire.catchUpRun(modData, ledger, kind, place, rateAt)` and `Fire.updateRun(craftRecipeData, ledger, kind,
     place, rateAt, speed)`: a weather-timed craft run's catch-up and its bar. A mod keeps only its own place
     default and old-save migration (Yeast, Vinegar, the template).
   - Pieces into something as a fluid (Fish & Meat's fat, Dairy's butter): one action, **`TPPutPieces`**, takes a
     destination (`Cauldron.piecesInto(fire)`, `ItemFluid.piecesInto(item)`: here, room, put, station, after; what goes in is `asFluid` = { fluid, pieceMl, hoursLeft }), and one
     row, **`PiecesUI.row`**: with more than one fitting it opens One (the piece nearest to going off,
     `PiecesUI.oldestFirst`) and All (n). The cauldron's rules are `CauldronFluid.pieceRoom`, `putPieces`, its menu
     `CauldronUI.addPieces({ title, icon, pieceMl, hoursLeft, fluidRows, help, noRoom, refusal })`; a pot's are
     `ItemFluid`'s, its menu `ItemFluidUI.addPieces`. The mod registers its fluids (`turnsHot`, `goesOff`, `staysIn`) and adds its notes.
   - `PlaceKeeping.new(keepingRules)`: food that keeps by place (Potted Meat, butter). Its script days are a 15 C cellar's;
     `keepingRules.curve` is days of age a day counts as by temperature, read at Core's place temperature (fridge 4 C,
     freezer stopped, by a fire or banked embers as the stations: `FluidAgeing.placeOfItem` asks `Fire.placeOf` of
     whatever holds the item, and each look notes the fire's fuel on the clock, `FluidAgeing.noteFire`; the stretch
     after counts by the clock at the fire's heat while that fuel lasted, the rest at the place under it). The keeper's `keep(item)` brings an item up to now on its own ledger (`keepingRules.ledgerKey`) and
     modData clock (`keepingRules.modDataKey`); `keepingRules.enabled` is the sandbox switch, `keepingRules.days` sets fresh and rotten days on
     an item whose script has none. The mod's World calls `keeper.recordWeather(now, temperature)` in its `Weather.onReading`;
     `PlaceKeepingUI.watch(keeper, types)` looks at the items (Fish & Meat looks at its crocks in its own look);
     `PlaceKeepingUI.near(types, reach)` lists such items carried and in containers within `REACH` (4) tiles, for the
     consoles (`TPD.butter`, `TPFM.crocks`).
   - `Portions`: food eaten from a vessel a portion at a time. `set`, `left`, `text`, `name`, `label` and `used` do
     the sums, the name ("Jar of Yogurt (3 portions)", the core's text), the weight and the empty vessel;
     `Portions.onEat(fullType, before, after)` hangs a mod's handlers on the one wrap of the eat action.
   - `Handcraft.around(before, after)` / `Handcraft.after(after)`: handlers on the one wrap of the hand craft
     action, for a mod that gives something back for what a craft used up.
   - `Pour.before(name, fn)` / `Pour.after(name, fn)` (name is `start`, `stop` or `complete`) and `Pour.owner`:
     handlers on the one wrap of the fluid transfer, for what rides along with a fluid.
   - `Drink.cure(fluid, { foodSickness, cooldown, hours })`: a fluid that eases food sickness, so much a litre
     drunk, only while the drinker has some (as vanilla's food). A fluid script's `foodSicknessChange` never reaches
     the drinker (ENGINE_NOTES), so the one wrap of the drink action measures it. With a cooldown, a drink cures only
     if the key has run out at its first sick step, and starts it. Auto-drink takes only Water-category fluid.
   - `Cooldown.ready(player, key)` / `Cooldown.start(player, key, hours)` / `Cooldown.left(player, key)`: a named
     cooldown in the player's modData (`tpCooldowns`), in world hours. Keys are shared on purpose: `foodSickness` is
     every TP cure's, as vanilla's foods share theirs; a mod's own key carries its prefix.
   - `Uses.count(character, tag)` / `Uses.take(character, tag, owed)`: salt, vinegar or any tagged food or drainable
     by the use from what a character carries, part-used first. `Uses.onEmptied(tag, fn)`: fn(character, emptied)
     for items of the tag a take used up (Salt gives back its empty shakers and bags). Charge what a recipe line
     can't (Fish & Meat's salt by weight, a cure by the litre) here, not in a copy.
   - `FluidAgeing` treatments: a fluid kind registered with `treatments`, `litresPerUse` and `treatMenu` gets a submenu on
     its containers (Fish & Meat's *Cure Blood > -n Salt / -n Vinegar*), greyed with the reason; the timed action is
     `TPFluidTreat`. `FluidTreat.treatRefusal` / `treatBy` / `litresIn` / `treatUses` for a mod's own code (also
     reached as `FluidAgeing.<name>`).
   - `TraditionalPreservationCore.OnCreateCooked` (`Recipes.cookOutputs`): a recipe's cookable food comes out cooked.
   - `Charge.line(amounts)`: one recipe line that takes a different amount of each item (uses or a count); the
     craft window shows it (`ChargeUI`). `OnHeat.watch(fullType, minutes, fn)`: food kept at frying heat after it
     was made (vanilla's OnCooked fires once).
   - `Season.register(fullTypes, { groups = { { name, types, uses }, ... }, unhappy, boredom })` (checked: a seasoning
     item in one group only; adds `seasoning.groupByType`): a food seasoned afterwards,
     as a stew is (Fish & Meat's sausage links). A **Season** submenu on it (`SeasonUI`, timed action `TPSeason`)
     offers each group in reach not yet in it; a group goes in once, no cap, taking `uses` (default 1, what vanilla
     takes for a stew), each `unhappy` (and `boredom`) nicer. Never hand `Food.setSpices` the food's own list: it clears it first. What went in is the food's own spice list; `Season.carry(from, to,
     share)` hands it on (smoked, sliced), `Season.carried` / `Season.carryOver` keep it through a pot.
   - Sounds: `TPBoiling` for anything of ours that boils (`CookingSound = TPBoiling`), `TPSimmering` (the cauldron, at 85 C or more).
   - `Container.ml(container)` and `Container.isEmptyVessel(item)`; `Recipes.created(craftRecipeData, wanted)` and
     `Recipes.consumed(...)`: an OnCreate's own items as a Lua list, by full type or a set of them.
   - `Loot.add(fullType, { listName = weight })` (server): a mod's item into vanilla's loot lists, each list a room
     rolls (`ProceduralDistributions`); a list the game doesn't have is skipped. The item and its weights stay in the
     mod's `server/<Mod>Loot.lua`, with the reasons for the numbers (Salt's Bag of Salt, Dairy's kefir grains).
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
| `server/<Mod>Loot.lua` | server | Where the mod's found-only items turn up: the item by the mod's constant, its lists and weights through `Loot.add`, and why those numbers. Only mods with loot have one (Salt, Dairy). |
| `client/<Mod>UI.lua` | client | Popups, slot rules, context menus, and the mod's own vanilla wraps. Salt's is `...Menu`, Yeast's `...ShelfUI`. |
| `client/<Mod>Dev.lua` | client | The Dev console (`TPFM`, `TPS`, `TPV`, `TPY`, `TPD`), documented by its `help()` and DEVHELP. Vinegar also has `...Debug.lua`, debug-mode only. TP Core's is `TPC` (`TraditionalPreservationCoreDev.lua`): the Stone Hearth's commands, whichever mods are on. |

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

**Translation keys.** A key shown where it is written stays a literal (`getText("IGUI_...")`). A key a shared
function returns (a refusal, a status word) goes in a table on its module, as the full literal, and the code uses
the table: `FluidTreat.REFUSALS`, `Season.REFUSALS`, `FireConnect.REFUSALS`, `Smokehouse.REFUSALS`, Fish & Meat's
`F.REFUSALS` and `F.WORDS`, Vinegar's `V.PUMP_REFUSALS`. So does a key written more than once in a module. Tests
compare the full key, so they check the one the translation file holds.

**Vanilla wraps.** Every wrap goes through Core's `Wrap.method(owner, name, handler)`: handler(vanilla, ...) gets
the call's arguments and calls `vanilla(...)` for anything that isn't the mod's. Its comment says why vanilla's isn't
enough. `Wrap` puts it in late (OnGameStart; OnGameBoot on a dedicated server, which never fires OnGameStart), so a
mod that replaces the function outright as its file loads is wrapped too instead of wiping TP's out. In normal play
the handler is guarded: if it fails, vanilla still runs and the error is printed once; vanilla's own call (or another
mod's version of the function) is never inside the guard, so its errors are raised with their own message. Debug mode
runs the handler bare, so every error shows where it happened with its full trace. `tp test` fails on a vanilla
function replaced in place (`function ISThing:name(`) and on a function wrapped twice anywhere in the series. After every B42 patch, check
each one below against the new vanilla Lua; the copied add loop in `UI.slotRules` most
of all:

| Wrapped vanilla function | Where | Why |
|---|---|---|
| `ISWidgetCraftLogicOutputProgress.updateProgressItems` | core `UI.onProgressSlot` (Fish, Vinegar, Yeast, template through `progressTooltips`) | Weather-aware popups on running batches; Fish's salt badge |
| `ISCraftLogicPanel.ItemSlotAddItems` (add loop copied) | core `UI.slotRules` (`SlotRules.lua`; Fish, Vinegar, Yeast, template) | Each station's own input rules |
| `ISItemSlot.defaultVerifyItem`, `ISItemSlot.onMouseUp` | core `UI.slotRules` | Slot border and refusal halo agree with the rules |
| `ISWidgetCraftLogicControl.startCraft` | core `SlotRules`: `UI.slotRules` with `recipeRefusal` (Fish & Meat), `UI.craftRefusal` (Vinegar) | Craft refuses stored inputs the selected recipe can't take; Craft on a vessel that can't run says why, and a second press doesn't queue another run |
| `ISMoveableSpriteProps.canPlaceMoveable` | core `Placement` (one wrap for every rule): `UI.outdoorOnly` (Salt), `UI.notInRooms` (Fish, the Smokehouse), `UI.keepDoorsFree` (every TP station), `UI.offAppliances` (Dairy's crock) | Outdoor stations can't be carried indoors (or into a room); a station with a door (`Doors.register`) needs its front tile free, and none is put down in front of one's door (the build menu asks `TraditionalPreservationCore.doorFits`, `OnIsValid`); table-top stations refuse stoves, fridges, freezers, washers and dryers (vanilla lets an IsTableTop tile onto any IsTable square; its build ghost asks only on a solid square, so the build recipe asks `TraditionalPreservationCore.offAppliances`) |
| `ISAddItemInRecipe.complete`, `ISAddItemInRecipe.checkName` | Fish `...Evolved` | Single-icon stand-ins in a dish's ingredient list; stock pot names |
| `ISHandcraftAction.performRecipe` | core `Handcraft` only; handlers: Salt `...Shaker`, Vinegar `...Bottles`, Fish & Meat `...Stock` | Empty shakers and the right bottles come back; a boiled bone smashes into boiled pieces (without giving vanilla's Smash Bone an OnCreate, which would replace another mod's) |
| `ISCraftLogicPanel.createChildren` | Vinegar `...UI` | Fluid tank columns in the vessel's window |
| `ISWidgetCraftLogicInputControl.updateOutputItems` | Vinegar `...UI` | Hides the marker item in the vessel's output preview |
| `ISWidgetCraftLogicInputControl.createChildren` (wrapped on the first `UI.outputTooltips`) | core `UI.outputTooltips` (Fish & Meat) | The Output slot's popup lists every end of a recipe whose OnCreate swaps its output (the Hang recipes); remakes the output slots, which copy the panel's drawTooltip. Other recipes keep vanilla's |
| `ISMoveableSpriteProps.canPickUpMoveable`, `.getInfoPanelFlagsPerTile` | core `UI.keepInPlace` (`Placement.lua`; Vinegar, the Stone Hearth, the kraut barrel, the Salting Tub, Dairy's pot and crock) | A station holding liquid, a running batch, a hose or anything kept in its movableData can't be picked up, nor a Stone Hearth that is lit, banked or holds fluid, and the cursor says why. No station moves mid-process: each process has its time and place |
| `ISObjectClickHandler.doClickSpecificObject` | core `InfoWindow.clickOpens` (Vinegar, Dairy, the Stone Hearth) | Clicking a cask, a Stone Hearth, an incubator or a crock opens its info window |
| `ISWidgetCraftLogicOutputProgress.createDynamicChildren`, `.calculateLayout` (wrapped on the first `StationInfo.add`) | core `StationInfo` (Fish & Meat) | A station's info block under Take All; the widget grows by its height. Other stations pass straight through |
| `ISWorldMenuElements.ContextEntity` | Vinegar `...UI` | Station icons in the right-click menu |
| `ISFluidTransferAction.start`, `stop`, `complete` | core `Pour` only; handlers: core `FluidAgeingWorld`, Dairy `World` | Poured fluid takes the source's age (older wins) and both ends are looked at as it ends, so names change at once (core); poured milk carries its heat record (`tpdCarry`) over, mixed by volume (Dairy) |
| `ISInventoryTransferAction.transferItem` | core `Transfer` only; handlers: core `FluidAgeingUI`, core `PlaceKeepingUI`, Dairy `UI`, Fish & Meat `UI`, Salt `BrineUI` | Looked at while still on the heat: hot milk scalds (core); kept food moved counts its time where it was (core, Dairy's butter); milk off a stove or fire keeps a heat record (Dairy); a crock moved counts its time (Fish & Meat); a bucket of brine into the heat becomes the boiling item and back (Salt) |
| `ISToolTipInv.render` | Salt `BrineUI` | A bucket of brine and the boiling item show their strength and the salt they boil to (the item's Tooltip text for the one draw) |
| `ISMilkAnimal.milk` | core `FluidAgeingWorld` | A container whose milk is all gone forgets its age before new milk goes in |
| `ISWidgetInput.updateValues` | core `ChargeUI` (Fish & Meat's filler) | A charged line (`Charge`) shows its real amount (*n/12 Uses*, *n/12*) with the consumed icon; other lines pass straight through |
| `ISGatherBloodFromAnimal.updateBucket` | core `FluidAgeingWorld` (for Fish & Meat's blood) | A container with no blood starts a new record; fresh blood gathered onto treated blood makes it untreated |
| `ISDrinkFluidAction.updateEat` | core `Drink` only; cures: Dairy `...Kefir` | Fresh kefir eases food sickness, 10 a litre drunk, on the shared `foodSickness` cooldown |
| `ISEatFoodAction.complete`, `serverStop` | core `Portions` only; handlers: Dairy `...Yoghurt`, Fish & Meat `...Potted` | A Jar of Yogurt or a Crock of Potted Meat eaten from is relabelled with its portions and weight, and the last bite gives the empty jar, Clay Jar or Clay Pot back; a crock's first portion opens it |
| `ISCampingMenu.doLightFireOption` | core `FireUI` | A banked Stone Hearth's vanilla fire is out: Put out Fire (unbank) instead of Light Fire, in the right-click and controller menus |
| `ISLootWindowObjectControlHandler_LightFireOption.shouldBeVisible`, `ISLootWindowObjectControlHandler_PutOut.shouldBeVisible`, `.perform` | core `FireLootControls` | The same in the loot window's buttons |
| `ISItemSlotRemoveAction.complete` | Salt `...Brine` | Brine taken out of the vat turns back into fluid in its bucket |
| `ISTakeGenerator.isValid` | FuelBarrel `ISFuelBarrelHose` | A generator with a barrel can't be picked up |
| `ISGeneratorInfoWindow.getRichText` | FuelBarrel `...Menu` | Barrel level in the generator's info (FuelBarrel is not a TP mod and wraps directly) |

A new wrap goes in this table. **One function has one wrap in the series: when a second mod needs a vanilla function
a first one wraps, the wrap moves to the core** and both add handlers (`Transfer`, `Portions`, `Handcraft`, `Pour`,
`Drink`, `SlotRules`' layers): one place to compare with vanilla after a game update. Registering the same function
again replaces the handler (a file reloaded in debug mode); it never wraps twice.
The handler order differs: Transfer runs its handlers in the order added, Pour and Handcraft as nested wraps would
(the last added's before first). Each module's header says which; a handler that depends on another's must not
assume the other order.
A wrap `require`s the vanilla file plainly before it wraps (`require "Fluids/ISFluidTransferAction"`), never through
`pcall`: the engine's `require` of a missing file only warns, and vanilla's file is loaded first anyway. The test harness stands in for the file (`H.preloadVanilla`).

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
  `TP_MODS` and the installed mods, and `tp status` warns on a duplicate. A tileset holds at most 512 tiles.
- **Every workstation needs its own sprite**, or the world won't load. Style names can't contain `_`.
- **A station tracked from Lua must check it is really loaded.** `getSquare()` and `getObjectIndex()` aren't enough:
  an unloaded object passes both until its chunk has been saved. Compare `getCell():getGridSquare(x, y, z)` with its
  square (the FAQ below says why).
- `mod.info`: `author=alienPaco`.

## Refactoring rules

What a refactor (and new code) aims for. `FluidAgeing.lua` follows every rule and is the one to read first.

1. **Rules on plain tables, engine calls apart.** A module's rules (ages, stages, merges, rates) take and return plain
   tables and numbers and get luajit tests; the parts that call the engine (`getFluidContainer`, `getModData`,
   `Fluid.Get`, squares) sit below them, or in their own file.
2. **Saved data stays plain.** Anything in modData or a ledger is plain tables, strings, numbers and booleans: no
   metatables (they don't survive a save), no functions. Records are worked on by functions, not turned into classes.
   A field rename comes with one migration function, in Core when two mods read the field.
3. **Say it once.** The same three or more lines twice in a file become a local helper; the same idea in two mods
   goes in Core (see "Core shared wraps"). A family of actions that differ only in their middle step (look, check,
   change, apply) gets one helper that takes the middle step as a function.
4. **Work out once what changes once.** What depends only on what was registered (sets of names, the lowest heat,
   engine objects such as `Fluid.Get`) is worked out at register time, or the first time it is asked for if the
   engine may not be ready then, and kept on the registered table. What a call needs more than once (a fluid age's state, the fluids
   found in a container) is worked out once in that call and passed down. Code on a timer (every minute, every ten,
   each loot refresh) matters most.
5. **One file, one job.** Split a module when it holds parts with different dependencies or different users (a
   station's state shape, the character's inventory, UI keys). The original module stays the one name callers use and
   passes the moved functions on, so no other mod changes.
6. **Check what register is given.** A `register` function `assert`s the fields it needs and that nothing another
   registration owns is claimed twice, naming the kind and the field, instead of failing later on a `nil` key. Its
   header says which fields it adds to the registered table.
7. **Client files don't add to shared tables.** A client function lives in a local or on the client module's own table.
8. **Name the magic values.** A fallback place, a tolerance, a radius: a named constant, one per meaning.
9. **Order never decides.** A result built while going through `pairs` must not depend on the order (Kahlua's
   isn't luajit's); test the cases where two orders could differ.
10. **Nothing changes in game.** A refactor changes no outcome; changing what the player sees or the numbers is a
    balance pass. `tp test` for the module and every mod that calls it passes before and after, and the golden
    results don't move. A bug found on the way may be fixed in the refactor, but only once it has been agreed
    (ask first, every time), and with its own test.
11. **Before the first release, old names can go.** While nothing is on the Workshop, leftover names (a save key, a
    module, a field from a test build) are renamed outright and their test-build migrations dropped. From the first
    release on, "Never rename a save key" above holds.
12. **Core is mod-agnostic.** Core names mechanisms, not one mod's product: no milk, blood or fish words in its
    fields, functions or save keys, and no special case that only one mod's fluid or station can use. What a mod
    brings is data it registers (names, numbers, curves, rules as functions). When a Core feature was built for one
    mod, fold it into the general mechanism once that mechanism can carry it. Example: Dairy's scalded milk is not a
    field of its own in FluidAgeing but one of its `states` (a variant of the fresh fluid with its own name and
    spoiling) with `heat = true`, brought about by heat instead of by hand, so any kind can have a heat-made variant.
13. **No guard for what the engine always has.** `x.method and x:method()` or a `pcall` around an engine call is for
    a real second kind only (a server or a test with no inventory menu, a non-food item that has no spices); say
    which in a comment. A guard that only covers a test stand-in missing the method is wrong: give the stand-in the
    method. A `pcall` that puts something back before raising the error again (Salt's tooltip draw) is a real case,
    and so is `Wrap`'s guard around a TP handler, in normal play only (vanilla and other mods' code run outside it,
    and debug mode runs bare).
    Check the class in the Umbrella stubs (and `decompile.sh` for whether the call can fail) before guarding.

## FAQ: why the series does it this way

For other modders reading the code. Each answer is the reason we chose it, not the only way it could be done.

**Why a weather ledger in global ModData, and not a timer on each object?**
A station's chunk is unloaded most of the time, and nothing on it runs then. The weather is the same for every
station, so one set of running totals (work done per place, recorded every 10 in-game minutes) is enough for all of
them. A station only keeps the totals it last saw; when it loads again, the difference is exactly the work it missed,
however long it was away. That costs one small table per mod, never grows with the number of stations, and needs no
catch-up simulation. The reading itself and the season's means are kept once, in TP Core's ModData, and copied into
each mod's ledger: a mod added to a save in July then agrees with the others about the cellar at once.

**Why five places (Open, Covered, Sheltered, AiredRoom, Basement), and how warm is each?**
They are what a survivor can actually choose, and each behaves the way a real porch, room or cellar does. **Open** and
**Covered** (a roof, not a room: a porch, an open shed) go by the hour's air: a roof keeps off rain and sun, which are
each process's own rules (rain on open frames, hot sun on fresh salt fish), not the air's. The game's temperature is
shade air already. A **shut room** (Sheltered: in a room, every window to the outside shut or barricaded) lags the
weather by its walls: the mean of the last three days (`ROOM_HOURS`, `threeDayTemperature`), +2 C in the cold from a
10 C mean down (`ROOM_LIFT`, none from 18 C: the house's mass, the people, the sun through the glass) and stuffy in
summer, up to +2 C from 18 C to 21 C (`ROOM_SUMMER_LIFT`). An **aired room** (AiredRoom, *Aired room*: a window to the
outside open, smashed, without its glass or an empty frame, a door to the outside open or an empty doorway, and not
barricaded;
`Windows.aired`) follows the day's
mean (`AIRED_HOURS`, `dayTemperature`), at most +1 C in winter (`AIRED_LIFT`): within a degree of outside, never
stuffy. In PZ the ground floor is boarded up, so the aired room is usually upstairs. While the grid is on both rooms
are 22 C (`Weather.GRID_ROOM_C`, vanilla's figure; a generator doesn't count, as in vanilla). A **basement** swings two
fifths as far as the ground from 10 C (`basementTemperature`); the ground is the season mean's (`SEASON_HOURS`, about
ten days) own 30-day mean (`GROUND_HOURS`, `groundTemperature`), so a cellar is coldest in March and warmest in August.
Every mean is kept once in the series' weather and copied into each ledger by `Weather.seasonTemperature`. Season
tools start from `Weather.settledMeans` (the sampled year gone round twice), not a cold 1 January. A room is not a
heated house: most players don't keep one heated, so autumn indoors is slow and a fire is the answer.
`Windows.lua` walks the room's squares (a map room by `getRoomID()`, a built one by its world region) because
`IsoRoom:getWindows()` is never filled, and asks each outside wall through the game's own lookups (`getWindowTo`,
`getWindowFrameTo`, `getWindowThumpableTo`, `getDoorTo`, then the wall's DoorWallN / DoorWallW flag for an empty
doorway), never the other objects on a square. It is kept cheap on purpose: a
room's answer holds for the ten-minute reading, a room is read at most 150 squares from the station, and at most one
scan runs in 20 real milliseconds (a room due inside that keeps its last answer). `TPC.windows()` times one.
Every place is a square's: a station that is a building of its own is not a place. Inside the Smokehouse
(*In the Smokehouse*, `Smokehouse.PLACE`) the stacks carry the Smokehouse's word, set by the station's session state
(`sessionState.place`), and its temperature is an open roof's (`Weather.STATION_PLACES`). The still air and the rain
kept off are the mod's own rates (Fish & Meat's Shed). The ledger keeps no totals for it.
**One place, one temperature:** a station or a stored item reads a place's temperature from
`Weather.placeTemperature` and nowhere else. If a process comes out wrong there, change the process's own numbers
(its curve, its hours), never the temperature it is given.
**One air rule:** anything that dries by air (salt fish, charque, dry curing, stockfish, onions and garlic, kefir grains
on a cloth) dries under a roof and in an aired room and stands still in a shut room until a window opens. Barrels,
tubs, crocks, shelves, vessels and crates mind the temperature only.
**Exceptions:** an exception to those rules must rest on **realism**, and must **keep every process's path open** (no
process shut out of the year by the place model; stockfish keeps its winter in the open). Write each one down here
with its reason. The ones there are:
- **A basement keeps its own still-air rates** (Fish & Meat: salt fish and charque at the still-air share, dry curing
  at two thirds): a cellar with its vent and its cold is where hams were cured.
- **Dry curing is spared the muggy-season spoiling** that salt fish and charque take in still air: country hams were
  aged through the summer heat on purpose.
- **Muggy spoiling needs still air, and the Smokehouse's reads the ten-day mean**: salt fish and charque spoil in a
  muggy season only in the Smokehouse, a shut room and a basement (moving air keeps the skin dry); in the Smokehouse
  by the season's mean, as mould and rancid fat come of days of damp warmth, not one hot afternoon.
- **Unsalted fish's warm rot is weighted by its wetness squared** (a process number, not a temperature: a dried skin
  protects the flesh), which keeps open-air stockfish possible in January and February while it reads the hour's
  temperature as the open air must.
- **A lit fire draws air through a shut room** for onions and garlic (Fruits and Vegetables' dry cure); banked embers
  don't.
More places (north wall, near the stove) would ask the player to learn rules the game can't show them.
By a fire and by banked embers are `Weather.FIRE_PLACES` that Stone Hearth registers, in a shut room at a fixed 28 / 24
C, and in an aired room, under an open roof or in the open (`FiresideAiredRoom`, `FiresideCovered`, `FiresideOpen`,
`Embers...`) at that place's air plus `Fire.FIRE_LIFT` / `EMBERS_LIFT`, capped at the indoor heat. The ledger keeps
no totals for them, so `Fire.catchUp` counts them by the clock until the fuel noted by `Fire.noteFire` runs out, then gives the
place under the fire its share of the gap by time. A station's World calls `Fire.notePlace`, which catches a run up
at its old place before writing the new one.

**Which kind of station? (the station rule)**
Three kinds, by what the station holds:
- **Counted items in, items out, in batches that may overlap: a `CraftLogic` station** (Yeast's Shelf, Vinegar's
  Floor, Salt's Vat, Fish & Meat's Tub; `DryingCraftLogic` for a frame of stacks: the Frame, Beams, Gantry and
  Smokehouse). It gives slots, the vanilla window, Take All, a bar and each run's save and load. The timer is always
  set from Lua (`OnStart` / `OnUpdate`, below). It is read by **an info block in the crafting window**
  (`StationInfo.block`: place, temperature, working rate, a bar a batch) and a hover popup on each running batch.
- **A measured liquid, one continuous pool, or a state that depends on its own past: Lua state and right-click
  timed actions** (the Orleans Cask, the Stone Hearth and its cauldron, Dairy's Incubator and Crock). The engine can't be
  trusted with fluid amounts in a station, a cask is one pool with no batch, and the
  incubator's milk cools from what it was. It is read by **an Info window on click** (`InfoWindow.clickOpens`) and
  its right-click line.
- **Storage that only changes how a finished item keeps or ripens: a container or the item's own clock**, no run at
  all (the Stockfish Pallet and Bale, the Crock of Potted Meat, maturing and ageing). It is read by the item's name
  and tooltip, and a right-click line where the place matters (the Pallet's speed).
Vinegar's Fermentation Vessel is the one hybrid: a `CraftLogic` run of a marker item while Lua moves the wort. A
new station picks its kind by this rule and is read the way its kind is.

**Where a station may stand**: **no TP station stands in front of a door** (the Stone Hearth's mouth,
a Smokehouse's door, any `Doors.register`ed one). Its entity script's `SpriteConfig` has an `OnIsValid`:
`TraditionalPreservationCore.doorFits`, or a mod's own check that also asks `Doors.fits`; a table-top station's is
`TraditionalPreservationCore.offAppliances` (no stove, fridge or washer under it). Its mod's client file passes its
sprites to `UI.keepDoorsFree` (a list like `Tiles.STATIONS` or a set) for putting it down. test_doors fails for an
entity script without an `OnIsValid`. Vanilla's build ghost asks `canPlaceMoveable` only on a solid square, so the
build check can't be left to the put-down rule.

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
A copy in each mod would let a player subscribe to one with no dependency (PZ loads only one file per Lua path, so
each copy would live under its mod's own path). But the series shares *stations*, not only code (the Stone Hearth with its cauldron is wanted by Dairy and later by cheese and others), and a station
needs one tileset, one save key and one set of timed actions. Two mods can't both ship it. One required mod also
means one copy of each fix, and one place for multiplayer's network code later. Its modules still return a local
table; the only globals are what the engine needs by name: `TraditionalPreservationCore.OnCreateStoneHearth`
(the entity script) and `OnCreateCooked`, the timed actions (`TPCauldronWork`, `TPFireTend`, `TPFireFit`,
`TPFireConnect`, `TPFluidTreat`, `TPSeason`), and `TPC`, the debug console. FuelBarrel is not a TP mod and does not require it.

**Why the extra check that a station is loaded?**
An unloaded object keeps its square and its index until its chunk has been saved and reused, so `getSquare()` and
`getObjectIndex()` both say it's fine. Writing to it then is lost, or worse, writes into a stale chunk. The cell stops
returning that square the moment the chunk unloads, so `getCell():getGridSquare(x, y, z) == square` is the real test.
Every tracker uses it through `Station.isLoaded`.

**Why no literal `%` in translations?**
The game's translator reads a finished line again as a format pattern. "40% soured" makes it throw, and so does a
line with `%1` given no values. So translations take plain tokens (`@1@`) through `UI.say`, and the values are swapped
in afterwards with `gsub`. `test_harness.lua` checks every mod's translations for a stray `%`.

**Why do saves never lose a key?**
Players keep saves for months. A renamed ledger field or modData key silently resets every running batch, so from
the first release names are fixed, and a migration an old save needs stays in the code with a test (until then,
rule 11 of the refactoring rules).

## Starting a new mod

Settle the design first (what the station holds, which place it reads, what it shares with the other mods), then:

```
tp new Dairy --station "Cheese Press"     # --short TPX to pick the console name
```

It renders `TraditionalPreservationCore/template/` into `<TP_MODS>/TraditionalPreservationDairy`: one floor station (S and E faces, a
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

- `tp package <Mod>` writes the folder to upload, `<TP_MODS>/_package/<Mod>/Contents/mods/<Mod>` (`--out DIR` for
  another place): `42/`, `common/`, README, guide and CHANGELOG, and nothing a player has no use for (tests, tools,
  DEVHELP, WORKSHOP.txt). It runs the tests first, replaces only the mod's own folder (a `workshop.txt` and
  `preview.png` beside `Contents` stay), warns if the repo isn't a clean commit and names the mods to list as
  required items. Don't point `--out` at `~/Zomboid/Workshop` while the mod is also in `~/Zomboid/mods`: the game
  loads both.

- Edit player guides in `<TP_MODS>/guides`, then run `tp guides`. It copies each guide into its mod and rebuilds the
  collection zip. It refuses if a copy inside a mod was edited more recently than the guide in `guides/`.
- Guides read like an old-school game manual: stat tables, margin notes, real-world notes, and a Tester's Toolkit
  appendix copied from the mod's `DEVHELP.md`. Change both together.
- Each mod keeps `README.md` (for developers), `WORKSHOP.txt` (Steam BBCode) and `DEVHELP.md` (debug console
  commands) in step with the guide.
