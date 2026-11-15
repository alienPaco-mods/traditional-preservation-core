-- Checks the Stone Hearth's cauldron and hooks in 42/media/lua. Run from TraditionalPreservationCore: luajit tests/test_fire.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near
package.path = "42/media/lua/shared/?.lua;" .. package.path
local Fire = require "TraditionalPreservationCore/Fire"
local Weather = require "TraditionalPreservationCore/Weather"

-- Item heat
check("room heat is room temperature", Fire.heatCelsius(1.0) == Fire.ROOM_C)
check("an item never reads hotter than the cauldron gets", Fire.heatCelsius(3.0) == Fire.MAX_C)
check("heat goes back to the item it came from", near(Fire.heatCelsius(Fire.itemHeat(60)), 60))
check("an item from the fridge reads cold, not frozen", near(Fire.heatCelsius(0.2), Fire.COLD_C))
check("and never colder than the fridge", Fire.heatCelsius(0) == Fire.COLD_C and Fire.heatCelsius(-5) == Fire.COLD_C)
check("cold heat goes back to the item too", near(Fire.heatCelsius(Fire.itemHeat(10)), 10))
check("a freezing cauldron fills at the engine's floor", Fire.itemHeat(-10) == Fire.COLD_HEAT)

-- Filling and emptying
local cauldron = {}
check("an empty cauldron takes any fluid", Fire.pourInto(cauldron, "Water", 4000, 20, 0) == 4000 and cauldron.fluid == "Water")
check("but not a second one", select(2, Fire.pourInto(cauldron, "CowMilk", 1000, 20, 0)) == "Mixed")
check("emptied, it forgets the fluid", Fire.take(cauldron) == 4000 and cauldron.fluid == nil and cauldron.tempC == nil)
check("cow's and sheep's milk don't mix", Fire.pourInto(cauldron, "CowMilk", 60000, 20, 0) == 60000
    and select(2, Fire.pourInto(cauldron, "SheepMilk", 100, 20, 0)) == "Mixed")
check("60 L fills it", select(2, Fire.pourInto(cauldron, "CowMilk", 100, 20, 0)) == "Full")

-- Fluids a mod has said may share the cauldron
Fire.blend("CowMilk", "SheepMilk")
local herd = {}
Fire.pourInto(herd, "CowMilk", 3000, 20, 0)
check("fluids that blend share the cauldron, heat mixing by volume", Fire.pourInto(herd, "SheepMilk", 1000, 60, 0) == 1000
    and herd.ml == 4000 and near(herd.tempC, 30) and herd.fluid == "CowMilk" and herd.parts.SheepMilk == 1000)
check("but nothing else joins them", select(2, Fire.pourInto(herd, "Water", 100, 20, 0)) == "Mixed")
local outMl, outFluid, _, outParts = Fire.take(herd, 2000)
check("a blend comes out in its shares", outMl == 2000 and outFluid == "CowMilk" and near(outParts.CowMilk, 1500)
    and near(outParts.SheepMilk, 500) and near(Fire.partsOf(herd).SheepMilk, 500))
check("a blend poured in keeps its shares", Fire.pourInto(herd, { SheepMilk = 3, CowMilk = 1 }, 2000, 20, 0) == 2000
    and near(Fire.partsOf(herd).SheepMilk, 2000) and herd.fluid == "CowMilk")
Fire.take(herd)
check("emptied, the blend is forgotten", herd.parts == nil and herd.fluid == nil)
local plain = {}
Fire.pourInto(plain, "Water", 1000, 20, 0)
local _, _, _, waterParts = Fire.take(plain, 400)
check("one fluid is one part", plain.parts == nil and waterParts.Water == 400)

-- Heating and cooling. Fire.advance takes the fire's state (fireUntil, banked) apart from the cauldron's; to keep
-- them short, these fixtures carry both on one table and pass it as each.
cauldron = {}
Fire.pourInto(cauldron, "CowMilk", 10000, 20, 0)
cauldron.fireUntil = 100
local hot
for minute = 6, 240, 6 do
    Fire.advance(cauldron, minute / 60, 20, cauldron)
    if not hot and Fire.isHot(cauldron) then hot = minute / 60 end
end
check("10 L over the fire is hot in about an hour and a half", hot and hot > 1.3 and hot < 1.7)
check("milk counts its hours at the steam, as any fluid does", near(Fire.heldHours(cauldron), 4 - hot, 0.15))
Fire.pourInto(cauldron, "CowMilk", 1000, 20, 4)
check("pouring more in starts the count over", Fire.heldHours(cauldron) == 0)
check("an empty cauldron has held nothing", Fire.heldHours({ held = 2 }) == 0)
check("20 L takes about two hours", Fire.hoursToHot({ ml = 20000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }) > 1.8
    and Fire.hoursToHot({ ml = 20000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }) < 2.1)
check("a full 60 L cauldron under three hours", Fire.hoursToHot({ ml = 60000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }) > 2.6
    and Fire.hoursToHot({ ml = 60000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }) < 2.9)
check("and never boils", cauldron.tempC <= Fire.MAX_C)
local split = { ml = 10000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }
Fire.advance(split, 1, 20, split)
Fire.advance(split, 2, 20, split)
local once = { ml = 10000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }
Fire.advance(once, 2, 20, once)
check("ticks or one catch-up give the same heat", near(split.tempC, once.tempC, 1e-6))
local small = { ml = 1000, fluid = "Water", tempC = 20, last = 0, fireUntil = 100 }
Fire.advance(small, 1, 20, small)
check("a litre heats faster", Fire.isHot(small))
check("cold fluid poured in lowers the heat", Fire.take(cauldron, 5000) == 5000
    and Fire.pourInto(cauldron, "CowMilk", 5000, 5, 4) == 5000 and cauldron.tempC < Fire.HOT_C and not Fire.isHot(cauldron))
local outFire = { ml = 10000, fluid = "CowMilk", tempC = 90, last = 0, fireUntil = 1 }
Fire.advance(outFire, 3, 20, outFire)
local byFireThenOut = Fire.cool(Fire.cool(90, Fire.MAX_C, 1, Fire.cauldronTau(10000, true)), 20, 2,
    Fire.cauldronTau(10000, false))
check("out of fuel it cools to the room from then on", near(outFire.tempC, byFireThenOut, 1e-6))
check("slower than it heated: the stone holds it", Fire.cauldronTau(10000, false) > 2 * Fire.cauldronTau(10000, true))
local unlit = { ml = 10000, fluid = "CowMilk", tempC = 90, last = 0 }
Fire.advance(unlit, 2, 20, unlit)
check("a cauldron with no fire cools", unlit.tempC < 60 and unlit.tempC > 20)
check("the cauldron shows empty, full or steaming", Fire.look({}) == "Empty"
    and Fire.look({ ml = 100, tempC = 40 }) == "Full" and Fire.look({ ml = 100, fluid = "Water", tempC = 90 }) == "Hot")
for _, fluid in ipairs({ "CowMilk", "Water" }) do
    local warming = { ml = 10000, fluid = fluid, tempC = 20, last = 0, fireUntil = 100 }
    local eta = Fire.hoursToHot(warming, warming.banked)
    Fire.advance(warming, eta - 0.01, 20, warming)
    local before = Fire.isHot(warming)
    Fire.advance(warming, eta + 0.01, 20, warming)
    check("the time to hot is right: " .. fluid, not before and Fire.isHot(warming) and Fire.hoursToHot(warming, warming.banked) == 0)
end
check("an empty cauldron is never hot", Fire.hoursToHot({}) == nil)

-- Water boils
local pot = { ml = 10000, fluid = "TaintedWater", tempC = 20, last = 0, fireUntil = 100 }
check("water steams sooner than milk: it is let boil", Fire.hoursToHot(pot, pot.banked) < 1.1)
Fire.advance(pot, 1.5, 20, pot)
check("10 L of water is not at the boil in an hour and a half", pot.tempC < Fire.BOIL_C and pot.fluid == "TaintedWater")
Fire.advance(pot, 1.7, 20, pot)
check("it boils at 100 C and holds there", pot.tempC == Fire.BOIL_C and pot.boiled and pot.fluid == "TaintedWater")
Fire.advance(pot, 1.9, 20, pot)
check("ten minutes at the boil and it is clean", pot.fluid == "Water" and pot.tempC == Fire.BOIL_C)
check("water at the boil pours out hot enough for vanilla to call it clean", Fire.itemHeat(Fire.BOIL_C) >= 1.6)
local stepped = { ml = 10000, fluid = "TaintedWater", tempC = 20, last = 0, fireUntil = 100 }
for minute = 1, 114 do Fire.advance(stepped, minute / 60, 20, stepped) end
check("minute by minute it boils clean as well", stepped.fluid == "Water")
local fullCauldron = { ml = 60000, fluid = "TaintedWater", tempC = 20, last = 0, fireUntil = 100 }
Fire.advance(fullCauldron, 2.9, 20, fullCauldron)
local notYet = fullCauldron.tempC < Fire.BOIL_C
Fire.advance(fullCauldron, 3.3, 20, fullCauldron)
check("a full cauldron of water boils clean in about three hours", notYet and fullCauldron.fluid == "Water")
local interrupted = { ml = 10000, fluid = "TaintedWater", tempC = 99, last = 0, fireUntil = 0.1 }
Fire.advance(interrupted, 0.2, 20, interrupted)
interrupted.fireUntil = 100
Fire.advance(interrupted, 0.3, 20, interrupted)
check("the boil starts over when the fire goes out", interrupted.fluid == "TaintedWater")
local topped = { ml = 10000, fluid = "TaintedWater", tempC = 100, last = 0, fireUntil = 100, boiled = 0.1 }
Fire.pourInto(topped, "TaintedWater", 1000, 20, 0)
check("and when more is poured in", topped.boiled == nil)
local milk = { ml = 10000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }
Fire.advance(milk, 24, 20, milk)
check("milk is kept off the boil", milk.tempC <= Fire.MAX_C and milk.boiled == nil)
local bankedWater = { ml = 10000, fluid = "TaintedWater", tempC = 20, last = 0, fireUntil = 100, banked = true }
Fire.advance(bankedWater, 24, 20, bankedWater)
check("banked embers never boil water", bankedWater.fluid == "TaintedWater" and bankedWater.tempC < 60)

-- Fluids a mod has the cauldron change
Fire.turnsHot("RawFat", "MeltedFat", 1)
Fire.goesOff("RawFat", "RancidFat")
Fire.staysIn("RawFat")
local fat = {}
Fire.pourInto(fat, "RawFat", 1500, 20, 0)
check("a fluid that stays in can't be filled out", not Fire.poursOut(fat) and Fire.poursOut({ fluid = "Water" }))
check("it has its whole hour of steaming to go", Fire.hoursToTurn(fat) == 1 and Fire.hoursToTurn({ ml = 1000, fluid = "Water" }) == nil)
Fire.advance(fat, 5, 20, fat)
check("a cold cauldron turns nothing", fat.fluid == "RawFat" and fat.hot == 0)
fat.fireUntil = 100
local toSteam = Fire.hoursToHot(fat, fat.banked)
Fire.advance(fat, 5 + toSteam + 0.5, 20, fat)
check("half an hour steaming is half the work", fat.fluid == "RawFat" and near(fat.hot, 0.5) and near(Fire.hoursToTurn(fat), 0.5))
Fire.advance(fat, 5 + toSteam + 1.01, 20, fat)
check("an hour steaming and it has turned", fat.fluid == "MeltedFat" and fat.hot == nil and Fire.poursOut(fat))
local away = {}
Fire.pourInto(away, "RawFat", 1500, 20, 0)
away.fireUntil = 100
Fire.advance(away, 3, 20, away)
check("left alone over the fire it turns as well", away.fluid == "MeltedFat")
local stepped = {}
Fire.pourInto(stepped, "RawFat", 1500, 20, 0)
stepped.fireUntil = 100
for minute = 1, 100 do Fire.advance(stepped, minute / 60, 20, stepped) end
check("minute by minute it isn't done at an hour and forty minutes", stepped.fluid == "RawFat")
for minute = 101, 110 do Fire.advance(stepped, minute / 60, 20, stepped) end
check("and is ten minutes on", stepped.fluid == "MeltedFat")
local dying = { ml = 1500, fluid = "RawFat", tempC = 95, last = 0, fireUntil = 0.5 }
Fire.advance(dying, 10, 20, dying)
check("a fire that dies counts the steaming while the cauldron cools, and no more", dying.fluid == "RawFat" and dying.hot > 0.5 and dying.hot < 1)
local more = { ml = 1500, fluid = "RawFat", tempC = 95, last = 0, fireUntil = 100, hot = 0.9 }
Fire.pourInto(more, "RawFat", 500, 20, 0)
check("more put in starts the hour over", more.hot == nil)
check("what has turned doesn't take the raw", select(2, Fire.pourInto(fat, "RawFat", 500, 20, 7)) == "Mixed")
local banked = { ml = 1500, fluid = "RawFat", tempC = 20, last = 0, fireUntil = 100, banked = true }
Fire.advance(banked, 24, 20, banked)
check("banked embers are too cool to turn it", banked.fluid == "RawFat")

-- Going off
local old = {}
Fire.pourInto(old, "RawFat", 1000, 20, 0)
Fire.offBy(old, 48)
Fire.offBy(old, 72)
check("the soonest hour to go off is kept", old.offAt == 48)
Fire.advance(old, 47, 20, old)
check("before then it is as it was", old.fluid == "RawFat")
Fire.advance(old, 49, 20, old)
check("after, it has gone off", old.fluid == "RancidFat" and old.offAt == nil)
old.fireUntil = 100
Fire.advance(old, 60, 20, old)
check("and no fire brings it back", old.fluid == "RancidFat")
local saved = {}
Fire.pourInto(saved, "RawFat", 1000, 20, 0)
Fire.offBy(saved, 48)
saved.fireUntil = 100
Fire.advance(saved, 3, 20, saved)
Fire.advance(saved, 500, 20, saved)
check("what turned in time never goes off", saved.fluid == "MeltedFat" and saved.offAt == nil)
local late = {}
Fire.pourInto(late, "RawFat", 1000, 20, 0)
Fire.offBy(late, 48)
Fire.advance(late, 40, 20, late)
late.fireUntil = 100
Fire.advance(late, 500, 20, late)
check("a fire lit in time turns it, however late it is looked at", late.fluid == "MeltedFat")
Fire.take(old)
check("emptied, the cauldron forgets both clocks", old.hot == nil and old.offAt == nil)

-- Banked
local banked = { ml = 10000, fluid = "Water", tempC = 20, last = 0, fireUntil = 100, banked = true }
Fire.advance(banked, 24, 20, banked)
check("banked embers keep the cauldron about 50 C and never steam it", near(banked.tempC, Fire.BANKED_C, 0.5)
    and Fire.hoursToHot(banked, banked.banked) == nil)
local fromHot = { ml = 10000, fluid = "Water", tempC = 90, last = 0, fireUntil = 100, banked = true }
local outHot = { ml = 10000, fluid = "Water", tempC = 90, last = 0 }
Fire.advance(fromHot, 2, 20, fromHot)
Fire.advance(outHot, 2, 20, outHot)
check("a hot cauldron over banked embers cools, slower than with the fire out", fromHot.tempC < 90 and fromHot.tempC > outHot.tempC)

-- Banked, vanilla's fire is out and its fuel stays put: only the mod's count burns.
local fire = {}
check("a fire that isn't banked is left alone", Fire.reckonFuel(fire, 120, true, 0) == nil)
Fire.setBanked(fire, true, 120, 0)
local fuel = Fire.reckonFuel(fire, 120, false, 1)
check("banked, an hour burns 20 minutes of fuel", fuel == 100 and fire.banked)
fuel = Fire.reckonFuel(fire, 100 + 60, false, 1.5)
check("wood added counts in full", fuel == 100 - 10 + 60)
local away = {}
Fire.setBanked(away, true, 180, 0)
check("away for five hours, the count burns on", Fire.reckonFuel(away, 180, false, 5) == 80)
local relit = {}
Fire.setBanked(relit, true, 180, 0)
check("lit by anything but stoking, it is a lit fire again", Fire.reckonFuel(relit, 180, true, 0.2) == nil and relit.banked == nil)
local burnt = {}
Fire.setBanked(burnt, true, 30, 0)
check("burnt down, it is out with no fuel and no longer banked", Fire.reckonFuel(burnt, 30, false, 2) == 0 and burnt.banked == nil)
local old = { banked = true }
check("banked with no count yet, it starts one from vanilla's fuel", Fire.reckonFuel(old, 90, false, 3) == nil and old.fuel == 90 and old.fuelAt == 3)
check("a banked firebox cooks a third as fast", near(Fire.bankedCooking(10, 40), 20) and Fire.bankedCooking(10, 5) == 5)

-- Tiles
check("every hearth tile is known with its facing", #Fire.CAULDRON_SPRITES == 12 and Fire.cauldronFace(Fire.cauldronSprite("Hot", 1)) == 1
    and Fire.cauldronFace(Fire.cauldronSprite("Empty", 0)) == 0 and Fire.cauldronFace("traditionalpreservationcore_01_6") == nil
    and Fire.cauldronFace("traditionalpreservationdairy_01_20") == nil)
check("its tile by the fire, its glow drawn in, steaming when hot", Fire.cauldronSprite("Full", 0) == "traditionalpreservationcore_01_0"
    and Fire.cauldronSprite("Hot", 1) == "traditionalpreservationcore_01_3" and Fire.cauldronSprite("Full", 0, true, false) == "traditionalpreservationcore_01_4"
    and Fire.cauldronSprite("Hot", 1, true, true) == "traditionalpreservationcore_01_75"
    and Fire.cauldronSprite("Empty", 0, false, true) == Fire.cauldronSprite("Empty", 0))
local overlay, tint = Fire.liquidOverlay({ ml = 1000, fluid = "Water" }, 1)
check("what it holds is the overlay, tinted (white when a fluid has no colour); none when empty",
    overlay == "traditionalpreservationcore_01_7" and tint[1] == 1 and tint[3] == 1
    and Fire.liquidOverlay({ ml = 0, fluid = "Water" }, 0) == nil and Fire.cauldronFace(overlay) == nil)
-- Tainted water taints clean, either way round and whatever the share; the lot boils clean again.
local tub = { ml = 10000, fluid = "Water", tempC = 60, last = 0, boiled = 0.5 }
check("clean water takes tainted water: the whole lot is tainted", Fire.pourInto(tub, "TaintedWater", 100, 20, 0) == 100
    and tub.fluid == "TaintedWater" and tub.ml == 10100 and tub.parts == nil and tub.boiled == nil)
local foul = { ml = 1000, fluid = "TaintedWater", tempC = 20, last = 0 }
check("tainted water takes clean, and stays tainted", Fire.pourInto(foul, { Water = 9000 }, 9000, 20, 0) == 9000
    and foul.fluid == "TaintedWater" and foul.ml == 10000 and foul.parts == nil)
foul.fireUntil = 100
Fire.advance(foul, 2, 20, foul)
check("and boils clean again", foul.fluid == "Water")
check("neither mixes with anything else", select(2, Fire.cauldronRoom({ ml = 1000, fluid = "TaintedWater" }, "CowMilk", 10)) == "Mixed"
    and select(2, Fire.cauldronRoom({ ml = 1000, fluid = "CowMilk" }, "TaintedWater", 10)) == "Mixed"
    and Fire.taintedBy({ ml = 1000, fluid = "Water" }, "Water") == nil and Fire.taintedBy({}, "TaintedWater") == nil)
check("a fluid is named in one taint only", select(1, pcall(Fire.taints, "TestFoul", "Water")) == false)
local function bucket(primary, amounts)
    local total = 0
    for _, litres in pairs(amounts) do total = total + litres end
    return {
        isEmpty = function() return total <= 0 end,
        getAmount = function() return total end,
        getPrimaryFluid = function() return { getFluidTypeString = function() return primary end } end,
        getPrimaryFluidAmount = function() return amounts[primary] end,
        getSpecificFluidAmount = function(_, fluid) return amounts[fluid.name] or 0 end,
    }
end
local savedFluid = Fluid
Fluid = { Get = function(name) return { name = name } end }
local bucketParts, bucketFluid = Fire.partsIn(bucket("Water", { Water = 8, TaintedWater = 2 }))
check("vanilla's bucket of clean and tainted water pours in as tainted water", bucketFluid == "TaintedWater"
    and bucketParts.TaintedWater == 10000 and bucketParts.Water == nil)
check("tainted first the same", select(2, Fire.partsIn(bucket("TaintedWater", { TaintedWater = 6, Water = 4 }))) == "TaintedWater"
    and Fire.partsIn(bucket("Water", { Water = 8, CowMilk = 2 })) == nil)
Fluid = savedFluid

local savedFluid = Fluid
Fluid = {}
local function colour(r, g, b) return { getRedFloat = function() return r end, getGreenFloat = function() return g end, getBlueFloat = function() return b end } end
Fluid.Get = function(name)
    local c = ({ TestRed = colour(1, 0, 0), TestBlue = colour(0, 0, 1) })[name]
    return c and { getColor = function() return c end }
end
local mixed = Fire.liquidColour({ ml = 1000, fluid = "TestRed", parts = { TestRed = 3, TestBlue = 1 } })
check("a blend's colour is its fluids' mixed by their shares", near(mixed[1], 0.75) and mixed[2] == 0 and near(mixed[3], 0.25))
Fluid = savedFluid

-- The Stone Hearth with nothing fitted (bare)
local bareTile = Fire.bareSprite(false, nil, 1)
check("every Stone Hearth tile is known with its facing, apart from the cauldron's", #Fire.BARE_SPRITES == 6
    and Fire.bareFace(bareTile) == 1 and Fire.cauldronFace(bareTile) == nil and Fire.stoneHearthFace(bareTile) == 1
    and Fire.bareFace(Fire.cauldronSprite("Empty", 0)) == nil and Fire.stoneHearthFace(Fire.cauldronSprite("Hot", 1)) == 1
    and #Fire.FIRE_SPRITES == 18)
check("its tile by hole alone, no flue tiles; open when nothing is in it",
    bareTile == "traditionalpreservationcore_01_11"
    and Fire.bareSprite(false, "Pot", 0) == "traditionalpreservationcore_01_14"
    and Fire.bareSprite(true, "Lid", 0) == "traditionalpreservationcore_01_12"
    and Fire.bareSprite(true, "Pot", 1) == "traditionalpreservationcore_01_15"
    and Fire.bareSprite(false, "Lid", 0) == "traditionalpreservationcore_01_12")
check("under a connection taking the smoke, the hole is never open: the lid goes on",
    Fire.bareSprite(true, "Open", 0) == Fire.bareSprite(true, "Lid", 0)
    and Fire.bareSprite(true, nil, 1) == "traditionalpreservationcore_01_13")
check("its glow: smoke round the door under the lid, out of the hole when open, round the pot, none once joined, nothing while out",
    Fire.bareGlow(true, false, nil, "Lid", 0) == "traditionalpreservationcore_01_24"
    and Fire.bareGlow(true, false, nil, "Open", 1) == "traditionalpreservationcore_01_47"
    and Fire.bareGlow(true, true, nil, "Pot", 0) == "traditionalpreservationcore_01_52"
    and Fire.bareGlow(true, true, true, "Pot", 1) == "traditionalpreservationcore_01_31"
    and Fire.bareGlow(false, false, nil, "Open", 0) == nil)

-- Stove or oven, and what shows in the hole
local function food(fullType, fluid)
    return { getFullType = function() return fullType end,
        getFluidContainer = function() return fluid and { isEmpty = function() return fluid == 0 end } or nil end }
end
check("vanilla's stews, soups, stir-fries, omelettes, pasta and rice are stove food; anything else is oven food",
    Fire.cookedOn(food("Base.PotOfStew")) == Fire.STOVE and Fire.cookedOn(food("Base.EggOmelette")) == Fire.STOVE
    and Fire.cookedOn(food("Base.PanFriedVegetablesForged")) == Fire.STOVE
    and Fire.cookedOn(food("Base.WaterPotForgedPasta")) == Fire.STOVE
    and Fire.cookedOn(food("Base.RicePanCopper")) == Fire.STOVE
    and Fire.cookedOn(food("Base.PieWholeRaw")) == Fire.OVEN)
Fire.cooksOn(Fire.STOVE, "Test.PotOfThing")
check("a mod names its own stove food", Fire.cookedOn(food("Test.PotOfThing")) == Fire.STOVE)
check("empty, the hole is open", Fire.holeLook(H.list({})) == Fire.OPEN and Fire.holeLook(nil) == Fire.OPEN)
check("oven food only: the lid", Fire.holeLook(H.list({ food("Base.PieWholeRaw"), food("Base.Bread") })) == Fire.LID)
check("an empty pot is oven gear too", Fire.holeLook(H.list({ food("Base.Pot", 0) })) == Fire.LID)
check("any stove food or fluid wins: the pot", Fire.holeLook(H.list({ food("Base.PieWholeRaw"), food("Base.PotOfSoup") })) == Fire.POT
    and Fire.holeLook(H.list({ food("Base.Bread"), food("Base.Pot", 2) })) == Fire.POT)
-- Connections (Fire.connect): one at a time, its kind and side under its id.
local trench = { tool = "DIG_GRAVE", items = { { "Base.FlatStone", 3 }, { "Base.Clay", 2 } }, back = "Base.FlatStone" }
local duct = Fire.connect({ id = "testDuct", kinds = { "Stones" }, kits = { Stones = trench }, blocks = "both" })
check("a connection registers by its id, its fields given later added to it", Fire.connection("testDuct") == duct
    and Fire.connect({ id = "testDuct", notes = print }) == duct and duct.notes == print and duct.blocks == "both")
local flue = {}
Fire.join(flue, "testDuct", "Stones", "Back")
check("joined to a side, its kind and side under its id", Fire.connectedTo(flue) == "testDuct"
    and flue.testDuct.kind == "Stones" and flue.testDuct.side == "Back" and select(2, Fire.joinOf(flue)) == "Back")
check("taken up, it says what it was", Fire.unjoin(flue) == "testDuct" and flue.connected == nil and flue.testDuct == nil
    and Fire.joinOf(flue) == nil)
Fire.join(flue, "testDuct", "Stones", "Front")
check("never the door's side: nothing is joined", Fire.connectedTo(flue) == nil and flue.testDuct == nil)
Fire.join(flue, "testDuct", "Pipe", "Back")
check("nor by a kit it hasn't got", Fire.connectedTo(flue) == nil)
Fire.join(flue, "noSuchThing", "Stones", "Back")
check("nor an unknown connection", Fire.connectedTo(flue) == nil)
check("Connect's refusals, the first that applies", Fire.connectRefusalOf({ side = "Back" }) == nil
    and Fire.connectRefusalOf({ joined = true, own = "X" }) == "IGUI_TraditionalPreservationCore_FlueStoneHearthJoined"
    and Fire.connectRefusalOf({ own = "X", burning = true }) == "X"
    and Fire.connectRefusalOf({ burning = true }) == "IGUI_TraditionalPreservationCore_FlueStoneHearthDoor"
    and Fire.connectRefusalOf({ side = "Left", burning = true, fitted = true }) == "IGUI_TraditionalPreservationCore_FireBurning"
    and Fire.connectRefusalOf({ side = "Left", fitted = true }) == "IGUI_TraditionalPreservationCore_ConnectFitted")
local short, noTool = Fire.kitMissing(trench, { ["Base.FlatStone"] = 1 }, false)
check("a kit's shortfall and its tool", #short == 2 and short[1][2] == 2 and short[2][2] == 2 and noTool)
local back = Fire.kitBack(trench)
check("Disconnect gives back only the kit's back items", #back == 1 and back[1][1] == "Base.FlatStone" and back[1][2] == 3)
for face, sides in pairs(require("TraditionalPreservationCore/FireConnect").FLUE_SIDES) do
    local door = face == 0 and { 0, 1 } or { 1, 0 }
    local ok = true
    for _, step in pairs(sides) do
        if step[1] == door[1] and step[2] == door[2] then ok = false end
    end
    check("facing " .. face .. ": the flue's three sides never include the door's", ok)
end

-- By a fire
local ledger = { temperature = -10, seasonTemperature = -5 }
check("a fire keeps its warmth whatever the weather", Weather.placeTemperature(ledger, Fire.PLACE) == Fire.FIRE_C
    and Weather.placeTemperature(ledger, "Open") == -10)
check("banked embers are a cooler place by a fire", Weather.placeTemperature(ledger, Fire.EMBERS) == Fire.EMBERS_C
    and Fire.EMBERS_C < Fire.FIRE_C and Fire.isFirePlace(Fire.EMBERS) and not Fire.isFirePlace("Open"))
check("a fire in a January field warms the day's air by 10, under an open roof the season's by 15",
    Weather.placeTemperature(ledger, "FiresideOpen") == 0 and Weather.placeTemperature(ledger, "FiresideCovered") == 10
    and Fire.isFirePlace("FiresideOpen") and Fire.isFirePlace("EmbersCovered"))
check("banked embers outside add 5 in the open, 10 under a roof", Weather.placeTemperature(ledger, "EmbersOpen") == -5
    and Weather.placeTemperature(ledger, "EmbersCovered") == 5)
local summer = { temperature = 25, seasonTemperature = 22 }
check("never warmer than by a fire indoors", Weather.placeTemperature(summer, "FiresideOpen") == Fire.FIRE_C
    and Weather.placeTemperature(summer, "EmbersCovered") == Fire.EMBERS_C)
check("fireC: indoors needs no ledger, outside does", Fire.fireC(Fire.PLACE) == Fire.FIRE_C
    and Fire.fireC("FiresideOpen") == nil and Fire.fireC("FiresideOpen", ledger) == 0 and Fire.fireC("Open", ledger) == nil)
check("firePlace: the fire's own place outside, plain indoors", Fire.firePlace(Fire.PLACE, "Open") == "FiresideOpen"
    and Fire.firePlace(Fire.EMBERS, "Covered") == "EmbersCovered" and Fire.firePlace(Fire.PLACE, "Basement") == Fire.PLACE
    and Fire.firePlace(Fire.PLACE, "Loft") == Fire.PLACE)
local state = {}
Fire.noteFire(state, nil, nil, 5)
check("no fire, no notes", state.fireUntil == nil and state.under == nil)

-- Catching up by a fire: by the clock at its heat until the fuel ran out, then the place under it by its share.
local half = function(celsius) return celsius >= 20 and 1 or 0.5 end
local kinds = { work = half }
local book = Weather.newLedger(0, kinds)
local marks = Weather.mark({}, book, "work")
for hour = 1, 10 do Weather.advance(book, hour, 0, kinds) end
local byFire = { fireUntil = 4, under = "Sheltered" }
check("by a fire 4 hours at full speed, then 6 in a cold room at half", near(Fire.catchUp(byFire, marks, book, "work", Fire.PLACE, half), 4 + 3)
    and marks.hour == 10)
check("a fire still burning counts all of it", near(Fire.catchUp({ fireUntil = 99 }, Weather.mark({}, book, "work"), book, "work",
    Fire.PLACE, half), 0))
local away = Weather.mark({}, book, "work")
for hour = 11, 20 do Weather.advance(book, hour, 0, kinds) end
check("away from a fire it is Weather's catch-up", near(Fire.catchUp({}, away, book, "work", "Open", half), 5))
local field = Weather.mark({}, book, "work")
for hour = 21, 30 do Weather.advance(book, hour, 0, kinds) end
check("by a fire in the open it counts at the air's heat plus the lift", near(Fire.catchUp({ fireUntil = 99 }, field, book, "work",
    "FiresideOpen", half), 5))
local seen = { place = Fire.PLACE, fireUntil = 22 }
local caught
Fire.placeOf = function() return "Sheltered" end
Fire.notePlace(seen, {}, 30, function(s) caught = s.place end)
check("a move catches up at the place it left first", caught == Fire.PLACE and seen.place == "Sheltered" and seen.fireUntil == nil)

-- Hooks
local function item(heat)
    local modData = {}
    return { getItemHeat = function() return heat end, setItemHeat = function(self, h) heat = h end,
        getModData = function() return modData end, heat = function() return heat end }
end
local plain = item(1)
check("with no hook an item pours at vanilla's heat", Fire.heatOf(plain, 0) == Fire.ROOM_C)
Fire.filledFrom(plain, { ml = 1000, fluid = "Water", tempC = 90 })
check("and a fill sets vanilla's heat to the cauldron's", near(Fire.heatCelsius(plain.heat()), 90))
local kept = item(1)
kept.keeps = true
Fire.hook("heatOf", function(i) return i.keeps and 70 or nil end)
check("a hook answers for its own items", Fire.heatOf(kept, 0) == 70 and Fire.heatOf(plain, 0) ~= 70)
local seen
Fire.hook("filled", function(i, fill)
    if fill.fluid ~= "CowMilk" then return false end
    seen = fill.ml
    return true
end)
Fire.filledFrom(kept, { ml = 500, fluid = "CowMilk", tempC = 90 })
check("a hook that handles a fill leaves vanilla's heat alone", seen == 500 and kept.heat() == 1)
local took
Fire.hook("taken", function(i, ml) took = ml end)
Fire.tookFrom(kept, 250)
check("taken hooks hear how much left", took == 250)

-- Save key
local modData = {}
local saved = Fire.cauldronState(modData)
Fire.pourInto(saved, "Water", 1000, 20, 0)
check("the cauldron lives under its id inside one prefixed key", modData.tpFire.cauldron.ml == 1000 and modData.tpFire.ml == nil
    and modData.ml == nil and Fire.cauldronState(modData) == saved)

-- The attachment registry
local first = Fire.attach({ id = "testPan", look = function() return "Full" end })
local later = Fire.attach({ id = "testPan", menu = function() end })
check("attaching an id again adds its fields to the one registered", first == later and Fire.attachment("testPan") == first
    and first.look ~= nil and first.menu ~= nil and first.id == "testPan")
check("each attachment's state is its own", Fire.partState(modData, "testPan") ~= saved and modData.tpFire.testPan ~= nil)

-- What register is given (refactoring rule 6): each refusal names the function and what is wrong.
local function refuses(name, fn, ...)
    local ok, err = pcall(fn, ...)
    return not ok and tostring(err):find(name, 1, true) ~= nil
end
check("an attachment needs an id", refuses("Fire.attach", Fire.attach, { look = print }))
check("a field already given isn't given again as something else",
    refuses("look is already given", Fire.attach, { id = "testPan", look = print })
    and Fire.attach({ id = "testPan", look = first.look }) == first)
check("a fit needs its items", refuses("fit needs items", Fire.attach, { id = "testPot", fit = { ticks = 1 } }))
check("a connection's kinds come with its kits, a kit for every kind",
    refuses("kinds and kits come together", Fire.connect, { id = "testHalf", kinds = { "Pipe" } })
    and refuses("no kit for kind Clay", Fire.connect, { id = "testOdd", kinds = { "Clay" }, kits = { Pipe = {} } }))
check("a hook has a known name and a function", refuses("no hook named heats", Fire.hook, "heats", print)
    and refuses("needs a function", Fire.hook, "taken", "print"))
Fire.blend("TestMilkA", "TestMilkB")
check("a fluid blends in one group only", refuses("TestMilkB is already in a blend", Fire.blend, "TestMilkB", "TestMilkC"))
Fire.turnsHot("TestRaw", "TestRendered", 1)
Fire.goesOff("TestRaw", "TestRancid")
check("a fluid turns and goes off one way only", refuses("already turns", Fire.turnsHot, "TestRaw", "TestOther", 2)
    and refuses("already goes off", Fire.goesOff, "TestRaw", "TestOther"))
check("food cooks on the stove or in the oven", refuses("Fire.cooksOn", Fire.cooksOn, "grill", "Base.Steak"))
-- The fire's record (Smokehouse 5c)
local fire = {}
Fire.logFire(fire, 10, Fire.STOKED, 16)
check("stoking starts a session", fire.session == 10 and Fire.sessionHours(fire) == 0 and fire.fireId == 10)
Fire.logFire(fire, 13, Fire.STOKED, 17)
check("stoked hours count in the session", near(fire.stokedHours, 3) and near(Fire.sessionHours(fire), 3))
Fire.logFire(fire, 13.5, nil, nil)
Fire.logFire(fire, 14.2, Fire.STOKED, 20)
check("a short gap keeps the session, and doesn't count", fire.session == 10 and near(Fire.sessionHours(fire), 3.5))
Fire.logFire(fire, 30, nil, nil)
check("away past the fuel: only the hours it had count", near(fire.stokedHours, 3.5 + 5.8) and fire.session == nil)
check("and the session is over", Fire.sessionHours(fire) == 0)
Fire.logFire(fire, 31, Fire.STOKED, 35)
check("stoking again starts a new session", fire.session == 31 and fire.sessionBase == fire.stokedHours)
Fire.logFire(fire, 32, Fire.BANKED, 50)
Fire.logFire(fire, 40, Fire.BANKED, 50)
check("banked hours count apart", near(fire.bankedHours, 8) and near(fire.stokedHours, 3.5 + 5.8 + 1))
check("banked more than the grace ends the session", fire.session == nil)
Fire.logFire(fire, 41, Fire.BANKED, 50)
check("banking never starts one", fire.session == nil and fire.fireId == 10)
H.done()
