-- Traditional Preservation core: the base of every station's info window (Hearth Info, Dairy's Incubator and Crock
-- Info). Rows of label and value, filled bars and wrapped notes, kept up to date while open. It closes when the player
-- walks off or the station is gone. One info window at a time, whatever the mod: opening another closes the last.
-- InfoWindow.clickOpens makes a click on the station open it.
-- A window derives this, sets its title in new, fills self.info in refresh and draws it in render:
--     local MyWindow = InfoWindow:derive("MyModWindow")
--     function MyWindow.open(playerObj, station) InfoWindow.open(MyWindow, playerObj, station) end
-- The drawing (drawRow, drawBar, noteLines, drawNoteLines) is shared with StationInfo's block in vanilla's crafting
-- window: each takes the element to draw on and its layout { padding, labelWidth, barHeight }.
require "ISUI/ISCollapsableWindow"
local Station = require "TraditionalPreservationCore/Station"

local InfoWindow = ISCollapsableWindow:derive("TraditionalPreservationCoreInfoWindow")

InfoWindow.WIDTH = 360
InfoWindow.REACH = 6
InfoWindow.PADDING = 10
InfoWindow.LABEL_WIDTH = 120
InfoWindow.BAR_HEIGHT = 12
InfoWindow.REFRESH_TICKS = 30
InfoWindow.START_HEIGHT = 200   -- drawNotes fits it to what is drawn
InfoWindow.VALUE_CACHE = 32     -- row values kept wrapped before the cache starts over (a value counts down)
InfoWindow.ROW_GAP, InfoWindow.BAR_GAP, InfoWindow.NOTE_GAP = 2, 4, 4
-- Text colours { r, g, b }: a row's label, its value, the notes; a bar's empty part and border.
InfoWindow.LABEL_COLOUR = { 0.7, 0.7, 0.7 }
InfoWindow.VALUE_COLOUR = { 1, 1, 1 }
InfoWindow.NOTE_COLOUR = { 0.8, 0.8, 0.65 }
InfoWindow.BAR_BACK, InfoWindow.BAR_BORDER = { 0.1, 0.1, 0.1 }, { 0.4, 0.4, 0.4 }

local LAYOUT = { padding = InfoWindow.PADDING, labelWidth = InfoWindow.LABEL_WIDTH, barHeight = InfoWindow.BAR_HEIGHT }

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

-- Fills self.info; a window's own refresh replaces this. Run twice a second, not every frame.
function InfoWindow:refresh()
end

function InfoWindow:update()
    ISCollapsableWindow.update(self)
    if not Station.isLoaded(self.station) or not InfoWindow.inReach(self.playerObj, self.station) then return self:close() end
    self.ticks = self.ticks + 1
    if self.ticks >= InfoWindow.REFRESH_TICKS then
        self.ticks = 0
        self:refresh()
    end
end

-- Words that run past the window go on to the next line.
local function wrapped(text, width)
    local lines, line = {}, ""
    for word in string.gmatch(text, "%S+") do
        local longer = line == "" and word or line .. " " .. word
        if line ~= "" and getTextManager():MeasureStringX(UIFont.Small, longer) > width then
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

-- A row's value wrapped to width, at least one line. Kept in owner until the width changes; a value changes as its
-- time counts down, so the cache starts over once it holds 32 texts.
function InfoWindow.valueLines(owner, value, width)
    if owner.valueWidth ~= width or owner.valueCount > InfoWindow.VALUE_CACHE then
        owner.valueWidth, owner.valueCache, owner.valueCount = width, {}, 0
    end
    local lines = owner.valueCache[value]
    if not lines then
        lines = wrapped(value, width)
        if #lines == 0 then lines = { value } end
        owner.valueCache[value], owner.valueCount = lines, owner.valueCount + 1
    end
    return lines
end

-- The y of the first row, under the title bar.
function InfoWindow:top()
    return self:titleBarHeight() + InfoWindow.PADDING
end

function InfoWindow.lineHeight()
    return getTextManager():getFontHeight(UIFont.Small)
end

local function drawText(ui, text, x, y, colour)
    ui:drawText(text, x, y, colour[1], colour[2], colour[3], 1, UIFont.Small)
end

-- A row's value lines when ui is width wide (the space right of the label), kept on ui.
function InfoWindow.rowLines(ui, layout, value, width)
    return InfoWindow.valueLines(ui, value, width - layout.padding * 2 - layout.labelWidth)
end

-- Draws label (text) and the value's lines at y on ui; returns the next row's y.
function InfoWindow.drawRow(ui, layout, y, label, value)
    local lineHeight = InfoWindow.lineHeight()
    drawText(ui, label, layout.padding, y, InfoWindow.LABEL_COLOUR)
    for _, line in ipairs(InfoWindow.rowLines(ui, layout, value, ui.width)) do
        drawText(ui, line, layout.padding + layout.labelWidth, y, InfoWindow.VALUE_COLOUR)
        y = y + lineHeight
    end
    return y + InfoWindow.ROW_GAP
end

-- Draws label (text) and a bar filled to share (0 to 1) in colour { r, g, b }, value in its middle; returns the next y.
function InfoWindow.drawBar(ui, layout, y, label, share, colour, value)
    local lineHeight = InfoWindow.lineHeight()
    local x = layout.padding + layout.labelWidth
    local width = ui.width - x - layout.padding
    local top = y + (lineHeight - layout.barHeight) / 2
    local back, border = InfoWindow.BAR_BACK, InfoWindow.BAR_BORDER
    drawText(ui, label, layout.padding, y, InfoWindow.LABEL_COLOUR)
    ui:drawRect(x, top, width, layout.barHeight, 0.6, back[1], back[2], back[3])
    ui:drawRect(x, top, width * math.max(0, math.min(share, 1)), layout.barHeight, 0.9, colour[1], colour[2], colour[3])
    ui:drawRectBorder(x, top, width, layout.barHeight, 0.8, border[1], border[2], border[3])
    ui:drawTextCentre(value, x + width / 2, y, 1, 1, 1, 1, UIFont.Small)
    return y + lineHeight + InfoWindow.BAR_GAP
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

-- A window's row: label is a translation key. Returns the next line's y. bar does the same with a filled bar.
function InfoWindow:row(y, label, value)
    return InfoWindow.drawRow(self, LAYOUT, y, getText(label), value)
end

function InfoWindow:bar(y, label, share, colour, value)
    return InfoWindow.drawBar(self, LAYOUT, y, getText(label), share, colour, value)
end

-- The notes, after which the window fits its height to them.
function InfoWindow:drawNotes(y, notes)
    local height = InfoWindow.drawNoteLines(self, LAYOUT, y, notes) + InfoWindow.PADDING
    if self.height ~= height then self:setHeight(height) end
end

-- Clicking a station opens its info window, as clicking a door opens it. test(object) says whether the object is
-- the mod's station, and open(playerObj, object) opens the window. Not while paused, aiming or out of reach:
-- vanilla's own checks for a click. Wraps ISObjectClickHandler.doClickSpecificObject once for every mod; it is in
-- vanilla's server folder, which loads after this one, so it is wrapped once the game has started.
local clicks = {}

local function canClick(object, playerObj)
    return playerObj and not playerObj:isAiming()
        and not (UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0)
        and InfoWindow.inReach(playerObj, object)
end

local function wrapClickHandler()
    if not ISObjectClickHandler or ISObjectClickHandler.tpInfoClick then return end
    local vanillaClickObject = ISObjectClickHandler.doClickSpecificObject
    ISObjectClickHandler.tpInfoClick = true
    function ISObjectClickHandler.doClickSpecificObject(object, playerNum, playerObj)
        if object then
            for _, click in ipairs(clicks) do
                if click.test(object) then
                    if not canClick(object, playerObj) then break end
                    click.open(playerObj, object)
                    return true
                end
            end
        end
        return vanillaClickObject(object, playerNum, playerObj)
    end
end

function InfoWindow.clickOpens(test, open)
    assert(type(test) == "function" and type(open) == "function", "InfoWindow.clickOpens: test and open (functions) needed")
    if #clicks == 0 then Events.OnGameStart.Add(wrapClickHandler) end
    table.insert(clicks, { test = test, open = open })
end

return InfoWindow
