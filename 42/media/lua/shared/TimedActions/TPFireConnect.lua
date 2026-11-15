-- Traditional Preservation core: Connect something to a fire (Fire.connect: the Smokehouse's flue) by one of
-- its kits, or Disconnect it (kind nil): the kit's back items come back, the rest is lost. The tool stays. Neither
-- while the fire burns (Fire.connectRefusal).
require "TimedActions/ISBaseTimedAction"

TPFireConnect = ISBaseTimedAction:derive("TPFireConnect")

local Action = require "TraditionalPreservationCore/Action"
local Fire = require "TraditionalPreservationCore/Fire"

local function stillFits(self)
    if not self.fire:getSquare() then return false end
    if self.kind then
        return self.target:getSquare() ~= nil and Fire.connectRefusal(self.fire, self.spec, self.target) == nil
    end
    return Fire.connectedTo(self.fire:getModData()[Fire.KEY]) == self.spec.id and not Fire.isBurning(self.fire)
end

function TPFireConnect:isValid()
    return Action.hasTool(self.character, self.kit.tool) and stillFits(self)
        and (not self.kind or Action.kitItems(self.character, self.kit.items) ~= nil)
end

function TPFireConnect:waitToStart()
    self.character:faceThisObject(self.fire)
    return self.character:shouldBeTurning()
end

function TPFireConnect:start()
    self:setActionAnim(CharacterActionAnims[self.kit.anim or "Build"] or CharacterActionAnims.Build)
end

function TPFireConnect:complete()
    if not stillFits(self) then return false end
    local state = Fire.stateOf(self.fire:getModData())
    if self.kind then
        local items = Action.kitItems(self.character, self.kit.items)
        if not items then return false end
        Action.takeItems(self.character, items)
        Fire.join(state, self.spec.id, self.kind, Fire.flueSideTo(self.fire, self.target:getSquare()))
    else
        Action.giveItems(self.character, Fire.kitBack(self.kit))
        Fire.unjoin(state)
    end
    Action.addXp(self.character, self.kit.xp)
    Fire.redraw(self.fire)
    if self.spec.onChange then self.spec.onChange(self.fire, self.target) end
    return true
end

function TPFireConnect:perform()
    ISBaseTimedAction.perform(self)
end

function TPFireConnect:getDuration()
    return Action.duration(self.character, self.kind and self.kit.ticks or self.kit.removeTicks or self.kit.ticks)
end

-- id names the connection, target what it joins (nil when it is gone, for Disconnect); kind is the kit to connect
-- with, nil to disconnect what is joined.
function TPFireConnect:new(character, fire, target, id, kind)
    local o = ISBaseTimedAction.new(self, character)
    o.fire = fire
    o.target = target
    o.spec = Fire.connection(id)
    o.kind = kind
    o.kit = o.spec.kits[kind or Fire.joinOf(fire:getModData()[Fire.KEY])]
    o.maxTime = o:getDuration()
    return o
end
