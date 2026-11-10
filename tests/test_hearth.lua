-- Checks the Hearth's copper and hooks in 42/media/lua. Run from TraditionalPreservationCore: luajit tests/test_hearth.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near
package.path = "42/media/lua/shared/?.lua;" .. package.path
local Hearth = require "TraditionalPreservationCore/Hearth"

-- Item heat
check("room heat is room temperature", Hearth.heatCelsius(1.0) == Hearth.ROOM_C)
check("an item never reads hotter than the copper gets", Hearth.heatCelsius(3.0) == Hearth.MAX_C)
check("heat goes back to the item it came from", near(Hearth.heatCelsius(Hearth.itemHeat(60)), 60))

-- Filling and emptying
local copper = {}
check("an empty copper takes any fluid", Hearth.pourInto(copper, "Water", 4000, 20, 0) == 4000 and copper.fluid == "Water")
check("but not a second one", select(2, Hearth.pourInto(copper, "CowMilk", 1000, 20, 0)) == "Mixed")
check("emptied, it forgets the fluid", Hearth.take(copper) == 4000 and copper.fluid == nil and copper.tempC == nil)
check("cow's and sheep's milk don't mix", Hearth.pourInto(copper, "CowMilk", 10000, 20, 0) == 10000
    and select(2, Hearth.pourInto(copper, "SheepMilk", 100, 20, 0)) == "Mixed")
check("10 L fills it", select(2, Hearth.pourInto(copper, "CowMilk", 100, 20, 0)) == "Full")

-- Heating and cooling
copper.fireUntil = 100
local hot
for minute = 6, 240, 6 do
    Hearth.advance(copper, minute / 60, 20)
    if not hot and Hearth.isHot(copper) then hot = minute / 60 end
end
check("10 L over the fire is hot in about an hour and a half", hot and hot > 1.3 and hot < 1.7)
check("and never boils", copper.tempC <= Hearth.MAX_C)
local split = { ml = 10000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }
Hearth.advance(split, 1, 20)
Hearth.advance(split, 2, 20)
local once = { ml = 10000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }
Hearth.advance(once, 2, 20)
check("ticks or one catch-up give the same heat", near(split.tempC, once.tempC, 1e-6))
local small = { ml = 1000, fluid = "Water", tempC = 20, last = 0, fireUntil = 100 }
Hearth.advance(small, 1, 20)
check("a litre heats faster", Hearth.isHot(small))
check("cold fluid poured in lowers the heat", Hearth.take(copper, 5000) == 5000
    and Hearth.pourInto(copper, "CowMilk", 5000, 5, 4) == 5000 and copper.tempC < Hearth.HOT_C and not Hearth.isHot(copper))
local outFire = { ml = 10000, fluid = "CowMilk", tempC = 90, last = 0, fireUntil = 1 }
Hearth.advance(outFire, 3, 20)
local byFireThenOut = Hearth.cool(Hearth.cool(90, Hearth.MAX_C, 1, Hearth.copperTau(10000, true)), 20, 2,
    Hearth.copperTau(10000, false))
check("out of fuel it cools to the room from then on", near(outFire.tempC, byFireThenOut, 1e-6))
check("slower than it heated: the stone holds it", Hearth.copperTau(10000, false) > 2 * Hearth.copperTau(10000, true))
local unlit = { ml = 10000, fluid = "CowMilk", tempC = 90, last = 0 }
Hearth.advance(unlit, 2, 20)
check("a copper with no fire cools", unlit.tempC < 60 and unlit.tempC > 20)
check("the copper shows empty, full or steaming", Hearth.look({}) == "Empty"
    and Hearth.look({ ml = 100, tempC = 40 }) == "Full" and Hearth.look({ ml = 100, fluid = "Water", tempC = 90 }) == "Hot")
local warming = { ml = 10000, fluid = "Water", tempC = 20, last = 0, fireUntil = 100 }
local eta = Hearth.hoursToHot(warming)
Hearth.advance(warming, eta + 0.01, 20)
check("the time to hot is right, for any fluid", eta > 1.3 and eta < 1.7 and Hearth.isHot(warming)
    and Hearth.hoursToHot(warming) == 0 and Hearth.hoursToHot({}) == nil)

-- Tiles
check("every hearth tile is known with its facing", #Hearth.SPRITES == 6 and Hearth.face(Hearth.sprite("Hot", 1)) == 1
    and Hearth.face(Hearth.sprite("Empty", 0)) == 0 and Hearth.face("traditionalpreservationcore_01_6") == nil
    and Hearth.face("traditionalpreservationdairy_01_20") == nil)

-- By a fire
local ledger = { temperature = -10, seasonTemperature = -5 }
check("a fire keeps its warmth whatever the weather", Hearth.placeTemperature(ledger, Hearth.PLACE) == Hearth.FIRE_C
    and Hearth.placeTemperature(ledger, "Open") == -10)
local state = {}
Hearth.noteFire(state, nil, nil, 5)
check("no fire, no notes", state.fireUntil == nil and state.under == nil)

-- Hooks
local function item(heat)
    local modData = {}
    return { getItemHeat = function() return heat end, setItemHeat = function(self, h) heat = h end,
        getModData = function() return modData end, heat = function() return heat end }
end
local plain = item(1)
check("with no hook an item pours at vanilla's heat", Hearth.heatOf(plain, 0) == Hearth.ROOM_C)
Hearth.filledFrom(plain, { ml = 1000, fluid = "Water", tempC = 90 })
check("and a fill sets vanilla's heat to the copper's", near(Hearth.heatCelsius(plain.heat()), 90))
local kept = item(1)
kept.keeps = true
Hearth.hook("heatOf", function(i) return i.keeps and 70 or nil end)
check("a hook answers for its own items", Hearth.heatOf(kept, 0) == 70 and Hearth.heatOf(plain, 0) ~= 70)
local seen
Hearth.hook("filled", function(i, fill)
    if fill.fluid ~= "CowMilk" then return false end
    seen = fill.ml
    return true
end)
Hearth.filledFrom(kept, { ml = 500, fluid = "CowMilk", tempC = 90 })
check("a hook that handles a fill leaves vanilla's heat alone", seen == 500 and kept.heat() == 1)
local took
Hearth.hook("taken", function(i, ml) took = ml end)
Hearth.tookFrom(kept, 250)
check("taken hooks hear how much left", took == 250)

-- Save key
local modData = {}
local saved = Hearth.stateOf(modData)
Hearth.pourInto(saved, "Water", 1000, 20, 0)
check("the copper lives under one prefixed key", modData.tpHearth.ml == 1000 and modData.ml == nil and Hearth.stateOf(modData) == saved)
H.done()
