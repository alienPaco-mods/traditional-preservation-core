-- Traditional Preservation core: the scrolling list of an info window, one row a piece (what hangs on a rack, sits
-- on a shelf or lies on a malting floor). A header row names it and holds the sort switch (furthest along first, or
-- least along first); under it a row of tabs, All and one for each process on the station with its count ("Salt Fish
-- (4)"), on as many lines as they need, shown only when there are two processes or more; under them up to ROWS_SHOWN
-- rows of the tab open, then a
-- scroll bar. Each row is an icon, a name, a bar with its text and, if given, a line under the bar (the Smokehouse's
-- smoke count). Hovering a row shows its popup, drawn like a crafting window's slot popup (ISToolTipItemSlot): the
-- row's popup(tooltip) fills it, as UI.drawTooltip does.
-- A window doesn't make one itself: InfoWindow:pieceList(y, label, rows) draws it in the window's flow.
-- rows is a list of { icon (Texture or nil), name, share (0 to 1), colour { r, g, b }, text (in the bar),
-- note (text under the bar, or nil), order (sort key, share if nil), tab (its process's tab name, or nil: All only),
-- tabOrder (the tabs' order, lowest first; the first row's order among equals), popup (function(tooltip), or nil) }.
-- A window builds a new rows table in refresh; the list lays it out again only when the table or the tab changes.
require "ISUI/ISScrollingListBox"
require "ISUI/ISComboBox"
require "ISUI/ISButton"
require "Entity/ISUI/Components/Crafting/ISToolTipItemSlot"

local PieceList = ISScrollingListBox:derive("TraditionalPreservationCorePieceList")

PieceList.ROWS_SHOWN = 8
PieceList.ICON = 16
PieceList.ROW_PAD = 3       -- above and below a row's line
PieceList.GAP = 4           -- between icon, name and bar
PieceList.SORT_WIDTH = 120
PieceList.TAB_PAD = 6       -- either side of a tab's title
PieceList.TAB_GAP = 2       -- between tabs
PieceList.TAB_OPEN = { r = 0.25, g = 0.4, b = 0.25, a = 1 }  -- the open tab's background
PieceList.TAB_SHUT = { r = 0, g = 0, b = 0, a = 1 }
PieceList.FIT_CACHE = 64    -- names kept cut to width before the cache starts over
PieceList.BACKGROUND = { r = 0, g = 0, b = 0, a = 0.4 }
PieceList.BORDER = { r = 0.4, g = 0.4, b = 0.4, a = 0.8 }
PieceList.FILL = { 0.35, 0.7, 0.35 } -- a bar with no colour of its own

-- The switch's sorts, in its order. One choice for every list, kept while the game runs.
PieceList.SORTS = { "furthest", "least" }
local SORT_TEXTS = { furthest = "IGUI_TraditionalPreservationCore_ListFurthest",
    least = "IGUI_TraditionalPreservationCore_ListLeast" }
local sortBy = "furthest"

-- rows sorted by sort (one of SORTS): furthest along first, or least along first; ties in the order given. Returns
-- a new list; rows is left as it is.
function PieceList.sorted(rows, sort)
    local keyed = {}
    for index, row in ipairs(rows) do
        keyed[index] = { row = row, key = row.order or row.share or 0, index = index }
    end
    table.sort(keyed, function(a, b)
        if a.key ~= b.key then
            if sort == "least" then return a.key < b.key end
            return a.key > b.key
        end
        return a.index < b.index
    end)
    local sorted = {}
    for index, entry in ipairs(keyed) do sorted[index] = entry.row end
    return sorted
end

-- The tabs for rows: { { name, count } }, All first (name nil, every row), then each tab the rows name, by tabOrder
-- (lowest first), equals in the order their first row comes. Only All when fewer than two tabs are named.
function PieceList.tabs(rows)
    local found, counts = {}, {}
    for index, row in ipairs(rows) do
        if row.tab then
            if not counts[row.tab] then
                counts[row.tab] = 0
                table.insert(found, { name = row.tab, order = row.tabOrder or 0, first = index })
            end
            counts[row.tab] = counts[row.tab] + 1
        end
    end
    table.sort(found, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.first < b.first
    end)
    local tabs = { { name = nil, count = #rows } }
    if #found < 2 then return tabs end
    for _, tab in ipairs(found) do table.insert(tabs, { name = tab.name, count = counts[tab.name] }) end
    return tabs
end

-- The rows on a tab (nil: All, every row), in the order given.
function PieceList.onTab(rows, tab)
    if tab == nil then return rows end
    local shown = {}
    for _, row in ipairs(rows) do
        if row.tab == tab then table.insert(shown, row) end
    end
    return shown
end

-- A tab's title: its name (All for nil) and its count.
function PieceList.tabTitle(tab)
    return (tab.name or getText("IGUI_TraditionalPreservationCore_ListAll")) .. " (" .. tostring(tab.count) .. ")"
end

-- The tabs laid out in width: each as wide as its title and padding, left to right, onto a new line when the next
-- doesn't fit (a title wider than the whole line is cut with "..."). Returns { { x, line (0 first), width, title } }
-- and the count of lines.
function PieceList.tabLayout(owner, tabs, width)
    local measure, placed, x, line = getTextManager(), {}, 0, 0
    for index, tab in ipairs(tabs) do
        local title = PieceList.tabTitle(tab)
        local tabWidth = measure:MeasureStringX(UIFont.Small, title) + PieceList.TAB_PAD * 2
        if tabWidth > width then
            title = PieceList.fit(owner, title, width - PieceList.TAB_PAD * 2)
            tabWidth = width
        end
        if x > 0 and x + tabWidth > width then x, line = 0, line + 1 end
        placed[index] = { x = x, line = line, width = tabWidth, title = title }
        x = x + tabWidth + PieceList.TAB_GAP
    end
    return placed, line + 1
end

-- text cut to width with "...", kept in owner until the cache fills.
function PieceList.fit(owner, text, width)
    if owner.fitWidth ~= width or owner.fitCount > PieceList.FIT_CACHE then
        owner.fitWidth, owner.fitCache, owner.fitCount = width, {}, 0
    end
    local fitted = owner.fitCache[text]
    if fitted then return fitted end
    local measure = getTextManager()
    fitted = text
    if measure:MeasureStringX(UIFont.Small, text) > width then
        local cut = #text
        repeat
            cut = cut - 1
            fitted = string.sub(text, 1, cut) .. "..."
        until cut <= 1 or measure:MeasureStringX(UIFont.Small, fitted) <= width
    end
    owner.fitCache[text], owner.fitCount = fitted, owner.fitCount + 1
    return fitted
end

local function lineHeight()
    return getTextManager():getFontHeight(UIFont.Small)
end

-- A row's height: one line (or the icon), and the note's line under it.
function PieceList.rowHeight(row)
    local height = math.max(lineHeight(), PieceList.ICON) + PieceList.ROW_PAD * 2
    if row.note then height = height + lineHeight() end
    return height
end

-- The list's height for these rows: as tall as they are, at most ROWS_SHOWN plain rows, at least one.
function PieceList.heightFor(rows)
    local plain = math.max(lineHeight(), PieceList.ICON) + PieceList.ROW_PAD * 2
    local height = 0
    for _, row in ipairs(rows) do height = height + PieceList.rowHeight(row) end
    return math.max(plain, math.min(height, plain * PieceList.ROWS_SHOWN)) + 2
end

-- The colours and sizes of InfoWindow, passed in so the two files don't require each other.
function PieceList:new(x, y, width, colours)
    local o = ISScrollingListBox.new(self, x, y, width, PieceList.heightFor({}))
    o.font, o.fontHgt = UIFont.Small, lineHeight()
    o.itemheight = PieceList.rowHeight({})
    o.backgroundColor, o.borderColor = PieceList.BACKGROUND, PieceList.BORDER
    o.drawBorder = true
    o.colours = colours
    o.hoverSlot = {}
    o.fitCount = 0
    return o
end

-- Lays out the open tab's rows, sorted, as the list's items; called when the window's rows, the tab or the switch
-- change. A tab whose last piece went shows All.
function PieceList:setRows(rows)
    local tabs, open = PieceList.tabs(rows), nil
    for _, tab in ipairs(tabs) do
        if tab.name ~= nil and tab.name == self.tab then open = tab.name end
    end
    self.tab = open
    self.rows, self.sortBy, self.tabShown, self.tabList = rows, sortBy, open, tabs
    local shown = PieceList.onTab(rows, open)
    self:clear()
    for _, row in ipairs(PieceList.sorted(shown, sortBy)) do
        local item = self:addItem(row.name, row)
        item.height = PieceList.rowHeight(row)
    end
    self:setHeight(PieceList.heightFor(shown))
end

-- Rows aren't picked: a click does nothing.
function PieceList:onMouseDown(x, y)
end

function PieceList:onMouseDoubleClick(x, y)
end

function PieceList:doDrawItem(y, item, alt)
    local row = item.item
    local height = item.height
    if y + self:getYScroll() + height < 0 or y + self:getYScroll() >= self.height then return y + height end
    if self.mouseoverselected == item.index and self:isMouseOver() and not self:isMouseOverScrollBar() then
        self:drawMouseOverHighlight(0, y, self.width, height - 1)
    end
    local colours = self.colours
    local line = lineHeight()
    local top = y + PieceList.ROW_PAD
    local x = PieceList.GAP
    if row.icon then
        self:drawTextureScaledAspect(row.icon, x, top + (line - PieceList.ICON) / 2, PieceList.ICON, PieceList.ICON, 1, 1, 1, 1)
    end
    x = x + PieceList.ICON + PieceList.GAP
    local barX = colours.barX
    local value = colours.value
    self:drawText(PieceList.fit(self, row.name or "", barX - x - PieceList.GAP), x, top, value[1], value[2], value[3], 1, UIFont.Small)
    local scroll = self:isVScrollBarVisible() and self.vscroll:getWidth() or 0
    local barWidth = self.width - barX - scroll - PieceList.GAP
    local barTop = top + (line - colours.barHeight) / 2
    local back, border, fill = colours.barBack, colours.barBorder, row.colour or PieceList.FILL
    self:drawRect(barX, barTop, barWidth, colours.barHeight, 0.6, back[1], back[2], back[3])
    self:drawRect(barX, barTop, barWidth * math.max(0, math.min(row.share or 0, 1)), colours.barHeight, 0.9, fill[1], fill[2], fill[3])
    self:drawRectBorder(barX, barTop, barWidth, colours.barHeight, 0.8, border[1], border[2], border[3])
    if row.text then self:drawTextCentre(row.text, barX + barWidth / 2, top, 1, 1, 1, 1, UIFont.Small) end
    if row.note then
        local note = colours.note
        self:drawText(PieceList.fit(self, row.note, self.width - x - scroll - PieceList.GAP), x, top + line, note[1], note[2], note[3], 1, UIFont.Small)
    end
    return y + height
end

-- The hover: the row under the mouse's popup, in a crafting slot's popup panel; none while the switch is open.
-- The panel calls drawTooltip on a stand-in slot holding the hovered row's popup.
local function drawHover(slot, tooltip)
    if slot.popup then slot.popup(tooltip) end
end

-- A new panel counts as visible before it is added, so whether it shows is kept in popupShown.
local function hidePopup(list)
    local panel = list.popupPanel
    if panel and list.popupShown then
        list.popupShown = false
        panel:setVisible(false)
        panel:removeFromUIManager()
    end
end

function PieceList:updateTooltip()
    local item = self:isMouseOver() and not self:isMouseOverScrollBar() and not (self.sort and self.sort.expanded)
        and self.items[self.mouseoverselected]
    local popup = item and item.item.popup
    if not popup then return hidePopup(self) end
    self.hoverSlot.popup = popup
    if not self.popupPanel then
        self.hoverSlot.drawTooltip = drawHover
        self.popupPanel = ISToolTipItemSlot:new(self.hoverSlot)
        self.popupPanel:initialise()
        self.popupPanel:setOwner(self)
    end
    if not self.popupShown then
        self.popupShown = true
        self.popupPanel:setVisible(true)
        self.popupPanel:addToUIManager()
        self.popupPanel:bringToTop()
    end
end

function PieceList:setVisible(visible)
    if not visible then hidePopup(self) end
    ISScrollingListBox.setVisible(self, visible)
end

function PieceList:removeFromUIManager()
    hidePopup(self)
    ISScrollingListBox.removeFromUIManager(self)
end

-- The sort switch's choice, for every list.
local function onSort(list, combo)
    sortBy = PieceList.SORTS[combo.selected] or "furthest"
    if list.rows then list:setRows(list.rows) end
end

-- A tab clicked: this list shows it (the window's own choice; a new window opens on All).
local function onTab(button)
    local list = button.pieceList
    list.tab = button.tabName
    if list.rows then list:setRows(list.rows) end
end

-- Lays out the tab buttons at y on window, one a tab (made as needed, hidden when not needed); returns the y under
-- them, or y with fewer than two tabs.
local function drawTabs(window, colours, list, y)
    local tabs = list.tabList or {}
    local buttons = list.tabButtons
    local shown = #tabs > 1 and #tabs or 0
    local placed, lines = PieceList.tabLayout(list, tabs, list.width)
    local height = lineHeight() + 4
    for index = 1, math.max(shown, #buttons) do
        local button = buttons[index]
        if index <= shown then
            local at = placed[index]
            if not button then
                button = ISButton:new(0, 0, at.width, height, "", nil, onTab)
                button:initialise()
                button:instantiate()
                button.pieceList = list
                button.target = button
                window:addChild(button)
                buttons[index] = button
            end
            button.tabName = tabs[index].name
            local x, top = colours.padding + at.x, y + at.line * (height + PieceList.TAB_GAP)
            if button.x ~= x then button:setX(x) end
            if button.y ~= top then button:setY(top) end
            if button.width ~= at.width then button:setWidth(at.width) end
            if button.title ~= at.title then button:setTitle(at.title) end
            button.backgroundColor = tabs[index].name == list.tab and PieceList.TAB_OPEN or PieceList.TAB_SHUT
            if not button:getIsVisible() and list:getIsVisible() then button:setVisible(true) end
        elseif button and button:getIsVisible() then
            button:setVisible(false)
        end
    end
    if shown == 0 then return y end
    return y + lines * height + (lines - 1) * PieceList.TAB_GAP + colours.gap
end

-- The list and its switch on window, made on the first call. Returns the list.
function PieceList.of(window, colours)
    local list = window.pieceListUI
    if list then return list end
    local padding = colours.padding
    list = PieceList:new(padding, 0, window.width - padding * 2, colours)
    list:initialise()
    list:instantiate()
    window:addChild(list)
    local sort = ISComboBox:new(window.width - padding - PieceList.SORT_WIDTH, 0, PieceList.SORT_WIDTH, lineHeight() + 4, list, onSort)
    sort:initialise()
    for _, name in ipairs(PieceList.SORTS) do sort:addOption(getText(SORT_TEXTS[name])) end
    window:addChild(sort)
    list.sort = sort
    list.tabButtons = {}
    window.pieceListUI = list
    return list
end

-- Draws the header (label, the switch) at y on window and places the list under it; returns the y under the list.
function PieceList.draw(window, colours, y, label, rows)
    local list = PieceList.of(window, colours)
    local sort = list.sort
    local header = math.max(lineHeight(), sort.height)
    local labelColour = colours.label
    window:drawText(label, colours.padding, y + (header - lineHeight()) / 2, labelColour[1], labelColour[2], labelColour[3], 1, UIFont.Small)
    if sort.y ~= y then sort:setY(y) end
    for index, name in ipairs(PieceList.SORTS) do
        if name == sortBy then sort.selected = index end
    end
    y = y + header + colours.gap
    if list.rows ~= rows or list.sortBy ~= sortBy or list.tabShown ~= list.tab then list:setRows(rows) end
    y = drawTabs(window, colours, list, y)
    if list.y ~= y then list:setY(y) end
    return y + list.height + colours.gap
end

-- Hides or shows the list, its switch and its tabs (a collapsed window); the next draw shows the tabs it needs.
function PieceList.show(window, visible)
    local list = window.pieceListUI
    if not list or list:getIsVisible() == visible then return end
    list:setVisible(visible)
    list.sort:setVisible(visible)
    for _, button in ipairs(list.tabButtons) do
        if not visible then button:setVisible(false) end
    end
end

return PieceList
