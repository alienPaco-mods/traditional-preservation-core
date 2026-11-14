# Traditional Preservation (Core): developer help

These console commands load only when the game runs in **debug mode** (launch option `-debug`). Type them into the in-game Lua console, the **Command Console** window, and press Enter. Output goes to the console and to `~/Zomboid/console.txt`.

`TPC.help()` prints this list in the game. They work on the Stone Hearth, its cauldron and the Smokehouse, whichever TP mods are on.

| Command | What it does |
|---|---|
| `TPC.speed(x)` | Game speed: the clock runs `x` times as fast (`getGameTime():setMultiplier(x)`); `TPC.speed()` shows it. Vanilla's speed buttons are 1, 5, 20 and 40, and clicking one sets vanilla's speed again. |
| `TPC.kit(kind)` | Gives what a station takes: `"hearth"` (the default: the Stone Hearth's build and Fit Cauldron's kit), `"firebox"` (a mason's trowel, 8 clay bricks and 2 clay, Masonry 2), `"cauldron"` (a Forged Cauldron, 2 iron pipes, a heavy chain, a large hook and pliers), `"forge"` (Forge Cauldron's materials and tools, Blacksmith 4, and the magazine), `"smokehouse"` (a hammer, 14 planks and 20 nails, Woodwork 3), `"flue"` (both flue kits: 2 Clay Pipe Segments, 3 Flat Stones, 3 Clay, with a Mason's Trowel and a Shovel) or `"hole"` (a stove food, an oven food and a pot to fill, for the hole's looks). `TPC.kit("?")` lists them. |
| `TPC.weather()` | The series' weather as every TP mod reads it: the temperature now, the season's mean and humidity, the ground's mean (the season a month behind, which a basement follows), and each place's temperature, a fire's under an open roof and in the open too. |
| `TPC.here()` | Which place you're standing in, and its temperature. |
| `TPC.setWeather(c, season, ground)` | Pretends the weather for a test that wants a cold month or a warm day: the day's temperature `c` (the engine's own override, the one the debug menu's Climate debugger sets), the season's mean (`c` if left out) and the ground's (left alone if left out). The mods read it at their next ten-minute reading, so run the clock; `TPC.weather()` shows it then. The season drifts towards the day again as it would. `TPC.setWeather()` ends it. Not kept through a load. |
| `TPC.cauldronInfo()` | The nearest Stone Hearth with the cauldron within 2 tiles: position, fire (lit, banked or out), fuel in minutes, sprite, the cauldron's litres, fluid and heat, when it will steam, and until when the fire burns. |
| `TPC.fit()` | Fits the Cauldron on the nearest Stone Hearth now, no items taken; `TPC.fit(false)` takes off what is fitted, nothing back. |
| `TPC.cauldron(litres, c, fluid)` | Empties its cauldron and fills it: `litres` (0 leaves it empty) of `fluid` at `c` degrees. `TPC.cauldron()` is 10 L of CowMilk at 20 C; it holds 60. |
| `TPC.fuel(minutes)` | Sets the fuel of the nearest Stone Hearth, fitted or not (600, ten hours, if left out); banked, what the embers have left. Vanilla's menu still lights it. |
| `TPC.hot(minutes)` | Brings its cauldron to the steam (90 C) now, counted as having steamed that long (an hour if left out, past Dairy's 20-minute scald). `TPC.hot(0)` lets you watch a hold count up. |
| `TPC.warmth()` | Air C and light 1-6 tiles east of the nearest Stone Hearth (Cauldron) and on your square, your core heat, the firebox's heat (and its custom heat while banked), and each cookable food's heat and cooking minutes. |
| `TPC.stone()` | The nearest Stone Hearth within 2 tiles, fitted or not: position, fire, fuel in minutes, sprite, what is fitted, what is joined (its kit and side), the hole's look, and the square on its back and each flank. |
| `TPC.flue(kind, side)` | Joins the Smokehouse's flue to the nearest Stone Hearth at once, for an art check: `kind` Pipe or Stones, `side` Back, Left or Right (Back if left out); `TPC.flue()` caps it. |
| `TPC.doors()` | The tile you stand on: whether a door facing S or E could open there (its front tile free, or what blocks it: a wall edge or a sprite with `BlocksPlacement`, `solid` or `solidtrans`), and whether a registered door (Stone Hearth, Smokehouse) opens onto it. For a station the build ghost refuses beside another. |
| `TPC.smokehouse()` | Each Smokehouse tile within 3 tiles on your floor: its facing, back or door tile, the entry overlay it shows, and each Stone Hearth beside it with its flue and why it can't join (or `may join`, `joined here`). |

**Typical check of the cauldron:** `TPC.kit()`, build a Stone Hearth, Fit Cauldron (or `TPC.fit()`), `TPC.cauldron(10)`, `TPC.fuel()`, light it from vanilla's menu, and watch Stone Hearth Info count down to the steam (about 1.5 hours). `TPC.hot()` skips the wait.

**Typical check of the hole:** `TPC.kit("firebox")` and `TPC.kit("hole")`, build one, `TPC.fuel()`, light it: smoke rises out of the open hole. Put the pie in: the lid, and the smoke leaks round the door. Add the stew: the lidded pot.

**Typical check of banking:** with the fire lit and `TPC.cauldron(10, 90)`, Bank the Fire. Vanilla's flames go out and the door's vents show dull embers; Stone Hearth Info reads Banked, the fuel time triples, and the cauldron settles towards 50 C. `TPC.warmth()` shows the air warm only within 2 tiles.
