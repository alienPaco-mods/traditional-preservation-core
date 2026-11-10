-- Traditional Preservation core: keeps the age of fluids that go off (FluidAgeing) as they move. Every ten minutes what
-- each player carries is brought up to date; loot windows do the same for the containers they show (FluidAgeingUI).
-- Vanilla's pouring hands the source's age to the target before any fluid moves, and milking into a container whose
-- milk is all gone starts a new record.
if isClient() then return end

local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"

Weather.record(function(now)
    local list = Station.players()
    for i = 0, list:size() - 1 do FluidAgeing.lookIn(list:get(i):getInventory(), now) end
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

local vanillaMilk = ISMilkAnimal.milk
function ISMilkAnimal:milk()
    FluidAgeing.clearIfEmpty(self.bucket)
    return vanillaMilk(self)
end
