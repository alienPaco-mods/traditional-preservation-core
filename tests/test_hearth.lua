-- Checks the Hearth's cauldron and hooks in 42/media/lua. Run from TraditionalPreservationCore: luajit tests/test_hearth.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near
package.path = "42/media/lua/shared/?.lua;" .. package.path
local Hearth = require "TraditionalPreservationCore/Hearth"
local Weather = require "TraditionalPreservationCore/Weather"

-- Item heat
check("room heat is room temperature", Hearth.heatCelsius(1.0) == Hearth.ROOM_C)
check("an item never reads hotter than the cauldron gets", Hearth.heatCelsius(3.0) == Hearth.MAX_C)
check("heat goes back to the item it came from", near(Hearth.heatCelsius(Hearth.itemHeat(60)), 60))
check("an item from the fridge reads cold, not frozen", near(Hearth.heatCelsius(0.2), Hearth.COLD_C))
check("and never colder than the fridge", Hearth.heatCelsius(0) == Hearth.COLD_C and Hearth.heatCelsius(-5) == Hearth.COLD_C)
check("cold heat goes back to the item too", near(Hearth.heatCelsius(Hearth.itemHeat(10)), 10))
check("a freezing cauldron fills at the engine's floor", Hearth.itemHeat(-10) == Hearth.COLD_HEAT)

-- Filling and emptying
local cauldron = {}
check("an empty cauldron takes any fluid", Hearth.pourInto(cauldron, "Water", 4000, 20, 0) == 4000 and cauldron.fluid == "Water")
check("but not a second one", select(2, Hearth.pourInto(cauldron, "CowMilk", 1000, 20, 0)) == "Mixed")
check("emptied, it forgets the fluid", Hearth.take(cauldron) == 4000 and cauldron.fluid == nil and cauldron.tempC == nil)
check("cow's and sheep's milk don't mix", Hearth.pourInto(cauldron, "CowMilk", 60000, 20, 0) == 60000
    and select(2, Hearth.pourInto(cauldron, "SheepMilk", 100, 20, 0)) == "Mixed")
check("60 L fills it", select(2, Hearth.pourInto(cauldron, "CowMilk", 100, 20, 0)) == "Full")

-- Fluids a mod has said may share the cauldron
Hearth.blend("CowMilk", "SheepMilk")
local herd = {}
Hearth.pourInto(herd, "CowMilk", 3000, 20, 0)
check("fluids that blend share the cauldron, heat mixing by volume", Hearth.pourInto(herd, "SheepMilk", 1000, 60, 0) == 1000
    and herd.ml == 4000 and near(herd.tempC, 30) and herd.fluid == "CowMilk" and herd.parts.SheepMilk == 1000)
check("but nothing else joins them", select(2, Hearth.pourInto(herd, "Water", 100, 20, 0)) == "Mixed")
local outMl, outFluid, _, outParts = Hearth.take(herd, 2000)
check("a blend comes out in its shares", outMl == 2000 and outFluid == "CowMilk" and near(outParts.CowMilk, 1500)
    and near(outParts.SheepMilk, 500) and near(Hearth.partsOf(herd).SheepMilk, 500))
check("a blend poured in keeps its shares", Hearth.pourInto(herd, { SheepMilk = 3, CowMilk = 1 }, 2000, 20, 0) == 2000
    and near(Hearth.partsOf(herd).SheepMilk, 2000) and herd.fluid == "CowMilk")
Hearth.take(herd)
check("emptied, the blend is forgotten", herd.parts == nil and herd.fluid == nil)
local plain = {}
Hearth.pourInto(plain, "Water", 1000, 20, 0)
local _, _, _, waterParts = Hearth.take(plain, 400)
check("one fluid is one part", plain.parts == nil and waterParts.Water == 400)

-- Heating and cooling. Hearth.advance takes the fire's state (fireUntil, banked) apart from the cauldron's; to keep
-- them short, these fixtures carry both on one table and pass it as each.
cauldron = {}
Hearth.pourInto(cauldron, "CowMilk", 10000, 20, 0)
cauldron.fireUntil = 100
local hot
for minute = 6, 240, 6 do
    Hearth.advance(cauldron, minute / 60, 20, cauldron)
    if not hot and Hearth.isHot(cauldron) then hot = minute / 60 end
end
check("10 L over the fire is hot in about an hour and a half", hot and hot > 1.3 and hot < 1.7)
check("milk counts its hours at the steam, as any fluid does", near(Hearth.heldHours(cauldron), 4 - hot, 0.15))
Hearth.pourInto(cauldron, "CowMilk", 1000, 20, 4)
check("pouring more in starts the count over", Hearth.heldHours(cauldron) == 0)
check("an empty cauldron has held nothing", Hearth.heldHours({ held = 2 }) == 0)
check("20 L takes about two hours", Hearth.hoursToHot({ ml = 20000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }) > 1.8
    and Hearth.hoursToHot({ ml = 20000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }) < 2.1)
check("a full 60 L cauldron under three hours", Hearth.hoursToHot({ ml = 60000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }) > 2.6
    and Hearth.hoursToHot({ ml = 60000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }) < 2.9)
check("and never boils", cauldron.tempC <= Hearth.MAX_C)
local split = { ml = 10000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }
Hearth.advance(split, 1, 20, split)
Hearth.advance(split, 2, 20, split)
local once = { ml = 10000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }
Hearth.advance(once, 2, 20, once)
check("ticks or one catch-up give the same heat", near(split.tempC, once.tempC, 1e-6))
local small = { ml = 1000, fluid = "Water", tempC = 20, last = 0, fireUntil = 100 }
Hearth.advance(small, 1, 20, small)
check("a litre heats faster", Hearth.isHot(small))
check("cold fluid poured in lowers the heat", Hearth.take(cauldron, 5000) == 5000
    and Hearth.pourInto(cauldron, "CowMilk", 5000, 5, 4) == 5000 and cauldron.tempC < Hearth.HOT_C and not Hearth.isHot(cauldron))
local outFire = { ml = 10000, fluid = "CowMilk", tempC = 90, last = 0, fireUntil = 1 }
Hearth.advance(outFire, 3, 20, outFire)
local byFireThenOut = Hearth.cool(Hearth.cool(90, Hearth.MAX_C, 1, Hearth.cauldronTau(10000, true)), 20, 2,
    Hearth.cauldronTau(10000, false))
check("out of fuel it cools to the room from then on", near(outFire.tempC, byFireThenOut, 1e-6))
check("slower than it heated: the stone holds it", Hearth.cauldronTau(10000, false) > 2 * Hearth.cauldronTau(10000, true))
local unlit = { ml = 10000, fluid = "CowMilk", tempC = 90, last = 0 }
Hearth.advance(unlit, 2, 20, unlit)
check("a cauldron with no fire cools", unlit.tempC < 60 and unlit.tempC > 20)
check("the cauldron shows empty, full or steaming", Hearth.look({}) == "Empty"
    and Hearth.look({ ml = 100, tempC = 40 }) == "Full" and Hearth.look({ ml = 100, fluid = "Water", tempC = 90 }) == "Hot")
for _, fluid in ipairs({ "CowMilk", "Water" }) do
    local warming = { ml = 10000, fluid = fluid, tempC = 20, last = 0, fireUntil = 100 }
    local eta = Hearth.hoursToHot(warming, warming.banked)
    Hearth.advance(warming, eta - 0.01, 20, warming)
    local before = Hearth.isHot(warming)
    Hearth.advance(warming, eta + 0.01, 20, warming)
    check("the time to hot is right: " .. fluid, not before and Hearth.isHot(warming) and Hearth.hoursToHot(warming, warming.banked) == 0)
end
check("an empty cauldron is never hot", Hearth.hoursToHot({}) == nil)

-- Water boils
local pot = { ml = 10000, fluid = "TaintedWater", tempC = 20, last = 0, fireUntil = 100 }
check("water steams sooner than milk: it is let boil", Hearth.hoursToHot(pot, pot.banked) < 1.1)
Hearth.advance(pot, 1.5, 20, pot)
check("10 L of water is not at the boil in an hour and a half", pot.tempC < Hearth.BOIL_C and pot.fluid == "TaintedWater")
Hearth.advance(pot, 1.7, 20, pot)
check("it boils at 100 C and holds there", pot.tempC == Hearth.BOIL_C and pot.boiled and pot.fluid == "TaintedWater")
Hearth.advance(pot, 1.9, 20, pot)
check("ten minutes at the boil and it is clean", pot.fluid == "Water" and pot.tempC == Hearth.BOIL_C)
check("water at the boil pours out hot enough for vanilla to call it clean", Hearth.itemHeat(Hearth.BOIL_C) >= 1.6)
local stepped = { ml = 10000, fluid = "TaintedWater", tempC = 20, last = 0, fireUntil = 100 }
for minute = 1, 114 do Hearth.advance(stepped, minute / 60, 20, stepped) end
check("minute by minute it boils clean as well", stepped.fluid == "Water")
local fullCauldron = { ml = 60000, fluid = "TaintedWater", tempC = 20, last = 0, fireUntil = 100 }
Hearth.advance(fullCauldron, 2.9, 20, fullCauldron)
local notYet = fullCauldron.tempC < Hearth.BOIL_C
Hearth.advance(fullCauldron, 3.3, 20, fullCauldron)
check("a full cauldron of water boils clean in about three hours", notYet and fullCauldron.fluid == "Water")
local interrupted = { ml = 10000, fluid = "TaintedWater", tempC = 99, last = 0, fireUntil = 0.1 }
Hearth.advance(interrupted, 0.2, 20, interrupted)
interrupted.fireUntil = 100
Hearth.advance(interrupted, 0.3, 20, interrupted)
check("the boil starts over when the fire goes out", interrupted.fluid == "TaintedWater")
local topped = { ml = 10000, fluid = "TaintedWater", tempC = 100, last = 0, fireUntil = 100, boiled = 0.1 }
Hearth.pourInto(topped, "TaintedWater", 1000, 20, 0)
check("and when more is poured in", topped.boiled == nil)
local milk = { ml = 10000, fluid = "CowMilk", tempC = 20, last = 0, fireUntil = 100 }
Hearth.advance(milk, 24, 20, milk)
check("milk is kept off the boil", milk.tempC <= Hearth.MAX_C and milk.boiled == nil)
local bankedWater = { ml = 10000, fluid = "TaintedWater", tempC = 20, last = 0, fireUntil = 100, banked = true }
Hearth.advance(bankedWater, 24, 20, bankedWater)
check("banked embers never boil water", bankedWater.fluid == "TaintedWater" and bankedWater.tempC < 60)

-- Fluids a mod has the cauldron change
Hearth.turnsHot("RawFat", "MeltedFat", 1)
Hearth.goesOff("RawFat", "RancidFat")
Hearth.staysIn("RawFat")
local fat = {}
Hearth.pourInto(fat, "RawFat", 1500, 20, 0)
check("a fluid that stays in can't be filled out", not Hearth.poursOut(fat) and Hearth.poursOut({ fluid = "Water" }))
check("it has its whole hour of steaming to go", Hearth.hoursToTurn(fat) == 1 and Hearth.hoursToTurn({ ml = 1000, fluid = "Water" }) == nil)
Hearth.advance(fat, 5, 20, fat)
check("a cold cauldron turns nothing", fat.fluid == "RawFat" and fat.hot == 0)
fat.fireUntil = 100
local toSteam = Hearth.hoursToHot(fat, fat.banked)
Hearth.advance(fat, 5 + toSteam + 0.5, 20, fat)
check("half an hour steaming is half the work", fat.fluid == "RawFat" and near(fat.hot, 0.5) and near(Hearth.hoursToTurn(fat), 0.5))
Hearth.advance(fat, 5 + toSteam + 1.01, 20, fat)
check("an hour steaming and it has turned", fat.fluid == "MeltedFat" and fat.hot == nil and Hearth.poursOut(fat))
local away = {}
Hearth.pourInto(away, "RawFat", 1500, 20, 0)
away.fireUntil = 100
Hearth.advance(away, 3, 20, away)
check("left alone over the fire it turns as well", away.fluid == "MeltedFat")
local stepped = {}
Hearth.pourInto(stepped, "RawFat", 1500, 20, 0)
stepped.fireUntil = 100
for minute = 1, 100 do Hearth.advance(stepped, minute / 60, 20, stepped) end
check("minute by minute it isn't done at an hour and forty minutes", stepped.fluid == "RawFat")
for minute = 101, 110 do Hearth.advance(stepped, minute / 60, 20, stepped) end
check("and is ten minutes on", stepped.fluid == "MeltedFat")
local dying = { ml = 1500, fluid = "RawFat", tempC = 95, last = 0, fireUntil = 0.5 }
Hearth.advance(dying, 10, 20, dying)
check("a fire that dies counts the steaming while the cauldron cools, and no more", dying.fluid == "RawFat" and dying.hot > 0.5 and dying.hot < 1)
local more = { ml = 1500, fluid = "RawFat", tempC = 95, last = 0, fireUntil = 100, hot = 0.9 }
Hearth.pourInto(more, "RawFat", 500, 20, 0)
check("more put in starts the hour over", more.hot == nil)
check("what has turned doesn't take the raw", select(2, Hearth.pourInto(fat, "RawFat", 500, 20, 7)) == "Mixed")
local banked = { ml = 1500, fluid = "RawFat", tempC = 20, last = 0, fireUntil = 100, banked = true }
Hearth.advance(banked, 24, 20, banked)
check("banked embers are too cool to turn it", banked.fluid == "RawFat")

-- Going off
local old = {}
Hearth.pourInto(old, "RawFat", 1000, 20, 0)
Hearth.offBy(old, 48)
Hearth.offBy(old, 72)
check("the soonest hour to go off is kept", old.offAt == 48)
Hearth.advance(old, 47, 20, old)
check("before then it is as it was", old.fluid == "RawFat")
Hearth.advance(old, 49, 20, old)
check("after, it has gone off", old.fluid == "RancidFat" and old.offAt == nil)
old.fireUntil = 100
Hearth.advance(old, 60, 20, old)
check("and no fire brings it back", old.fluid == "RancidFat")
local saved = {}
Hearth.pourInto(saved, "RawFat", 1000, 20, 0)
Hearth.offBy(saved, 48)
saved.fireUntil = 100
Hearth.advance(saved, 3, 20, saved)
Hearth.advance(saved, 500, 20, saved)
check("what turned in time never goes off", saved.fluid == "MeltedFat" and saved.offAt == nil)
local late = {}
Hearth.pourInto(late, "RawFat", 1000, 20, 0)
Hearth.offBy(late, 48)
Hearth.advance(late, 40, 20, late)
late.fireUntil = 100
Hearth.advance(late, 500, 20, late)
check("a fire lit in time turns it, however late it is looked at", late.fluid == "MeltedFat")
Hearth.take(old)
check("emptied, the cauldron forgets both clocks", old.hot == nil and old.offAt == nil)

-- Banked
local banked = { ml = 10000, fluid = "Water", tempC = 20, last = 0, fireUntil = 100, banked = true }
Hearth.advance(banked, 24, 20, banked)
check("banked embers keep the cauldron about 50 C and never steam it", near(banked.tempC, Hearth.BANKED_C, 0.5)
    and Hearth.hoursToHot(banked, banked.banked) == nil)
local fromHot = { ml = 10000, fluid = "Water", tempC = 90, last = 0, fireUntil = 100, banked = true }
local outHot = { ml = 10000, fluid = "Water", tempC = 90, last = 0 }
Hearth.advance(fromHot, 2, 20, fromHot)
Hearth.advance(outHot, 2, 20, outHot)
check("a hot cauldron over banked embers cools, slower than with the fire out", fromHot.tempC < 90 and fromHot.tempC > outHot.tempC)

-- Banked, vanilla's fire is out and its fuel stays put: only the mod's count burns.
local fire = {}
check("a fire that isn't banked is left alone", Hearth.reckonFuel(fire, 120, true, 0) == nil)
Hearth.setBanked(fire, true, 120, 0)
local fuel = Hearth.reckonFuel(fire, 120, false, 1)
check("banked, an hour burns 20 minutes of fuel", fuel == 100 and fire.banked)
fuel = Hearth.reckonFuel(fire, 100 + 60, false, 1.5)
check("wood added counts in full", fuel == 100 - 10 + 60)
local away = {}
Hearth.setBanked(away, true, 180, 0)
check("away for five hours, the count burns on", Hearth.reckonFuel(away, 180, false, 5) == 80)
local relit = {}
Hearth.setBanked(relit, true, 180, 0)
check("lit by anything but stoking, it is a lit fire again", Hearth.reckonFuel(relit, 180, true, 0.2) == nil and relit.banked == nil)
local burnt = {}
Hearth.setBanked(burnt, true, 30, 0)
check("burnt down, it is out with no fuel and no longer banked", Hearth.reckonFuel(burnt, 30, false, 2) == 0 and burnt.banked == nil)
local old = { banked = true }
check("banked with no count yet, it starts one from vanilla's fuel", Hearth.reckonFuel(old, 90, false, 3) == nil and old.fuel == 90 and old.fuelAt == 3)
check("a banked firebox cooks a third as fast", near(Hearth.bankedCooking(10, 40), 20) and Hearth.bankedCooking(10, 5) == 5)

-- Tiles
check("every hearth tile is known with its facing", #Hearth.SPRITES == 12 and Hearth.face(Hearth.sprite("Hot", 1)) == 1
    and Hearth.face(Hearth.sprite("Empty", 0)) == 0 and Hearth.face("traditionalpreservationcore_01_6") == nil
    and Hearth.face("traditionalpreservationdairy_01_20") == nil)
check("its tile by the fire, its glow drawn in, steaming when hot", Hearth.sprite("Full", 0) == "traditionalpreservationcore_01_0"
    and Hearth.sprite("Hot", 1) == "traditionalpreservationcore_01_3" and Hearth.sprite("Full", 0, true, false) == "traditionalpreservationcore_01_4"
    and Hearth.sprite("Hot", 1, true, true) == "traditionalpreservationcore_01_75"
    and Hearth.sprite("Empty", 0, false, true) == Hearth.sprite("Empty", 0))
local overlay, tint = Hearth.liquidOverlay({ ml = 1000, fluid = "Water" }, 1)
check("what it holds is the overlay, tinted (white when a fluid has no colour); none when empty",
    overlay == "traditionalpreservationcore_01_7" and tint[1] == 1 and tint[3] == 1
    and Hearth.liquidOverlay({ ml = 0, fluid = "Water" }, 0) == nil and Hearth.face(overlay) == nil)
-- Tainted water taints clean, either way round and whatever the share; the lot boils clean again.
local tub = { ml = 10000, fluid = "Water", tempC = 60, last = 0, boiled = 0.5 }
check("clean water takes tainted water: the whole lot is tainted", Hearth.pourInto(tub, "TaintedWater", 100, 20, 0) == 100
    and tub.fluid == "TaintedWater" and tub.ml == 10100 and tub.parts == nil and tub.boiled == nil)
local foul = { ml = 1000, fluid = "TaintedWater", tempC = 20, last = 0 }
check("tainted water takes clean, and stays tainted", Hearth.pourInto(foul, { Water = 9000 }, 9000, 20, 0) == 9000
    and foul.fluid == "TaintedWater" and foul.ml == 10000 and foul.parts == nil)
foul.fireUntil = 100
Hearth.advance(foul, 2, 20, foul)
check("and boils clean again", foul.fluid == "Water")
check("neither mixes with anything else", select(2, Hearth.cauldronRoom({ ml = 1000, fluid = "TaintedWater" }, "CowMilk", 10)) == "Mixed"
    and select(2, Hearth.cauldronRoom({ ml = 1000, fluid = "CowMilk" }, "TaintedWater", 10)) == "Mixed"
    and Hearth.taintedBy({ ml = 1000, fluid = "Water" }, "Water") == nil and Hearth.taintedBy({}, "TaintedWater") == nil)
check("a fluid is named in one taint only", select(1, pcall(Hearth.taints, "TestFoul", "Water")) == false)
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
local bucketParts, bucketFluid = Hearth.partsIn(bucket("Water", { Water = 8, TaintedWater = 2 }))
check("vanilla's bucket of clean and tainted water pours in as tainted water", bucketFluid == "TaintedWater"
    and bucketParts.TaintedWater == 10000 and bucketParts.Water == nil)
check("tainted first the same", select(2, Hearth.partsIn(bucket("TaintedWater", { TaintedWater = 6, Water = 4 }))) == "TaintedWater"
    and Hearth.partsIn(bucket("Water", { Water = 8, CowMilk = 2 })) == nil)
Fluid = savedFluid

local savedFluid = Fluid
Fluid = {}
local function colour(r, g, b) return { getRedFloat = function() return r end, getGreenFloat = function() return g end, getBlueFloat = function() return b end } end
Fluid.Get = function(name)
    local c = ({ TestRed = colour(1, 0, 0), TestBlue = colour(0, 0, 1) })[name]
    return c and { getColor = function() return c end }
end
local mixed = Hearth.liquidColour({ ml = 1000, fluid = "TestRed", parts = { TestRed = 3, TestBlue = 1 } })
check("a blend's colour is its fluids' mixed by their shares", near(mixed[1], 0.75) and mixed[2] == 0 and near(mixed[3], 0.25))
Fluid = savedFluid

-- The Stone Hearth with nothing fitted (the Firebox)
local fireboxTile = Hearth.fireboxSprite(false, nil, 1)
check("every Stone Hearth tile is known with its facing, apart from the cauldron's", #Hearth.FIREBOX_SPRITES == 6
    and Hearth.fireboxFace(fireboxTile) == 1 and Hearth.face(fireboxTile) == nil and Hearth.fireFace(fireboxTile) == 1
    and Hearth.fireboxFace(Hearth.sprite("Empty", 0)) == nil and Hearth.fireFace(Hearth.sprite("Hot", 1)) == 1
    and #Hearth.FIRE_SPRITES == 18)
check("its tile by hole alone, no flue tiles; open when nothing is in it",
    fireboxTile == "traditionalpreservationcore_01_11"
    and Hearth.fireboxSprite(false, "Pot", 0) == "traditionalpreservationcore_01_14"
    and Hearth.fireboxSprite(true, "Lid", 0) == "traditionalpreservationcore_01_12"
    and Hearth.fireboxSprite(true, "Pot", 1) == "traditionalpreservationcore_01_15"
    and Hearth.fireboxSprite(false, "Lid", 0) == "traditionalpreservationcore_01_12")
check("under a connection taking the smoke, the hole is never open: the lid goes on",
    Hearth.fireboxSprite(true, "Open", 0) == Hearth.fireboxSprite(true, "Lid", 0)
    and Hearth.fireboxSprite(true, nil, 1) == "traditionalpreservationcore_01_13")
check("its glow: smoke round the door under the lid, out of the hole when open, round the pot, none once joined, nothing while out",
    Hearth.fireboxGlow(true, false, nil, "Lid", 0) == "traditionalpreservationcore_01_24"
    and Hearth.fireboxGlow(true, false, nil, "Open", 1) == "traditionalpreservationcore_01_47"
    and Hearth.fireboxGlow(true, true, nil, "Pot", 0) == "traditionalpreservationcore_01_52"
    and Hearth.fireboxGlow(true, true, true, "Pot", 1) == "traditionalpreservationcore_01_31"
    and Hearth.fireboxGlow(false, false, nil, "Open", 0) == nil)

-- Stove or oven, and what shows in the hole
local function food(fullType, fluid)
    return { getFullType = function() return fullType end,
        getFluidContainer = function() return fluid and { isEmpty = function() return fluid == 0 end } or nil end }
end
check("vanilla's stews, soups, stir-fries, omelettes, pasta and rice are stove food; anything else is oven food",
    Hearth.cookedOn(food("Base.PotOfStew")) == Hearth.STOVE and Hearth.cookedOn(food("Base.EggOmelette")) == Hearth.STOVE
    and Hearth.cookedOn(food("Base.PanFriedVegetablesForged")) == Hearth.STOVE
    and Hearth.cookedOn(food("Base.WaterPotForgedPasta")) == Hearth.STOVE
    and Hearth.cookedOn(food("Base.RicePanCopper")) == Hearth.STOVE
    and Hearth.cookedOn(food("Base.PieWholeRaw")) == Hearth.OVEN)
Hearth.cooksOn(Hearth.STOVE, "Test.PotOfThing")
check("a mod names its own stove food", Hearth.cookedOn(food("Test.PotOfThing")) == Hearth.STOVE)
check("empty, the hole is open", Hearth.holeLook(H.list({})) == Hearth.OPEN and Hearth.holeLook(nil) == Hearth.OPEN)
check("oven food only: the lid", Hearth.holeLook(H.list({ food("Base.PieWholeRaw"), food("Base.Bread") })) == Hearth.LID)
check("an empty pot is oven gear too", Hearth.holeLook(H.list({ food("Base.Pot", 0) })) == Hearth.LID)
check("any stove food or fluid wins: the pot", Hearth.holeLook(H.list({ food("Base.PieWholeRaw"), food("Base.PotOfSoup") })) == Hearth.POT
    and Hearth.holeLook(H.list({ food("Base.Bread"), food("Base.Pot", 2) })) == Hearth.POT)
-- Connections (Hearth.connect): one at a time, its kind and side under its id.
local trench = { tool = "DIG_GRAVE", items = { { "Base.FlatStone", 3 }, { "Base.Clay", 2 } }, back = "Base.FlatStone" }
local duct = Hearth.connect({ id = "testDuct", kinds = { "Stones" }, kits = { Stones = trench }, blocks = "both" })
check("a connection registers by its id, its fields given later added to it", Hearth.connection("testDuct") == duct
    and Hearth.connect({ id = "testDuct", notes = print }) == duct and duct.notes == print and duct.blocks == "both")
local flue = {}
Hearth.join(flue, "testDuct", "Stones", "Back")
check("joined to a side, its kind and side under its id", Hearth.connectedTo(flue) == "testDuct"
    and flue.testDuct.kind == "Stones" and flue.testDuct.side == "Back" and select(2, Hearth.joinOf(flue)) == "Back")
check("taken up, it says what it was", Hearth.unjoin(flue) == "testDuct" and flue.connected == nil and flue.testDuct == nil
    and Hearth.joinOf(flue) == nil)
Hearth.join(flue, "testDuct", "Stones", "Front")
check("never the door's side: nothing is joined", Hearth.connectedTo(flue) == nil and flue.testDuct == nil)
Hearth.join(flue, "testDuct", "Pipe", "Back")
check("nor by a kit it hasn't got", Hearth.connectedTo(flue) == nil)
Hearth.join(flue, "noSuchThing", "Stones", "Back")
check("nor an unknown connection", Hearth.connectedTo(flue) == nil)
check("Connect's refusals, the first that applies", Hearth.connectRefusalOf({ side = "Back" }) == nil
    and Hearth.connectRefusalOf({ joined = true, own = "X" }) == "IGUI_TraditionalPreservationCore_FlueFireboxJoined"
    and Hearth.connectRefusalOf({ own = "X", burning = true }) == "X"
    and Hearth.connectRefusalOf({ burning = true }) == "IGUI_TraditionalPreservationCore_FlueFireboxDoor"
    and Hearth.connectRefusalOf({ side = "Left", burning = true, fitted = true }) == "IGUI_TraditionalPreservationCore_FireBurning"
    and Hearth.connectRefusalOf({ side = "Left", fitted = true }) == "IGUI_TraditionalPreservationCore_ConnectFitted")
local short, noTool = Hearth.kitMissing(trench, { ["Base.FlatStone"] = 1 }, false)
check("a kit's shortfall and its tool", #short == 2 and short[1][2] == 2 and short[2][2] == 2 and noTool)
local back = Hearth.kitBack(trench)
check("Disconnect gives back only the kit's back items", #back == 1 and back[1][1] == "Base.FlatStone" and back[1][2] == 3)
for face, sides in pairs(require("TraditionalPreservationCore/HearthConnect").FLUE_SIDES) do
    local door = face == 0 and { 0, 1 } or { 1, 0 }
    local ok = true
    for _, step in pairs(sides) do
        if step[1] == door[1] and step[2] == door[2] then ok = false end
    end
    check("facing " .. face .. ": the flue's three sides never include the door's", ok)
end

-- By a fire
local ledger = { temperature = -10, seasonTemperature = -5 }
check("a fire keeps its warmth whatever the weather", Weather.placeTemperature(ledger, Hearth.PLACE) == Hearth.FIRE_C
    and Weather.placeTemperature(ledger, "Open") == -10)
check("banked embers are a cooler place by a fire", Weather.placeTemperature(ledger, Hearth.EMBERS) == Hearth.EMBERS_C
    and Hearth.EMBERS_C < Hearth.FIRE_C and Hearth.isFirePlace(Hearth.EMBERS) and not Hearth.isFirePlace("Open"))
check("a fire in a January field warms the day's air by 10, under an open roof the season's by 15",
    Weather.placeTemperature(ledger, "HearthOpen") == 0 and Weather.placeTemperature(ledger, "HearthCovered") == 10
    and Hearth.isFirePlace("HearthOpen") and Hearth.isFirePlace("EmbersCovered"))
check("banked embers outside add 5 in the open, 10 under a roof", Weather.placeTemperature(ledger, "EmbersOpen") == -5
    and Weather.placeTemperature(ledger, "EmbersCovered") == 5)
local summer = { temperature = 25, seasonTemperature = 22 }
check("never warmer than by a fire indoors", Weather.placeTemperature(summer, "HearthOpen") == Hearth.FIRE_C
    and Weather.placeTemperature(summer, "EmbersCovered") == Hearth.EMBERS_C)
check("fireC: indoors needs no ledger, outside does", Hearth.fireC(Hearth.PLACE) == Hearth.FIRE_C
    and Hearth.fireC("HearthOpen") == nil and Hearth.fireC("HearthOpen", ledger) == 0 and Hearth.fireC("Open", ledger) == nil)
check("firePlace: the fire's own place outside, plain indoors", Hearth.firePlace(Hearth.PLACE, "Open") == "HearthOpen"
    and Hearth.firePlace(Hearth.EMBERS, "Covered") == "EmbersCovered" and Hearth.firePlace(Hearth.PLACE, "Basement") == Hearth.PLACE
    and Hearth.firePlace(Hearth.PLACE, "Loft") == Hearth.PLACE)
local state = {}
Hearth.noteFire(state, nil, nil, 5)
check("no fire, no notes", state.fireUntil == nil and state.under == nil)

-- Catching up by a fire: by the clock at its heat until the fuel ran out, then the place under it by its share.
local half = function(celsius) return celsius >= 20 and 1 or 0.5 end
local kinds = { work = half }
local book = Weather.newLedger(0, kinds)
local marks = Weather.mark({}, book, "work")
for hour = 1, 10 do Weather.advance(book, hour, 0, kinds) end
local byFire = { fireUntil = 4, under = "Sheltered" }
check("by a fire 4 hours at full speed, then 6 in a cold room at half", near(Hearth.catchUp(byFire, marks, book, "work", Hearth.PLACE, half), 4 + 3)
    and marks.hour == 10)
check("a fire still burning counts all of it", near(Hearth.catchUp({ fireUntil = 99 }, Weather.mark({}, book, "work"), book, "work",
    Hearth.PLACE, half), 0))
local away = Weather.mark({}, book, "work")
for hour = 11, 20 do Weather.advance(book, hour, 0, kinds) end
check("away from a fire it is Weather's catch-up", near(Hearth.catchUp({}, away, book, "work", "Open", half), 5))
local field = Weather.mark({}, book, "work")
for hour = 21, 30 do Weather.advance(book, hour, 0, kinds) end
check("by a fire in the open it counts at the air's heat plus the lift", near(Hearth.catchUp({ fireUntil = 99 }, field, book, "work",
    "HearthOpen", half), 5))
local seen = { place = Hearth.PLACE, fireUntil = 22 }
local caught
Hearth.placeOf = function() return "Sheltered" end
Hearth.notePlace(seen, {}, 30, function(s) caught = s.place end)
check("a move catches up at the place it left first", caught == Hearth.PLACE and seen.place == "Sheltered" and seen.fireUntil == nil)

-- Hooks
local function item(heat)
    local modData = {}
    return { getItemHeat = function() return heat end, setItemHeat = function(self, h) heat = h end,
        getModData = function() return modData end, heat = function() return heat end }
end
local plain = item(1)
check("with no hook an item pours at vanilla's heat", Hearth.heatOf(plain, 0) == Hearth.ROOM_C)
Hearth.filledFrom(plain, { ml = 1000, fluid = "Water", tempC = 90 })
check("and a fill sets vanilla's heat to the cauldron's", near(Hearth.heatCelsius(plain.heat()), 90))
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
local saved = Hearth.cauldronState(modData)
Hearth.pourInto(saved, "Water", 1000, 20, 0)
check("the cauldron lives under its id inside one prefixed key", modData.tpHearth.cauldron.ml == 1000 and modData.tpHearth.ml == nil
    and modData.ml == nil and Hearth.cauldronState(modData) == saved)

-- The attachment registry
local first = Hearth.attach({ id = "testPan", look = function() return "Full" end })
local later = Hearth.attach({ id = "testPan", menu = function() end })
check("attaching an id again adds its fields to the one registered", first == later and Hearth.attachment("testPan") == first
    and first.look ~= nil and first.menu ~= nil and first.id == "testPan")
check("each attachment's state is its own", Hearth.partState(modData, "testPan") ~= saved and modData.tpHearth.testPan ~= nil)

-- What register is given (refactoring rule 6): each refusal names the function and what is wrong.
local function refuses(name, fn, ...)
    local ok, err = pcall(fn, ...)
    return not ok and tostring(err):find(name, 1, true) ~= nil
end
check("an attachment needs an id", refuses("Hearth.attach", Hearth.attach, { look = print }))
check("a field already given isn't given again as something else",
    refuses("look is already given", Hearth.attach, { id = "testPan", look = print })
    and Hearth.attach({ id = "testPan", look = first.look }) == first)
check("a fit needs its items", refuses("fit needs items", Hearth.attach, { id = "testPot", fit = { ticks = 1 } }))
check("a connection's kinds come with its kits, a kit for every kind",
    refuses("kinds and kits come together", Hearth.connect, { id = "testHalf", kinds = { "Pipe" } })
    and refuses("no kit for kind Clay", Hearth.connect, { id = "testOdd", kinds = { "Clay" }, kits = { Pipe = {} } }))
check("a hook has a known name and a function", refuses("no hook named heats", Hearth.hook, "heats", print)
    and refuses("needs a function", Hearth.hook, "taken", "print"))
Hearth.blend("TestMilkA", "TestMilkB")
check("a fluid blends in one group only", refuses("TestMilkB is already in a blend", Hearth.blend, "TestMilkB", "TestMilkC"))
Hearth.turnsHot("TestRaw", "TestRendered", 1)
Hearth.goesOff("TestRaw", "TestRancid")
check("a fluid turns and goes off one way only", refuses("already turns", Hearth.turnsHot, "TestRaw", "TestOther", 2)
    and refuses("already goes off", Hearth.goesOff, "TestRaw", "TestOther"))
check("food cooks on the stove or in the oven", refuses("Hearth.cooksOn", Hearth.cooksOn, "grill", "Base.Steak"))
-- The fire's record (Smokehouse 5c)
local fire = {}
Hearth.logFire(fire, 10, Hearth.STOKED, 16)
check("stoking starts a session", fire.session == 10 and Hearth.sessionHours(fire) == 0 and fire.fireId == 10)
Hearth.logFire(fire, 13, Hearth.STOKED, 17)
check("stoked hours count in the session", near(fire.stokedHours, 3) and near(Hearth.sessionHours(fire), 3))
Hearth.logFire(fire, 13.5, nil, nil)
Hearth.logFire(fire, 14.2, Hearth.STOKED, 20)
check("a short gap keeps the session, and doesn't count", fire.session == 10 and near(Hearth.sessionHours(fire), 3.5))
Hearth.logFire(fire, 30, nil, nil)
check("away past the fuel: only the hours it had count", near(fire.stokedHours, 3.5 + 5.8) and fire.session == nil)
check("and the session is over", Hearth.sessionHours(fire) == 0)
Hearth.logFire(fire, 31, Hearth.STOKED, 35)
check("stoking again starts a new session", fire.session == 31 and fire.sessionBase == fire.stokedHours)
Hearth.logFire(fire, 32, Hearth.BANKED, 50)
Hearth.logFire(fire, 40, Hearth.BANKED, 50)
check("banked hours count apart", near(fire.bankedHours, 8) and near(fire.stokedHours, 3.5 + 5.8 + 1))
check("banked more than the grace ends the session", fire.session == nil)
Hearth.logFire(fire, 41, Hearth.BANKED, 50)
check("banking never starts one", fire.session == nil and fire.fireId == 10)
H.done()
