-- Traditional Preservation core: keeps the age of fluids that go off (FluidAgeing) as they move. Every ten minutes what
-- each player carries is brought up to date, and every minute whatever sits on a lit stove or fire near them (it may
-- scald); loot windows do the same for the containers they show, and an item taken off the heat is looked at as it
-- goes (FluidAgeingUI). Both ends of a pour are looked at as it ends, so mixed milk is renamed at once.
-- Vanilla's pouring hands the source's age to the target before any fluid moves (through the core's Pour, the one
-- wrap of the transfer action), and milking into a container whose milk is all gone starts a new record.
if isClient() then return end

local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"
local Pour = require "TraditionalPreservationCore/Pour"

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

local owner = Pour.owner

Pour.before("start", function(action)
    local source, target = owner(action.source), owner(action.target)
    if source and target then FluidAgeing.pour(source, target, getGameTime():getWorldAgeHours()) end
end)

local function lookAtBoth(action)
    local now = getGameTime():getWorldAgeHours()
    local source, target = owner(action.source), owner(action.target)
    if source then FluidAgeing.look(source, now) end
    if target then FluidAgeing.look(target, now) end
end

Pour.after("stop", lookAtBoth)
Pour.after("complete", lookAtBoth)

local vanillaMilk = ISMilkAnimal.milk
function ISMilkAnimal:milk()
    FluidAgeing.clearIfEmpty(self.bucket)
    return vanillaMilk(self)
end

-- Bleeding a carcass (vanilla's ISGatherBloodFromAnimal adds blood a tick at a time), for a mod that ages blood
-- (Fish & Meat): a container holding none of the kind starts a new record, and fresh blood gathered onto treated
-- blood makes the lot untreated, as pouring does. Nothing happens to a fluid no kind is registered for.
if not ISGatherBloodFromAnimal then pcall(require, "TimedActions/Animals/ISGatherBloodFromAnimal") end
if ISGatherBloodFromAnimal then
    local vanillaUpdateBucket = ISGatherBloodFromAnimal.updateBucket
    function ISGatherBloodFromAnimal:updateBucket()
        FluidAgeing.clearIfEmpty(self.bucket)
        local result = vanillaUpdateBucket(self)
        if self.bucket then FluidAgeing.untreat(self.bucket, getGameTime():getWorldAgeHours()) end
        return result
    end
end
