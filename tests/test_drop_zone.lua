-- Checks DropZone outside the game: its place in an info window, the judgement of a drag (once a drag), and what a
-- release does. Run from this folder: luajit tests/test_drop_zone.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installGetText({})

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end

-- Engine stand-ins: every character is 6 wide and a line 10 high.
UIFont = { Small = "small" }
function getTextManager()
    return { getFontHeight = function() return 10 end, MeasureStringX = function(_, _, text) return #text * 6 end }
end
ISCollapsableWindow = H.class("ISCollapsableWindow")
ISPanel = { Type = "ISPanel" }
function ISPanel:derive(type) return setmetatable({ Type = type }, { __index = self }) end
function ISPanel.new(class, x, y, width, height)
    return setmetatable({ x = x, y = y, width = width, height = height }, { __index = class })
end
function ISPanel:initialise() end
function ISPanel:instantiate() end
function ISPanel:setY(y) self.y = y end
function ISPanel:setVisible(visible) self.visible = visible end
function ISPanel:getIsVisible() return self.visible ~= false end
function ISPanel:isMouseOver() return self.mouseOver == true end
local drawn, fills = {}, {}
function ISPanel:drawRect(_, _, _, _, _, r, g, b) table.insert(fills, { r, g, b }) end
function ISPanel:drawTextCentre(text) table.insert(drawn, text) end
ISMouseDrag = {}
ISInventoryPane = { getActualItems = function(dragging) return dragging.items end }
local halos = {}
HaloTextHelper = { addBadText = function(player, text) table.insert(halos, { player, text }) end }

local DropZone = require "TraditionalPreservationCore/DropZone"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"

local window = { width = 360, children = {}, playerObj = "player" }
function window:addChild(child) table.insert(self.children, child) end
window.dropZone = InfoWindow.dropZone

local judged, dropped = 0, nil
local function judge(items)
    judged = judged + 1
    local take = {}
    for _, item in ipairs(items) do
        if item ~= "apple" then table.insert(take, item) end
    end
    return { take = take, lines = { #take .. " of " .. #items }, refused = #take < #items and "Not that" or nil }
end
local function drop(take) dropped = take end

local nextY = window:dropZone(200, "Drag fish here", judge, drop)
local zone = window.dropZoneUI
check("the square is the window's child, inside the padding, at y", zone and #window.children == 1 and zone.x == 10
    and zone.width == 340 and zone.y == 200)
check("the next y is under it", nextY == 200 + DropZone.HEIGHT + InfoWindow.BAR_GAP)
window:dropZone(240, "Drag fish here", judge, drop)
check("drawn again it moves, it isn't made again", #window.children == 1 and zone.y == 240)

zone:render()
check("at rest it says what it takes", drawn[#drawn] == "Drag fish here" and judged == 0)

-- Dragging two fish and an apple over it.
ISMouseDrag.dragging = { items = { "fish", "fish", "apple" } }
zone.mouseOver = true
drawn = {}
zone:render()
zone:render()
check("held over it, the drag is judged once, and its lines shown", judged == 1 and drawn[1] == "2 of 3" and drawn[2] == "2 of 3")
local function shown(colour)
    for _, fill in ipairs(fills) do
        if fill[1] == colour[1] and fill[2] == colour[2] and fill[3] == colour[3] then return true end
    end
    return false
end
check("some taken, some refused: orange", shown(DropZone.SOME_FILL) and not shown(DropZone.OK_FILL))
ISMouseDrag.dragging = { items = { "fish" } }
zone.mouseOver, fills = true, {}
zone:render()
check("all taken: green", shown(DropZone.OK_FILL) and not shown(DropZone.SOME_FILL))
ISMouseDrag.dragging = { items = { "apple" } }
fills = {}
zone:render()
check("none taken: red", shown(DropZone.NO_FILL))
ISMouseDrag.dragging = { items = { "fish", "fish", "apple" } }
zone.mouseOver = false
drawn = {}
zone:render()
check("dragged elsewhere, it is at rest again", drawn[1] == "Drag fish here")

zone:onMouseUp(5, 5)
check("released: it takes what it takes, and the rest's reason shows over the player", dropped and #dropped == 2
    and halos[1][1] == "player" and halos[1][2] == "Not that")
ISMouseDrag.dragging = { items = { "apple" } }
dropped = nil
zone:onMouseUp(5, 5)
check("nothing taken: nothing dropped, the reason shown", dropped == nil and halos[2][2] == "Not that")
ISMouseDrag.dragging = nil
zone:onMouseUp(5, 5)
check("a plain click does nothing", dropped == nil and #halos == 2)

DropZone.show(window, false)
check("a collapsed window hides it", not zone:getIsVisible())

H.done()
