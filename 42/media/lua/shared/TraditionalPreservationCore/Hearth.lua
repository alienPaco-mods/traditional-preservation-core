-- Traditional Preservation core: the Hearth, a low stone oven with a copper set in its top, shared by every TP mod.
-- The built tile is swapped for a vanilla fireplace, as the Barrel Oven's is (BuildRecipeCode.barrelOven.OnCreate),
-- so vanilla gives it fuel, lighting, burn time, room heat and a firebox to cook in. The copper holds one fluid at
-- a time, or a blend of fluids a mod has said may share it (Hearth.blend: Dairy's milks): it heats towards MAX_C (water boils, and boils clean) while the fire burns and cools to the room when it is out. Its state is a plain
-- table in the fireplace's modData under KEY; every rule here works on it without the engine.
--
-- "By a fire" is a place of its own (PLACE, at FIRE_C): any lit fire within FIRE_RADIUS tiles on the same floor,
-- the Hearth or not. It is opt-in: Weather.placeOf never returns it, Hearth.placeOf does, so only a mod that asks
-- for it gets it. Mods hook into the copper with Hearth.hook (see HOOKS below).
--
-- A lit Hearth can be banked: the fire raked down under its ash. It burns BANKED_BURN of the wood a lit fire does,
-- the copper settles at BANKED_C, and beside it is a place of its own (EMBERS, at EMBERS_C). Vanilla's fireplace has
-- one speed and heats and lights 8 tiles whatever its fuel (ENGINE_NOTES), so a banked Hearth's vanilla fire is out:
-- the mod counts its fuel from the clock (Hearth.reckonFuel) and sets vanilla's to the count, gives it its own small
-- heat and faint light, and keeps the firebox hot (HearthWorld). Hearth.isBurning is a fire lit or banked.
local Weather = require "TraditionalPreservationCore/Weather"
local Station = require "TraditionalPreservationCore/Station"
local Tiles = require "TraditionalPreservationCore/Tiles"

local Hearth = {}

-- Save key: never rename it once the mod is out (DEVGUIDE, "Rules that keep saves and the game happy").
-- Inside: ml, fluid, parts, tempC, last, fireUntil, boiled; banked, fuel, fuelAt, fuelSet.
Hearth.KEY = "tpHearth"

-- By a fire. A fireplace, an antique stove or a campfire, never an electric or gas stove.
Hearth.PLACE = "Hearth"
Hearth.FIRE_C = 28
Hearth.FIRE_RADIUS = 2

-- Banked
Hearth.BANKED_C = 50               -- the copper's heat over banked embers
Hearth.BANKED_BURN = 1 / 3         -- of the wood a lit fire burns: a banked fire lasts three times as long
Hearth.EMBERS = "Embers"           -- the place by a banked Hearth
Hearth.EMBERS_C = 24
Hearth.BANKED_HEAT_RADIUS = 2      -- tiles of room heat around banked embers (a lit fire: 8)
Hearth.BANKED_HEAT_C = 25          -- that heat (a lit fire: 35 C)
Hearth.BANKED_LIGHT_RADIUS = 1
Hearth.BANKED_LIGHT = { 0.6, 0.25, 0.1 }
Hearth.BANKED_FIREBOX = 1.8        -- the firebox's heat (vanilla's container temperature): it cooks, a third as fast

local FIRE_C = { [Hearth.PLACE] = Hearth.FIRE_C, [Hearth.EMBERS] = Hearth.EMBERS_C }

-- The heat of a place by a fire, lit or banked; nil for any other place.
function Hearth.fireC(place)
    return FIRE_C[place]
end

function Hearth.isFirePlace(place)
    return FIRE_C[place] ~= nil
end

-- The copper
Hearth.COPPER_ML = 60000            -- a farmhouse copper (real ones 40 to 100 L)
Hearth.TAU_ML = 10000              -- the litres the time constants below are for; more heats and cools slower
Hearth.MAX_C = 95                  -- over a fire; nothing in it quite boils
Hearth.HOT_C = 85                  -- steaming
Hearth.LIT_TAU = 0.75              -- hours, for 10 L over a lit fire: 20 to 85 C in about an hour and a half
Hearth.OUT_TAU = 2.0               -- hours, for 10 L once the fire is out: the stone holds its heat
Hearth.FLOOR_ML = 1000             -- a splash heats as fast as a litre

-- Water is let boil: over a lit fire it heats towards WATER_FIRE_C and holds at BOIL_C. Tainted water kept at the
-- boil for BOIL_HOURS turns clean (BOILED). Every other fluid is kept off the boil, at MAX_C.
Hearth.BOIL_C = 100
Hearth.WATER_FIRE_C = 110
Hearth.BOIL_HOURS = 1 / 6
Hearth.BOILS = { Water = true, TaintedWater = true }
Hearth.BOILED = { TaintedWater = "Water" }

-- Vanilla's item heat, for fluids poured between the copper and the player's containers. Vanilla cools a
-- container in the player's hands to room heat within seconds.
Hearth.ROOM_C = 20
Hearth.HEAT_PER_DEGREE = 1 / 133   -- itemHeat 1.0 is room temperature; 1.6 (water turns clean) is about 100 C
Hearth.COLD_HEAT = 0.2             -- the engine's floor: an item in a powered fridge or freezer
Hearth.COLD_C = 4                  -- what that reads as; below room heat the scale is gentler than above it

-- Newton's law: tempC after hours at placeC, for a time constant tau.
function Hearth.cool(tempC, placeC, hours, tau)
    return placeC + (tempC - placeC) * math.exp(-hours / tau)
end

local COLD_PER_DEGREE = (1 - Hearth.COLD_HEAT) / (Hearth.ROOM_C - Hearth.COLD_C)

function Hearth.heatCelsius(itemHeat)
    itemHeat = itemHeat or 1
    if itemHeat < 1 then
        return Hearth.ROOM_C + (math.max(itemHeat, Hearth.COLD_HEAT) - 1) / COLD_PER_DEGREE
    end
    return math.min(Hearth.ROOM_C + (itemHeat - 1) / Hearth.HEAT_PER_DEGREE, Hearth.MAX_C)
end

-- The other way, for fluid poured back out: it starts at the heat it had.
function Hearth.itemHeat(celsius)
    if celsius < Hearth.ROOM_C then
        return math.max(1 + (celsius - Hearth.ROOM_C) * COLD_PER_DEGREE, Hearth.COLD_HEAT)
    end
    return 1 + (celsius - Hearth.ROOM_C) * Hearth.HEAT_PER_DEGREE
end

function Hearth.stateOf(modData)
    modData[Hearth.KEY] = modData[Hearth.KEY] or {}
    return modData[Hearth.KEY]
end

-- Copper rules

function Hearth.copperTau(ml, lit)
    local base = lit and Hearth.LIT_TAU or Hearth.OUT_TAU
    return base * (math.max(ml, Hearth.FLOOR_ML) / Hearth.TAU_ML) ^ (1 / 3)
end

-- Whether the copper's fluid is let boil: water on its own.
function Hearth.boils(copper)
    return Hearth.BOILS[copper.fluid] == true and not copper.parts
end

-- The heat the copper heats towards while the fire burns.
function Hearth.fireTarget(copper)
    if copper.banked then return Hearth.BANKED_C end
    return Hearth.boils(copper) and Hearth.WATER_FIRE_C or Hearth.MAX_C
end

-- Fluids that may share the copper, as a cow's and a sheep's milk do: a mod names each group. Anything else is
-- one fluid at a time.
local BLENDS = {}

function Hearth.blend(...)
    local group = {}
    for _, name in ipairs({ ... }) do
        group[name] = true
        BLENDS[name] = group
    end
end

function Hearth.blends(a, b)
    return a == b or (BLENDS[a] ~= nil and BLENDS[a][b] == true)
end

-- parts ({ name = ml }) in the same shares, adding up to ml.
function Hearth.share(parts, ml)
    local total, shares = 0, {}
    for _, part in pairs(parts) do total = total + part end
    if total <= 0 then return shares end
    for name, part in pairs(parts) do shares[name] = part * ml / total end
    return shares
end

-- What ml of a store (the copper, or a mod's own: anything with ml, fluid and parts) is, by fluid: { name = ml }.
-- parts is kept only for a blend, and only its shares count; fluid is then the largest of them.
function Hearth.partsOf(state, ml)
    ml = ml or state.ml or 0
    if state.parts then return Hearth.share(state.parts, ml) end
    return state.fluid and ml > 0 and { [state.fluid] = ml } or {}
end

-- Notes ml of a fluid (a name, or parts for a blend) going into a store. Call it before the store's ml grows.
function Hearth.addParts(state, fluid, ml)
    local parts = Hearth.partsOf(state)
    local added = type(fluid) == "table" and Hearth.share(fluid, ml) or { [fluid] = ml }
    for name, part in pairs(added) do parts[name] = (parts[name] or 0) + part end
    local count, most = 0, nil
    for name, part in pairs(parts) do
        count = count + 1
        if not most or part > parts[most] or (part == parts[most] and name < most) then most = name end
    end
    state.fluid = most
    state.parts = count > 1 and parts or nil
end

-- What a fluid container holds, { name = ml }, and its main fluid: one fluid, or a blend of fluids that may share
-- the copper. nil for none, or for any other mixture.
function Hearth.partsIn(container)
    if not container or container:isEmpty() then return nil end
    local primary = container:getPrimaryFluid()
    local name = primary and primary:getFluidTypeString()
    if not name then return nil end
    local found = container:getPrimaryFluidAmount()
    local parts = { [name] = found * 1000 }
    for other in pairs(BLENDS[name] or {}) do
        local fluid = other ~= name and Fluid.Get(other)
        local amount = fluid and container:getSpecificFluidAmount(fluid) or 0
        if amount > 0 then
            parts[other] = amount * 1000
            found = found + amount
        end
    end
    if found < container:getAmount() - 0.001 then return nil end
    return parts, name
end

-- How much of ml of a fluid (a name, or parts) fits, or 0 with the reason: one fluid at a time, unless they blend.
function Hearth.copperRoom(copper, fluid, ml)
    if (copper.ml or 0) > 0 then
        for name in pairs(type(fluid) == "table" and fluid or { [fluid] = true }) do
            if not Hearth.blends(copper.fluid, name) then return 0, "Mixed" end
        end
    end
    local room = Hearth.COPPER_ML - (copper.ml or 0)
    if room <= 0 then return 0, "Full" end
    return math.min(ml, room)
end

-- Pours a fluid (a name, or parts) in; the temperatures mix by volume. Returns the ml taken (0 with a reason when
-- refused).
function Hearth.pourInto(copper, fluid, ml, fluidC, now)
    local taken, reason = Hearth.copperRoom(copper, fluid, ml)
    if taken <= 0 then return 0, reason end
    local had = copper.ml or 0
    copper.tempC = had > 0 and (copper.tempC * had + fluidC * taken) / (had + taken) or fluidC
    copper.boiled = nil
    Hearth.addParts(copper, fluid, taken)
    copper.ml = had + taken
    copper.last = copper.last or now
    return taken
end

-- Takes up to maxMl out, all of it if left out. Returns the ml, the main fluid, its temperature, and the ml by
-- fluid ({ name = ml }: more than one name when the copper holds a blend).
function Hearth.take(copper, maxMl)
    local ml = math.min(copper.ml or 0, maxMl or copper.ml or 0)
    if ml <= 0 then return 0 end
    local fluid, tempC, parts = copper.fluid, copper.tempC, Hearth.partsOf(copper, ml)
    copper.ml = copper.ml - ml
    if copper.ml <= 0 then
        for _, key in ipairs({ "ml", "fluid", "parts", "tempC", "last", "boiled" }) do copper[key] = nil end
    end
    return ml, fluid, tempC, parts
end

-- Hours of a lit fire under the copper: water stops at BOIL_C, and the time it spends there counts towards boiling
-- tainted water clean.
local function heat(copper, hours)
    local target, tau = Hearth.fireTarget(copper), Hearth.copperTau(copper.ml, not copper.banked)
    if target <= Hearth.BOIL_C then
        copper.tempC = Hearth.cool(copper.tempC, target, hours, tau)
        return
    end
    local toBoil = copper.tempC >= Hearth.BOIL_C and 0
        or tau * math.log((target - copper.tempC) / (target - Hearth.BOIL_C))
    if hours <= toBoil then
        copper.tempC = Hearth.cool(copper.tempC, target, hours, tau)
        return
    end
    copper.tempC = Hearth.BOIL_C
    copper.boiled = (copper.boiled or 0) + hours - toBoil
    if copper.boiled >= Hearth.BOIL_HOURS and Hearth.BOILED[copper.fluid] then
        copper.fluid = Hearth.BOILED[copper.fluid]
    end
end

-- Brings the copper up to now: heating while the fire burns (to fireUntil), cooling to roomC after. Over banked
-- embers it settles at BANKED_C, as slowly as it cools: the fire is low and the stone holds the heat.
function Hearth.advance(copper, now, roomC)
    if (copper.ml or 0) <= 0 then return end
    local t = copper.last or now
    if copper.fireUntil and copper.fireUntil > t then
        local stop = math.min(copper.fireUntil, now)
        heat(copper, stop - t)
        t = stop
    end
    if now > t then
        copper.tempC = Hearth.cool(copper.tempC, roomC, now - t, Hearth.copperTau(copper.ml, false))
        copper.boiled = nil
    end
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

-- Hours until the copper is hot if the fire burns on; 0 if it is already, nil if it is empty or banked.
function Hearth.hoursToHot(copper)
    if (copper.ml or 0) <= 0 then return nil end
    if copper.tempC >= Hearth.HOT_C then return 0 end
    if copper.banked then return nil end
    local target = Hearth.fireTarget(copper)
    return Hearth.copperTau(copper.ml, true) * math.log((target - copper.tempC) / (target - Hearth.HOT_C))
end

-- Banks the fire (banked true) or stokes it up again, with fuel minutes in vanilla's fireplace now.
function Hearth.setBanked(state, banked, fuel, now)
    state.banked = banked or nil
    if banked then
        state.fuel, state.fuelAt, state.fuelSet = fuel, now, fuel
    else
        state.fuel, state.fuelAt, state.fuelSet = nil, nil, nil
    end
end

-- The fuel a banked fire has left now, from vanilla's fuel (minutes) and whether vanilla's fire is lit (it is out
-- while banked). Returns the fuel to give vanilla's fireplace, nil to leave it alone. The count runs on the clock,
-- away time included; wood added since the last reckoning counts in full. Burnt down, the fire is out and no longer
-- banked. Lit by anything but stoking, it is a lit fire again.
function Hearth.reckonFuel(state, fuel, lit, now)
    if not state.banked then return nil end
    if lit then
        Hearth.setBanked(state, false)
        return nil
    end
    if not state.fuel then
        Hearth.setBanked(state, true, fuel, now)
        return nil
    end
    local left = state.fuel - (now - state.fuelAt) * 60 * Hearth.BANKED_BURN + math.max(fuel - state.fuelSet, 0)
    if left < 1 then
        Hearth.setBanked(state, false)
        return 0
    end
    state.fuel, state.fuelAt, state.fuelSet = left, now, math.ceil(left)
    return state.fuelSet
end

-- A banked firebox cooks as slowly as it burns: vanilla adds cooking time at full speed, so of the minutes cooked
-- since before, only BANKED_BURN count. Returns the cooking time the food should have.
function Hearth.bankedCooking(before, now)
    if now <= before then return now end
    return before + (now - before) * Hearth.BANKED_BURN
end

-- Hooks: other mods' say on fluid going in and out of the copper. Each is a list of functions, called in order.
--   heatOf(item, now, character)  the heat in C of the fluid in item, or nil to let the next one (or vanilla's
--                                 item heat) say. A container that keeps its own heat answers here.
--   taken(item, ml)               ml left item for the copper.
--   filled(item, fill)            fill = { ml, fluid, parts, tempC, hot, hadMl, hadC, now, character }: ml went into
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

-- The hearth's own sprite is swapped among its looks, so each look is a "kind" of tile here.
local lookOf, HEARTH_TILES = Station.kinds(Tiles.PREFIX, Hearth.FACE_COUNT, Hearth.LOOKS)

-- The facing (0 S, 1 E) of a hearth tile, whatever its copper shows; nil for any other tile.
function Hearth.face(spriteName)
    return spriteName and HEARTH_TILES.face[spriteName]
end

function Hearth.sprite(look, face)
    return Tiles.PREFIX .. (Hearth.LOOKS[look] + face)
end

-- The fire mouth's glow, the hearth's overlay sprite (as vanilla lights its kilns): nil while the fire is out.
Hearth.GLOWS = Tiles.GLOWS or {}

function Hearth.glowSprite(lit, banked, face)
    local base = lit and Hearth.GLOWS[banked and "Banked" or "Lit"]
    return base and Tiles.PREFIX .. (base + face) or nil
end

function Hearth.isHearth(object)
    return lookOf(object) ~= nil and instanceof(object, "IsoFireplace")
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
    if instanceof(object, "IsoFireplace") then return Hearth.isBurning(object) end
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

-- A Hearth whose fire is banked (vanilla's fire is out meanwhile).
function Hearth.isBanked(object)
    return Hearth.isHearth(object) and Hearth.stateOf(object:getModData()).banked == true
end

-- A fireplace whose fire burns, lit or banked.
function Hearth.isBurning(object)
    return object:isLit() or Hearth.isBanked(object)
end

-- The warmest lit fire within FIRE_RADIUS tiles on the same floor, the nearest of those, with its place (PLACE, or
-- EMBERS for a banked Hearth); nil if there is none.
local function warmestFire(square)
    local fires = Hearth.near(square, isLitFire)
    for _, fire in ipairs(fires) do
        if not Hearth.isBanked(fire) then return fire, Hearth.PLACE end
    end
    if fires[1] then return fires[1], Hearth.EMBERS end
end

function Hearth.fireNear(square)
    return (warmestFire(square))
end

-- Hearths within FIRE_RADIUS tiles, nearest first.
function Hearth.hearthsNear(square)
    return Hearth.near(square, Hearth.isHearth)
end

-- Hours of fuel the fire has left; nil if it can't be read (it is then taken to burn on).
function Hearth.fuelHours(fire)
    if Hearth.isBanked(fire) then return fire:getFuelAmount() / 60 / Hearth.BANKED_BURN end
    if instanceof(fire, "IsoFireplace") then return fire:getFuelAmount() / 60 end
    local minutes = fire:getModData().fuelAmt
    return minutes and minutes / 60 or nil
end

-- The opt-in place: by a fire (or by banked embers), else below ground, under a roof or in the open. The fire, if any, comes second.
function Hearth.placeOf(object)
    local square = object and object:getSquare()
    local fire, place
    if square then fire, place = warmestFire(square) end
    if fire then return place, fire end
    return Weather.placeOf(object)
end

function Hearth.placeTemperature(ledger, place)
    if FIRE_C[place] then return FIRE_C[place] end
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
