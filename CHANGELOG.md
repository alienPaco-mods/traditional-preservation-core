# Changelog: Traditional Preservation (Core)

## 0.1.0 (in development, not released)
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
