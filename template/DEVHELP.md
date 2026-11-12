# Traditional Preservation (__NAME__): developer help

These console commands load only when the game runs in **debug mode** (launch option `-debug`). Type them into the in-game Lua console and press Enter. Output goes to the console and to `~/Zomboid/console.txt`.

`__SHORT__.help()` prints this list in the game.

| Command | What it does |
|---|---|
| `__SHORT__.weather()` | The temperature outdoors, under a roof and in a basement, how fast a batch works in each, and how many days it takes there. |
| `__SHORT__.here()` | Which kind of place you're standing in. |
| `__SHORT__.age(hours)` | Gives every station this many hours of perfect weather. `__SHORT__.age(72)` finishes a batch. |
| `__SHORT__.fast(hours)` | Test timer: a batch takes this many hours. `__SHORT__.fast()` goes back to the sandbox time. |
| `__SHORT__.give(name, n)` | Spawns `n` of: `"batch"` (a raw batch). `__SHORT__.give()` lists them. |

**Typical check:** `__SHORT__.give("batch", 4)`, load the station and press Craft, then `__SHORT__.age(72)`.
