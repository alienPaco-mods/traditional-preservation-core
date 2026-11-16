-- Checks the banked Stone Hearth in the world with stand-ins for the engine: vanilla's fire out, the mod's own heat,
-- light and hot firebox in its place, the fuel counted by the mod, and all of it undone by stoking, putting the
-- fire out, burning down or the area unloading. Run from TraditionalPreservationCore: luajit tests/test_fire_world.lua
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

local Fire = require "TraditionalPreservationCore/Fire"
local StoneHearth = require "TraditionalPreservationCore/StoneHearth"
local Cauldron = require "TraditionalPreservationCore/Cauldron"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local World = require "TraditionalPreservationCore/FireWorld"
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
local fire = { class = "IsoFireplace", lit = true, fuel = 120, sprite = getSprite(StoneHearth.cauldronSprite("Empty", 0)) }
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
check("a lit Stone Hearth has no embers of its own", count(cell.heat) == 0 and count(cell.lights) == 0 and container.custom == 0)

World.setFire(fire, "bank", 100)
local heat = next(cell.heat)
local light = next(cell.lights)
check("banked, vanilla's fire is out and its fuel kept", not fire:isLit() and fire.fuel == 120 and Fire.isBanked(fire)
    and Fire.isBurning(fire))
check("its own heat: two tiles at 25 C, on the Stone Hearth", count(cell.heat) == 1 and heat.radius == Fire.BANKED_HEAT_RADIUS
    and heat.celsius == Fire.BANKED_HEAT_C and heat.x == 5 and heat.y == 6)
check("and a faint light", count(cell.lights) == 1 and light.radius == Fire.BANKED_LIGHT_RADIUS)
check("its firebox kept hot enough to cook", container.custom == Fire.BANKED_FIREBOX and container.processed == 1)
check("banked, its tile glows dimly; empty, no overlay", fire.sprite:getName() == StoneHearth.cauldronSprite("Empty", 0, true, true)
    and fire.overlay == nil)
check("its fuel burns three times as long", near(modData[Fire.KEY].fireUntil, 106))

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
check("the firebox's heat is put back after a reload", container.custom == Fire.BANKED_FIREBOX)

World.setFire(fire, "stoke", 101)
check("stoked, vanilla's fire burns again, the embers' heat, light and firebox gone", fire:isLit() and not Fire.isBanked(fire)
    and count(cell.heat) == 0 and count(cell.lights) == 0 and container.custom == 0)
check("lit, its tile glows lit", fire.sprite:getName() == StoneHearth.cauldronSprite("Empty", 0, true, false))

World.setFire(fire, "bank", 101)
World.setFire(fire, "out", 101.5)
check("put out while banked, it is out with its fuel, nothing of the embers left", not fire:isLit() and not Fire.isBurning(fire)
    and fire.fuel == 90 and count(cell.heat) == 0 and container.custom == 0 and fire.sprite:getName() == StoneHearth.cauldronSprite("Empty", 0))

fire:turnOn()
World.setFire(fire, "bank", 102)
World.update(fire, 106.6)
check("banked until the count runs out, it goes out with no fuel", not Fire.isBurning(fire) and fire.fuel == 0
    and count(cell.heat) == 0 and container.custom == 0)

fire.fuel = 60
fire:turnOn()
World.setFire(fire, "bank", 107)
cell.squares["5,6,0"] = nil
for _ = 1, 200 do H.fire("OnTick") end
check("its area unloaded, the embers' heat and light are taken away", count(cell.heat) == 0 and count(cell.lights) == 0)

-- The Stone Hearth with nothing fitted (bare): the same fire, no cauldron; its tile follows its flue and hole.
cell.squares["5,6,0"] = square
local boxData = {}
local boxItems = {}
local boxContainer = setmetatable({ getItems = function() return H.list(boxItems) end }, { __index = container })
local box = setmetatable({ lit = true, fuel = 120, sprite = getSprite(StoneHearth.bareSprite(false, nil, 0)) }, { __index = fire })
function box:getModData() return boxData end
function box:getContainer() return boxContainer end
local function food(fullType)
    return { getFullType = function() return fullType end, getFluidContainer = function() return nil end }
end
World.track(box)
World.update(box, 110)
check("a lit Stone Hearth is tracked, open, its smoke out of the hole", box.sprite:getName() == StoneHearth.bareSprite(false, "Open", 0)
    and box.overlay:getName() == StoneHearth.bareGlow(true, false, false, "Open", 0) and boxData[Fire.KEY].cauldron == nil
    and Fire.isBare(box) and not Fire.isFitted(box, Cauldron.ID))
boxItems[1] = food("Base.PieWholeRaw")
World.update(box, 110)
check("oven food in it: the lid, the smoke round the door", box.sprite:getName() == StoneHearth.bareSprite(false, "Lid", 0)
    and box.overlay:getName() == StoneHearth.bareGlow(true, false, false, "Lid", 0))
boxItems[2] = food("Base.PotOfStew")
World.update(box, 110)
check("a stew too: the pot", box.sprite:getName() == StoneHearth.bareSprite(false, "Pot", 0)
    and box.overlay:getName() == StoneHearth.bareGlow(true, false, false, "Pot", 0))
World.setFire(box, "bank", 110)
check("it banks as the Stone Hearth does", not box:isLit() and Fire.isBanked(box) and count(cell.heat) >= 1
    and box.overlay:getName() == StoneHearth.bareGlow(true, true, false, "Pot", 0))
boxItems[2] = nil
Fire.join(boxData[Fire.KEY], Smokehouse.ID, "Pipe", "Back")
World.update(box, 111)
check("its flue joined, the lid goes on and the smoke goes up it (the shed draws the pipe)",
    box.sprite:getName() == StoneHearth.bareSprite(true, "Lid", 0)
    and box.overlay:getName() == StoneHearth.bareGlow(true, true, true, "Lid", 0))
boxItems[1] = nil
World.update(box, 111)
check("joined and empty, the lid stays on", box.sprite:getName() == StoneHearth.bareSprite(true, "Lid", 0))
check("and it never grows a cauldron", boxData[Fire.KEY].cauldron == nil and boxData[Fire.KEY].ml == nil
    and boxData[Fire.KEY].attached == nil and Fire.attachmentOf(box) == nil and Fire.canRemove(box) == false)
World.setFire(box, "stoke", 111)

-- The cauldron, fitted through the attachment registry
fire.fuel, fire.lit = 600, true
H.setHours(120)
World.setFire(fire, "stoke", 120)
local attachment, cauldron = Fire.attachmentOf(fire)
check("a Stone Hearth's attachment is the cauldron, its state under its id", attachment == Fire.attachment(Cauldron.ID)
    and cauldron == modData[Fire.KEY].cauldron and attachment.heats ~= nil and attachment.onFire ~= nil)
check("known by its cauldron tile, it is noted as fitted", modData[Fire.KEY].attached == Cauldron.ID and Fire.isFitted(fire, Cauldron.ID)
    and not Fire.isBare(fire))
check("the fire's own state stays outside the cauldron's", modData[Fire.KEY].fireUntil ~= nil and cauldron.ml == nil)
CauldronFluid.pourInto(cauldron, "Water", 10000, 20, 120)
H.setHours(120.5)
World.update(fire, 120.5)
check("the cauldron heats by the fire through its heats, as the fire was until now, the fire's fields kept the fire's",
    cauldron.tempC > 40 and cauldron.lastHour == 120.5 and cauldron.fireUntil == nil and cauldron.banked == nil)
check("what it holds shows as the overlay, tinted", fire.overlay:getName() == StoneHearth.liquidOverlay(cauldron, 0)
    and fire.tint ~= nil and fire.tint[1] == 1)
fire.tint = nil
fire.overlay = getSprite(StoneHearth.liquidOverlay(cauldron, 0))
World.update(fire, 120.5)
check("an overlay already shown is not tinted again", fire.tint == nil)
local Weather = require "TraditionalPreservationCore/Weather"
local heats, heatsPlace = attachment.heats, nil
attachment.heats = function(...) heatsPlace = select(6, ...) return heats(...) end
World.update(fire, 120.5)
attachment.heats = heats
check("heats is given the place the Stone Hearth stands in", heatsPlace ~= nil and heatsPlace == Weather.placeOf(fire))
-- Kahlua has no weak tables: the tint seen goes with the fire when its area unloads, so it is set again on return.
cell.squares["5,6,0"] = nil
for _ = 1, 200 do H.fire("OnTick") end
cell.squares["5,6,0"] = square
fire.tint = nil
World.update(fire, 120.5)
check("unloaded and back, the overlay is tinted again", fire.tint ~= nil and fire.tint[1] == 1)
check("lit, nothing may come off", Fire.canRemove(fire) == false and select(2, Fire.canRemove(fire)) == "Burning")
World.setFire(fire, "out", 120.5)
fire.lit = false
check("out, a cauldron holding fluid may not come off", Fire.canRemove(fire) == false and select(2, Fire.canRemove(fire)) == "Full")
CauldronFluid.take(cauldron)
check("out and empty, it may", Fire.canRemove(fire) == true)

-- Two slots: the Cauldron and the Smokehouse's flue go together; Remove leaves the bare Stone Hearth.
local cauldronAttachment = Fire.attachment(Cauldron.ID)
check("fitted, a second fit is refused", Fire.fitRefusal(fire, cauldronAttachment) == "Fitted")
Fire.join(modData[Fire.KEY], Smokehouse.ID, "Pipe", "Back")
check("a fitted Stone Hearth's flue can be joined, the cauldron kept", Smokehouse.flueOf(fire) == "Pipe" and Fire.isFitted(fire, Cauldron.ID))
check("Remove gives the whole kit back", #Fire.fitBack(cauldronAttachment) == 4)
check("taken off, the cauldron's state goes and nothing is fitted", Fire.unfit(fire) == Cauldron.ID
    and modData[Fire.KEY].cauldron == nil and modData[Fire.KEY].attached == false and Fire.attachmentOf(fire) == nil)
World.update(fire, 121)
check("its cauldron tile turns to the bare Stone Hearth's, the flue still joined", Fire.isBare(fire)
    and fire.sprite:getName() == StoneHearth.bareSprite(true, "Lid", 0) and Smokehouse.flueOf(fire) == "Pipe")
check("the joined flue never blocks the fit", Fire.fitRefusal(fire, cauldronAttachment) == nil)
fire.lit = true
check("but a burning fire does", Fire.fitRefusal(fire, cauldronAttachment) == "Burning")
fire.lit = false
Fire.connect({ id = "testWall", kitNames = { "Pipe" }, kits = { Pipe = Smokehouse.FLUE_KITS.Pipe }, blocks = "both" })
Fire.join(modData[Fire.KEY], "testWall", "Pipe", "Back")
check("a connection that blocks both slots refuses the fit", Fire.fitRefusal(fire, cauldronAttachment) == "Blocked")
World.update(fire, 121)
check("a connection that doesn't take the smoke leaves the hole open", fire.sprite:getName() == StoneHearth.bareSprite(false, "Open", 0))
Fire.join(modData[Fire.KEY], Smokehouse.ID, "Pipe", "Back")
check("joined again to the Smokehouse, the other is gone", modData[Fire.KEY].testWall == nil and Smokehouse.flueOf(fire) == "Pipe")
Fire.fit(fire, Cauldron.ID)
World.update(fire, 121)
check("fitted again, the cauldron's tile, its state empty", Fire.isFitted(fire, Cauldron.ID) and StoneHearth.cauldronFace(fire.sprite:getName()) == 0
    and next(modData[Fire.KEY].cauldron) == nil)

H.done()
