-- Checks PlaceKeeping (food that keeps by place) on stand-ins for the engine. Run from TraditionalPreservationCore:
-- luajit tests/test_place_keeping.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near
package.path = "42/media/lua/shared/?.lua;" .. package.path
H.installClock(0)
H.installModData()

local PlaceKeeping = require "TraditionalPreservationCore/PlaceKeeping"

-- A food item that sits where the test says (no container: placeOfItem gives nil).
local function food(fullType, offAge, offAgeMax, age)
    local self = { fullType = fullType, offAge = offAge, offAgeMax = offAgeMax, age = age or 0, modData = {} }
    function self:getFullType() return self.fullType end
    function self:getOffAge() return self.offAge end
    function self:getOffAgeMax() return self.offAgeMax end
    function self:setOffAge(x) self.offAge = x end
    function self:setOffAgeMax(x) self.offAgeMax = x end
    function self:getAge() return self.age end
    function self:setAge(x) self.age = x end
    function self:getModData() return self.modData end
    function self:getOutermostContainer() return nil end
    function self:getWorldItem() return nil end
    function self:getDisplayName() return self.fullType end
    return self
end

local on = true
local keeper = PlaceKeeping.new({
    kind = "test", curve = { { -2, 0 }, { 4, 0.4 }, { 15, 1 }, { 25, 2 } }, ledgerKey = "TestKeeping",
    modDataKey = "tpKeep", enabled = function() return on end,
    days = { ["Base.Butter"] = { 30, 45 } },
})

check("the curve: a cellar day is a day, a fridge 0.4, 25 C two, frozen nothing",
    keeper.ageRate(15) == 1 and near(keeper.rate("Fridge"), 0.4) and keeper.ageRate(30) == 2
    and keeper.ageRate(-5) == 0 and keeper.rate("Freezer") == 0)

local ledger = keeper.ledger()
check("its ledger lives under its key", H.modData.TestKeeping.ledger == ledger)

local butter = food("Base.Butter", 1e9, 1e9, 2)
local clock = keeper.keep(butter, 0, "Basement", ledger)
check("the first look starts the clock at the item's age", clock.base == 2 and butter.modData.tpKeep == clock)
check("and gives an item that never spoiled its days", butter.offAge == 30 and butter.offAgeMax == 45)
local other = food("Base.Lard", 1e9, 1e9)
keeper.keep(other, 0, "Basement", ledger)
check("an item not in days keeps its own", other.offAge == 1e9)

local fridge = food("Base.Butter", 30, 45)
keeper.keep(fridge, 0, "Fridge", ledger)
for hour = 1, 240 do keeper.record(hour, 15) end
keeper.keep(butter, 240, nil, ledger)
keeper.keep(fridge, 240, nil, ledger)
check("ten days in a basement age it by the basement's warmth", near(butter.age, 2 + 10 * keeper.rate("Basement", ledger), 1e-6))
check("ten days in a fridge age it four", near(fridge.age, 4, 1e-6))
check("an unseen item keeps counting where it was last seen", butter.modData.tpKeep.record.place == "Basement")

keeper.age(fridge, 5)
check("the console's age moves it on at its place", near(fridge.age, 6, 1e-6))
check("a line for the console", keeper.describe(fridge):find("Base.Butter in Fridge: x0.40", 1, true) ~= nil)
local frozen = food("Base.Butter", 30, 45)
keeper.keep(frozen, 0, "Freezer", ledger)
local line = keeper.describe(frozen)
check("a frozen one keeps forever there: no days counted as 0", line:find("x0.00 (keeps forever here)", 1, true) ~= nil
    and line:find("stale in never, rotten in never", 1, true) ~= nil)

on = false
local plain = food("Base.Butter", 1e9, 1e9, 4)
check("off, an item gets no clock and keeps its script days", keeper.keep(plain, 240, "Sheltered", ledger) == nil
    and plain.modData.tpKeep == nil and plain.offAge == 1e9)
on = true

SandboxVars = { FoodRotSpeed = 1 }
check("vanilla's Very Fast food spoilage speeds it up", near(keeper.ageing.speed(), 1.7))
SandboxVars = nil

H.done()
