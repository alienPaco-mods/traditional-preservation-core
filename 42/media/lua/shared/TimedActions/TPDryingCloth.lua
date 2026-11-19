-- Traditional Preservation core: the hand jobs at a Drying Cloth. "lay" lays carried pieces of one kind on the next
-- free lot (up to the kind's perLot), "take" takes lots off (each as its kind gives it: dry, still wet, or dead).
require "TimedActions/ISBaseTimedAction"

TPDryingCloth = ISBaseTimedAction:derive("TPDryingCloth")

local DryingCloth = require "TraditionalPreservationCore/DryingCloth"
local Action = require "TraditionalPreservationCore/Action"
local DURATIONS = { lay = 60, take = 40 }

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
    if self.mode == "lay" then return #carried(self) > 0 and DryingCloth.freeLots(record) > 0 end
    for _, i in ipairs(self.lots) do
        if record.lots[i] then return true end
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
        if #items > 0 and DryingCloth.lay(self.station, items) then
            for _, item in ipairs(items) do Action.removeItem(item) end
        end
    else
        for _, i in ipairs(self.lots) do DryingCloth.take(self.station, i, inventory) end
    end
    clothNow(self)
    return true
end

function TPDryingCloth:perform()
    ISBaseTimedAction.perform(self)
end

function TPDryingCloth:getDuration()
    return Action.duration(self.character, DURATIONS[self.mode])
end

-- "lay": items are the pieces for one lot; "take": lots are the lot numbers (1 to LOTS) to take off.
function TPDryingCloth:new(character, station, mode, items, lots)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.mode = mode
    o.items = items
    o.lots = lots or {}
    o.maxTime = o:getDuration()
    return o
end
