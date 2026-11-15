-- Traditional Preservation core: banking a Stone Hearth's fire down under its ash ("bank"), stoking it up again ("stoke"),
-- or putting a banked fire out ("out", vanilla's Put out Fire). A banked fire burns a third of the wood, keeps the
-- cauldron about 50 C, warms only beside it and cooks a third as fast.
require "TimedActions/ISBaseTimedAction"
local Fire = require "TraditionalPreservationCore/Fire"
local Action = require "TraditionalPreservationCore/Action"

TPFireTend = ISBaseTimedAction:derive("TPFireTend")

local DURATION = 100

function TPFireTend:isValid()
    if not self.hearth:getSquare() or not Fire.isBurning(self.hearth) then return false end
    return Fire.isBanked(self.hearth) == (self.mode ~= "bank")
end

function TPFireTend:waitToStart()
    self.character:faceThisObject(self.hearth)
    return self.character:shouldBeTurning()
end

function TPFireTend:start()
    self:setActionAnim("Loot")
end

function TPFireTend:complete()
    if Fire.World then Fire.World.setFire(self.hearth, self.mode, getGameTime():getWorldAgeHours()) end
    return true
end

function TPFireTend:perform()
    ISBaseTimedAction.perform(self)
end

function TPFireTend:getDuration()
    return Action.duration(self.character, DURATION)
end

function TPFireTend:new(character, hearth, mode)
    local o = ISBaseTimedAction.new(self, character)
    o.hearth = hearth
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
