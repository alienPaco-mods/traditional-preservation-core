-- Traditional Preservation core: an info window's Holds block, what a station holds drawn standing up, left to right
-- in the order things move through it. A fluid is a tank (vanilla's fluid gradient over the fluid's colour, ticks at
-- quarters, thin bands at the top for layers: a mother's skin); anything else held is a column of cells (wood, soil,
-- a rack's load, jars), a real count where it is small, else five cells of a share; heat on its own is a
-- thermometer, its column coloured by its own heat, with marks (85 steam, 100 boils). A tank that is heated (the
-- cauldron, the salt pan) carries its heat as a thin bar beside it (user): its top level with the tank's, a line
-- short of its foot, its temperature centred under it, ticks at its marks. Under each: its name in bold, its amount,
-- a state line and a line under that if it has them, centred under the tank and its heat bar as one. A holding with
-- an arrow draws one to the next, its text (a rate) above it. A window doesn't draw one itself: InfoWindow:holds(y,
-- holdings) draws it in the window's flow.
-- holdings is a list of
--   { kind = "tank", name, amount, state, stateColour, under, underColour, share (0 to 1), colour { r, g, b }, layers (bands, or
--     nil), heat = { celsius (nil: no reading), marks = { { celsius, text } } } or nil, settled = { share (0 to 1),
--     colour } or nil: what has settled out at its foot under the fluid, the salt a boil leaves (user), drop =
--     { judge(items), drop(take) } or nil: buckets dragged onto the tank pour in (InfoWindow:holds; judge returns
--     DropZone's { take, lines, refused } and adds, the share of the tank the pour would fill), working = { speed,
--     foam, spill } or nil: a tank at work (a batch fermenting), bubbles rising through its liquid, speed times
--     Holds.BUBBLE_SPEED (0: still), a foam cap on top, foam (0 to 1) of Holds.FOAM thick, and with spill foam
--     running down its side, line = { share, text } or nil: a dashed line across at that share of the tank, its text
--     beside it (the vessel's headspace) }
--   { kind = "cells", name, amount, state, stateColour, cells (default 5),
--     filled (cells full; default the share's), share, colour, drop = { judge, drop } or nil: what is dragged onto the
--     cells goes on, in place of a drop square (user); judge adds cells, the cells it would fill, shown see-through,
--     and pattern, theirs;
--     pattern (a texture path: every full cell drawn in it, tools/cell_patterns.py) or parts ({ { pattern, weight } }:
--     a mixed holding, its full cells split by Holds.byShare) in place of the flat colour }
--   { kind = "heat", name, amount, state, stateColour, celsius (nil: nothing to warm), top (the scale's top C,
--     default 100), marks = { { celsius, text } } }
--   { kind = "slot", name, nameColour, amount, state, stateColour, icons (one or two textures: two are split on the
--     diagonal, the first top left, when either fits), look ("empty": dashed, the icons greyed, what it takes; "in":
--     bright; "pending": greyed in a solid frame, what will come back; "ready": bright in a green frame), count (text at
--     its foot's right, or nil), drop = { judge, drop } or nil as a tank's, click = function() or nil (a left click),
--     menu = function(context) or nil (a right click fills a menu): a starter (user, session 69,
--     art/starter_path_mock.png): what goes in, left of its tank with an arrow into it, and what comes back (kefir's
--     grains, the vinegar mother) right of it with an arrow out. The slot stands on the tank's middle line. }
-- any of them with counts = { { icon (a Texture or texture path), count } } or nil: a last line of small icons, each
-- with its count beside it (the kraut barrel's apples and carrots; user, session 72, art/kraut_spiked_mock.png B);
-- each with arrow (text above an arrow to the next holding, "" for a plain one, nil for none) and arrowColour
-- ({ r, g, b }, or nil for the usual grey). An arrow to or from a slot is SLOT_ARROW long.

local Holds = {}

Holds.HEIGHT = 96            -- the tank, the cells, the thermometer with its bulb
Holds.TANK_WIDTH = 34
Holds.CELL_WIDTH = Holds.TANK_WIDTH   -- cells stand as tall and wide as a tank (user)
Holds.CELL_GAP = 2
Holds.CELLS = 5              -- cells for a share
Holds.TUBE = 10              -- the thermometer's glass
Holds.COLUMN_INSET = 3       -- the column inside the glass
Holds.BULB = 20
Holds.MARK_GAP = 4           -- a mark's line to its text
Holds.TICK = 5
Holds.COLUMN_PAD = 8         -- either side of a holding
Holds.ARROW_MIN = 64
Holds.ARROW_PAD = 8          -- an arrow's ends to the holdings
Holds.TEXT_GAP = 4           -- the graphic to its name
Holds.HEAT_BAR = 12          -- a tank's heat bar
Holds.HEAT_GAP = 6           -- the tank to its heat's room
Holds.LEADER = 12            -- crowded marks: their text this much further right, a slanted line from each tick to it
Holds.LEADER_COLOUR = { 0.55, 0.55, 0.55 }
Holds.SETTLED_MIN = 3        -- a settled layer's least height, so a little still shows
Holds.BUBBLE_SPEED = 8       -- a working tank's bubbles rise this many pixels a second at speed 1
Holds.FOAM = 3               -- its foam cap's height at foam 1
Holds.FOAM_COLOUR, Holds.BUBBLE_COLOUR = { 0.93, 0.89, 0.78 }, { 1, 0.96, 0.86 }
Holds.SPILL = 14             -- foam running over: how far down the tank's side
Holds.LINE_GAP = 4           -- a tank's line to its text
Holds.SLOT = 34              -- a starter's slot, square
Holds.SLOT_ICON = 28
Holds.SLOT_ARROW = 34        -- an arrow to or from a slot
Holds.SLOT_DASH = 2          -- the empty slot's dashes, and the gaps between them
Holds.GREYED = { 0.6, 0.6, 0.6, 0.4 }     -- an icon greyed: tint and alpha
Holds.READY = { 0.59, 0.82, 0.51 }        -- what is there to take: its frame
-- Where a working tank's bubbles start: { across (0 to 1), up (0 to 1) }.
local BUBBLES = { { 0.25, 0.15 }, { 0.6, 0.45 }, { 0.4, 0.75 }, { 0.75, 0.9 }, { 0.2, 0.55 }, { 0.55, 0.2 } }
Holds.DROP_MARGIN = 6        -- a drop frame round its holding
Holds.PREVIEW_ALPHA = 0.45   -- a pour shown in the tank before it is made, see-through as vanilla's fluid bar
Holds.DROP_OK, Holds.DROP_SOME, Holds.DROP_NO = { 1, 1, 1 }, { 0.92, 0.6, 0.25 }, { 0.86, 0.35, 0.27 }
Holds.BACK = { 0, 0, 0 }
Holds.BORDER = { 0.6, 0.6, 0.6 }
Holds.EMPTY_CELL = { 0.12, 0.12, 0.12 }
Holds.CELL_COLOUR = { 0.6, 0.38, 0.2 }    -- cells with no colour of their own: wood
Holds.TANK_COLOUR = { 0.42, 0.42, 0.44 }  -- a tank with no fluid colour: its iron
Holds.GLASS = { 0.75, 0.75, 0.75 }
Holds.ARROW = { 0.7, 0.7, 0.7 }
Holds.GRADIENT_ALPHA = 0.35
-- A thermometer's colour along its heat: blue cold, amber warm, orange hot, red near the boil.
Holds.HEAT_COLOURS = {
    { 0, { 0.35, 0.55, 0.9 } },
    { 25, { 0.85, 0.65, 0.25 } },
    { 60, { 0.9, 0.45, 0.15 } },
    { 95, { 0.85, 0.2, 0.15 } },
}

local gradient

local function lineHeight()
    return getTextManager():getFontHeight(UIFont.Small)
end

local function measure(text)
    return getTextManager():MeasureStringX(UIFont.Small, text)
end

-- The colour { r, g, b } of a thermometer's column at celsius.
function Holds.heatColour(celsius)
    local stops = Holds.HEAT_COLOURS
    if celsius <= stops[1][1] then return stops[1][2] end
    for index = 2, #stops do
        local low, high = stops[index - 1], stops[index]
        if celsius <= high[1] then
            local t = (celsius - low[1]) / (high[1] - low[1])
            local a, b = low[2], high[2]
            return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
        end
    end
    return stops[#stops][2]
end

-- The cells full of a cells holding: filled if given, else its share of cells, at least one while it holds any.
function Holds.filledCells(holding)
    local cells = holding.cells or Holds.CELLS
    if holding.filled then return math.max(0, math.min(holding.filled, cells)), cells end
    local share = math.max(0, math.min(holding.share or 0, 1))
    local filled = math.floor(share * cells + 0.5)
    if share > 0 and filled == 0 then filled = 1 end
    return filled, cells
end

-- The patterns of filled cells, bottom up, for parts { { pattern, weight } } (user, session 65): each part there gets a
-- cell (the lightest left out when there are more parts than cells), each its whole cells by weight, and the cells
-- left go to the heaviest first; the heaviest at the bottom.
function Holds.byShare(parts, filled)
    local order = {}
    for _, part in ipairs(parts) do
        if (part.weight or 0) > 0 then table.insert(order, part) end
    end
    table.sort(order, function(a, b) return a.weight > b.weight end)
    while #order > filled do table.remove(order) end
    local total = 0
    for _, part in ipairs(order) do total = total + part.weight end
    local counts, used = {}, 0
    for index, part in ipairs(order) do
        counts[index] = math.max(1, math.floor(part.weight / total * filled))
        used = used + counts[index]
    end
    while used > filled do
        for index = #order, 1, -1 do
            if counts[index] > 1 then
                counts[index], used = counts[index] - 1, used - 1
                break
            end
        end
    end
    local index = 1
    while used < filled and #order > 0 do
        counts[index], used = counts[index] + 1, used + 1
        index = index % #order + 1
    end
    local cells = {}
    for i, part in ipairs(order) do
        for _ = 1, counts[i] do table.insert(cells, part.pattern) end
    end
    return cells
end

-- Each mark's side, 1 right or -1 left: right, unless it comes within a line of the last one on the right.
function Holds.markSides(marks, top, height)
    local sides, lastRight = {}, nil
    local line = lineHeight()
    for index, mark in ipairs(marks) do
        local y = height * (1 - mark[1] / top)
        if lastRight and math.abs(y - lastRight) < line then
            sides[index] = -1
        else
            sides[index], lastRight = 1, y
        end
    end
    return sides
end

-- The bar's height for a tank's heat: a line short of the tank's foot.
local function heatBarHeight()
    return Holds.HEIGHT - lineHeight() - 2
end

-- The graphic's width: a thermometer's leaves room for its marks' text on both sides, so the glass stays centred.
-- A tank's heat: the room its temperature takes (the bar centred in it), and how far its ticks' text reaches past
-- the bar's centre.
local function heatRoom(holding)
    local room = math.max(Holds.HEAT_BAR, measure(getText("IGUI_TraditionalPreservationCore_HeatDegrees", "100")))
    local marks = 0
    for _, mark in ipairs(holding.heat.marks or {}) do marks = math.max(marks, measure(mark[2])) end
    local _, crowded = Holds.heatLabels(holding.heat.marks or {}, 0, heatBarHeight())
    local reach = Holds.HEAT_BAR / 2 + (marks > 0 and Holds.TICK + Holds.MARK_GAP + marks + (crowded and Holds.LEADER or 0) or 0)
    return room, math.max(room / 2, reach)
end

-- The width the text centres under: a tank and its heat's room, else the graphic.
local function unitWidth(holding)
    if holding.kind == "tank" and holding.heat then
        local room = heatRoom(holding)
        return Holds.TANK_WIDTH + Holds.HEAT_GAP + room
    end
    if holding.kind == "tank" then return Holds.TANK_WIDTH end
    if holding.kind == "cells" then return Holds.CELL_WIDTH end
    if holding.kind == "slot" then return Holds.SLOT end
    return nil
end

local function graphicWidth(holding)
    if holding.kind == "tank" and holding.heat then
        local room, reach = heatRoom(holding)
        return Holds.TANK_WIDTH + Holds.HEAT_GAP + room / 2 + reach
    end
    if holding.kind == "tank" and holding.line then return Holds.TANK_WIDTH + Holds.LINE_GAP + measure(holding.line.text or "") end
    if holding.kind == "tank" then return Holds.TANK_WIDTH end
    if holding.kind == "cells" then return Holds.CELL_WIDTH end
    if holding.kind == "slot" then return Holds.SLOT end
    local text = 0
    for _, mark in ipairs(holding.marks or {}) do text = math.max(text, measure(mark[2])) end
    if text == 0 then return Holds.BULB end
    return Holds.BULB + 2 * (Holds.TICK + Holds.MARK_GAP + text)
end

local function textLines(holding)
    local lines = { holding.amount or "" }
    if holding.state then table.insert(lines, holding.state) end
    if holding.under then table.insert(lines, holding.under) end
    return lines
end

-- The counts line: an icon a line high, its count COUNT_GAP after it, COUNTS_GAP to the next.
Holds.COUNT_GAP, Holds.COUNTS_GAP = 3, 10

local function countsWidth(holding)
    local width = 0
    for index, entry in ipairs(holding.counts or {}) do
        width = width + lineHeight() + Holds.COUNT_GAP + measure(tostring(entry[2])) + (index > 1 and Holds.COUNTS_GAP or 0)
    end
    return width
end

-- The text lines and the counts line, if any.
local function lineCount(holding)
    return #textLines(holding) + ((holding.counts and #holding.counts > 0) and 1 or 0)
end

-- A holding's text centre from its column's left, and its column's width: the text centres under the unit (a tank
-- and its heat bar as one), the graphic runs on to its right.
local function extents(holding, boldWidth)
    local text = boldWidth(holding.name or "")
    for _, line in ipairs(textLines(holding)) do text = math.max(text, measure(line)) end
    text = math.max(text, countsWidth(holding))
    local graphic = graphicWidth(holding)
    local unit = unitWidth(holding) or graphic
    local left = math.max(unit / 2, text / 2)
    local right = math.max(graphic - unit / 2, text / 2)
    return Holds.COLUMN_PAD + left, left + right + Holds.COLUMN_PAD * 2
end

-- Each holding's column width and each arrow's, packed from the left (user: centred looks off; spare room stays at
-- the right). Returns columns, arrows (by the holding the arrow leaves), the width they need and each column's text
-- centre from its left.
function Holds.layout(holdings, boldWidth)
    local columns, arrows, needed, centres = {}, {}, 0, {}
    for index, holding in ipairs(holdings) do
        centres[index], columns[index] = extents(holding, boldWidth)
        needed = needed + columns[index]
        if holding.arrow and index < #holdings then
            local slot = holding.kind == "slot" or holdings[index + 1].kind == "slot"
            arrows[index] = math.max(slot and Holds.SLOT_ARROW or Holds.ARROW_MIN, measure(holding.arrow) + Holds.ARROW_PAD * 2)
            needed = needed + arrows[index]
        end
    end
    return columns, arrows, needed, centres
end

-- The height of the block for these holdings: the graphic, then the most text lines any of them has.
function Holds.heightFor(holdings)
    local lines = 0
    for _, holding in ipairs(holdings) do lines = math.max(lines, 1 + lineCount(holding)) end
    return Holds.HEIGHT + Holds.TEXT_GAP + lines * lineHeight()
end

local function fill(ui, x, y, width, height, colour, alpha)
    ui:drawRect(x, y, width, height, alpha or 1, colour[1], colour[2], colour[3])
end

-- A filled disc of diameter size at x, y (its top left), drawn a line a pixel.
local function disc(ui, x, y, size, colour)
    local radius = size / 2
    for row = 0, size - 1 do
        local dy = row + 0.5 - radius
        local half = math.sqrt(math.max(0, radius * radius - dy * dy))
        fill(ui, x + radius - half, y + row, half * 2, 1, colour)
    end
end

-- A tank at work, over its liquid (left x, foot y, width, depth in pixels): bubbles rising by the clock, wrapping
-- round at the surface, and the foam cap.
local function drawWorking(ui, working, x, foot, width, depth)
    local seconds = getTimestampMs and getTimestampMs() / 1000 or 0
    local rise = depth - Holds.FOAM - 4
    for index, bubble in ipairs(BUBBLES) do
        local size = index % 2 == 0 and 2 or 3
        local up = (bubble[2] * rise + seconds * Holds.BUBBLE_SPEED * (working.speed or 0)) % rise
        ui:drawRectBorder(math.floor(x + 1 + bubble[1] * (width - size - 2)), math.floor(foot - 2 - up - size), size, size,
            0.8, Holds.BUBBLE_COLOUR[1], Holds.BUBBLE_COLOUR[2], Holds.BUBBLE_COLOUR[3])
    end
    local foam = math.max(1, math.floor(Holds.FOAM * (working.foam or 1) + 0.5))
    fill(ui, x, foot - depth, width, foam, Holds.FOAM_COLOUR)
    for bump = 1, width - 4, 6 do fill(ui, x + bump, foot - depth - 1, 4, 1, Holds.FOAM_COLOUR) end
    if working.spill then
        fill(ui, x + width + 1, foot - depth - 1, 2, Holds.SPILL, Holds.FOAM_COLOUR)
        fill(ui, x + width, foot - depth - 1 + Holds.SPILL, 4, 3, Holds.FOAM_COLOUR)
    end
end

-- A tank's line: dashed across at its share (x, y the tank's top left), its text to the right.
local function drawLine(ui, line, x, y)
    local lineY = y + 2 + math.floor((Holds.HEIGHT - 4) * (1 - line.share) + 0.5)
    for dash = x + 2, x + Holds.TANK_WIDTH - 4, 4 do fill(ui, dash, lineY, 2, 1, Holds.GLASS) end
    if line.text then
        ui:drawText(line.text, x + Holds.TANK_WIDTH + Holds.LINE_GAP, lineY - lineHeight() / 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
end

local function drawTank(ui, holding, x, y, adds)
    local width, height = Holds.TANK_WIDTH, Holds.HEIGHT
    gradient = gradient or getTexture("media/ui/Fluids/fluid_gradient.png")
    fill(ui, x, y, width, height, Holds.BACK)
    local inside = height - 4
    -- What has settled lies at the foot; the fluid stands on it, up to the top.
    local settled, foot = holding.settled, 0
    if settled and (settled.share or 0) > 0 then
        foot = math.max(Holds.SETTLED_MIN, math.floor(inside * math.min(settled.share, 1) + 0.5))
        fill(ui, x + 2, y + height - 2 - foot, width - 4, foot, settled.colour)
    end
    -- The fluid's top is rounded on its own, so it holds still while the fluid turns into what settles (the salt pan:
    -- each litre boiled off past saturation leaves a litre of Brine's salt), not the two rounded apart (user: jitter).
    local share = math.max(0, math.min(holding.share or 0, 1))
    local settledShare = settled and math.min(settled.share or 0, 1) or 0
    local top = math.max(foot, math.min(math.floor(inside * (settledShare + share) + 0.5), inside))
    local level = top - foot
    -- A pour dragged over it: what it would add, see-through over the fluid's top.
    if adds and adds > 0 then
        local added = math.min(math.floor(inside * adds + 0.5), inside - top)
        local tint = holding.colour or Holds.TANK_COLOUR
        if added > 0 then ui:drawRect(x + 2, y + height - 2 - top - added, width - 4, added, Holds.PREVIEW_ALPHA, tint[1], tint[2], tint[3]) end
    end
    local colour = holding.colour or Holds.TANK_COLOUR
    if level > 0 then
        fill(ui, x + 2, y + height - 2 - foot - level, width - 4, level, colour)
        -- Layers: thin lighter bands at the top of the fluid, one each.
        for band = 1, math.min(holding.layers or 0, math.floor(level / 3)) do
            ui:drawRect(x + 2, y + height - 2 - foot - level + (band - 1) * 3, width - 4, 1, 0.8,
                math.min(1, colour[1] + 0.35), math.min(1, colour[2] + 0.3), math.min(1, colour[3] + 0.25))
        end
    end
    if holding.working and top > 8 then drawWorking(ui, holding.working, x + 2, y + height - 2, width - 4, top) end
    if gradient then ui:drawTextureScaled(gradient, x, y, width, height, Holds.GRADIENT_ALPHA, 1, 1, 1) end
    for quarter = 1, 3 do
        local tickY = y + 2 + (height - 4) * (1 - quarter / 4)
        fill(ui, x + width - 2 - Holds.TICK, tickY, Holds.TICK, 1, Holds.BORDER)
    end
    ui:drawRectBorder(x, y, width, height, 1, Holds.BORDER[1], Holds.BORDER[2], Holds.BORDER[3])
end

-- A heat bar's marks, hottest first: each tick at its heat on a bar barHeight tall from y, its text centred on it
-- unless that would run into the one above, then a line under it (user, session 69: 45, 40 and 35 a few pixels apart
-- were drawn over each other). Returns { tickY, textY, text } for each.
function Holds.heatLabels(marks, y, barHeight)
    local sorted = {}
    for _, mark in ipairs(marks) do table.insert(sorted, mark) end
    table.sort(sorted, function(a, b) return a[1] > b[1] end)
    local line, labels, lastY, crowded = lineHeight(), {}, nil, false
    for _, mark in ipairs(sorted) do
        local tickY = y + 2 + (barHeight - 4) * (1 - math.max(0, math.min(mark[1] / 100, 1)))
        local textY = tickY - line / 2
        if lastY and textY < lastY + line then textY, crowded = lastY + line, true end
        table.insert(labels, { tickY = tickY, textY = textY, text = mark[2] })
        lastY = textY
    end
    return labels, crowded
end

-- A thin line from x0, y0 to x1, y1 (y1 below y0), a pixel a row.
local function slant(ui, x0, y0, x1, y1, colour)
    local rows = math.max(1, math.floor(y1 - y0 + 0.5))
    for row = 0, rows do
        fill(ui, math.floor(x0 + (x1 - x0) * row / rows + 0.5), math.floor(y0 + row + 0.5), 1, 1, colour)
    end
end

-- A tank's heat bar, the room for it from x: the bar centred in it from y, a line short of the tank's foot, filled
-- by its heat in its heat's colour; ticks and their text to its right; the temperature centred under it.
local function drawHeatBar(ui, heat, x, y)
    local room = heatRoom({ heat = heat })
    local centre = x + room / 2
    local line = lineHeight()
    local barX, barHeight = centre - Holds.HEAT_BAR / 2, heatBarHeight()
    fill(ui, barX, y, Holds.HEAT_BAR, barHeight, Holds.BACK)
    if heat.celsius then
        local share = math.max(0, math.min(heat.celsius / 100, 1))
        local level = math.floor((barHeight - 4) * share + 0.5)
        if level > 0 then fill(ui, barX + 2, y + barHeight - 2 - level, Holds.HEAT_BAR - 4, level, Holds.heatColour(heat.celsius)) end
    end
    ui:drawRectBorder(barX, y, Holds.HEAT_BAR, barHeight, 1, Holds.BORDER[1], Holds.BORDER[2], Holds.BORDER[3])
    -- Crowded marks (user, session 69, art/heat_leaders_mock.png A): every text LEADER further right, a slanted line from
    -- each tick to its text's middle.
    local labels, crowded = Holds.heatLabels(heat.marks or {}, y, barHeight)
    local tickEnd = barX + Holds.HEAT_BAR + Holds.TICK
    local textX = tickEnd + Holds.MARK_GAP + (crowded and Holds.LEADER or 0)
    for _, label in ipairs(labels) do
        fill(ui, barX + Holds.HEAT_BAR, label.tickY, Holds.TICK, 1, Holds.GLASS)
        if crowded then slant(ui, tickEnd, label.tickY, textX - 2, label.textY + line / 2, Holds.LEADER_COLOUR) end
        ui:drawText(label.text, textX, label.textY, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
    local degrees = heat.celsius and getText("IGUI_TraditionalPreservationCore_HeatDegrees", tostring(math.floor(heat.celsius + 0.5))) or "-"
    ui:drawTextCentre(degrees, centre, y + Holds.HEIGHT - line, 1, 1, 1, 1, UIFont.Small)
end

-- adds: cells a drop would fill, drawn see-through over the empty ones above the filled (nil: none), in addsPattern
-- (the judge's pattern) if given.
local function drawCells(ui, holding, x, y, adds, addsPattern)
    local width = Holds.CELL_WIDTH
    local top, height = y, Holds.HEIGHT
    local filled, cells = Holds.filledCells(holding)
    local cellHeight = (height - 2 - Holds.CELL_GAP * (cells - 1)) / cells
    fill(ui, x, top, width, height, Holds.BACK)
    local colour = holding.colour or Holds.CELL_COLOUR
    local patterns = holding.parts and Holds.byShare(holding.parts, filled) or {}
    -- A drop's cells in its own pattern (the judge's), else the one on top or the holding's, see-through.
    local preview = addsPattern or patterns[#patterns] or holding.pattern
    for cell = 1, cells do
        -- From the bottom up: the first filled cells are the lowest.
        local cellY = top + 1 + (cells - cell) * (cellHeight + Holds.CELL_GAP)
        local pattern = cell <= filled and (patterns[cell] or holding.pattern) or nil
        if pattern then
            ui:drawTextureScaled(getTexture(pattern), x + 2, cellY, width - 4, cellHeight, 1, 1, 1, 1)
        else
            fill(ui, x + 2, cellY, width - 4, cellHeight, cell <= filled and colour or Holds.EMPTY_CELL)
        end
        if adds and cell > filled and cell <= filled + adds then
            if preview then
                ui:drawTextureScaled(getTexture(preview), x + 2, cellY, width - 4, cellHeight, Holds.PREVIEW_ALPHA, 1, 1, 1)
            else
                ui:drawRect(x + 2, cellY, width - 4, cellHeight, Holds.PREVIEW_ALPHA, colour[1], colour[2], colour[3])
            end
        end
    end
    ui:drawRectBorder(x, top, width, height, 1, Holds.BORDER[1], Holds.BORDER[2], Holds.BORDER[3])
end

local function drawHeat(ui, holding, x, y, width)
    local centre = x + width / 2
    local tube, bulb = Holds.TUBE, Holds.BULB
    local glassTop, bulbTop = y, y + Holds.HEIGHT - bulb
    local tubeLeft = centre - tube / 2
    local scaleTop, scaleBottom = glassTop + tube / 2, bulbTop + 2
    -- The glass: a round top, the tube and the bulb, with the dark inside.
    disc(ui, tubeLeft, glassTop, tube, Holds.GLASS)
    fill(ui, tubeLeft, glassTop + tube / 2, tube, bulbTop - glassTop, Holds.GLASS)
    disc(ui, centre - bulb / 2, bulbTop, bulb, Holds.GLASS)
    local inset = Holds.COLUMN_INSET
    fill(ui, tubeLeft + 1, glassTop + tube / 2, tube - 2, bulbTop - glassTop - tube / 2 + 2, Holds.BACK)
    disc(ui, centre - bulb / 2 + 1, bulbTop + 1, bulb - 2, Holds.BACK)
    local top = holding.top or 100
    if holding.celsius then
        local colour = Holds.heatColour(holding.celsius)
        local share = math.max(0, math.min(holding.celsius / top, 1))
        local columnTop = scaleBottom - (scaleBottom - scaleTop) * share
        fill(ui, tubeLeft + inset, columnTop, tube - inset * 2, bulbTop + bulb / 2 - columnTop, colour)
        disc(ui, centre - bulb / 2 + inset, bulbTop + inset, bulb - inset * 2, colour)
    end
    -- The marks: a line out from the glass and its text, on alternating sides when two come close.
    local marks = holding.marks or {}
    local sides = Holds.markSides(marks, top, scaleBottom - scaleTop)
    local line = lineHeight()
    for index, mark in ipairs(marks) do
        local markY = scaleBottom - (scaleBottom - scaleTop) * math.max(0, math.min(mark[1] / top, 1))
        if sides[index] > 0 then
            fill(ui, tubeLeft + tube, markY, Holds.TICK, 1, Holds.GLASS)
            ui:drawText(mark[2], tubeLeft + tube + Holds.TICK + Holds.MARK_GAP, markY - line / 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
        else
            fill(ui, tubeLeft - Holds.TICK, markY, Holds.TICK, 1, Holds.GLASS)
            ui:drawTextRight(mark[2], tubeLeft - Holds.TICK - Holds.MARK_GAP, markY - line / 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
        end
    end
end

-- The slot's top, standing on the middle line of a holding drawn at y.
function Holds.slotTop(y)
    return math.floor(y + Holds.HEIGHT / 2 - Holds.SLOT / 2)
end

-- A dashed frame round x, y, size square.
local function dashedFrame(ui, x, y, size, colour)
    local step = Holds.SLOT_DASH * 2
    for along = 0, size - 1, step do
        local length = math.min(Holds.SLOT_DASH, size - along)
        fill(ui, x + along, y, length, 1, colour)
        fill(ui, x + along, y + size - 1, length, 1, colour)
        fill(ui, x, y + along, 1, length, colour)
        fill(ui, x + size - 1, y + along, 1, length, colour)
    end
end

-- An icon at x, y, size square, tinted { r, g, b, a } (nil: as it is). Two icons are split on the diagonal from the
-- top right to the bottom left, the first above it: drawn row by row, each row's part of each icon.
local function drawIcons(ui, icons, x, y, size, tint)
    local r, g, b, a = 1, 1, 1, 1
    if tint then r, g, b, a = tint[1], tint[2], tint[3], tint[4] end
    local first, second = icons[1], icons[2]
    if not second then
        if first then ui:drawTextureScaled(first, x, y, size, size, a, r, g, b) end
        return
    end
    local element = ui.javaObject
    for row = 0, size - 1 do
        local cut = size - row   -- the first icon left of the cut
        for index, icon in ipairs({ first, second }) do
            local from, to = index == 1 and 0 or cut, index == 1 and cut or size
            if to > from then
                local scaleX, scaleY = icon:getWidth() / size, icon:getHeight() / size
                element:DrawSubTextureRGBA(icon, from * scaleX, row * scaleY, (to - from) * scaleX, scaleY, x + from, y + row,
                    to - from, 1, r, g, b, a)
            end
        end
    end
end

-- A starter's slot at x, y (its top left), by its look; adds (a drop over it that takes) shows its icons bright.
local function drawSlot(ui, holding, x, y, adds)
    local size, inset = Holds.SLOT, (Holds.SLOT - Holds.SLOT_ICON) / 2
    local look = holding.look or "empty"
    local icons = {}
    for _, icon in ipairs(holding.icons or {}) do
        local texture = type(icon) == "string" and getTexture(icon) or icon
        if texture then table.insert(icons, texture) end
    end
    if look == "empty" then
        dashedFrame(ui, x, y, size, Holds.BORDER)
    else
        fill(ui, x, y, size, size, Holds.EMPTY_CELL)
        local frame = look == "ready" and Holds.READY or Holds.BORDER
        ui:drawRectBorder(x, y, size, size, 1, frame[1], frame[2], frame[3])
        if look == "ready" then ui:drawRectBorder(x + 1, y + 1, size - 2, size - 2, 1, frame[1], frame[2], frame[3]) end
    end
    local greyed = (look == "empty" or look == "pending") and not adds
    drawIcons(ui, icons, x + inset, y + inset, Holds.SLOT_ICON, greyed and Holds.GREYED or nil)
    if holding.count then
        ui:drawTextRight(holding.count, x + size - 2, y + size - lineHeight() - 1, 1, 1, 1, 1, UIFont.Small)
    end
end

local function drawArrow(ui, text, x, width, y, colour)
    local midY = y + Holds.HEIGHT / 2
    local left, right = x + Holds.ARROW_PAD, x + width - Holds.ARROW_PAD
    colour = colour or Holds.ARROW
    fill(ui, left, midY, right - left, 1, colour)
    for step = 1, 4 do fill(ui, right - step, midY - step, 1, step * 2 + 1, colour) end
    if text ~= "" then
        ui:drawTextCentre(text, x + width / 2, midY - lineHeight() - 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
end

-- The frame round a holding something is dragged over: white when it takes it all, orange some, red none.
local function drawDropFrame(ui, judged, x, y, width, height)
    local colour = #judged.take == 0 and Holds.DROP_NO or judged.refused and Holds.DROP_SOME or Holds.DROP_OK
    local margin = Holds.DROP_MARGIN
    ui:drawRectBorder(x - margin, y - margin, width + margin * 2, height + margin * 2, 1, colour[1], colour[2], colour[3])
    ui:drawRectBorder(x - margin + 1, y - margin + 1, width + margin * 2 - 2, height + margin * 2 - 2, 1, colour[1], colour[2], colour[3])
end

-- Draws holdings from x at y on ui, packed from the left, with look { value, note (colours), bold (function(ui, text, x, y,
-- colour) drawing centred bold text), boldWidth (function(text)), judged (function(index): what is dragged over that
-- holding's drop target, or nil) }. Returns the y under it, the width needed and each holding's unit { x, y, width,
-- height } (the tank and its heat bar; a drop target goes over it).
function Holds.draw(ui, look, x, y, holdings)
    local columns, arrows, needed, centres = Holds.layout(holdings, look.boldWidth)
    local units = {}
    local line = lineHeight()
    local textTop = y + Holds.HEIGHT + Holds.TEXT_GAP
    for index, holding in ipairs(holdings) do
        local columnWidth = columns[index]
        local graphic = graphicWidth(holding)
        local centre = x + centres[index]
        local unit = unitWidth(holding) or graphic
        local graphicX = centre - unit / 2
        units[index] = { x = graphicX, y = y, width = unit, height = Holds.HEIGHT }
        local judged = look.judged and look.judged(index)
        if holding.kind == "slot" then
            local top = Holds.slotTop(y)
            units[index] = { x = graphicX, y = top, width = unit, height = Holds.SLOT }
            drawSlot(ui, holding, graphicX, top, judged and #judged.take > 0)
        elseif holding.kind == "tank" then
            drawTank(ui, holding, graphicX, y, judged and #judged.take > 0 and judged.adds or nil)
            if holding.line then drawLine(ui, holding.line, graphicX, y) end
            if holding.heat then drawHeatBar(ui, holding.heat, graphicX + Holds.TANK_WIDTH + Holds.HEAT_GAP, y) end
        elseif holding.kind == "cells" then
            drawCells(ui, holding, graphicX, y, judged and #judged.take > 0 and judged.cells or nil, judged and judged.pattern)
        else
            drawHeat(ui, holding, graphicX, y, graphic)
        end
        if judged then drawDropFrame(ui, judged, units[index].x, units[index].y, unit, units[index].height) end
        look.bold(ui, holding.name or "", centre, textTop, holding.nameColour or look.value)
        local value = look.value
        ui:drawTextCentre(holding.amount or "", centre, textTop + line, value[1], value[2], value[3], 1, UIFont.Small)
        if holding.state then
            local colour = holding.stateColour or look.note
            ui:drawTextCentre(holding.state, centre, textTop + line * 2, colour[1], colour[2], colour[3], 1, UIFont.Small)
        end
        if holding.under then
            local note = holding.underColour or look.note
            ui:drawTextCentre(holding.under, centre, textTop + line * (holding.state and 3 or 2), note[1], note[2], note[3], 1, UIFont.Small)
        end
        if holding.counts and #holding.counts > 0 then
            local note, size = look.note, line
            local countX, countY = centre - countsWidth(holding) / 2, textTop + line * (1 + #textLines(holding))
            for _, entry in ipairs(holding.counts) do
                local icon = entry[1]
                if type(icon) == "string" then icon = getTexture(icon) end
                if icon then ui:drawTextureScaledAspect(icon, countX, countY, size, size, 1, 1, 1, 1) end
                local count = tostring(entry[2])
                ui:drawText(count, countX + size + Holds.COUNT_GAP, countY, note[1], note[2], note[3], 1, UIFont.Small)
                countX = countX + size + Holds.COUNT_GAP + measure(count) + Holds.COUNTS_GAP
            end
        end
        x = x + columnWidth
        if arrows[index] then
            drawArrow(ui, holding.arrow, x, arrows[index], y, holding.arrowColour)
            x = x + arrows[index]
        end
    end
    return y + Holds.heightFor(holdings), needed, units
end

return Holds
