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
    return setmetatable({ x = x, y = y, width = width, height = height, title = title, target = target, onclick = onclick },
        { __index = ISButton })
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
check("a thermometer with nothing to warm draws", true)

H.done()
