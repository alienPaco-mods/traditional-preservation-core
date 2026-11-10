-- Traditional Preservation core: the hand jobs at a Hearth's copper. "pourIn" empties a container of one plain
-- fluid into the copper, as much as fits; "fillFrom" fills an empty container, or one of the same fluid, from it.
-- The copper holds one fluid at a time. Mods follow the fluid with Hearth.hook (heatOf, taken, filled).
require "TimedActions/ISBaseTimedAction"
local Hearth = require "TraditionalPreservationCore/Hearth"
local Action = require "TraditionalPreservationCore/Action"
local Container = require "TraditionalPreservationCore/Container"

TPHearthCopper = ISBaseTimedAction:derive("TPHearthCopper")

local fluidIn = Container.fluidIn

local function mlIn(container)
    return math.floor(container:getAmount() * 1000 + 0.5)
end

-- Millilitres the container has room for.
local function roomIn(container)
    return math.floor((container:getCapacity() - container:getAmount()) * 1000 + 0.5)
end

local function canFillFrom(container, copper)
    if (copper.ml or 0) <= 0 or roomIn(container) <= 0 then return false end
    return container:isEmpty() or fluidIn(container) == copper.fluid
end
TPHearthCopper.canFillFrom = canFillFrom

function TPHearthCopper:isValid()
    if not self.hearth:getSquare() or not self.character:getInventory():containsRecursive(self.item) then return false end
    local container = self.item:getFluidContainer()
    local copper = Hearth.stateOf(self.hearth:getModData())
    if self.mode == "pourIn" then
        local fluid = fluidIn(container)
        return fluid ~= nil and Hearth.copperRoom(copper, fluid, 1) > 0
    end
    return canFillFrom(container, copper)
end

function TPHearthCopper:waitToStart()
    self.character:faceThisObject(self.hearth)
    return self.character:shouldBeTurning()
end

function TPHearthCopper:start()
    self:setActionAnim("Loot")
end

function TPHearthCopper:complete()
    -- Brought up to the minute first, so poured fluid mixes with the copper as it is now.
    local copper = Hearth.copperOf(self.hearth)
    local now = getGameTime():getWorldAgeHours()
    local container = self.item:getFluidContainer()
    if self.mode == "pourIn" then
        local fluid = fluidIn(container)
        local heat = Hearth.heatOf(self.item, now, self.character)
        local taken = fluid and Hearth.pourInto(copper, fluid, mlIn(container), heat, now) or 0
        if taken > 0 then
            container:removeFluid(taken / 1000)
            Hearth.tookFrom(self.item, taken)
        end
    elseif canFillFrom(container, copper) then
        local hadMl = mlIn(container)
        local hadC = hadMl > 0 and Hearth.heatOf(self.item, now, self.character) or 0
        local hot = Hearth.isHot(copper)
        local ml, fluid, tempC = Hearth.take(copper, roomIn(container))
        if ml > 0 then
            container:addFluid(fluid, ml / 1000)
            Hearth.filledFrom(self.item, { ml = ml, fluid = fluid, tempC = tempC, hot = hot, hadMl = hadMl, hadC = hadC,
                now = now, character = self.character })
        end
    end
    if Hearth.World then Hearth.World.refresh(self.hearth) end
    return true
end

function TPHearthCopper:perform()
    ISBaseTimedAction.perform(self)
end

function TPHearthCopper:getDuration()
    local container = self.item:getFluidContainer()
    local litres = 0
    if container and self.mode == "pourIn" then litres = container:getAmount() end
    if container and self.mode == "fillFrom" then litres = container:getCapacity() - container:getAmount() end
    return Action.pourDuration(self.character, litres, 10)
end

function TPHearthCopper:new(character, hearth, item, mode)
    local o = ISBaseTimedAction.new(self, character)
    o.hearth = hearth
    o.item = item
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
