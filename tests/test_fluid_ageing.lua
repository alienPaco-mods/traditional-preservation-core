-- Checks fluid ageing (FluidAgeing) on stand-ins for the engine. Run from TraditionalPreservationCore: luajit tests/test_fluid_ageing.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near
package.path = "42/media/lua/shared/?.lua;" .. package.path

Fluid = { Get = function(name) return { name = name } end }
instanceof = function(o, class) return type(o) == "table" and o.class == class end
ModData = { getOrCreate = function() return {} end }

local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"

-- A ledger the test moves by hand: hours of work at each place.
local ledger = { milkOpen = 0, milkSheltered = 0, milkBasement = 0 }
local function pass(place, work)
    ledger["milk" .. place] = ledger["milk" .. place] + work
end

local on, speed = true, 1
local spec = FluidAgeing.register({
    kind = "milk",
    rate = function(celsius) return celsius <= 0 and 0 or celsius / 20 end,
    turnHours = 36,
    spoilHours = 72,
    fresh = { CowMilk = "SourCowMilk", SheepMilk = "SourSheepMilk" },
    spoiled = { CowMilk = "RottenCowMilk", SheepMilk = "RottenSheepMilk" },
    scalded = { CowMilk = "ScaldedCowMilk", SheepMilk = "ScaldedSheepMilk" },
    sealed = { ["Base.Milk"] = true },
    getLedger = function() return ledger end,
    enabled = function() return on end,
    speed = function() return speed end,
})

-- A fluid container: litres by name.
local function container(fluids)
    local c = { fluids = fluids or {} }
    function c:getSpecificFluidAmount(fluid) return self.fluids[fluid.name] or 0 end
    function c:adjustSpecificFluidAmount(fluid, amount) self.fluids[fluid.name] = amount > 0 and amount or nil end
    function c:addFluid(name, amount) self.fluids[name] = (self.fluids[name] or 0) + amount end
    function c:isEmpty() return next(self.fluids) == nil end
    return c
end

local function item(fluids, fullType)
    local o = { class = "InventoryItem", fc = container(fluids), md = {}, fullType = fullType or "Base.Bucket" }
    function o:getFluidContainer() return self.fc end
    function o:getModData() return self.md end
    function o:getFullType() return self.fullType end
    function o:getOutermostContainer() return nil end
    function o:getWorldItem() return nil end
    return o
end

-- Stages
check("fresh milk is fresh", FluidAgeing.stage({ age = 35 }, spec) == "Fresh")
check("raw milk turns at 36", FluidAgeing.stage({ age = 36 }, spec) == "Turned")
check("and spoils at 72", FluidAgeing.stage({ age = 72 }, spec) == "Spoiled")
check("scalded milk never turns", FluidAgeing.stage({ age = 50, scalded = true }, spec) == "Fresh")
check("but spoils at the same age", FluidAgeing.stage({ age = 72, scalded = true }, spec) == "Spoiled")
check("hours left: to souring when raw", FluidAgeing.hoursLeft({ age = 30 }, spec) == 6)
check("to spoiling when scalded", FluidAgeing.hoursLeft({ age = 30, scalded = true }, spec) == 42)

-- Catching up by place
local record = FluidAgeing.newRecord(spec, ledger, 0, "Basement")
pass("Basement", 10)
pass("Open", 99)
FluidAgeing.advance(record, spec, ledger, 10, "Sheltered")
check("time since the last look counts where it was seen", near(record.age, 10) and record.place == "Sheltered")
pass("Basement", 50)
pass("Sheltered", 5)
FluidAgeing.advance(record, spec, ledger, 20, "Fridge")
check("then where it has been since", near(record.age, 15))
FluidAgeing.advance(record, spec, ledger, 30, "Freezer")
check("a fridge counts by the clock at its cold", near(record.age, 15 + 10 * 4 / 20))
pass("Sheltered", 100)
FluidAgeing.advance(record, spec, ledger, 500, "Sheltered")
check("a freezer stops it", near(record.age, 17))
speed = 2
pass("Sheltered", 3)
FluidAgeing.advance(record, spec, ledger, 503, "Sheltered")
check("the sandbox speed multiplies the work", near(record.age, 23))
speed = 1

-- Mixing
check("the older age wins", FluidAgeing.merge({ age = 5 }, { age = 40 }).age == 40)
check("raw milk makes scalded raw", FluidAgeing.merge({ age = 5, scalded = true }, { age = 1 }).scalded == nil)
check("scalded into scalded stays scalded", FluidAgeing.merge({ age = 5, scalded = true }, { age = 1, scalded = true }).scalded)

-- Looking: records, swaps
local bucket = item({ CowMilk = 3, SheepMilk = 1 })
local r = FluidAgeing.look(bucket, 0, "Sheltered")
check("milk seen for the first time starts fresh", r and r.age == 0 and bucket.md.tpFluidAge == r)
pass("Sheltered", 36)
FluidAgeing.look(bucket, 36, "Sheltered")
check("turned, each milk becomes its sour twin", bucket.fc.fluids.SourCowMilk == 3 and bucket.fc.fluids.SourSheepMilk == 1
    and bucket.fc.fluids.CowMilk == nil and bucket.fc.fluids.SheepMilk == nil)
bucket.fc.fluids.CowMilk = 1
FluidAgeing.look(bucket, 36, "Sheltered")
check("fresh milk poured onto sour sours too", bucket.fc.fluids.CowMilk == nil and bucket.fc.fluids.SourCowMilk == 4)
pass("Sheltered", 36)
FluidAgeing.look(bucket, 72, "Sheltered")
check("spoiled, each milk is its own rotten one", bucket.fc.fluids.RottenCowMilk == 4 and bucket.fc.fluids.RottenSheepMilk == 1
    and bucket.fc.fluids.SourCowMilk == nil
    and bucket.fc.fluids.SourSheepMilk == nil)
bucket.fc.fluids = { Water = 1 }
check("a container with no milk loses its record", FluidAgeing.look(bucket, 72) == nil and bucket.md.tpFluidAge == nil)

local water = item({ Water = 2 })
check("other fluids are left alone", FluidAgeing.look(water, 0) == nil and water.md.tpFluidAge == nil)

on = false
local off = item({ CowMilk = 1 })
check("switched off, nothing is recorded", FluidAgeing.look(off, 0) == nil and off.md.tpFluidAge == nil)
on = true

-- Store milk
local carton = item({ CowMilk = 1 }, "Base.Milk")
check("a sealed carton keeps with no record", FluidAgeing.look(carton, 0) == nil and carton.md.tpFluidAge == nil)
local jug = item({})
FluidAgeing.pour(carton, jug, 0)
check("poured out, store milk counts as scalded", jug.md.tpFluidAge and jug.md.tpFluidAge.scalded and jug.md.tpFluidAge.age == 0)
local old = item({ CowMilk = 1 })
old.md.tpFluidAge = { kind = "milk", age = 20, place = "Sheltered", hour = 0, marks = { Sheltered = ledger.milkSheltered } }
FluidAgeing.pour(old, carton, 0)
check("raw milk poured into a carton ages there", carton.md.tpFluidAge and carton.md.tpFluidAge.age == 20 and not carton.md.tpFluidAge.scalded)

-- Pouring
local empty = item({})
FluidAgeing.pour(old, empty, 0)
check("an empty container takes the source's age", empty.md.tpFluidAge.age == 20 and empty.md.tpFluidAge ~= old.md.tpFluidAge)
local young = item({ CowMilk = 1 })
young.md.tpFluidAge = { kind = "milk", age = 2, place = "Sheltered", hour = 0, marks = { Sheltered = ledger.milkSheltered } }
FluidAgeing.pour(young, old, 0)
check("pouring young into old keeps the old age", old.md.tpFluidAge.age == 20)
FluidAgeing.pour(old, young, 0)
check("pouring old into young makes it old", young.md.tpFluidAge.age == 20)
local waterJug = item({ Water = 1 })
waterJug.md.tpFluidAge = { kind = "milk", age = 60 }
FluidAgeing.pour(old, waterJug, 0)
check("a stale record on a container with no milk is replaced", waterJug.md.tpFluidAge.age == 20)

-- Milking, the cauldron
local drunk = item({})
drunk.md.tpFluidAge = { kind = "milk", age = 50 }
FluidAgeing.clearIfEmpty(drunk)
check("a container emptied of milk forgets its age before milking", drunk.md.tpFluidAge == nil)
local cauldron = { ml = 2000 }
FluidAgeing.receive(cauldron, { kind = "milk", age = 12, marks = {} }, false, "Sheltered")
local out = FluidAgeing.cauldronRecord(cauldron, 0, "Sheltered")
check("the cauldron keeps the age of what was poured in", out and out.age == 12 and out ~= cauldron.tpFluidAge)
FluidAgeing.receive(cauldron, { kind = "milk", age = 3, marks = {} }, true, "Sheltered")
check("and the older age when more is poured onto it", cauldron.tpFluidAge.age == 12)
local pail = item({ CowMilk = 1 })
FluidAgeing.receive(pail:getModData(), out, false, "Sheltered")
FluidAgeing.markScalded(pail, 0)
check("drawn steaming, it is scalded, and renamed so", pail.md.tpFluidAge.scalded and pail.md.tpFluidAge.age == 12
    and pail.fc.fluids.ScaldedCowMilk == 1 and pail.fc.fluids.CowMilk == nil)
check("an empty cauldron has no age to give", FluidAgeing.cauldronRecord({ ml = 0, tpFluidAge = { kind = "milk", age = 1 } }, 0, "Open") == nil)

-- Scalded milk in containers
local jar = item({ ScaldedCowMilk = 1 })
check("scalded milk seen for the first time is scalded", FluidAgeing.look(jar, 0).scalded and jar.fc.fluids.ScaldedCowMilk == 1)
local mixed = item({ ScaldedCowMilk = 1, CowMilk = 0.5 })
mixed.md.tpFluidAge = { kind = "milk", age = 4, place = "Sheltered", marks = { Sheltered = ledger.milkSheltered } }
FluidAgeing.look(mixed, 0, "Sheltered")
check("with raw milk in it, scalded is plain milk again", mixed.fc.fluids.CowMilk == 1.5 and mixed.fc.fluids.ScaldedCowMilk == nil)
local turned = item({ ScaldedSheepMilk = 1 })
turned.md.tpFluidAge = { kind = "milk", age = 40, place = "Sheltered", marks = { Sheltered = ledger.milkSheltered } }
FluidAgeing.look(turned, 0, "Sheltered")
check("raw again past souring age, it sours", turned.fc.fluids.SourSheepMilk == 1)
local storeJug = item({ CowMilk = 1 })
storeJug.md.tpFluidAge = { kind = "milk", age = 0, scalded = true, place = "Sheltered", marks = { Sheltered = ledger.milkSheltered } }
FluidAgeing.look(storeJug, 0, "Sheltered")
check("store milk poured out is scalded", storeJug.fc.fluids.ScaldedCowMilk == 1)
check("nameAt: rotten stays rotten", FluidAgeing.nameAt(spec, "Fresh", "RottenCowMilk", true) == "RottenCowMilk")
check("nameAt: soured is never scalded", FluidAgeing.nameAt(spec, "Fresh", "SourCowMilk", true) == "SourCowMilk")

-- Scalding on a stove or a fire: the item's own heat
spec.scaldHeat = 1.5
check("the lowest scalding heat is worked out at register", FluidAgeing.lowestScaldHeat() == nil
    and FluidAgeing.register(spec) and FluidAgeing.lowestScaldHeat() == 1.5)
local onStove = item({ CowMilk = 2 })
onStove.heat = 1.6
function onStove:getItemHeat() return self.heat end
check("milk first seen on the heat is scalded", FluidAgeing.look(onStove, 0, "Sheltered").scalded and onStove.fc.fluids.ScaldedCowMilk == 2)
local warming = item({ SheepMilk = 1 })
warming.heat = 1.2
function warming:getItemHeat() return self.heat end
FluidAgeing.look(warming, 0, "Sheltered")
check("warm is not enough", not warming.md.tpFluidAge.scalded and warming.fc.fluids.SheepMilk == 1)
warming.heat = 1.55
FluidAgeing.look(warming, 0, "Sheltered")
check("brought to the steam later, it scalds", warming.md.tpFluidAge.scalded and warming.fc.fluids.ScaldedSheepMilk == 1)
local soured = item({ SourCowMilk = 1 })
soured.md.tpFluidAge = { kind = "milk", age = 40, place = "Sheltered", marks = { Sheltered = ledger.milkSheltered } }
soured.heat = 2
function soured:getItemHeat() return self.heat end
FluidAgeing.look(soured, 0, "Sheltered")
check("soured milk boiled stays soured", soured.fc.fluids.SourCowMilk == 1 and not soured.md.tpFluidAge.scalded)
spec.scaldHeat = nil

-- Milk left in the cauldron turns there too
local cold = { ml = 4000, fluid = "CowMilk", parts = { CowMilk = 3000, SheepMilk = 1000 } }
FluidAgeing.receive(cold, { kind = "milk", age = 30, place = "Sheltered", marks = { Sheltered = ledger.milkSheltered } }, false, "Sheltered")
FluidAgeing.updateCauldron(cold, 0, "Sheltered", 0)
check("fresh milk in a cold cauldron stays milk", cold.fluid == "CowMilk" and cold.parts.SheepMilk == 1000)
pass("Sheltered", 6)
FluidAgeing.updateCauldron(cold, 0, "Sheltered", 0)
check("turned in the cauldron, its milks are renamed to their twins", cold.fluid == "SourCowMilk"
    and cold.parts.SourSheepMilk == 1000 and cold.parts.CowMilk == nil)
pass("Sheltered", 36)
FluidAgeing.updateCauldron(cold, 0, "Sheltered", 0)
check("spoiled in the cauldron, each milk is its own rotten one", cold.fluid == "RottenCowMilk"
    and cold.parts.RottenSheepMilk == 1000 and cold.parts.SourCowMilk == nil)
local plainCauldron = { ml = 1000, fluid = "CowMilk" }
FluidAgeing.receive(plainCauldron, { kind = "milk", age = 40, marks = {} }, false, "Sheltered")
FluidAgeing.updateCauldron(plainCauldron, 0, "Sheltered", 0)
check("one milk alone is renamed too", plainCauldron.fluid == "SourCowMilk")
local hotCauldron = { ml = 1000, fluid = "CowMilk" }
FluidAgeing.receive(hotCauldron, { kind = "milk", age = 30, place = "Sheltered", marks = { Sheltered = ledger.milkSheltered } }, false, "Sheltered")
FluidAgeing.updateCauldron(hotCauldron, 0, "Sheltered", 1)
pass("Sheltered", 10)
FluidAgeing.updateCauldron(hotCauldron, 0, "Sheltered", 0)
check("milk scalded in the cauldron doesn't sour there, and is scalded", hotCauldron.tpFluidAge.scalded
    and hotCauldron.fluid == "ScaldedCowMilk")
check("raw milk poured onto old scalded milk sours it all", (function()
    FluidAgeing.receive(hotCauldron, { kind = "milk", age = 1, marks = {} }, true, "Sheltered")
    hotCauldron.parts = { ScaldedCowMilk = 1000, CowMilk = 500 }
    FluidAgeing.updateCauldron(hotCauldron, 0, "Sheltered", 0)
    return hotCauldron.fluid == "SourCowMilk" and hotCauldron.parts == nil
end)())
local youngCauldron = { ml = 1500, fluid = "ScaldedCowMilk", parts = { ScaldedCowMilk = 1000, CowMilk = 500 } }
FluidAgeing.receive(youngCauldron, { kind = "milk", age = 2, scalded = true, marks = {} }, false, "Sheltered")
FluidAgeing.receive(youngCauldron, { kind = "milk", age = 1, marks = {} }, true, "Sheltered")
FluidAgeing.updateCauldron(youngCauldron, 0, "Sheltered", 0)
check("raw milk poured onto it makes it all plain again", youngCauldron.fluid == "CowMilk" and youngCauldron.parts == nil
    and not youngCauldron.tpFluidAge.scalded)
local blendCauldron = { ml = 2000, fluid = "CowMilk", parts = { CowMilk = 1500, SheepMilk = 500 } }
FluidAgeing.receive(blendCauldron, { kind = "milk", age = 0, marks = {} }, false, "Sheltered")
FluidAgeing.updateCauldron(blendCauldron, 0, "Sheltered", 1)
check("a steaming blend scalds each milk", blendCauldron.fluid == "ScaldedCowMilk" and blendCauldron.parts.ScaldedSheepMilk == 500)
pass("Sheltered", 80)
FluidAgeing.updateCauldron(blendCauldron, 0, "Sheltered", 0)
check("and scalded milk spoils to its own milk's rotten one", blendCauldron.fluid == "RottenCowMilk"
    and blendCauldron.parts.RottenSheepMilk == 500)
local cooled = { ml = 1000, fluid = "ScaldedCowMilk" }
FluidAgeing.receive(cooled, { kind = "milk", age = 2, scalded = true, place = "Sheltered", marks = { Sheltered = ledger.milkSheltered } }, false, "Sheltered")
FluidAgeing.updateCauldron(cooled, 0, "Sheltered", 0)
check("cooled, scalded milk stays scalded", cooled.fluid == "ScaldedCowMilk")
local debugCauldron = { ml = 5000, fluid = "CowMilk" }
FluidAgeing.updateCauldron(debugCauldron, 0, "Sheltered", 1)
check("milk in a cauldron with no record starts one, and scalds", debugCauldron.tpFluidAge and debugCauldron.tpFluidAge.age == 0
    and debugCauldron.fluid == "ScaldedCowMilk")
local waterCauldron = { ml = 5000, fluid = "Water" }
check("water in the cauldron gets no record", FluidAgeing.updateCauldron(waterCauldron, 0, "Sheltered", 1) == nil
    and waterCauldron.tpFluidAge == nil)
local drained = { ml = 0, tpFluidAge = { kind = "milk", age = 5 } }
FluidAgeing.updateCauldron(drained, 0, "Sheltered", 0)
check("an emptied cauldron forgets the age", drained.tpFluidAge == nil)

-- A hold at the heat (scaldHold): Dairy's 20 minutes at 85 C
spec.scaldHold = 1 / 3
local heldCauldron = { ml = 1000, fluid = "CowMilk" }
FluidAgeing.updateCauldron(heldCauldron, 0, "Sheltered", 0.2)
check("steaming 12 minutes is not yet scalded", not heldCauldron.tpFluidAge.scalded and heldCauldron.fluid == "CowMilk")
FluidAgeing.updateCauldron(heldCauldron, 0, "Sheltered", 1 / 3)
check("20 minutes at the steam scalds it", heldCauldron.tpFluidAge.scalded and heldCauldron.fluid == "ScaldedCowMilk")
check("a copy taken before the hold is not scalded", not FluidAgeing.cauldronRecord({ ml = 500, fluid = "CowMilk" }, 0, "Sheltered", 0.1).scalded)
spec.scaldHeat = 1.5
local pot = item({ CowMilk = 2 })
pot.heat = 1.6
function pot:getItemHeat() return self.heat end
FluidAgeing.look(pot, 10, "Sheltered")
check("a pot first seen on the heat starts its hold, not scalded", not pot.md.tpFluidAge.scalded and pot.fc.fluids.CowMilk == 2
    and FluidAgeing.heldHours(pot) > 0)
FluidAgeing.look(pot, 10.2, "Sheltered")
check("12 minutes on, still not", not pot.md.tpFluidAge.scalded and math.abs(FluidAgeing.heldHours(pot) - 0.2) < 1e-4)
pot.heat = 1.2
FluidAgeing.look(pot, 10.5, "Sheltered")
check("off the heat, the hold stops counting", math.abs(FluidAgeing.heldHours(pot) - 0.2) < 1e-4)
pot.heat = 1.6
FluidAgeing.look(pot, 11, "Sheltered")
FluidAgeing.look(pot, 11.14, "Sheltered")
check("back on, the hours add up, and at 20 minutes in all it scalds", pot.md.tpFluidAge.scalded and pot.fc.fluids.ScaldedCowMilk == 2)
local topped = item({ CowMilk = 1 })
topped.md.tpHeldHot = { hours = 0.3 }
FluidAgeing.receive(topped:getModData(), { kind = "milk", age = 1, marks = {} }, true, "Sheltered")
check("raw milk poured in starts the hold over", topped.md.tpHeldHot == nil)
on = false
local offPot = item({ CowMilk = 1 })
offPot.heat = 1.6
function offPot:getItemHeat() return self.heat end
FluidAgeing.look(offPot, 20, "Sheltered")
FluidAgeing.look(offPot, 20.5, "Sheltered")
check("with ageing off the hold still counts (no record)", offPot.md.tpFluidAge == nil and math.abs(FluidAgeing.heldHours(offPot) - 0.5) < 1e-4)
on = true
spec.scaldHeat, spec.scaldHold = nil, nil

-- Treatments (Fish & Meat's blood): states with their own names and spoiling.
local bloodLedger = { bloodOpen = 0, bloodSheltered = 0 }
local blood = FluidAgeing.register({
    kind = "blood",
    rate = function() return 1 end,
    turnHours = math.huge,
    spoilHours = 24,
    fresh = { AnimalBlood = "AnimalBlood" },
    spoiled = { AnimalBlood = "SpoiledBlood" },
    states = {
        Salted = { fluids = { AnimalBlood = "SaltedBlood" }, spoilHours = 72 },
        Vinegared = { fluids = { AnimalBlood = "VinegaredBlood" }, spoilHours = 72 },
        Cured = { fluids = { AnimalBlood = "CuredBlood" }, spoilHours = 96, of = { "Salted", "Vinegared" } },
    },
    getLedger = function() return bloodLedger end,
})
check("fresh blood spoils at 24", FluidAgeing.stage({ age = 24 }, blood) == "Spoiled"
    and FluidAgeing.hoursLeft({ age = 20 }, blood) == 4)
check("salted blood keeps to 72", FluidAgeing.stage({ age = 50, treated = { Salted = true } }, blood) == "Fresh"
    and FluidAgeing.hoursLeft({ age = 50, treated = { Salted = true } }, blood) == 22)
check("both treatments are Cured", FluidAgeing.state({ treated = { Vinegared = true, Salted = true } }, blood).name == "Cured"
    and FluidAgeing.spoilHours({ treated = { Vinegared = true, Salted = true } }, blood) == 96)
local pail = item({ AnimalBlood = 2 })
FluidAgeing.look(pail, 0, "Sheltered")
check("salting renames the blood", FluidAgeing.treat(pail, 0, "Salted") and pail.fc.fluids.SaltedBlood == 2
    and pail.fc.fluids.AnimalBlood == nil)
FluidAgeing.treat(pail, 0, "Vinegared")
check("vinegar on salted blood cures it", pail.fc.fluids.CuredBlood == 2 and pail.fc.fluids.SaltedBlood == nil)
local cup = item({})
FluidAgeing.pour(pail, cup, 0)
cup.fc.fluids.CuredBlood = 1
FluidAgeing.look(cup, 0, "Sheltered")
check("poured, the blood stays cured", cup.md.tpFluidAge.treated.Salted and cup.md.tpFluidAge.treated.Vinegared
    and cup.fc.fluids.CuredBlood == 1)
local salted = item({ SaltedBlood = 1 })
check("salted blood seen for the first time is salted", FluidAgeing.look(salted, 0, "Sheltered").treated.Salted
    and not salted.md.tpFluidAge.scalded and salted.fc.fluids.SaltedBlood == 1)
local vinegared = item({ VinegaredBlood = 1 })
FluidAgeing.look(vinegared, 0, "Sheltered")
FluidAgeing.pour(vinegared, salted, 0)
salted.fc.fluids.VinegaredBlood = 1
FluidAgeing.look(salted, 0, "Sheltered")
check("salted and vinegared mixed keep neither", salted.md.tpFluidAge.treated == nil and salted.fc.fluids.AnimalBlood == 2)
local mixed = item({ AnimalBlood = 1, SaltedBlood = 1 })
check("a fresh share makes a new record untreated", FluidAgeing.look(mixed, 0, "Sheltered").treated == nil
    and mixed.fc.fluids.AnimalBlood == 2)
-- First seen with spoiled blood in it, salted blood is salted whichever fluid comes first. pairs is swapped for the
-- one look so the fluids found come in the order given.
for _, order in ipairs({ { "SaltedBlood", "SpoiledBlood" }, { "SpoiledBlood", "SaltedBlood" } }) do
    local both = item({ SaltedBlood = 1, SpoiledBlood = 1 })
    local realPairs = pairs
    pairs = function(t)
        if rawget(t, "SaltedBlood") == 1 and rawget(t, "SpoiledBlood") == 1 and t ~= both.fc.fluids then
            local i = 0
            return function() i = i + 1 if order[i] then return order[i], t[order[i]] end end
        end
        return realPairs(t)
    end
    local record = FluidAgeing.look(both, 0, "Sheltered")
    pairs = realPairs
    check("salted and spoiled blood, " .. order[1] .. " first: salted", record.treated and record.treated.Salted)
end
local gathered = item({ SaltedBlood = 1 })
FluidAgeing.look(gathered, 0, "Sheltered")
gathered.fc.fluids.AnimalBlood = 1
FluidAgeing.untreat(gathered, 0)
check("untreat: blood gathered in makes it all fresh", gathered.fc.fluids.AnimalBlood == 2 and gathered.md.tpFluidAge.treated == nil)
local old = item({ SaltedBlood = 1 })
FluidAgeing.look(old, 0, "Sheltered")
bloodLedger.bloodSheltered = 80
FluidAgeing.look(old, 80, "Sheltered")
check("salted blood spoils at 72", old.fc.fluids.SpoiledBlood == 1 and not FluidAgeing.treat(old, 80, "Vinegared"))
-- A state with its own cold curve ages on its own ledger kind.
local cold = FluidAgeing.register({
    kind = "cold", rate = function(c) return c >= 20 and 1 or 0.25 end, turnHours = math.huge, spoilHours = 24,
    fresh = { Gore = "Gore" }, spoiled = { Gore = "RottenGore" },
    states = { Kept = { fluids = { Gore = "KeptGore" }, spoilHours = 72, kind = "coldKept",
        rate = function(c) return c >= 20 and 1 or 0.5 end } },
    getLedger = function() return bloodLedger end,
})
bloodLedger.coldSheltered, bloodLedger.coldKeptSheltered = 0, 0
local jar = item({ Gore = 1 })
FluidAgeing.look(jar, 0, "Sheltered")
bloodLedger.coldSheltered, bloodLedger.coldKeptSheltered = 10, 4
FluidAgeing.look(jar, 0, "Sheltered")
check("untreated ages on the kind's totals", jar.md.tpFluidAge.age == 10)
FluidAgeing.treat(jar, 0, "Kept")
bloodLedger.coldSheltered, bloodLedger.coldKeptSheltered = 30, 9
FluidAgeing.look(jar, 0, "Sheltered")
check("the change of state loses one stretch, then marks the state's kind", jar.md.tpFluidAge.age == 10
    and jar.md.tpFluidAge.markKind == "coldKept")
bloodLedger.coldSheltered, bloodLedger.coldKeptSheltered = 50, 15
FluidAgeing.look(jar, 0, "Sheltered")
check("treated, it ages on the state's totals", jar.md.tpFluidAge.age == 16)
jar.md.tpFluidAge.place, jar.md.tpFluidAge.hour = FluidAgeing.FRIDGE, 0
FluidAgeing.look(jar, 10, "Sheltered")
check("in a fridge, by the state's curve", jar.md.tpFluidAge.age == 16 + 10 * 0.5)
check("nameAt with no state is unchanged for milk", FluidAgeing.nameAt(spec, "Fresh", "CowMilk", true) == "ScaldedCowMilk")

-- register checks what it is given.
local function refused(bad, says)
    local ok, err = pcall(FluidAgeing.register, bad)
    return not ok and tostring(err):find(says, 1, true) ~= nil
end
local function base(kind)
    return { kind = kind, rate = function() return 1 end, turnHours = 1, spoilHours = 2,
        fresh = { Ooze = "SourOoze" }, spoiled = { Ooze = "RottenOoze" }, getLedger = function() return ledger end }
end
local noLedger = base("ooze")
noLedger.getLedger = nil
check("a spec with no ledger is refused, by name", refused(noLedger, "ooze has no getLedger"))
local noSpoiled = base("ooze")
noSpoiled.spoiled = {}
check("a fresh fluid with no spoiled one is refused", refused(noSpoiled, "ooze has no spoiled fluid for Ooze"))
local thief = base("thief")
thief.fresh, thief.spoiled = { CowMilk = "SourThief" }, { CowMilk = "RottenThief" }
check("a fluid another kind has is refused", refused(thief, "thief claims CowMilk, already milk"))
local twice = base("twice")
twice.states = { A = { fluids = { Ooze = "AOoze" }, spoilHours = 3, of = { "X" } },
    B = { fluids = { Ooze = "BOoze" }, spoilHours = 3, of = { "X" } } }
check("two states done by the same treatments are refused", refused(twice, "twice has two states done by X"))
check("registering a kind again is allowed", FluidAgeing.register(base("again")) and FluidAgeing.register(base("again")))

-- Each fluid is looked up in the engine once, not on every look.
local gets, realGet = 0, Fluid.Get
Fluid.Get = function(name) gets = gets + 1 return realGet(name) end
local counted = FluidAgeing.register({ kind = "counted", rate = function() return 1 end, turnHours = 5, spoilHours = 9,
    fresh = { Brew = "SourBrew" }, spoiled = { Brew = "FlatBrew" }, getLedger = function() return ledger end })
local keg = item({ Brew = 1 })
for _ = 1, 5 do FluidAgeing.amounts(keg.fc, counted) end
check("fluids are looked up once each", gets == 3)
Fluid.Get = realGet

H.done()
