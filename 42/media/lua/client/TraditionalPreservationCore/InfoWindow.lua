-- Traditional Preservation core: the base of every station's info window (Stone Hearth Info, Dairy's Incubator and Crock
-- Info). Rows of label and value, filled bars and wrapped notes, kept up to date while open. It closes when the player
-- walks off or the station is gone. One info window at a time, whatever the mod: opening another closes the last.
-- A window opens from its station's right-click menu only: a left click stays vanilla's (a container's loot window).
-- A window derives this, sets its title in new, keeps what it shows in refresh (a view named for its station:
-- fireView, potView, caskView) and draws it in render:
--     local MyWindow = InfoWindow:derive("MyModWindow")
--     function MyWindow.open(playerObj, station) InfoWindow.open(MyWindow, playerObj, station) end
-- The drawing (drawRow, drawBar, noteLines, drawNoteLines) is shared with StationInfo's block in vanilla's crafting
-- window: each takes the element to draw on and its layout { padding, labelWidth, barHeight }.
-- A window reads in blocks, each under a small grey header and a hairline (section): Station, Holds, Working, List,
-- Buttons, the drop square, then the notes; a block with nothing to show is left out. Spacing is on a 4 px grid. The
-- label column is as wide as the longest label the window has drawn. holds (Holds.lua) draws what the station holds
-- standing up: tanks, cells and a thermometer. A window is WIDTH wide unless what it holds needs more, up to
-- MAX_WIDTH, and as tall as what it shows.
-- A station holding many pieces lists them with pieceList (PieceList.lua, required by the first window that draws
-- one): a scrolling list, one row a piece. dropZone (DropZone.lua, the same way) is a square that takes a selection
-- dragged from the inventory or a loot window.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
local Station = require "TraditionalPreservationCore/Station"

local InfoWindow = ISCollapsableWindow:derive("TraditionalPreservationCoreInfoWindow")

InfoWindow.WIDTH = 400
InfoWindow.MAX_WIDTH = 680
InfoWindow.WIDTHS_FILE = "TraditionalPreservationWindowWidths.txt"   -- in ~/Zomboid/Lua: the player's, not the save's
InfoWindow.REACH = 6
InfoWindow.PADDING = 12
InfoWindow.LABEL_WIDTH = 120
InfoWindow.LABEL_GAP = 16       -- a label to its value
InfoWindow.SECTION_GAP = 12     -- above a block's header
InfoWindow.HEADER_GAP = 4       -- a header to its first row
InfoWindow.HEADER_SPACE = 6     -- a header's name to its hairline
InfoWindow.BAR_HEIGHT = 18
InfoWindow.BAR_TEXT_PAD = 6     -- a bar's text to its ends; longer text goes under the bar
InfoWindow.REFRESH_TICKS = 30
InfoWindow.START_HEIGHT = 200   -- drawNotes fits it to what is drawn
InfoWindow.VALUE_CACHE = 32     -- row values kept wrapped before the cache starts over (a value counts down)
InfoWindow.ROW_GAP, InfoWindow.BAR_GAP, InfoWindow.NOTE_GAP = 4, 4, 4
InfoWindow.ICON_GAP = 4         -- a row's icon to its text
InfoWindow.BAND_HEIGHT = 28    -- the state band under the title
InfoWindow.BAND_BUTTON, InfoWindow.BAND_ICON = 24, 20   -- its icon-only button, square, and the icon in it
-- A band's colours { colour, dark } by what its state means (user): working, slowed or waiting on the player, something
-- will be lost. The fire has its own (FireUI).
InfoWindow.BAND_WORKING = { { 0.35, 0.6, 0.3 }, { 0.12, 0.22, 0.11 } }
InfoWindow.BAND_WAITING = { { 0.75, 0.55, 0.2 }, { 0.27, 0.2, 0.07 } }
InfoWindow.BAND_AT_RISK = { { 0.6, 0.3, 0.25 }, { 0.24, 0.11, 0.09 } }
InfoWindow.BAND_IDLE = { { 0.51, 0.51, 0.51 }, { 0.18, 0.18, 0.18 } }   -- nothing in it: grey, as a fire that is out
InfoWindow.BUTTON_HEIGHT, InfoWindow.BUTTON_GAP, InfoWindow.BUTTON_PAD, InfoWindow.BUTTON_ICON = 24, 8, 12, 16
-- Text colours { r, g, b }: a row's label, its value, the notes; a bar's empty part and border.
InfoWindow.LABEL_COLOUR = { 0.7, 0.7, 0.7 }
InfoWindow.VALUE_COLOUR = { 1, 1, 1 }
InfoWindow.NOTE_COLOUR = { 0.8, 0.8, 0.65 }
InfoWindow.BAR_BACK, InfoWindow.BAR_BORDER = { 0.1, 0.1, 0.1 }, { 0.4, 0.4, 0.4 }
InfoWindow.DROP_NO_TEXT = { 0.9, 0.43, 0.35 }   -- a drag hint that takes nothing
-- A block's header and its hairline.
InfoWindow.HEADER_COLOUR, InfoWindow.HAIRLINE = { 0.55, 0.55, 0.55 }, { 0.3, 0.3, 0.3 }
-- Bold text (a holding's name) is Small drawn twice, a pixel apart (user: SdfBold zoomed down looked shadowed).
-- A lone holding's lore note: the game's serif italic (SdfOldItalic) at Small's height, a rule at its left.
InfoWindow.LORE_COLOUR, InfoWindow.LORE_RULE = { 0.8, 0.8, 0.65 }, { 0.47, 0.43, 0.31 }
InfoWindow.LORE_GAP, InfoWindow.LORE_PAD = 12, 12   -- the holdings to the rule, the rule to the text
InfoWindow.LORE_MIN = 140       -- the least room for the lore beside the holdings: the window widens to give it

local LAYOUT = { padding = InfoWindow.PADDING, labelWidth = InfoWindow.LABEL_WIDTH, barHeight = InfoWindow.BAR_HEIGHT }
-- What PieceList draws with: its bars start under the rows' values.
local LIST_LOOK = { padding = InfoWindow.PADDING, gap = InfoWindow.BAR_GAP, barTextPad = InfoWindow.BAR_TEXT_PAD,
    barHeight = InfoWindow.BAR_HEIGHT, label = InfoWindow.LABEL_COLOUR, value = InfoWindow.VALUE_COLOUR,
    note = InfoWindow.NOTE_COLOUR, barBack = InfoWindow.BAR_BACK, barBorder = InfoWindow.BAR_BORDER }

local current -- the info window open, from any mod

function InfoWindow.inReach(playerObj, station)
    local square = station:getSquare()
    return square ~= nil and not playerObj:isDead() and square:getZ() == playerObj:getZ()
        and IsoUtils.DistanceTo(playerObj:getX(), playerObj:getY(), square:getX() + 0.5, square:getY() + 0.5) <= InfoWindow.REACH
end

function InfoWindow:new(playerObj, station)
    local x = getCore():getScreenWidth() / 2 - InfoWindow.WIDTH / 2
    local o = ISCollapsableWindow.new(self, x, getCore():getScreenHeight() / 3, InfoWindow.WIDTH, InfoWindow.START_HEIGHT)
    o.playerObj, o.station = playerObj, station
    o.resizable = false
    o.ticks = InfoWindow.REFRESH_TICKS
    o.labelColumn = 0
    return o
end

-- Opens class's window on station, closing whichever info window was open.
function InfoWindow.open(class, playerObj, station)
    if current then current:close() end
    current = class:new(playerObj, station)
    current:initialise()
    current:addToUIManager()
end

function InfoWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if current == self then current = nil end
end

-- Fills the window's view; a window's own refresh replaces this. Run twice a second, not every frame.
function InfoWindow:refresh()
end

local keepWidth -- below, with the resize

function InfoWindow:update()
    ISCollapsableWindow.update(self)
    if not Station.isLoaded(self.station) or not InfoWindow.inReach(self.playerObj, self.station) then return self:close() end
    if self.pieceListUI then require("TraditionalPreservationCore/PieceList").show(self, not self.isCollapsed) end
    if self.dropZoneUI then require("TraditionalPreservationCore/DropZone").show(self, not self.isCollapsed) end
    if self.dropTargetsUI then require("TraditionalPreservationCore/DropZone").showTargets(self, math.huge) end
    for _, button in ipairs(self.buttonsUI or {}) do
        if button:getIsVisible() == self.isCollapsed then button:setVisible(not self.isCollapsed) end
    end
    local bandButton = self.bandButtonUI
    if bandButton and bandButton:getIsVisible() == self.isCollapsed then bandButton:setVisible(not self.isCollapsed) end
    if self.widthResizes then keepWidth(self) end
    self.ticks = self.ticks + 1
    if self.ticks >= InfoWindow.REFRESH_TICKS then
        self.ticks = 0
        self:refresh()
    end
end

-- Words that run past the window go on to the next line; measure(text) is the width in Small unless given.
local function wrapped(text, width, measure)
    local lines, line = {}, ""
    for word in string.gmatch(text, "%S+") do
        local longer = line == "" and word or line .. " " .. word
        local wide = measure and measure(longer) or getTextManager():MeasureStringX(UIFont.Small, longer)
        if line ~= "" and wide > width then
            table.insert(lines, line)
            line = word
        else
            line = longer
        end
    end
    if line ~= "" then table.insert(lines, line) end
    return lines
end

-- For a panel that wraps its own notes (StationInfo).
InfoWindow.wrapped = wrapped

-- A row's text wrapped to width, at least one line. Kept in owner until the width changes; a text changes as its
-- time counts down, so the cache starts over once it holds 32 texts.
function InfoWindow.valueLines(owner, text, width)
    if owner.valueWidth ~= width or owner.valueCount > InfoWindow.VALUE_CACHE then
        owner.valueWidth, owner.valueCache, owner.valueCount = width, {}, 0
    end
    local lines = owner.valueCache[text]
    if not lines then
        lines = wrapped(text, width)
        if #lines == 0 then lines = { text } end
        owner.valueCache[text], owner.valueCount = lines, owner.valueCount + 1
    end
    return lines
end

-- The y of the first row, under the title bar (and the band, when the window draws one).
function InfoWindow:top()
    return self.bandBottom or self:titleBarHeight() + InfoWindow.PADDING
end

function InfoWindow.lineHeight()
    return getTextManager():getFontHeight(UIFont.Small)
end

local function drawText(ui, text, x, y, colour)
    ui:drawText(text, x, y, colour[1], colour[2], colour[3], 1, UIFont.Small)
end

-- A row's text lines when ui is width wide (the space right of the label), kept on ui.
function InfoWindow.rowLines(ui, layout, text, width)
    return InfoWindow.valueLines(ui, text, width - layout.padding * 2 - layout.labelWidth)
end

-- Draws label (text) and the text's lines at y on ui, icon (a Texture, or nil) before the first line, a line high;
-- returns the next row's y.
function InfoWindow.drawRow(ui, layout, y, label, text, icon)
    local lineHeight = InfoWindow.lineHeight()
    drawText(ui, label, layout.padding, y, InfoWindow.LABEL_COLOUR)
    local x = layout.padding + layout.labelWidth
    if icon then
        ui:drawTextureScaledAspect(icon, x, y, lineHeight, lineHeight, 1, 1, 1, 1)
        x = x + lineHeight + InfoWindow.ICON_GAP
    end
    for _, line in ipairs(InfoWindow.valueLines(ui, text, ui.width - layout.padding - x)) do
        drawText(ui, line, x, y, InfoWindow.VALUE_COLOUR)
        y = y + lineHeight
    end
    return y + InfoWindow.ROW_GAP
end

-- Draws label (text) and a bar filled to share (0 to 1) in colour { r, g, b }, text in its middle, or under the bar
-- when it doesn't fit inside; returns the next y.
function InfoWindow.drawBar(ui, layout, y, label, share, colour, text)
    local lineHeight = InfoWindow.lineHeight()
    local x = layout.padding + layout.labelWidth
    local width = ui.width - x - layout.padding
    local height = math.max(layout.barHeight, lineHeight)
    local back, border = InfoWindow.BAR_BACK, InfoWindow.BAR_BORDER
    drawText(ui, label, layout.padding, y + (height - lineHeight) / 2, InfoWindow.LABEL_COLOUR)
    ui:drawRect(x, y, width, height, 0.6, back[1], back[2], back[3])
    ui:drawRect(x, y, width * math.max(0, math.min(share, 1)), height, 0.9, colour[1], colour[2], colour[3])
    ui:drawRectBorder(x, y, width, height, 0.8, border[1], border[2], border[3])
    y = y + height
    if getTextManager():MeasureStringX(UIFont.Small, text) <= width - InfoWindow.BAR_TEXT_PAD * 2 then
        ui:drawTextCentre(text, x + width / 2, y - height + (height - lineHeight) / 2, 1, 1, 1, 1, UIFont.Small)
    else
        for _, line in ipairs(InfoWindow.valueLines(ui, text, width)) do
            drawText(ui, line, x, y, InfoWindow.VALUE_COLOUR)
            y = y + lineHeight
        end
    end
    return y + InfoWindow.BAR_GAP
end

-- Each note's lines when ui is width wide, kept on ui until its text or the width changes (wrapping measures every
-- word).
function InfoWindow.noteLines(ui, layout, notes, width)
    width = width - layout.padding * 2
    if ui.noteWidth ~= width then ui.noteWidth, ui.noteTexts, ui.noteLines = width, {}, {} end
    for index, note in ipairs(notes) do
        if ui.noteTexts[index] ~= note then
            ui.noteTexts[index], ui.noteLines[index] = note, wrapped(note, width)
        end
    end
    return ui.noteLines
end

-- Draws the notes in the muted colour from y on ui; returns the y under them.
function InfoWindow.drawNoteLines(ui, layout, y, notes)
    local lineHeight = InfoWindow.lineHeight()
    local lines = InfoWindow.noteLines(ui, layout, notes, ui.width)
    for index = 1, #notes do
        y = y + InfoWindow.NOTE_GAP
        for _, line in ipairs(lines[index]) do
            drawText(ui, line, layout.padding, y, InfoWindow.NOTE_COLOUR)
            y = y + lineHeight
        end
    end
    return y
end

-- The window's layout: the label column as wide as the longest label it has drawn, and the gap after it. A new label
-- longer than the rest widens it from the next frame on.
function InfoWindow:layoutFor(labelText)
    local width = getTextManager():MeasureStringX(UIFont.Small, labelText) + InfoWindow.LABEL_GAP
    if width > self.labelColumn then self.labelColumn = width end
    self.layout = self.layout or { padding = InfoWindow.PADDING, barHeight = InfoWindow.BAR_HEIGHT }
    self.layout.labelWidth = self.labelColumn
    return self.layout
end

-- A window's row: label is a translation key. Returns the next line's y. bar does the same with a filled bar.
function InfoWindow:row(y, label, text)
    local labelText = getText(label)
    return InfoWindow.drawRow(self, self:layoutFor(labelText), y, labelText, text)
end

-- The Place row: the place's icon, its temperature and its word ("17°C (Aired room)").
function InfoWindow:placeRow(y, label, place, celsius)
    local UI = require "TraditionalPreservationCore/UI"
    local labelText = getText(label)
    return InfoWindow.drawRow(self, self:layoutFor(labelText), y, labelText, UI.placeText(place, celsius), UI.placeIcon(place))
end

function InfoWindow:bar(y, label, share, colour, text)
    local labelText = getText(label)
    return InfoWindow.drawBar(self, self:layoutFor(labelText), y, labelText, share, colour, text)
end

-- A bar whose label is already text (a numbered lot: "1. Yeast Cakes").
function InfoWindow:barNamed(y, labelText, share, colour, text)
    return InfoWindow.drawBar(self, self:layoutFor(labelText), y, labelText, share, colour, text)
end

-- A band right under the title bar, the window's full width: a state at a glance (the fire: lit, banked, out). word
-- (finished text, drawn bold in capitals) then text, on a strip fading from colour { r, g, b } to dark, and entry (a
-- button as buttonRow's, or nil) at its right as its icon alone, the title heading its hover (user: saves room). The rows start under it (top). Returns the y of the first row.
local placeButton -- below, with the buttons

-- The game draws a window's prerender, then its children (buttons), then its render: the band is drawn in
-- prerender from what band() kept, so its button shows on top of it.
local function drawBand(window, look)
    local top, height = window:titleBarHeight(), InfoWindow.BAND_HEIGHT
    local colour, dark = look.colour, look.dark
    for line = 0, height - 1 do
        local t = line / (height - 1)
        window:drawRect(1, top + line, window.width - 2, 1, 1, colour[1] * (1 - t) * 0.55 + dark[1] * t,
            colour[2] * (1 - t) * 0.55 + dark[2] * t, colour[3] * (1 - t) * 0.55 + dark[3] * t)
    end
    local y = top + (height - InfoWindow.lineHeight()) / 2
    local value = InfoWindow.VALUE_COLOUR
    local wordWidth = InfoWindow.boldWidth(look.word)
    InfoWindow.drawBoldCentre(window, look.word, InfoWindow.PADDING + wordWidth / 2, y, value)
    InfoWindow.drawBoldCentre(window, look.text, InfoWindow.PADDING + wordWidth + 8 + InfoWindow.boldWidth(look.text) / 2, y, value)
end

function InfoWindow:prerender()
    ISCollapsableWindow.prerender(self)
    if self.bandLook and not self.isCollapsed then drawBand(self, self.bandLook) end
end

function InfoWindow:band(word, text, colour, dark, entry)
    local top, height = self:titleBarHeight(), InfoWindow.BAND_HEIGHT
    self.bandLook = { word = string.upper(word), text = text, colour = colour, dark = dark }
    if entry then
        local size = InfoWindow.BAND_BUTTON
        local iconOnly = { title = "", enabled = entry.enabled, onClick = entry.onClick,
            tooltip = entry.tooltip and entry.title .. " <LINE> " .. entry.tooltip or entry.title }
        local button = placeButton(self, self.bandButtonUI, iconOnly, self.width - InfoWindow.PADDING - size,
            top + (height - size) / 2, size, size)
        local icon = entry.icon
        if type(icon) == "string" then icon = getTexture(icon) end
        if button.image ~= icon then
            button:setImage(icon)
            button:forceImageSize(InfoWindow.BAND_ICON, InfoWindow.BAND_ICON)
        end
        if not button:getIsVisible() and not self.isCollapsed then button:setVisible(true) end
        self.bandButtonUI = button
    elseif self.bandButtonUI and self.bandButtonUI:getIsVisible() then
        self.bandButtonUI:setVisible(false)
    end
    self.bandBottom = top + height + InfoWindow.PADDING
    return self.bandBottom
end

-- A block's header at y (label a translation key): its name in small grey capitals, then a hairline to the window's
-- edge (user: no lead before the name), a gap above it unless it is the window's first. Returns the y of the block's first row.
function InfoWindow:section(y, label)
    if y > self:top() then y = y + InfoWindow.SECTION_GAP end
    local text = string.upper(getText(label))
    local lineHeight = InfoWindow.lineHeight()
    local hair, lineY = InfoWindow.HAIRLINE, y + math.floor(lineHeight / 2)
    local textX = InfoWindow.PADDING
    drawText(self, text, textX, y, InfoWindow.HEADER_COLOUR)
    local lineX = textX + getTextManager():MeasureStringX(UIFont.Small, text) + InfoWindow.HEADER_SPACE
    self:drawRect(lineX, lineY, self.width - InfoWindow.PADDING - lineX, 1, 1, hair[1], hair[2], hair[3])
    return y + lineHeight + InfoWindow.HEADER_GAP
end

-- An Sdf font is drawn zoomed to Small's height: the zoom for font.
local zooms = {}
local function zoom(font)
    if not zooms[font] then
        local height = getTextManager():getFontHeight(font)
        zooms[font] = height > 0 and InfoWindow.lineHeight() / height or 1
    end
    return zooms[font]
end

-- Bold text centred on x: Small drawn at x and a pixel right of it.
function InfoWindow.boldWidth(text)
    return getTextManager():MeasureStringX(UIFont.Small, text) + 1
end

function InfoWindow.drawBoldCentre(ui, text, x, y, colour)
    local left = x - InfoWindow.boldWidth(text) / 2
    ui:drawText(text, left, y, colour[1], colour[2], colour[3], 1, UIFont.Small)
    ui:drawText(text, left + 1, y, colour[1], colour[2], colour[3], 1, UIFont.Small)
end

local function loreWidth(text)
    return getTextManager():MeasureStringX(UIFont.SdfOldItalic, text) * zoom(UIFont.SdfOldItalic)
end

-- The lore note's lines at width, kept on ui until the text or the width changes.
local function loreLines(ui, text, width)
    if ui.loreText ~= text or ui.loreWidth ~= width then
        ui.loreText, ui.loreWidth, ui.loreLines = text, width, wrapped(text, width, loreWidth)
    end
    return ui.loreLines
end

local HOLDS_LOOK = { value = InfoWindow.VALUE_COLOUR, note = InfoWindow.NOTE_COLOUR, bold = InfoWindow.drawBoldCentre,
    boldWidth = InfoWindow.boldWidth }

-- What the station holds, left to right (Holds.lua's header has the holdings); the window widens to fit them, up to
-- MAX_WIDTH. lore (finished text: a line of real-world history, or nil) goes beside them, wrapped in the room to
-- their right; the window widens to give it LORE_MIN (user: a long fluid name left it out), and only past MAX_WIDTH
-- is it left out. Returns the y under them.
-- What is dragged over the index'th holding's drop target, or nil.
local function judgedOver(window, index)
    local target = window.dropTargetsUI and window.dropTargetsUI[index]
    return target and target.inUse and target:judgedNow() or nil
end

-- A holding with drop (Holds' header) gets a drop target over its tank and heat bar; what a drag over it would do is
-- written by the mouse, as vanilla's own drag hints are.
local function placeTargets(window, holdings, units)
    local any = window.dropTargetsUI ~= nil
    for _, holding in ipairs(holdings) do any = any or holding.drop ~= nil end
    if not any then return end
    local DropZone = require "TraditionalPreservationCore/DropZone"
    local margin = require("TraditionalPreservationCore/Holds").DROP_MARGIN
    for _, target in pairs(window.dropTargetsUI or {}) do target.inUse = false end
    for index, holding in ipairs(holdings) do
        local unit, drop = units[index], holding.drop
        if drop and unit then
            local target = DropZone.placeTarget(window, index, unit.x - margin, unit.y - margin, unit.width + margin * 2,
                unit.height + margin * 2, drop.judge, drop.drop)
            target.inUse = true
        end
    end
    DropZone.showTargets(window, #holdings)
end

local function drawDropHint(window, holdings)
    for index in ipairs(holdings) do
        local judged = judgedOver(window, index)
        if judged then
            local lineHeight = InfoWindow.lineHeight()
            local lines = {}
            for _, line in ipairs(judged.lines or {}) do table.insert(lines, line) end
            if judged.refused and #judged.take > 0 then table.insert(lines, judged.refused) end
            local width = 0
            for _, line in ipairs(lines) do width = math.max(width, getTextManager():MeasureStringX(UIFont.Small, line)) end
            local x, y = window:getMouseX() + 16, window:getMouseY() + 16
            local colour = #judged.take == 0 and InfoWindow.DROP_NO_TEXT or InfoWindow.VALUE_COLOUR
            window:drawRect(x, y, width + 12, #lines * lineHeight + 6, 0.9, 0, 0, 0)
            window:drawRectBorder(x, y, width + 12, #lines * lineHeight + 6, 1, colour[1], colour[2], colour[3])
            for row, line in ipairs(lines) do drawText(window, line, x + 6, y + 3 + (row - 1) * lineHeight, colour) end
        end
    end
end

function InfoWindow:holds(y, holdings, lore)
    local Holds = require "TraditionalPreservationCore/Holds"
    HOLDS_LOOK.judged = function(index) return judgedOver(self, index) end
    local under, needed, units = Holds.draw(self, HOLDS_LOOK, InfoWindow.PADDING, y, holdings)
    placeTargets(self, holdings, units)
    local ruleX = InfoWindow.PADDING + needed + InfoWindow.LORE_GAP
    if lore then
        self:fitWidth(ruleX + InfoWindow.LORE_PAD + InfoWindow.LORE_MIN + InfoWindow.PADDING)
    else
        self:fitWidth(needed + InfoWindow.PADDING * 2)
    end
    if not lore or self.width - InfoWindow.PADDING - ruleX - InfoWindow.LORE_PAD < InfoWindow.LORE_MIN then
        drawDropHint(self, holdings)
        return under + InfoWindow.BAR_GAP
    end
    local textX = ruleX + InfoWindow.LORE_PAD
    local lineHeight = InfoWindow.lineHeight()
    local textY = y + 4
    local colour = InfoWindow.LORE_COLOUR
    for _, line in ipairs(loreLines(self, lore, self.width - InfoWindow.PADDING - textX)) do
        self:drawTextZoomed(line, textX, textY, zoom(UIFont.SdfOldItalic), colour[1], colour[2], colour[3], 1, UIFont.SdfOldItalic)
        textY = textY + lineHeight
    end
    local rule = InfoWindow.LORE_RULE
    self:drawRect(ruleX, y, 2, math.max(textY + 4, y + Holds.HEIGHT) - y, 1, rule[1], rule[2], rule[3])
    drawDropHint(self, holdings)
    return math.max(under, textY + 4) + InfoWindow.BAR_GAP
end

-- Widens the window to width, up to MAX_WIDTH; it never narrows while open, and a resize doesn't take it narrower.
function InfoWindow:fitWidth(width)
    width = math.min(math.ceil(width), InfoWindow.MAX_WIDTH)
    if width > (self.minimumWidth or 0) then self.minimumWidth = width end
    if width > self.width then self:setWidth(width) end
end

-- Widths a player gave the windows that resize, by widthKey: read from WIDTHS_FILE once, one "key=width" a line.
local savedWidths
local function widths()
    if savedWidths then return savedWidths end
    savedWidths = {}
    local reader = getFileReader(InfoWindow.WIDTHS_FILE, false)
    if not reader then return savedWidths end
    local line = reader:readLine()
    while line do
        local key, width = string.match(line, "^(.-)=(%d+)$")
        if key then savedWidths[key] = tonumber(width) end
        line = reader:readLine()
    end
    reader:close()
    return savedWidths
end

local function saveWidths()
    local writer = getFileWriter(InfoWindow.WIDTHS_FILE, true, false)
    if not writer then return end
    for key, width in pairs(widths()) do writer:write(key .. "=" .. tostring(width) .. "\n") end
    writer:close()
end

-- The resize widget's drag: the width only, between the window's least (WIDTH, or wider for what it holds) and
-- MAX_WIDTH; the height stays the window's own.
local function resizeToWidth(window, width)
    width = math.max(window.minimumWidth or InfoWindow.WIDTH, math.min(math.floor(width), InfoWindow.MAX_WIDTH))
    if width ~= window.width then
        window:setWidth(width)
        window.widthToSave = true
    end
end

-- A window with a list resizes in width only (vanilla's resize widget at its corner; the bottom edge's is hidden),
-- from WIDTH to MAX_WIDTH, opening at the width last given a window of the same widthKey (its station type; the
-- window's class unless it sets one). Made on the first call.
function InfoWindow:resizeWidth()
    if self.widthResizes then return end
    self.widthResizes = true
    self.minimumWidth = math.max(self.minimumWidth or 0, InfoWindow.WIDTH)
    self:setResizable(true)
    if self.resizeWidget2 then self.resizeWidget2:setVisible(false) end
    self.resizeWidget.resizeFunction = resizeToWidth
    local saved = widths()[self.widthKey or self.Type]
    if saved then resizeToWidth(self, saved) end
    self.widthToSave = false
end

-- The width given by a drag, kept once the drag ends.
function keepWidth(window)
    if not window.widthToSave or window.resizeWidget.resizing then return end
    window.widthToSave = false
    widths()[window.widthKey or window.Type] = window.width
    saveWidths()
end

-- The pieces, one row each, under a header (label is a translation key) with the sort switch; rows as PieceList's
-- header says, a new table each refresh. The window resizes in width from then on (resizeWidth). Returns the y under
-- the list.
function InfoWindow:pieceList(y, label, rows)
    self:resizeWidth()
    return require("TraditionalPreservationCore/PieceList").draw(self, LIST_LOOK, y, getText(label), rows)
end

-- A list whose header line is already text (a count: "2 lots").
function InfoWindow:pieceListNamed(y, labelText, rows)
    self:resizeWidth()
    return require("TraditionalPreservationCore/PieceList").draw(self, LIST_LOOK, y, labelText, rows)
end

-- The drop square (DropZone.lua's header): idleText (finished text) at rest beside icon (what it takes: a Texture or
-- texture name, or nil), judge(items) while a selection is dragged over it, drop(take) on release. Returns the y
-- under it.
function InfoWindow:dropZone(y, idleText, judge, drop, icon)
    return require("TraditionalPreservationCore/DropZone").draw(self, InfoWindow.PADDING, InfoWindow.BAR_GAP, y, idleText, judge, drop, icon)
end

-- Buttons across the window at y, each { title (finished text, a count in brackets: "Take All (5)"), icon (what it
-- gives or uses: a Texture or texture name, or nil), enabled, tooltip (or nil; a disabled one says why), onClick (button) },
-- each as wide as its text, onto a new line when the next doesn't fit; made on the first call, then kept and set from
-- the list each draw. Returns the y under them.
local function onButton(entry, button)
    if entry.onClick then entry.onClick(button) end
end

local function buttonWidth(entry)
    local width = getTextManager():MeasureStringX(UIFont.Small, entry.title) + InfoWindow.BUTTON_PAD * 2
    if entry.icon then width = width + InfoWindow.BUTTON_ICON + 5 end
    return width
end

-- Each width's { x, line } placed left to right in room, a new line when the next doesn't fit; and the lines used.
function InfoWindow.buttonLayout(widths, room, gap)
    local placed, x, line = {}, 0, 0
    for index, width in ipairs(widths) do
        if x > 0 and x + width > room then x, line = 0, line + 1 end
        placed[index] = { x = x, line = line }
        x = x + width + gap
    end
    return placed, #widths > 0 and line + 1 or 0
end

-- Vanilla's ISButton draws its icon (drawTextureScaled) and image at full alpha, enabled or not: a disabled button's
-- are drawn at DISABLED_ICON_ALPHA, the title where it always is.
InfoWindow.DISABLED_ICON_ALPHA = 0.35

local function dimmedTexture(button, texture, x, y, width, height, alpha, r, g, b)
    if texture == button.iconTexture then alpha = InfoWindow.DISABLED_ICON_ALPHA end
    ISUIElement.drawTextureScaled(button, texture, x, y, width, height, alpha, r, g, b)
end

local function renderButton(button)
    if not button.enable then button.drawTextureScaled = dimmedTexture end
    ISButton.render(button)
    button.drawTextureScaled = nil
end

-- A button on window for entry, made when button is nil, placed at x, top and set from entry. Returns it.
function placeButton(window, button, entry, x, top, width, height)
    if not button then
        button = ISButton:new(0, 0, width, height, "", {}, onButton)
        button:initialise()
        button:instantiate()
        button.joypadTextureWH = InfoWindow.BUTTON_ICON
        button.render = renderButton
        window:addChild(button)
    end
    button.target = entry
    if button.x ~= x then button:setX(x) end
    if button.y ~= top then button:setY(top) end
    if button.width ~= width then button:setWidth(width) end
    if button.height ~= height then button:setHeight(height) end
    if button.title ~= entry.title then button:setTitle(entry.title) end
    if button.enable ~= entry.enabled then button:setEnable(entry.enabled) end
    button.textureColor.a = entry.enabled and 1 or InfoWindow.DISABLED_ICON_ALPHA
    local icon = entry.icon
    if type(icon) == "string" then icon = getTexture(icon) end
    button.iconTexture = icon
    button:setTooltip(entry.tooltip)
    return button
end

function InfoWindow:buttonRow(y, buttons)
    self.buttonsUI = self.buttonsUI or {}
    local widths = {}
    for index, entry in ipairs(buttons) do widths[index] = buttonWidth(entry) end
    local placed, lines = InfoWindow.buttonLayout(widths, self.width - InfoWindow.PADDING * 2, InfoWindow.BUTTON_GAP)
    for index, entry in ipairs(buttons) do
        local top = y + placed[index].line * (InfoWindow.BUTTON_HEIGHT + InfoWindow.BUTTON_GAP)
        self.buttonsUI[index] = placeButton(self, self.buttonsUI[index], entry, InfoWindow.PADDING + placed[index].x, top,
            widths[index], InfoWindow.BUTTON_HEIGHT)
    end
    if lines == 0 then return y end
    return y + lines * InfoWindow.BUTTON_HEIGHT + (lines - 1) * InfoWindow.BUTTON_GAP + InfoWindow.BAR_GAP
end

-- The notes, after which the window fits its height to them.
function InfoWindow:drawNotes(y, notes)
    local height = InfoWindow.drawNoteLines(self, LAYOUT, y, notes) + InfoWindow.PADDING
    if self.height ~= height then self:setHeight(height) end
end

return InfoWindow
