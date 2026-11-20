-- Traditional Preservation core: records the weather into the frost ledger every ten minutes (Frost).
if isClient() then return end

local Frost = require "TraditionalPreservationCore/Frost"
local Weather = require "TraditionalPreservationCore/Weather"

Weather.onReading(function(now, climate)
    Frost.recordWeather(now, climate:getTemperature())
end)
