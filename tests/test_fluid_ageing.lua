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
check("steamed milk never turns", FluidAgeing.stage({ age = 50, steamed = true }, spec) == "Fresh")
check("but spoils at the same age", FluidAgeing.stage({ age = 72, steamed = true }, spec) == "Spoiled")
check("hours left: to souring when raw", FluidAgeing.hoursLeft({ age = 30 }, spec) == 6)
check("to spoiling when steamed", FluidAgeing.hoursLeft({ age = 30, steamed = true }, spec) == 42)

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
check("raw milk makes steamed raw", FluidAgeing.merge({ age = 5, steamed = true }, { age = 1 }).steamed == nil)
check("steamed into steamed stays steamed", FluidAgeing.merge({ age = 5, steamed = true }, { age = 1, steamed = true }).steamed)

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
check("poured out, store milk counts as steamed", jug.md.tpFluidAge and jug.md.tpFluidAge.steamed and jug.md.tpFluidAge.age == 0)
local old = item({ CowMilk = 1 })
old.md.tpFluidAge = { kind = "milk", age = 20, place = "Sheltered", hour = 0, marks = { Sheltered = ledger.milkSheltered } }
FluidAgeing.pour(old, carton, 0)
check("raw milk poured into a carton ages there", carton.md.tpFluidAge and carton.md.tpFluidAge.age == 20 and not carton.md.tpFluidAge.steamed)

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

-- Milking, the copper
local drunk = item({})
drunk.md.tpFluidAge = { kind = "milk", age = 50 }
FluidAgeing.clearIfEmpty(drunk)
check("a container emptied of milk forgets its age before milking", drunk.md.tpFluidAge == nil)
local copper = { ml = 2000 }
FluidAgeing.receive(copper, { kind = "milk", age = 12, marks = {} }, false, "Sheltered")
local out = FluidAgeing.copperRecord(copper, 0, "Sheltered")
check("the copper keeps the age of what was poured in", out and out.age == 12 and out ~= copper.tpFluidAge)
FluidAgeing.receive(copper, { kind = "milk", age = 3, marks = {} }, true, "Sheltered")
check("and the older age when more is poured onto it", copper.tpFluidAge.age == 12)
local pail = item({ CowMilk = 1 })
FluidAgeing.receive(pail:getModData(), out, false, "Sheltered")
FluidAgeing.markSteamed(pail, 0)
check("drawn steaming, it is steamed", pail.md.tpFluidAge.steamed and pail.md.tpFluidAge.age == 12)
check("an empty copper has no age to give", FluidAgeing.copperRecord({ ml = 0, tpFluidAge = { kind = "milk", age = 1 } }, 0, "Open") == nil)

-- Milk left in the copper turns there too
local cold = { ml = 4000, fluid = "CowMilk", parts = { CowMilk = 3000, SheepMilk = 1000 } }
FluidAgeing.receive(cold, { kind = "milk", age = 30, place = "Sheltered", marks = { Sheltered = ledger.milkSheltered } }, false, "Sheltered")
FluidAgeing.updateCopper(cold, 0, "Sheltered", false)
check("fresh milk in a cold copper stays milk", cold.fluid == "CowMilk" and cold.parts.SheepMilk == 1000)
pass("Sheltered", 6)
FluidAgeing.updateCopper(cold, 0, "Sheltered", false)
check("turned in the copper, its milks are renamed to their twins", cold.fluid == "SourCowMilk"
    and cold.parts.SourSheepMilk == 1000 and cold.parts.CowMilk == nil)
pass("Sheltered", 36)
FluidAgeing.updateCopper(cold, 0, "Sheltered", false)
check("spoiled in the copper, each milk is its own rotten one", cold.fluid == "RottenCowMilk"
    and cold.parts.RottenSheepMilk == 1000 and cold.parts.SourCowMilk == nil)
local plainCopper = { ml = 1000, fluid = "CowMilk" }
FluidAgeing.receive(plainCopper, { kind = "milk", age = 40, marks = {} }, false, "Sheltered")
FluidAgeing.updateCopper(plainCopper, 0, "Sheltered", false)
check("one milk alone is renamed too", plainCopper.fluid == "SourCowMilk")
local hotCopper = { ml = 1000, fluid = "CowMilk" }
FluidAgeing.receive(hotCopper, { kind = "milk", age = 30, place = "Sheltered", marks = { Sheltered = ledger.milkSheltered } }, false, "Sheltered")
FluidAgeing.updateCopper(hotCopper, 0, "Sheltered", true)
pass("Sheltered", 10)
FluidAgeing.updateCopper(hotCopper, 0, "Sheltered", false)
check("milk steamed in the copper doesn't sour there", hotCopper.tpFluidAge.steamed and hotCopper.fluid == "CowMilk")
local drained = { ml = 0, tpFluidAge = { kind = "milk", age = 5 } }
FluidAgeing.updateCopper(drained, 0, "Sheltered", false)
check("an emptied copper forgets the age", drained.tpFluidAge == nil)

H.done()
