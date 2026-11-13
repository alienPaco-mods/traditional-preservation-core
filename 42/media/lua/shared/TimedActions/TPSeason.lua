-- Traditional Preservation core: putting a seasoning into a food by hand (Season: Fish & Meat's sausage links), a use
-- of it from what is in reach.
require "TimedActions/ISBaseTimedAction"

TPSeason = ISBaseTimedAction:derive("TPSeason")

local Season = require "TraditionalPreservationCore/Season"
local Action = require "TraditionalPreservationCore/Action"

TPSeason.TICKS = 60

function TPSeason:isValid()
    return self.character:getInventory():containsRecursive(self.item)
        and Season.refusal(self.item, self.fullType, self.character) == nil
end

function TPSeason:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

function TPSeason:complete()
    return Season.season(self.character, self.item, self.fullType)
end

function TPSeason:perform()
    ISBaseTimedAction.perform(self)
end

function TPSeason:getDuration()
    return Action.duration(self.character, TPSeason.TICKS)
end

function TPSeason:new(character, item, fullType)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.fullType = fullType
    o.maxTime = o:getDuration()
    return o
end
