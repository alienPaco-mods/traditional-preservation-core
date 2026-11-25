-- Traditional Preservation core: brings every loaded animal's days up to now each in-game hour (AnimalDays).
if isClient() then return end

local AnimalDays = require "TraditionalPreservationCore/AnimalDays"

Events.EveryHours.Add(function()
    AnimalDays.keepAll(getCell():getAnimals(), getGameTime():getWorldAgeHours())
end)
