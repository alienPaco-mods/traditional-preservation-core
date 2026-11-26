# Traditional Preservation (Core) — Build 42 prototype (v0.1.73)

**Status: experimental, not released.** Back up your save before enabling.

TP Core is the mod every Traditional Preservation mod requires (Salt, Fish, Yeast, Vinegar, Dairy). It holds what they share: the weather record and the places a station can stand in, station tracking, popups and info windows, fluids that go off, seasoning a food after it is made, and the series' shared stations, the **Stone Hearth**, the **Forged Cauldron** fitted over it, the **Smokehouse** and the **Drying Cloth**. On its own it adds only those, and the cauldron's forge recipe.

This file describes the mod as a player meets it. How to work on the code, the tests and the `tp` tool: `DEVGUIDE.md`.

## Install

Copy this folder's `42/` to `~/Zomboid/mods/TraditionalPreservationCore/42` (`tp install Core` does it), as a real copy rather than a symlink. Enable **Traditional Preservation (Core)** with any TP mod; it loads first (each mod's `mod.info` has `require` and `loadModAfter`).

## The Stone Hearth

A knee-high block of grey dressed stone in courses under one overhanging slab, four fifths of a tile across, with an iron door on its arched mouth and a small stone-lined hole in the top. It is a vanilla fireplace (the built tile is swapped for an `IsoFireplace`), so vanilla gives it Add Fuel, lighting, burn time, room heat and cooking inside: as an oven, and a pot over the hole as on a hob. Its door's vents show the fire.

**Build** (Build menu, Masonry; Masonry 2; 8 Masonry XP): 12 Stone Blocks, 12 Clay and a mason's trowel (kept). Two facings. It is the only build recipe: the cauldron is fitted to it afterwards.

**The hole** shows what is cooking (`StoneHearth.holeLook`, by the stove or oven flag of what is inside, `StoneHearth.cooksOn`): open, with smoke rising out of it while lit; a dark forged pot with its lid on for any stove food or container holding fluid; a sooted steel lid for oven food only (the smoke then leaks round the door). Joined to a connection that takes the smoke (the Smokehouse's flue) it is never open.

**Right-click it.** Vanilla's Stone Hearth submenu gains **Stone Hearth Info** (a band for the fire, red lit, orange banked, grey out, with its buttons at its right: Bank the Fire (embers) or Stoke the Fire (a flame) while it burns, then Light the Fire (a lighter) or Put Out the Fire (a bucket of water); the Station block, its Place the place the fire makes round it (by a fire, by banked embers, or the room's own air when out, `FireUI.placeAround`); the wood as cells; a note), **Bank the Fire** / **Stoke the Fire** (the loot window has it too, a button beside vanilla's Put out Fire), **Fit Cauldron** (and **Fit Salt Pan** with Salt) and, with a Smokehouse beside it, **Connect the Stone Hearth**.

**Two slots** (`Fire.attach`, `Fire.connect`): one thing fitted over the hole (the Forged Cauldron, or Salt's salt pan: a mod's attachment brings its own whole-hearth tiles through `StoneHearth.fittedTiles`) and one thing joined to its back or a flank (the Smokehouse's flue), each free of the other. A Stone Hearth can't be picked up while it burns (too hot), while something is fitted or while something is joined; the pick-up cursor says so.

## The Forged Cauldron

A round-bellied kettle of dark forged iron, greased and blacked, sooted below its shoulder: an Alpine cheese kettle in iron. It holds 60 L, though it is drawn roomier.

**Forge Cauldron** (a vanilla forge; Blacksmith 4; 35 Blacksmithing XP): 2 Steel Sheets, 3 Charcoal, 1 Wire, with a ball-peen hammer, metalworking pliers or tongs and a metalworking chisel kept. Learned from *Everyday Smithing - May 1993* (`SmithingMag2`, added at load by `Recipes.teach`; magazines already in the world teach it too), at Blacksmith 5 with Cooking 2, or by research from the cauldron.

**Fit Cauldron** (the Stone Hearth's menu, fire out; generic `TPFireFit`): the cauldron, 2 Iron Pipes, 1 Heavy Chain, 1 Large Hook, pliers kept; 5 Blacksmithing XP. It is then the **Stone Hearth (Cauldron)**: two iron pipes in the stone, the chain slung between them, the cauldron on the hook in its middle. **Remove Cauldron** takes half as long and gives every piece back; not while the fire burns or the cauldron holds anything. A joined Smokehouse stays joined.

**Right-click the Stone Hearth (Cauldron).** Its submenu also has:

- A grey status line: `Cauldron: 10 / 60 L Cow's Milk (Fresh), 62 C`, or `Cauldron: empty`.
- **Pour into the Cauldron**: every container on you or nearby with a fluid in it. A mixture, or a fluid that doesn't go with what the cauldron holds, shows in red with the reason.
- **Fill from the Cauldron** (when it holds anything): empty containers, and ones holding the same fluid with room left.
- **Empty the Cauldron** (when it holds anything): pours the whole lot away, its age record with it. The hover says how much of what.
- **Remove Cauldron**.

The **Stone Hearth Info** window then also shows the cauldron as a tank in the colour of what it holds (its litres and fluid under it) with a thin heat bar beside it (ticks at 85 and 100, its temperature under it), and "steaming" or "steams in 1.2 hours" under both. Drag containers onto the cauldron there to pour them in; right-click it to fill a container you choose. It closes when you walk more than 6 squares away.

### The cauldron

- Holds **60 L** of **one fluid at a time**, any fluid. A mod can name fluids that may share it (`CauldronFluid.blend`; Dairy's milks), and such a blend keeps its shares going in and out.
- **Tainted water taints clean water** (`CauldronFluid.taints`): poured together, either way round and whatever the share, the whole cauldron is tainted water and must be boiled clean again. A bucket that already holds both pours in as tainted water. Pour into the Cauldron's hover says so, unless the sandbox hides tainted water.
- Poured fluid mixes its temperature with what is there, by volume.
- **Lit fire:** it heats towards 95 C and **steams at 85 C**; milk and every other fluid are kept off the boil.
- **Water boils.** Water on its own heats towards 110 C and holds at **100 C**. Tainted water kept at the boil for
  **10 minutes** turns to clean water (`CauldronFluid.BOIL_C`, `WATER_FIRE_C`, `BOIL_HOURS`, `BOILED`; the time at the boil is
  `boiled` in the cauldron's state and starts over when the fire goes out or more is poured in). Being let boil, water
  also steams sooner than milk.
- **Fire out:** it cools towards the temperature of the place the Stone Hearth stands in (open air, an open roof, a shut room, an aired room or a basement), slowly, as the stone holds heat.
- **Banked fire:** it settles at 50 C.
- More fluid heats and cools more slowly (by the cube root of the volume; a splash counts as a litre).

| In the cauldron | 20 C to 85 C, fire lit | 85 C to 45 C, fire out, 20 C room |
|---|---|---|
| 5 L | about 1.2 hours | about 1.5 hours |
| 10 L | about 1.5 hours | about 1.9 hours |
| 20 L | about 1.9 hours | about 2.4 hours |
| 60 L (full) | about 2.75 hours | about 3.5 hours |

| Water in the cauldron | 20 C to clean, fire lit (to 100 C, then 10 minutes) |
|---|---|
| 10 L | about 1.8 hours |
| 20 L | about 2.25 hours |
| 60 L (full) | about 3.2 hours |

The cauldron shows empty, full or steaming in the tile; what it holds shows in its mouth in the fluid's own colour (the tile's overlay, tinted). While the fire burns, the door's vents and the hole glow and flames curl up round the kettle; banked, they show dull embers. At 85 C or more a gentle simmer plays at the Stone Hearth.

Fluid filled from the cauldron leaves at the cauldron's heat. Vanilla cools a carried container to room heat within seconds, unless a mod keeps its own record (Dairy's milk does).

### Banking

**Bank the Fire** rakes a lit fire down under its ash. It burns a third of the wood, so the same fuel lasts three times as long; the cauldron settles at about 50 C; the firebox cooks a third as fast; the room warms only within 2 tiles (25 C) and a faint light is left. **Stoke the Fire** brings it back to a full fire. Vanilla's fire is out while banked (its heat and light would reach 8 tiles whatever the fuel), so vanilla's Light Fire gives way to Put out Fire, which unbanks it. A banked fire burnt down goes out. The mod counts the wood from the clock, away time included, and wood added counts in full. A bare Stone Hearth banks the same way.

### By a fire

Two places beyond the five of `Weather.PLACES`, which a mod must ask for (`Fire.placeOf`; Yeast, Vinegar and Dairy do):

- **By a fire, 28 C:** any lit fire within 2 tiles on the same floor. A Stone Hearth, a fireplace, an antique stove, a brazier or a campfire counts; an electric or gas stove never does.
- **By banked embers, 24 C:** a banked Stone Hearth within 2 tiles, when no full fire is in reach.

Those are a fire indoors (a shut room, a basement). With a window open, or outside, the air carries the heat off, so a fire warms the place it stands in by a lift, never past its indoor heat (`Fire.FIRE_LIFT`, `Fire.EMBERS_LIFT`; places `FiresideAiredRoom`, `FiresideCovered`, `FiresideOpen`, `EmbersAiredRoom`, `EmbersCovered`, `EmbersOpen`, `Fire.firePlace`):

| Fire | Shut room | Aired room | Under an open roof | In the open |
|---|---|---|---|---|
| Lit | 28 C | the room's + 15, up to 28 | the air's + 15, up to 28 | the air's + 10, up to 28 |
| Banked | 24 C | the room's + 10, up to 24 | the air's + 10, up to 24 | the air's + 5, up to 24 |

A station seen by a fire notes how long the fuel will last. While its area is unloaded the fire counts until then, and after that the place under it does.

## The Smokehouse

Core's, so every TP mod can smoke in it (Fish & Meat's fish and meat, and later Dairy's smoked cheese). A plank shed on four tiles, two by two, under a low pitched roof, a gable over its pair of plank doors with a sooted metal vent under the peak; inside it is always *In the Smokehouse* (`Smokehouse.PLACE`): an open roof's temperature, out of rain and wind. It shows nothing hanging; a joined flue is drawn by the shed's own overlay, the whole pipe or trench from the stone into its long side in view. While finished pieces wait inside, a look hangs by the door for each, up to three (a country ham, then a smoked chicken, then a smoked rabbit), and smoke comes out of the vent while the joined Stone Hearth burns (a plume stoked, a wisp banked).

**Build** (Build menu, Furniture; Woodwork 5; 15 Carpentry XP): 14 Planks, 20 Nails, 2 Large Hooks and a hammer (kept). Open air or under an open roof, never in a room; the two tiles in front of its doors stay clear. No crafting window: each mod hangs its pieces from the shed's right-click menu (Fish & Meat: up to 90 kg, 150 pieces, none over 12 kg).

**Connect the Stone Hearth** (the Stone Hearth's menu or the shed's right-click): a **clay pipe** out of the stone's side low down, climbing a little into the wall (2 Clay Pipe Segments + 1 Clay, Mason's Trowel kept), or a **stone trench** from its foot (3 Flat Stones + 2 Clay, a shovel or spade kept); about half a minute, 5 Masonry XP. Not at the door end, not with the Stone Hearth's own door towards the shed, not while it burns; one Stone Hearth a shed, one thing joined to a Stone Hearth. **Disconnect the Stone Hearth** gives the pipe or stones back; the clay is lost. Neither picks up while joined. Joined, the hole is lidded (or shows the pot) and the smoke goes up the flue; cooking and the cauldron carry on. The Stone Hearth window says where its flue goes, and each mod adds what its smoke does.

**For a mod** (`shared/TraditionalPreservationCore/Smokehouse.lua`): the chamber has no crafting window or slots (UiConfig `uiEnabled = false`). A mod keeps its own record of what hangs on the shed's record tile (`Smokehouse.recordTile`: the back left one, from any tile), in its movableData under its own key, with its own menu and Info window, and steps it from its World (tracking `Tiles.CHAMBERS`, `Smokehouse.isChamber`, `Smokehouse.chamberTiles`), from the record tile alone so the shed steps once. A piece's fire counters start with `Smokehouse.startCounters(state, owner, hotSmokeHoursNeeded)` (owner: the mod's id) and step with `Smokehouse.fireStep(state, Smokehouse.fireOf(tile), coolShare)`: `hotSmokeHours` is the stoked session now running, `coldSmokeHours` banked hours and broken sessions' hours (by `coolShare`, the share of cool hours since the last look; a piece with `noHotSmoke` takes stoked hours as smoke at once); it returns the stoked and banked hours since the last look for the mod's own use, nil when the piece starts counting from this fire. `Smokehouse.hotDone(state)` says when the cook is done (the counters live in `SmokehouseStacks.lua`, reached through `Smokehouse`). Each mod adds its finished pieces to the door look with `Smokehouse.countsFinished(fn)` (fn(recordTile) returns a count) and redraws the shed at once with `Smokehouse.redraw(tile)`. A mod's limits are its own (Fish & Meat's 90 kg is Fish & Meat's). The chamber's World (`server/.../SmokehouseWorld.lua`) draws the look; its flue is a Stone Hearth connection (`Fire.connect`, `Smokehouse.ID`, `smoke = true`) that draws its own sprites (`Smokehouse.entrySprite`; the stone has no flue tiles), so Connect / Disconnect and the action `TPFireConnect` are Core's Stone Hearth ones; `client/.../SmokehouseUI.lua` adds the chamber's right-click and the flue's note, and `SmokehouseUI.band(window, chamberTile)` draws a mod's Smokehouse Info band: the joined Stone Hearth's fire in the hearth's colours with its Bank / Stoke and Light / Put Out buttons (`FireUI.BANDS`, `FireUI.bandButtons`), grey No Fire when none is joined; its `tooWarm` says a banked fire is too warm for the mod's cold smoke. `TPC.kit("smokehouse")`, `TPC.kit("flue")` and `TPC.smokehouse()` in the console.

## The Drying Cloth

A Sheet spread on the floor, two Stones holding its corners down, one corner turned up: where things dry by the air of their place. Each mod brings what dries on it (Yeast's cakes, Dairy's kefir grains); on its own it takes nothing.

**Build** (Build menu, Furniture): a Sheet and 2 Stones, no skill, no tool. Anywhere on a floor, not in front of a door.

**Right-click it**: a status line (how full it is; hover for the place and each lot), **Drying Cloth Info**, **Lay <kind> on the Cloth** for each kind you carry (**One** or **All**, as many as there is room for), **Take Off the Finished Lots** and **Take Everything Off** (what isn't dry comes back as it went on). It has room for **5 batches of yeast cakes or 50 kefir grains**, in any mix (a batch takes the room of 10 grains); a lot is what one lay puts down, of one kind, with its own clock (each batch of yeast cakes its own lot, as each keeps its own age), and there can be any number of lots while there is room. The cloth draws five spots, each a fifth of its room, showing the lot that covers most of it. Clicking the cloth opens the Drying Cloth window too: the place and its temperature, how full it is, a bar for each lot with its share dried and the time left at today's temperature (or why it waits), **Take Done** and **Take All** buttons (counts in brackets), and a note. It closes when you walk more than 6 squares away.

**Drying** goes by the place's temperature (Places and weather, below), each kind by its own curve and hours: by a fire or banked embers too. **In a shut room nothing dries**: still air, the series' rule; open a window. Frost stops it as the kind's curve says. A kind may die past a heat (yeast cakes after an hour above 35 C), or go off before it dries (wet yeast cakes that go Spent): the Drying Cloth window says *Gone off*. Time counts while you're away. A cloth with anything on it can't be picked up. It lies flat as a rug: you walk over it (vanilla's rug depth, `common/media/tileDepthTextureAssignments.txt`). Spread it with a Sheet and 2 Stones in your inventory: right-click a floor, **Spread Drying Cloth**; empty, **Pick Up Drying Cloth** gives them back (no Build menu entry, not a moveable).

**For a mod** (`shared/TraditionalPreservationCore/DryingCloth.lua`): `DryingCloth.register{ name, title, types, room, perLot, hours, curve, killAbove, sprite(spot, state), layable(item), lay(items), give(lot, inventory, state) }` at load (`room`: what one piece takes of the cloth's `DryingCloth.ROOM`, 50; `perLot`: optional most pieces in a lot, 1 for a kind whose lay data is one piece's; `sprite`: the overlay for spot 0 to 4). The lots live in the object's modData `tpcCloth` (`{ lots = { lot, ... }, nextId }` in the order laid, a lot `{ id, kind, count, data, dry, heat, dead }`; a record from before the room, five slots with `false` when free, is packed on first look); `dry` and `heat` are FluidAgeing ages on the cloth's ledger (`TraditionalPreservationCoreCloth`, one process per kind), brought up to now at each look. `DryingCloth.lay` (as many as fit; returns the lot's id and the count), `take` (by id), `fits`, `roomUsed`, `update`, `status`, `state` ("wet", "dry", "dead"), `spotLots`. The World (`server/.../DryingClothWorld.lua`) records the weather into the ledger and draws each spot's overlay (the kind's `sprite`; `tools/cloth_art.py` gives `lot_spot` for the art); the menu, the window and the keep-in-place rule are `client/.../DryingClothUI.lua`; the action `TPDryingCloth`. Tiles 100 and 101. `TPC.kit("cloth")`, `TPC.cloth()` and `TPC.dryCloth(hours)` in the console.

## Doors keep their front free

`Doors` (shared) keeps a list of tiles with a door or fire mouth and the way each opens (`Doors.register`): the Stone Hearth's door and the Smokehouse's, every look, and mods add theirs. None is built or put down with something in front of its door: an object that blocks placing (`BlocksPlacement`, `solid`, `solidtrans`) or a wall on that edge. And nothing checked stands on a tile in front of one's door. The build menu asks `TraditionalPreservationCore.doorFits` (the entities' `OnIsValid`); putting a moveable down asks `UI.keepDoorsFree(sprites)`, where every mod adds its door-less stations (`Tiles.STATIONS`); every TP entity script has an `OnIsValid` that asks it (test_doors checks). Dairy's crock asks `TraditionalPreservationCore.offAppliances` (`Appliances.lua`): no stove, fridge or washer under it either. Vanilla furniture isn't checked. `TPC.doors()` says what is in the way.

A picked-up Stone Hearth turns between its two facings as it is put down. The engine links a moveable's facings by `GroupName` + `CustomName` only for a small group, so only the plain look (the open hole: the one that can be picked up) carries `GroupName = Stone`.

## Places and weather

Every TP station works by the temperature of the place it stands in, from one weather record kept every 10 in-game minutes for the whole world, so stations keep working while their area is unloaded.

| Place | When | Temperature |
|---|---|---|
| **Open air** | Nothing overhead | The hour's weather |
| **Under an open roof** (Covered) | A roof or floor overhead, not a room: a porch, an open shed | The same: a roof keeps off rain and sun, not the cold |
| **Indoors** (Sheltered, a shut room) | A room (a map building's, or a space you built with walls all round and every square roofed) with every window to the outside shut or barricaded | The average of the last 3 days (`threeDayTemperature`, `Weather.ROOM_HOURS`), **2 C warmer in the cold months** (in full from 10 C down, none from 18 C; `ROOM_LIFT`) and **stuffy in summer**, up to 2 C warmer from 18 C to 21 C (`ROOM_SUMMER_LIFT`); **22 C while the power grid is on**, as vanilla's rooms are |
| **Aired room** (AiredRoom) | A square in a room the outside air reaches within 6 steps (`Windows.AIR_STEPS`): through a window open, smashed, without its glass or an empty frame, a door to the outside open, an empty doorway (its door broken off) or a gap in the wall, not barricaded, and on through open inside doors and knocked-through walls; a wall, a shut door or a shut window stops it (`Windows.aired`: walked edge by edge; a square's answer holds for the ten-minute reading) | The day's average (`dayTemperature`, `AIRED_HOURS`), at most 1 C warmer in winter (`AIRED_LIFT`), never stuffy; 22 C while the grid is on. Anything that dries by air dries here as under a roof; in a shut room it waits |
| **Basement** | Any level below ground | `10 + 0.4 x (ground - 10)`, the ground being the 10-day average's own 30-day mean (`Weather.GROUND_HOURS`, a month behind): about 5 C January to March, 9 in May, 13 July to September, 9 in November |
| **In the Smokehouse** | Not a place: inside the Smokehouse chamber, a station's word (`Smokehouse.PLACE`) its pieces carry, never from a square. Still air, out of the rain and wind (each mod counts that) | An open roof's (`Smokehouse.AIR`, through `Weather.STATION_PLACES`) |
| **In a clamp** (StrawClamp) / **In an earthed clamp** (EarthedClamp) | Not a square's place: inside a clamp's container (Fruits and Vegetables), given by the container (`FluidAgeing.CONTAINER_PLACES`) | Halfway from the air it follows to the basement's temperature (`Weather.CLAMP_GROUND`): under straw the day's average, earthed over the 3-day average. About 1 C in January, never at -1 C in the sampled winter once earthed |
| **By a fire** / **By banked embers** | A lit fire within 2 tiles on the same floor (see the Stone Hearth) | 28 C / 24 C in a shut room, for as long as the fuel lasts; with a window open or outside the air's plus a lift |

Every place has one word for the whole series (`UI.placeName`, `UI.placeText`: "12 C (Indoors)"). Yeast, Vinegar and Dairy count by a fire (`Fire.placeOf`); Fish & Meat dries by its own rates.

Each mod keeps its own rate curve, and its sandbox option **Temperature sensitivity** (Off, Forgiving, Normal, Harsh) sets how much of a temperature's slowdown applies: none, half, all, or half as much again. `Weather.frozen(celsius, sensitivity, freezeC)` says whether work has stopped for the frost (at or below its freezing point, 0 C unless given): a stop outside the scaling and under any floor, the same on every setting but Off. `Weather.rate(curve, celsius, sensitivity, minRate, freezeC)` puts the two together: a stage's speed, 0 when frozen.

## How long food keeps, in its tooltip

A food that keeps by where it is (Fruits and Vegetables' vegetables, Fish & Meat's Potted Meat, Dairy's butter,
Yeast's culture) says in its inventory and loot tooltip how long it keeps there and how fast it ages:

> Fresh for about 50 days here, rotten in about 88 days
> 4°C (Fridge), ages 0.40 days a day

A container of a fluid that goes off (Dairy's milk and kefir, Fish & Meat's blood, Vinegar's wort) gets the same two
lines from its fluid: *Fresh for about 1.5 days here, rotten in about 3 days* for raw milk (fresh until it sours),
*Rotten in about 3 days here* once soured, or for scalded milk and blood, which never turn; sealed store milk says
*Sealed: doesn't age until it is opened*. Read-only, from `FluidAgeing.forecast` (a copy of its age brought up to now).

(Stale already: *Stale: rotten in about 3 days here*; in a freezer or frozen through, *Doesn't age here*.) A mod adds
its own lines under them: Fruits and Vegetables the storage's factors and the cure. The age is as at the item's last
look, so a container opened just now is up to date. Sandbox **Keeping in item tooltips** (Traditional Preservation
(Core), on) turns it off for a harder game, where the place is yours to judge. `ItemTooltip.lua` is the one wrap of
the tooltip's draw (Salt's brine strength goes through it too); `KeepingTooltip.lua` the keeping lines, from
`PlaceKeeping`'s read-only `keeper.forecast(item, place, factor)`.

## Fluids that go off

Vanilla fluids never age. A mod can register a kind of fluid that does (`FluidAgeing.register`; Dairy's milk). The core then keeps an age on whatever holds it, by the place it was last seen in: a powered fridge counts as 4 C, a powered freezer stops it. Pouring hands the age on (the older wins), and fluid in the Forged Cauldron ages there and is scalded once the cauldron has steamed for the kind's hold (`scaldHold`; Dairy's milk: 20 minutes in all, counted by `CauldronFluid.heldHours`), as is fluid in a pot held that long on a stove or fire. With no such mod on, nothing ages.

## Seasoning afterwards

A mod can register a food that is seasoned after it is made, as a stew is (`Season.register`; Fish & Meat's sausage links). Right-click it, **Season**: each kind of seasoning it takes that you have in reach and that isn't in it yet, with the uses you have. Each kind goes in once, as many kinds as you like, takes what a stew would (a use, half an onion), and makes the food a little nicer to eat. Select several and each one that lacks it gets it. The seasoning stays with the food through what the mod does to it next.

## Animals keep their days

Vanilla ages a penned animal a day, moves its pregnancy on a day and grows it only after a whole day of its being loaded, and each time the player comes back the pen's catch-up drops the part-day: someone who works away from the pens and comes back several times a day finds their animals no older, no nearer their birth and no bigger after days of play. TP Core keeps each animal's own count by the calendar and moves vanilla's forward when it falls behind: the age a day at a time through vanilla's own daily step (size, weight, the day's eggs), the pregnancy set to the day from its conception, back as well as forward (vanilla's catch-up can count a midnight twice and run a pregnancy ahead), so births, chicks turning hens and lambs growing up come on time however you come and go. An age is never held back, and hourly things (milk, hunger, thirst) stay vanilla's. Wild animals are left alone, and an animal is only counted while loaded: one far away catches up the hour it next loads. The animal report shows the days kept for each animal. Sandbox **Animals keep their days** (on); off, vanilla's count.

## What it changes in vanilla

Nothing on its own beyond adding its stations and the cauldron's recipe, and keeping animals' days (above). It wraps several vanilla Lua functions on behalf of the mods that use them (slot rules, popups, pick-up and placing checks, fluid pours, item transfers, hand crafts, eating, milking); the full table is in `DEVGUIDE.md`, "Vanilla wraps". Compare them with vanilla after a game update. An item only TP's recipes use (a Ceramic Jar) gets vanilla's **Craft** row on its right-click, which vanilla leaves out because it looks recipes up in its own module only.

## Compatibility

Every TP wrap calls the function it replaced, and goes in once all mods have loaded, so a mod that replaces one of these functions as its files load keeps working under TP. A mod that replaces one later, without calling the one before, switches TP's part off. In normal play an error in TP's part is printed once to the console and vanilla carries on; an error inside vanilla's code, or another mod's version of it, is raised with its own message. What the TP mods wrap:

| Vanilla function | What for |
|---|---|
| `ISInventoryTransferAction.transferItem` | Milk, butter, crocks and brine moved on and off the heat |
| `ISFluidTransferAction.start`, `stop`, `complete` | A poured fluid's age and heat |
| `ISEatFoodAction.complete`, `serverStop` | Yogurt jars and Potted Meat crocks eaten by the portion |
| `ISDrinkFluidAction.updateEat` | Kefir easing food sickness |
| `ISHandcraftAction.performRecipe` | Empty shakers and bottles given back; boiled bones smashed |
| `ISMilkAnimal.milk`, `ISGatherBloodFromAnimal.updateBucket` | A fresh age for new milk and blood |
| `ISAddItemInRecipe.complete`, `checkName` | Fish & Meat's ingredient icons and stock dish names |
| `ISToolTipInv.render` | Brine strength in a bucket's tooltip |
| `ISWidgetInput.updateValues` | A charged recipe line's real amount (Fish & Meat's filler) |
| `ISMoveableSpriteProps.canPickUpMoveable`, `getInfoPanelFlagsPerTile`, `canPlaceMoveable` | Where stations may stand, and which can't be picked up |
| `ISWorldMenuElements.ContextEntity` | Station icons in the right-click menu |
| `ISCampingMenu.doLightFireOption`, the loot window's Light Fire and Put Out buttons | A banked fire |

The Dairy, Vinegar and Salt mods also change three vanilla items' script fields at load: Yoghurt (its food values and the cup it leaves), Vinegar (the bottle it leaves) and the salt shaker (what it leaves). A mod that changes the same fields wins or loses by load order. Some vanilla lists are widened at load, keeping what was there: with Dairy, Make Cake Batter, Prepare Muffins, Make Bowl of Cereal, Churn Butter and Make Mildew Cure also take soured or scalded milk; and the magazine that teaches the forged pot also teaches the Forged Cauldron.

## Tuning

The cauldron's size, heats and time constants, the fire's reach and the banked fire's numbers are at the top of `42/media/lua/shared/TraditionalPreservationCore/CauldronFluid.lua` (the cauldron) and `Fire.lua` (the fire). The places are at the top of `Weather.lua`, the fridge's temperature in `FluidAgeing.lua`. The build recipes are `42/media/scripts/entities/entity_TP_StoneHearth.txt` (the Stone Hearth) and `entity_Smokehouse_Chamber.txt`, the cauldron and its forge recipe `42/media/scripts/TraditionalPreservationCore_Cauldron.txt`; the cauldron's fit kit in `Cauldron.lua`, the Smokehouse's flue kits and times at the top of `Smokehouse.lua`.

`python3 tools/build_tileset.py` (needs Pillow) paints the Stone Hearth (its hole open, lidded or with the pot, and its glows), the fitted cauldron's looks and its liquid overlay, the cauldron's and the menu icons, the Smokehouse (its four tiles drawn by `tools/smokehouse_tiles.py`) with its flue entries (the whole pipe or trench), the pieces by its door and the vent's smoke, and writes the generated `Tiles.lua`; `tools/build_model.py` the cauldron's ground model. `tp test Core` runs `tests/test_core.lua` (weather, places, stations), `test_fire.lua` and `test_fire_menu.lua`, `test_fluid_ageing.lua`, `test_doors.lua`, `test_container.lua`, `test_recipes.lua`, `test_portions.lua`, `test_uses.lua` (Uses, Charge, OnHeat, the cooked OnCreate), `test_wraps.lua` (Handcraft, Pour, `Station.near`, the recipe and container helpers), `test_smokehouse.lua` and `test_smokehouse_world.lua`, `test_console.lua` and `test_harness.lua`.

## Debug commands

In debug mode, `TPC.help()` in the Lua console lists the Stone Hearth's, the cauldron's and the Smokehouse's commands. They are described in `DEVHELP.md`.

## Known prototype caveats

- While a Stone Hearth's area is unloaded, its cauldron heats only as far as the fuel it had when last seen would have lasted, then cools.
- Cooking in a banked firebox is slowed only while the area is loaded, which is also the only time vanilla cooks.
- A banked Stone Hearth's own heat, light and firebox heat aren't saved by the game; the mod puts them back as soon as it is refreshed after a load (within a second).
- Vanilla's fuel info window (from the fuel line in the fireplace menu) says Unlit for a banked Stone Hearth; the menu line and the Stone Hearth window say Banked.
- The tiledef number 5173 must be unique among your active mods.
- Multiplayer is not supported. This mod is singleplayer only for now.

## Credits

Cooking sounds (`TPBoiling`, `TPSimmering`): "boiling water loops" by TinyWorlds, OpenGameArt.org, CC0.
