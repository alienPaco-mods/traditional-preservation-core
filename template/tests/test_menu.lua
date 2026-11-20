-- Checks the __STATION__'s right-click menu outside the game: put raw batches in, they work, take them out finished.
-- Run from the mod folder: luajit tests/test_menu.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installClock(10)
H.installModData()
H.installEvents()
H.installGetText()
local ui = H.installMenus()
-- Only TP files load; vanilla's (the timed action base, the window) are the stand-ins above.
local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservation") then return realRequire(name) end
end
function isClient() return false end
function getPlayer() return nil end
function getCell() return { getGridSquare = function() return nil end } end
MapObjects = { OnLoadWithSprite = function() end }
function getScriptManager() return { FindItem = function() return nil end } end

dofile("42/media/lua/shared/__MOD__.lua")
dofile("42/media/lua/server/__MOD__World.lua")
dofile("42/media/lua/shared/TimedActions/TP__STATION_TAG__.lua")
dofile("42/media/lua/client/__MOD__UI.lua")
local M = __MOD__
local Tiles = require "__MOD__/Tiles"
require("TraditionalPreservationCore/Action").removeItem = function(item) item.removed = true end

local modData = {}
local square = H.shutRoom({ getX = function() return 0 end, getY = function() return 0 end, getZ = function() return 0 end,
    isOutside = function() return false end, isInARoom = function() return true end })
local station = { getSprite = function() return { getName = function() return Tiles.STATIONS[1] end } end,
    getModData = function() return modData end, hasModData = function() return true end,
    getSquare = function() return square end }

local function raw()
    return { getFullType = function() return M.RAW end, isFavorite = function() return false end, getTex = function() return "raw" end }
end
ui.carried = { raw(), raw(), raw(), raw(), raw() }
local player = H.player()
local inventory = player:getInventory()
function inventory:containsRecursive(item) return not item.removed end
player.isTimedActionInstant = function() return false end
function getSpecificPlayer() return player end

local function stationMenu()
    local context = H.menu()
    H.fire("OnFillWorldObjectContextMenu", 0, context, { station }, false)
    return context.options[1].subOption
end

-- The menu's rows pass a nil among their arguments (vanilla's addOption keeps ten slots).
local function choose(option)
    option.onSelect(option.target, unpack(option.args, 1, 4))
end

local menu = stationMenu()
check("an Info row", menu:getOptionFromName("__STATION__ Info") ~= nil)
local put = menu:getOptionFromName("Put Raw Batches In")
check("Put In opens One and All", put and put.subOption and #put.subOption.options == 2)
choose(put.subOption.options[2])
check("All: one action for as many as fit", #ui.queued == 1 and #ui.queued[1].items == M.ROOM)
local action = ui.queued[1]
check("the action is valid", action:isValid())
action:complete()
check("they went in as one batch", #M.recordOf(station).batches == 1 and M.used(M.recordOf(station)) == M.ROOM)
check("a full station refuses its Put In row", stationMenu():getOptionFromName("Put Raw Batches In").subOption == nil)

for _ = 1, M.PROCESS_HOURS do
    H.setHours(H.hours + 1)
    M.advance(M.getLedger(), H.hours, 20)
end
ui.queued = {}
choose(stationMenu():getOptionFromName("Take Out the Finished Batches (1)"))
ui.queued[1]:complete()
check("they come out finished", #player.given == M.ROOM and player.given[1] == M.FINISHED and M.isEmpty(M.recordOf(station)))
H.done()
