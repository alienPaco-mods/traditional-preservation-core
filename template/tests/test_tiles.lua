-- Checks the generated Tiles.lua against the entity scripts. Run from the mod folder: luajit tests/test_tiles.lua
local H = dofile((os.getenv("TPCORE") or "../_tpcore") .. "/tests/harness.lua")
H.useModPaths()
H.checkTiles(require "__MOD__/Tiles")
H.done()
