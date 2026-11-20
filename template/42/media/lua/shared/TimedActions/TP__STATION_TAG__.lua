-- Traditional Preservation (__NAME__) B42: the hand jobs at the __STATION__. "put" puts carried raw batches in as one
-- batch (as many as fit), "take" takes batches out (finished, or raw as they went in).
require "TimedActions/ISBaseTimedAction"

TP__STATION_TAG__ = ISBaseTimedAction:derive("TP__STATION_TAG__")

local Action = require "TraditionalPreservationCore/Action"
local DURATIONS = { put = 40, take = 40 }   -- TEMPLATE: for each raw batch, and for each batch taken

local function stationNow(self)
    if __MOD__World then return __MOD__World.updateStation(self.station) end
    return __MOD__.update(self.station)
end

local function carried(self)
    local inventory, here = self.character:getInventory(), {}
    for _, item in ipairs(self.items or {}) do
        if inventory:containsRecursive(item) then table.insert(here, item) end
    end
    return here
end

function TP__STATION_TAG__:isValid()
    if not self.station:getSquare() then return false end
    local record = __MOD__.recordOf(self.station)
    if self.mode == "put" then return #carried(self) > 0 and __MOD__.fits(record) > 0 end
    for _, id in ipairs(self.batches) do
        if __MOD__.batchById(record, id) then return true end
    end
    return false
end

function TP__STATION_TAG__:waitToStart()
    self.character:faceThisObject(self.station)
    return self.character:shouldBeTurning()
end

function TP__STATION_TAG__:start()
    self:setActionAnim("Loot")
end

function TP__STATION_TAG__:complete()
    stationNow(self)
    if self.mode == "put" then
        local items = carried(self)
        local id, count = __MOD__.put(self.station, #items)
        if id then
            for i = 1, count do Action.removeItem(items[i]) end
        end
    else
        local inventory = self.character:getInventory()
        for _, id in ipairs(self.batches) do __MOD__.take(self.station, id, inventory) end
    end
    stationNow(self)
    return true
end

function TP__STATION_TAG__:perform()
    ISBaseTimedAction.perform(self)
end

function TP__STATION_TAG__:getDuration()
    local times = self.mode == "put" and #(self.items or {}) or #self.batches
    return Action.duration(self.character, DURATIONS[self.mode] * math.max(times, 1))
end

-- "put": items are the raw batches; "take": batches are the batches' ids.
function TP__STATION_TAG__:new(character, station, mode, items, batches)
    local o = ISBaseTimedAction.new(self, character)
    o.station = station
    o.mode = mode
    o.items = items
    o.batches = batches or {}
    o.maxTime = o:getDuration()
    return o
end
