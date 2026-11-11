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
getSprite = function(name) return { getName = function() return name end } end

local square = { getX = function() return 5 end, getY = function() return 6 end, getZ = function() return 0 end,
    isOutside = function() return false end }
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
function fire:setOverlaySprite(name) self.overlay = name and getSprite(name) end

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
check("the fire mouth glows banked", fire.overlay:getName() == Hearth.glowSprite(true, true, 0))
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
check("the fire mouth glows lit", fire.overlay:getName() == Hearth.glowSprite(true, false, 0))

World.setFire(fire, "bank", 101)
World.setFire(fire, "out", 101.5)
check("put out while banked, it is out with its fuel, nothing of the embers left", not fire:isLit() and not Hearth.isBurning(fire)
    and fire.fuel == 90 and count(cell.heat) == 0 and container.custom == 0 and fire.overlay == nil)

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

H.done()
