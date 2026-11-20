-- Checks Holds and InfoWindow's blocks outside the game: a thermometer's colour, cells for a share, marks that come
-- close, columns and arrows fitted to the width, a bar's text inside or under, a block's header, and a whole Holds
-- block drawn on a stand-in. Run from this folder: luajit tests/test_holds.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installGetText({})

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end

-- Engine stand-ins: every character is 6 wide and a line 10 high.
UIFont = { Small = "small", SdfBold = "bold", SdfOldItalic = "italic" }
function getTextManager()
    return { getFontHeight = function() return 10 end, MeasureStringX = function(_, _, text) return #text * 6 end }
end
function getTexture(name) return { name = name } end
ISCollapsableWindow = H.class("ISCollapsableWindow")

local Holds = require "TraditionalPreservationCore/Holds"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"

check("cold is blue", Holds.heatColour(-5)[3] == 0.9)
check("between two stops the colour is between them", near(Holds.heatColour(12.5)[1], (0.35 + 0.85) / 2))
check("past the last stop it stays red", Holds.heatColour(120)[1] == 0.85 and Holds.heatColour(120)[2] == 0.2)

check("a share fills its part of five cells", Holds.filledCells({ share = 0.6 }) == 3)
check("a little fills one cell", Holds.filledCells({ share = 0.01 }) == 1)
check("nothing fills none", Holds.filledCells({ share = 0 }) == 0)
local filled, cells = Holds.filledCells({ filled = 3, cells = 4 })
check("a real count is drawn as it is", filled == 3 and cells == 4)

-- On a 100 C scale 80 tall, 85 and 100 are 12 apart, more than a line (10); 95 and 100 are 4 apart.
local sides = Holds.markSides({ { 85, "85 steam" }, { 100, "100 boils" } }, 100, 80)
check("marks far enough apart are both on the right", sides[1] == 1 and sides[2] == 1)
sides = Holds.markSides({ { 95, "a" }, { 100, "b" }, { 40, "c" } }, 100, 80)
check("a mark close to the last on the right goes left, the next far one right", sides[1] == 1 and sides[2] == -1 and sides[3] == 1)

local function boldWidth(text) return #text * 6 end
local wood = { kind = "cells", name = "Wood", amount = "5 h 20 min", state = "lit", share = 0.4 }
local tank = { kind = "tank", name = "Cauldron", amount = "24 / 60 L", state = "Water", share = 0.4 }
local columns, arrows, needed = Holds.layout({ wood, tank }, boldWidth)
-- Wood: "5 h 20 min" 60 wide, plus 8 each side; Cauldron: "24 / 60 L" 54, "Cauldron" 48, the tank 34: 54 + 16.
check("each column fits its widest text", needed == 76 + 70)
check("packed from the left: each column only as wide as it needs", columns[1] == 76 and columns[2] == 70 and next(arrows) == nil)
local wort = { kind = "tank", name = "Wort", amount = "6 / 20 L", share = 0.3, arrow = "yeast" }
local fermented = { kind = "tank", name = "Fermented", amount = "8 / 20 L", share = 0.4 }
columns, arrows, needed = Holds.layout({ wort, fermented }, boldWidth)
check("an arrow is as wide as its text needs, at least ARROW_MIN", needed == 64 + 70 + 64 and arrows[1] == 64 and columns[1] == 64)
columns, arrows, needed = Holds.layout({ wood, tank, wood, tank, wood, tank }, boldWidth)
check("too many to fit: the width they need is more", needed == 3 * 146 and near(columns[1], 76))

-- A window on a stand-in that records what it draws.
local drawn = {}
local window = setmetatable({ width = InfoWindow.WIDTH, labelColumn = 0, titleBarHeight = function() return 16 end },
    { __index = InfoWindow })
for _, name in ipairs({ "drawRect", "drawRectBorder", "drawTextureScaled", "drawTextureScaledAspect" }) do
    window[name] = function() end
end
for _, name in ipairs({ "drawText", "drawTextCentre", "drawTextRight", "drawTextZoomed" }) do
    window[name] = function(_, text) table.insert(drawn, text) end
end
function window:setWidth(width) self.width = width end

local y = window:section(window:top(), "T_Fire")
check("the first header has no gap above it", y == 16 + 12 + 10 + InfoWindow.HEADER_GAP and drawn[1] == "T_FIRE")
local next = window:section(100, "T_Holds")
check("a later header has the section gap above it", next == 100 + 12 + 10 + InfoWindow.HEADER_GAP)

y = window:bar(0, "T_Fuel", 0.5, { 1, 0, 0 }, "45%, 2 d 4 h")
check("a short text sits inside the bar", y == 18 + InfoWindow.BAR_GAP and drawn[#drawn] == "45%, 2 d 4 h")
check("the label column is as wide as the label and its gap", window.labelColumn == #"T_Fuel" * 6 + 16)
y = window:bar(0, "T_Fuel", 0.5, { 1, 0, 0 }, string.rep("long ", 11))
-- 55 letters (330) are more than the bar (400 - 12 - 52 - 12 = 324) less its 6 each side, and wrap to one line of 324.
check("a long text goes under the bar", y == 18 + 10 + InfoWindow.BAR_GAP)

drawn = {}
y = window:holds(0, { wood, tank, { kind = "heat", name = "Heat", amount = "72 C", state = "steams in 40 min", celsius = 72,
    marks = { { 85, "85 steam" }, { 100, "100 boils" } } } })
check("the block is the graphic and three lines of text", y == Holds.HEIGHT + Holds.TEXT_GAP + 30 + InfoWindow.BAR_GAP)
local seen = {}
for _, text in ipairs(drawn) do seen[text] = true end
check("names, amounts, states and marks are drawn", seen.Wood and seen.Cauldron and seen.Heat and seen["24 / 60 L"]
    and seen["steams in 40 min"] and seen["85 steam"] and seen["100 boils"])
check("they fit the window as it is", window.width == InfoWindow.WIDTH)
window:holds(0, { wood, tank, wood, tank, wood, tank })
check("more than fit widen the window, up to the most", window.width == 3 * 146 + 24)
window:holds(0, { wood, tank, wood, tank, wood, tank, wood, tank, wood, tank })
check("never past MAX_WIDTH", window.width == InfoWindow.MAX_WIDTH)
drawn = {}
local first = window:band("Lit", "burns 5 h 49 min, full heat", { 0.67, 0.22, 0.16 }, { 0.27, 0.1, 0.08 })
ISCollapsableWindow.prerender = function() end
window:prerender()
check("a band under the title: its word in capitals, its text, the rows start under it", drawn[1] == "LIT"
    and drawn[3] == "burns 5 h 49 min, full heat" and first == 16 + InfoWindow.BAND_HEIGHT + InfoWindow.PADDING
    and window:top() == first)
check("a header right under the band has no gap above it", window:section(first, "T_Holds") == first + 10 + InfoWindow.HEADER_GAP)
-- With a button: icon only, square at the band's right, the title heading its hover.
ISButton = {}
function ISButton:new(x, y, width, height, title, target, onclick)
    return setmetatable({ x = x, y = y, width = width, height = height, title = title, target = target, onclick = onclick,
        textureColor = { r = 1, g = 1, b = 1, a = 1 } }, { __index = ISButton })
end
for _, name in ipairs({ "initialise", "instantiate" }) do ISButton[name] = function() end end
function ISButton:setX(x) self.x = x end
function ISButton:setY(y) self.y = y end
function ISButton:setWidth(width) self.width = width end
function ISButton:setHeight(height) self.height = height end
function ISButton:setTitle(title) self.title = title end
function ISButton:setEnable(enabled) self.enable = enabled end
function ISButton:setTooltip(tooltip) self.tooltip = tooltip end
function ISButton:setImage(image) self.image = image end
function ISButton:forceImageSize(width, height) self.forcedWidthImage, self.forcedHeightImage = width, height end
function ISButton:getIsVisible() return self.visible ~= false end
function ISButton:setVisible(visible) self.visible = visible end
function window:addChild() end
window:band("Out", "6 h 0 min of wood in it", { 0.5, 0.5, 0.5 }, { 0.2, 0.2, 0.2 },
    { title = "Light the Fire", icon = "Item_Lighter", enabled = true, tooltip = "Light it.", onClick = function() end })
local lighter = window.bandButtonUI
check("the band's button is its icon alone, square at the right, its title heading the hover", lighter and lighter.title == ""
    and lighter.image.name == "Item_Lighter" and lighter.width == InfoWindow.BAND_BUTTON
    and lighter.x == window.width - InfoWindow.PADDING - InfoWindow.BAND_BUTTON and lighter.tooltip == "Light the Fire <LINE> Light it.")
window.bandBottom = nil
drawn = {}
local lore = "Curfew comes from the Old French cuevrefeu, cover fire: the evening bell that told a household to rake its hearth over."
y = window:holds(0, { wood }, lore)
local lines = 0
for _, text in ipairs(drawn) do if text:find("^Curfew") or text:find("hearth over%.$") then lines = lines + 1 end end
check("one holding with lore: the holding and the note beside it, wrapped", seen and lines == 2
    and y >= Holds.heightFor({ wood }) + InfoWindow.BAR_GAP)
window:holds(0, { { kind = "heat", name = "Heat", amount = "-" } })

-- A heated tank: its heat bar beside it, the temperature under the bar, the text centred under the two as one.
H.installGetText({ IGUI_TraditionalPreservationCore_HeatDegrees = "%1 C" })
local cauldron = { kind = "tank", name = "Cauldron", amount = "24 / 60 L", state = "Water", under = "steaming", share = 0.4,
    heat = { celsius = 92, marks = { { 85, "85" }, { 100, "100" } } } }
columns, arrows, needed, centres = Holds.layout({ cauldron }, boldWidth)
-- The tank 34, its heat's room "100 C" 30 after a gap of 6: the unit 70, centred at 35; the ticks reach 6 + 5 + 4 +
-- "100" 18 = 33 past the bar's centre (at 34 + 6 + 15 = 55), so the graphic runs to 88; "24 / 60 L" is 54.
check("the text centres under tank and heat bar as one", centres[1] == 8 + 35 and columns[1] == 35 + (88 - 35) + 16)
drawn = {}
y = window:holds(0, { wood, cauldron }, lore)
seen = {}
for _, text in ipairs(drawn) do seen[text] = true end
check("its temperature, ticks and the line under are drawn", seen["92 C"] and seen["85"] and seen["100"] and seen.steaming)
check("four text lines under it", y >= Holds.HEIGHT + Holds.TEXT_GAP + 40)
local loreDrawn = false
for _, text in ipairs(drawn) do if text:find("^Curfew") then loreDrawn = true end end
check("with room to their right the lore goes beside two holdings", loreDrawn)
window.width = InfoWindow.WIDTH
drawn = {}
window:holds(0, { wood, cauldron, wood }, lore)
loreDrawn = false
for _, text in ipairs(drawn) do if text:find("^Curfew") then loreDrawn = true end end
check("short of LORE_MIN of room the window widens to give it", loreDrawn and window.width > InfoWindow.WIDTH
    and window.width <= InfoWindow.MAX_WIDTH)
window.width = InfoWindow.WIDTH
drawn = {}
window:holds(0, { wood, cauldron, wood, cauldron, wood, cauldron }, lore)
loreDrawn = false
for _, text in ipairs(drawn) do if text:find("^Curfew") then loreDrawn = true end end
check("past MAX_WIDTH it is left out", not loreDrawn and window.width == InfoWindow.MAX_WIDTH)

-- A settled layer: at the tank's foot under the fluid, at least SETTLED_MIN tall.
local rects = {}
window.drawRect = function(_, x, y, w, h, a, r, g, b) table.insert(rects, { y = y, h = h, r = r, g = g, b = b }) end
window:holds(0, { { kind = "tank", name = "Salt Pan", amount = "0 / 30 L", share = 0, colour = { 0, 0, 1 },
    settled = { share = 0.001, colour = { 0.9, 0.9, 0.9 } } } })
local layer
for _, rect in ipairs(rects) do if rect.r == 0.9 and rect.g == 0.9 then layer = rect end end
check("a little salt still shows as a thin layer at the foot", layer and layer.h == Holds.SETTLED_MIN
    and layer.y + layer.h == Holds.HEIGHT - 2)
rects = {}
window:holds(0, { { kind = "tank", name = "Salt Pan", amount = "15 / 30 L", share = 0.5, colour = { 0, 0, 1 },
    settled = { share = 0.25, colour = { 0.9, 0.9, 0.9 } } } })
local brine
for _, rect in ipairs(rects) do if rect.b == 1 and rect.r == 0 then brine = rect end end
check("the brine stands on the salt", brine and brine.y + brine.h == Holds.HEIGHT - 2 - 23)
-- Past saturation each litre boiled off leaves a litre of salt: the brine's top holds still, step after step.
local tops = {}
for step = 0, 40 do
    local ml = 18 - step * 0.37
    rects = {}
    window:holds(0, { { kind = "tank", name = "Salt Pan", amount = "", share = ml / 30, colour = { 0, 0, 1 },
        settled = { share = (18 - ml) / 30, colour = { 0.9, 0.9, 0.9 } } } })
    for _, rect in ipairs(rects) do if rect.b == 1 and rect.r == 0 then tops[rect.y] = true end end
end
local count = 0
for _ in pairs(tops) do count = count + 1 end
check("the brine's top holds still as it turns to salt", count == 1)
check("a thermometer with nothing to warm draws", true)

-- Patterns (user, session 65): a mixed holding's full cells split by weight, each part a cell, the cells left to the
-- heaviest first, the heaviest at the bottom; a pattern drawn in each full cell.
local function kinds(cells) return table.concat(cells, " ") end
check("by share: 50/20/16 over 5 cells, the heaviest takes the cell left",
    kinds(Holds.byShare({ { pattern = "fish", weight = 20 }, { pattern = "meat", weight = 50 }, { pattern = "sausage", weight = 16 } }, 5))
    == "meat meat meat fish sausage")
check("by share: a small part still gets a cell", kinds(Holds.byShare({ { pattern = "meat", weight = 44 },
    { pattern = "sausage", weight = 6 } }, 3)) == "meat meat sausage")
check("by share: more parts than cells, the lightest left out", kinds(Holds.byShare({ { pattern = "a", weight = 5 },
    { pattern = "b", weight = 3 }, { pattern = "c", weight = 1 } }, 2)) == "a b")
check("by share: nothing full, nothing drawn", #Holds.byShare({ { pattern = "a", weight = 5 } }, 0) == 0)
local drawn = {}
window.drawTextureScaled = function(_, texture, x, y, w, h, a) table.insert(drawn, { name = texture and texture.name, a = a }) end
window:holds(0, { { kind = "cells", name = "Load", amount = "", share = 0.6,
    parts = { { pattern = "media/textures/TPCell_Fish.png", weight = 9 }, { pattern = "media/textures/TPCell_Meat.png", weight = 5 } } } })
local names = {}
for _, d in ipairs(drawn) do if d.name and d.name:find("TPCell") then table.insert(names, d.name:match("TPCell_(%a+)")) end end
check("three full cells drawn in their patterns, fish below meat", table.concat(names, " ") == "Fish Fish Meat")
drawn = {}
window:holds(0, { { kind = "cells", name = "Wood", amount = "", share = 0.4, pattern = "media/textures/TPCell_Wood.png" } })
check("one pattern for every full cell", #drawn >= 2 and drawn[1].name == "media/textures/TPCell_Wood.png")

H.done()
