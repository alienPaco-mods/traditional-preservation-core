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
    process = "test", curve = { { -2, 0 }, { 4, 0.4 }, { 15, 1 }, { 25, 2 } }, ledgerKey = "TestKeeping",
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
for hour = 1, 240 do keeper.recordWeather(hour, 15) end
keeper.keep(butter, 240, nil, ledger)
keeper.keep(fridge, 240, nil, ledger)
check("ten days in a basement age it by the basement's warmth", near(butter.age, 2 + 10 * keeper.rate("Basement", ledger), 1e-6))
check("ten days in a fridge age it four", near(fridge.age, 4, 1e-6))
check("an unseen item keeps counting where it was last seen", butter.modData.tpKeep.fluidAge.place == "Basement")

keeper.age(fridge, 5)
check("the console's age moves it on at its place", near(fridge.age, 6, 1e-6))
check("a line for the console", keeper.describe(fridge):find("Base.Butter in Fridge: x0.40", 1, true) ~= nil)
local frozen = food("Base.Butter", 30, 45)
keeper.keep(frozen, 0, "Freezer", ledger)
local line = keeper.describe(frozen)
check("a frozen one keeps forever there: no days counted as 0", line:find("x0.00 (keeps forever here)", 1, true) ~= nil
    and line:find("stale in never, rotten in never", 1, true) ~= nil)

-- By a fire (Fire.placeOf): the item takes the fire's place and notes its fuel; the stretch since counts by the clock at
-- the fire's heat while that fuel lasted, the rest at the room under it by its share.
local Fire = require "TraditionalPreservationCore/Fire"
local Weather = require "TraditionalPreservationCore/Weather"
local placeOf, fuelHours, weatherPlaceOf = Fire.placeOf, Fire.fuelHours, Weather.placeOf
local stove = {}
local holder = { getSquare = function() return {} end }
Fire.placeOf = function() return Fire.PLACE, stove end
Fire.fuelHours = function() return 48 end
Weather.placeOf = function() return "Sheltered" end
local byFire = food("Base.Butter", 30, 45)
function byFire:getWorldItem() return holder end
H.setHours(240)
local seen = keeper.keep(byFire, 240, nil, ledger)
check("by a fire an item takes the fire's place and notes the fuel and the room under it",
    seen.fluidAge.place == Fire.PLACE and seen.fluidAge.fireUntil == 288 and seen.fluidAge.placeWithoutFire == "Sheltered")
local roomBefore = ledger.testSheltered
for hour = 241, 480 do keeper.recordWeather(hour, 15) end
Fire.placeOf = function() return "Sheltered" end
keeper.keep(byFire, 480, nil, ledger)
local room = (ledger.testSheltered - roomBefore) * (480 - 288) / (480 - 240)
check("48 h at the fire's 28 C, then the room for the rest of the stretch",
    near(byFire.age, (48 * keeper.ageRate(Fire.FIRE_C) + room) / 24, 1e-6))
check("away from the fire the note is gone", byFire.modData.tpKeep.fluidAge.fireUntil == nil
    and byFire.modData.tpKeep.fluidAge.place == "Sheltered")
check("the fire place's rate reads the fire's heat", keeper.rate(Fire.PLACE, ledger) == keeper.ageRate(Fire.FIRE_C))
Fire.placeOf, Fire.fuelHours, Weather.placeOf = placeOf, fuelHours, weatherPlaceOf

on = false
local plain = food("Base.Butter", 1e9, 1e9, 4)
check("off, an item gets no clock and keeps its script days", keeper.keep(plain, 240, "Sheltered", ledger) == nil
    and plain.modData.tpKeep == nil and plain.offAge == 1e9)
on = true

SandboxVars = { FoodRotSpeed = 1 }
check("vanilla's Very Fast food spoilage speeds it up", near(keeper.ageing.speed(), 1.7))
SandboxVars = nil

-- The tooltip's forecast: read-only, the days left at the rate where it is now.
local fresh = food("Base.Butter", 30, 45, 10)
local seen = keeper.forecast(fresh, "Fridge")
check("a forecast in a fridge: 4 C, 0.4 a day, 50 days to stale, 87.5 to rotten", seen.place == "Fridge" and seen.celsius == 4
    and near(seen.rate, 0.4) and near(seen.stale, 50) and near(seen.rotten, 87.5))
check("it changes nothing on the item", fresh.age == 10 and fresh.modData.tpKeep == nil)
check("a storage's factor scales the rate", near(keeper.forecast(fresh, "Fridge", 0.5).stale, 100))
seen = keeper.forecast(fresh, "Freezer")
check("in a freezer: no reading, and it doesn't age", seen.celsius == nil and seen.rate == 0 and seen.stale == math.huge
    and seen.rotten == math.huge)
local stale = food("Base.Butter", 30, 45, 40)
seen = keeper.forecast(stale, "Fridge")
check("stale already: only the days to rotten", seen.stale == nil and near(seen.rotten, 12.5))
check("rotten: neither", keeper.forecast(food("Base.Butter", 30, 45, 50), "Fridge").rotten == nil)
local churned = food("Base.Butter", 1000000000, 1000000000, 0)
seen = keeper.forecast(churned, "Fridge")
check("before its first look (vanilla's never-ending days): the keeper's days, not a billion", near(seen.stale, 75)
    and near(seen.rotten, 112.5) and churned.offAge == 1000000000)
check("with no place given, where the item is (nowhere: the default place)", keeper.forecast(fresh).place == Weather.DEFAULT_PLACE)

-- A stale stretch of its own (staleShare): cold buys the fresh days, the stale ones go at a day a day (share 0).
local stales = PlaceKeeping.new({ process = "staleTest", curve = { { -2, 0 }, { 4, 0.2 }, { 15, 1 } }, ledgerKey = "TestStale",
    modDataKey = "tpStale", staleShare = 0, days = { ["Base.Potato"] = { 28, 73 } } })
check("share 0: a stale day is a day, a cold one too; frozen stops it", stales.staleRateOf(0.2) == 1 and stales.staleRateOf(1) == 1
    and stales.staleRateOf(0) == 0)
check("share a half: half the slowing (0.2 is five times slower, at half three: 1/3)",
    near(PlaceKeeping.new({ process = "half", curve = { { 0, 1 } }, ledgerKey = "TestHalf", modDataKey = "h", staleShare = 0.5 })
        .staleRateOf(0.2), 1 / 3))
check("its stale process is on the ledger", stales.processes.staleTestStale ~= nil and stales.ledger().staleTestStaleBasement ~= nil)
local staleLedger = stales.ledger()
local spud = food("Base.Potato", 28, 280, 20)
stales.keep(spud, 0, "Fridge", staleLedger)
check("its days: fresh as given, rotten its stale days after", spud.offAge == 28 and spud.offAgeMax == 73)
stales.keep(spud, 24 * 20, nil, staleLedger)
check("20 days in a fridge at 0.2: 4 days of age, still fresh, no stale clock", near(spud.age, 24, 1e-6)
    and spud.modData.tpStale.stale == nil)
local crossing = food("Base.Potato", 28, 73, 27)
stales.keep(crossing, 0, "Fridge", staleLedger)
stales.keep(crossing, 24 * 10, nil, staleLedger)
check("crossing into stale in a fridge: 2 days of fresh age past it count again at the stale rate (5 times)",
    crossing.modData.tpStale.stale ~= nil and near(crossing.age, 28 + 1 * 5, 1e-6))
stales.keep(crossing, 24 * 20, nil, staleLedger)
check("then a day a day, the fridge no help", near(crossing.age, 33 + 10, 1e-6))
seen = stales.forecast(crossing, "Fridge")
check("its forecast: stale, rotten in its stale days left at a day a day", seen.stale == nil and near(seen.rotten, 73 - 43)
    and near(seen.rate, 1))
local cold = food("Base.Potato", 28, 73, 0)
seen = stales.forecast(cold, "Fridge")
check("a fresh one's forecast: 140 days fresh in a fridge, then its 45 stale", near(seen.stale, 140) and near(seen.rotten, 185))
check("in a freezer neither", stales.forecast(cold, "Freezer").rotten == math.huge)
local lootStale = food("Base.Potato", 28, 73, 50)
stales.keep(lootStale, 24 * 20, "Fridge", staleLedger)
check("one stale already at its first look starts on its stale clock", lootStale.modData.tpStale.stale ~= nil
    and near(lootStale.modData.tpStale.stale.age, 22 * 24))
stales.age(lootStale, 3)
check("the console's age moves its stale clock", near(lootStale.age, 53, 1e-6))

H.done()
