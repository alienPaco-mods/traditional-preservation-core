-- Traditional Preservation core: an info window's drop square. A selection dragged from the inventory or a loot
-- window (vanilla's ISMouseDrag, read as vanilla's crafting slots read it: ISInventoryPane.getActualItems) is judged
-- while it is held over the square, whose border turns white when it takes everything, orange when it takes some and
-- refuses the rest, red when it takes nothing, with what would happen or why not, and on release the
-- station takes what it takes. At rest it says what it takes, beside an icon of it. A window doesn't make one itself:
-- InfoWindow:dropZone(y, idleText, judge, drop, icon) draws it in the window's flow.
--   judge(items)  returns { take = the items it would take, lines = text lines to show, refused = why the others
--                 aren't taken (finished text) or nil }; called while dragging over the square and on release
--   drop(take)    takes them (queues the hand jobs); what was refused shows over the player in red
require "ISUI/ISPanel"

local DropZone = ISPanel:derive("TraditionalPreservationCoreDropZone")

DropZone.HEIGHT = 56          -- three lines of text
DropZone.TEXT_MARGIN = 6
DropZone.ICON, DropZone.ICON_GAP = 16, 6
DropZone.DASH, DropZone.GAP, DropZone.EDGE = 6, 4, 2
DropZone.IDLE_EDGE = { 0.47, 0.47, 0.47 }
DropZone.OK_EDGE, DropZone.OK_FILL = { 1, 1, 1 }, { 0.24, 0.55, 0.24, 0.2 }
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
    -- At rest, one line: the icon before it, the two centred together.
    local icon = not judged and #shown == 1 and self.icon
    if type(icon) == "string" then icon = getTexture(icon) end
    if icon then
        local textWidth = getTextManager():MeasureStringX(UIFont.Small, shown[1])
        local x = (self.width - textWidth - DropZone.ICON - DropZone.ICON_GAP) / 2
        self:drawTextureScaledAspect(icon, x, (self.height - DropZone.ICON) / 2, DropZone.ICON, DropZone.ICON, 1, 1, 1, 1)
        self:drawText(shown[1], x + DropZone.ICON + DropZone.ICON_GAP, y, textColour[1], textColour[2], textColour[3], 1, UIFont.Small)
        return
    end
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

-- Places the square at y on window with these words, rules and icon; returns the y under it.
function DropZone.draw(window, padding, gap, y, idleText, judge, drop, icon)
    local zone = DropZone.of(window, padding)
    zone.idleText, zone.judge, zone.drop, zone.icon = idleText, judge, drop, icon
    if zone.width ~= window.width - padding * 2 then zone:setWidth(window.width - padding * 2) end
    if zone.y ~= y then zone:setY(y) end
    return y + zone.height + gap
end

-- Hides or shows the square (a collapsed window).
function DropZone.show(window, visible)
    local zone = window.dropZoneUI
    if zone and zone:getIsVisible() ~= visible then zone:setVisible(visible) end
end

-- A drop target over something the window draws (a holding's tank, Holds): it judges and takes a drag as the square
-- does, but draws nothing itself; the window draws its frame from judgedNow(), over its own drawing.
local DropTarget = DropZone:derive("TraditionalPreservationCoreDropTarget")

function DropTarget:render()
end

-- The judgement while a selection is dragged over it, else nil.
function DropTarget:judgedNow()
    if not self:getIsVisible() or not self:isMouseOver() then return nil end
    return self:judgement()
end

-- Window's index'th target at x, y, width, height with these rules, made on the first call. Returns it.
function DropZone.placeTarget(window, index, x, y, width, height, judge, drop)
    window.dropTargetsUI = window.dropTargetsUI or {}
    local target = window.dropTargetsUI[index]
    if not target then
        target = DropTarget:new(x, y, width, window)
        target:initialise()
        target:instantiate()
        window:addChild(target)
        window.dropTargetsUI[index] = target
    end
    target.judge, target.drop = judge, drop
    if target.x ~= x then target:setX(x) end
    if target.y ~= y then target:setY(y) end
    if target.width ~= width then target:setWidth(width) end
    if target.height ~= height then target:setHeight(height) end
    if not target:getIsVisible() and not window.isCollapsed then target:setVisible(true) end
    return target
end

-- Hides the window's targets past count (the holdings drawn this time), and all of them when collapsed.
function DropZone.showTargets(window, count)
    for index, target in pairs(window.dropTargetsUI or {}) do
        local visible = index <= count and not window.isCollapsed and target.inUse
        if target:getIsVisible() ~= visible then target:setVisible(visible) end
    end
end

return DropZone
