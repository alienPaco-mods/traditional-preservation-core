-- Checks PieceList outside the game: the sort and its switch, the tabs, names cut to fit, the list's height, its
-- place in an info window's flow, and the hover popup. Run from this folder: luajit tests/test_piece_list.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installGetText({ T_Hanging = "On the frame", IGUI_TraditionalPreservationCore_ListFurthest = "Furthest along",
    IGUI_TraditionalPreservationCore_ListLeast = "Least along", IGUI_TraditionalPreservationCore_ListAll = "All" })

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end

-- Engine stand-ins: every character is 6 wide and a line 10 high, so a plain row is the 32 px icon (taller than
-- the name's line, 4 and an 18 px bar) and 4 above and below: 40 high.
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
-- As vanilla's: clear keeps the scroll height and addItem adds to it.
function ISScrollingListBox:clear() self.items = {} end
function ISScrollingListBox:setScrollHeight(height) self.scrollHeight = height end
function ISScrollingListBox:addItem(name, item)
    local entry = { text = name, item = item, index = #self.items + 1 }
    table.insert(self.items, entry)
    self.scrollHeight = (self.scrollHeight or 0) + 40
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
ISButton = element({ Type = "ISButton" })
function ISButton:new(x, y, width, height, title, target, onClick)
    return setmetatable({ x = x, y = y, width = width, height = height, title = title, target = target, onclick = onClick },
        { __index = ISButton })
end
function ISButton:setTitle(title) self.title = title end
function ISButton:click() self.onclick(self.target, self) end
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
    { name = "Bluegill", share = 0.2, tab = "Salt Fish", tabOrder = 1 },
    { name = "Yellow Perch", share = 1, tab = "Salt Fish", tabOrder = 1 },
    { name = "Beef (Salted)", share = 0.55, order = 0.55, tab = "Corned Meat", tabOrder = 3 },
    { name = "Pork (Salted)", share = 0.2, tab = "Country Cured Meat", tabOrder = 4 },
}
local function names(list)
    local out = {}
    for _, row in ipairs(list) do table.insert(out, row.name) end
    return table.concat(out, ", ")
end
check("furthest along first, ties as given", names(PieceList.sorted(rows, "furthest")) == "Yellow Perch, Beef (Salted), Bluegill, Pork (Salted)")
check("least along first, ties still as given", names(PieceList.sorted(rows, "least")) == "Bluegill, Pork (Salted), Beef (Salted), Yellow Perch")
check("the window's rows are left as they were", rows[1].name == "Bluegill" and rows[2].name == "Yellow Perch")
check("order goes before share", names(PieceList.sorted({ { name = "a", share = 1, order = 0 },
    { name = "b", share = 0 } }, "furthest")) == "a, b")

-- The tabs: All, then each process named, by tabOrder; a count each.
local function tabNames(list)
    local out = {}
    for _, tab in ipairs(list) do table.insert(out, PieceList.tabTitle(tab)) end
    return table.concat(out, ", ")
end
check("All first, then each process by its order, with counts",
    tabNames(PieceList.tabs(rows)) == "All (4), Salt Fish (2), Corned Meat (1), Country Cured Meat (1)")
check("equal orders go by their first row", tabNames(PieceList.tabs({ { tab = "B" }, { tab = "A" }, { tab = "B" } }))
    == "All (3), B (2), A (1)")
check("one process, or none, is All alone", tabNames(PieceList.tabs({ rows[1], rows[2] })) == "All (2)"
    and tabNames(PieceList.tabs({})) == "All (0)")
check("a tab's rows, in the order given; All is every row", names(PieceList.onTab(rows, "Salt Fish")) == "Bluegill, Yellow Perch"
    and PieceList.onTab(rows, nil) == rows)
local tabOwner = { fitCount = 0 }
local placed, lines = PieceList.tabLayout(tabOwner, PieceList.tabs(rows), 1000)
check("tabs that fit go on one line, each as wide as its title", lines == 1 and placed[1].width == #"All (4)" * 6 + 12
    and placed[2].x == placed[1].width + PieceList.TAB_GAP and placed[2].title == "Salt Fish (2)")
placed, lines = PieceList.tabLayout(tabOwner, PieceList.tabs(rows), 200)
check("tabs that don't fit go on to the next line, titles whole", lines == 3 and placed[2].line == 0 and placed[3].line == 1
    and placed[3].x == 0 and placed[4].line == 2 and placed[4].title == "Country Cured Meat (1)")
placed, lines = PieceList.tabLayout(tabOwner, { { name = "A very long process name", count = 1 } }, 100)
check("a title wider than the line is cut", lines == 1 and placed[1].width == 100 and placed[1].title:sub(-3) == "...")

-- Names cut to width: 60 wide holds 10 letters.
local owner = { fitCount = 0 }
check("a name that fits is as it is", PieceList.fit(owner, "Bluegill", 60) == "Bluegill")
check("a long one is cut with dots", PieceList.fit(owner, "Bluegill (cold)", 60) == "Bluegil...")
check("and kept for the next frame", owner.fitCache["60|Bluegill (cold)"] == "Bluegil..." and owner.fitCount == 2)
check("the same text at another width is fitted again", PieceList.fit(owner, "Bluegill (cold)", 90) == "Bluegill (cold)"
    and owner.fitCount == 3)

-- Heights: a plain row 40, one with a note 50; at least one row, at most the first three rows, and the border's 2.
check("a plain row and one with a note", PieceList.rowHeight({}) == 40 and PieceList.rowHeight({ note = "x" }) == 50)
check("a bar tall enough makes the row taller than the icon", PieceList.rowHeight({}, 24) == 10 + 4 + 24 + 8)
check("an empty list is one row high", PieceList.heightFor({}) == 42)
local many = {}
for i = 1, 20 do many[i] = { name = "Fish " .. i, share = i / 20 } end
check("twenty rows show three and scroll", PieceList.heightFor(many) == 3 * 40 + 2)
check("three rows, one with a note, are as high as they are", PieceList.heightFor({ {}, {}, { note = "x" } }) == 40 + 40 + 50 + 2)
check("rows with notes: three still show whole", PieceList.heightFor({ { note = "x" }, { note = "x" }, { note = "x" }, {} }) == 3 * 50 + 2)

-- In a window: the header at y, the switch beside it, the list under it.
local window = element({ width = 360, children = {} })
function window:addChild(child) table.insert(self.children, child) end
local drawn = {}
function window:drawText(text, x, y) table.insert(drawn, { text = text, x = x, y = y }) end
local look = { padding = 10, gap = 4, barTextPad = 6, barHeight = 12, label = { 1, 1, 1 }, value = { 1, 1, 1 },
    note = { 1, 1, 1 }, barBack = { 0, 0, 0 }, barBorder = { 0, 0, 0 } }
local nextY = PieceList.draw(window, look, 50, "On the frame", rows)
local list = window.pieceListUI
check("the list, its switch and four tabs are the window's children", list and #window.children == 6 and window.children[2] == list.sort
    and #list.tabButtons == 4 and list.tabButtons[1].title == "All (4)")
check("the header is drawn, the switch beside it at the right", drawn[1].text == "On the frame" and drawn[1].y == 52
    and list.sort.y == 50 and list.sort.x == 360 - 10 - PieceList.SORT_WIDTH)
check("the switch offers two sorts, furthest first", #list.sort.options == 2 and list.sort.options[2] == "Least along"
    and list.sort.selected == 1)
check("the tabs sit under the header, side by side, All open", list.tabButtons[1].y == 50 + 14 + 4 and list.tabButtons[1].x == 10
    and list.tabButtons[2].x == 10 + list.tabButtons[1].width + PieceList.TAB_GAP
    and list.tabButtons[1].backgroundColor == PieceList.TAB_OPEN and list.tabButtons[2].backgroundColor == PieceList.TAB_SHUT)
check("four tabs take two lines of 340 (the fourth wraps); the list sits under them, inside the padding",
    list.tabButtons[4].x == 10 and list.tabButtons[4].y == 68 + 14 + PieceList.TAB_GAP
    and list.y == 68 + 14 * 2 + PieceList.TAB_GAP + 4 and list.x == 10 and list.width == 340)
check("its rows are sorted, its height three of them", names(list.rows) == names(rows) and list.items[1].text == "Yellow Perch"
    and list.height == 3 * 40 + 2)
check("laid out again, the scroll height counts the new rows only (the jitter)", list.scrollHeight == 4 * 40)
check("the next y is under the list", nextY == list.y + list.height + 4)

-- The same rows table again (every frame between refreshes) lays nothing out; a new one does.
list.items[1].marked = true
PieceList.draw(window, look, 50, "On the frame", rows)
check("the same rows aren't laid out again", list.items[1].marked == true and #window.children == 6)

-- A tab clicked shows its rows only, and opens it; the list is as tall as they are.
list.tabButtons[2]:click()
PieceList.draw(window, look, 50, "On the frame", rows)
check("a tab shows its rows, sorted", names(list.items[1] and { list.items[1].item, list.items[2].item } or {}) == "Yellow Perch, Bluegill"
    and #list.items == 2 and list.height == 2 * 40 + 2 and list.tabButtons[2].backgroundColor == PieceList.TAB_OPEN
    and list.tabButtons[1].backgroundColor == PieceList.TAB_SHUT)
local fewer = { rows[1], rows[3], rows[4] }
PieceList.draw(window, look, 50, "On the frame", fewer)
check("new rows keep the tab open while it has pieces", list.tab == "Salt Fish" and #list.items == 1)
local fresh = { { name = "Pike", share = 0.9, note = "Cold smoke 30 of 72 h", tab = "Salt Fish" } }
PieceList.draw(window, look, 50, "On the frame", fresh)
check("one process: no tabs, every row, the list under the header", #list.items == 1 and list.items[1].text == "Pike"
    and list.height == 50 + 2 and not list.tabButtons[1]:getIsVisible() and not list.tabButtons[4]:getIsVisible()
    and list.y == 50 + 14 + 4)
check("and the tab it had is All again", list.tab == nil)
PieceList.draw(window, look, 50, "On the frame", { rows[3], rows[4] })
check("a tab gone shows All; tabs come back as needed", list.tab == nil and #list.items == 2
    and list.tabButtons[1]:getIsVisible() and list.tabButtons[3]:getIsVisible() and not list.tabButtons[4]:getIsVisible())

-- The switch: least along first, for every list; the next draw shows it.
list.sort.selected = 2
list.sort.onChange(list.sort.target, list.sort)
PieceList.draw(window, look, 50, "On the frame", rows)
check("the switch sorts least along first", list.items[1].text == "Bluegill" and list.items[4].text == "Yellow Perch")
local other = element({ width = 360, children = {} })
other.addChild, other.drawText = window.addChild, window.drawText
PieceList.draw(other, look, 10, "On the frame", rows)
check("another window's list keeps the sort, and opens on All", other.pieceListUI.sort.selected == 2
    and other.pieceListUI.items[1].text == "Bluegill" and other.pieceListUI.tab == nil)
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
check("collapsed: list, switch, tabs and popup hidden", not list:getIsVisible() and not list.sort:getIsVisible()
    and not panel:getIsVisible() and not list.tabButtons[1]:getIsVisible())
PieceList.show(window, true)
PieceList.draw(window, look, 50, "On the frame", rows)
check("opened again: shown, the tabs at the next draw", list:getIsVisible() and list.sort:getIsVisible()
    and list.tabButtons[1]:getIsVisible())

-- A resized window: the list fills its width, the switch keeps to its right.
window.width = 500
PieceList.draw(window, look, 50, "On the frame", rows)
check("a wider window widens the list and moves the switch", list.width == 480
    and list.sort.x == 500 - 10 - PieceList.SORT_WIDTH)
window.width = 360
PieceList.draw(window, look, 50, "On the frame", rows)

-- A row drawn: the name bold (twice, a pixel apart) at 48, the warning right-aligned 20 short of the edge, the bar
-- from 48 to there; the name is cut only when the warning needs the room.
local function drawRow(row, width)
    local canvas = setmetatable({ width = width, height = 200, colours = look, texts = {}, rects = {}, fitCount = 0,
        mouseoverselected = 0 }, { __index = list })
    function canvas:getYScroll() return 0 end
    function canvas:isMouseOver() return false end
    function canvas:drawText(text, x, y) table.insert(self.texts, { text = text, x = x, y = y }) end
    function canvas:drawTextCentre(text, x, y) table.insert(self.texts, { text = text, x = x, y = y, centre = true }) end
    function canvas:drawRect(x, y, w, h) table.insert(self.rects, { x = x, y = y, w = w, h = h }) end
    function canvas:drawRectBorder() end
    function canvas:drawTextureScaledAspect(_, x, y, w, h) self.icon = { x = x, y = y, w = w, h = h } end
    local bottom = canvas:doDrawItem(0, { item = row, height = 40, index = 1 })
    return canvas, bottom
end
local drawnRow, bottom = drawRow({ name = "Pork (Corned)", warning = "Wet: rain", share = 0.2, text = "20%, 6 d", icon = "pork" }, 300)
local texts = drawnRow.texts
check("the warning sits right, 20 short of the edge", texts[1].text == "Wet: rain" and texts[1].x == 300 - 20 - 9 * 6)
check("the name is bold at 48, whole when it fits", texts[2].text == "Pork (Corned)" and texts[2].x == 48
    and texts[3].text == "Pork (Corned)" and texts[3].x == 49)
check("the bar runs from 48 to the warning's edge, under the name", drawnRow.rects[1].x == 48 and drawnRow.rects[1].w == 300 - 20 - 48
    and drawnRow.rects[1].y == 4 + 10 + 4 and drawnRow.rects[2].w == (300 - 20 - 48) * 0.2)
check("the icon is 32 px at 6", drawnRow.icon.x == 6 and drawnRow.icon.w == 32 and bottom == 40)
local cut = drawRow({ name = "Leg of Pork (Country Cured)", warning = "Stale in 3.5 d", share = 0.5 }, 300).texts
check("a long name gives way to the warning", cut[2].text:sub(-3) == "..." and 48 + #cut[2].text * 6 + 1 <= 300 - 20 - 14 * 6 - 12)
local whole = drawRow({ name = "Leg of Pork (Country Cured)", share = 0.5 }, 300).texts
check("without a warning it is whole", whole[1].text == "Leg of Pork (Country Cured)")

H.done()
