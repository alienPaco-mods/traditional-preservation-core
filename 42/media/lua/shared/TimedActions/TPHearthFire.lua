-- Traditional Preservation core: banking a Hearth's fire down under its ash ("bank"), stoking it up again ("stoke"),
-- or putting a banked fire out ("out", vanilla's Put out Fire). A banked fire burns a third of the wood, keeps the
-- cauldron about 50 C, warms only beside it and cooks a third as fast.
require "TimedActions/ISBaseTimedAction"
local Hearth = require "TraditionalPreservationCore/Hearth"
local Action = require "TraditionalPreservationCore/Action"

TPHearthFire = ISBaseTimedAction:derive("TPHearthFire")

local DURATION = 100

function TPHearthFire:isValid()
    if not self.hearth:getSquare() or not Hearth.isBurning(self.hearth) then return false end
    return Hearth.isBanked(self.hearth) == (self.mode ~= "bank")
end

function TPHearthFire:waitToStart()
    self.character:faceThisObject(self.hearth)
    return self.character:shouldBeTurning()
end

function TPHearthFire:start()
    self:setActionAnim("Loot")
end

function TPHearthFire:complete()
    if Hearth.World then Hearth.World.setFire(self.hearth, self.mode, getGameTime():getWorldAgeHours()) end
    return true
end

function TPHearthFire:perform()
    ISBaseTimedAction.perform(self)
end

function TPHearthFire:getDuration()
    return Action.duration(self.character, DURATION)
end

function TPHearthFire:new(character, hearth, mode)
    local o = ISBaseTimedAction.new(self, character)
    o.hearth = hearth
    o.mode = mode
    o.maxTime = o:getDuration()
    return o
end
