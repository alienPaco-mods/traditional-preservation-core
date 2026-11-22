-- Checks the station report outside the game: a window's render read as text (band, Station block, holdings, list),
-- a station of several tiles once, a window that fails says so, and the file written on save. Run from this folder:
-- luajit tests/test_station_report.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installGetText({ IGUI_TraditionalPreservationCore_PlaceAt = "%1°C (%2)", IGUI_TraditionalPreservationCore_StationPlace = "Place",
    IGUI_TraditionalPreservationCore_Place_AiredRoom = "Aired room", Test_SectionHolds = "Holds", Test_SectionList = "On it",
    Test_Title = "Test Info", IGUI_TraditionalPreservationCore_HeatDegrees = "%1°C" })
H.installEvents()
H.installModData()

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end

UIFont = { Small = "small" }
function getGameTime()
    return { getWorldAgeHours = function() return 300.5 end, getYear = function() return 1993 end, getMonth = function() return 6 end,
        getDay = function() return 20 end, getHour = function() return 14 end, getMinutes = function() return 5 end }
end
function getTexture(name) return { name = name } end
function getCore() return { getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end } end
ISCollapsableWindow = H.class("ISCollapsableWindow")
ISCollapsableWindow.render = function() error("the frame drew") end

local Station = require "TraditionalPreservationCore/Station"
local UI = require "TraditionalPreservationCore/UI"
UI.placeName = function(place) return getText("IGUI_TraditionalPreservationCore_Place_" .. place) end
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local StationReport = require "TraditionalPreservationCore/StationReport"

local function station(x, y, kind)
    local square = { getX = function() return x end, getY = function() return y end, getZ = function() return 0 end }
    return { kind = kind, getSquare = function() return square end, getObjectIndex = function() return 0 end }
end
function getCell()
    return { getGridSquare = function(_, x, y)
        for object in pairs(Station.trackers[1].tracked) do
            local square = object:getSquare()
            if square:getX() == x and square:getY() == y then return square end
        end
    end }
end

-- A window drawing every block a real one does, and a primitive of its own.
local TestWindow = InfoWindow:derive("TestWindow")
function TestWindow:new(playerObj, isoObject)
    local o = InfoWindow.new(self, playerObj, isoObject)
    o.title = getText("Test_Title")
    return o
end
function TestWindow:refresh() self.view = { pct = "74%" } end
function TestWindow:render()
    ISCollapsableWindow.render(self)
    local y = self:band("Drying", "1 of 2 lots dry", { 0, 0, 0 }, { 0, 0, 0 })
    y = self:stationBlock(y, "icon.png", "AiredRoom", 17.4, { { "Test_Rows", "two <LINE> lines" } })
    y = self:section(y, "Test_SectionHolds")
    self:drawRect(0, y, 10, 10, 1, 1, 1, 1)
    y = self:holds(y, { { kind = "tank", name = "Wort", amount = "6.0 L", state = self.view.pct .. ", 3d", heat = { celsius = 45 },
        arrow = "1 L/day" }, { kind = "cells", name = "Lots", amount = "60%" }, { kind = "slot", name = "Add Mother", arrow = "" },
        { kind = "slot", name = "Mother", amount = "2 layers", count = "2" }, { kind = "slot", name = "Next in 3.0 L", count = "+1" },
        { kind = "cells", name = "Heaps" },
        { kind = "cells", name = "Spiked", amount = "38", counts = { { "Item_Apple", 2 }, { "media/textures/Item_Carrots.png", 1 } } } }, "Some lore.")
    y = self:pieceListBlock(y, "Test_SectionList", "2 lots", { { name = "Yeast Cakes x6", text = "74%, 3d", warning = "Too hot" },
        { name = "Kefir Grains", text = "Dry", note = "smoked 2 times" } })
    y = self:buttonRow(y, { { title = "Take All (2)" } })
    self:drawNotes(y, { "a note" })
end

local BrokenWindow = InfoWindow:derive("BrokenWindow")
function BrokenWindow:refresh() error("no record") end

local tracker = Station.tracker({ sprites = {}, refresh = function() end })
local a, b1, b2, c = station(10, 20, "test"), station(30, 40, "big"), station(31, 40, "big"), station(5, 5, "broken")
for _, object in ipairs({ a, b1, b2, c }) do tracker.track(object) end
StationReport.add(TestWindow, function(object)
    if object.kind == "test" then return object end
    if object.kind == "big" then return b1 end   -- its record tile
end)
StationReport.add(BrokenWindow, function(object) return object.kind == "broken" and object or nil end)

local playerObj = { getX = function() return 12.6 end, getY = function() return 21.2 end, getZ = function() return 0 end }
local lines = StationReport.linesOf(TestWindow, playerObj, a)
local text = table.concat(lines, "\n")
check("the band as its word in capitals and its text", lines[1] == "DRYING: 1 of 2 lots dry")
check("the Station block's Place row", text:find("Place: 17°C (Aired room)", 1, true) ~= nil)
check("a window's own Station row, its rich text plain", text:find("Test_Rows: two / lines", 1, true) ~= nil)
check("a section's header", text:find("\nHolds:\n", 1, true) ~= nil)
check("a tank with its amount, state, heat and arrow", text:find("  Wort: 6.0 L, 74%, 3d, 45°C -> 1 L/day", 1, true) ~= nil)
check("cells with their amount", text:find("  Lots: 60%", 1, true) ~= nil)
check("an empty slot: what it says, no dangling colon", text:find("\n  Slot: Add Mother\n", 1, true) ~= nil)
check("a filled slot: its count and amount", text:find("  Slot: Mother (2), 2 layers", 1, true) ~= nil
    and text:find("  Slot: Next in 3.0 L (+1)", 1, true) ~= nil)
check("a holding with nothing to say: its name alone", text:find("\n  Heaps\n", 1, true) ~= nil)
check("counts as the item its icon names, then its count", text:find("  Spiked: 38, Apple x2, Carrots x1", 1, true) ~= nil)
check("the lore is left out", text:find("lore", 1, true) == nil)
check("the list's header and rows, a warning and a note", text:find("On it:\n2 lots\n  - Yeast Cakes x6: 74%, 3d [Too hot]\n"
    .. "  - Kefir Grains: Dry (smoked 2 times)", 1, true) ~= nil)
check("buttons and notes are left out", text:find("Take All", 1, true) == nil and text:find("a note", 1, true) == nil)
check("the frame is put back after", select(1, pcall(ISCollapsableWindow.render)) == false)

local broken = StationReport.linesOf(BrokenWindow, playerObj, c)
check("a window that fails says so in its place", #broken == 1 and broken[1]:find("couldn't be read", 1, true) ~= nil)

function getWorld() return { getWorld = function() return "TPLongGame" end } end
local report = StationReport.text(playerObj)
check("the header: the save, the date and hours, the player", report:find("save TPLongGame", 1, true) ~= nil
    and report:find("In game: 1993-07-21 14:05, day 13 (hours=300.50)", 1, true) ~= nil
    and report:find("Player at 12, 21, 0", 1, true) ~= nil)
local _, blocks = report:gsub("\n== ", "")
check("three stations: the two-tile one once", blocks == 3 and report:find("Stations loaded: 3", 1, true) ~= nil)
check("by title, then west to east", report:find("== BrokenWindow (5, 5, 0)", 1, true) < report:find("== Test Info (10, 20, 0)", 1, true)
    and report:find("== Test Info (10, 20, 0)", 1, true) < report:find("== Test Info (30, 40, 0)", 1, true))

local written = {}
function getPlayer() return playerObj end
function getFileWriter(name, create, append)
    written.name, written.append = name, append
    return { write = function(_, body) written.body = body end, close = function() written.closed = true end }
end
H.fire("OnSave")
check("written on save, by the save's name, not appended", written.name == "TraditionalPreservationStations_TPLongGame.txt"
    and written.append == false and written.closed and written.body == report)

H.done()
