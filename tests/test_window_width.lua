-- Checks InfoWindow's width-only resize outside the game: from WIDTH to MAX_WIDTH, never narrower than what the window
-- holds needs, the height left alone, the width kept per widthKey in a file once a drag ends, and a new window of the
-- same key opening at it. Run from this folder: luajit tests/test_window_width.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installGetText({})

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end
UIFont = { Small = "small" }
function getTextManager()
    return { getFontHeight = function() return 10 end, MeasureStringX = function(_, _, text) return #text * 6 end }
end
ISCollapsableWindow = H.class("ISCollapsableWindow")
ISButton = {}
function ISCollapsableWindow.update() end
-- A loaded station within reach, for update.
local square = { getX = function() return 1 end, getY = function() return 1 end, getZ = function() return 0 end }
function getCell() return { getGridSquare = function() return square end } end
IsoUtils = { DistanceTo = function() return 0 end }
local station = { getSquare = function() return square end, getObjectIndex = function() return 0 end }
local player = { isDead = function() return false end, getZ = function() return 0 end, getX = function() return 1 end,
    getY = function() return 1 end }

-- Files in ~/Zomboid/Lua, in memory: name -> text.
local files = {}
function getFileReader(name)
    if not files[name] then return nil end
    local lines = {}
    for line in string.gmatch(files[name], "[^\n]+") do table.insert(lines, line) end
    local at = 0
    return { readLine = function() at = at + 1 return lines[at] end, close = function() end }
end
function getFileWriter(name)
    files[name] = ""
    return { write = function(_, text) files[name] = files[name] .. text end, close = function() end }
end

local InfoWindow = require "TraditionalPreservationCore/InfoWindow"

-- A window as ISCollapsableWindow makes it: its two resize widgets, setResizable showing both.
local function window(type, key)
    local o = setmetatable({ Type = type, widthKey = key, width = InfoWindow.WIDTH, height = 300, station = station,
        playerObj = player, ticks = 0 }, { __index = InfoWindow })
    local function widget() return { visible = false, setVisible = function(self, visible) self.visible = visible end } end
    o.resizeWidget, o.resizeWidget2 = widget(), widget()
    function o:setResizable(resizable)
        self.resizable = resizable
        self.resizeWidget:setVisible(resizable)
        self.resizeWidget2:setVisible(resizable)
    end
    function o:setWidth(width) self.width = width end
    function o:setHeight(height) self.height = height end
    return o
end

local frame = window("RackWindow", "Fish.DryingFrame")
frame:resizeWidth()
check("a list's window resizes from its corner only", frame.resizable and frame.resizeWidget.visible
    and not frame.resizeWidget2.visible and frame.minimumWidth == InfoWindow.WIDTH)
check("and opens at WIDTH with nothing saved", frame.width == InfoWindow.WIDTH and files[InfoWindow.WIDTHS_FILE] == nil)
local drag = frame.resizeWidget.resizeFunction
drag(frame, 520.6, 900)
check("a drag sets the width only", frame.width == 520 and frame.height == 300)
drag(frame, 900, 300)
check("never past MAX_WIDTH", frame.width == InfoWindow.MAX_WIDTH)
drag(frame, 200, 300)
check("never under WIDTH", frame.width == InfoWindow.WIDTH)
frame:fitWidth(450)
drag(frame, 420, 300)
check("never under what the window needs", frame.width == 450)
drag(frame, 560, 300)

frame.resizeWidget.resizing = true
frame:update()
check("nothing is saved while dragging", files[InfoWindow.WIDTHS_FILE] == nil)
frame.resizeWidget.resizing = false
frame:update()
check("the drag's end saves the width under the key", files[InfoWindow.WIDTHS_FILE] == "Fish.DryingFrame=560\n")

local again = window("RackWindow", "Fish.DryingFrame")
again:resizeWidth()
check("a window of the same key opens at it", again.width == 560 and not again.widthToSave)
local beam = window("RackWindow", "Fish.HangingBeam")
beam:resizeWidth()
check("another key keeps its own", beam.width == InfoWindow.WIDTH)
local shelf = window("ShelfWindow")
shelf:resizeWidth()
shelf.resizeWidget.resizeFunction(shelf, 600, 300)
shelf:update()
check("without a key the window's class is the key, and both are kept",
    files[InfoWindow.WIDTHS_FILE]:find("ShelfWindow=600\n", 1, true) and files[InfoWindow.WIDTHS_FILE]:find("Fish.DryingFrame=560\n", 1, true))

-- A list's fold (art/fold_list_mock.png): open by default, kept per station type beside its width, read back by a new
-- window of the same type, and a second click opens it again.
local beam = window("RackWindow", "Fish.HangingBeam")
check("a list opens unfolded by default", not beam:isListFolded())
beam:toggleListFold()
check("a click folds it and keeps it in the file, per station type", beam:isListFolded()
    and files[InfoWindow.WIDTHS_FILE]:find("Fish.HangingBeam:folded=1\n", 1, true) ~= nil)
check("another station type keeps its own", not window("RackWindow", "Fish.DryingFrame"):isListFolded())
check("the width is kept beside it", files[InfoWindow.WIDTHS_FILE]:find("Fish.DryingFrame=560\n", 1, true) ~= nil)
check("a new window of the type opens folded", window("RackWindow", "Fish.HangingBeam"):isListFolded())
beam:toggleListFold()
check("a second click opens it, and the file forgets it", not beam:isListFolded()
    and files[InfoWindow.WIDTHS_FILE]:find("HangingBeam:folded", 1, true) == nil)

H.done()
