# Changelog: Traditional Preservation (Core)

## 0.1.71
- **Fixed: a kept food's keeping line read far too few days after a while unlooked** (user, 2026-11-26: cured garlic
  on a pole, 46 days fresh for 114). Between two looks vanilla ages the item at its own speed, and the forecast read
  that age; it now reads the keeper's clock, as a look writes it (`PlaceKeeping` `forecast`). The item was never
  affected. Test in `test_place_keeping.lua`.

## 0.1.70
- **Animals keep their days** (user, 2026-11-25: a herd that aged no day in four of coming and going). Vanilla ages an
  animal, moves its pregnancy on and grows it only after a whole day loaded, and its pen's catch-up drops the part-day.
  `AnimalDays` keeps each animal's age and pregnancy by the calendar (world mod data by animal id) and moves vanilla's
  forward when it falls behind, the age through vanilla's own `growUp` (never back); the pregnancy day is set to the
  calendar day from conception both ways, as vanilla's catch-up can count a midnight twice (user, 2026-11-26: an Angus
  cow 3 days ahead in 2). Hourly things untouched, wild animals left alone. Run each hour by `server/.../AnimalDaysWorld.lua`. Sandbox **Animals keep their days** (on). The
  animal report shows the days kept. Tests in `test_animal_days.lua`.

## 0.1.69
- **Fixed: the animal report split one pen in two when its joined zones had different names** (user, 2026-11-25: a pen
  redrawn as four quarters). A pen now goes by its most north-west zone, and each zone's line gives its name.

## 0.1.68
- **The animal report lists each zone a pen is joined from** (user, 2026-11-25): its corners, size, and whether all of
  it was loaded at the save. Vanilla catches a zone's animals up for the hours away only when both its corners load at
  once, so this shows which part of a large pen stands still while the player is away.

## 0.1.67
- **Fixed: the animal report put an animal in "No pen" when it hadn't looked up its pen yet** (user, 2026-11-25: a
  Holstein just brought, and the bull at the edge of the loaded squares). The report now finds the pen where the animal
  stands, as the animal's own lookup does (`DesignationZoneAnimal.getZoneF`).

## 0.1.66
- **Fixed: the animal report read 0 troughs for a pen partly out of reach** (user, 2026-11-25: the pig pen has 6).
  Vanilla counts a pen's troughs, food and hutches only while all of it is loaded; such a pen now says it wasn't
  counted.

## 0.1.65
- **An animal report beside the station report** (`AnimalReport.lua`), for the long save's log: on each save,
  `~/Zomboid/Lua/TraditionalPreservationAnimals_<save>.txt` lists every loaded animal (walking about, in a hutch, in a
  trailer) by its pen, with the pen's troughs, feed and water, then each animal's sex, age, place, health, hunger,
  thirst, stress and acceptance, and its milk, pregnancy, wool and young where it has them. Read-only. Test in
  `test_animal_report.lua`.

## 0.1.64
- **Fixed: a fresh Butter's keeping line read about 821 million days** (user, 2026-11-24: freshly churned). Before
  an item's first look it still has its script's days (vanilla Butter's never-ending ones), and the tooltip's forecast
  read those. It now reads the keeper's own days for the item when it has them (`PlaceKeeping` `days`). The item itself
  got its days at its first look as before. Test in `test_place_keeping.lua`.

## 0.1.63
- **Console: `TPC.food(r)`, `TPC.foodTotal()`, `TPC.foodReset()` and `TPC.crops(r)`** (user, 2026-11-23, for the long
  save's winter sums): the food on you and in containers within reach summed by name and state (count, weight, kcal,
  hunger, days at 2,500 kcal, salt in uses and E), a running total over the containers read, and the living crops by
  kind with their ready dates and expected harvest. Read-only. DEVHELP.
- `Wrap.method` takes a path to a nested table as its owner (`"Fishing.Utils"`), for Fish & Meat's fishing by season.

## 0.1.62
- **Fixed: the station report wrote `xnil` for a holding's counts** (the Kraut Barrel's apples and carrots;
  long-save snapshot, 2026-11-22). It read a `count` field; the entries are `{ icon, count }` as Holds draws them. It
  now writes the item its icon names and the count ("Apple x2"). Test in `test_station_report.lua`.

## 0.1.61
- **Fixed: a pot of melting butter turned into an empty pot** (user, 2026-11-22, Dairy's Put Butter in a Pot).
  Vanilla's `canAddFluid` refuses anything while the player can't empty a container, and a fluid that stays in
  (`ItemFluid.staysIn`, Butter (Melting)) locks it: the turn to Clarified Butter (Melted) took the butter out and
  added nothing, and Put Butter in a Pot on a pot already melting butter used the butter and added nothing.
  ItemFluid now unlocks, adds and locks again. The test's container refuses as vanilla's does. Yeast's hop water
  and potato soak were never locked, so never affected.

## 0.1.60
- **Right-click the cauldron's tank in Stone Hearth Info to fill a container you choose** (user, 2026-11-22): the
  same Fill from the Cauldron submenu as the hearth's menu, while the cauldron holds anything. Test in
  `test_fire_menu.lua`.

## 0.1.59
- **The clay pipe flue is laid as masonry** (user, 2026-11-22): Connect / Disconnect with the Pipe kit play vanilla's
  crouched brick-laying (`MakeWithBrick_Low`), the trowel carried in the right hand and a lump of clay in the left,
  in place of the generic build. The flat-stone kit keeps its digging.
- A fit (Fire.attach) can say how its work looks, as a connection's kit could: `anim` and `prop`, played by the new
  `Action.playKit` for Fit / Remove and Connect / Disconnect; `Build` without them, so the cauldron's fit is as
  before. DEVGUIDE; test `test_action_kit.lua`.


## 0.1.58
- **Fixed: a favourite tool didn't count for a hearth kit** (user, 2026-11-22: a favourited Wooden Trowel read
  "Missing" for Fit Salt Pan). Fit, Remove and the Smokehouse's joining kits now take a favourite as the kept tool, as
  vanilla's crafting does (`InputScript.allowFavorites`); a favourite is still never used up. `UI.findItems` takes a
  third argument, `withFavourites`, for kept tools. Test in `test_fire_menu.lua`.
- The trowel reads "a Mason's or Wooden Trowel": both carry vanilla's mason's trowel tag.


## 0.1.57
- **How long food keeps, in its tooltip** (user, 2026-11-21: needed to check the storages in game without debug): a
  food kept by place (`PlaceKeeping`) says in its inventory and loot tooltip how long it keeps where it is ("Fresh for
  about 50 days here, rotten in about 88 days", "Stale: rotten in ...", "Doesn't age here") and where and how fast
  ("4°C (Fridge), ages 0.40 days a day"), read-only from the new `keeper.forecast(item, place, factor)`. A mod adds its
  types with `KeepingTooltip.add(types, lines)`. TP Core's first sandbox option, **Keeping in item tooltips** (on), turns
  it off for a harder game. Places Fridge and Freezer have names now.
- **`ItemTooltip.lua`, the one wrap of `ISToolTipInv.render`**, moved here from Salt so every mod adds lines to it
  (`ItemTooltip.add(fn, { sameLine })`); Salt's brine line reads as before.
- **A stale stretch of its own** (`PlaceKeeping` `staleShare`, for Fruits and Vegetables, user, session 78): a keeper
  that sets it runs an item's stale days on a second clock (`clock.stale`, its own ledger process `<process>Stale`)
  where only that share of the place's slowing holds (0: a day a day, frozen still stopping it). The crossing at a look
  counts the part past stale again at the stale rate. `keeper.settle` / `keeper.active` for mods that move a clock
  themselves; `Frost.bite` moves the stale clock once there is one; the forecast and the console's `describe` count
  both stretches. Keepers without it (Potted Meat, butter, the cultures) keep as before. A keeper's `days` now also
  sets a rotten day that differs while the fresh one matches.
- Tests: `test_item_tooltip.lua`, forecast and stale-clock checks in `test_place_keeping.lua`.

## 0.1.56
- **Station report on each save** (ROADMAP "after the break" 4, for the long-save log): when the game saves (quitting,
  waking up), TP Core writes `~/Zomboid/Lua/TraditionalPreservationStations_<save>.txt`, what every loaded station's
  info window would show then: its band, the Station block (place, season, its own rows), what it holds (amount,
  state, heat, the rate on an arrow) and its list's rows with their warnings, a block per station, by window title
  then position, under a header with the save, the in-game date and the player's square. Read-only: each station is
  brought up to now as opening its window does. Only stations loaded at the save are in it (those round the player).
  Buttons, notes and lore are left out. A window takes part with one `StationReport.add(class, stationOf)` line
  (`StationReport.lua`); `Station.trackers` and `Station.eachLoaded` list every mod's tracked stations. The Fire and
  Drying Cloth windows are in it; test `test_station_report.lua`. `_pzdev/longsave_snapshot.py` copies the report into
  the log as `stations.txt`.

## 0.1.55
- **Spread Drying Cloth finds the kit in bags**: the Sheet and Stones are looked for in everything carried, a
  backpack too, and brought out to the main inventory before the cloth is spread (it showed only when both were
  loose in the main inventory).

## 0.1.54
- **Spread Drying Cloth** (user, session 77: the build menu is for what is built of wood): with a Sheet and 2 Stones in
  the inventory, right-click a floor: **Spread Drying Cloth** (only with the whole kit; greyed in front of a door, on
  furniture or on another cloth), lying along the way you look. Empty, its menu has **Pick Up Drying Cloth**: the
  Sheet and Stones back (greyed while anything lies on it). No Build menu entry; not a moveable any more (no
  `IsMoveAble`). `DryingCloth.KIT`, `spreadRefusal`, `pickUpRefusal`, `spread`; `TPDryingCloth` modes "spread",
  "pickup". Tests in `test_drying_cloth.lua`.
- **Walking over the Drying Cloth**: the cloth takes vanilla's rug depth (`floors_rugs_01_0`) through
  `common/media/tileDepthTextureAssignments.txt`, written by `tools/build_tileset.py`, so a character standing on it is
  drawn over it. Without a depth texture the game's default drew the cloth over the character's legs. What lies on it
  shares its depth.
- Internal: `tp install` ships Core's `common/` folder too (it had shipped `42/` only).
- Internal: `tools/pzart.py` `write_depth_assignments` and `RUG_DEPTH`, shared by the builders that put things on
  the cloth (Yeast's cakes, Dairy's grains).

## 0.1.53
- **Clamp places** (ROADMAP section 8 phase 3, session 77): `StrawClamp` (roots under straw) and `EarthedClamp` (earthed
  over) join `Weather.PLACES`, given by a container, never by a square: `FluidAgeing.CONTAINER_PLACES[type] =
  fn(container)` says the place of what lies in a world container (Fruits and Vegetables' clamp). A clamp sits halfway
  (`Weather.CLAMP_GROUND` 0.5) from the air it follows to the basement's temperature (`Weather.clampTemperature`):
  under straw the day's mean, earthed over the three-day mean. Every ledger gets their totals (Yeast's and Dairy's
  golden reports re-recorded for the new ledger lines; Dairy's report skips the clamps, which take only roots).
  Words "In a clamp", "In an earthed clamp". DEVGUIDE lists it as a place exception. Tests in `test_core.lua` and
  `test_fluid_ageing.lua`.
- **Diggable ground** (`Ground.lua`): `Ground.diggable(square)` is vanilla's own rule for a furrow
  (`ISFarmingMenu.canDigHereSquare`: ground level, a free square of bare dirt, no plant or grave) with its grass
  removed first (`Ground.hasGrass`: what Remove Grass takes, flagged `canBeRemoved`; a furrow digs through it), outdoors
  under the sky; for something set into the earth (FV's clamp). Tests: `test_ground.lua`.
- **Storage icons in the loot window** (user, session 77): `UI.containerIcon(type, path)` gives a container type its
  button icon (vanilla's `ContainerButtonIcons`; a type it doesn't know shows the shelves). `tools/pzart.py`
  `write_container_icon` paints one as vanilla's: 32 px, the art fitted inside 30 (`art/container_icons_mock.png`).

## 0.1.52
- **Frost helpers** (ROADMAP NEXT 1, step 3): `Frost.see(modData, key, kind, now, seen)` keeps an item's frost record
  and gives the hours frozen since the last look; `Frost.frozenThrough(record, hours)` says a one-time change is due
  (`Frost.THROUGH_HOURS` 6: a jar or pot frozen through); `Frost.bite(item, hours, ruinHours, clock)` moves an item
  towards rotten, its PlaceKeeping clock too (`Frost.STARTER_RUIN_HOURS` 48 for live starters, user, session 76).
  `frozenThrough` has a hair of slack, so six hours of ten-minute readings (a whisker under 6) count as 6. FV's
  vegetables use them (no change in game). Tests added to `test_frost.lua`.

## 0.1.51
- **Frost** (ROADMAP NEXT 1, step 1 of 4): `Frost.lua` counts hours at or below a freezing point by place, on one
  ledger for the whole series (`TraditionalPreservationCoreFrost`, recorded every ten minutes by `FrostWorld.lua`), at
  Core's place temperature, so a thing left alone catches up when next looked at. A mod names its points at load
  (`Frost.point(celsius)`, processes `frostAt<celsius>`), starts a record (`Frost.newRecord`) and gets the hours frozen
  since the last look (`Frost.catchUp`); `Frost.freezingAt` says whether a place freezes now. A powered fridge never
  freezes, a powered freezer counts nothing (vanilla's rules), a place by a fire goes by the fire's heat while its fuel
  lasted. Nothing in game changes yet: no mod names a point, and with none Core makes no ledger. Tests: `test_frost.lua`.

## 0.1.50
- **Aired room by distance** (ROADMAP NEXT 1): a square in a room is an aired room when the outside air reaches it
  within `Windows.AIR_STEPS` (6) steps, walking through edges with nothing shut on them: an open or broken window, an
  empty frame, an open door, an empty doorway or no wall at all lets it through, room to room too (an open inside
  door, a knocked-through wall); a wall, a shut door or a shut window stops it. Replaces the walk by room id, which
  kept two rooms opened into one apart (Known issue "A knocked-through wall doesn't share the air"); a big room's far
  end now reads shut. The answer is kept per square for the ten-minute reading (was per room), under the same frame
  budget; `Windows.MAX_SQUARES` and `Windows.roomKey` are gone. Checked first against both long saves with a
  temporary `TPC.airCheck()`: one Drying Beam beside a broken wall goes from shut to aired, nothing else moves.
- `TPC.windows()` walks from where you stand. Tests: the harness's `H.shutRoom` gives a square a shut window on
  every side; new walk tests (distance, inside doors, a knocked-through wall, a gap, a doorway).

## 0.1.49
- **Crafting-window pieces retired** (ROADMAP Info windows step d; a refactor, nothing changes in game): no TP station
  uses vanilla's crafting window, so `StationInfo.lua`, `SlotRules.lua` (`UI.slotRules`, `UI.craftRefusal`),
  `UI.onProgressSlot`, `UI.progressTooltips`, `UI.outputTooltips`, `UI.drawListTooltip`, `UI.shortName` and
  `Station.uiLogic` / `itemSlots` / `countItems` are gone, with their wraps of `ISCraftLogicPanel.ItemSlotAddItems`,
  `ISItemSlot.defaultVerifyItem` / `onMouseUp`, `ISWidgetCraftLogicControl.startCraft`,
  `ISWidgetCraftLogicInputControl.createChildren` and `ISWidgetCraftLogicOutputProgress.updateProgressItems` /
  `createDynamicChildren` / `calculateLayout`, and their tests. `UI.drawTooltip` stays (the piece lists' popups).
- **Craft-run timers retired** (no craft recipe runs on a timer now): `Fire.updateRun` / `catchUpRun` and CraftClock's
  `showProgress`, `setRecipeHours`, `recipeHours`, `startClock`, `showClock` and `batchStatus` are gone with their
  tests. `CraftClock.lua` is gone too: its one live function, `Weather.startRun` (Yeast's cultures), is in Weather
  itself, same name, same behaviour. `Action.startClock` (timed actions on the game clock) is untouched.
- **The template's station is a piece record** (`tp new`), as the station rule says: raw batches put in from its
  right-click menu (One / All) or dragged onto the cells in its Info window, each batch on its own weather-weighted
  clock in the station's movableData (FluidAgeing on the mod's ledger), Take Done / Take All, kept in place while it
  holds anything, never in front of a door (`OnIsValid`). Its timed action is `TP<Station>`. No crafting window, no
  Process Batch recipe; the Dev console's `fast` sets the hours alone. New `tests/test_menu.lua` (put in, age, take
  out); `test_process.lua` and the golden `season_report.lua` run on the record. README, DEVHELP and the guide stub
  follow.
- DEVGUIDE: the wrap table, "Where things live", the naming example and the station rule follow; the crafting-window
  and craft-timer FAQ entries are gone.

## 0.1.48
- **A menu button in a window's button row** (user, session 72, `art/kraut_info_mock.png`): a button entry with `menu`
  (`{ { title, icon, enabled, tooltip, onClick } }`) opens its rows as a context menu under it on a click, in place of
  `onClick`; vanilla's combo box arrow (`media/ui/ArrowDown.png`) at its right, the button wider by it. A disabled row
  is refused with its reason, as a station menu's. First used by the Kraut Barrel's Take Sauerkraut (n) / Take Sauer
  Turnip (n), each opening One / All (n).
- **A counts line under a holding** (`counts = { { icon, count } }`; user, session 72, `art/kraut_spiked_mock.png` B):
  small icons a line high, each with its count beside it, as the holding's last line; the column widens to fit it.
  First used by the Kraut Barrel's apples and carrots.

## 0.1.47
- **A starter's slot in Holds** (`kind = "slot"`; user, session 69, `art/starter_path_mock.png`): a 34 px square left of
  its tank with an arrow into it, or right of it with an arrow out (what comes back). Looks: empty (dashed, the icons
  greyed: what it takes), in (bright), pending (greyed in a solid frame), ready (bright in a green frame); a count at
  its foot's right; two icons split on the diagonal (`DrawSubTextureRGBA`, a row at a time). It takes a drag (`drop`,
  as a tank), a click (`click`) and a right click (`menu(context)`); `DropZone.placeTarget` takes the two new
  handlers, a target may take clicks alone. An arrow to or from a slot is `SLOT_ARROW` long; any arrow takes
  `arrowColour`; a holding's name takes `nameColour`.
- A tank's heat bar stacks marks that come close (`Holds.heatLabels`): each tick at its heat, its text a line under
  the one above when they would overlap, hottest first (user, session 69: the pot's 45, 40 and 35 were drawn over
  each other); then every text sits `LEADER` further right with a thin slanted line from its tick to it
  (`art/heat_leaders_mock.png` A). Marks far apart (the cauldron's 85 and 100) stay as they were.
- `TPC.cauldron` refuses a fluid the game has no such fluid for ("Milk": it went in and was never milk to Dairy, so it
  never scalded) and arguments out of order, saying the right form.
- The station outline icon generator names the Culturing Pot's `TPStation_CulturingPot.png` (was YogurtIncubator).

## 0.1.46
- **The Craft row on items only mod recipes use** (`RecipeUI`): vanilla looks the recipes it lists up by bare name in
  module Base, so an item used only in TP's recipes (a ceramic jar) had no Craft row. Core adds vanilla's own row
  (same text, icon and crafting window filtered to the item) when vanilla left it out; one item or stack selected,
  as vanilla. No wrap.
- `RecipeUI.oneOrAll`'s All (n) counts every item type in reach: the context click's logic is manual select, which
  counted only the type each input was given (a glass Jar beside Ceramic ones gave 1, so no submenu).
- An Info window's list (rows, sort switch, tabs) hides when the window stops drawing it: taking the last piece off a
  shelf, floor, cloth, rack or Smokehouse left the rows and the sort switch over the notes.

## 0.1.45
- An Info window that resizes keeps its 12 px under the notes clear of vanilla's status bar at its foot (the bar
  covered it: the last note sat on the edge).
- An Info window refreshes as soon as the player's action starts or ends (a lay, a take, a pour), so the cells and
  rows follow a drag at once instead of on the next half-second refresh.

## 0.1.44
- **The Drying Cloth has room, not five lots** (as the Drying Frame has its weight): `DryingCloth.ROOM` 50, each kind
  registers `room` per piece, and `perLot` is now optional (most pieces in one lot; none, any number). A lay is
  one lot, as many as fit, with its own clock (`DryingCloth.lotsOf` splits by perLot); any number of lots while
  there is room. Five batches of yeast cakes or fifty kefir grains as before, now in any mix,
  and a single grain no longer takes a fifth of the cloth.
- The cloth's art keeps its five spots (`DryingCloth.SPOTS`): each shows the lot covering most of its fifth
  (`DryingCloth.spotLots`); a kind's `sprite(spot, state)`.
- Save: `tpcCloth` is `{ lots = { lot, ... }, nextId }`, a lot with an `id`; an older cloth's five slots are packed
  on first look. `DryingCloth.take` goes by id; `fits`, `roomUsed`, `lotRoom`, `lotById` added, `freeLots` and
  `LOTS` gone.
- Menu: Lay <kind> uses Core's One / All (n) rows (`PiecesUI.row`); the status line and Cloth Info's cells read how
  full the cloth is, the cells split by the room each kind takes; list rows lose their lot numbers. Laying takes
  about 5 s for each fifth of the cloth, as before.
- Cloth Info has **Take Done (n)** and **Take All (n)** buttons, as every window with a cell-style process (vanilla's
  Icon_Crafted and Icon_Returned; Take Done greyed says nothing is dry yet).

## 0.1.43
- `Container.fluidColour(name)`: a fluid's own colour, for any mod's tanks (was the cauldron's own, `CauldronFluid` now uses it).
- **A tank at work** (`working = { speed, foam }` on a Holds tank; the Fermentation Vessel's batch): bubbles rising
  through its liquid by the clock, `speed` times `Holds.BUBBLE_SPEED` (still at 0), and a foam cap on top.
- A Holds tank's `line = { share, text }` (a dashed line across, its text beside: the vessel's 16 L headspace),
  `working.spill` (foam running down its side) and `underColour`.
- `UI.shortDuration(hours)`: a wait in few letters for a state line under a tank ("<1h", "30h", "3d").

## 0.1.42
- **Bank and Stoke move into the fire's band** (user, session 67; `art/fire_toggle_mock.png`): one icon button by the
  fire's state, glowing embers for Bank the Fire while it is stoked, a flame for Stoke the Fire while it is banked,
  none while it is out, left of Light / Put Out. Stone Hearth Info loses its Bank / Stoke button row; Smokehouse Info
  gets the same pair for its joined hearth. Put Out the Fire's icon is vanilla's Metal Bucket of Water (`Item_MetalBucket_Water`), not the Extinguisher
  (`art/fire_icon_options_mock.png`, B1 with darker coals and P1).
- `InfoWindow:band` takes a list of buttons (`InfoWindow.BAND_BUTTON_GAP` between them); `FireUI.bandButtons`
  replaces `FireUI.bandButton`. Icons `TPIcon_Stoke.png` and `TPIcon_Bank.png` from `tools/fire_icons.py`.
- The Bank / Stoke refusal strings (FireIsOut, BankedAlready, BurningAlready) are gone with the buttons.
- **Stone Hearth Info gets the Station block** (user, session 67; `art/hearth_station_mock.png` A): the hearth's
  outline icon (its kind's `display.station`), Place as the place the fire makes round it, what a station beside it
  reads (by a fire lit, by banked embers banked, the air where it stands when out; `FireUI.placeAround`), and Season;
  its holdings get their Holds header back.

## 0.1.41
- **The Smokehouse's band** (`SmokehouseUI.band`; the module now returns `SmokehouseUI`): its joined Stone Hearth's
  fire as the hearth's own band, in its colours: Stoked (hot smoke and how long it burns), Banked (cold smoke on
  embers), Out (no smoke, the wood in it), with the hearth's Light / Put Out button acting on the joined hearth;
  grey No Fire with no button when none is joined. A mod may say the day is too warm for cold smoke
  (`tooWarm`): banked then reads "too warm for cold smoke". Tested in `test_smokehouse_band`.
- `FireUI.BANDS`, `FireUI.bandButton(window, fire)` and `FireUI.burnTime` are shared, so a window can show a fire
  that isn't its own; Stone Hearth Info uses them unchanged.

## 0.1.40
- **The Station block** (`InfoWindow:stationBlock`; user, session 66, `art/station_aligned_mock.png` H): the station's
  white outline icon, and at its right, in Small (Medium was too large in game), Place, **Season** (the series' season
  mean, "11°C avg outdoors", on every station) and the window's own rows; the icon and the rows centre on each other's
  height, and the icon stands on the first holding's centre line, the rows following it. Drying Cloth Info uses it.
- **Station icons** (`tools/station_icons.py`, `art/station_icons_mock.png`): a white outline of every station in the
  place icons' style, `TPStation_<Name>.png` at 64 px in the mod whose station it is (the Drying Cloth, Stone Hearth
  and Smokehouse here). Info windows only; the menus keep the item icons.
- **A piece list's block folds** (user, session 66, `art/fold_list_mock.png`; `InfoWindow:pieceListBlock`): an arrow
  before its header, the line lit on hover, a click folds or opens it; folded, the header keeps the count
  ("HANGING (20)") and the buttons move up. Each station type keeps its fold beside its width in the player's
  `TraditionalPreservationWindowWidths.txt`; open by default. Drying Cloth Info uses it.
- A window's piece list shows three rows before it scrolls (was five), rows with a line under the bar (the
  Smokehouse's smoke) as whole rows too.

## 0.1.39
- **Patterned cells** (user, session 65; `art/all_cells_mock.png`): a cells holding can be drawn in a pattern of what it
  holds in place of a flat colour (`pattern`, a texture), and a mixed one by share (`parts`, `Holds.byShare`: each
  part there gets a cell, the rest by weight, the cells left to the heaviest first, the heaviest at the bottom). A
  drag's see-through cells take the judge's `pattern`. The Stone Hearth's wood is drawn in plank grain, the Drying
  Cloth's lots in each kind's pattern (a kind registers `pattern`). `tools/cell_patterns.py` makes every mod's
  `TPCell_<Name>.png` (palette B, darker: one family each, wood vanilla's red-brown, one jar a cell on its side;
  big fish scales, marbled meat and long sausage links, as small marks read as a mesh or as wood at game size).

## 0.1.38
- An Info window's button row can shrink: `buttonRow` with fewer buttons than last time hides the rest, and the
  window's update keeps them hidden (it showed every button it had made, so a hidden one flashed on and off).
  `InfoWindow:showButtons`. Salting Tub Info's buttons change with its stage.

## 0.1.37
- Drying Cloth Info on the settled look (`art/all_info_mock.png`): a state band under the title (EMPTY grey, DRYING
  or DRY green, WAITING amber for still air or frost, TOO HOT or LOST red, the worst first), a Station block with the
  place, the lots as five cells under Holds with the cloth's lore beside them (1800s hop yeast dried into cakes with
  Indian meal), then a piece list a lot: its icon, name, a warning in amber (Still air, Too cold, Too hot), the bar.
  The window resizes in width as the other list windows.
- InfoWindow: a block's header has no lead line before its name (`HOLDS ------`); band colours by meaning,
  `BAND_WORKING` green, `BAND_WAITING` amber, `BAND_AT_RISK` red, `BAND_IDLE` grey; `pieceListNamed` for a list
  whose header line is finished text. The Place block's header reads "Station" (`SectionStation`).
- **Place icons** (user, `art/place_icons_mock.png`): white outlines of our own beside the Place row, one a place
  (the sun, a roof on posts, a house, a gust for an aired room, steps down for a basement, the Smokehouse, a flame,
  banked embers; a fire's place shows the fire). `tools/place_icons.py` draws them (`TPPlace_<place>.png`);
  `InfoWindow:placeRow(y, label, place, celsius)` draws the row, `UI.placeIcon(place)` picks the icon, and
  `drawRow` takes an icon.
- **Drag onto the cells** (user, `art/place_drop_mock.png` B): a cells holding takes `drop = { judge, drop }` as a
  tank does, in place of a drop square; while dragging, the cells it would fill show see-through (judge's `cells`).
  The Drying Cloth takes its lots this way: what is dragged is grouped by kind into lots as the menu lays them, the
  rest refused with what the cloth takes.
- Temperatures in the game's text read with the degree sign ("17°C (Aired room)", was "17 C").
- DEVGUIDE: every window opens with a state band; its colours by what the state means; the Place row with its icon;
  a list window's cells take the drag.

## 0.1.36
- Piece lists draw rows as in `art/all_info_mock.png`: a 32 px icon, the name in bold, a warning (new `warning` field)
  right-aligned in amber, the bar the row's width under them, the line under the bar as before. A name is cut with
  "..." only when the warning needs the room. Five rows show before the list scrolls (was eight).
- The bars in a piece list no longer jitter: vanilla's `clear()` keeps the list's scroll height and `addItem` adds to
  it, so each refresh drew one frame with a scroll bar and every bar narrower. The list resets it before refilling.
- A window with a piece list resizes in width only, 400 to 680, from its corner, and opens at the width last given a
  window of the same station type (kept in `~/Zomboid/Lua/TraditionalPreservationWindowWidths.txt`, not the save).
- A disabled button draws its icon faded; vanilla draws it at full alpha.
- `TPC.pieceList(n)`'s sample rows show warnings.
- Guide 6: a list window widens from its bottom-right corner and opens that wide next time.

## 0.1.35
- The Drying Cloth's window row reads "Drying Cloth Info" (was "Cloth Info"), its title "Drying Cloth"; DEVGUIDE: a
  window row is "<the station's full name> Info", as vanilla's Fireplace Info, and its title the bare name.
- An Info window's block header has a short hairline before its name as well as after (`-- HOLDS ------`).
- A tank can show what has settled out at its foot (`settled = { share, colour }`): a layer under the fluid, at least
  3 px tall so a little still shows; the fluid stands on it.
- **Drag containers onto the cauldron to pour them in** (user, `art/pan_drag_mock.png` option 2): the cauldron's tank
  and heat bar are a drop target in Stone Hearth Info. While a selection is dragged over it, it gets a white frame
  (orange when it takes some, red when none), the pour shows see-through in the tank as vanilla's fluid bar shows what
  is added, and a hint by the mouse says what it would pour or why not. Each container is tried on a copy of the
  cauldron by the pour itself, so the drag takes and refuses just what Pour into the Cauldron would; on release the
  player walks over once and pours each. A note says so while there is room. Any holding takes one: `drop = { judge,
  drop }` on a tank (DropZone.placeTarget, a target that draws nothing itself).
- The salt pan's tank no longer jiggles a pixel as the brine boils past saturation: the fluid's top is rounded once,
  not the salt and the brine apart.
- Stone Hearth Info's band reads STOKED (not LIT) for a fire burning at full.
- Stone Hearth Info has no Holds header: the wood (and what is fitted) sits right under the band.
- **A heated tank carries its heat as a thin bar beside it** (user): its top level with the tank's, a line short, its
  temperature ("62°C") centred under it, ticks at 85 and 100; the name, litres, fluid and "steaming" / "steams in" are
  centred under tank and bar as one (`heat = { celsius, marks }` on a tank, an `under` line). The cauldron's separate
  thermometer column is gone; `FireUI.heat` became `FireUI.heatOf(celsius, steams)`.
- **The lore goes beside the holdings**, not only beside a lone holding: the window widens to give it at least 140 px
  (a long fluid name such as Cow's Milk (Scalded, Fresh) makes the cauldron's column wide), and only past 680 is it
  left out. The Stone Hearth's curfew line now shows with the cauldron or the salt pan fitted too.

## 0.1.34
- **UI pass, first part: the rules in Core's InfoWindow** (session 61's rules). Every Info window: padding 12 on a
  4 px grid, 400 wide (wider when what it holds needs it, up to 680), the label column as wide as its longest label,
  bars 18 px with their text inside, or under the bar when it doesn't fit. New blocks: `section` (a small grey header
  and a hairline), `band` (a coloured strip under the title for a state at a glance, an icon-only button at its
  right) and `holds` (new `Holds.lua`: what a station holds standing up, packed from the left in flow order: fluids
  as tanks with vanilla's fluid gradient, anything else as a column of cells the same size as a tank, heat as a
  thermometer coloured by its heat with marks; an arrow with its rate between). A lone holding with lore
  (`holds(y, holdings, lore)`) has a line of real-world history beside it, in the game's serif italic with a rule at
  its left. Names under holdings are bold (Small drawn twice a pixel apart). Buttons are as wide as their text, take
  an icon, and wrap onto a new line. The drop square is 56 px with an icon of what it takes, its border white when it
  takes everything.
- **Stone Hearth Info** is the first window on the new rules: a band under the title, red lit, orange banked, grey
  out, with how long it burns, and at its right the game's Lighter for **Light the Fire** (vanilla's light menu
  opens under it, as the loot window's Light does) or its Extinguisher for **Put Out the Fire**; then Holds (the wood
  as five cells of 12 hours; with nothing fitted, the curfew bell's lore beside it; fitted, the cauldron as a tank and
  its heat as a thermometer with 85 steam and 100 boils); then **Bank the Fire** and **Stoke the Fire** as buttons
  (the one that can't work now says why); then the notes.
- Internal: `Fire.attach` takes `holds(fireView, holdings)`; `FireUI.heat(celsius, state, steams)` makes the
  thermometer for any attachment; a fire kind's display takes `lore`. Unused texts gone (the Fuel and Steaming rows').
  New test `test_holds.lua`.

## 0.1.33
- **`UI.confirm(playerObj, text, onYes)`**: a yes or no box before a menu row that loses something for good (vanilla's
  `ISModalDialog`, as for killing an animal; a controller's focus moves to it). First use: Vinegar's Pour Away the Batch.
- DEVGUIDE: the station rule and the wrap table without the Fermentation Vessel's crafting window (Vinegar 0.2.42).
- Guide: every station but Salt's Leaching Vat has an Info window now.

## 0.1.32
- **One and All on a vessel's recipe row** (user, for Yeast's pots of Potato Water and Hop Tea): `RecipeUI.oneOrAll({
  recipe, fluid, litres })` turns vanilla's right-click Craft row for a recipe that takes `litres` of `fluid` from the
  clicked vessel into a submenu, **One** (vanilla's own craft) and **All (n)**, n the crafts the vessel's fluid covers,
  capped by what the rest in reach allows (vanilla's craft count). All makes them one after the other from that
  vessel, each started as vanilla's row starts one, and stops when the next can't be made. With one craft's worth the
  row is left as vanilla's. The crafting window's own count is unchanged. test_recipe_menu.
- **DEVGUIDE: "How a recipe takes a fluid"** (series recipe audit, 2026-11-19): the three ways the series writes a
  fluid input, the receiving jar, clean or tainted water, `CanBeDoneFromFloor`, and the game's jar names.

## 0.1.31
- **Tabs in the piece list** (ROADMAP section 12; user, session 55): `InfoWindow:pieceList` shows a row of tabs under
  its header, All and one for each process on the station with its count ("Salt Fish (4)"), wrapping onto more lines
  as needed; none with a single process. A row names its tab (`tab`, ordered by `tabOrder`); each window opens on All
  and keeps its own tab, back to All when that tab's last piece goes. The By process sort is gone (the switch keeps
  Furthest along and Least along); rows no longer need `group`. `TPC.pieceList()` shows the tabs.

## 0.1.30
- **The Smokehouse is off CraftLogic** (ROADMAP section 12, S4): no crafting window (UiConfig `uiEnabled = false`), no
  slots or recipe tag; what hangs inside is each mod's own record on the back left tile. The door look counts finished
  pieces only (`Smokehouse.pieceSprites(face, part, col, finishedPieces)`); `Smokehouse.slotTile`,
  `Smokehouse.RECIPES`, `Smokehouse.STACKS` and `STACKS_A_PIECE` are gone. The build tooltip says pieces.

## 0.1.29
- **For the Smokehouse's menu** (ROADMAP section 12, S3): `Smokehouse.redraw(tile)` redraws every tile of the shed
  now (was the flue's own local), so a mod taking a finished piece off updates the door look at once.

## 0.1.28
- **The Smokehouse's build** (ROADMAP section 12, item 5): Woodwork 5 and 2 Large Hooks with the 14 planks and 20
  nails (was Woodwork 3), between the Hanging Beam's 4 and the Gantry's 6; `TPC.kit("smokehouse")` gives the hooks.
- **For the Smokehouse's move off its crafting slots** (S2): `Smokehouse.recordTile` (the back left tile, where a mod
  keeps its record of what hangs in the shed), and `Smokehouse.countsFinished(fn)` / `finishedPieces`: each mod's
  count of finished pieces adds a door look each (up to three), beside the slots' stacks.

## 0.1.27
- **Items move into the inventory before the walk** (user, session 53; vanilla's order, and more natural): the Drying Cloth and the cauldron's rows (`PiecesUI.queue` takes a walk step, run after the move) move what they need from a crate or a bag first, then walk, then act, so a crate left behind can't cancel the queue. `UI.walkTo` walks keeping the queue (vanilla's `walkAdj` and `WalkToEntity` clear it first, which dropped the moves). The test harness's walk now clears the queue as vanilla's does, and counts it (`ui.cleared`).

## 0.1.26
- **A row of buttons for info windows** (`InfoWindow:buttonRow`): buttons across the window sharing its width, each
  `{ title, enabled, tooltip, onClick }`, kept and set anew each draw. `test_button_row.lua` new.

## 0.1.25
- **The drop square has three colours** (user, session 53): green when it takes everything dragged, orange when it
  takes some and refuses the rest, red when it takes nothing. `test_drop_zone` checks each.

## 0.1.24
- **A drop square for info windows** (`DropZone.lua`, `InfoWindow:dropZone`; user, session 53, mock
  `art/rack_drop_mock.png`): an always-shown square under a station's list that takes a selection dragged from the
  inventory or a loot window. Held over it, it turns green with what would happen (and "some items will be
  rejected" when not all would go) or red with why not; on release the station takes what it takes, and the rest's
  reason shows over the player. `test_drop_zone.lua` new.
- **Info in the main menu too** (user, session 53): every station's Info row is also at the bottom of the main right-click menu, besides its submenu (TP Core's `UI.topInfo`). The Stone Hearth (Cauldron) and the Drying Cloth have it.

## 0.1.23
- **Info windows open from the right-click menu only** (user, session 53): a left click on a station is vanilla's again, as for every vanilla workstation (a container opens its loot window). `InfoWindow.clickOpens` and its wrap of `ISObjectClickHandler.doClickSpecificObject` are gone; the Stone Hearth's left click opens only its loot window, the Drying Cloth's nothing. Docs and TESTING 9b, 9c, 27j updated.

## 0.1.22
- **The list sorts by process too**: the switch's third choice, *By process*, groups the rows by their process
  (a row's `group`, by name; every row needs one), furthest along within each. `TPC.pieceList` gives its sample
  pieces processes.

## 0.1.21
- **A scrolling list for info windows** (`PieceList.lua`, `InfoWindow:pieceList`), the first step of moving the
  CraftLogic workstations onto info windows: one row a piece (icon, name, a bar with its text, an optional line under
  the bar), at most 8 rows shown before it scrolls, a sort switch (*Furthest along* / *Least along*, one choice for
  every list) and each row's popup on hover, drawn like a crafting slot's. No station uses it yet.
- **Console:** `TPC.pieceList(n)`, a sample window with made-up pieces to check the list in game.
  `test_piece_list.lua` new; test_console checks the command.

## 0.1.20
- **The Drying Cloth** (2026-11-19): a Sheet spread on the floor with 2 Stones on its corners (Build menu, Furniture),
  where things dry by the air of their place. Five lots, each what one lay put down, of one kind; the kinds belong to
  the mods, which register them (`DryingCloth.register`: Yeast's cakes, Dairy's kefir grains). A lot dries on a
  FluidAgeing age on the cloth's own ledger (`TraditionalPreservationCoreCloth`), so time counts while the cloth is
  unloaded; it waits in a shut room's still air (the series' rule) and as its kind's curve says in the cold; a kind may
  die past a heat (`killAbove`, an hour there), or go off before it dries (`goesOff`, the earlier of the two wins;
  Cloth Info: *Gone off*). Right-click: *Lay <kind> on the Cloth* (One Lot / All), *Take Off the
  Finished Lots*, *Take Everything Off*, **Cloth Info** (also a click on the cloth): the place, a bar for each lot. A
  cloth with anything on it can't be picked up, and none goes down in front of a door. The lots are the object's
  modData `tpcCloth`. Tiles 100 and 101 (`tools/cloth_art.py`, which also gives mods `lot_spot` for their overlays).
- **InfoWindow:barNamed**, a bar with a label not from a translation key.
- **PlaceKeeping keeper.addAgeing**: a second ageing curve on a keeper's ledger (Yeast's cakes on the cloth); the
  ledger fills totals for every process once a game.
- **Console:** `TPC.kit("cloth")`, `TPC.cloth()` (each cloth near you: place and every lot) and `TPC.dryCloth(hours)`
  (dries the wet lots near you). `test_drying_cloth.lua` new; test_console checks the new commands.

## 0.1.19
- **An empty doorway airs a room** (2026-11-19, from the long save: a door broken off read shut): a door frame on an
  outside wall (the DoorWallN / DoorWallW flag on the square that owns the wall) with no door in it lets air in. A shut
  door in the frame still shuts it. One more call, only on an outside wall with no window or door letting air in.
- **`TPC.windows()` updates the room's answer** (2026-11-19, from the long save: `TPC.windows()` said shut while
  `TPC.here()` still said aired). A room's answer is kept for the ten-minute reading, so a door shut a moment ago still
  read open; the fresh scan now replaces the kept answer, and `TPC.here()` and the stations agree with it at once.

## 0.1.18
- **An open outside door airs a room too** (2026-11-19, user): a door open to the outside, and not barricaded, counts as
  an open window does (`getDoorTo`, one more call on an outside wall with no window letting air in). A map door or a
  built one; a door into another room doesn't count, as the scan asks only walls to the outside. A door broken off
  (an empty doorway) isn't seen yet: to check in game.

## 0.1.17
- **A lighter window scan** (2026-11-19; the series must never cost a game its frame rate). Each outside wall is asked
  through the game's own lookups (`getWindowTo`, `getWindowFrameTo`, `getWindowThumpableTo`: one call each, either side
  of the wall) instead of a loop over everything on the square; each square carries its coordinates through the walk.
  At most **150 squares** a room (`Windows.MAX_SQUARES`, was 400). **A frame budget:** at most one scan in 20 real
  milliseconds (`Windows.SCAN_GAP_MS`); a room due inside it keeps its last answer (shut, if it has none) until its
  next look. A room is still scanned at most once a ten-minute reading.
- **`TPC.windows()`**: scans the room you stand in and prints aired or shut, the squares read, the outside walls, about
  how many engine calls and the milliseconds it took. Guide 6 and DEVHELP list it.

## 0.1.16
- **Fix: the window scan failed in game** (2026-11-19, seen in console.txt at the first load: "Object tried to call nil
  in onEdge"). It asked every object on a wall's square which edge it stands on, and a wall, the floor or an item has
  no `isNorth`. `Windows.lua` now asks only a window, a window frame or a built window. The tests' squares carry a wall,
  an item and a built door beside the window, as in game.

## 0.1.15
- **The aired room and new place temperatures** (2026-11-19, ROADMAP section 10, simulated in every mod's season tool
  first). Five places: Open, Covered, Sheltered (a shut room), **AiredRoom** (*Aired room*, new) and Basement; **the
  loft is gone**, its summer heat too. An aired room is a room with a window to the outside open, smashed, without its
  glass or an empty frame, and not barricaded: the new `Windows.lua` walks the room's squares (a map room by its room
  id, a built one by its world region) and reads the windows on its outside walls, because `IsoRoom:getWindows()` is
  never filled (ENGINE_NOTES). A room's answer holds for the ten-minute reading, then is read again.
- **Temperatures:** under an open roof is the hour's air, as outdoors (it was the ten-day season mean, which made a
  porch 3 C warmer than outdoors in January and warmer in August). A shut room follows a three-day mean
  (`threeDayTemperature`, `Weather.ROOM_HOURS` 72), +2 C from a 10 C mean down to none at 18 C as before, and now
  **stuffy in summer**: up to +2 C from 18 C to 21 C (`ROOM_SUMMER_LIFT`, `ROOM_SUMMER_FULL`). An aired room follows a
  one-day mean (`dayTemperature`, `AIRED_HOURS` 24), at most +1 C in winter (`AIRED_LIFT`). Both are 22 C on the grid.
  The basement is unchanged. Month means, Jan: open -4.6, aired -3.4, shut -1.8; Jul 20.9 / 20.9 / 21.9 (+2 at 21 C).
- **The Smokehouse has an aired room's air** (`Smokehouse.AIR` = AiredRoom: the day's mean, up to 1 C over in winter),
  never warmed by the grid (`Weather.STATION_PLACES` reads its air off the grid). It borrowed the open roof's, which
  now follows the hour; a plank shed with a vent damps the afternoon peaks, as 0.1.14 meant.
- Windows: a room's answer is kept for the ten-minute reading only (every room's answers start over each reading).
- By a fire in an aired room: its air +15 C lit, +10 banked (`Fire.FIRE_LIFT`, `EMBERS_LIFT`), as under a roof;
  *By a fire, aired room*, *By banked embers, aired room*. A shut room by a fire is still 28 / 24 C.
- Autumn indoors is harder (a shut room no longer coasts on summer for ten days): a fire indoors is the answer.
- Ledgers copy the new means from the series' weather; a save from before reads the season in a shut room and the hour
  in an aired one until its first reading. Old `...Loft` totals are left unused.
- Tests: `H.shutRoom(square)` in the harness gives a fake square what the window check asks. Golden results: Fish &
  Meat, Dairy, Yeast, Vinegar and Fruits and Vegetables.

## 0.1.14
- **Five places: Enclosed is gone** (2026-11-19). It was only ever the inside of the Smokehouse, and it read the day's
  temperature while an open shed (Covered) reads the season's: a closed shed lags the weather at least as much.
  `Weather.PLACES` is Open, Covered, Sheltered, Loft and Basement, every one a square's. Inside the Smokehouse is a
  station's word, not a place: `Smokehouse.PLACE` ("Smokehouse", *In the Smokehouse*), its air Covered's
  (`Smokehouse.AIR`) through the new `Weather.STATION_PLACES`, which `Weather.placeTemperature` reads. The ledgers keep
  no totals for it (an old save's `...Enclosed` totals are left unused). The place word `PlaceEnclosed` ("In a shed")
  is `PlaceSmokehouse` ("In the Smokehouse"). Golden results: Dairy's and Yeast's season reports lose the shed.

## 0.1.13
- **The Smokehouse is 2 x 2** (2026-11-19, a new look only: the same 6 stacks, recipe, places and rules). A plank
  shed on four tiles under a low pitched roof, its ridge from the door end to the back; the door end a gable with a
  pair of plank doors and a sooted galvanised louvre vent (preview `WIP/TPCore/art/smokehouse_2x2_mock.py`, from the
  user's reference photos). Painted whole and cut into tiles by footprint in the new `tools/smokehouse_tiles.py`;
  tiles 76-83 (`Tiles.CHAMBERS`, each face column by column, back row first), entity `Smokehouse_Chamber` two rows of
  two. **Old 2-tile Smokehouses are not kept** (tiles 32-35 and the ham 44-45 left empty): empty one before updating
  and replace it.
- `Smokehouse.tileOf` gives the facing, row (part) and column; `chamberTiles` all four, each where its own row and
  column say (a shed next door is never taken); `stepTo` (was `otherStep`); `sideAllowed(face, part, col, dx, dy)`: any
  outer side but the door's end. Both front tiles keep their front free (Doors). The flue's entry overlays are
  unchanged, on the column in view.
- **What hangs by the door** (`Smokehouse.pieceSprites`, was `readySprite`): a piece for every two finished stacks,
  counted by their `stackId` (`Smokehouse.STACKS_A_PIECE`): a country ham (shorter and fuller than the old ham) on the
  front-left tile, then a smoked chicken and a smoked rabbit on the front-right one, each with a shadow on the boards
  (`Tiles.CHAMBER_PIECES`, `CHAMBER_PIECE_COLUMNS`).
- **Smoke from the vent** while the joined Stone Hearth burns (`Smokehouse.smokeLook`, `smokeSprite`): a plume stoked,
  a wisp banked, static as the cauldron's steam, over the two front tiles (`Tiles.CHAMBER_SMOKE`).
- `TPC.smokehouse()` names each tile's row and column and the smoke. test_smokehouse, test_smokehouse_world. README,
  guide 6, Workshop text, tooltip, DEVGUIDE.

## 0.1.12
- **`UI.durationText(hours)`** (2026-11-19): a long wait as text, whole hours up to two days (`UI.DAYS_FROM_HOURS`), then "about N days" to the nearest day; Fish & Meat's Tub Info reads "Cured in about 21 days" instead of 504 hours. test_station_info. DEVGUIDE.

## 0.1.11
- **Kept food and fluids read the fire places** (2026-11-18): whatever keeps by place (Fish & Meat's Potted Meat, Dairy's butter and milk, Fruits and Vegetables' crops and their cures) now counts by a fire (28 C) or by banked embers (24 C), less under a roof or in the open, as the stations do. `FluidAgeing.placeOfItem` asks `Fire.placeOf` of whatever holds the item (a crate, the floor, the player, a vehicle; a powered fridge or freezer still comes first) and returns the fire and the holder too; one answer a square and hour, so a crate is scanned once. Each look notes the fire's fuel on the item's clock (`FluidAgeing.noteFire`: `fireUntil`, `placeWithoutFire`); `FluidAgeing.advance` counts a stretch by a fire by the clock at its heat while that fuel lasted, the rest at the place under it by its share (as `Fire.catchUp`), and takes a station's own note (`fireNote`). Before, a fluidAge by a fire counted nothing (the ledger keeps no totals there). test_place_keeping. DEVGUIDE.

## 0.1.10
- **Fix: a full bucket of brine fits in the Stone Hearth's fire box** (2026-11-18): the bare Stone Hearth's fire box held 10, and a full metal bucket of brine weighs 11, so Salt's boil on the Stone Hearth refused a full bucket (*11/10*). It now holds 15 (`StoneHearth.FIREBOX_CAPACITY`), as the cauldron's tiles already did: one full bucket, not two. The game saves a container's capacity with the object, so a kind of fire can name its `fireboxCapacity` and FireWorld raises a fire built with less the first time it looks at it; Stone Hearths already built are fixed in place. The tiles' `ContainerCapacity` is 15 for new ones (`tools/build_tileset.py`; the art is unchanged). test_fire_world. DEVGUIDE.

## 0.1.9
- **The Stone Hearth takes 12 Clay** (2026-11-17), was 2: 12 Stone Blocks laid in clay need more than two lumps of mortar. `TPC.kit("stone")` and `TPC.kit()` give 12 (test_console). README (its heading also read 0.1.7, now 0.1.9), guide 6, DEVHELP, Workshop text.

## 0.1.8
- **A mod's own attachment tiles** (2026-11-17, for Salt's salt pan): `StoneHearth.fittedTiles(id, sprites, faces)` makes an attachment's whole-hearth tiles, in its mod's own tileset, Stone Hearth tiles: tracked as fires, their facing and door known, and shown with that attachment fitted when put down with nothing noted (`StoneHearth.fittedFace`, `StoneHearth.fittedByTile`). The cauldron's tiles go the same way; nothing changes for it. An attachment's `removeText` (client) gives Remove's hover for its own refusals; any other still reads "Empty it first". test_fire. DEVGUIDE.

## 0.1.7
- **The Stone Hearth is built of stone** (2026-11-16): 12 Stone Blocks (vanilla's cut mason blocks, as its tiles draw it), 2 Clay and a mason's trowel kept, Masonry 2; was 8 Clay Bricks, which matched neither its look nor its name. `TPC.kit("stone")` and `TPC.kit()` follow (test_console). README, guide 6, DEVHELP, Workshop text.

## 0.1.6
- **Fix: a new save's weather no longer starts at 0 C** (2026-11-16, `Weather.weatherModData`): the series' weather took its first reading on first use, and a new save first uses it as the mods load (`OnInitGlobalModData`), before the game's climate has run, when it reads 0 C and 0 humidity. The season's mean, the ground's and the humidity started at 0 and took weeks to catch up, so basements, sheds and the open read as winter in July. It now starts only once `ClimateManager:isUpdated()`, otherwise on the first ten-minute reading. test_core: a new check; every test's climate stand-in answers `isUpdated`.

## 0.1.5
- **`Loot`** (2026-11-16, `server/TraditionalPreservationCore/Loot.lua`): `Loot.add(fullType, { listName = weight })` puts a mod's item into vanilla's loot lists, skipping a list the game doesn't have. Salt's Bag of Salt and Dairy's kefir grains use it in place of their own copies of the loop. The test harness finds Core's server modules and stands in for `Items/ProceduralDistributions`. test_loot. DEVGUIDE: the module, and `server/<Mod>Loot.lua` in the mod layout. Nothing changes in game.

## 0.1.4
- **Fix: the cauldron no longer renders what had already gone off** (2026-11-16, `CauldronFluid.advance`): a long catch-up counted every hot hour before checking the going-off hour, so raw fat or butter due to go rancid partway through its hour of steaming came out rendered in one look, and rancid when looked at every ten minutes. The stretch is now split at the going-off hour, while the fire burns and while the cauldron cools after it, so one look and many agree. test_fire: three new checks.
- **Fix: a fluid's change of state no longer loses the time until the next look** (2026-11-16, `FluidAgeing`): a state with its own ageing process (Fish & Meat's Cured blood) was marked on the old process after treating, so everything up to the next look was dropped, not one look's worth: blood cured on the floor and left unviewed did not age. Every change of state (treat, untreat, scald, a pour that merges, a fluid found already in a state) now re-marks at once, on the process it ages by. test_fluid_ageing: the old "loses one stretch" check now expects the stretch counted, plus three new checks.
- README header shows the right version.

## 0.1.3
- **Dairy's kefir grains on the core's ageing** (2026-11-16): Dairy 0.0.5's grains starve and dry on `FluidAgeing` ages and are looked at through `PlaceKeepingUI.watch` (any table with `keep(item)` serves as a keeper); Dairy's season report golden gains the grains' ledger totals, nothing else in it changes. FluidAgeing's header names scalded milk by its name now, Cow's Milk (Scalded, Fresh). Nothing changes in game.

## 0.1.2
- **Naming sweep** (2026-11-16): every name says what the thing is in game, by DEVGUIDE "How code is named" (new). The station tracker's table is `sessionState`, a station `station`, any world object `isoObject`; a registered fluid is a `fluidKind` (was `spec`), its age a `fluidAge` (was `record`), the ledger's kind of work a `process`; saved tables are `fireModData`, `stationModData`, `weatherModData`; the craft clock's keys are `workHours`, `marks`, `placeWithoutFire` and the Smokehouse stack's `hotSmokeHours`, `coldSmokeHours`, `hotSmokeCoolHours`, `hotSmokeHoursNeeded`, `noHotSmoke`; windows keep a `fireView` / `stationView`. `TPC.flue(kitName, side)`. `tp test`: the Wrap lint's in-place check runs only on mods that require TP Core (FuelBarrel never does). Tests and golden results unchanged; nothing changes in game. Pre-release: an old test save's stations read as new, so test on a fresh save.

## 0.1.1
- **`Wrap`: every vanilla wrap, late and guarded** (2026-11-16). `Wrap.method(owner, name, handler)` puts a wrap in once every mod's Lua has loaded (OnGameStart; OnGameBoot on a dedicated server), so a mod that replaces the same function as its files load is wrapped too instead of wiping TP's out. In normal play a failing TP handler lets vanilla carry on and prints the error once; vanilla's own call and other mods' versions are never inside the guard. Debug mode runs bare, full traces. Every Core wrap is on it (Handcraft, Drink, Pour, Portions, Transfer, Placement, InfoWindow, ChargeUI, StationInfo, UI, FluidAgeingWorld, FireUI, FireLootControls); SlotRules is one wrap a function with each mod's rules as layers, and `UI.craftRefusal` adds a Craft refusal as a layer (Vinegar's vessel). `tp test` fails on a vanilla function replaced in place and on one wrapped twice in the series. README "Compatibility" lists every wrap. test_wrap.
- **Translation keys checked, refusal keys as constants** (2026-11-16): `tp test` and `tp install` fail on a translation key written whole in a mod's Lua that no EN file has (the mod's, TP Core's or the game's, found under `TP_GAME`). The keys a shared function returns are tables on their modules: `FluidTreat.REFUSALS`, `Season.REFUSALS`, `FireConnect.REFUSALS`, `Smokehouse.REFUSALS` (DEVGUIDE "Translation keys"). Same keys, nothing changes in game.

## 0.1.0
- **One or All, and one action for pieces** (2026-11-16): a row that puts pieces in as a fluid (Put Fat and Put Butter in the Cauldron, Put Butter in a Pot) opens **One** (the piece nearest to going off) and **All (n)** when more than one fits; with one it puts it straight away. Before, every piece carried went in. The cauldron's `TPCauldronPieces` and the pot's action are one, **`TPPutPieces`**, which takes a destination (`Cauldron.piecesInto`, `ItemFluid.piecesInto`); the rows are **`PiecesUI.row`**. All puts the oldest first.
- **`ItemFluid`: fluid that changes in a pot** (2026-11-16, for Dairy's butter in a pot). The cauldron's fluid rules for an item: a mod names what **turns hot** (`turnsHot(from, to, hours)`: kept steaming, the item's heat at `CauldronFluid.HOT_C` or more), what **goes off** (`goesOff(from, to)`, by the clock from its oldest piece), what **burns** (`burns(fluid, hours, mapper)`: kept steaming that much longer, the vessel is emptied and swapped where it lies for its burnt item, condition kept; a vessel the mapper doesn't name never burns) and what **stays in** (`staysIn(name)`: no pouring or drinking while it holds it, vanilla's `canPlayerEmpty`, so raw pieces keep their clock in their vessel; it can always be thrown away: **Empty** in the item's Fluid menu, the action **`TPEmptyFluid`**, as vanilla's own Empty refuses a sealed container). The record is `tpItemFluid` in the item's modData. Looked at every minute on the heat near a player, every ten minutes on the player, as a loot window shows a container and as an item is moved (`ItemFluidWorld`, `ItemFluidUI`). **Put Pieces in a Pot**, shared: the menu row **`ItemFluidUI.addPieces(spec)`** on a piece's right-click menu, a row per pot or saucepan in reach. **`Action.replaceItem(old, new)`**: puts an item where another is, in a container or on the ground (moved out of Salt's brine). test_item_fluid; the harness's given items take `setBurnt`.
- **`PlaceKeepingUI.near(types, reach)`** (2026-11-16): kept items carried and in containers within 4 tiles on the player's floor, for the consoles. Fish & Meat's `TPFM.crocks` search moved here; Dairy's `TPD.butter` and `TPD.rancid` use it, so they see butter in a fridge or freezer (they saw only carried butter). Nothing changes in game. The console line for a kept item with no ageing (a freezer) reads *keeps forever here* (was *0 days fresh here*). test_place_keeping.
- **`Drink` and `Cooldown`** (2026-11-16, for Dairy's kefir). A fluid script's `foodSicknessChange` never reaches the drinker (the engine leaves it out of what a drink carries; ENGINE_NOTES). **`Drink.cure(fluid, { foodSickness, cooldown, hours })`** registers a fluid that eases food sickness, so much a litre drunk, only while the drinker has some, as vanilla's food; the one wrap of **`ISDrinkFluidAction.updateEat`** measures the litres drunk. **`Cooldown`**: named cooldowns in the player's modData (`tpCooldowns`, world hours: `ready`, `start`, `left`), for any mod; a cure with one acts only if its key has run out as the drink starts, and starts it. test_drink. The test harness stands in for vanilla's drink action.
- **`PlaceKeeping`** (2026-11-15): food that keeps by place, moved out of Fish & Meat's Potted Meat so Dairy's butter shares it. `PlaceKeeping.new(spec)` gives a keeper (its curve, ledger, modData clock, sandbox switch and, for an item whose script never spoils, the days to set on it): `keep`, `rate`, `record`, `age` and `describe` for the consoles. **`PlaceKeepingUI.watch(keeper, types)`** looks at those items hourly on the player, as the inventory windows show a container, and as one is moved. test_place_keeping.
- **Pieces into the cauldron, shared** (2026-11-15): `CauldronFluid.pieceRoom` and `CauldronFluid.putPieces` (pieces that go in as a fluid and go off by their oldest), the action **`TPCauldronPieces`** and the menu row **`CauldronUI.addPieces(spec)`**, moved out of Fish & Meat's Put Fat in the Cauldron so Dairy's Put Butter in the Cauldron shares them (the row can be refused for a skill). Fat behaves as before.
- **`Recipes.addItems`** (2026-11-15): widens a recipe's item line at load, as `addFluids` does a fluid line, so a mod's recipe takes another mod's item only when that mod is on (Fish & Meat's Potted Meat and Dairy's Clarified Butter). test_recipes.
- **Guide** (2026-11-15): 60 L of water boils clean in about 3 hours (was 3¼; the code gives 3 h 10 min). Nothing changes in game.
- **Guide shortened** (2026-11-15): repeats cut (the Notebook's cost table, four tips, a history margin note); the Stone Trench takes an Entrenching Tool too, as the code does; `TPC.warmth` says the Stone Hearth's heat (guide and console help). Nothing changes in game.
- **DEVGUIDE and README say what is** (2026-11-15): no dates, version tags, step labels or pointers to private notes; `tp` described with `TP_MODS` / `TP_INSTALLED` instead of one machine's paths; the save-key FAQ no longer names migrations that are gone. Nothing changes in game.
- **Docs and comments** (2026-11-15): decisions are stated plainly, without attributions (CHANGELOG, comments, DEVGUIDE, `tools/build_tileset.py`). Nothing changes in game.
- **README** (2026-11-15): the opening names seasoning a food after it is made.
- **Refactor (d), the Stone Hearth split** (2026-11-15): nothing changes in game. **`Fire` names no stone:** fires come in kinds, registered with **`Fire.kind{ id, is, face, sprites, showing, fittedByTile, display }`**, which refuses a kind without `is`, `face`, `showing` or `sprites` before keeping it; `Fire.isFire`, `Fire.kindOf`, `Fire.faceOf` and `Fire.sprites()` replace the stone tests in banking, fit and remove, FireConnect's sides, FireUI, FireLootControls and FireWorld's tracker. **New `StoneHearth.lua`**, the first kind: the tiles (`cauldronSprite`, `liquidOverlay`, `bareSprite`, `bareGlow`, `face`, `SPRITES`), `StoneHearth.isStoneHearth` (the Smokehouse's chamber and `TPC.stone` look for the stone alone), the door, the hole (`holeLook`, `cooksOn`, `STOVE`, `OVEN`), the bare display and `OnCreateStoneHearth`. **The cauldron off `Fire`:** its fluid rules are called as `CauldronFluid.*` (Fire no longer copies them), and `Cauldron` is a module of its own: `Cauldron.ID`, `Cauldron.ITEM`, `Cauldron.RECIPE`, `Cauldron.state`, `Cauldron.of` (were `Fire.CAULDRON`, `CAULDRON_ITEM`, `CAULDRON_RECIPE`, `cauldronState`, `cauldronOf`), its attachment spec `Cauldron.spec`. The cauldron's spec gives its own `sprite` and `overlay`, so `Fire` has no cauldron fallback; an attachment without a `display` shows as its fire's kind. **FireUI names no stone:** `FireUI.addMenu` and `FireUI.addNotes` (were `addStoneHearthMenu`, `addStoneHearthNotes`), the Info window `FireWindow`; the bare help notes and Connect's joined and door refusals are the kind's words (`display.help`, `refusals`; the Stone Hearth keeps its text keys and wording), and the fire object is `fire` in every Fire file, timed action (`action.fire`) and the console. test_fire checks the kind refusals. Every mod's tests and golden results unchanged.
- **Refactor (d), the names**: nothing changes in game. The module `Hearth` is now **`Fire`** (`FireConnect`, `FireUI`, `FireWorld`, `FireLootControls`; `HearthPlace` is **`Fireside`**), the save key `tpHearth` is `tpFire` and the place by a fire `Fireside` (`FiresideOpen`, `FiresideCovered`). The station's names follow the game's: `stoneHearth` is any Stone Hearth (`Fire.isStoneHearth`, was `isFire`; `stoneHearthFace`, `stoneHearthsBy`, `joinedStoneHearth`), `bare` one with nothing fitted (`Fire.isBare`, was `isFirebox`; `bareSprite`, `bareGlow`, `BARE_LOOKS`), `cauldron` / `StoneHearthCauldron` one with the Cauldron (`Fire.cauldronSprite`, `cauldronFace`, `CAULDRON_LOOKS`, was `sprite`, `face`, `LOOKS`). Timed actions `TPFireTend`, `TPFireFit`, `TPFireConnect`, `TPCauldronWork`; entity `TP_StoneHearth`; icons `Item_TPStoneHearth*` and `Item_TPStoneHearthCauldron*`; text keys `ConnectStoneHearth`, `StoneHearthInfo`, `StoneHearthHelp*`, `CauldronHelp*`; tile CustomNames `Hearth` (bare) and `HearthCauldron`. Console: `TPC.kit("stone")` (was `"firebox"`), the default kit `"stoneCauldron"`. Pre-release, so no migration: a fresh save. Tests and golden numbers unchanged (Vinegar's and Yeast's season reports name the place Fireside).
- **`Weather.recipeHours(craftRecipeData)`** (Yeast refactor): a running batch's recipe time in hours (CraftClock's, passed on by Weather), for `batchStatus`. Yeast's and Vinegar's popups and info blocks use it (each divided the script time by 3600 itself). test_core. Nothing changes in game; tests and golden results unchanged in every mod.
- **`Weather.NEW_RUN_PLACE`** (Vinegar refactor): where a station's run or stack counts before its World first says where it stands, the open air. Vinegar's runs and Fish & Meat's stacks and tubs read it (each had its own `"Open"`). Nothing changes in game; tests and golden results unchanged in every mod. In-game step 160 of `TESTING_GUIDE.md`.
- **Game clock for timed actions** (Salt refactor): **`Action.startClock(action)`** and **`Action.clockProgress(action, item, minutes)`** run a timed action on the game clock (the same in-game time at any Day Length): the item's job bar follows it, and the action completes when the minutes are up, at once with the instant cheat. Salt's Dig and Fill use them (each had its own copy). test_container. In-game step 159 of `TESTING_GUIDE.md`.
- **`Action.removeItem` takes the item out of the hands too** (Fish & Meat refactor B3): it calls vanilla's `Remove`, which does `removeFromHands` for a character's inventory before what `DoRemoveItem` does (ENGINE_NOTES, from the decompiled `ItemContainer`). Dairy's cup, incubator and starter crock and Fish & Meat's bale, leg, cauldron fat use it; so do **`Uses.remove`** (an emptied salt shaker or bag) and **`Portions.used`** (an eaten-out crock or jar), and Salt's brine, Dairy's wrap and Vinegar's spare bottle. Test stand-in containers have `Remove`. test_container. In-game step 158 of `TESTING_GUIDE.md`.
- **Shared helpers from Dairy's refactor** (refactor pass step c): **`Action.removeItem(item)`** (was a local in two Dairy actions), **`UI.refuse(option, text)`** (a red submenu row with its reason; five files set `notAvailable` by hand, Dairy uses it now, the others in their own turn). `Station.onHeatNear` gives its callers the object holding the container as a third argument (`fn(container, now, object)`), for Dairy's wrap burning. **The `tp new` template's console** gets a `kit` command (the station's build and four raw batches, kits listed sorted) and a pointer to `TPC.help()`; its DEVHELP and test_console follow. Nothing changes in game; tests and golden results unchanged in every mod.
- **Console tidy** (refactor pass b3, family 6: TraditionalPreservationCoreDev): nothing changes in game. The `TPC` commands share one search for the nearest Stone Hearth (`nearestFire`, fitted or not; `TPC.fuel` had its own copy); the `Hearth.World` guards are gone (rule 13: its file loads wherever the console does in single player, and four calls already used it plainly). The `"hearth"` kit is built from `"firebox"` and `"cauldron"` (same items); `TPC.kit("?")` lists the kits in name order (was `pairs` order, rule 9). The help reads `Hearth.FIRE_RADIUS` and `CauldronFluid.CAULDRON_ML`; `TPC.hot`'s 90 C is `HOT_TEST_C`. **`Hearth.FACE_NAMES`** (was a local) names the facings for `TPC.doors` and `TPC.smokehouse`. HearthConnect and Doors are required at the top. Tests and golden results unchanged in every mod. In-game step 156 of `TESTING_GUIDE.md`.
- **Small shared helpers tidy, with the guard audit** (refactor pass b3, family 5: Charge, ChargeUI, Container, Doors, Uses, Portions, Pour, Handcraft, Appliances, Tiles, Transfer, Action, Log; the audit series-wide): nothing changes in game but one fix. **Vanilla files required plainly:** the engine's `require` of a missing file only warns and returns nil, and vanilla's files are loaded before a mod's on the same side, so Handcraft, Pour, Portions, ChargeUI and FluidAgeingWorld (and Salt's Brine) `require` the vanilla file plainly, as Transfer did; the test harness stands in for those files (**`H.preloadVanilla`**, `H.VANILLA`, run by `H.useModPaths`). **No guards for methods the engine always has** (they covered test stand-ins, now given the method): SlotRules calls `getCurrentRecipe` plainly (every crafting component has it, and CraftLogic's never fails; it was wrapped in a closure on every slot check), Appliances `getContainerCount`, Uses `getWorldItem`, FluidTreat `sendSyncEntity`; Season asks for spices only of a registered food. **Core names no mod** (rule 12): `Uses.take` no longer calls `TraditionalPreservationSalt.returnEmpties`; new **`Uses.onEmptied(tag, fn)`**, which Salt registers. **Register checks** (rule 6): `Charge.line` (uses or count, a positive number, not the same kinds twice), `Portions.onEat` (one set of handlers a type, an after), `Pour.before` / `Pour.after` (an action name it wraps). ChargeUI's line lookup keeps each script line's key (it ran a split, sort and join every frame). **`Container.MIXTURE_TOLERANCE`** names the 0.001 L. `Charge`'s OnTest uses `need` and `has`; Doors' `blocked` and Portions' second `contains` are gone. **Fixed:** `Container.giveBack` takes a placeholder off the floor as `Uses.remove` does (the square's `removeWorldObject`, which also marks the floor tile to redraw, and the item's floor link cleared); its own copy skipped the redraw, so the placeholder's picture could stay on the floor. Test stand-ins given the methods: Core test_core, test_uses, test_container; Fish & Meat test_blood, test_curing, test_ui; Vinegar test_vinegar; Yeast test_shelf; Salt test_shaker. New checks for the register checks, the kept key and the floor. Tests and golden results otherwise unchanged in every mod. In-game step 155 of `TESTING_GUIDE.md`.
- **Seasons, recipes and fluids tidy** (refactor pass b3, family 4: Season, SeasonUI, TPSeason, Recipes, OnHeat, FluidAgeingWorld, FluidAgeingUI, TPFluidTreat): nothing changes in game but one fix. **One minute look at the heat:** new **`Station.onHeatNear(heat, fn)`** walks the squares within **`Station.HEAT_NEAR`** (8) of each player once a game minute and tells each caller of the containers at its own heat or hotter; FluidAgeing's scalding and OnHeat both use it (each walked the same squares on its own; `FluidAgeing.lookOnHeat`, `FluidAgeing.HEAT_RADIUS` and `OnHeat.RADIUS` are gone). **`OnHeat.HEAT`** (100 C as item heat) is worked out once, not for every item each minute. New **`Station.eachPlayer(fn)`**. Season finds a seasoning's kind by one lookup (**`spec.kindByType`**, built at register); **register checks** (rule 6): `Season.register` needs kinds with names and types, `unhappy`, a number for `boredom` and `uses`, and refuses a seasoning item in two kinds; `OnHeat.watch` needs a type, minutes and a function. **`Season.BOREDOM_KEY`** names the boredom save key (same name as before); one pair of helpers turns a spice list to Lua and back. SeasonUI's menu is a local (was `Season.fillMenu` on the shared table, rule 7). **The treat menu moved to the new `FluidTreatUI.lua`** (FluidAgeingUI keeps the loot window and moved items). New **`UI.selectedItems(items, wanted)`** and **`UI.firstSelected(items, wanted)`** (a collapsed stack lists its first item twice; SeasonUI and the treat menu use them). Recipes' header names its three parts; `cookOutputs` reads through `listed`, which asks an item's full type only when filtering. **Fixed:** `Recipes.researchable(itemType, recipeName, tag)` says *Could not find* in the console when the item is missing (it said nothing) and returns whether it took. test_uses: the minute look, OnHeat through it, `researchable`, Season's register checks; test_core: the selection helpers. Tests and golden results otherwise unchanged in every mod. In-game step 154 of `TESTING_GUIDE.md`.
- **Hearth world and cauldron tidy** (refactor pass b3, family 3: HearthWorld, Cauldron, CauldronUI, TPHearthCauldron, TPHearthConnect, TPHearthFit, TPHearthFire): nothing changes in game but one fix. Fit and Connect share a kit's parts, now in **`Action`** (`hasTool`, `kitItems`, `takeItems`, `giveItems`, `addXp`; each action's own copies gone). New **`Hearth.redraw(fire)`** (was `if Hearth.World then Hearth.World.refresh(...) end` in each action). An attachment's **`heats` is given the place** as its sixth argument (`heats(part, fire, now, fireState, airC, place)`): a refresh looks it up once (was twice, the cauldron's `heats` asking again); `isBurning` once a refresh. `slowAll` goes over the banked fires directly (Kahlua's `pairs` copies the keys first: ENGINE_NOTES, read from the decompiled engine). TPHearthCauldron: `MOST_LITRES`, one helper each for the saved cauldron and forgetting an empty cauldron's age record. CauldronUI: one helper builds Pour into and Fill from's item submenus; `holds` sorts by the shares it named. The cauldron's `look` is `Hearth.look`. **Bug fixed:** Kahlua has no weak tables, so HearthWorld's `__mode = "k"` did nothing and the overlay tints it had seen kept every unloaded Stone Hearth for the session; the tint is now dropped with the fire (as the cooking times already were) and `__mode` is gone. test_hearth_world: the place given to `heats`, the tint set again after an unload. Tests and golden results otherwise unchanged in every mod. In-game step 153 of `TESTING_GUIDE.md` passed (INGAME_PASS 152).
- **Stations and windows tidy** (refactor pass b3, family 2: Station, StationInfo, InfoWindow): nothing changes in game but one fix. Station's three walks over the squares round a point (`nearAt`, `hotContainers`, the tracker's scan) are one local helper; new **`Station.squareAt(square, dx, dy)`**, which Doors and the Smokehouse use (were their own copies). StationInfo's block in vanilla's crafting window and InfoWindow draw with the same helpers, **`InfoWindow.drawRow`, `drawBar`, `noteLines`, `drawNoteLines`** (each takes the element and its layout), with named colours (`InfoWindow.LABEL_COLOUR`, `VALUE_COLOUR`, `NOTE_COLOUR`, `BAR_BACK`, `BAR_BORDER`), gaps and `VALUE_CACHE`; `InfoWindow:row`, `:bar` and `:drawNotes` keep their names. StationInfo's `Panel:noteLines` and `Panel:rowLines` are gone (InfoWindow's take the width). New **`UI.daysHours(hours)`**, shared by `UI.timeText` and the crafting window's bars. **Register checks** (rule 6): `Station.tracker` needs `sprites` and `refresh`, `StationInfo.add` a function, `InfoWindow.clickOpens` two. **Bug fixed:** two running batches at the same progress could swap rows in the crafting window, as the engine lists them in no set order; ties now go by recipe name, then item count (**`StationInfo.batchBefore`**, rule 9). test_station_info: the tie-break, `daysHours`, the register checks. Salt's test_vat_info mock recipe has a name. Tests and golden results otherwise unchanged in every mod. In-game step 152 of `TESTING_GUIDE.md` passed (INGAME_PASS 151).
- **Smokehouse tidy** (refactor pass b3, DEVGUIDE "Refactoring rules"): nothing changes in game but one fix. A stack's fire counters (`startCounters`, `owns`, `fireStep`, `hotDone`) moved to the new **`SmokehouseStacks.lua`**; Smokehouse passes them on, so every `Smokehouse.<name>` call still works. `fireStep` uses `Hearth.sessionHours`. The chamber's lookups no longer scan round the shed for each question: the connection's `finds` and `refusal` work out the Stone Hearth's entry from its two squares (one helper builds `fireboxesBy`'s entries, one finds the first object on a square). Named values: the flue's entry overlays follow `Smokehouse.FLUE_KINDS` (as the tile builder does), each facing's door letter, **`HearthConnect.SIDES`** (the order a search takes Back, Left, Right; `TPC.stone()` uses it too). **Core names no product** (rule 12): `Smokehouse.hamSprite` is **`Smokehouse.readySprite`** and `Tiles.CHAMBER_HAM` **`Tiles.CHAMBER_READY`** (same tile, same art; every file `tools/build_tileset.py` writes but Tiles.lua comes out byte for byte as before). The flue's menu texts and icon are registered in SmokehouseUI (client fields, rule 7); **`Smokehouse.CHAMBER_NAMES`** is the chamber's set of sprite names for the placement rules. **Dropped:** the unused `Smokehouse.setFlue`; `Smokehouse.chamberBy` is a local. **Bug fixed:** with two Stone Hearths beside a shed, the chamber's Connect picked one with a sort that isn't stable, so which was offered could depend on the order; it now offers the first that may join, else the first found (**`Smokehouse.connectCandidate`**, rule 9). test_smokehouse_world: `finds`, `refusal`, `connectCandidate` with either Stone Hearth refused and both; tests and golden results otherwise unchanged in every mod. In-game step 151 of `TESTING_GUIDE.md` passed (INGAME_PASS 150).
- **Weather.lua tidy** (refactor pass b3, DEVGUIDE "Refactoring rules"): nothing changes in game. The craft recipe helpers (`startRun`, `showProgress`, `setRecipeHours`, `startClock`, `showClock`, `batchStatus`) moved to the new **`CraftClock.lua`**; Weather passes them on, so every `Weather.<name>` call still works. Each place's temperature is worked out once a reading, not once a kind; `placeTemperature` reads a table of place rules (one for each of `Weather.PLACES`, checked at load); the season's mean and the ground's behind it are one helper (was three copies). **`Weather.season(ledger, field, ...)` is two functions**, `Weather.seasonTemperature(ledger, t, hours)` and `Weather.seasonHumidity(ledger, h, hours)`. New **`Weather.rate(curve, celsius, sensitivity, minRate, freezeC)`**: 0 when frozen, else the curve after the sensitivity (Dairy, Vinegar and Yeast had it six times over). **`Weather.DEFAULT_PLACE`** ("Sheltered": where something stands when nothing says); `Hearth.DEFAULT_UNDER` and `FluidAgeing.DEFAULT_PLACE` are it. Named values for the no-square place, the first upstairs floor, the hours a day and `settledMeans`' rounds. `Weather.seasonMean` and `Weather.SENSITIVITY_SCALES` are locals. New **`FluidAgeing.foodRotSpeed()`**: vanilla's Food Spoilage setting as a multiplier (1.7 to 0.4), for a spec's `speed` (was Fish & Meat's, inside Potted Meat). test_core: `Weather.rate`, an unknown place; it loads Weather through `require`. test_fluid_ageing: `foodRotSpeed`. Tests and golden results unchanged in every mod. In-game step 149 of `TESTING_GUIDE.md` passed (INGAME_PASS 148).
- **HearthUI.lua tidy** (refactor pass b3, DEVGUIDE "Refactoring rules"): nothing changes in game but two fixes. Fit and Connect share one set of kit helpers (an attachment's `fit` is a kit like a connection's: one look through the containers in reach finds its items and tool, `Hearth.kitMissing` says what is short, one hover builder); the Stone Hearth's menu is one function, fitted or bare (`Hearth.isFirebox` picks Fit or the attachment's rows); one `LOOKS` table holds the Hearth's and the Firebox's icon, title, Info row and fire icons; Hearth Info's notes are built by **`HearthUI.notes(info)`** (testable). **The cauldron's hooks moved to CauldronUI** (rule 12): `CauldronUI.addMenu` and `CauldronUI.addNotes` (were `HearthUI.addMenu`, `HearthUI.addNotes`, `HearthUI.modRows`); Hearth Info's `info.cauldron` is **`info.part`** (nil with nothing fitted). Text keys `FlueNeeds`, `FlueTool`, `FlueMissing`, `FlueBurning` are `KitNeeds`, `KitTool`, `KitMissing`, `FireBurning` (same texts). **Named for any attachment**: `Hearth.isHearth` is now **`Hearth.isFitted(fire, id)`** (that attachment fitted, or any with no id; the cauldron's callers pass `Hearth.CAULDRON`) and `Hearth.hearthsNear(square)` **`Hearth.fittedNear(square, id)`**; a fitted Stone Hearth's icon, title, Info row and Bank / Stoke icons come from its attachment's new **`display`** field (the cauldron's, in CauldronUI, if left out), so the salt pan can bring its own. Dropped: `HearthUI.FIRE_ICONS`, `HearthUI.HearthWindow`, `HearthLootControls`' `Handler.modeOf`, HearthUI's unused `require` of Cauldron. **Bug fixed:** Disconnect's hover, greyed while the fire burns, now says what comes back as well as *Let the fire go out first* (as Remove's does). test_hearth_menu: the Disconnect hover, `HearthUI.notes` fitted and bare, `isFitted`, an attachment's own display and the fallback; test_hearth_world reads `isFitted`; tests and golden results otherwise unchanged in every mod. In-game step 148 of `TESTING_GUIDE.md` passed (INGAME_PASS 147).
- **Table-top stations' builds refuse appliances; every TP station minds the doors** (after in-game step 146b; both gaps were older than the UI split). Vanilla's build ghost asks `canPlaceMoveable` only on a solid square (`ISBuildIsoEntity.isValidPerSquare`), so Dairy's crock built on a stove or fridge. New shared **`Appliances.lua`** (`Appliances.is`, `Appliances.onSquare`, moved from Placement) and the build check **`TraditionalPreservationCore.offAppliances`** (no appliance, and `doorFits`). Every TP mod's stations now keep off a door's front, built (`OnIsValid`) and put down (`UI.keepDoorsFree`, which takes a list such as `Tiles.STATIONS` as well as a set). test_doors: the build check, and every TP entity script has an `OnIsValid`; test_core: `keepDoorsFree` with a list. DEVGUIDE. In-game step 147 of `TESTING_GUIDE.md` passed (INGAME_PASS 146).
- **UI.lua split** (refactor pass b3, DEVGUIDE "Refactoring rules"): nothing changes in game. UI.lua (538 lines) keeps the text, menus and window popups; **`SlotRules.lua`** holds `slotRules` and **`Placement.lua`** the put-down and pick-up rules (`keepInPlace`, `outdoorOnly`, `notInRooms`, `keepDoorsFree`, `offAppliances`). UI passes them on, so every `UI.<name>` call still works. The put-down rules now share **one wrap** of `canPlaceMoveable` (was one a call, five deep); every rule must pass, as before. The slot record is built by one helper; the popups' title and closing lines are one helper each; `UI.LABEL_COLOUR` names the pale yellow; a fluid's `Fluid.Get` is looked up once for `UI.fluidName`; `UI.isAppliance` is a local of Placement. test_core loads UI through `require` and checks the single wrap; tests and golden results unchanged in every mod. In-game step 146 of `TESTING_GUIDE.md` (INGAME_PASS 145).
- **Tainted water taints the lot**: clean and tainted water may now share the cauldron. Poured together, either way round and whatever the share, the whole cauldron is Tainted Water, and its 10 minutes at the boil start over. A container already holding both (vanilla mixes them) pours in as tainted water. Pour into the Cauldron's hover says "Everything in the cauldron becomes Water (Tainted). Boil it again to make it safe." while the sandbox's tainted water text is on, and nothing when it is off. Everything else is still one fluid at a time. The general rule is `Hearth.taints(fluid, other)` and `Hearth.taintedBy` (CauldronFluid); `UI.hidesTaint`. test_hearth, test_hearth_menu; README, DEVGUIDE, guide 6. In-game step 145 of `TESTING_GUIDE.md` passed (INGAME_PASS 144).
- **Bug fixed: tainted water in the cauldron read plain "Water"**: the status row, Stone Hearth Info's Holds line, the mixed refusal and Empty's hover now say **Water (Tainted)**, with vanilla's own text, when the sandbox option *Enable 'Tainted Water' tooltip* is on, as vanilla's containers, sinks and rain barrels do; with it off, plain Water as before (`UI.fluidName`). test_core. In-game step 144 of `TESTING_GUIDE.md` passed (INGAME_PASS 143).
- **Hearth.lua split** (refactor pass b3, DEVGUIDE "Refactoring rules"): nothing changes in game. Hearth.lua (1,127 lines) keeps the fire, its attachments, banking and tiles; three new files hold the rest, and Hearth passes their functions on, so every `Hearth.<name>` call still works: **`CauldronFluid.lua`** (what the cauldron holds: heating, boiling, blends, turnsHot / goesOff, the pour hooks, item heat, the liquid's colour, and their numbers, `Hearth.MAX_C` and the rest), **`HearthConnect.lua`** (connections; `FLUE_SIDES` is `HearthConnect.FLUE_SIDES` now) and **`HearthPlace.lua`** (by a fire as a place, `placeOf`, `catchUp`, the runs, `notePlace`). Also: `attach` and `connect` share one registry (`Hearth.registry`); the time-to-a-heat sum is one helper, and the hot hours are worked out once per step for both `held` and `hot`; a blend partner's `Fluid.Get` is looked up once. **Register checks** (rule 6): `attach` and `connect` need an id and refuse a field given again as something else, `attach`'s fit needs items, `connect`'s kinds come with a kit each; `hook` refuses an unknown name or a non-function; `blend` a fluid already in a blend; `turnsHot` and `goesOff` a fluid named twice; `cooksOn` anything but stove or oven. Named values: `Hearth.DEFAULT_UNDER` (the room under a fire when none was noted), `Hearth.MINUTES_PER_HOUR`, `ML_PER_L`, `AMOUNT_TOLERANCE_L`. **Dropped:** the aliases `Hearth.placeTemperature` and `Hearth.mark` (callers use `Weather.placeTemperature` and `Weather.mark`), the unused `Hearth.fireNear`; `Hearth.share` and `Hearth.fluidColour` are locals. **The cauldron no longer keeps a copy of the fire's `fireUntil` and `banked`**: `Hearth.advance(cauldron, now, roomC, fire)` takes the fire's state, `Hearth.fireTarget(cauldron, banked)` and `Hearth.hoursToHot(cauldron, banked)` take banked (a cauldron in an older test save keeps the two old fields, unread). test_hearth: the register checks; tests and golden results unchanged in every mod. In-game step 143 of `TESTING_GUIDE.md` passed (INGAME_PASS 142).
- **Scalded folded into FluidAgeing's states** (refactor pass b2, DEVGUIDE rule 12): nothing changes in game. The spec's `scalded` field is gone: a state may be made by heat (`heat = true`, one a kind, brought about by `scaldHeat` / `scaldHold` and `markScalded`), and the record keeps it with the treatments (`treated = { Scalded = true }`; its `scalded` field is gone, so milk scalded in an older test save reads plain: use a clean one). Every rule for scalded milk holds: it never turns, keeps the plain kind's spoilHours, goes plain when raw is mixed in, and store milk poured out is in the heat state. **One state at a time**: heat leaves a fluid already in a state as it is, a treatment by hand replaces the heat state, and a container first seen with two states' fluids is plain. `FluidAgeing.inState(record, name)`; `newRecord`'s last argument is a state's name; `nameAt(spec, stage, name, state)`. `register` refuses two heat states and a heat state done by treatments. test_fluid_ageing: the one-state rules. Tests and golden results unchanged. In-game step 142 of `TESTING_GUIDE.md` (INGAME_PASS 141).
- **Copper-to-cauldron rename** (refactor pass b1, DEVGUIDE "Refactoring rules"): nothing changes in game. The code says cauldron where it said copper, as the player's text already did: `Cauldron.lua`, `CauldronUI.lua`, the action `TPHearthCauldron`; the attachment's id and save key `Hearth.CAULDRON` = `"cauldron"` (was `Hearth.COPPER` = `"copper"`; a cauldron fitted in an older test save isn't known, use a clean one); the item constant is now `Hearth.CAULDRON_ITEM`; `Hearth.cauldronState`, `cauldronOf`, `cauldronTau`, `cauldronRoom`, `CAULDRON_ML`; `FluidAgeing.updateCauldron`, `cauldronRecord`; the translation keys (`PourIntoCauldron`, `FillFromCauldron`, `EmptyCauldron`, `InfoCauldron`, `Cauldron*`); every comment, test and DEVGUIDE line. Real copper stays (vanilla's copper pans, the guide's notes, copper for Dairy's cheese vat). Tests and golden results unchanged. In-game step 141. Also: the mod list's description says the Stone Hearth and the Forged Cauldron (was "a stone oven with a copper"); `tools/build_tileset.py` says cauldron (`paint_copper` is `paint_mouth`, `copper_icon` is `kettle_icon`, `ICON_METAL` gone) and no longer writes the unused `Item_TPCopper.png` and `Item_TPCopperFull.png`, both deleted; every other file it writes comes out byte for byte as before.
- **FluidAgeing refactor** (DEVGUIDE "Refactoring rules", the worked example): nothing changes in game. Treating by hand (`litresIn`, `treatUses`, `treatableSpec`, `treatRefusal`, `treatBy`) moved to the new `FluidTreat.lua`, still reached as `FluidAgeing.<name>`; `TPFluidTreat` and `FluidAgeingUI` call it directly, and the treat menu is a local of `FluidAgeingUI` (was `FluidAgeing.fillTreatMenu`). `register` checks the spec (the fields it needs, a spoiled fluid for each fresh one, no fluid another kind has, no two states done by the same treatments; it claims nothing unless all pass) and works out the lowest scalding heat and the spoiled set once; each fluid is looked up in the engine once (`Fluid.Get`); `specIn` also returns the amounts it found, so a look reads the container once; a record's state is found without sorting. One helper each for starting a record, scalding a fresh one, forgetting an empty owner and changing a record (`markScalded`, `treat`, `untreat`); the spec's fields listed one a line; `FluidAgeing.DEFAULT_PLACE`. The `steamed` field of test builds is no longer read (nothing released wrote it). test_fluid_ageing: the register checks and the one-time lookups. In-game step 140 of `TESTING_GUIDE.md` passed (INGAME_PASS 139).
- **Bug fixed: blood first seen with spoiled blood in it**: a container seen for the first time with salted, vinegared or cured blood and some turned or spoiled blood came out treated or untreated depending on which fluid the game listed first. Turned and spoiled shares now say nothing either way (as scalding already did): salted plus spoiled blood is salted. A plain or scalded share, or another state's, still makes it untreated. test_fluid_ageing tries both orders.
- **Pasta and rice are stove food**: vanilla's pasta and rice pots, forged pots and saucepans (cooking, and the water stages) show the forged pot in the Stone Hearth's hole instead of the lid (`Hearth.cooksOn`). Guide 6; test_hearth. In-game step 139 of `TESTING_GUIDE.md` (INGAME_PASS 138).
- **Console names**: `TPC.hearth()` is now **`TPC.cauldronInfo()`** and `TPC.firebox()` **`TPC.stone()`** (no aliases); `TPC.kit("hearth")` and `TPC.kit("firebox")` keep their kinds. Help, guide 6, DEVHELP, test_console.
- **Docs pass after the Stone Hearth hub**: guide 6 rewritten for the Stone Hearth, the Forged Cauldron (forging, Fit / Remove, its Info bar) and the Smokehouse in Core (flat roof, the low flue, two slots), with the vanilla item names (Steel Sheet, Iron Pipe, *Everyday Smithing - May 1993*); README, DEVGUIDE (the cauldron is still `copper` in the code), DEVHELP and the Workshop text the same. **Console:** `TPC.copper` is now **`TPC.cauldron(l, c, f)`** (no alias), and the help and outputs say Stone Hearth and cauldron (`TPC.hearth`, `fuel`, `hot`, `warmth`, `smokehouse`); test_console.
- **The pot's lid, connections draw themselves, the cauldron's bar** (the Stone Hearth hub's step iv):
  - **The forged pot in the hole has its lid on** (`pot_lid` in `tools/build_tileset.py`): forged iron as the pot, a low dome inside the rolled rim up to a loop handle; the stew no longer shows (it looked off). The steam still curls up round the rim.
  - **A connection owns its sprites**: `Hearth.FLUES` is gone; a connection's `smoke = true` (the Smokehouse's) says it takes the fire's smoke, so the bare Stone Hearth's hole is lidded and its glow goes up it. The stone draws no flue: its Pipe_ and Stones_ looks, which drew the same as the plain ones since 2b, are dropped (tiles 16-23 and 54-69 free; `FIREBOX_LOOKS` is Open 10, Lid 12, Pot 14). `Hearth.fireboxSprite(smoke, hole, face)` and `Hearth.fireboxGlow(lit, banked, smoke, hole, face)` take a flag in place of the flue's kind and side. A Stone Hearth joined in an older build has a tile that is gone: use a save without one.
  - **The cauldron's Info bar** shows the colour of what it holds (`Hearth.liquidColour`, as the overlay), iron grey when empty; it was the copper's (`COPPER_COLOUR` gone).
  - Tests in test_hearth, test_hearth_world, test_doors. In-game step 135 of `TESTING_GUIDE.md` (INGAME_PASS 134).
- **Hearth connections, the Smokehouse's flue moved onto them** (the Stone Hearth hub's step iii): `Hearth.connect{ id, kinds, kits, blocks, finds, joined, refusal, onChange, connectText, disconnectText, disconnectHelp, icon, notes }`, what is built onto a fire in its second slot, one at a time. **Its state moved** from `flue` / `flueSide` on the fire to `connected` and `{ kind, side }` under the connection's id in `tpHearth` (`Hearth.join`, `Hearth.unjoin`, `Hearth.connectedTo`, `Hearth.joinOf`, `Hearth.connectionOf`; old saves ignored: a flue laid before shows capped, lay it again). `blocks` "connection" (the Smokehouse's: the Cauldron still fits) or "both" (Fit refused while joined, `fitRefusal` "Blocked", and Connect while fitted). Core enforces one a fire, one fire a shed (the Smokehouse's own `refusal`), never the door's side and never while burning (`Hearth.connectRefusal`, `connectRefusalOf`); kits are the connection's (`Hearth.kitMissing`, `Hearth.kitBack`). The timed action `TPFlue` became Core's `TPHearthConnect` (kit ticks, XP and animation from the kit), and Connect / Disconnect are on every Stone Hearth's menu from `HearthUI` (`HearthUI.addConnect`, `addDisconnect`, also used by the chamber's right-click); a joined Stone Hearth can't be picked up (Core's rule now). `Hearth.setFlue` and `Smokehouse.connectRefusal` are gone (`Smokehouse.chamberRefusal` is the shed's part); `Smokehouse.flueOf`, `joinedChamber`, `joinedFirebox`, `fireOf`, `setFlue` unchanged, so Fish & Meat and Dairy don't change. Texts: the door-side refusal is general, new `ConnectFitted`, `FitBlocked`. `TPC.firebox()` prints what is joined; `TPC.flue` joins the Smokehouse's connection. Tests in test_hearth, test_hearth_world, test_hearth_menu, test_smokehouse, test_smokehouse_world.
- **The Stone Hearth's art: bigger, a low flue, the cauldron's look** (the hub's install 2b): its stone covers four fifths of its tile (half footprint `H` 0.32 to 0.40, `tools/build_tileset.py`), the same height; the hole, the pot and the cauldron keep their size. Tiles, build and menu icons and the mod icon redrawn.
  - **The flue climbs only a little** (after trying it level along the ground): the clay pipe leaves the stone's side near its foot (`PIPE_Z` 8 px), 0.2 tiles towards the viewer (`PIPE_SHIFT`), runs out to 0.46 (`PIPE_OUT`) and climbs to just over the stone's top, entering the Smokehouse's wall at 48 px (`PIPE_TOP`; the shed's entry moved down to meet it). It no longer climbs past the cauldron (`FLUE_RISE`, `PIPE_EXIT` gone), so it never meets the cauldron's pipes and a fitted Hearth needs no flue tiles: the elbow and the short rise show behind the stone's corner.
  - **The fitted look is the Forged Cauldron's**: the kettle in dark forged iron, greased and blacked (near black, a cool sheen on the rim), the cauldron's size unchanged; the gallows bar gone for what the fitting takes, two Metal Pipes, the Heavy Chain sagging between their tops and the Large Hook in its middle, all sooted. The menu icons are still the darkened copper's.
  - In-game step 129 of `TESTING_GUIDE.md` (INGAME_PASS 128).
  - **The stone as vanilla's stone mill** (style guide, 2026-11-13): grey dressed blocks in courses with dark joints, each lighter at its top (`fieldstone`), under one large flat stone that overhangs the walls a little all round and drops a soft shadow on them (`slab_top`, `CAP_OVER` 0.05, `SLAB` 7 px; was a cream lime render). The door's arch and the trench's stones in the same grey. The clay pipe runs out to 0.49 and climbs to 54 px (`PIPE_OUT`, `PIPE_TOP`; were 0.46 and 48) so the slab's overhang doesn't hide it, and the Smokehouse's entry overlay now draws the whole pipe from the stone to its wall (a fitted Hearth's tiles draw no flue, so the pipe was missing beside the cauldron; the Hearth, drawn after the shed, still hides its foot), drawn and weathered as the Hearth's own pipe was, with its collars at the elbow. **The flue is drawn once, by the shed:** the entry overlay draws the whole pipe (with its clay bedding at the stone) and the whole trench up to the stone's foot, and the Stone Hearth's flue looks (Pipe_, Stones_) now draw the same as its plain ones (`back_pipe`, `trench` gone), so nothing is drawn twice and a fitted Hearth's trench shows too.
  - **The cauldron greyer** where the soot hasn't reached, and **its ground model**: `tools/build_model.py` builds `Models_X/ForgedCauldron.glb` and its texture (the kettle alone, bail dropped over the rim; the tiles' profile and soot, at the tiles' size, 0.66 m across the belly and 0.6 m high (taller than true, as the camera squashes a model), with a thick rolled lip blotched with soot (its own strip of the texture); textured in vanilla's forged pot's greys and cloudy mottling, light iron above the soot and dark below, used as painted), `model ForgedCauldronGround` (scale 0.54) as the item's `WorldStaticModel`.
  - In-game step 130 of `TESTING_GUIDE.md` (INGAME_PASS 129).
  - **What the cauldron holds shows in its colour**: the overlay is the one thing the game tints per object (ENGINE_NOTES), so the fire's glow is now drawn into the fitted Hearth's tiles (`HEARTH_LOOKS`: Cold, Steam, Lit, LitSteam, Banked, BankedSteam; `GLOWS` gone) and the overlay is a pale surface in the kettle's mouth (`LIQUID`, the bail, hook and near pipe cut out of it), tinted each vanilla fluid's own colour, a blend's mixed by its shares (`Hearth.liquidOverlay`, `Hearth.liquidColour`, `Hearth.fluidColour`; HearthWorld's `showOverlay` sets the tint again after a load). The tiles no longer draw milk: an empty cauldron has no overlay. `Hearth.sprite(look, face, burning, banked)`; an attachment's `glow` is now `overlay(part, face, burning, banked)` returning a sprite and a tint. Tests in test_hearth, test_hearth_world. In-game step 131 (INGAME_PASS 130).
  - **The cauldron's icons** (the approved mock `art/cauldron_icons_mock.png`): `cauldron_icon` draws the item empty and full (`Item_TPCauldron`, `Item_TPCauldronFull`: the tiles' kettle in iron, the thick lip, a milky surface when full, a near-black outline as vanilla's forged pot), `fit_icon` the Fit / Remove icon (`Item_TPCauldronFit`: the cauldron in front of the sooted pipes, chain and hook; the cauldron's `fitIcon`), all generated by `tools/build_tileset.py` in place of the darkened copper placeholders. In-game step 132 (INGAME_PASS 131).
  - **The Smokehouse rebuilt in its look** (`art/smokehouse_mock.png`): a flat roof (`CHAMBER_EAVE` 132 px; was one slope along the shed), its boards across the shed; the door wider (`CHAMBER_DOOR_HALF` 0.3, was 0.17) with uneven cracks where its latch side and top meet the frame, and a rope handle in a loop under the latch (drawn only: the recipe takes no rope); thicker boards as vanilla's barricades (`CHAMBER_PLANK` 0.15, was 0.11), lit along one edge, grain along them, the walls' joins about half open a crack (`CHAMBER_WALL_GAP`), the roof's and door's fewer (`CHAMBER_GAP`); the battens nailed to each board. The ham moved out to the corner (`HAM_A` -0.44) to clear the wider door. In-game step 133 (INGAME_PASS 132).
- **The Forged Cauldron, Fit and Remove, two slots** (the Stone Hearth hub's step ii, install 2a; design 2026-11-13; old saves ignored). The Hearth's kettle is now a **Forged Cauldron** (`TraditionalPreservationCore.ForgedCauldron`, 60 L as before; copper is kept for Dairy's cheese vat). It is forged at a vanilla forge as the forged pot is, scaled up (`Forge_TPCauldron`: 2 sheet metal, 3 charcoal, wire; ball-peen hammer, pliers or tongs, metalworking chisel kept; Blacksmith 4, 400), learned from the Smithing Magazine Vol. 2 (added at load, `Recipes.teach`; magazines already in the world teach it too), auto-learned at Blacksmith 5 and Cooking 2, or researched from the cauldron (`Recipes.researchable`). **The Hearth build recipe is gone**: a Stone Hearth is built bare and the cauldron fitted from its menu.
  - **Fit Cauldron / Remove Cauldron** (generic, timed action `TPHearthFit`): an attachment's `fit = { items, tool, ticks, removeTicks, xp, lost }`, with `fitHelp` and `fitIcon` for the menu. The cauldron's fit takes the cauldron, 2 metal pipes, a heavy chain and a large hook, with pliers kept, about an hour (Remove half that); Remove gives them all back. Neither while the fire burns, Remove not while the cauldron holds anything. `Hearth.fitRefusal`, `Hearth.fit`, `Hearth.unfit` (`attached` false: nothing, whatever the tile), `Hearth.fitBack`, `Hearth.attachments()`.
  - **Two slots**: an attachment (the Cauldron) and a connection (the Smokehouse's flue) go on the same Stone Hearth, each free of the other; what a connection blocks comes with `Hearth.connect` (step iii). The flue joins any Stone Hearth (`Smokehouse`, `SmokehouseUI`), and `HearthUI.addFireboxMenu` / `addFireboxNotes` rows show on a fitted one too (notes read the fire's state as `info.state`). A fitted Stone Hearth can't be picked up: Remove first. Until the art (install 2b) the fitted tile is the copper kettle's and draws no flue pipe.
  - Texts: Copper reads Cauldron (Stone Hearth (Cauldron), Pour into / Fill from / Empty the Cauldron, the notes); new Fit / Remove texts. Icons `Item_TPCauldron`, `Item_TPCauldronFull` (the copper's darkened; the real art in 2b). Console: `TPC.kit()` gives the Stone Hearth and the fit kit, `TPC.kit("cauldron")`, `TPC.kit("forge")`, `TPC.fit()` / `TPC.fit(false)`; `TPC.firebox()` and `TPC.flue` work on any Stone Hearth. Engine notes: "Magazine recipes and tinted liquid on a tile". Tests in test_hearth_menu, test_hearth_world, test_smokehouse_world, test_recipes, test_console. In-game step 128 of `TESTING_GUIDE.md` (INGAME_PASS 127), passed.
- **The Stone Hearth** (the hub's step ii, first install; design 2026-11-13; old saves ignored): the Firebox is renamed **Stone Hearth** and gets a stone-lined hole in its top (radius 0.09 tiles, "hole D"). What shows in the hole follows its firebox (`Hearth.holeLook`): open, smoke and firelight rising out of it while lit; Base.PotForged's look set in it for any stove food or container holding fluid; a sooted steel lid with a flat bar handle for oven food only, and always when joined to a flue with no pot. A joined clay pipe now leaves the stone's side low down and climbs past the top into the wall (the Smokehouse's entry moved up to meet it, `FLUE_RISE` 24). Tiles: the Stone Hearth's 15 looks a facing (Open, Lid, Pot, and each flue and side with Lid or Pot) take the old Firebox's 10-23 and 54-69, new glows (open, pot; lit and banked) 46-53; the sheet has 128 tiles now. The Hearth is named **Stone Hearth (Copper)**; its tiles, menu and build recipe are unchanged until Fit Copper (next install).
  - **What is fitted is noted on the fire** (`tpHearth.attached`, was told by the tile): `Hearth.isHearth` is a Stone Hearth with the copper fitted, `Hearth.isFirebox` one with nothing, `Hearth.isFire` either; `Hearth.attachedTo`, `Hearth.fireFace`. A copper tile with nothing noted (put down after a pick-up) is the copper fitted, and the World notes it. An attachment may give its own `sprite(look, face)` and `glow(burning, banked, face)`.
  - **Stove or oven** (`Hearth.cooksOn(where, fullTypes...)`, `Hearth.cookedOn(item)`): every food is oven food unless a mod names it stove food. Core names vanilla's stews, soups, stir-fries and omelettes (pots, forged pots, buckets, pans, griddle). `Hearth.fireboxSprite(flue, side, hole, face)` and `Hearth.fireboxGlow(lit, banked, flue, hole, face)` take the hole.
  - Texts: Firebox reads Stone Hearth everywhere (menus, Info, flue messages, tooltip); Stone Hearth Info. Console: `TPC.kit("hole")` (a Pot of Stew, an uncooked pie and an empty Cooking Pot), `TPC.firebox()` shows the hole's look. Tests in test_hearth, test_hearth_world, test_doors, test_console.
- **The Smokehouse moved here from Fish & Meat** (before Dairy, so its smoked cheeses and later mods share it; old saves ignored). The chamber entity (`TraditionalPreservationCore.Smokehouse_Chamber`, same build: 14 planks, 20 nails, hammer, Woodwork 3), its art (tiles 32-45: the chamber, the flue entries, the ham; pixel for pixel Fish & Meat's, `tools/build_tileset.py`), the build icon, Connect / Disconnect the Firebox (`SmokehouseUI`, timed action `TPFlue`, the clay pipe and stone trench kits), the door, its World look (`SmokehouseWorld`: the flue's entry and the ham by the door, the `Smokehouse` recipe tag) and the fire's two counters. `Smokehouse.lua`: the chamber's tiles and sides, the flue, `startCounters(modData, owner, hotNeed)`, `owns`, `fireStep(modData, fire, coolShare)` (returns the stoked and banked hours for the mod's own use), `hotDone`, `fireOf`, `slotTile`; `TraditionalPreservationCore.notInRoom` for its build menu. **Each stack records its owner**, and each mod steps only its own (2026-11-13). Texts moved with new keys (`IGUI_TraditionalPreservationCore_Flue...`, `ContextMenu_TraditionalPreservationCore_Connect...`); the build tooltip names what the TP mods smoke. Console: `TPC.kit("smokehouse")`, `TPC.kit("flue")`, `TPC.smokehouse()` (was Fish & Meat's). Tests in `test_smokehouse.lua`, `test_smokehouse_world.lua`, `test_console.lua`. `tp sync` leaves the three files out.
- **`UI.slotRules` takes `owns(entity, item)`** (2026-11-13, for the shared Smokehouse): a mod judges only its own items there; any other passes on to the next mod's rules and vanilla, and an add with one in it is left to them whole.
- **Season** (a food seasoned afterwards, as a stew is; for Fish & Meat's sausage links): `Season.register(fullTypes, spec)`, a **Season** submenu in the food's own submenu (`SeasonUI`), each kind of seasoning in reach and not yet in it with the uses there, for every selected item of the type; timed action `TPSeason`. Each kind goes in once, no cap, taking what vanilla takes for a stew (`uses`, default 1), and makes the food `unhappy` and `boredom` nicer (a part-eaten one, its share; vanilla's spice in a stew is -2 of each). What went in is the food's own spice list (saved by the game); the bonus is kept in ModData (`tpSeasoning`). `Season.carry`, `Season.record`, `Season.apply` hand it on.
- **Fluid states (treatments)** (2026-11-13, for Fish & Meat's blood): a kind registered with `FluidAgeing` may name `states`, each with its own fluid names and `spoilHours`, and `of` for a state made of several treatments (salted and vinegared blood is Cured). A record keeps `treated` (saved inside `tpFluidAge`); `FluidAgeing.treat(owner, now, name)` adds one to fresh fluid and renames it, `FluidAgeing.untreat` drops them (fresh fluid gathered in). Pouring keeps only the treatments both sides had, as a raw share makes milk raw; fluid first seen under a state's name takes that state; a treated record never turns. `FluidAgeing.state`, `FluidAgeing.spoilHours`. A state may also have its own `kind` and `rate`, when it slows in the cold unlike the plain fluid: it ages on that ledger kind (the record's `markKind`), and a change of state loses only the stretch since the last look. A container first seen with a scalded or treated name mixed with a plain one is now renamed plain at once (it already counted as plain). Milk unchanged. Tests in `test_fluid_ageing.lua`.
  - **Treat menu** (what other mods can reuse goes in Core): a kind with `treatments`, `litresPerUse` and `treatMenu` gets a submenu on its containers, one option a treatment with its icon and the uses it takes (*-2 Salt*), greyed with the reason (none, spoiled, done, too few carried; new `IGUI_TraditionalPreservationCore_Treat...` texts); timed action `TPFluidTreat`; `FluidAgeing.treatRefusal`, `treatBy`, `litresIn`, `treatUses`, `treatableSpec`.
  - **`ISGatherBloodFromAnimal.updateBucket`** wrapped in `FluidAgeingWorld`, beside milking: a bucket with no blood starts a new record, fresh blood gathered onto treated blood makes it untreated.
- **TP's own cooking sounds** (vanilla's BoilingFood sizzles like frying): `TPBoiling` (a rolling boil, looped), the CookingSound of every TP item that boils, and `TPSimmering` (a gentle lidded simmer), looped on the Hearth's square while its copper is at 85 C or more (`HearthWorld`, a free world emitter, stopped when it cools, empties or unloads). Sound scripts in `TraditionalPreservationCore_sounds.txt`, files in `media/sound/`. Both clips: "boiling water loops" by TinyWorlds, OpenGameArt, CC0.
- **`Charge.line(amounts)`** (2026-11-13): one recipe line taking a different amount of each item (Fish & Meat's filler: 12 uses of oats or rice, or 12 grains). The line keeps the item; `onTest` wants the amount in reach, `take` (OnCreate) takes it. The craft window shows the real amount on that line, *n/12 Uses* or *n/12*, red when short, with the consumed icon (`ChargeUI`, wrapping `ISWidgetInput.updateValues`; the line is found by its item list). Tests in `test_uses.lua`.
- **`Uses` reaches as a craft does**: counting and taking salt, vinegar or a charged line's items now looks in the inventory, bags, and the containers and floor round the player (vanilla's `ISInventoryPaneContextMenu.getContainers`), each bag once; an item on the floor goes from its square. Outside the UI only the inventory.
- **`UI.itemSubMenu(context, item)`** (2026-11-13): the submenu named after an item that holds its recipes, so a mod's options sit with vanilla's (was Fish & Meat's `fishSubMenu`). The treat menu goes there (*Bucket > Cure Blood*), its options labelled with what the player carries and a tooltip of what it takes (`IGUI_TraditionalPreservationCore_TreatTakes`).
- **`OnHeat.watch(fullType, minutes, fn)`** (2026-11-13): food kept at frying heat (100 C) in a hot container near a player for so many minutes, after it was made, runs fn once (Fish & Meat's boiled sausage fried). Vanilla's OnCooked fires only once. Tests in `test_uses.lua`.
- **`Uses`** (2026-11-13): `Uses.count` / `Uses.take`, things used by the use (salt, vinegar) from what a character carries, part-used first, emptied salt back to the Salt mod. Was Fish & Meat's own salt charging, now shared. Tests in `test_uses.lua`.
- **`TraditionalPreservationCore.OnCreateCooked`** (`Recipes.cookOutputs`, 2026-11-13): a recipe's cookable food comes out cooked (Fish & Meat's black pudding and sausages).
- **The Hearth redesigned** (after Alpine cheese kettles): a round-bellied copper kettle, sooted black below its shoulder and blending into the copper, hanging by its bail from a Large Hook on an iron gallows (two posts set in the stone, a bar along the door's side) nearly on a small round hole in the top of the Firebox's knee-high body and iron door. The bail runs towards the door (for later). Drawn as a 100-120 L kettle; it still holds 60 L. Same tile numbers and properties, so built Hearths take the new look. The glow overlay is cut round the kettle's outline: the vents, the hole, flames curling up round the belly and a warm rim on its bottom; banked, a dull red. The copper menu icons are the kettle from the side. `tools/build_tileset.py`: the Firebox and the Hearth share `body()` (Firebox tiles byte-identical), the old waist-high sizes gone. **Build:** 8 Clay Bricks, 2 Clay, 2 Copper Sheets, 3 of Iron Bar / Metal Bar / Metal Pipe / Steel Bar, 1 Large Hook, trowel kept; Masonry 2, 10 XP; no welding (was 12 bricks, 4 clay, 1 copper sheet). `TPC.kit()` follows (test in `test_console.lua`). README, guide 6, Workshop text, DEVHELP, build tooltip.
- **Long row values wrap** (2026-11-13, a Vinegar vessel's Wort row ran past its window): `StationInfo` rows and `InfoWindow:row` wrap a value to the space beside its label (`InfoWindow.valueLines`, kept until the width changes). Test in `test_station_info.lua`.
- **Hearth attachments** (the Stone Hearth hub, step i): `Hearth.attach{ id, name, fit, canRemove, look, heats, onFire, status, menu, rows, notes }`, what is fitted on a fire, one at a time, each with its state under its id in `tpHearth` (`Hearth.partState`). The copper is the first, written against the registry alone: its rules in `Copper.lua`, its menu and Info rows in `CopperUI.lua` (moved out of `HearthUI`), its simmer an `onFire` in `HearthWorld`; its fluid functions and hooks unchanged. HearthWorld, HearthUI, Hearth Info and the pick-up rule (`Hearth.canRemove`: never while burning, the copper only empty) now go through the attachment. **The copper's state moved** from the top of `tpHearth` to `tpHearth.copper` (`Hearth.copperState(modData)`; `Hearth.copperOf(fire)` returns it as before; old saves ignored); `Hearth.fireStateOf(fire)` is the fire's own state (`TPC.fuel`, `TPC.firebox`, `TPC.flue` use it). Hearth Info's `info` gains `state` (the fire's) and `spec`; `info.copper` is still the copper's. `HearthUI.modRows` places `HearthUI.addMenu`'s rows in the copper's menu. Nothing changes in game. Tests in `test_hearth.lua`, `test_hearth_world.lua`, `test_hearth_menu.lua`.
- **A burning Hearth is too hot to pick up** (2026-11-13, in-game step 126d): the pick-up cursor said *Has items in container* for a lit or banked Hearth or Firebox; it now gives vanilla's *Too hot to pick up.*, and *Has items* only for a copper that holds something. `UI.keepInPlace`'s test may return an `InfoPanelFlags` name (`"tooHot"`) in place of true. Test in `test_hearth_menu.lua`.
- **`tp` lints shipped Lua for `goto` and labels** (2026-11-13): Kahlua is Lua 5.1 and has neither, while the luajit tests run them; `tp test` and `tp install` now fail on them, as on `next(`.
- **`tp` checks translation files** (2026-11-13): `tp test` and `tp install` fail on translation JSON that isn't valid or gives a key twice. The game refuses such a file whole, and Fish & Meat's repeated `DryCured` key stopped a save loading.
- **A paused batch has no time left** (2026-11-13, for the curve edits L6 and L7 in Yeast, Vinegar, Dairy): `Weather.batchStatus` gives `hoursLeft` nil at a rate of 0 (was a division by zero); `UI.timeText` then says *Paused here (frozen)* and a `StationInfo.block` bar *paused here (frozen)* (new strings `IGUI_TraditionalPreservationCore_Paused`, `InfoPaused`). Tests in `test_core.lua`, `test_station_info.lua`. In-game step 118 of `TESTING_GUIDE.md`.
- **Realism pass, Core part** (ROADMAP's decided picks 1b, 2a, 3a):
  - **A fire by its place (L1).** Indoors (a room, a loft, a basement) a fire still holds 28 C and banked embers 24 C whatever the weather. Under an open roof a fire adds 15 C to the season's mean (embers 10), in the open 10 C to the day's (embers 5), never past 28 and 24: a campfire in a January field no longer makes summer. New places `HearthCovered`, `HearthOpen`, `EmbersCovered`, `EmbersOpen` (`Hearth.FIRE_LIFT`, `EMBERS_LIFT`, `Hearth.firePlace`), with their words (*By a fire, under a roof*, ...). `Weather.FIXED_C` is now `Weather.FIRE_PLACES` (indoor heat, or under-place and lift); `Hearth.fireC(place, ledger)` takes the ledger for a fire outside; `Hearth.catchUp` and `Weather.showProgress` read it. A station already noted *By a fire* outside moves to its new place the next time it is seen, catching up first.
  - **An unheated room is 2 C warmer in the cold months (1b):** in full at a season mean of 10 C or below, none from 18 C (`Weather.roomTemperature`, `ROOM_LIFT`), a room and a loft; not while the grid is on (22 C), not an open roof or a basement.
  - **`Weather.frozen(celsius, sensitivity, freezeC)` (2a):** at or below a freezing point (0 C by default) work stops, on every Temperature Sensitivity but Off, under any floor. For the curve edits to come in Yeast, Dairy and Vinegar.
  - `TPC.weather()` lists a fire's heat under a roof and in the open. Tests in `test_core.lua`, `test_hearth.lua`. Goldens: Yeast's season report gains two fire columns (a January culture: 11 days by a porch fire, 20 by a campfire), Vinegar's a by-month table for fires outside, Dairy's two fire columns; every room and loft column warmer in the cold months (Yeast, Vinegar, Dairy, Fish & Meat). README, guide 6 (chapter 7 by the fire, chapter 8's month table), Workshop text, DEVGUIDE, DEVHELP. In-game step 117 of `TESTING_GUIDE.md`.
- **`Portions.weigh`** (2026-11-13, for Fish & Meat 0.4.33): weighs a portioned item without renaming it; `Portions.label` names and then weighs. Fish & Meat's crock keeps its plain name.
- **A hold at the heat** (2026-11-13, for Dairy's 20-minute scald): the copper counts the hours its fluid spends at 85 C or more since it was last poured into (`Hearth.heldHours`, `copper.held`), for every fluid. `FluidAgeing` takes a `scaldHold` (hours): a copper scalds once held that long (`updateCopper` and `copperRecord` take the held hours, was a hot flag), an item on a stove or fire counts its own hours at the scalding heat in all (`HELD_KEY` "tpHeldHot", `FluidAgeing.heldHours`; counted with the kind's ageing off too), and raw fluid poured in starts it over. A fill from the copper no longer marks the item scalded because the copper was hot: it takes the copper's record. With no hold, scalding is at once as before. `TPC.hot(minutes)`. Tests.
- **The muggy exception written down**: DEVGUIDE's exceptions to one place, one temperature now list salt fish's and charque's muggy spoiling, which reads the ten-day mean in the open air and the Smokehouse (mould and rancid fat come of days of damp warmth). Golden: Vinegar's season report gains its "Wort sours" table (Vinegar 0.2.16).
- **`UI.outputTooltips`** and **`UI.drawListTooltip`** (2026-11-13, for Fish & Meat 0.4.31): a recipe can replace the popup on a station window's Output slot, which names the script's one output even when OnCreate makes others. Wraps `ISWidgetCraftLogicInputControl.createChildren` (DEVGUIDE's wrap table). Tested from Fish & Meat's `test_ui.lua`.
- **Docs pass, sweep step G** (2026-11-12): guide 6 says what a station's window and Info window show; README: six places plus the two fire places, the loft where the Hearth cools; Workshop text: eight places with *In a shed*, the Firebox in "Good to know"; the template guide's places (two fifths, a month behind, the loft, by a fire). Golden: Fish & Meat's season report gains its loft column, and its charque report is recorded too.
- **Sweep step F** (2026-11-12): Needs Build 42.22 or newer (`versionMin`, was 42.20: everything is checked on 42.22). Workshop text and the template's mod.info and Workshop text too.
  DEVGUIDE: "Which kind of station?", the station rule (counted items in batches: `CraftLogic`, read by its window's
  info block; a liquid, one pool or a state with a past: Lua state, read by an Info window on click; storage: a
  container or the item's clock).
- **A sixth place, Enclosed: *In a shed*** (step J, 2026-11-12). A closed shed in the outside air: out of the rain and
  wind, by the day's temperature as the open air, and not warmed by the power grid. No square says it, so
  `Weather.placeOf` never returns it: a station claims it in its World entry (only Fish & Meat's Smokehouse).
  `Weather.PLACES` gains it, so every ledger built on `Weather.newLedger` gains `...Enclosed` totals, and
  `fillLedger` adds them to old saves. The place word *In a shed* (`IGUI_TraditionalPreservationCore_PlaceEnclosed`).
  Tests in `test_core.lua`; the Yeast and Dairy season reports' ledger dumps re-recorded (two new totals, the tables
  unchanged). README's place table, the guide's (page 6), DEVGUIDE (six places; the Smokehouse is no longer an
  exception). In-game step 105 of `TESTING_GUIDE.md`.
- **One wrap each, and what two mods wrote twice** (2026-11-12; nothing a player sees). New modules: `Portions` (food
  eaten from a vessel a portion at a time: `set`, `left`, `text`, `name`, `label`, `used`, and `onEat`, the one wrap
  of `ISEatFoodAction.complete` and `serverStop`; Dairy's jar and Fish & Meat's crock each wrapped it), `Handcraft`
  (`around`, `after`: the one wrap of `ISHandcraftAction.performRecipe`; Salt's shakers and Vinegar's bottles each
  wrapped it) and `Pour` (`before`, `after`, `owner`: the one wrap of `ISFluidTransferAction` start, stop and
  complete; the core's own `FluidAgeingWorld` and Dairy's World each wrapped it). Handlers run in the order nested
  wraps ran. Also `Station.near` and `Station.nearAt` (objects round a square, nearest first; `Hearth.near` is it at
  the fire's reach), `Hearth.catchUpRun` and `Hearth.updateRun` (a weather-timed craft run's catch-up and bar, as
  Yeast, Vinegar and the template each wrote them), `Container.ml` and `Container.isEmptyVessel`, and
  `Recipes.created` and `Recipes.consumed` (an OnCreate's own items). The portion texts ("%1 (%2 portions)") are the
  core's. Tests `test_portions.lua` and `test_wraps.lua`; DEVGUIDE (the list of modules, what the core already does,
  the table of vanilla wraps), README, the template. In-game steps 10 and 101 of `TESTING_GUIDE.md`.
- Guide (2026-11-12): checked line by line against the code. Hearth Info's Copper row reads of 60 L (the guide said
  20); a banked fire's wood lasts three times as long (it said 6 hours); a Firebox counts as a fire to stand by; the
  month table has a Loft column; whole chapter numbers (the Firebox is chapter 6), one form for margin notes, a
  Credits page.
- **The loft is a place** (2026-11-12, consistency sweep step H): the top storey, a room at floor 1 or higher with
  no room on the square above (`Weather.placeOf` returns `Loft`; a middle storey and a bungalow's ground floor stay
  Indoors). It reads the season's mean plus `LOFT_LIFT` (0.3) of what the season is above `LOFT_ANCHOR` (10 C), the
  sun on the roof: about 24 C in a 21 C July, a room's from October to April; 22 C while the grid is on
  (`Weather.loftTemperature`, `placeTemperature`). Every ledger keeps Loft totals; the place word is "Loft". Rule
  written into DEVGUIDE: one place, one temperature for every mod. Tests, README, guide 6, Workshop text.
- Debug console (2026-11-12): `TPC.setWeather(c, season, ground)` pretends the weather for a test (the engine's own
  temperature override, and the series' season and ground means set outright); `TPC.setWeather()` ends it. Test,
  DEVHELP, guide 6.
- Guide: no emojis (2026-11-12): the decorative bullets and margin-note marks are gone, warning signs read **Warning:**.
- Debug console (2026-11-12): `TPC.speed(x)` sets the game speed (`getGameTime():setMultiplier`), past vanilla's 40
  at the fastest button; `TPC.speed()` shows it. DEVHELP, guide 6.
- **Station info for plain stations** (2026-11-12, consistency sweep step E): `StationInfo.contents(entity)` lists a
  CraftLogic station's waiting and finished items and its running batches (with their item counts);
  `StationInfo.block(options)` builds the series' block from them: Place, Temperature and Working rate (when the
  station works by the weather), the mod's own rows, a bar a batch with the time left, then what waits, what is done
  and the note that times assume the temperature holds. Yeast's shelf, Vinegar's floor and vessel and Salt's vat use it.
- **The cellar runs a month behind** (2026-11-12, consistency sweep step D): the basement follows the ground, the
  season mean's own 30-day mean (`Weather.GROUND_HOURS`, `groundTemperature` in the series' weather, copied into
  each ledger by `Weather.season` and `Weather.getLedger`), at `BASEMENT_SWING` 0.4: about 5 C January to March,
  9 in May, 13 July to September, 9 in November. Old saves start the ground at the season they have.
  `Weather.seasonMean` takes a length. `Weather.settledMeans(year)` gives tools a long-running save's means for any
  day; every season tool starts from it. Guide 6, README, DEVGUIDE, Workshop text, template test.
- **Places, one set for the series** (2026-11-12, consistency sweep step C): a room (Sheltered) is the season's mean,
  no +10 C and no 28 C cap; **22 C while the power grid is on**, as vanilla's rooms (`Weather.GRID_ROOM_C`, `gridOn`
  copied from the series' weather). **Covered** (a roof, not a room) is a place for every mod: `Weather.placeOf`
  returns it itself (the `withCovered` flag is gone) and it reads the season's mean. The basement is
  `10 + 0.35 x (season - 10)` (`Weather.basementTemperature`; `BASEMENT_TEMPERATURE`, `SHELTER_WARMTH`,
  `SHELTER_MAX` and `shelterTemperature` are gone). By a fire and by banked embers are `Weather.FIXED_C` places;
  `Hearth.catchUp` counts them by the clock until the noted fuel runs out (lifted from Dairy's crock),
  `Hearth.notePlace` catches a run up at its old place before writing a new one; `Weather.mark` keeps the hour.
  One set of place words (`UI.placeName`, `UI.placeText`: Open air, Under an open roof, Indoors, Basement, By a fire,
  By banked embers). The test harness loads Core's translations under each mod's. Template, README, guide 6, DEVGUIDE.
- Debug console (2026-11-12, consistency sweep): `TPC.weather()` (the series' weather and each place's temperature),
  `TPC.here()`, and `TPC.kit(kind)` for `"hearth"` (default) or `"firebox"` (`TPC.fireboxKit()` is gone). DEVGUIDE
  has the console convention every TP mod follows. Tests, DEVHELP, guide.
- Docs (2026-11-12, consistency sweep): the guide and DEVGUIDE use the series' new names (Yogurt, Lard (Melted)).
- **`StationInfo`: a station's info inside vanilla's crafting window** (2026-11-12, for Fish & Meat 0.4.19): new client
  module `TraditionalPreservationCore/StationInfo`. `StationInfo.add(provider)`; `provider(entity)` returns
  `{ rows = { { labelKey, value } }, bars = { { text, share, value, colour } }, notes = { ... } }` or nil. The block
  sits under In Progress, Done and Take All, asks its provider again twice a second and has the window laid out
  again when its height changes. Wraps `ISWidgetCraftLogicOutputProgress.createDynamicChildren` and
  `.calculateLayout`, only once a mod adds a provider; a window with no block goes straight to vanilla's.
  `InfoWindow.wrapped` is shared with it. Tests in `tests/test_station_info.lua`.
- **One wrap of `ISInventoryTransferAction.transferItem` for every mod** (2026-11-12): new client module
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
- **Doors keep their front free** (Smokehouse 5b-2b test): `Doors` (shared) registers tiles with a door or
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
- A bigger copper (for realism): `Hearth.COPPER_ML` 20 L -> 60 L (real ones 40 to 100 L). Same build
  cost; heating still by the cube root of what is in it, so 10 L is unchanged and a full copper steams in about 2.75 h.
- Water boils: water or tainted water alone heats towards `WATER_FIRE_C` (110) and holds at
  `BOIL_C` (100); tainted water at the boil for `BOIL_HOURS` (10 min) turns to water. New key `boiled` in `tpHearth`
  (hours at the boil; cleared when the fire goes out, fluid is poured in or the copper is emptied). Milk and every
  other fluid still top out at 95 C. Water, let boil, steams sooner than milk. `TPC.hearth()` shows the minutes at
  the boil.
- `UI.itemName(item)` and `UI.nameHook(fn)`: an item's name in a menu, vanilla's unless a mod has a say. The Hearth's
  Pour into and Fill from the Copper menus use it (Dairy names wrapped pots).
- `Station.hotContainers(square, radius, heat, fn)`: every item container at a vanilla temperature or hotter near a
  square. `FluidAgeing.lookOnHeat` uses it; Dairy uses it to burn wraps left on the heat.
- Banked Hearth: vanilla's fire is put out while banked, since its room heat and light reach 8 tiles
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
- Empty the Copper: the Hearth's menu pours whatever the copper holds away in one go, with its
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
- Left-clicking a Hearth opens Hearth Info (after test H), as an incubator's click opens Incubator Info.
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
