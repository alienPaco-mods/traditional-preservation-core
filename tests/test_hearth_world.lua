-- Checks the banked Hearth in the world with stand-ins for the engine: vanilla's fire out, the mod's own heat,
-- light and hot firebox in its place, the fuel counted by the mod, and all of it undone by stoking, putting the
-- fire out, burning down or the area unloading. Run from TraditionalPreservationCore: luajit tests/test_hearth_world.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near
package.path = "42/media/lua/shared/?.lua;42/media/lua/server/?.lua;" .. package.path
H.installClock(100)
H.installModData()
H.installEvents()
isClient = function() return false end
MapObjects = { OnLoadWithSprite = function() end }
isServer = function() return false end
getNumActivePlayers = function() return 0 end
ArrayList = { new = function() return H.list({}) end }
function instanceof(object, name) return type(object) == "table" and object.class == name end

-- The cell: its squares, heat sources and lampposts.
local cell = { heat = {}, lights = {}, squares = {} }
function cell:getGridSquare(x, y, z) return self.squares[x .. "," .. y .. "," .. z] end
function cell:addHeatSource(source) self.heat[source] = true end
function cell:removeHeatSource(source) self.heat[source] = nil end
function cell:addLamppost(x, y, z, r, g, b, radius)
    local light = { x = x, y = y, z = z, radius = radius }
    self.lights[light] = true
    return light
end
function cell:removeLamppost(light) self.lights[light] = nil end
getCell = function() return cell end
IsoHeatSource = { new = function(x, y, z, radius, celsius) return { x = x, y = y, z = z, radius = radius, celsius = celsius } end }

local function count(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
end

local Hearth = require "TraditionalPreservationCore/Hearth"
local World = require "TraditionalPreservationCore/HearthWorld"
local Smokehouse = require "TraditionalPreservationCore/Smokehouse"
getSprite = function(name) return { getName = function() return name end } end

local square = { getX = function() return 5 end, getY = function() return 6 end, getZ = function() return 0 end,
    isOutside = function() return false end, isInARoom = function() return true end }
cell.squares["5,6,0"] = square
local container = { custom = 0, processed = 0, getItems = function() return H.list({}) end }
function container:getCustomTemperature() return self.custom end
function container:setCustomTemperature(value) self.custom = value end
function container:addItemsToProcessItems() self.processed = self.processed + 1 end
local modData = {}
local fire = { class = "IsoFireplace", lit = true, fuel = 120, sprite = getSprite(Hearth.sprite("Empty", 0)) }
function fire:isLit() return self.lit end
function fire:setLit(lit) self.lit = lit end
function fire:turnOn() self.lit = true end
function fire:hasFuel() return self.fuel > 0 end
function fire:getFuelAmount() return self.fuel end
function fire:setFuelAmount(fuel) self.fuel = fuel end
function fire:getModData() return modData end
function fire:getSquare() return square end
function fire:getX() return 5 end
function fire:getY() return 6 end
function fire:getZ() return 0 end
function fire:getObjectIndex() return 0 end
function fire:getContainer() return container end
function fire:getSprite() return self.sprite end
function fire:setSprite(sprite) self.sprite = sprite end
function fire:getOverlaySprite() return self.overlay end
function fire:setOverlaySprite(name, r, g, b) self.overlay, self.tint = name and getSprite(name), r and { r, g, b } end

World.track(fire)
World.update(fire, 100)
check("a lit Hearth has no embers of its own", count(cell.heat) == 0 and count(cell.lights) == 0 and container.custom == 0)

World.setFire(fire, "bank", 100)
local heat = next(cell.heat)
local light = next(cell.lights)
check("banked, vanilla's fire is out and its fuel kept", not fire:isLit() and fire.fuel == 120 and Hearth.isBanked(fire)
    and Hearth.isBurning(fire))
check("its own heat: two tiles at 25 C, on the Hearth", count(cell.heat) == 1 and heat.radius == Hearth.BANKED_HEAT_RADIUS
    and heat.celsius == Hearth.BANKED_HEAT_C and heat.x == 5 and heat.y == 6)
check("and a faint light", count(cell.lights) == 1 and light.radius == Hearth.BANKED_LIGHT_RADIUS)
check("its firebox kept hot enough to cook", container.custom == Hearth.BANKED_FIREBOX and container.processed == 1)
check("banked, its tile glows dimly; empty, no overlay", fire.sprite:getName() == Hearth.sprite("Empty", 0, true, true)
    and fire.overlay == nil)
check("its fuel burns three times as long", near(modData[Hearth.KEY].fireUntil, 106))

World.update(fire, 101)
check("a refresh adds nothing twice", count(cell.heat) == 1 and count(cell.lights) == 1 and container.processed == 1)
check("an hour banked burns 20 minutes of the count, set on vanilla's fuel", fire.fuel == 100 and not fire:isLit())

local stew = { class = "Food", id = 7, time = 0 }
function stew:isCookable() return true end
function stew:getID() return self.id end
function stew:getCookingTime() return self.time end
function stew:setCookingTime(time) self.time = time end
container.getItems = function() return H.list({ stew }) end
World.update(fire, 101)
local bar = {}
for tick = 1, 6 do
    stew.time = stew.time + 0.3 -- vanilla's tick at full speed
    H.fire("OnTick")
    bar[tick] = stew.time
end
check("a banked firebox's cooking is set back every tick, so the bar climbs smoothly at a third", near(bar[1], 0.1)
    and near(bar[6], 0.6) and bar[3] > bar[2])
container.getItems = function() return H.list({}) end

container.custom = 0 -- not saved by the game: a reload clears it
World.update(fire, 101)
check("the firebox's heat is put back after a reload", container.custom == Hearth.BANKED_FIREBOX)

World.setFire(fire, "stoke", 101)
check("stoked, vanilla's fire burns again, the embers' heat, light and firebox gone", fire:isLit() and not Hearth.isBanked(fire)
    and count(cell.heat) == 0 and count(cell.lights) == 0 and container.custom == 0)
check("lit, its tile glows lit", fire.sprite:getName() == Hearth.sprite("Empty", 0, true, false))

World.setFire(fire, "bank", 101)
World.setFire(fire, "out", 101.5)
check("put out while banked, it is out with its fuel, nothing of the embers left", not fire:isLit() and not Hearth.isBurning(fire)
    and fire.fuel == 90 and count(cell.heat) == 0 and container.custom == 0 and fire.sprite:getName() == Hearth.sprite("Empty", 0))

fire:turnOn()
World.setFire(fire, "bank", 102)
World.update(fire, 106.6)
check("banked until the count runs out, it goes out with no fuel", not Hearth.isBurning(fire) and fire.fuel == 0
    and count(cell.heat) == 0 and container.custom == 0)

fire.fuel = 60
fire:turnOn()
World.setFire(fire, "bank", 107)
cell.squares["5,6,0"] = nil
for _ = 1, 200 do H.fire("OnTick") end
check("its area unloaded, the embers' heat and light are taken away", count(cell.heat) == 0 and count(cell.lights) == 0)

-- The Stone Hearth with nothing fitted (the Firebox): the same fire, no cauldron; its tile follows its flue and hole.
cell.squares["5,6,0"] = square
local boxData = {}
local boxItems = {}
local boxContainer = setmetatable({ getItems = function() return H.list(boxItems) end }, { __index = container })
local box = setmetatable({ lit = true, fuel = 120, sprite = getSprite(Hearth.fireboxSprite(false, nil, 0)) }, { __index = fire })
function box:getModData() return boxData end
function box:getContainer() return boxContainer end
local function food(fullType)
    return { getFullType = function() return fullType end, getFluidContainer = function() return nil end }
end
World.track(box)
World.update(box, 110)
check("a lit Firebox is tracked, open, its smoke out of the hole", box.sprite:getName() == Hearth.fireboxSprite(false, "Open", 0)
    and box.overlay:getName() == Hearth.fireboxGlow(true, false, false, "Open", 0) and boxData[Hearth.KEY].cauldron == nil
    and Hearth.isFirebox(box) and not Hearth.isFitted(box, Hearth.CAULDRON))
boxItems[1] = food("Base.PieWholeRaw")
World.update(box, 110)
check("oven food in it: the lid, the smoke round the door", box.sprite:getName() == Hearth.fireboxSprite(false, "Lid", 0)
    and box.overlay:getName() == Hearth.fireboxGlow(true, false, false, "Lid", 0))
boxItems[2] = food("Base.PotOfStew")
World.update(box, 110)
check("a stew too: the pot", box.sprite:getName() == Hearth.fireboxSprite(false, "Pot", 0)
    and box.overlay:getName() == Hearth.fireboxGlow(true, false, false, "Pot", 0))
World.setFire(box, "bank", 110)
check("it banks as the Hearth does", not box:isLit() and Hearth.isBanked(box) and count(cell.heat) >= 1
    and box.overlay:getName() == Hearth.fireboxGlow(true, true, false, "Pot", 0))
boxItems[2] = nil
Hearth.join(boxData[Hearth.KEY], Smokehouse.ID, "Pipe", "Back")
World.update(box, 111)
check("its flue joined, the lid goes on and the smoke goes up it (the shed draws the pipe)",
    box.sprite:getName() == Hearth.fireboxSprite(true, "Lid", 0)
    and box.overlay:getName() == Hearth.fireboxGlow(true, true, true, "Lid", 0))
boxItems[1] = nil
World.update(box, 111)
check("joined and empty, the lid stays on", box.sprite:getName() == Hearth.fireboxSprite(true, "Lid", 0))
check("and it never grows a cauldron", boxData[Hearth.KEY].cauldron == nil and boxData[Hearth.KEY].ml == nil
    and boxData[Hearth.KEY].attached == nil and Hearth.attachmentOf(box) == nil and Hearth.canRemove(box) == false)
World.setFire(box, "stoke", 111)

-- The cauldron, fitted through the attachment registry
fire.fuel, fire.lit = 600, true
H.setHours(120)
World.setFire(fire, "stoke", 120)
local spec, cauldron = Hearth.attachmentOf(fire)
check("a Hearth's attachment is the cauldron, its state under its id", spec == Hearth.attachment(Hearth.CAULDRON)
    and cauldron == modData[Hearth.KEY].cauldron and spec.heats ~= nil and spec.onFire ~= nil)
check("known by its cauldron tile, it is noted as fitted", modData[Hearth.KEY].attached == Hearth.CAULDRON and Hearth.isFitted(fire, Hearth.CAULDRON)
    and not Hearth.isFirebox(fire))
check("the fire's own state stays outside the cauldron's", modData[Hearth.KEY].fireUntil ~= nil and cauldron.ml == nil)
Hearth.pourInto(cauldron, "Water", 10000, 20, 120)
H.setHours(120.5)
World.update(fire, 120.5)
check("the cauldron heats by the fire through its heats, as the fire was until now, the fire's fields kept the fire's",
    cauldron.tempC > 40 and cauldron.last == 120.5 and cauldron.fireUntil == nil and cauldron.banked == nil)
check("what it holds shows as the overlay, tinted", fire.overlay:getName() == Hearth.liquidOverlay(cauldron, 0)
    and fire.tint ~= nil and fire.tint[1] == 1)
fire.tint = nil
fire.overlay = getSprite(Hearth.liquidOverlay(cauldron, 0))
World.update(fire, 120.5)
check("an overlay already shown is not tinted again", fire.tint == nil)
check("lit, nothing may come off", Hearth.canRemove(fire) == false and select(2, Hearth.canRemove(fire)) == "Burning")
World.setFire(fire, "out", 120.5)
fire.lit = false
check("out, a cauldron holding fluid may not come off", Hearth.canRemove(fire) == false and select(2, Hearth.canRemove(fire)) == "Full")
Hearth.take(cauldron)
check("out and empty, it may", Hearth.canRemove(fire) == true)

-- Two slots: the Cauldron and the Smokehouse's flue go together; Remove leaves the bare Stone Hearth.
local cauldronSpec = Hearth.attachment(Hearth.CAULDRON)
check("fitted, a second fit is refused", Hearth.fitRefusal(fire, cauldronSpec) == "Fitted")
Hearth.join(modData[Hearth.KEY], Smokehouse.ID, "Pipe", "Back")
check("a fitted Hearth's flue can be joined, the cauldron kept", Smokehouse.flueOf(fire) == "Pipe" and Hearth.isFitted(fire, Hearth.CAULDRON))
check("Remove gives the whole kit back", #Hearth.fitBack(cauldronSpec) == 4)
check("taken off, the cauldron's state goes and nothing is fitted", Hearth.unfit(fire) == Hearth.CAULDRON
    and modData[Hearth.KEY].cauldron == nil and modData[Hearth.KEY].attached == false and Hearth.attachmentOf(fire) == nil)
World.update(fire, 121)
check("its cauldron tile turns to the bare Stone Hearth's, the flue still joined", Hearth.isFirebox(fire)
    and fire.sprite:getName() == Hearth.fireboxSprite(true, "Lid", 0) and Smokehouse.flueOf(fire) == "Pipe")
check("the joined flue never blocks the fit", Hearth.fitRefusal(fire, cauldronSpec) == nil)
fire.lit = true
check("but a burning fire does", Hearth.fitRefusal(fire, cauldronSpec) == "Burning")
fire.lit = false
Hearth.connect({ id = "testWall", kinds = { "Pipe" }, kits = { Pipe = Smokehouse.FLUE_KITS.Pipe }, blocks = "both" })
Hearth.join(modData[Hearth.KEY], "testWall", "Pipe", "Back")
check("a connection that blocks both slots refuses the fit", Hearth.fitRefusal(fire, cauldronSpec) == "Blocked")
World.update(fire, 121)
check("a connection that doesn't take the smoke leaves the hole open", fire.sprite:getName() == Hearth.fireboxSprite(false, "Open", 0))
Hearth.join(modData[Hearth.KEY], Smokehouse.ID, "Pipe", "Back")
check("joined again to the Smokehouse, the other is gone", modData[Hearth.KEY].testWall == nil and Smokehouse.flueOf(fire) == "Pipe")
Hearth.fit(fire, Hearth.CAULDRON)
World.update(fire, 121)
check("fitted again, the cauldron's tile, its state empty", Hearth.isFitted(fire, Hearth.CAULDRON) and Hearth.face(fire.sprite:getName()) == 0
    and next(modData[Hearth.KEY].cauldron) == nil)

H.done()
