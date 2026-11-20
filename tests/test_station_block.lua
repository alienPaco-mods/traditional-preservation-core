-- Checks Info windows' Station block outside the game (InfoWindow:stationBlock, art/station_aligned_mock.png H): Place,
-- Season (the series' mean, left out before a reading) and the window's own rows in order, the outline icon and the
-- rows centred on each other's height, and a long value wrapped under itself.
-- Run from this folder: luajit tests/test_station_block.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installGetText()
H.installModData()
H.installClock(1000)

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end
UIFont = { Small = "small", Medium = "medium" }
function getTextManager()
    return { getFontHeight = function(_, font) return font == "medium" and 20 or 10 end,
        MeasureStringX = function(_, _, text) return #text * 8 end }
end
function getTexture(name) return "texture:" .. name end
ISCollapsableWindow = H.class("ISCollapsableWindow")
ISButton = {}
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local Weather = require "TraditionalPreservationCore/Weather"

local rows = InfoWindow.stationRows("Basement", 9, { { "IGUI_TraditionalPreservationFishMeat_Wind", "Calm" } }, 11)
check("Place, Season, then the window's own rows", #rows == 3 and rows[1].label == "Place" and rows[2].label == "Season"
    and rows[3].label == "IGUI_TraditionalPreservationFishMeat_Wind" and rows[3].value == "Calm")
check("Place reads its temperature and word, with its icon", rows[1].value == "9°C (Basement)" and rows[1].icon ~= nil)
check("Season is the series' mean, short", rows[2].value == "11°C avg outdoors" and rows[2].icon == nil)
check("no reading yet: no Season row", #InfoWindow.stationRows("Open", 14, nil, nil) == 1)

-- Drawn: a window 400 wide that records what it draws.
local function window()
    local drawn = { texts = {}, rects = {}, textures = {} }
    local w = { width = 400, labelColumn = 0, drawn = drawn }
    function w:titleBarHeight() return 16 end
    function w:top() return 28 end
    function w:drawText(text, x, y) table.insert(drawn.texts, { text = text, x = x, y = y }) end
    function w:drawRect(x, y, wd, ht) table.insert(drawn.rects, { x = x, y = y, w = wd, h = ht }) end
    function w:drawRectBorder(x, y, wd, ht) table.insert(drawn.rects, { x = x, y = y, w = wd, h = ht, border = true }) end
    function w:drawTextureScaledAspect(texture, x, y, wd, ht) table.insert(drawn.textures, { texture = texture, x = x, y = y, w = wd }) end
    return setmetatable(w, { __index = InfoWindow })
end
local function textAt(win, text)
    for _, t in ipairs(win.drawn.texts) do if t.text == text then return t end end
end

local weather = Weather.weatherModData()
weather.temperature, weather.seasonTemperature = 14, 11
local one = window()
local under = one:stationBlock(28, "media/textures/Item_SaltingTub.png", "Basement", 9)
-- section: 28 + 10 + 4 = 42; the icon 64 high; two rows of 10 (Small) with a gap of 4 (24) centred on it
check("two rows: the block is the icon's height", under == 42 + 64 + InfoWindow.ROW_GAP)
check("the icon at the padding, 64 square, no frame", one.drawn.textures[1].texture == "texture:media/textures/Item_SaltingTub.png"
    and one.drawn.textures[1].x == 12 and one.drawn.textures[1].w == 64 and #one.drawn.rects == 1)
local place = textAt(one, "Place")
check("the rows right of the icon, centred on its height", place.x == 12 + 64 + 16 and place.y == 42 + (64 - 24) / 2
    and textAt(one, "Season").y == place.y + 14)
check("Season shows on any station", textAt(one, "11°C avg outdoors") ~= nil)

local lined = window()
lined.holdsCentre = 60
lined:stationBlock(28, "icon", "Basement", 9)
check("the icon stands on the first holding's centre line, the rows after it", lined.drawn.textures[1].x == 60 - 32
    and textAt(lined, "Place").x == 60 - 32 + 64 + 16)
lined = window()
lined.holdsCentre = 20
lined:stationBlock(28, "icon", "Basement", 9)
check("never left of the padding", lined.drawn.textures[1].x == 12)

local tall = window()
local own = {}
for i = 1, 4 do own[i] = { "IGUI_Row" .. i, "v" .. i } end
under = tall:stationBlock(28, nil, "Open", 14, own)
local tallIcon = window()
tallIcon:stationBlock(28, "icon", "Open", 14, own)
check("six rows are taller than the icon: it centres on them", under == 42 + 6 * 10 + 5 * 4 + InfoWindow.ROW_GAP
    and tallIcon.drawn.textures[1].y == 42 + (80 - 64) / 2 and textAt(tall, "Place").y == 42)

local long = window()
long:stationBlock(28, nil, "Open", 14, { { "IGUI_Hose", "Connected to an Orleans Vinegar Cask, far too long for one line" } })
local first, second = textAt(long, "Connected to an Orleans"), nil
for _, t in ipairs(long.drawn.texts) do if t.text:find("^Vinegar") or t.text:find("line$") then second = second or t end end
check("a long value wraps under itself, at its own x", first == nil or (second and second.x == first.x and second.y > first.y))
local hoseLines = 0
for _, t in ipairs(long.drawn.texts) do if t.text:find("Connected") or t.text:find("line") then hoseLines = hoseLines + 1 end end
check("it takes more than one line", hoseLines >= 2)

H.done()
