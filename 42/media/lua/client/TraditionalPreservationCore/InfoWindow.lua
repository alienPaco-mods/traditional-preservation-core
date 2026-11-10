-- Traditional Preservation core: the base of every station's info window (Hearth Info, Dairy's Incubator and Crock
-- Info). Rows of label and value, filled bars and wrapped notes, kept up to date while open. It closes when the player
-- walks off or the station is gone. One info window at a time, whatever the mod: opening another closes the last.
-- A window derives this, sets its title in new, fills self.info in refresh and draws it in render:
--     local MyWindow = InfoWindow:derive("MyModWindow")
--     function MyWindow.open(playerObj, station) InfoWindow.open(MyWindow, playerObj, station) end
require "ISUI/ISCollapsableWindow"
local Station = require "TraditionalPreservationCore/Station"

local InfoWindow = ISCollapsableWindow:derive("TraditionalPreservationCoreInfoWindow")

InfoWindow.WIDTH = 360
InfoWindow.REACH = 6
InfoWindow.PADDING = 10
InfoWindow.LABEL_WIDTH = 120
InfoWindow.BAR_HEIGHT = 12
InfoWindow.REFRESH_TICKS = 30

local current -- the info window open, from any mod

function InfoWindow.inReach(playerObj, station)
    local square = station:getSquare()
    return square ~= nil and not playerObj:isDead() and square:getZ() == playerObj:getZ()
        and IsoUtils.DistanceTo(playerObj:getX(), playerObj:getY(), square:getX() + 0.5, square:getY() + 0.5) <= InfoWindow.REACH
end

function InfoWindow:new(playerObj, station)
    local x = getCore():getScreenWidth() / 2 - InfoWindow.WIDTH / 2
    local o = ISCollapsableWindow.new(self, x, getCore():getScreenHeight() / 3, InfoWindow.WIDTH, 200)
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

-- The y of the first row, under the title bar.
function InfoWindow:top()
    return self:titleBarHeight() + InfoWindow.PADDING
end

-- Draws a label (a translation key) and value line at y and returns the next line's y. bar does the same with a
-- filled bar, share 0 to 1, colour { r, g, b }.
function InfoWindow:row(y, label, value)
    self:drawText(getText(label), InfoWindow.PADDING, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
    self:drawText(value, InfoWindow.PADDING + InfoWindow.LABEL_WIDTH, y, 1, 1, 1, 1, UIFont.Small)
    return y + getTextManager():getFontHeight(UIFont.Small) + 2
end

function InfoWindow:bar(y, label, share, colour, value)
    local lineHeight = getTextManager():getFontHeight(UIFont.Small)
    local x = InfoWindow.PADDING + InfoWindow.LABEL_WIDTH
    local width = self.width - x - InfoWindow.PADDING
    local top = y + (lineHeight - InfoWindow.BAR_HEIGHT) / 2
    self:drawText(getText(label), InfoWindow.PADDING, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
    self:drawRect(x, top, width, InfoWindow.BAR_HEIGHT, 0.6, 0.1, 0.1, 0.1)
    self:drawRect(x, top, width * math.max(0, math.min(share, 1)), InfoWindow.BAR_HEIGHT, 0.9, colour[1], colour[2], colour[3])
    self:drawRectBorder(x, top, width, InfoWindow.BAR_HEIGHT, 0.8, 0.4, 0.4, 0.4)
    self:drawTextCentre(value, x + width / 2, y, 1, 1, 1, 1, UIFont.Small)
    return y + lineHeight + 4
end

-- The notes in a muted colour, wrapped to the window, which then fits its height to them.
function InfoWindow:drawNotes(y, notes)
    local lineHeight = getTextManager():getFontHeight(UIFont.Small)
    for _, note in ipairs(notes) do
        y = y + 4
        for _, line in ipairs(wrapped(note, self.width - InfoWindow.PADDING * 2)) do
            self:drawText(line, InfoWindow.PADDING, y, 0.8, 0.8, 0.65, 1, UIFont.Small)
            y = y + lineHeight
        end
    end
    local height = y + InfoWindow.PADDING
    if self.height ~= height then self:setHeight(height) end
end

return InfoWindow
