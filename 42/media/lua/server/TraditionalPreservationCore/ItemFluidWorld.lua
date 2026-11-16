-- Traditional Preservation core: keeps fluid that changes in an item (ItemFluid) up to date. Every minute whatever
-- sits steaming on a stove or fire within Station.HEAT_NEAR of a player (it turns, or burns), every ten minutes what
-- each player carries (it goes off); loot windows do the same for the containers they show (ItemFluidUI).
if isClient() then return end

local ItemFluid = require "TraditionalPreservationCore/ItemFluid"
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"

Weather.record(function(now)
    Station.eachPlayer(function(player) ItemFluid.lookIn(player:getInventory(), now) end)
end)

Station.onHeatNear(ItemFluid.lookHeat, ItemFluid.lookIn)
