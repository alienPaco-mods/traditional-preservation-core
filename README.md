# Traditional Preservation (Core) — Build 42 prototype (v0.1.0)

**Status: experimental, not released.** Back up your save before enabling.

TP Core is the mod every Traditional Preservation mod requires (Salt, Fish, Yeast, Vinegar, Dairy). It holds what they share: the weather record and the places a station can stand in, station tracking, popups and info windows, fluids that go off, and the series' shared stations, the **Hearth**, the **Firebox** and the **Smokehouse**. On its own it adds only those three.

This file describes the mod as a player meets it. How to work on the code, the tests and the `tp` tool: `DEVGUIDE.md`.

## Install

Copy this folder's `42/` to `~/Zomboid/mods/TraditionalPreservationCore/42` (`tp install Core` does it), as a real copy rather than a symlink. Enable **Traditional Preservation (Core)** with any TP mod; it loads first (each mod's `mod.info` has `require` and `loadModAfter`).

## The Hearth

A copper kettle hung from an iron gallows (two posts and a bar) on a Large Hook, nearly on a small round hole in the top of a knee-high fieldstone firebox with an iron door: an Alpine cheese copper. It holds 60 L, though it is drawn roomier. It is a vanilla fireplace (the built tile is swapped for an `IsoFireplace`), so vanilla gives it Add Fuel, lighting, burn time, room heat and a firebox that cooks. The copper is the mod's.

**Build** (Build menu, Masonry; Masonry 2; 10 Masonry XP): 8 Clay Bricks, 2 Clay, 2 Copper Sheets, 3 Iron Bars (or Metal Bars, Metal Pipes, Steel Bars), 1 Large Hook and a mason's trowel (kept). Two facings. The posts are set in the mortar, so no welding.

**Right-click it.** Vanilla's Hearth submenu gains:

- A grey status line: `Copper: 10 / 60 L Cow's Milk (Fresh), 62 C`, or `Copper: empty`.
- **Hearth Info**: the fire (Lit, Banked or Out), a fuel bar with the time it will burn (a full bar is 12 hours), the copper's litres, what it holds, its heat, and under **Steaming** either "Yes", "in 1.2 hours", "Not yet (85 C)" or "Not while banked". Clicking the Hearth opens it too. It closes when you walk more than 6 squares away.
- **Bank the Fire** / **Stoke the Fire**, while it is lit. The loot window has it too, as a button beside vanilla's Put out Fire.
- **Pour into the Copper**: every container on you or nearby with a fluid in it. A mixture, or a fluid that doesn't go with what the copper holds, shows in red with the reason.
- **Fill from the Copper** (when it holds anything): empty containers, and ones holding the same fluid with room left.
- **Empty the Copper** (when it holds anything): pours the whole lot away, its age record with it. The hover says how
  much of what.

### The copper

- Holds **60 L** of **one fluid at a time**, any fluid. A mod can name fluids that may share it (`Hearth.blend`; Dairy's milks), and such a blend keeps its shares going in and out.
- Poured fluid mixes its temperature with what is there, by volume.
- **Lit fire:** it heats towards 95 C and **steams at 85 C**; milk and every other fluid are kept off the boil.
- **Water boils.** Water on its own heats towards 110 C and holds at **100 C**. Tainted water kept at the boil for
  **10 minutes** turns to clean water (`Hearth.BOIL_C`, `WATER_FIRE_C`, `BOIL_HOURS`, `BOILED`; the time at the boil is
  `boiled` in the copper's state and starts over when the fire goes out or more is poured in). Being let boil, water
  also steams sooner than milk.
- **Fire out:** it cools towards the temperature of the place the Hearth stands in (open air, an open roof, indoors, a loft or a basement), slowly, as the stone holds heat.
- **Banked fire:** it settles at 50 C.
- More fluid heats and cools more slowly (by the cube root of the volume; a splash counts as a litre).

| In the copper | 20 C to 85 C, fire lit | 85 C to 45 C, fire out, 20 C room |
|---|---|---|
| 5 L | about 1.2 hours | about 1.5 hours |
| 10 L | about 1.5 hours | about 1.9 hours |
| 20 L | about 1.9 hours | about 2.4 hours |
| 60 L (full) | about 2.75 hours | about 3.5 hours |

| Water in the copper | 20 C to clean, fire lit (to 100 C, then 10 minutes) |
|---|---|
| 10 L | about 1.8 hours |
| 20 L | about 2.25 hours |
| 60 L (full) | about 3.2 hours |

The copper shows empty, full or steaming in the Hearth's sprite. While the fire burns, the door's vents and the hole glow and flames curl up round the kettle; banked, they show dull embers.

Fluid filled from the copper leaves at the copper's heat. Vanilla cools a carried container to room heat within seconds, unless a mod keeps its own record (Dairy's milk does).

### Banking

**Bank the Fire** rakes a lit fire down under its ash. It burns a third of the wood, so the same fuel lasts three times as long; the copper settles at about 50 C; the firebox cooks a third as fast; the room warms only within 2 tiles (25 C) and a faint light is left. **Stoke the Fire** brings it back to a full fire. Vanilla's fire is out while banked (its heat and light would reach 8 tiles whatever the fuel), so vanilla's Light Fire gives way to Put out Fire, which unbanks it. A banked fire burnt down goes out. The mod counts the wood from the clock, away time included, and wood added counts in full.

### By a fire

Two places beyond the six of `Weather.PLACES`, which a mod must ask for (`Hearth.placeOf`; Yeast, Vinegar and Dairy do):

- **By a fire, 28 C:** any lit fire within 2 tiles on the same floor. A Hearth, a fireplace, an antique stove, a brazier or a campfire counts; an electric or gas stove never does.
- **By banked embers, 24 C:** a banked Hearth or Firebox within 2 tiles, when no full fire is in reach.

Those are a fire indoors (a room, a loft, a basement). Outside the air carries the heat off, so a fire warms the place it stands in by a lift, never past its indoor heat (`Hearth.FIRE_LIFT`, `Hearth.EMBERS_LIFT`; places `HearthCovered`, `HearthOpen`, `EmbersCovered`, `EmbersOpen`, `Hearth.firePlace`):

| Fire | Indoors | Under an open roof | In the open |
|---|---|---|---|
| Lit | 28 C | 10-day average + 15, up to 28 | the day's + 10, up to 28 |
| Banked | 24 C | 10-day average + 10, up to 24 | the day's + 5, up to 24 |

A station seen by a fire notes how long the fuel will last. While its area is unloaded the fire counts until then, and after that the place under it does.

### Picking it up

A Hearth can't be picked up while its fire burns or its copper holds anything; the pick-up cursor says so.

## The Firebox

The Hearth without its kettle and gallows: the same knee-high fieldstone, lime top and iron door on its arched mouth, with no hole in its top. Its fire shows through the door's vents. It is a vanilla fireplace as the Hearth is, so it lights, burns, cooks in its firebox and warms stations within 2 tiles ("by a fire") the same way.

**Build** (Build menu, Masonry; Masonry 2; 8 Masonry XP): 8 Clay Bricks, 2 Clay and a mason's trowel (kept). Two facings.

**Right-click it.** Vanilla's Firebox submenu gains **Firebox Info** (fire and fuel, with a note) and **Bank the Fire** / **Stoke the Fire**, which work exactly as on the Hearth (the loot-window button too). Clicking it opens Firebox Info. It can't be picked up while its fire burns, or while its flue is joined to a building.

**Its flue** leaves its top and is capped on its own: smoke leaks round the door while it burns. It can be joined to a Smokehouse beside it (below), on its back or either flank, never the door's side, with a clay pipe out of the top or a trench roofed with flat stones from its foot. The Firebox's tile then shows that flue on that side, and the smoke goes up it instead of round the door.

## The Smokehouse

Moved here from Traditional Preservation (Fish & Meat) on 2026-11-13, so every TP mod can smoke in it (Dairy's smoked cheese next). A plank shed two tiles long under one roof slope, the door on the high end; inside it is always **In a shed** (Enclosed): the day's temperature, out of rain and wind. It shows nothing hanging; a joined flue shows where it enters on the long side in view, and a ham hangs by the door while finished stacks wait inside.

**Build** (Build menu, Furniture; Woodwork 3; 15 Woodwork XP): 14 Planks, 20 Nails and a hammer (kept). Open air or under an open roof, never in a room; the tile in front of its door stays clear. 6 stacks.

**Connect the Firebox** (the Firebox's menu or the shed's right-click): a **clay pipe** (2 Clay Pipe Segments + 1 Clay, Mason's Trowel kept) or a **stone trench** (3 Flat Stones + 2 Clay, a shovel or spade kept); about half an hour, a little Masonry XP. Not at the door end, not with the Firebox's own door towards the shed, not while it burns; one Firebox a shed, one shed a Firebox. **Disconnect** gives the pipe or stones back; the clay is lost. Neither picks up while joined. Firebox Info says where its flue goes, and each mod adds what its smoke does.

**For a mod** (`shared/TraditionalPreservationCore/Smokehouse.lua`): its recipes carry the tag `Smokehouse` (`Smokehouse.RECIPES`). A stack's OnStart calls `Smokehouse.startCounters(modData, owner, hotNeed)` (owner: the mod's id); the mod's World tracks the chamber's tiles (`Tiles.CHAMBERS`, `Smokehouse.isChamber`, `Smokehouse.slotTile`) and steps **only its own stacks** (`Smokehouse.owns`), each with `Smokehouse.fireStep(modData, Smokehouse.fireOf(tile), coolShare)`: `hot` is the stoked session now running, `cold` banked hours and broken sessions' hours (by `coolShare`, the share of cool hours since the last look; a stack with `noHot` takes stoked hours as smoke at once); it returns the stoked and banked hours since the last look for the mod's own use, nil when the stack starts counting from this fire. `Smokehouse.hotDone(modData)` says when the cook is done. Its `UI.slotRules` gives `owns(entity, item)` so that in the shared shed it judges only its own items. Other stacks count against the shed's 6. The chamber's World (`server/.../SmokehouseWorld.lua`) draws the look and sets the tag; its flue is a Hearth connection (`Hearth.connect`, `Smokehouse.ID`), so Connect / Disconnect and the action `TPHearthConnect` are Core's Hearth ones; `client/.../SmokehouseUI.lua` adds the chamber's right-click and the flue's note. `TPC.kit("smokehouse")`, `TPC.kit("flue")` and `TPC.smokehouse()` in the console.

## Doors keep their front free

`Doors` (shared) keeps a list of tiles with a door or fire mouth and the way each opens (`Doors.register`): the Hearth's mouth, the Firebox's door and the Smokehouse's, every look, and mods add theirs. None is built or put down with something in front of its door: an object that blocks placing (`BlocksPlacement`, `solid`, `solidtrans`) or a wall on that edge. And nothing checked stands on a tile in front of one's door. The build menu asks `TraditionalPreservationCore.doorFits` (the entities' `OnIsValid`); putting a moveable down asks `UI.keepDoorsFree(sprites)`, where a mod adds its door-less stations (Fish's beams). Vanilla furniture isn't checked. `TPC.doors()` says what is in the way.

A picked-up Hearth or Firebox turns between its two facings as it is put down. The engine links a moveable's facings by `GroupName` + `CustomName` only for a small group, so only the plain look (empty copper, capped flue: the ones that can be picked up) carries `GroupName = Stone`.

## Places and weather

Every TP station works by the temperature of the place it stands in, from one weather record kept every 10 in-game minutes for the whole world, so stations keep working while their area is unloaded.

| Place | When | Temperature |
|---|---|---|
| **Open air** | Nothing overhead | The day's weather |
| **Under an open roof** (Covered) | A roof or floor overhead, not a room: a porch, an open shed | The average outdoor temperature of the last 10 days |
| **Indoors** (Sheltered) | A room: a map building's, or a space you built with walls all round and every square roofed | The same, **2 C warmer in the cold months**: in full at a season of 10 C or below, none from 18 C (`Weather.roomTemperature`, `ROOM_LIFT`); **22 C while the power grid is on**, as vanilla's rooms are |
| **Loft** | The top storey: a room at floor 1 or higher whose square above is in no room (`square:getSquareAbove()`) | A room's, `+ 0.3 x max(season - 10, 0)` (`Weather.loftTemperature`, `LOFT_ANCHOR`, `LOFT_LIFT`); 22 C while the grid is on |
| **Basement** | Any level below ground | `10 + 0.4 x (ground - 10)`, the ground being the 10-day average's own 30-day mean (`Weather.GROUND_HOURS`, a month behind): about 5 C January to March, 9 in May, 13 July to September, 9 in November |
| **In a shed** (Enclosed) | Never from a square: a station claims it in its World entry (the Smokehouse chamber, the only one). A closed shed in the outside air: out of the rain and wind, no thermal mass | The day's, as Open; not warmed by the grid |
| **By a fire** / **By banked embers** | A lit fire within 2 tiles on the same floor (see the Hearth) | 28 C / 24 C indoors, for as long as the fuel lasts; outside the air's plus a lift |

Every place has one word for the whole series (`UI.placeName`, `UI.placeText`: "12 C (Indoors)"). Yeast, Vinegar and Dairy count by a fire (`Hearth.placeOf`); Fish & Meat dries by its own rates.

Each mod keeps its own rate curve, and its sandbox option **Temperature sensitivity** (Off, Forgiving, Normal, Harsh) sets how much of a temperature's slowdown applies: none, half, all, or half as much again. `Weather.frozen(celsius, sensitivity, freezeC)` says whether work has stopped for the frost (at or below its freezing point, 0 C unless given): a stop outside the scaling and under any floor, the same on every setting but Off.

## Fluids that go off

Vanilla fluids never age. A mod can register a kind of fluid that does (`FluidAgeing.register`; Dairy's milk). The core then keeps an age on whatever holds it, by the place it was last seen in: a powered fridge counts as 4 C, a powered freezer stops it. Pouring hands the age on (the older wins), and fluid in the Hearth's copper ages there and is scalded once the copper has steamed for the kind's hold (`scaldHold`; Dairy's milk: 20 minutes in all, counted by `Hearth.heldHours`), as is fluid in a pot held that long on a stove or fire. With no such mod on, nothing ages.

## Seasoning afterwards

A mod can register a food that is seasoned after it is made, as a stew is (`Season.register`; Fish & Meat's sausage links). Right-click it, **Season**: each kind of seasoning it takes that you have in reach and that isn't in it yet, with the uses you have. Each kind goes in once, as many kinds as you like, takes what a stew would (a use, half an onion), and makes the food a little nicer to eat. Select several and each one that lacks it gets it. The seasoning stays with the food through what the mod does to it next.

## What it changes in vanilla

Nothing on its own beyond adding the Hearth. It wraps several vanilla Lua functions on behalf of the mods that use them (slot rules, popups, pick-up and placing checks, fluid pours, item transfers, hand crafts, eating, milking); the full table is in `DEVGUIDE.md`, "Vanilla wraps". Compare them with vanilla after a game update.

## Tuning

The copper's size, heats and time constants, the fire's reach and the banked fire's numbers are at the top of `42/media/lua/shared/TraditionalPreservationCore/Hearth.lua`. The places are at the top of `Weather.lua`, the fridge's temperature in `FluidAgeing.lua`. The build recipes are `42/media/scripts/entities/entity_TP_Hearth.txt`, `entity_TP_Firebox.txt` and `entity_Smokehouse_Chamber.txt`; the Smokehouse's flue kits and times at the top of `Smokehouse.lua`.

`python3 tools/build_tileset.py` (needs Pillow) paints the Hearth, its copper looks, the glow and the menu icons, the Firebox with its flues (capped, pipe and trench to each side) and its vent glows, the Smokehouse chamber with its flue entries and the ham (tiles 32-45, drawn as Fish & Meat drew them), and writes the generated `Tiles.lua`. `tp test Core` runs `tests/test_core.lua` (weather, places, stations), `test_hearth.lua` and `test_hearth_menu.lua`, `test_fluid_ageing.lua`, `test_doors.lua`, `test_container.lua`, `test_recipes.lua`, `test_portions.lua`, `test_uses.lua` (Uses, Charge, OnHeat, the cooked OnCreate), `test_wraps.lua` (Handcraft, Pour, `Station.near`, the recipe and container helpers), `test_smokehouse.lua` and `test_smokehouse_world.lua`, `test_console.lua` and `test_harness.lua`.

## Debug commands

In debug mode, `TPC.help()` in the Lua console lists the Hearth's and the Firebox's commands. They are described in `DEVHELP.md`.

## Known prototype caveats

- While a Hearth's area is unloaded, its copper heats only as far as the fuel it had when last seen would have lasted, then cools.
- Cooking in a banked firebox is slowed only while the area is loaded, which is also the only time vanilla cooks.
- A banked Hearth's own heat, light and firebox heat aren't saved by the game; the mod puts them back as soon as the Hearth is refreshed after a load (within a second).
- Vanilla's fuel info window (from the fuel line in the fireplace menu) says Unlit for a banked Hearth; the menu line and Hearth Info say Banked.
- The tiledef number 5173 must be unique among your active mods.
- Multiplayer is not supported. This mod is singleplayer only for now.

## Credits

Cooking sounds (`TPBoiling`, `TPSimmering`): "boiling water loops" by TinyWorlds, OpenGameArt.org, CC0.
