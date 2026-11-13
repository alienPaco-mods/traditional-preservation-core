-- Traditional Preservation core: Connect the Firebox to the Smokehouse chamber with a clay pipe or a stone
-- trench, or Disconnect it (kind nil): the pipe segments or flat stones come back, the clay is lost. The tool stays.
require "TimedActions/ISBaseTimedAction"

TPFlue = ISBaseTimedAction:derive("TPFlue")

local Smokehouse = require "TraditionalPreservationCore/Smokehouse"
local Action = require "TraditionalPreservationCore/Action"
local Hearth = require "TraditionalPreservationCore/Hearth"

local function toolHere(self)
    return self.character:getInventory():containsTagRecurse(ItemTag[self.tool])
end

-- The kit's items, all in the main inventory (the menu brings them there first).
local function kitItems(self)
    local inventory = self.character:getInventory()
    local items = {}
    for _, need in ipairs(Smokehouse.FLUE_KITS[self.kind].items) do
        local found = inventory:getSomeType(need[1], need[2], ArrayList.new())
        if found:size() < need[2] then return nil end
        for i = 0, need[2] - 1 do table.insert(items, found:get(i)) end
    end
    return items
end

local function stillFits(self)
    if not self.firebox:getSquare() or not self.tile:getSquare() or Hearth.isBurning(self.firebox) then return false end
    if self.kind then return Smokehouse.flueOf(self.firebox) == nil and Smokehouse.joinedFirebox(self.tile) == nil end
    return Smokehouse.flueOf(self.firebox) ~= nil
end

function TPFlue:isValid()
    return toolHere(self) and stillFits(self) and (not self.kind or kitItems(self) ~= nil)
end

function TPFlue:waitToStart()
    self.character:faceThisObject(self.firebox)
    return self.character:shouldBeTurning()
end

function TPFlue:start()
    self:setActionAnim(self.kind == "Stones" and CharacterActionAnims.DigShovel or CharacterActionAnims.Build)
end

function TPFlue:complete()
    if not stillFits(self) then return false end
    local inventory = self.character:getInventory()
    if self.kind then
        local items = kitItems(self)
        if not items then return false end
        for _, item in ipairs(items) do inventory:Remove(item) end
        Smokehouse.setFlue(self.firebox, self.tile, self.kind)
    else
        local kit = Smokehouse.FLUE_KITS[Smokehouse.flueOf(self.firebox)]
        for _, need in ipairs(kit.items) do
            if need[1] == kit.back then
                for _ = 1, need[2] do inventory:AddItem(need[1]) end
            end
        end
        Smokehouse.setFlue(self.firebox, self.tile, nil)
    end
    self.character:getXp():AddXP(Perks.Masonry, Smokehouse.CONNECT_XP)
    return true
end

function TPFlue:perform()
    ISBaseTimedAction.perform(self)
end

function TPFlue:getDuration()
    return Action.duration(self.character, self.kind and Smokehouse.CONNECT_TICKS or Smokehouse.DISCONNECT_TICKS)
end

-- kind is Pipe or Stones to connect, nil to disconnect; tool is the kit's ItemTag name.
function TPFlue:new(character, firebox, tile, kind, tool)
    local o = ISBaseTimedAction.new(self, character)
    o.firebox = firebox
    o.tile = tile
    o.kind = kind
    o.tool = tool
    o.maxTime = o:getDuration()
    return o
end
