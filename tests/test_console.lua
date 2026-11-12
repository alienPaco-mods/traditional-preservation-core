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
check("kit gives what a Hearth is built from", counts["Base.MasonsTrowel_Wood"] == 1 and counts["Base.ClayBrick"] == 12
    and counts["Base.Clay"] == 4 and counts["Base.CopperSheet"] == 1)
local before = #player.given
run("kit", "firebox")
check("kit(\"firebox\") gives what a Firebox is built from", #player.given == before + 11)
check("an unknown kind lists the kits and gives nothing", run("kit", "?"):find("TPC.kit(\"firebox\")", 1, true) ~= nil
    and #player.given == before + 11)
for _, command in ipairs({ "hearth", "copper", "fuel", "hot" }) do
    check(command .. " says so when no Hearth is near", run(command):find("No Hearth", 1, true) ~= nil)
end

H.done()
