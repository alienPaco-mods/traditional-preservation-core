# Traditional Preservation (Core): developer help

These console commands load only when the game runs in **debug mode** (launch option `-debug`). Type them into the in-game Lua console, the **Command Console** window, and press Enter. Output goes to the console and to `~/Zomboid/console.txt`.

`TPC.help()` prints this list in the game. They work on the Hearth and the Firebox, whichever TP mods are on.

| Command | What it does |
|---|---|
| `TPC.kit()` | Gives a mason's trowel, 12 clay bricks, 4 clay and a copper sheet: what a Hearth takes to build (Masonry 2). |
| `TPC.hearth()` | The nearest Hearth within 2 tiles: position, fire (lit, banked or out), fuel in minutes, sprite, the copper's litres, fluid and heat, when it will steam, and until when the fire burns. |
| `TPC.copper(litres, c, fluid)` | Empties its copper and fills it: `litres` (0 leaves it empty) of `fluid` at `c` degrees. `TPC.copper()` is 10 L of CowMilk at 20 C; the copper holds 60. |
| `TPC.fuel(minutes)` | Sets the fuel of the nearest Hearth or Firebox (600, ten hours, if left out); banked, what the embers have left. Vanilla's menu still lights it. |
| `TPC.hot()` | Brings its copper to the steam (90 C) now. |
| `TPC.warmth()` | Air C and light 1-6 tiles east of the nearest Hearth and on your square, your core heat, the firebox's heat (and its custom heat while banked), and each cookable food's heat and cooking minutes. |
| `TPC.fireboxKit()` | Gives a mason's trowel, 8 clay bricks and 2 clay: what a Firebox takes to build (Masonry 2). |
| `TPC.firebox()` | The nearest Firebox within 2 tiles: position, fire, fuel in minutes, sprite, its flue and side, and the square on each of its flue's sides. |
| `TPC.flue(kind, side)` | Shows its flue for an art check: `kind` Pipe or Stones, `side` Back, Left or Right (Back if left out); `TPC.flue()` caps it. The Smokehouse joins it for real. |

**Typical check of the copper:** `TPC.kit()`, build a Hearth, `TPC.copper(10)`, `TPC.fuel()`, light it from vanilla's menu, and watch Hearth Info count down to the steam (about 1.5 hours). `TPC.hot()` skips the wait.

**Typical check of the Firebox:** `TPC.fireboxKit()`, build one, `TPC.fuel()`, light it: the glow shows through the door's vents and smoke leaks round the door. `TPC.flue("Pipe", "Left")` shows a joined flue and the smoke stops.

**Typical check of banking:** with the fire lit and `TPC.copper(10, 90)`, Bank the Fire. Vanilla's flames go out and the mouth shows dull embers; Hearth Info reads Banked, the fuel time triples, and the copper settles towards 50 C. `TPC.warmth()` shows the air warm only within 2 tiles.
