-- Traditional Preservation core: banking a Hearth's fire down under its ash ("bank"), or stoking it up again
-- ("stoke"). A banked fire burns a third of the wood, keeps the copper about 50 C and cooks a third as fast.
require "TimedActions/ISBaseTimedAction"
local Hearth = require "TraditionalPreservationCore/Hearth"
local Action = require "TraditionalPreservationCore/Action"

TPHearthFire = ISBaseTimedAction:derive("TPHearthFire")

local DURATION = 100

function TPHearthFire:isValid()
    if not self.hearth:getSquare() or not self.hearth:isLit() then return false end
    return Hearth.isBanked(self.hearth) == (self.mode == "stoke")
end

function TPHearthFire:waitToStart()
    self.character:faceThisObject(self.hearth)
    return self.character:shouldBeTurning()
end

function TPHearthFire:start()
    self:setActionAnim("Loot")
end

function TPHearthFire:complete()
    -- Brought up to the minute first, so the copper heated as the fire was until now.
    local state = Hearth.copperOf(self.hearth)
    Hearth.setBanked(state, self.mode == "bank", self.hearth:getFuelAmount(), getGameTime():getWorldAgeHours())
    if Hearth.World then Hearth.World.refresh(self.hearth) end
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
