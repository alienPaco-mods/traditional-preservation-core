# Traditional Preservation (Core) — Build 42 prototype (v0.1.0)

**Status: experimental, not released.** Back up your save before enabling.

TP Core is the mod every Traditional Preservation mod requires (Salt, Fish, Yeast, Vinegar, Dairy). It holds what they share: the weather record and the places a station can stand in, station tracking, popups and info windows, fluids that go off, and the series' shared station, the **Hearth**. On its own it adds only the Hearth.

This file describes the mod as a player meets it. How to work on the code, the tests and the `tp` tool: `DEVGUIDE.md`.

## Install

Copy this folder's `42/` to `~/Zomboid/mods/TraditionalPreservationCore/42` (`tp install Core` does it), as a real copy rather than a symlink. Enable **Traditional Preservation (Core)** with any TP mod; it loads first (each mod's `mod.info` has `require` and `loadModAfter`).

## The Hearth

A waist-high block of fieldstone with an arched fire mouth and a copper pan set in its top. It is a vanilla fireplace (the built tile is swapped for an `IsoFireplace`), so vanilla gives it Add Fuel, lighting, burn time, room heat and a firebox that cooks. The copper is the mod's.

**Build** (Build menu, Masonry; Masonry 2; 10 Masonry XP): 12 Clay Bricks, 4 Clay, 1 Copper Sheet and a mason's trowel (kept). Two facings.

**Right-click it.** Vanilla's Hearth submenu gains:

- A grey status line: `Copper: 10 / 20 L Cow's Milk (Fresh), 62 C`, or `Copper: empty`.
- **Hearth Info**: the fire (Lit, Banked or Out), a fuel bar with the time it will burn (a full bar is 12 hours), the copper's litres, what it holds, its heat, and under **Steaming** either "Yes", "in 1.2 hours", "Not yet (85 C)" or "Not while banked". Clicking the Hearth opens it too. It closes when you walk more than 6 squares away.
- **Bank the Fire** / **Stoke the Fire**, while it is lit.
- **Pour into the Copper**: every container on you or nearby with a fluid in it. A mixture, or a fluid that doesn't go with what the copper holds, shows in red with the reason.
- **Fill from the Copper** (when it holds anything): empty containers, and ones holding the same fluid with room left.

### The copper

- Holds **20 L** of **one fluid at a time**, any fluid. A mod can name fluids that may share it (`Hearth.blend`; Dairy's milks), and such a blend keeps its shares going in and out.
- Poured fluid mixes its temperature with what is there, by volume.
- **Lit fire:** it heats towards 95 C and **steams at 85 C**; nothing in it quite boils.
- **Fire out:** it cools towards the temperature of the place the Hearth stands in (outdoors, under a roof or a basement), slowly, as the stone holds heat.
- **Banked fire:** it settles at 50 C.
- More fluid heats and cools more slowly (by the cube root of the volume; a splash counts as a litre).

| In the copper | 20 C to 85 C, fire lit | 85 C to 45 C, fire out, 20 C room |
|---|---|---|
| 5 L | about 1.2 hours | about 1.5 hours |
| 10 L | about 1.5 hours | about 1.9 hours |
| 20 L (full) | about 1.9 hours | about 2.4 hours |

The copper shows empty, full or steaming in the Hearth's sprite. The fire mouth glows while the fire burns and shows dull embers when it is banked.

Fluid filled from the copper leaves at the copper's heat. Vanilla cools a carried container to room heat within seconds, unless a mod keeps its own record (Dairy's milk does).

### Banking

**Bank the Fire** rakes a lit fire down under its ash. It burns a third of the wood, so the same fuel lasts three times as long; the copper settles at about 50 C; the firebox cooks a third as fast. **Stoke the Fire** brings it back to a full fire. A banked fire put out by hand, or burnt down, is no longer banked: it lights again as a full fire.

### By a fire

Two places beyond the series' three, which a mod must ask for (`Hearth.placeOf`; Dairy does):

- **By a fire, 28 C:** any lit fire within 2 tiles on the same floor. A Hearth, a fireplace, an antique stove, a brazier or a campfire counts; an electric or gas stove never does.
- **By banked embers, 24 C:** a banked Hearth within 2 tiles, when no full fire is in reach.

A station seen by a fire notes how long the fuel will last. While its area is unloaded the fire counts until then, and after that the place under it does.

### Picking it up

A Hearth can't be picked up while its fire burns or its copper holds anything; the pick-up cursor says so.

## Places and weather

Every TP station works by the temperature of the place it stands in, from one weather record kept every 10 in-game minutes for the whole world, so stations keep working while their area is unloaded.

| Place | When | Temperature |
|---|---|---|
| **Outdoors** | Nothing overhead | The day's weather |
| **Under a roof** | Any roof or floor overhead, walls or not | The average outdoor temperature of the last 10 days, plus 10 C, never above 28 C |
| **Basement** | Any level below ground | 15 C all year |

Each mod keeps its own rate curve, and its sandbox option **Temperature sensitivity** (Off, Forgiving, Normal, Harsh) sets how much of a temperature's slowdown applies: none, half, all, or half as much again.

## Fluids that go off

Vanilla fluids never age. A mod can register a kind of fluid that does (`FluidAgeing.register`; Dairy's milk). The core then keeps an age on whatever holds it, by the place it was last seen in: a powered fridge counts as 4 C, a powered freezer stops it. Pouring hands the age on (the older wins), and fluid in the Hearth's copper ages there and is scalded while the copper steams. With no such mod on, nothing ages.

## What it changes in vanilla

Nothing on its own beyond adding the Hearth. It wraps several vanilla Lua functions on behalf of the mods that use them (slot rules, popups, pick-up and placing checks, fluid pours, item transfers, milking); the full table is in `DEVGUIDE.md`, "Vanilla wraps". Compare them with vanilla after a game update.

## Tuning

The copper's size, heats and time constants, the fire's reach and the banked fire's numbers are at the top of `42/media/lua/shared/TraditionalPreservationCore/Hearth.lua`. The places are at the top of `Weather.lua`, the fridge's temperature in `FluidAgeing.lua`. The Hearth's build recipe is `42/media/scripts/entities/entity_TP_Hearth.txt`.

`python3 tools/build_tileset.py` (needs Pillow) paints the Hearth, its copper looks, the glow and the menu icons, and writes the generated `Tiles.lua`. `tp test Core` runs `tests/test_core.lua` (weather, places, stations), `test_hearth.lua` and `test_hearth_menu.lua`, `test_fluid_ageing.lua`, `test_container.lua`, `test_recipes.lua`, `test_console.lua` and `test_harness.lua`.

## Debug commands

In debug mode, `TPC.help()` in the Lua console lists the Hearth's commands. They are described in `DEVHELP.md`.

## Known prototype caveats

- While a Hearth's area is unloaded, its copper heats only as far as the fuel it had when last seen would have lasted, then cools.
- The copper can't be emptied in one go: fill containers from it. An Empty Copper option is planned.
- Cooking in a banked firebox is slowed only while the area is loaded, which is also the only time vanilla cooks.
- The tiledef number 5173 must be unique among your active mods.
- Multiplayer is not supported. This mod is singleplayer only for now.
