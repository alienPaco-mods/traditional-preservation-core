-- Checks the item tooltip's TP lines outside the game: the one wrap of ISToolTipInv.render (lines in for the one draw,
-- the item's own text put back), a same-line adder (Salt's brine), and the keeping lines (KeepingTooltip): fresh,
-- stale, not ageing, where and how fast, the sandbox switch. Run from this folder: luajit tests/test_item_tooltip.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
TPCoreTesting = true
H.useModPaths()
H.installGetText()
H.installEvents()
H.installModData()
H.installClock(0)

local drawn
ISToolTipInv = { render = function(self) drawn = self.item:getTooltip() end }
function instanceof(object, class) return class == "InventoryItem" and type(object) == "table" and object.isItem end
local clock = 0
function getTimestampMs() return clock end

local function item(fullType, own, age)
    local self = { isItem = true, fullType = fullType, tooltip = own, modData = {}, age = age or 0, offAge = 30, offAgeMax = 45 }
    function self:getFullType() return self.fullType end
    function self:getFluidContainer() return nil end
    function self:getTooltip() return self.modData.Tooltip or self.tooltip end
    function self:setTooltip(text) self.tooltip, self.modData.Tooltip = text, text end
    function self:getModData() return self.modData end
    function self:getAge() return self.age end
    function self:getOffAge() return self.offAge end
    function self:getOffAgeMax() return self.offAgeMax end
    function self:getOutermostContainer() return nil end
    function self:getWorldItem() return nil end
    return self
end

local ItemTooltip = require "TraditionalPreservationCore/ItemTooltip"
local PlaceKeeping = require "TraditionalPreservationCore/PlaceKeeping"
local KeepingTooltip = require "TraditionalPreservationCore/KeepingTooltip"

local plain = item("Base.Apple", "Tooltip_Apple")
ISToolTipInv.render({ item = plain })
check("an item no adder speaks for draws as vanilla's", drawn == "Tooltip_Apple" and plain.modData.Tooltip == nil)

ItemTooltip.add(function(it) return it.fullType == "Test.Brine" and "Strong: 8 salt" or nil end, { sameLine = true })
local brine = item("Test.Brine", "Tooltip_Bucket")
ISToolTipInv.render({ item = brine })
check("a same-line adder goes before the item's own text, a space between", drawn == "Strong: 8 salt Tooltip_Bucket")
ItemTooltip.add(function(it) return it.fullType == "Test.Cure" and "Curing (dry): 40%, about 6 days" or nil end)
ISToolTipInv.render({ item = item("Test.Cure") })
check("a % is doubled, as the engine formats the text (a lone one threw in debug mode)", drawn == "Curing (dry): 40%%, about 6 days")
check("the item's own text is put back, nothing left in its modData", brine.tooltip == "Tooltip_Bucket" and brine.modData.Tooltip == nil)

local on = true
local keeper = PlaceKeeping.new({ process = "test", curve = { { 4, 0.4 }, { 15, 1 } }, ledgerKey = "TestKeep",
    modDataKey = "tpKeep", enabled = function() return on end })
local place = "Fridge"
KeepingTooltip.add({ ["Test.Butter"] = true }, function(it) return KeepingTooltip.keeperLines(keeper, it, nil, place) end)

local butter = item("Test.Butter", nil, 10)
ISToolTipInv.render({ item = butter })
check("a kept food: fresh for, rotten in, then where and how fast", drawn == "Fresh for about 50 days here, rotten in about 88 days\n"
    .. "4°C (Fridge), ages 0.40 days a day")
check("its own text under the keeping lines", ItemTooltip.text(item("Test.Butter", "Tooltip_Butter", 10), "Tooltip_Butter")
    :find("a day\nTooltip_Butter$") ~= nil)

clock = clock + KeepingTooltip.CACHE_MS
local stale = item("Test.Butter", nil, 44)
place = "Fridge"
ISToolTipInv.render({ item = stale })
check("stale: only the time to rotten", drawn == "Stale: rotten in about 3 days here\n4°C (Fridge), ages 0.40 days a day")

place = "Freezer"
ISToolTipInv.render({ item = item("Test.Butter", nil, 10) })
check("a freezer: doesn't age, no reading", drawn == "Doesn't age here\nFreezer, ages 0.00 days a day")

local cached = item("Test.Butter", nil, 10)
place = "Fridge"
ISToolTipInv.render({ item = cached })
local first = drawn
place = "Freezer"
ISToolTipInv.render({ item = cached })
check("a hovered item's lines are kept a moment (drawn every frame)", drawn == first)
clock = clock + KeepingTooltip.CACHE_MS
ISToolTipInv.render({ item = cached })
check("then worked out again", drawn ~= first)

ISToolTipInv.render({ item = item("Test.Butter", nil, 50) })
check("a rotten one has no keeping lines", drawn == nil)

on = false
ISToolTipInv.render({ item = item("Test.Butter", nil, 10) })
check("the keeper off: no lines", drawn == nil)
on = true

SandboxVars = { TraditionalPreservationCore = { KeepingTooltips = false } }
clock = clock + KeepingTooltip.CACHE_MS
ISToolTipInv.render({ item = item("Test.Butter", nil, 10) })
check("the sandbox's Keeping in item tooltips off: no lines", drawn == nil)
SandboxVars = nil

H.done()
