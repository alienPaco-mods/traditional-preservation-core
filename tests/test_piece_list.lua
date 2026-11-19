-- Checks PieceList outside the game: the sort and its switch, names cut to fit, the list's height, its place in an
-- info window's flow, and the hover popup. Run from this folder: luajit tests/test_piece_list.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installGetText({ T_Hanging = "On the frame", IGUI_TraditionalPreservationCore_ListFurthest = "Furthest along",
    IGUI_TraditionalPreservationCore_ListLeast = "Least along", IGUI_TraditionalPreservationCore_ListProcess = "By process" })

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end

-- Engine stand-ins: every character is 6 wide and a line 10 high, so a plain row is 16 + 3 + 3 = 22 high.
UIFont = { Small = "small" }
function getTextManager()
    return { getFontHeight = function() return 10 end, MeasureStringX = function(_, _, text) return #text * 6 end }
end
local function element(o)
    function o:setX(x) self.x = x end
    function o:setY(y) self.y = y end
    function o:setWidth(width) self.width = width end
    function o:setHeight(height) self.height = height end
    function o:getWidth() return self.width end
    function o:initialise() end
    function o:instantiate() end
    function o:setVisible(visible) self.visible = visible end
    function o:getIsVisible() return self.visible ~= false end
    function o:addToUIManager() self.managed = true end
    function o:removeFromUIManager() self.managed = false end
    function o:bringToTop() end
    function o:derive(type) return setmetatable({ Type = type }, { __index = self }) end
    return o
end
ISCollapsableWindow = H.class("ISCollapsableWindow")
ISScrollingListBox = element({ Type = "ISScrollingListBox" })
function ISScrollingListBox.new(class, x, y, width, height)
    return setmetatable({ x = x, y = y, width = width, height = height, items = {} }, { __index = class })
end
function ISScrollingListBox:clear() self.items = {} end
function ISScrollingListBox:addItem(name, item)
    local entry = { text = name, item = item, index = #self.items + 1 }
    table.insert(self.items, entry)
    return entry
end
function ISScrollingListBox:isMouseOver() return self.mouseOver == true end
function ISScrollingListBox:isMouseOverScrollBar() return false end
ISComboBox = element({ Type = "ISComboBox" })
function ISComboBox:new(x, y, width, height, target, onChange)
    return setmetatable({ x = x, y = y, width = width, height = height, target = target, onChange = onChange,
        options = {}, selected = 0 }, { __index = ISComboBox })
end
function ISComboBox:addOption(text) table.insert(self.options, text) end
local popupsMade = 0
ISToolTipItemSlot = element({ Type = "ISToolTipItemSlot" })
function ISToolTipItemSlot:new(slot)
    popupsMade = popupsMade + 1
    return setmetatable({ itemSlot = slot }, { __index = ISToolTipItemSlot })
end
function ISToolTipItemSlot:setOwner(owner) self.owner = owner end

local PieceList = require "TraditionalPreservationCore/PieceList"

-- The sort: furthest along first, ties in the order given; least along first reverses it, ties still in order.
local rows = {
    { name = "Bluegill", share = 0.2, group = "Salt Dried" },
    { name = "Yellow Perch", share = 1, group = "Salt Dried" },
    { name = "Beef (Salted)", share = 0.55, order = 0.55, group = "Charque" },
    { name = "Pork (Salted)", share = 0.2, group = "Cold Smoked" },
}
local function names(list)
    local out = {}
    for _, row in ipairs(list) do table.insert(out, row.name) end
    return table.concat(out, ", ")
end
check("furthest along first, ties as given", names(PieceList.sorted(rows, "furthest")) == "Yellow Perch, Beef (Salted), Bluegill, Pork (Salted)")
check("least along first, ties still as given", names(PieceList.sorted(rows, "least")) == "Bluegill, Pork (Salted), Beef (Salted), Yellow Perch")
check("by process: groups by name, furthest along within",
    names(PieceList.sorted(rows, "process")) == "Beef (Salted), Pork (Salted), Yellow Perch, Bluegill")
check("a row without a process is refused", not pcall(PieceList.sorted, { { name = "x", share = 0 } }, "furthest"))
check("the window's rows are left as they were", rows[1].name == "Bluegill" and rows[2].name == "Yellow Perch")
check("order goes before share", names(PieceList.sorted({ { name = "a", share = 1, order = 0, group = "g" },
    { name = "b", share = 0, group = "g" } }, "furthest")) == "a, b")

-- Names cut to width: 60 wide holds 10 letters.
local owner = { fitCount = 0 }
check("a name that fits is as it is", PieceList.fit(owner, "Bluegill", 60) == "Bluegill")
check("a long one is cut with dots", PieceList.fit(owner, "Bluegill (cold)", 60) == "Bluegil...")
check("and kept for the next frame", owner.fitCache["Bluegill (cold)"] == "Bluegil..." and owner.fitCount == 2)

-- Heights: a plain row 22, one with a note 32; at least one row, at most eight plain rows, and the border's 2.
check("a plain row and one with a note", PieceList.rowHeight({}) == 22 and PieceList.rowHeight({ note = "x" }) == 32)
check("an empty list is one row high", PieceList.heightFor({}) == 24)
local many = {}
for i = 1, 20 do many[i] = { name = "Fish " .. i, share = i / 20 } end
check("twenty rows show eight and scroll", PieceList.heightFor(many) == 8 * 22 + 2)
check("three rows, one with a note, are as high as they are", PieceList.heightFor({ {}, {}, { note = "x" } }) == 22 + 22 + 32 + 2)

-- In a window: the header at y, the switch beside it, the list under it.
local window = element({ width = 360, children = {} })
function window:addChild(child) table.insert(self.children, child) end
local drawn = {}
function window:drawText(text, x, y) table.insert(drawn, { text = text, x = x, y = y }) end
local look = { padding = 10, gap = 4, barX = 120, barHeight = 12, label = { 1, 1, 1 }, value = { 1, 1, 1 },
    note = { 1, 1, 1 }, barBack = { 0, 0, 0 }, barBorder = { 0, 0, 0 } }
local nextY = PieceList.draw(window, look, 50, "On the frame", rows)
local list = window.pieceListUI
check("the list and its switch are the window's children", list and #window.children == 2 and window.children[2] == list.sort)
check("the header is drawn, the switch beside it at the right", drawn[1].text == "On the frame" and drawn[1].y == 52
    and list.sort.y == 50 and list.sort.x == 360 - 10 - PieceList.SORT_WIDTH)
check("the switch offers three sorts, furthest first", #list.sort.options == 3 and list.sort.options[3] == "By process"
    and list.sort.selected == 1)
check("the list sits under the header, inside the padding", list.y == 50 + 14 + 4 and list.x == 10 and list.width == 340)
check("its rows are sorted, its height theirs", names(list.rows) == names(rows) and list.items[1].text == "Yellow Perch"
    and list.height == 4 * 22 + 2)
check("the next y is under the list", nextY == list.y + list.height + 4)

-- The same rows table again (every frame between refreshes) lays nothing out; a new one does.
list.items[1].marked = true
PieceList.draw(window, look, 50, "On the frame", rows)
check("the same rows aren't laid out again", list.items[1].marked == true and #window.children == 2)
local fresh = { { name = "Pike", share = 0.9, note = "Cold smoke 30 of 72 h", group = "Hot Smoked" } }
PieceList.draw(window, look, 50, "On the frame", fresh)
check("new rows are", #list.items == 1 and list.items[1].text == "Pike" and list.height == 32 + 2)

-- The switch: least along first, for every list; the next draw shows it.
list.sort.selected = 2
list.sort.onChange(list.sort.target, list.sort)
PieceList.draw(window, look, 50, "On the frame", rows)
check("the switch sorts least along first", list.items[1].text == "Bluegill" and list.items[4].text == "Yellow Perch")
local other = element({ width = 360, children = {} })
other.addChild, other.drawText = window.addChild, window.drawText
PieceList.draw(other, look, 10, "On the frame", rows)
check("another window's list keeps the choice", other.pieceListUI.sort.selected == 2 and other.pieceListUI.items[1].text == "Bluegill")
list.sort.selected = 3
list.sort.onChange(list.sort.target, list.sort)
check("the switch sorts by process", list.items[1].text == "Beef (Salted)" and list.items[4].text == "Bluegill")
list.sort.selected = 1
list.sort.onChange(list.sort.target, list.sort)
check("and back", list.items[1].text == "Yellow Perch")

-- The hover: the row under the mouse shows its popup; none away from the rows or while the switch is open.
local popped
rows[2].popup = function(tooltip) popped = tooltip end
list.mouseOver, list.mouseoverselected = true, 1
list:updateTooltip()
local panel = list.popupPanel
check("hovering a row with a popup shows it", panel and panel:getIsVisible() and panel.managed and panel.owner == list)
panel.itemSlot:drawTooltip("tooltip")
check("the panel draws the row's popup", popped == "tooltip")
list.mouseoverselected = 2
list:updateTooltip()
check("a row without one hides it", not panel:getIsVisible() and not panel.managed)
list.mouseoverselected = 1
list.sort.expanded = true
list:updateTooltip()
check("none while the switch is open", not panel:getIsVisible())
list.sort.expanded = nil
list:updateTooltip()
list.mouseOver = false
list:updateTooltip()
check("none once the mouse leaves", not panel:getIsVisible() and popupsMade == 1)

-- A collapsed window hides the list and its switch, and the popup with them.
list.mouseOver = true
list:updateTooltip()
PieceList.show(window, false)
check("collapsed: list, switch and popup hidden", not list:getIsVisible() and not list.sort:getIsVisible() and not panel:getIsVisible())
PieceList.show(window, true)
check("opened again: shown", list:getIsVisible() and list.sort:getIsVisible())

H.done()
