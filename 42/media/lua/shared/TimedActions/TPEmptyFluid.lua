-- Traditional Preservation core: throwing away a fluid that stays in its vessel (ItemFluid.staysIn: raw butter in a
-- pot). Vanilla's Empty refuses a sealed container, and the seal is what keeps the fluid from being poured into
-- another to dodge its clock; emptying it out loses it, so this always may. ItemFluidUI puts it in the Fluid menu.
require "TimedActions/ISBaseTimedAction"

TPEmptyFluid = ISBaseTimedAction:derive("TPEmptyFluid")

local ItemFluid = require "TraditionalPreservationCore/ItemFluid"
local Action = require "TraditionalPreservationCore/Action"

function TPEmptyFluid:isValid()
    local container = self.item:getFluidContainer()
    return self.character:getInventory():containsRecursive(self.item) and container ~= nil and not container:isEmpty()
end

function TPEmptyFluid:start()
    self:setActionAnim(CharacterActionAnims.Pour)
end

-- Emptied, the item forgets its record and is unsealed (ItemFluid.look).
function TPEmptyFluid:complete()
    self.item:getFluidContainer():Empty()
    ItemFluid.look(self.item, getGameTime():getWorldAgeHours())
    return true
end

function TPEmptyFluid:perform()
    ISBaseTimedAction.perform(self)
end

function TPEmptyFluid:getDuration()
    local litres = self.item:getFluidContainer():getAmount()
    return Action.pourDuration(self.character, litres, litres)
end

function TPEmptyFluid:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.maxTime = o:getDuration()
    return o
end
