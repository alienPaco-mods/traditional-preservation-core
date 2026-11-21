-- Traditional Preservation core: the hand jobs at a Drying Cloth. "spread" spreads a Sheet weighted with two Stones on
-- a square (target: the square), "pickup" picks an empty cloth up and gives them back, "lay" lays carried pieces of one
-- kind as one lot (as many as there is room for), "take" takes lots off (each as its kind gives it: dry, still wet, or
-- dead).
require "TimedActions/ISBaseTimedAction"

TPDryingCloth = ISBaseTimedAction:derive("TPDryingCloth")

local DryingCloth = require "TraditionalPreservationCore/DryingCloth"
local Action = require "TraditionalPreservationCore/Action"
local DURATIONS = { lay = 60, take = 40, spread = 50, pickup = 40 }   -- lay: for each fifth of the cloth the lot covers

-- Whether the character carries the cloth's kit (DryingCloth.KIT), in the main inventory.
function TPDryingCloth.hasKit(character)
    return Action.kitItems(character, DryingCloth.KIT) ~= nil
end

local function clothNow(self)
    if TraditionalPreservationCoreDryingCloth then return TraditionalPreservationCoreDryingCloth.updateCloth(self.station) end
    return DryingCloth.update(self.station)
end

local function carried(self)
    local inventory, here = self.character:getInventory(), {}
    for _, item in ipairs(self.items or {}) do
        if inventory:containsRecursive(item) then table.insert(here, item) end
    end
    return here
end

function TPDryingCloth:isValid()
    if self.mode == "spread" then return self.started or (self.free and TPDryingCloth.hasKit(self.character)) end
    if not self.station:getSquare() then return false end
    if self.mode == "pickup" then return DryingCloth.pickUpRefusal(DryingCloth.recordOf(self.station)) == nil end
    local record = DryingCloth.recordOf(self.station)
    if self.mode == "lay" then
        local items = carried(self)
        return #items > 0 and DryingCloth.fits(record, DryingCloth.kindOf(items[1]:getFullType())) > 0
    end
    for _, id in ipairs(self.lots) do
        if DryingCloth.lotById(record, id) then return true end
    end
    return false
end

function TPDryingCloth:waitToStart()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    return self.character:shouldBeTurning()
end

function TPDryingCloth:start()
    self.started = true
    self:setActionAnim("Loot")
end

function TPDryingCloth:complete()
    if self.mode == "spread" then
        local items = Action.kitItems(self.character, DryingCloth.KIT)
        if not items then return false end
        Action.takeItems(self.character, items)
        local cloth = DryingCloth.spread(self.square, self.sprite)
        if TraditionalPreservationCoreDryingCloth then TraditionalPreservationCoreDryingCloth.updateCloth(cloth) end
        return true
    end
    if self.mode == "pickup" then
        if DryingCloth.pickUpRefusal(DryingCloth.recordOf(self.station)) ~= nil then return false end
        self.square:transmitRemoveItemFromSquare(self.station)
        Action.giveItems(self.character, DryingCloth.KIT)
        return true
    end
    clothNow(self)
    local inventory = self.character:getInventory()
    if self.mode == "lay" then
        local items = carried(self)
        local id, count = nil, 0
        if #items > 0 then id, count = DryingCloth.lay(self.station, items) end
        if id then
            for i = 1, count do Action.removeItem(items[i]) end
        end
    else
        for _, id in ipairs(self.lots) do DryingCloth.take(self.station, id, inventory) end
    end
    clothNow(self)
    return true
end

function TPDryingCloth:perform()
    ISBaseTimedAction.perform(self)
end

function TPDryingCloth:getDuration()
    local times = 1
    local kind = self.mode == "lay" and self.items and self.items[1] and DryingCloth.kindOf(self.items[1]:getFullType())
    if kind then times = math.max(math.ceil(#self.items * kind.room * DryingCloth.SPOTS / DryingCloth.ROOM), 1) end
    return Action.duration(self.character, DURATIONS[self.mode] * times)
end

-- "lay": items are the pieces for one lot; "take": lots are the lots' ids to take off; "pickup": the cloth alone.
function TPDryingCloth:new(character, station, mode, items, lots)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.square = station:getSquare()
    o.mode = mode
    o.items = items
    o.lots = lots or {}
    o.maxTime = o:getDuration()
    return o
end

-- "spread": a cloth of sprite on square; free says the square took it when the menu looked.
function TPDryingCloth.spreadOn(character, square, sprite, free)
    local o = ISBaseTimedAction.new(TPDryingCloth, character)
    o.square = square
    o.sprite = sprite
    o.free = free
    o.mode = "spread"
    o.items, o.lots = {}, {}
    o.maxTime = o:getDuration()
    return o
end
