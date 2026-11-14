-- Traditional Preservation core: Fit an attachment on a Stone Hearth (id given) or Remove what is fitted (id nil),
-- by the attachment's fit (Hearth.attach): its items go into the fit and come back on Remove, all but lost ones. The
-- tool stays. Neither while the fire burns; Remove only when the attachment says it may come off (Hearth.canRemove).
require "TimedActions/ISBaseTimedAction"

TPHearthFit = ISBaseTimedAction:derive("TPHearthFit")

local Action = require "TraditionalPreservationCore/Action"
local Hearth = require "TraditionalPreservationCore/Hearth"

local function stillFits(self)
    if not self.fire:getSquare() then return false end
    if self.fitting then return Hearth.fitRefusal(self.fire, self.spec) == nil end
    return Hearth.attachedTo(self.fire) == self.spec.id and Hearth.canRemove(self.fire)
end

function TPHearthFit:isValid()
    return Action.hasTool(self.character, self.spec.fit.tool) and stillFits(self)
        and (not self.fitting or Action.kitItems(self.character, self.spec.fit.items) ~= nil)
end

function TPHearthFit:waitToStart()
    self.character:faceThisObject(self.fire)
    return self.character:shouldBeTurning()
end

function TPHearthFit:start()
    self:setActionAnim(CharacterActionAnims.Build)
end

function TPHearthFit:complete()
    if not stillFits(self) then return false end
    if self.fitting then
        local items = Action.kitItems(self.character, self.spec.fit.items)
        if not items then return false end
        Action.takeItems(self.character, items)
        Hearth.fit(self.fire, self.spec.id)
    else
        Action.giveItems(self.character, Hearth.fitBack(self.spec))
        Hearth.unfit(self.fire)
    end
    Action.addXp(self.character, self.spec.fit.xp)
    Hearth.redraw(self.fire)
    return true
end

function TPHearthFit:perform()
    ISBaseTimedAction.perform(self)
end

function TPHearthFit:getDuration()
    local fit = self.spec.fit
    return Action.duration(self.character, self.fitting and fit.ticks or fit.removeTicks or fit.ticks)
end

-- id names the attachment to fit; nil removes what is fitted.
function TPHearthFit:new(character, fire, id)
    local o = ISBaseTimedAction.new(self, character)
    o.fire = fire
    o.fitting = id ~= nil
    o.spec = Hearth.attachment(id or Hearth.attachedTo(fire))
    o.maxTime = o:getDuration()
    return o
end
