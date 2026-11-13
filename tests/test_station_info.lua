-- Checks StationInfo outside the game: which crafting windows get a block, and that the widget grows by the block's
-- height whatever height it is given. Run from this folder: luajit tests/test_station_info.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installGetText({ T_Place = "Place" })

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end

-- Engine stand-ins: every character is 6 wide and a line 10 high.
UIFont = { Small = "small" }
function getTextManager()
    return { getFontHeight = function() return 10 end, MeasureStringX = function(_, _, text) return #text * 6 end }
end
local function element(o)
    function o:setX(x) self.x = x end
    function o:setY(y) self.y = y end
    function o:setWidth(width) self.width = width end
    function o:setHeight(height) self.height = height end
    function o:getWidth() return self.width end
    function o:getHeight() return self.height end
    function o:initialise() end
    function o:instantiate() end
    return o
end
ISCollapsableWindow = H.class("ISCollapsableWindow")
ISPanel = element({ Type = "ISPanel" })
function ISPanel:derive(type) return setmetatable({ Type = type }, { __index = self }) end
function ISPanel.new(class, x, y, width, height)
    return setmetatable({ x = x, y = y, width = width, height = height }, { __index = class })
end
function ISPanel:update() end

-- Vanilla's widget: 120 wide and 80 high at least, and as big as it is asked to be.
local layouts = 0
ISWidgetCraftLogicOutputProgress = element({})
function ISWidgetCraftLogicOutputProgress:createDynamicChildren() self.vanillaChildren = true end
function ISWidgetCraftLogicOutputProgress:calculateLayout(width, height)
    layouts = layouts + 1
    self:setWidth(math.max(120, width or 0))
    self:setHeight(math.max(80, height or 0))
end
local function widget(entity)
    local o = setmetatable({ entity = entity, children = {} }, { __index = ISWidgetCraftLogicOutputProgress })
    function o:addChild(child) table.insert(self.children, child) end
    function o:xuiRecalculateLayout(width, height) self.relaid = { width, height } end
    return o
end

local StationInfo = require "TraditionalPreservationCore/StationInfo"
local info = { rows = { { "T_Place", "Open air" } }, bars = { { text = "1. Salt fish", share = 0.5, value = "50%", colour = { 0, 1, 0 } } },
    notes = { "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen" } }
local asked = 0
StationInfo.add(function(entity)
    asked = asked + 1
    return entity == "frame" and info or nil
end)

local other = widget("workbench")
other:createDynamicChildren()
other:calculateLayout(0, 0)
check("another station's window is vanilla's", other.vanillaChildren and other.tpInfo == nil and #other.children == 0
    and other.width == 120 and other.height == 80)

local frame = widget("frame")
frame:createDynamicChildren()
local panel = frame.tpInfo
check("the mod's station gets a block, after vanilla's children", frame.vanillaChildren and panel and frame.children[1] == panel)

-- At 300 wide: padding 8, a row 12, a bar 14, a note of 3 lines (4 + 30), padding 8 = 76.
frame:calculateLayout(0, 0)
check("the widget is wide enough for the block", frame.width == StationInfo.MIN_WIDTH)
check("the block's height at that width", panel.height == 76)
check("the widget grows by it, the block under vanilla's rows", frame.height == 80 + 76 and panel.y == 80 and panel.width == 300)
frame:calculateLayout(300, 156)
check("given its own height back it stays as it is", frame.height == 156 and panel.y == 80)
frame:calculateLayout(300, 200)
check("given more, vanilla takes the rest", frame.height == 200 and panel.y == 124)
frame:calculateLayout(600, 0)
check("a wider window wraps the note less", panel.height == 56 and frame.height == 136)

-- The block asks again twice a second, and has the window laid out again when its height changes.
frame:calculateLayout(300, 0)
local before = asked
for _ = 1, StationInfo.REFRESH_TICKS - 1 do panel:update() end
check("it doesn't ask every tick", asked == before and frame.relaid == nil)
panel:update()
check("it asks again, and an unchanged block lays nothing out", asked == before + 1 and frame.relaid == nil)
table.insert(info.bars, { text = "2. Charque", share = 0.1, value = "10%", colour = { 0, 1, 0 } })
for _ = 1, StationInfo.REFRESH_TICKS do panel:update() end
check("a block that grew has the window laid out again", frame.relaid ~= nil and frame.relaid[2] == nil)
frame.relaid = nil
frame:calculateLayout(300, 0)
info.bars = {}
for _ = 1, StationInfo.REFRESH_TICKS do panel:update() end
check("one that shrank gives the height back", frame.relaid[2] == -28)

-- The plain station's block (StationInfo.block), keys shown as they are.
local shown = StationInfo.block({ place = "Basement", temperature = 9.6, rate = 0.3,
    rows = { { "T_Place", "own" } }, batches = { { name = "Malt", progress = 0.5, hoursLeft = 49.2 } }, numbered = true,
    waiting = 2, notes = { "mine" } })
check("place, temperature and rate first, then the mod's rows", #shown.rows == 4 and shown.rows[2][2] ~= nil
    and shown.rows[3][2] == "30%" and shown.rows[4][2] == "own")
check("a numbered bar, slow below half speed", shown.bars[1].share == 0.5
    and shown.bars[1].colour == StationInfo.SLOW_COLOUR and #shown.notes == 3)
local frozen = StationInfo.block({ place = "Open", temperature = -8, rate = 0,
    batches = { { name = "Malt", progress = 0.5 } } })
check("a frozen batch has no time left: its bar says paused", frozen.bars[1].value:find("InfoPaused") ~= nil
    and frozen.bars[1].colour == StationInfo.SLOW_COLOUR)
local bare = StationInfo.block({ place = "Open" })
check("by the clock: one row, and nothing in it", #bare.rows == 1 and #bare.bars == 0 and #bare.notes == 1)

H.done()
