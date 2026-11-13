-- Checks the debug console (TPC) loads and its commands run. Run from TraditionalPreservationCore: luajit tests/test_console.lua
local H = dofile("tests/harness.lua")
local check = H.check
package.path = "42/media/lua/shared/?.lua;" .. package.path
H.installClock(100)
H.installModData()
H.installEvents()

-- No Hearth is built near the player.
function getCell() return { getGridSquare = function() return nil end } end
local player = H.player()
function getPlayer() return player end

local TPC, run = H.checkConsole("42/media/lua/client/TraditionalPreservationCoreDev.lua", "TPC")

run("kit")
local counts = {}
for _, fullType in ipairs(player.given) do counts[fullType] = (counts[fullType] or 0) + 1 end
check("kit gives a Stone Hearth and Fit Cauldron's kit", counts["Base.MasonsTrowel_Wood"] == 1 and counts["Base.ClayBrick"] == 8
    and counts["Base.Clay"] == 2 and counts["TraditionalPreservationCore.ForgedCauldron"] == 1 and counts["Base.MetalPipe"] == 2
    and counts["Base.HeavyChain"] == 1 and counts["Base.LargeHook"] == 1 and counts["Base.Pliers"] == 1)
local given = #player.given
run("kit", "cauldron")
check("kit(\"cauldron\") gives Fit Cauldron's kit", #player.given == given + 6)
given = #player.given
run("kit", "forge")
check("kit(\"forge\") gives the forging and the magazine", #player.given == given + 10)
local before = #player.given
run("kit", "firebox")
check("kit(\"firebox\") gives what a Firebox is built from", #player.given == before + 11)
check("an unknown kind lists the kits and gives nothing", run("kit", "?"):find("TPC.kit(\"firebox\")", 1, true) ~= nil
    and #player.given == before + 11)
before = #player.given
run("kit", "smokehouse")
check("kit(\"smokehouse\") gives what a Smokehouse is built from", #player.given == before + 35)
before = #player.given
run("kit", "flue")
check("kit(\"flue\") gives both flue kits and their tools", #player.given == before + 10)
before = #player.given
run("kit", "hole")
check("kit(\"hole\") gives a stove food, an oven food and a pot", #player.given == before + 3)
check("smokehouse says so when none is near", run("smokehouse"):find("No Smokehouse", 1, true) ~= nil)
local multiplier = 1
getGameTime = function()
    return { setMultiplier = function(_, x) multiplier = x end, getTrueMultiplier = function() return multiplier end }
end
check("speed sets the game's multiplier and says so", run("speed", 60):find("x60", 1, true) ~= nil and multiplier == 60)
check("speed() only shows it", run("speed"):find("x60", 1, true) ~= nil and multiplier == 60)
H.installClock(100)

-- The engine's temperature override, as the debug menu's Climate debugger uses it.
local override = {}
function override:setEnableAdmin(on) self.on = on end
function override:setAdminValue(value) self.value = value end
ClimateManager = { FLOAT_TEMPERATURE = 4 }
function getClimateManager()
    return { getClimateFloat = function(_, id) return id == 4 and override or nil end,
        getTemperature = function() return 18 end, getHumidity = function() return 0.5 end }
end
local Weather = require("TraditionalPreservationCore/Weather")
local state = Weather.shared()
state.groundTemperature = 9
run("setWeather", 4)
check("setWeather sets the engine's override and the season's mean", override.on == true and override.value == 4
    and state.seasonTemperature == 4 and state.groundTemperature == 9)
run("setWeather", 12, 6, 5)
check("and takes a season and a ground of their own", override.value == 12 and state.seasonTemperature == 6 and state.groundTemperature == 5)
run("setWeather")
check("setWeather() ends the override and leaves the means to drift", override.on == false and state.seasonTemperature == 6)

for _, command in ipairs({ "hearth", "copper", "fuel", "hot" }) do
    check(command .. " says so when no Hearth is near", run(command):find("No Hearth", 1, true) ~= nil)
end

H.done()
