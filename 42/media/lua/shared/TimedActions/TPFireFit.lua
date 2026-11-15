-- Traditional Preservation core: Fit an attachment on a Stone Hearth (id given) or Remove what is fitted (id nil),
-- by the attachment's fit (Fire.attach): its items go into the fit and come back on Remove, all but lost ones. The
-- tool stays. Neither while the fire burns; Remove only when the attachment says it may come off (Fire.canRemove).
require "TimedActions/ISBaseTimedAction"

TPFireFit = ISBaseTimedAction:derive("TPFireFit")

local Action = require "TraditionalPreservationCore/Action"
local Fire = require "TraditionalPreservationCore/Fire"

local function stillFits(self)
    if not self.fire:getSquare() then return false end
    if self.fitting then return Fire.fitRefusal(self.fire, self.spec) == nil end
    return Fire.attachedTo(self.fire) == self.spec.id and Fire.canRemove(self.fire)
end

function TPFireFit:isValid()
    return Action.hasTool(self.character, self.spec.fit.tool) and stillFits(self)
        and (not self.fitting or Action.kitItems(self.character, self.spec.fit.items) ~= nil)
end

function TPFireFit:waitToStart()
    self.character:faceThisObject(self.fire)
    return self.character:shouldBeTurning()
end

function TPFireFit:start()
    self:setActionAnim(CharacterActionAnims.Build)
end

function TPFireFit:complete()
    if not stillFits(self) then return false end
    if self.fitting then
        local items = Action.kitItems(self.character, self.spec.fit.items)
        if not items then return false end
        Action.takeItems(self.character, items)
        Fire.fit(self.fire, self.spec.id)
    else
        Action.giveItems(self.character, Fire.fitBack(self.spec))
        Fire.unfit(self.fire)
    end
    Action.addXp(self.character, self.spec.fit.xp)
    Fire.redraw(self.fire)
    return true
end

function TPFireFit:perform()
    ISBaseTimedAction.perform(self)
end

function TPFireFit:getDuration()
    local fit = self.spec.fit
    return Action.duration(self.character, self.fitting and fit.ticks or fit.removeTicks or fit.ticks)
end

-- id names the attachment to fit; nil removes what is fitted.
function TPFireFit:new(character, fire, id)
    local o = ISBaseTimedAction.new(self, character)
    o.fire = fire
    o.fitting = id ~= nil
    o.spec = Fire.attachment(id or Fire.attachedTo(fire))
    o.maxTime = o:getDuration()
    return o
end
