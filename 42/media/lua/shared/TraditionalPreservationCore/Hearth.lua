-- Traditional Preservation core: the Hearth, a low stone oven with a copper set in its top, shared by every TP mod.
-- The built tile is swapped for a vanilla fireplace, as the Barrel Oven's is (BuildRecipeCode.barrelOven.OnCreate),
-- so vanilla gives it fuel, lighting, burn time, room heat and a firebox to cook in. The copper holds one fluid at
-- a time: it heats towards MAX_C while the fire burns and cools to the room when it is out. Its state is a plain
-- table in the fireplace's modData under KEY; every rule here works on it without the engine.
--
-- "By a fire" is a place of its own (PLACE, at FIRE_C): any lit fire within FIRE_RADIUS tiles on the same floor,
-- the Hearth or not. It is opt-in: Weather.placeOf never returns it, Hearth.placeOf does, so only a mod that asks
-- for it gets it. Mods hook into the copper with Hearth.hook (see HOOKS below).
local Weather = require "TraditionalPreservationCore/Weather"
local Tiles = require "TraditionalPreservationCore/Tiles"

local Hearth = {}

-- Save key: never rename it once the mod is out (DEVGUIDE, "Rules that keep saves and the game happy").
-- Inside: ml, fluid, tempC, last, fireUntil.
Hearth.KEY = "tpHearth"

-- By a fire. A fireplace, an antique stove or a campfire, never an electric or gas stove.
Hearth.PLACE = "Hearth"
Hearth.FIRE_C = 28
Hearth.FIRE_RADIUS = 2

-- The copper
Hearth.COPPER_ML = 10000
Hearth.MAX_C = 95                  -- over a fire; nothing in it quite boils
Hearth.HOT_C = 85                  -- steaming
Hearth.LIT_TAU = 0.75              -- hours, for 10 L over a lit fire: 20 to 85 C in about an hour and a half
Hearth.OUT_TAU = 2.0               -- hours, for 10 L once the fire is out: the stone holds its heat
Hearth.FLOOR_ML = 1000             -- a splash heats as fast as a litre

-- Vanilla's item heat, for fluids poured between the copper and the player's containers. Vanilla cools a
-- container in the player's hands to room heat within seconds.
Hearth.ROOM_C = 20
Hearth.HEAT_PER_DEGREE = 1 / 133   -- itemHeat 1.0 is room temperature; 1.6 (water turns clean) is about 100 C

-- Newton's law: tempC after hours at placeC, for a time constant tau.
function Hearth.cool(tempC, placeC, hours, tau)
    return placeC + (tempC - placeC) * math.exp(-hours / tau)
end

function Hearth.heatCelsius(itemHeat)
    return math.min(Hearth.ROOM_C + ((itemHeat or 1) - 1) / Hearth.HEAT_PER_DEGREE, Hearth.MAX_C)
end

-- The other way, for fluid poured back out: it starts at the heat it had.
function Hearth.itemHeat(celsius)
    return 1 + (celsius - Hearth.ROOM_C) * Hearth.HEAT_PER_DEGREE
end

function Hearth.stateOf(modData)
    modData[Hearth.KEY] = modData[Hearth.KEY] or {}
    return modData[Hearth.KEY]
end

-- Copper rules

function Hearth.copperTau(ml, lit)
    local base = lit and Hearth.LIT_TAU or Hearth.OUT_TAU
    return base * (math.max(ml, Hearth.FLOOR_ML) / Hearth.COPPER_ML) ^ (1 / 3)
end

-- How much of ml of a fluid fits, or 0 with the reason: one fluid at a time.
function Hearth.copperRoom(copper, fluid, ml)
    if (copper.ml or 0) > 0 and copper.fluid ~= fluid then return 0, "Mixed" end
    local room = Hearth.COPPER_ML - (copper.ml or 0)
    if room <= 0 then return 0, "Full" end
    return math.min(ml, room)
end

-- Pours a fluid in; the temperatures mix by volume. Returns the ml taken (0 with a reason when refused).
function Hearth.pourInto(copper, fluid, ml, fluidC, now)
    local taken, reason = Hearth.copperRoom(copper, fluid, ml)
    if taken <= 0 then return 0, reason end
    local had = copper.ml or 0
    copper.tempC = had > 0 and (copper.tempC * had + fluidC * taken) / (had + taken) or fluidC
    copper.ml, copper.fluid = had + taken, fluid
    copper.last = copper.last or now
    return taken
end

-- Takes up to maxMl out, all of it if left out. Returns the ml, the fluid and its temperature.
function Hearth.take(copper, maxMl)
    local ml = math.min(copper.ml or 0, maxMl or copper.ml or 0)
    if ml <= 0 then return 0 end
    local fluid, tempC = copper.fluid, copper.tempC
    copper.ml = copper.ml - ml
    if copper.ml <= 0 then
        for _, key in ipairs({ "ml", "fluid", "tempC", "last" }) do copper[key] = nil end
    end
    return ml, fluid, tempC
end

-- Brings the copper up to now: heating while the fire burns (to fireUntil), cooling to roomC after.
function Hearth.advance(copper, now, roomC)
    if (copper.ml or 0) <= 0 then return end
    local t = copper.last or now
    if copper.fireUntil and copper.fireUntil > t then
        local stop = math.min(copper.fireUntil, now)
        copper.tempC = Hearth.cool(copper.tempC, Hearth.MAX_C, stop - t, Hearth.copperTau(copper.ml, true))
        t = stop
    end
    if now > t then copper.tempC = Hearth.cool(copper.tempC, roomC, now - t, Hearth.copperTau(copper.ml, false)) end
    copper.last = now
end

-- What the copper shows: Empty, Full or Hot (steaming, whatever the fluid).
function Hearth.look(copper)
    if (copper.ml or 0) <= 0 then return "Empty" end
    return copper.tempC >= Hearth.HOT_C and "Hot" or "Full"
end

function Hearth.isHot(copper)
    return (copper.ml or 0) > 0 and (copper.tempC or 0) >= Hearth.HOT_C
end

-- Hours until the copper is hot if the fire burns on; 0 if it is already, nil if it is empty.
function Hearth.hoursToHot(copper)
    if (copper.ml or 0) <= 0 then return nil end
    if copper.tempC >= Hearth.HOT_C then return 0 end
    return Hearth.copperTau(copper.ml, true) * math.log((Hearth.MAX_C - copper.tempC) / (Hearth.MAX_C - Hearth.HOT_C))
end

-- Hooks: other mods' say on fluid going in and out of the copper. Each is a list of functions, called in order.
--   heatOf(item, now, character)  the heat in C of the fluid in item, or nil to let the next one (or vanilla's
--                                 item heat) say. A container that keeps its own heat answers here.
--   taken(item, ml)               ml left item for the copper.
--   filled(item, fill)            fill = { ml, fluid, tempC, hot, hadMl, hadC, now, character }: ml went into
--                                 item from the copper. Return true if it set the item's heat itself.
local HOOKS = { heatOf = {}, taken = {}, filled = {} }

function Hearth.hook(name, fn)
    table.insert(HOOKS[name], fn)
end

-- The heat of an item's fluid, by the hooks, else vanilla's item heat.
function Hearth.heatOf(item, now, character)
    for _, fn in ipairs(HOOKS.heatOf) do
        local celsius = fn(item, now, character)
        if celsius then return celsius end
    end
    return Hearth.heatCelsius(item:getItemHeat())
end

function Hearth.tookFrom(item, ml)
    for _, fn in ipairs(HOOKS.taken) do fn(item, ml) end
end

-- After a fill from the copper: the hooks first, else vanilla's item heat is set to the copper's.
function Hearth.filledFrom(item, fill)
    local handled = false
    for _, fn in ipairs(HOOKS.filled) do handled = fn(item, fill) or handled end
    if not handled then item:setItemHeat(Hearth.itemHeat(fill.tempC)) end
end

-- Tiles: one per look of the copper and facing, all of them fireplaces.
Hearth.LOOKS = Tiles.HEARTH_LOOKS or {}
Hearth.SPRITES = Tiles.HEARTHS or {}
Hearth.FACE_COUNT = Tiles.FACE_COUNT or 2

local function spriteIndex(name)
    if not name or string.sub(name, 1, #Tiles.PREFIX) ~= Tiles.PREFIX then return nil end
    return tonumber(string.sub(name, #Tiles.PREFIX + 1))
end

-- The facing (0 S, 1 E) of a hearth tile, whatever its copper shows; nil for any other tile.
function Hearth.face(spriteName)
    local index = spriteIndex(spriteName)
    if not index then return nil end
    for _, base in pairs(Hearth.LOOKS) do
        if index >= base and index < base + Hearth.FACE_COUNT then return index - base end
    end
    return nil
end

function Hearth.sprite(look, face)
    return Tiles.PREFIX .. (Hearth.LOOKS[look] + face)
end

function Hearth.isHearth(object)
    local sprite = object and object:getSprite()
    return sprite ~= nil and instanceof(object, "IsoFireplace") and Hearth.face(sprite:getName()) ~= nil
end

-- The copper's state, brought up to now where the World runs (a server or single player).
function Hearth.copperOf(fire)
    if Hearth.World then return Hearth.World.update(fire, getGameTime():getWorldAgeHours()) end
    return Hearth.stateOf(fire:getModData())
end

-- Fires

-- Fireplaces, antique ovens, braziers, cooking pits and burn barrels are IsoFireplace; a player's campfire is a
-- plain object named "Campfire" whose lit state the camping system copies into its modData (ENGINE_NOTES).
local function isLitFire(object)
    if instanceof(object, "IsoFireplace") then return object:isLit() end
    return object:getName() == "Campfire" and object:getModData().isLit == true
end

-- Every object within FIRE_RADIUS tiles on the same floor that passes test, nearest first.
function Hearth.near(square, test)
    local found, cell = {}, getCell()
    for dx = -Hearth.FIRE_RADIUS, Hearth.FIRE_RADIUS do
        for dy = -Hearth.FIRE_RADIUS, Hearth.FIRE_RADIUS do
            local there = cell:getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
            local objects = there and there:getObjects()
            for i = 0, objects and objects:size() - 1 or -1 do
                local object = objects:get(i)
                if test(object) then table.insert(found, { object = object, distance = dx * dx + dy * dy }) end
            end
        end
    end
    table.sort(found, function(a, b) return a.distance < b.distance end)
    local list = {}
    for index, entry in ipairs(found) do list[index] = entry.object end
    return list
end

-- The nearest lit fire within FIRE_RADIUS tiles on the same floor, or nil.
function Hearth.fireNear(square)
    return Hearth.near(square, isLitFire)[1]
end

-- Hearths within FIRE_RADIUS tiles, nearest first.
function Hearth.hearthsNear(square)
    return Hearth.near(square, Hearth.isHearth)
end

-- Hours of fuel the fire has left; nil if it can't be read (it is then taken to burn on).
function Hearth.fuelHours(fire)
    if instanceof(fire, "IsoFireplace") then return fire:getFuelAmount() / 60 end
    local minutes = fire:getModData().fuelAmt
    return minutes and minutes / 60 or nil
end

-- The opt-in place: by a fire, else below ground, under a roof or in the open. The fire, if any, comes second.
function Hearth.placeOf(object)
    local square = object and object:getSquare()
    local fire = square and Hearth.fireNear(square)
    if fire then return Hearth.PLACE, fire end
    return Weather.placeOf(object)
end

function Hearth.placeTemperature(ledger, place)
    if place == Hearth.PLACE then return Hearth.FIRE_C end
    return Weather.placeTemperature(ledger, place)
end

-- Notes on a station's state where it stands: by a fire, until when the fuel lasts and what it stands in without
-- the fire. A station's catch-up reads them for the time it was away.
function Hearth.noteFire(state, object, fire, now)
    if not fire then
        state.fireUntil, state.under = nil, nil
        return
    end
    local hours = Hearth.fuelHours(fire)
    state.fireUntil = hours and now + hours or nil
    state.under = Weather.placeOf(object)
end

-- Building: the entity script's OnCreate, so a global.
TraditionalPreservationCore = TraditionalPreservationCore or {}

function TraditionalPreservationCore.OnCreateHearth(params)
    local thumpable = params.thumpable
    local sprite = thumpable and thumpable:getSprite()
    local name = sprite and sprite:getName()
    if not Hearth.face(name) then return nil end
    local square = thumpable:getSquare()
    local fire = IsoFireplace.new(getCell(), square, getSprite(name))
    square:AddTileObject(fire)
    if thumpable:getSquare() ~= nil then
        thumpable:removeFromWorld()
        thumpable:removeFromSquare()
        thumpable:setSquare(nil)
    end
    return { replaceObject = true, object = fire }
end

return Hearth
