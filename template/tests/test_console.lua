-- Checks the debug console (__SHORT__) loads and its commands run. Run from the mod folder: luajit tests/test_console.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()

-- Engine stand-ins
function getClimateManager()
    return { getTemperature = function() return 20 end, getHumidity = function() return 50 end }
end
local loaded = {}
ScriptManager = { instance = { getCraftRecipe = function() return { Load = function(_, name, text) loaded[name] = text end } end } }
SandboxVars = { __MOD__ = { ProcessDays = 2 } }
function getCell() return { getGridSquare = function() return nil end } end
local player = H.player({ z = -1 })
function getPlayer() return player end

dofile("42/media/lua/shared/__MOD__.lua")
local M = __MOD__
H.fire("OnInitGlobalModData")
local __SHORT__, run = H.checkConsole("42/media/lua/client/__MOD__Dev.lua", "__SHORT__")

check("weather names every place", (function()
    local text = run("weather")
    for _, place in ipairs(M.PLACES) do
        if not text:find(place, 1, true) then return false end
    end
    return true
end)())
check("here says where the player stands", run("here"):find("Basement", 1, true) ~= nil)

local key = "process" .. M.PLACES[1]
local before = M.getLedger()[key] or 0
run("age", 12)
check("age adds its hours to every place", M.getLedger()[key] == before + 12)

run("fast", 2)
check("fast sets the test timer and reloads the recipe", M.PROCESS_HOURS == 2 and next(loaded) ~= nil)
run("fast")
check("fast with no number goes back to the sandbox time", M.PROCESS_HOURS == 48)

run("give", "batch", 3)
check("batches land in the inventory", #player.given == 3 and player.given[1] == "__MOD__.RawBatch")

H.done()
