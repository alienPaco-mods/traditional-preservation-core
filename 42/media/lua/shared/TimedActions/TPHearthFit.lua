-- Traditional Preservation core: Fit an attachment on a Stone Hearth (id given) or Remove what is fitted (id nil),
-- by the attachment's fit (Hearth.attach): its items go into the fit and come back on Remove, all but lost ones. The
-- tool stays. Neither while the fire burns; Remove only when the attachment says it may come off (Hearth.canRemove).
require "TimedActions/ISBaseTimedAction"

TPHearthFit = ISBaseTimedAction:derive("TPHearthFit")

local Action = require "TraditionalPreservationCore/Action"
local Hearth = require "TraditionalPreservationCore/Hearth"

local function toolHere(self)
    return self.character:getInventory():containsTagRecurse(ItemTag[self.spec.fit.tool])
end

-- The fit's items, all in the main inventory (the menu brings them there first).
local function fitItems(self)
    local inventory = self.character:getInventory()
    local items = {}
    for _, need in ipairs(self.spec.fit.items) do
        local found = inventory:getSomeType(need[1], need[2], ArrayList.new())
        if found:size() < need[2] then return nil end
        for i = 0, need[2] - 1 do table.insert(items, found:get(i)) end
    end
    return items
end

local function stillFits(self)
    if not self.fire:getSquare() then return false end
    if self.fitting then return Hearth.fitRefusal(self.fire, self.spec) == nil end
    return Hearth.attachedTo(self.fire) == self.spec.id and Hearth.canRemove(self.fire)
end

function TPHearthFit:isValid()
    return toolHere(self) and stillFits(self) and (not self.fitting or fitItems(self) ~= nil)
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
    local inventory = self.character:getInventory()
    if self.fitting then
        local items = fitItems(self)
        if not items then return false end
        for _, item in ipairs(items) do inventory:Remove(item) end
        Hearth.fit(self.fire, self.spec.id)
    else
        for _, need in ipairs(Hearth.fitBack(self.spec)) do
            for _ = 1, need[2] do inventory:AddItem(need[1]) end
        end
        Hearth.unfit(self.fire)
    end
    local xp = self.spec.fit.xp
    if xp and Perks[xp[1]] then self.character:getXp():AddXP(Perks[xp[1]], xp[2]) end
    if Hearth.World then Hearth.World.refresh(self.fire) end
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
