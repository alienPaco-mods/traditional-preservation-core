-- Traditional Preservation core: keeps the age of fluids that go off (FluidAgeing) as they move. Every ten minutes what
-- each player carries is brought up to date, and every minute whatever sits on a lit stove or fire near them (it may
-- scald); loot windows do the same for the containers they show, and an item taken off the heat is looked at as it
-- goes (FluidAgeingUI). Both ends of a pour are looked at as it ends, so mixed milk is renamed at once.
-- Vanilla's pouring hands the source's age to the target before any fluid moves, and milking into a container whose
-- milk is all gone starts a new record.
if isClient() then return end

local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"

Weather.record(function(now)
    local list = Station.players()
    for i = 0, list:size() - 1 do
        local player = list:get(i)
        FluidAgeing.lookIn(player:getInventory(), now)
    end
end)

Events.EveryOneMinute.Add(function()
    local now, list = getGameTime():getWorldAgeHours(), Station.players()
    for i = 0, list:size() - 1 do FluidAgeing.lookOnHeat(list:get(i):getSquare(), now) end
end)

local function owner(fluidObject)
    local o = fluidObject and fluidObject:getOwner()
    if instanceof(o, "InventoryItem") or instanceof(o, "IsoObject") then return o end
end

local vanillaTransferStart = ISFluidTransferAction.start
function ISFluidTransferAction:start()
    local source, target = owner(self.source), owner(self.target)
    if source and target then FluidAgeing.pour(source, target, getGameTime():getWorldAgeHours()) end
    return vanillaTransferStart(self)
end

local function lookAtBoth(self)
    local now = getGameTime():getWorldAgeHours()
    local source, target = owner(self.source), owner(self.target)
    if source then FluidAgeing.look(source, now) end
    if target then FluidAgeing.look(target, now) end
end

local vanillaTransferStop, vanillaTransferComplete = ISFluidTransferAction.stop, ISFluidTransferAction.complete
function ISFluidTransferAction:stop()
    local result = vanillaTransferStop(self)
    lookAtBoth(self)
    return result
end

function ISFluidTransferAction:complete()
    local result = vanillaTransferComplete(self)
    lookAtBoth(self)
    return result
end

local vanillaMilk = ISMilkAnimal.milk
function ISMilkAnimal:milk()
    FluidAgeing.clearIfEmpty(self.bucket)
    return vanillaMilk(self)
end
