-- Traditional Preservation core: the hand jobs at a Drying Cloth. "lay" lays carried pieces of one kind as one lot
-- (as many as there is room for), "take" takes lots off (each as its kind gives it: dry, still wet, or dead).
require "TimedActions/ISBaseTimedAction"

TPDryingCloth = ISBaseTimedAction:derive("TPDryingCloth")

local DryingCloth = require "TraditionalPreservationCore/DryingCloth"
local Action = require "TraditionalPreservationCore/Action"
local DURATIONS = { lay = 60, take = 40 }   -- lay: for each fifth of the cloth the lot covers

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
    if not self.station:getSquare() then return false end
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
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function TPDryingCloth:start()
    self:setActionAnim("Loot")
end

function TPDryingCloth:complete()
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

-- "lay": items are the pieces for one lot; "take": lots are the lots' ids to take off.
function TPDryingCloth:new(character, station, mode, items, lots)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.mode = mode
    o.items = items
    o.lots = lots or {}
    o.maxTime = o:getDuration()
    return o
end
