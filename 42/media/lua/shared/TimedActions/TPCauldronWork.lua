-- Traditional Preservation core: the hand jobs at a fire's cauldron. "pourIn" empties a container of one plain
-- fluid into the cauldron, as much as fits; "fillFrom" fills an empty container, or one of the same fluid, from it;
-- "empty" pours whatever the cauldron holds away (rotten milk above all), and takes no item.
-- The cauldron holds one fluid at a time, or fluids that blend (CauldronFluid.blend). Mods follow the fluid with CauldronFluid.hook
-- (heatOf, taken, filled).
require "TimedActions/ISBaseTimedAction"
local Fire = require "TraditionalPreservationCore/Fire"
local Cauldron = require "TraditionalPreservationCore/Cauldron"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local Action = require "TraditionalPreservationCore/Action"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Weather = require "TraditionalPreservationCore/Weather"

TPCauldronWork = ISBaseTimedAction:derive("TPCauldronWork")

-- Past this many litres a pour takes no longer.
local MOST_LITRES = 10

local function mlIn(container)
    return math.floor(container:getAmount() * 1000 + 0.5)
end

-- Millilitres the container has room for.
local function roomIn(container)
    return math.floor((container:getCapacity() - container:getAmount()) * 1000 + 0.5)
end

local function canFillFrom(container, cauldron)
    if (cauldron.ml or 0) <= 0 or roomIn(container) <= 0 or not CauldronFluid.poursOut(cauldron) then return false end
    if container:isEmpty() then return true end
    local parts, fluid = CauldronFluid.partsIn(container)
    return parts ~= nil and CauldronFluid.blends(cauldron.fluid, fluid)
end
TPCauldronWork.canFillFrom = canFillFrom

-- The cauldron's state as saved, not brought up to now (isValid and getDuration run often).
local function savedCauldron(self)
    return Cauldron.state(self.fire:getModData())
end

-- An empty cauldron keeps no age record: the next fluid starts its own.
local function forgetAgeIfEmpty(cauldron)
    if (cauldron.ml or 0) <= 0 then cauldron[FluidAgeing.KEY] = nil end
end

function TPCauldronWork:isValid()
    if self.mode == "empty" then
        return self.fire:getSquare() ~= nil and (savedCauldron(self).ml or 0) > 0
    end
    if not self.fire:getSquare() or not self.character:getInventory():containsRecursive(self.item) then return false end
    local container = self.item:getFluidContainer()
    local cauldron = savedCauldron(self)
    if self.mode == "pourIn" then
        local parts = CauldronFluid.partsIn(container)
        return parts ~= nil and CauldronFluid.cauldronRoom(cauldron, parts, 1) > 0
    end
    return canFillFrom(container, cauldron)
end

function TPCauldronWork:waitToStart()
    self.character:faceThisObject(self.fire)
    return self.character:shouldBeTurning()
end

function TPCauldronWork:start()
    self:setActionAnim("Loot")
end

function TPCauldronWork:complete()
    -- Brought up to the minute first, so poured fluid mixes with the cauldron as it is now.
    local cauldron = Cauldron.of(self.fire)
    local now = getGameTime():getWorldAgeHours()
    if self.mode == "empty" then
        CauldronFluid.take(cauldron)
        forgetAgeIfEmpty(cauldron)
        Fire.redraw(self.fire)
        return true
    end
    local container = self.item:getFluidContainer()
    if self.mode == "pourIn" then
        local parts = CauldronFluid.partsIn(container)
        local heat = CauldronFluid.heatOf(self.item, now, self.character)
        local age = FluidAgeing.sourceRecord(self.item, now)
        local had = cauldron.ml or 0
        local taken = parts and CauldronFluid.pourInto(cauldron, parts, mlIn(container), heat, now) or 0
        if taken > 0 then
            container:removeFluid(taken / 1000)
            CauldronFluid.tookFrom(self.item, taken)
            if age then FluidAgeing.receive(cauldron, age, had > 0, Weather.placeOf(self.fire)) end
        end
    elseif canFillFrom(container, cauldron) then
        local hadMl = mlIn(container)
        local hadC = hadMl > 0 and CauldronFluid.heatOf(self.item, now, self.character) or 0
        local hot, held = CauldronFluid.isHot(cauldron), CauldronFluid.heldHours(cauldron)
        local age = FluidAgeing.cauldronRecord(cauldron, now, Weather.placeOf(self.fire), held)
        if age then FluidAgeing.look(self.item, now) end
        local ml, fluid, tempC, parts = CauldronFluid.take(cauldron, roomIn(container))
        if ml > 0 then
            for name, part in pairs(parts) do container:addFluid(name, part / 1000) end
            CauldronFluid.filledFrom(self.item, { ml = ml, fluid = fluid, parts = parts, tempC = tempC, hot = hot, held = held, hadMl = hadMl,
                hadC = hadC, now = now, character = self.character })
            -- The cauldron's record says whether it has been held long enough to count as scalded.
            if age then FluidAgeing.receive(self.item:getModData(), age, hadMl > 0, FluidAgeing.placeOfItem(self.item)) end
        end
        forgetAgeIfEmpty(cauldron)
    end
    Fire.redraw(self.fire)
    return true
end

function TPCauldronWork:perform()
    ISBaseTimedAction.perform(self)
end

function TPCauldronWork:getDuration()
    if self.mode == "empty" then
        return Action.pourDuration(self.character, (savedCauldron(self).ml or 0) / 1000, MOST_LITRES)
    end
    local container = self.item:getFluidContainer()
    local litres = 0
    if container and self.mode == "pourIn" then litres = container:getAmount() end
    if container and self.mode == "fillFrom" then litres = container:getCapacity() - container:getAmount() end
    return Action.pourDuration(self.character, litres, MOST_LITRES)
end

-- item is false for "empty".
function TPCauldronWork:new(character, fire, item, mode)
    local o = ISBaseTimedAction.new(self, character)
    o.fire = fire
    o.item = item
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
