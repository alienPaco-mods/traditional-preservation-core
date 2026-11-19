-- Traditional Preservation core: an info window's drop square. A selection dragged from the inventory or a loot
-- window (vanilla's ISMouseDrag, read as vanilla's crafting slots read it: ISInventoryPane.getActualItems) is judged
-- while it is held over the square, which turns green when it takes everything, orange when it takes some and refuses
-- the rest, red when it takes nothing, with what would happen or why not, and on release the
-- station takes what it takes. At rest it says what it takes. A window doesn't make one itself:
-- InfoWindow:dropZone(y, idleText, judge, drop) draws it in the window's flow.
--   judge(items)  returns { take = the items it would take, lines = text lines to show, refused = why the others
--                 aren't taken (finished text) or nil }; called while dragging over the square and on release
--   drop(take)    takes them (queues the hand jobs); what was refused shows over the player in red
require "ISUI/ISPanel"

local DropZone = ISPanel:derive("TraditionalPreservationCoreDropZone")

DropZone.HEIGHT = 60          -- three lines of text
DropZone.TEXT_MARGIN = 6
DropZone.DASH, DropZone.GAP, DropZone.EDGE = 6, 4, 2
DropZone.IDLE_EDGE = { 0.47, 0.47, 0.47 }
DropZone.OK_EDGE, DropZone.OK_FILL = { 0.4, 0.78, 0.4 }, { 0.24, 0.55, 0.24, 0.2 }
DropZone.SOME_EDGE, DropZone.SOME_FILL = { 0.92, 0.6, 0.25 }, { 0.65, 0.4, 0.15, 0.2 }
DropZone.NO_EDGE, DropZone.NO_FILL = { 0.86, 0.35, 0.27 }, { 0.63, 0.24, 0.2, 0.2 }
DropZone.IDLE_TEXT, DropZone.OK_TEXT, DropZone.NO_TEXT = { 0.7, 0.7, 0.7 }, { 1, 1, 1 }, { 0.9, 0.43, 0.35 }

-- What is being dragged now, as items (a collapsed stack as its items), or nil.
function DropZone.dragged()
    if ISMouseDrag.dragging == nil then return nil end
    return ISInventoryPane.getActualItems(ISMouseDrag.dragging)
end

function DropZone:new(x, y, width, window)
    local o = ISPanel.new(self, x, y, width, DropZone.HEIGHT)
    o.background = false
    o.window = window
    o.valueCount = 0
    return o
end

-- The judgement of what is dragged, kept while the same drag is held (judge runs once a drag, not every frame).
function DropZone:judgement()
    local dragging = ISMouseDrag.dragging
    if dragging == nil then
        self.judged, self.judgedFor = nil, nil
        return nil
    end
    if self.judgedFor ~= dragging then
        self.judgedFor, self.judged = dragging, self.judge(DropZone.dragged())
    end
    return self.judged
end

local function dashedLine(ui, x0, y0, x1, y1, colour)
    local step = DropZone.DASH + DropZone.GAP
    if y0 == y1 then
        for x = x0, x1, step do
            ui:drawRect(x, y0, math.min(DropZone.DASH, x1 - x), DropZone.EDGE, 1, colour[1], colour[2], colour[3])
        end
    else
        for y = y0, y1, step do
            ui:drawRect(x0, y, DropZone.EDGE, math.min(DropZone.DASH, y1 - y), 1, colour[1], colour[2], colour[3])
        end
    end
end

function DropZone:render()
    local judged = self:isMouseOver() and self:judgement() or nil
    local edge, textColour, lines = DropZone.IDLE_EDGE, DropZone.IDLE_TEXT, { self.idleText }
    if judged then
        -- Green: all of it; orange: some, the rest refused; red: none.
        local fill
        if #judged.take == 0 then
            fill, edge, textColour = DropZone.NO_FILL, DropZone.NO_EDGE, DropZone.NO_TEXT
        elseif judged.refused then
            fill, edge, textColour = DropZone.SOME_FILL, DropZone.SOME_EDGE, DropZone.OK_TEXT
        else
            fill, edge, textColour = DropZone.OK_FILL, DropZone.OK_EDGE, DropZone.OK_TEXT
        end
        self:drawRect(0, 0, self.width, self.height, fill[4], fill[1], fill[2], fill[3])
        lines = judged.lines
    end
    local w, h = self.width - DropZone.EDGE, self.height - DropZone.EDGE
    dashedLine(self, 0, 0, w, 0, edge)
    dashedLine(self, 0, h, w, h, edge)
    dashedLine(self, 0, 0, 0, h, edge)
    dashedLine(self, w, 0, w, h, edge)
    -- Each line wrapped to the square (InfoWindow's cache keeps the wrapping from frame to frame).
    local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
    local shown = {}
    for _, line in ipairs(lines) do
        for _, part in ipairs(InfoWindow.valueLines(self, line, self.width - DropZone.TEXT_MARGIN * 2)) do table.insert(shown, part) end
    end
    local lineHeight = getTextManager():getFontHeight(UIFont.Small)
    local y = (self.height - #shown * lineHeight) / 2
    for _, line in ipairs(shown) do
        self:drawTextCentre(line, self.width / 2, y, textColour[1], textColour[2], textColour[3], 1, UIFont.Small)
        y = y + lineHeight
    end
end

-- Released over the square: the station takes what it takes; the rest's reason shows over the player.
function DropZone:onMouseUp(x, y)
    local items = DropZone.dragged()
    if not items then return end
    local judged = self.judge(items)
    self.judged, self.judgedFor = nil, nil
    if #judged.take > 0 then self.drop(judged.take) end
    if judged.refused and self.window and self.window.playerObj then
        HaloTextHelper.addBadText(self.window.playerObj, judged.refused)
    end
end

-- The square on window, made on the first call. Returns it.
function DropZone.of(window, padding)
    local zone = window.dropZoneUI
    if zone then return zone end
    zone = DropZone:new(padding, 0, window.width - padding * 2, window)
    zone:initialise()
    zone:instantiate()
    window:addChild(zone)
    window.dropZoneUI = zone
    return zone
end

-- Places the square at y on window with these words and rules; returns the y under it.
function DropZone.draw(window, padding, gap, y, idleText, judge, drop)
    local zone = DropZone.of(window, padding)
    zone.idleText, zone.judge, zone.drop = idleText, judge, drop
    if zone.y ~= y then zone:setY(y) end
    return y + zone.height + gap
end

-- Hides or shows the square (a collapsed window).
function DropZone.show(window, visible)
    local zone = window.dropZoneUI
    if zone and zone:getIsVisible() ~= visible then zone:setVisible(visible) end
end

return DropZone
