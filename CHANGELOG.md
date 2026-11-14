# Changelog: Traditional Preservation (Core)

## 0.1.0 (in development, not released)
- **Hearth connections, the Smokehouse's flue moved onto them** (the Stone Hearth hub's step iii; user's picks 2026-11-14): `Hearth.connect{ id, kinds, kits, blocks, finds, joined, refusal, onChange, connectText, disconnectText, disconnectHelp, icon, notes }`, what is built onto a fire in its second slot, one at a time. **Its state moved** from `flue` / `flueSide` on the fire to `connected` and `{ kind, side }` under the connection's id in `tpHearth` (`Hearth.join`, `Hearth.unjoin`, `Hearth.connectedTo`, `Hearth.joinOf`, `Hearth.connectionOf`; old saves ignored: a flue laid before shows capped, lay it again). `blocks` "connection" (the Smokehouse's: the Cauldron still fits) or "both" (Fit refused while joined, `fitRefusal` "Blocked", and Connect while fitted). Core enforces one a fire, one fire a shed (the Smokehouse's own `refusal`), never the door's side and never while burning (`Hearth.connectRefusal`, `connectRefusalOf`); kits are the connection's (`Hearth.kitMissing`, `Hearth.kitBack`). The timed action `TPFlue` became Core's `TPHearthConnect` (kit ticks, XP and animation from the kit), and Connect / Disconnect are on every Stone Hearth's menu from `HearthUI` (`HearthUI.addConnect`, `addDisconnect`, also used by the chamber's right-click); a joined Stone Hearth can't be picked up (Core's rule now). `Hearth.setFlue` and `Smokehouse.connectRefusal` are gone (`Smokehouse.chamberRefusal` is the shed's part); `Smokehouse.flueOf`, `joinedChamber`, `joinedFirebox`, `fireOf`, `setFlue` unchanged, so Fish & Meat and Dairy don't change. Texts: the door-side refusal is general, new `ConnectFitted`, `FitBlocked`. `TPC.firebox()` prints what is joined; `TPC.flue` joins the Smokehouse's connection. Tests in test_hearth, test_hearth_world, test_hearth_menu, test_smokehouse, test_smokehouse_world.
- **The Stone Hearth's art: bigger, a low flue, the cauldron's look** (the hub's install 2b; user's pick 2026-11-13): its stone covers four fifths of its tile (half footprint `H` 0.32 to 0.40, `tools/build_tileset.py`), the same height; the hole, the pot and the cauldron keep their size. Tiles, build and menu icons and the mod icon redrawn.
  - **The flue climbs only a little** (user, 2026-11-13, after trying it level along the ground): the clay pipe leaves the stone's side near its foot (`PIPE_Z` 8 px), 0.2 tiles towards the viewer (`PIPE_SHIFT`), runs out to 0.46 (`PIPE_OUT`) and climbs to just over the stone's top, entering the Smokehouse's wall at 48 px (`PIPE_TOP`; the shed's entry moved down to meet it). It no longer climbs past the cauldron (`FLUE_RISE`, `PIPE_EXIT` gone), so it never meets the cauldron's pipes and a fitted Hearth needs no flue tiles: the elbow and the short rise show behind the stone's corner.
  - **The fitted look is the Forged Cauldron's** (user, 2026-11-13): the kettle in dark forged iron, greased and blacked (near black, a cool sheen on the rim), the cauldron's size unchanged; the gallows bar gone for what the fitting takes, two Metal Pipes, the Heavy Chain sagging between their tops and the Large Hook in its middle, all sooted. The menu icons are still the darkened copper's.
  - In-game step 129 of `TESTING_GUIDE.md` (INGAME_PASS 128).
  - **The stone as vanilla's stone mill** (user's style guide, 2026-11-13): grey dressed blocks in courses with dark joints, each lighter at its top (`fieldstone`), under one large flat stone that overhangs the walls a little all round and drops a soft shadow on them (`slab_top`, `CAP_OVER` 0.05, `SLAB` 7 px; was a cream lime render). The door's arch and the trench's stones in the same grey. The clay pipe runs out to 0.49 and climbs to 54 px (`PIPE_OUT`, `PIPE_TOP`; were 0.46 and 48) so the slab's overhang doesn't hide it, and the Smokehouse's entry overlay now draws the whole pipe from the stone to its wall (a fitted Hearth's tiles draw no flue, so the pipe was missing beside the cauldron; the Hearth, drawn after the shed, still hides its foot), drawn and weathered as the Hearth's own pipe was, with its collars at the elbow. **The flue is drawn once, by the shed:** the entry overlay draws the whole pipe (with its clay bedding at the stone) and the whole trench up to the stone's foot, and the Stone Hearth's flue looks (Pipe_, Stones_) now draw the same as its plain ones (`back_pipe`, `trench` gone), so nothing is drawn twice and a fitted Hearth's trench shows too.
  - **The cauldron greyer** where the soot hasn't reached, and **its ground model**: `tools/build_model.py` builds `Models_X/ForgedCauldron.glb` and its texture (the kettle alone, bail dropped over the rim; the tiles' profile and soot, at the tiles' size, 0.66 m across the belly and 0.6 m high (taller than true, as the camera squashes a model), with a thick rolled lip blotched with soot (its own strip of the texture); textured in vanilla's forged pot's greys and cloudy mottling, light iron above the soot and dark below, used as painted), `model ForgedCauldronGround` (scale 0.54) as the item's `WorldStaticModel`.
  - In-game step 130 of `TESTING_GUIDE.md` (INGAME_PASS 129).
  - **What the cauldron holds shows in its colour**: the overlay is the one thing the game tints per object (ENGINE_NOTES), so the fire's glow is now drawn into the fitted Hearth's tiles (`HEARTH_LOOKS`: Cold, Steam, Lit, LitSteam, Banked, BankedSteam; `GLOWS` gone) and the overlay is a pale surface in the kettle's mouth (`LIQUID`, the bail, hook and near pipe cut out of it), tinted each vanilla fluid's own colour, a blend's mixed by its shares (`Hearth.liquidOverlay`, `Hearth.liquidColour`, `Hearth.fluidColour`; HearthWorld's `showOverlay` sets the tint again after a load). The tiles no longer draw milk: an empty cauldron has no overlay. `Hearth.sprite(look, face, burning, banked)`; an attachment's `glow` is now `overlay(part, face, burning, banked)` returning a sprite and a tint. Tests in test_hearth, test_hearth_world. In-game step 131 (INGAME_PASS 130).
  - **The cauldron's icons** (user-approved mock `art/cauldron_icons_mock.png`): `cauldron_icon` draws the item empty and full (`Item_TPCauldron`, `Item_TPCauldronFull`: the tiles' kettle in iron, the thick lip, a milky surface when full, a near-black outline as vanilla's forged pot), `fit_icon` the Fit / Remove icon (`Item_TPCauldronFit`: the cauldron in front of the sooted pipes, chain and hook; the cauldron's `fitIcon`), all generated by `tools/build_tileset.py` in place of the darkened copper placeholders. In-game step 132 (INGAME_PASS 131).
  - **The Smokehouse rebuilt in its look** (user's mocks, `art/smokehouse_mock.png`): a flat roof (`CHAMBER_EAVE` 132 px; was one slope along the shed), its boards across the shed; the door wider (`CHAMBER_DOOR_HALF` 0.3, was 0.17) with uneven cracks where its latch side and top meet the frame, and a rope handle in a loop under the latch (drawn only: the recipe takes no rope); thicker boards as vanilla's barricades (`CHAMBER_PLANK` 0.15, was 0.11), lit along one edge, grain along them, the walls' joins about half open a crack (`CHAMBER_WALL_GAP`), the roof's and door's fewer (`CHAMBER_GAP`); the battens nailed to each board. The ham moved out to the corner (`HAM_A` -0.44) to clear the wider door. In-game step 133 (INGAME_PASS 132).
- **The Forged Cauldron, Fit and Remove, two slots** (the Stone Hearth hub's step ii, install 2a; user's design 2026-11-13; old saves ignored). The Hearth's kettle is now a **Forged Cauldron** (`TraditionalPreservationCore.ForgedCauldron`, 60 L as before; copper is kept for Dairy's cheese vat). It is forged at a vanilla forge as the forged pot is, scaled up (`Forge_TPCauldron`: 2 sheet metal, 3 charcoal, wire; ball-peen hammer, pliers or tongs, metalworking chisel kept; Blacksmith 4, 400), learned from the Smithing Magazine Vol. 2 (added at load, `Recipes.teach`; magazines already in the world teach it too), auto-learned at Blacksmith 5 and Cooking 2, or researched from the cauldron (`Recipes.researchable`). **The Hearth build recipe is gone**: a Stone Hearth is built bare and the cauldron fitted from its menu.
  - **Fit Cauldron / Remove Cauldron** (generic, timed action `TPHearthFit`): an attachment's `fit = { items, tool, ticks, removeTicks, xp, lost }`, with `fitHelp` and `fitIcon` for the menu. The cauldron's fit takes the cauldron, 2 metal pipes, a heavy chain and a large hook, with pliers kept, about an hour (Remove half that); Remove gives them all back. Neither while the fire burns, Remove not while the cauldron holds anything. `Hearth.fitRefusal`, `Hearth.fit`, `Hearth.unfit` (`attached` false: nothing, whatever the tile), `Hearth.fitBack`, `Hearth.attachments()`.
  - **Two slots** (user, 2026-11-13): an attachment (the Cauldron) and a connection (the Smokehouse's flue) go on the same Stone Hearth, each free of the other; what a connection blocks comes with `Hearth.connect` (step iii). The flue joins any Stone Hearth (`Smokehouse`, `SmokehouseUI`), and `HearthUI.addFireboxMenu` / `addFireboxNotes` rows show on a fitted one too (notes read the fire's state as `info.state`). A fitted Stone Hearth can't be picked up: Remove first. Until the art (install 2b) the fitted tile is the copper kettle's and draws no flue pipe.
  - Texts: Copper reads Cauldron (Stone Hearth (Cauldron), Pour into / Fill from / Empty the Cauldron, the notes); new Fit / Remove texts. Icons `Item_TPCauldron`, `Item_TPCauldronFull` (the copper's darkened; the real art in 2b). Console: `TPC.kit()` gives the Stone Hearth and the fit kit, `TPC.kit("cauldron")`, `TPC.kit("forge")`, `TPC.fit()` / `TPC.fit(false)`; `TPC.firebox()` and `TPC.flue` work on any Stone Hearth. Engine notes: "Magazine recipes and tinted liquid on a tile". Tests in test_hearth_menu, test_hearth_world, test_smokehouse_world, test_recipes, test_console. In-game step 128 of `TESTING_GUIDE.md` (INGAME_PASS 127), passed.
- **The Stone Hearth** (the hub's step ii, first install; user's design 2026-11-13; old saves ignored): the Firebox is renamed **Stone Hearth** and gets a stone-lined hole in its top (radius 0.09 tiles, the user's "hole D"). What shows in the hole follows its firebox (`Hearth.holeLook`): open, smoke and firelight rising out of it while lit; Base.PotForged's look set in it for any stove food or container holding fluid; a sooted steel lid with a flat bar handle for oven food only, and always when joined to a flue with no pot. A joined clay pipe now leaves the stone's side low down and climbs past the top into the wall (the Smokehouse's entry moved up to meet it, `FLUE_RISE` 24). Tiles: the Stone Hearth's 15 looks a facing (Open, Lid, Pot, and each flue and side with Lid or Pot) take the old Firebox's 10-23 and 54-69, new glows (open, pot; lit and banked) 46-53; the sheet has 128 tiles now. The Hearth is named **Stone Hearth (Copper)**; its tiles, menu and build recipe are unchanged until Fit Copper (next install).
  - **What is fitted is noted on the fire** (`tpHearth.attached`, was told by the tile): `Hearth.isHearth` is a Stone Hearth with the copper fitted, `Hearth.isFirebox` one with nothing, `Hearth.isFire` either; `Hearth.attachedTo`, `Hearth.fireFace`. A copper tile with nothing noted (put down after a pick-up) is the copper fitted, and the World notes it. An attachment may give its own `sprite(look, face)` and `glow(burning, banked, face)`.
  - **Stove or oven** (`Hearth.cooksOn(where, fullTypes...)`, `Hearth.cookedOn(item)`): every food is oven food unless a mod names it stove food. Core names vanilla's stews, soups, stir-fries and omelettes (pots, forged pots, buckets, pans, griddle). `Hearth.fireboxSprite(flue, side, hole, face)` and `Hearth.fireboxGlow(lit, banked, flue, hole, face)` take the hole.
  - Texts: Firebox reads Stone Hearth everywhere (menus, Info, flue messages, tooltip); Stone Hearth Info. Console: `TPC.kit("hole")` (a Pot of Stew, an uncooked pie and an empty Cooking Pot), `TPC.firebox()` shows the hole's look. Tests in test_hearth, test_hearth_world, test_doors, test_console.
- **The Smokehouse moved here from Fish & Meat** (user, 2026-11-13: before Dairy, so its smoked cheeses and later mods share it; old saves ignored). The chamber entity (`TraditionalPreservationCore.Smokehouse_Chamber`, same build: 14 planks, 20 nails, hammer, Woodwork 3), its art (tiles 32-45: the chamber, the flue entries, the ham; pixel for pixel Fish & Meat's, `tools/build_tileset.py`), the build icon, Connect / Disconnect the Firebox (`SmokehouseUI`, timed action `TPFlue`, the clay pipe and stone trench kits), the door, its World look (`SmokehouseWorld`: the flue's entry and the ham by the door, the `Smokehouse` recipe tag) and the fire's two counters. `Smokehouse.lua`: the chamber's tiles and sides, the flue, `startCounters(modData, owner, hotNeed)`, `owns`, `fireStep(modData, fire, coolShare)` (returns the stoked and banked hours for the mod's own use), `hotDone`, `fireOf`, `slotTile`; `TraditionalPreservationCore.notInRoom` for its build menu. **Each stack records its owner**, and each mod steps only its own (user's side note, 2026-11-13). Texts moved with new keys (`IGUI_TraditionalPreservationCore_Flue...`, `ContextMenu_TraditionalPreservationCore_Connect...`); the build tooltip names what the TP mods smoke. Console: `TPC.kit("smokehouse")`, `TPC.kit("flue")`, `TPC.smokehouse()` (was Fish & Meat's). Tests in `test_smokehouse.lua`, `test_smokehouse_world.lua`, `test_console.lua`. `tp sync` leaves the three files out.
- **`UI.slotRules` takes `owns(entity, item)`** (2026-11-13, for the shared Smokehouse): a mod judges only its own items there; any other passes on to the next mod's rules and vanilla, and an add with one in it is left to them whole.
- **Season** (user, 2026-11-13: a food seasoned afterwards, as a stew is; for Fish & Meat's sausage links): `Season.register(fullTypes, spec)`, a **Season** submenu in the food's own submenu (`SeasonUI`), each kind of seasoning in reach and not yet in it with the uses there, for every selected item of the type; timed action `TPSeason`. Each kind goes in once, no cap, taking what vanilla takes for a stew (`uses`, default 1), and makes the food `unhappy` and `boredom` nicer (a part-eaten one, its share; vanilla's spice in a stew is -2 of each). What went in is the food's own spice list (saved by the game); the bonus is kept in ModData (`tpSeasoning`). `Season.carry`, `Season.record`, `Season.apply` hand it on.
- **Fluid states (treatments)** (2026-11-13, for Fish & Meat's blood): a kind registered with `FluidAgeing` may name `states`, each with its own fluid names and `spoilHours`, and `of` for a state made of several treatments (salted and vinegared blood is Cured). A record keeps `treated` (saved inside `tpFluidAge`); `FluidAgeing.treat(owner, now, name)` adds one to fresh fluid and renames it, `FluidAgeing.untreat` drops them (fresh fluid gathered in). Pouring keeps only the treatments both sides had, as a raw share makes milk raw; fluid first seen under a state's name takes that state; a treated record never turns. `FluidAgeing.state`, `FluidAgeing.spoilHours`. A state may also have its own `kind` and `rate`, when it slows in the cold unlike the plain fluid: it ages on that ledger kind (the record's `markKind`), and a change of state loses only the stretch since the last look. A container first seen with a scalded or treated name mixed with a plain one is now renamed plain at once (it already counted as plain). Milk unchanged. Tests in `test_fluid_ageing.lua`.
  - **Treat menu** (user, 2026-11-13: what other mods can reuse goes in Core): a kind with `treatments`, `litresPerUse` and `treatMenu` gets a submenu on its containers, one option a treatment with its icon and the uses it takes (*-2 Salt*), greyed with the reason (none, spoiled, done, too few carried; new `IGUI_TraditionalPreservationCore_Treat...` texts); timed action `TPFluidTreat`; `FluidAgeing.treatRefusal`, `treatBy`, `litresIn`, `treatUses`, `treatableSpec`.
  - **`ISGatherBloodFromAnimal.updateBucket`** wrapped in `FluidAgeingWorld`, beside milking: a bucket with no blood starts a new record, fresh blood gathered onto treated blood makes it untreated.
- **TP's own cooking sounds** (user, 2026-11-13: vanilla's BoilingFood sizzles like frying): `TPBoiling` (a rolling boil, looped), the CookingSound of every TP item that boils, and `TPSimmering` (a gentle lidded simmer), looped on the Hearth's square while its copper is at 85 C or more (`HearthWorld`, a free world emitter, stopped when it cools, empties or unloads). Sound scripts in `TraditionalPreservationCore_sounds.txt`, files in `media/sound/`. Both clips: "boiling water loops" by TinyWorlds, OpenGameArt, CC0.
- **`Charge.line(amounts)`** (2026-11-13): one recipe line taking a different amount of each item (Fish & Meat's filler: 12 uses of oats or rice, or 12 grains). The line keeps the item; `onTest` wants the amount in reach, `take` (OnCreate) takes it. The craft window shows the real amount on that line, *n/12 Uses* or *n/12*, red when short, with the consumed icon (`ChargeUI`, wrapping `ISWidgetInput.updateValues`; the line is found by its item list). Tests in `test_uses.lua`.
- **`Uses` reaches as a craft does** (user, 2026-11-13): counting and taking salt, vinegar or a charged line's items now looks in the inventory, bags, and the containers and floor round the player (vanilla's `ISInventoryPaneContextMenu.getContainers`), each bag once; an item on the floor goes from its square. Outside the UI only the inventory.
- **`UI.itemSubMenu(context, item)`** (2026-11-13): the submenu named after an item that holds its recipes, so a mod's options sit with vanilla's (was Fish & Meat's `fishSubMenu`). The treat menu goes there (*Bucket > Cure Blood*), its options labelled with what the player carries and a tooltip of what it takes (`IGUI_TraditionalPreservationCore_TreatTakes`).
- **`OnHeat.watch(fullType, minutes, fn)`** (2026-11-13): food kept at frying heat (100 C) in a hot container near a player for so many minutes, after it was made, runs fn once (Fish & Meat's boiled sausage fried). Vanilla's OnCooked fires only once. Tests in `test_uses.lua`.
- **`Uses`** (2026-11-13): `Uses.count` / `Uses.take`, things used by the use (salt, vinegar) from what a character carries, part-used first, emptied salt back to the Salt mod. Was Fish & Meat's own salt charging, now shared. Tests in `test_uses.lua`.
- **`TraditionalPreservationCore.OnCreateCooked`** (`Recipes.cookOutputs`, 2026-11-13): a recipe's cookable food comes out cooked (Fish & Meat's black pudding and sausages).
- **The Hearth redesigned** (user, 2026-11-13, after Alpine cheese kettles): a round-bellied copper kettle, sooted black below its shoulder and blending into the copper, hanging by its bail from a Large Hook on an iron gallows (two posts set in the stone, a bar along the door's side) nearly on a small round hole in the top of the Firebox's knee-high body and iron door. The bail runs towards the door (user's pick, for later). Drawn as a 100-120 L kettle; it still holds 60 L. Same tile numbers and properties, so built Hearths take the new look. The glow overlay is cut round the kettle's outline: the vents, the hole, flames curling up round the belly and a warm rim on its bottom; banked, a dull red. The copper menu icons are the kettle from the side. `tools/build_tileset.py`: the Firebox and the Hearth share `body()` (Firebox tiles byte-identical), the old waist-high sizes gone. **Build:** 8 Clay Bricks, 2 Clay, 2 Copper Sheets, 3 of Iron Bar / Metal Bar / Metal Pipe / Steel Bar, 1 Large Hook, trowel kept; Masonry 2, 10 XP; no welding (was 12 bricks, 4 clay, 1 copper sheet). `TPC.kit()` follows (test in `test_console.lua`). README, guide 6, Workshop text, DEVHELP, build tooltip.
- **Long row values wrap** (2026-11-13, a Vinegar vessel's Wort row ran past its window): `StationInfo` rows and `InfoWindow:row` wrap a value to the space beside its label (`InfoWindow.valueLines`, kept until the width changes). Test in `test_station_info.lua`.
- **Hearth attachments** (user, 2026-11-13; the Stone Hearth hub, step i): `Hearth.attach{ id, name, fit, canRemove, look, heats, onFire, status, menu, rows, notes }`, what is fitted on a fire, one at a time, each with its state under its id in `tpHearth` (`Hearth.partState`). The copper is the first, written against the registry alone: its rules in `Copper.lua`, its menu and Info rows in `CopperUI.lua` (moved out of `HearthUI`), its simmer an `onFire` in `HearthWorld`; its fluid functions and hooks unchanged. HearthWorld, HearthUI, Hearth Info and the pick-up rule (`Hearth.canRemove`: never while burning, the copper only empty) now go through the attachment. **The copper's state moved** from the top of `tpHearth` to `tpHearth.copper` (`Hearth.copperState(modData)`; `Hearth.copperOf(fire)` returns it as before; old saves ignored); `Hearth.fireStateOf(fire)` is the fire's own state (`TPC.fuel`, `TPC.firebox`, `TPC.flue` use it). Hearth Info's `info` gains `state` (the fire's) and `spec`; `info.copper` is still the copper's. `HearthUI.modRows` places `HearthUI.addMenu`'s rows in the copper's menu. Nothing changes in game. Tests in `test_hearth.lua`, `test_hearth_world.lua`, `test_hearth_menu.lua`.
- **A burning Hearth is too hot to pick up** (2026-11-13, in-game step 126d): the pick-up cursor said *Has items in container* for a lit or banked Hearth or Firebox; it now gives vanilla's *Too hot to pick up.*, and *Has items* only for a copper that holds something. `UI.keepInPlace`'s test may return an `InfoPanelFlags` name (`"tooHot"`) in place of true. Test in `test_hearth_menu.lua`.
- **`tp` lints shipped Lua for `goto` and labels** (2026-11-13): Kahlua is Lua 5.1 and has neither, while the luajit tests run them; `tp test` and `tp install` now fail on them, as on `next(`.
- **`tp` checks translation files** (2026-11-13): `tp test` and `tp install` fail on translation JSON that isn't valid or gives a key twice. The game refuses such a file whole, and Fish & Meat's repeated `DryCured` key stopped a save loading.
- **A paused batch has no time left** (2026-11-13, for the curve edits L6 and L7 in Yeast, Vinegar, Dairy): `Weather.batchStatus` gives `hoursLeft` nil at a rate of 0 (was a division by zero); `UI.timeText` then says *Paused here (frozen)* and a `StationInfo.block` bar *paused here (frozen)* (new strings `IGUI_TraditionalPreservationCore_Paused`, `InfoPaused`). Tests in `test_core.lua`, `test_station_info.lua`. In-game step 118 of `TESTING_GUIDE.md`.
- **Realism pass, Core part** (user, 2026-11-13; ROADMAP's decided picks 1b, 2a, 3a):
  - **A fire by its place (L1).** Indoors (a room, a loft, a basement) a fire still holds 28 C and banked embers 24 C whatever the weather. Under an open roof a fire adds 15 C to the season's mean (embers 10), in the open 10 C to the day's (embers 5), never past 28 and 24: a campfire in a January field no longer makes summer. New places `HearthCovered`, `HearthOpen`, `EmbersCovered`, `EmbersOpen` (`Hearth.FIRE_LIFT`, `EMBERS_LIFT`, `Hearth.firePlace`), with their words (*By a fire, under a roof*, ...). `Weather.FIXED_C` is now `Weather.FIRE_PLACES` (indoor heat, or under-place and lift); `Hearth.fireC(place, ledger)` takes the ledger for a fire outside; `Hearth.catchUp` and `Weather.showProgress` read it. A station already noted *By a fire* outside moves to its new place the next time it is seen, catching up first.
  - **An unheated room is 2 C warmer in the cold months (1b):** in full at a season mean of 10 C or below, none from 18 C (`Weather.roomTemperature`, `ROOM_LIFT`), a room and a loft; not while the grid is on (22 C), not an open roof or a basement.
  - **`Weather.frozen(celsius, sensitivity, freezeC)` (2a):** at or below a freezing point (0 C by default) work stops, on every Temperature Sensitivity but Off, under any floor. For the curve edits to come in Yeast, Dairy and Vinegar.
  - `TPC.weather()` lists a fire's heat under a roof and in the open. Tests in `test_core.lua`, `test_hearth.lua`. Goldens: Yeast's season report gains two fire columns (a January culture: 11 days by a porch fire, 20 by a campfire), Vinegar's a by-month table for fires outside, Dairy's two fire columns; every room and loft column warmer in the cold months (Yeast, Vinegar, Dairy, Fish & Meat). README, guide 6 (chapter 7 by the fire, chapter 8's month table), Workshop text, DEVGUIDE, DEVHELP. In-game step 117 of `TESTING_GUIDE.md`.
- **`Portions.weigh`** (2026-11-13, for Fish & Meat 0.4.33): weighs a portioned item without renaming it; `Portions.label` names and then weighs. Fish & Meat's crock keeps its plain name.
- **A hold at the heat** (2026-11-13, for Dairy's 20-minute scald): the copper counts the hours its fluid spends at 85 C or more since it was last poured into (`Hearth.heldHours`, `copper.held`), for every fluid. `FluidAgeing` takes a `scaldHold` (hours): a copper scalds once held that long (`updateCopper` and `copperRecord` take the held hours, was a hot flag), an item on a stove or fire counts its own hours at the scalding heat in all (`HELD_KEY` "tpHeldHot", `FluidAgeing.heldHours`; counted with the kind's ageing off too), and raw fluid poured in starts it over. A fill from the copper no longer marks the item scalded because the copper was hot: it takes the copper's record. With no hold, scalding is at once as before. `TPC.hot(minutes)`. Tests.
- **The muggy exception written down** (user, 2026-11-13): DEVGUIDE's exceptions to one place, one temperature now list salt fish's and charque's muggy spoiling, which reads the ten-day mean in the open air and the Smokehouse (mould and rancid fat come of days of damp warmth). Golden: Vinegar's season report gains its "Wort sours" table (Vinegar 0.2.16).
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
- **One wrap of `ISInventoryTransferAction.transferItem` for every mod** (2026-11-12, user's pick): new client module
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
- **Doors keep their front free** (user, Smokehouse 5b-2b test): `Doors` (shared) registers tiles with a door or
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
- A bigger copper (user 2026-11-11, for realism): `Hearth.COPPER_ML` 20 L -> 60 L (real ones 40 to 100 L). Same build
  cost; heating still by the cube root of what is in it, so 10 L is unchanged and a full copper steams in about 2.75 h.
- Water boils (user 2026-11-11): water or tainted water alone heats towards `WATER_FIRE_C` (110) and holds at
  `BOIL_C` (100); tainted water at the boil for `BOIL_HOURS` (10 min) turns to water. New key `boiled` in `tpHearth`
  (hours at the boil; cleared when the fire goes out, fluid is poured in or the copper is emptied). Milk and every
  other fluid still top out at 95 C. Water, let boil, steams sooner than milk. `TPC.hearth()` shows the minutes at
  the boil.
- `UI.itemName(item)` and `UI.nameHook(fn)`: an item's name in a menu, vanilla's unless a mod has a say. The Hearth's
  Pour into and Fill from the Copper menus use it (Dairy names wrapped pots).
- `Station.hotContainers(square, radius, heat, fn)`: every item container at a vanilla temperature or hotter near a
  square. `FluidAgeing.lookOnHeat` uses it; Dairy uses it to burn wraps left on the heat.
- Banked Hearth (user 2026-11-11): vanilla's fire is put out while banked, since its room heat and light reach 8 tiles
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
- Empty the Copper (user 2026-11-11): the Hearth's menu pours whatever the copper holds away in one go, with its
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
- Left-clicking a Hearth opens Hearth Info (user, after test H), as an incubator's click opens Incubator Info.
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
