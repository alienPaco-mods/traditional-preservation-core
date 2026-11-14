-- Traditional Preservation core: treating the fluid in a carried container by hand (a kind's treatments in
-- FluidAgeing: Fish & Meat's Cure Blood), a use for each litresPerUse litres (FluidTreat.treatBy).
require "TimedActions/ISBaseTimedAction"

TPFluidTreat = ISBaseTimedAction:derive("TPFluidTreat")

local FluidTreat = require "TraditionalPreservationCore/FluidTreat"
local Action = require "TraditionalPreservationCore/Action"

TPFluidTreat.TICKS = 100

function TPFluidTreat:isValid()
    return self.character:getInventory():containsRecursive(self.container)
        and FluidTreat.treatRefusal(self.container, self.spec, self.treatment, self.character) == nil
end

function TPFluidTreat:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

function TPFluidTreat:complete()
    return FluidTreat.treatBy(self.container, self.spec, self.treatment, self.character)
end

function TPFluidTreat:perform()
    ISBaseTimedAction.perform(self)
end

function TPFluidTreat:getDuration()
    return Action.duration(self.character, TPFluidTreat.TICKS)
end

function TPFluidTreat:new(character, container, spec, treatment)
    local o = ISBaseTimedAction.new(self, character)
    o.container = container
    o.spec = spec
    o.treatment = treatment
    o.maxTime = o:getDuration()
    return o
end
