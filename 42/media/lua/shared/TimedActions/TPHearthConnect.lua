-- Traditional Preservation core: Connect something to a Stone Hearth (Hearth.connect: the Smokehouse's flue) by one of
-- its kits, or Disconnect it (kind nil): the kit's back items come back, the rest is lost. The tool stays. Neither
-- while the fire burns (Hearth.connectRefusal).
require "TimedActions/ISBaseTimedAction"

TPHearthConnect = ISBaseTimedAction:derive("TPHearthConnect")

local Action = require "TraditionalPreservationCore/Action"
local Hearth = require "TraditionalPreservationCore/Hearth"

local function toolHere(self)
    return self.character:getInventory():containsTagRecurse(ItemTag[self.kit.tool])
end

-- The kit's items, all in the main inventory (the menu brings them there first).
local function kitItems(self)
    local inventory = self.character:getInventory()
    local items = {}
    for _, need in ipairs(self.kit.items) do
        local found = inventory:getSomeType(need[1], need[2], ArrayList.new())
        if found:size() < need[2] then return nil end
        for i = 0, need[2] - 1 do table.insert(items, found:get(i)) end
    end
    return items
end

local function stillFits(self)
    if not self.fire:getSquare() then return false end
    if self.kind then
        return self.target:getSquare() ~= nil and Hearth.connectRefusal(self.fire, self.spec, self.target) == nil
    end
    return Hearth.connectedTo(self.fire:getModData()[Hearth.KEY]) == self.spec.id and not Hearth.isBurning(self.fire)
end

function TPHearthConnect:isValid()
    return toolHere(self) and stillFits(self) and (not self.kind or kitItems(self) ~= nil)
end

function TPHearthConnect:waitToStart()
    self.character:faceThisObject(self.fire)
    return self.character:shouldBeTurning()
end

function TPHearthConnect:start()
    self:setActionAnim(CharacterActionAnims[self.kit.anim or "Build"] or CharacterActionAnims.Build)
end

function TPHearthConnect:complete()
    if not stillFits(self) then return false end
    local inventory = self.character:getInventory()
    local state = Hearth.stateOf(self.fire:getModData())
    if self.kind then
        local items = kitItems(self)
        if not items then return false end
        for _, item in ipairs(items) do inventory:Remove(item) end
        Hearth.join(state, self.spec.id, self.kind, Hearth.flueSideTo(self.fire, self.target:getSquare()))
    else
        for _, need in ipairs(Hearth.kitBack(self.kit)) do
            for _ = 1, need[2] do inventory:AddItem(need[1]) end
        end
        Hearth.unjoin(state)
    end
    local xp = self.kit.xp
    if xp and Perks[xp[1]] then self.character:getXp():AddXP(Perks[xp[1]], xp[2]) end
    if Hearth.World then Hearth.World.refresh(self.fire) end
    if self.spec.onChange then self.spec.onChange(self.fire, self.target) end
    return true
end

function TPHearthConnect:perform()
    ISBaseTimedAction.perform(self)
end

function TPHearthConnect:getDuration()
    return Action.duration(self.character, self.kind and self.kit.ticks or self.kit.removeTicks or self.kit.ticks)
end

-- id names the connection, target what it joins (nil when it is gone, for Disconnect); kind is the kit to connect
-- with, nil to disconnect what is joined.
function TPHearthConnect:new(character, fire, target, id, kind)
    local o = ISBaseTimedAction.new(self, character)
    o.fire = fire
    o.target = target
    o.spec = Hearth.connection(id)
    o.kind = kind
    o.kit = o.spec.kits[kind or Hearth.joinOf(fire:getModData()[Hearth.KEY])]
    o.maxTime = o:getDuration()
    return o
end
