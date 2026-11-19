-- Traditional Preservation core: an info window's Holds block, what a station holds drawn standing up, left to right
-- in the order things move through it. A fluid is a tank (vanilla's fluid gradient over the fluid's colour, ticks at
-- quarters, thin bands at the top for layers: a mother's skin); anything else held is a column of cells (wood, soil,
-- a rack's load, jars), a real count where it is small, else five cells of a share; heat
-- is a thermometer, its column coloured by its own heat, with marks (85 steam, 100 boils). Under each: its name in
-- bold, its amount, and a state line if it has one. A holding with an arrow draws one to the next, its text (a rate)
-- above it. A window doesn't draw one itself: InfoWindow:holds(y, holdings) draws it in the window's flow.
-- holdings is a list of
--   { kind = "tank", name, amount, state, stateColour, share (0 to 1), colour { r, g, b }, layers (bands, or nil) }
--   { kind = "cells", name, amount, state, stateColour, cells (default 5),
--     filled (cells full; default the share's), share, colour }
--   { kind = "heat", name, amount, state, stateColour, celsius (nil: nothing to warm), top (the scale's top C,
--     default 100), marks = { { celsius, text } } }
-- each with arrow (text above an arrow to the next holding, "" for a plain one, nil for none).

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

-- The graphic's width: a thermometer's leaves room for its marks' text on both sides, so the glass stays centred.
local function graphicWidth(holding)
    if holding.kind == "tank" then return Holds.TANK_WIDTH end
    if holding.kind == "cells" then return Holds.CELL_WIDTH end
    local text = 0
    for _, mark in ipairs(holding.marks or {}) do text = math.max(text, measure(mark[2])) end
    if text == 0 then return Holds.BULB end
    return Holds.BULB + 2 * (Holds.TICK + Holds.MARK_GAP + text)
end

local function textLines(holding)
    local lines = { holding.amount or "" }
    if holding.state then table.insert(lines, holding.state) end
    return lines
end

-- Each holding's column width and each arrow's, packed from the left (user: centred looks off; spare room stays at
-- the right). Returns columns, arrows (by the holding the arrow leaves) and the width they need.
function Holds.layout(holdings, boldWidth)
    local columns, arrows, needed = {}, {}, 0
    for index, holding in ipairs(holdings) do
        local widest = math.max(graphicWidth(holding), boldWidth(holding.name or ""))
        for _, line in ipairs(textLines(holding)) do widest = math.max(widest, measure(line)) end
        columns[index] = widest + Holds.COLUMN_PAD * 2
        needed = needed + columns[index]
        if holding.arrow and index < #holdings then
            arrows[index] = math.max(Holds.ARROW_MIN, measure(holding.arrow) + Holds.ARROW_PAD * 2)
            needed = needed + arrows[index]
        end
    end
    return columns, arrows, needed
end

-- The height of the block for these holdings: the graphic, then the most text lines any of them has.
function Holds.heightFor(holdings)
    local lines = 0
    for _, holding in ipairs(holdings) do lines = math.max(lines, 1 + #textLines(holding)) end
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

local function drawTank(ui, holding, x, y)
    local width, height = Holds.TANK_WIDTH, Holds.HEIGHT
    gradient = gradient or getTexture("media/ui/Fluids/fluid_gradient.png")
    fill(ui, x, y, width, height, Holds.BACK)
    local share = math.max(0, math.min(holding.share or 0, 1))
    local level = math.floor((height - 4) * share + 0.5)
    local colour = holding.colour or Holds.TANK_COLOUR
    if level > 0 then
        fill(ui, x + 2, y + height - 2 - level, width - 4, level, colour)
        -- Layers: thin lighter bands at the top of the fluid, one each.
        for band = 1, math.min(holding.layers or 0, math.floor(level / 3)) do
            ui:drawRect(x + 2, y + height - 2 - level + (band - 1) * 3, width - 4, 1, 0.8,
                math.min(1, colour[1] + 0.35), math.min(1, colour[2] + 0.3), math.min(1, colour[3] + 0.25))
        end
    end
    if gradient then ui:drawTextureScaled(gradient, x, y, width, height, Holds.GRADIENT_ALPHA, 1, 1, 1) end
    for quarter = 1, 3 do
        local tickY = y + 2 + (height - 4) * (1 - quarter / 4)
        fill(ui, x + width - 2 - Holds.TICK, tickY, Holds.TICK, 1, Holds.BORDER)
    end
    ui:drawRectBorder(x, y, width, height, 1, Holds.BORDER[1], Holds.BORDER[2], Holds.BORDER[3])
end

local function drawCells(ui, holding, x, y)
    local width = Holds.CELL_WIDTH
    local top, height = y, Holds.HEIGHT
    local filled, cells = Holds.filledCells(holding)
    local cellHeight = (height - 2 - Holds.CELL_GAP * (cells - 1)) / cells
    fill(ui, x, top, width, height, Holds.BACK)
    local colour = holding.colour or Holds.CELL_COLOUR
    for cell = 1, cells do
        -- From the bottom up: the first filled cells are the lowest.
        local cellY = top + 1 + (cells - cell) * (cellHeight + Holds.CELL_GAP)
        fill(ui, x + 2, cellY, width - 4, cellHeight, cell <= filled and colour or Holds.EMPTY_CELL)
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

local function drawArrow(ui, text, x, width, y)
    local midY = y + Holds.HEIGHT / 2
    local left, right = x + Holds.ARROW_PAD, x + width - Holds.ARROW_PAD
    fill(ui, left, midY, right - left, 1, Holds.ARROW)
    for step = 1, 4 do fill(ui, right - step, midY - step, 1, step * 2 + 1, Holds.ARROW) end
    if text ~= "" then
        ui:drawTextCentre(text, x + width / 2, midY - lineHeight() - 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
    end
end

-- Draws holdings from x at y on ui, packed from the left, with look { value, note (colours), bold (function(ui, text, x, y,
-- colour) drawing centred bold text), boldWidth (function(text)) }. Returns the y under it and the width needed.
function Holds.draw(ui, look, x, y, holdings)
    local columns, arrows, needed = Holds.layout(holdings, look.boldWidth)
    local line = lineHeight()
    local textTop = y + Holds.HEIGHT + Holds.TEXT_GAP
    for index, holding in ipairs(holdings) do
        local columnWidth = columns[index]
        local graphic = graphicWidth(holding)
        local graphicX = x + (columnWidth - graphic) / 2
        if holding.kind == "tank" then
            drawTank(ui, holding, graphicX, y)
        elseif holding.kind == "cells" then
            drawCells(ui, holding, graphicX, y)
        else
            drawHeat(ui, holding, graphicX, y, graphic)
        end
        local centre = x + columnWidth / 2
        look.bold(ui, holding.name or "", centre, textTop, look.value)
        local value = look.value
        ui:drawTextCentre(holding.amount or "", centre, textTop + line, value[1], value[2], value[3], 1, UIFont.Small)
        if holding.state then
            local colour = holding.stateColour or look.note
            ui:drawTextCentre(holding.state, centre, textTop + line * 2, colour[1], colour[2], colour[3], 1, UIFont.Small)
        end
        x = x + columnWidth
        if arrows[index] then
            drawArrow(ui, holding.arrow, x, arrows[index], y)
            x = x + arrows[index]
        end
    end
    return y + Holds.heightFor(holdings), needed
end

return Holds
