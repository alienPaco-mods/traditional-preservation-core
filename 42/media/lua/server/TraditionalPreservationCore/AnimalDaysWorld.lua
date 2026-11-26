-- Traditional Preservation core: brings every loaded animal's days up to now every ten in-game minutes (AnimalDays),
-- so a pen's catch-up on coming back (vanilla's part-day loss, its double midnight) is set right within ten minutes,
-- before a save taken just after arriving (user, 2026-11-26).
if isClient() then return end

local AnimalDays = require "TraditionalPreservationCore/AnimalDays"

Events.EveryTenMinutes.Add(function()
    AnimalDays.keepAll(getCell():getAnimals(), getGameTime():getWorldAgeHours())
end)
