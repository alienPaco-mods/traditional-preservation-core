-- Traditional Preservation core: the hand jobs at a Hearth's cauldron. "pourIn" empties a container of one plain
-- fluid into the cauldron, as much as fits; "fillFrom" fills an empty container, or one of the same fluid, from it;
-- "empty" pours whatever the cauldron holds away (rotten milk above all), and takes no item.
-- The cauldron holds one fluid at a time, or fluids that blend (Hearth.blend). Mods follow the fluid with Hearth.hook
-- (heatOf, taken, filled).
require "TimedActions/ISBaseTimedAction"
local Hearth = require "TraditionalPreservationCore/Hearth"
local Action = require "TraditionalPreservationCore/Action"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Weather = require "TraditionalPreservationCore/Weather"

TPHearthCauldron = ISBaseTimedAction:derive("TPHearthCauldron")

local function mlIn(container)
    return math.floor(container:getAmount() * 1000 + 0.5)
end

-- Millilitres the container has room for.
local function roomIn(container)
    return math.floor((container:getCapacity() - container:getAmount()) * 1000 + 0.5)
end

local function canFillFrom(container, cauldron)
    if (cauldron.ml or 0) <= 0 or roomIn(container) <= 0 or not Hearth.poursOut(cauldron) then return false end
    if container:isEmpty() then return true end
    local parts, fluid = Hearth.partsIn(container)
    return parts ~= nil and Hearth.blends(cauldron.fluid, fluid)
end
TPHearthCauldron.canFillFrom = canFillFrom

function TPHearthCauldron:isValid()
    if self.mode == "empty" then
        return self.hearth:getSquare() ~= nil and (Hearth.cauldronState(self.hearth:getModData()).ml or 0) > 0
    end
    if not self.hearth:getSquare() or not self.character:getInventory():containsRecursive(self.item) then return false end
    local container = self.item:getFluidContainer()
    local cauldron = Hearth.cauldronState(self.hearth:getModData())
    if self.mode == "pourIn" then
        local parts = Hearth.partsIn(container)
        return parts ~= nil and Hearth.cauldronRoom(cauldron, parts, 1) > 0
    end
    return canFillFrom(container, cauldron)
end

function TPHearthCauldron:waitToStart()
    self.character:faceThisObject(self.hearth)
    return self.character:shouldBeTurning()
end

function TPHearthCauldron:start()
    self:setActionAnim("Loot")
end

function TPHearthCauldron:complete()
    -- Brought up to the minute first, so poured fluid mixes with the cauldron as it is now.
    local cauldron = Hearth.cauldronOf(self.hearth)
    local now = getGameTime():getWorldAgeHours()
    if self.mode == "empty" then
        Hearth.take(cauldron)
        cauldron[FluidAgeing.KEY] = nil
        if Hearth.World then Hearth.World.refresh(self.hearth) end
        return true
    end
    local container = self.item:getFluidContainer()
    if self.mode == "pourIn" then
        local parts = Hearth.partsIn(container)
        local heat = Hearth.heatOf(self.item, now, self.character)
        local age = FluidAgeing.sourceRecord(self.item, now)
        local had = cauldron.ml or 0
        local taken = parts and Hearth.pourInto(cauldron, parts, mlIn(container), heat, now) or 0
        if taken > 0 then
            container:removeFluid(taken / 1000)
            Hearth.tookFrom(self.item, taken)
            if age then FluidAgeing.receive(cauldron, age, had > 0, Weather.placeOf(self.hearth)) end
        end
    elseif canFillFrom(container, cauldron) then
        local hadMl = mlIn(container)
        local hadC = hadMl > 0 and Hearth.heatOf(self.item, now, self.character) or 0
        local hot, held = Hearth.isHot(cauldron), Hearth.heldHours(cauldron)
        local age = FluidAgeing.cauldronRecord(cauldron, now, Weather.placeOf(self.hearth), held)
        if age then FluidAgeing.look(self.item, now) end
        local ml, fluid, tempC, parts = Hearth.take(cauldron, roomIn(container))
        if ml > 0 then
            for name, part in pairs(parts) do container:addFluid(name, part / 1000) end
            Hearth.filledFrom(self.item, { ml = ml, fluid = fluid, parts = parts, tempC = tempC, hot = hot, held = held, hadMl = hadMl,
                hadC = hadC, now = now, character = self.character })
            -- The cauldron's record says whether it has been held long enough to count as scalded.
            if age then FluidAgeing.receive(self.item:getModData(), age, hadMl > 0, FluidAgeing.placeOfItem(self.item)) end
        end
        if (cauldron.ml or 0) <= 0 then cauldron[FluidAgeing.KEY] = nil end
    end
    if Hearth.World then Hearth.World.refresh(self.hearth) end
    return true
end

function TPHearthCauldron:perform()
    ISBaseTimedAction.perform(self)
end

function TPHearthCauldron:getDuration()
    if self.mode == "empty" then
        return Action.pourDuration(self.character, (Hearth.cauldronState(self.hearth:getModData()).ml or 0) / 1000, 10)
    end
    local container = self.item:getFluidContainer()
    local litres = 0
    if container and self.mode == "pourIn" then litres = container:getAmount() end
    if container and self.mode == "fillFrom" then litres = container:getCapacity() - container:getAmount() end
    return Action.pourDuration(self.character, litres, 10)
end

-- item is false for "empty".
function TPHearthCauldron:new(character, hearth, item, mode)
    local o = ISBaseTimedAction.new(self, character)
    o.hearth = hearth
    o.item = item
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
