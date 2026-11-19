-- Traditional Preservation core: the Drying Cloth in the world. Records the weather into the cloth's ledger, and
-- brings every loaded cloth up to now and shows what lies on it (one overlay a lot, each kind's own art).
if isClient() then return end

local DryingCloth = require "TraditionalPreservationCore/DryingCloth"
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"

TraditionalPreservationCoreDryingCloth = TraditionalPreservationCoreDryingCloth or {}
local World = TraditionalPreservationCoreDryingCloth

local function newSessionState(isoObject)
    return DryingCloth.isCloth(isoObject) and {} or nil
end

local function refresh(cloth, sessionState)
    local record = DryingCloth.update(cloth)
    Station.showSprites(cloth, sessionState, DryingCloth.lookKey(record), DryingCloth.lotSprites(record))
end

local tracker = Station.tracker({ sprites = DryingCloth.SPRITES, newSessionState = newSessionState, refresh = refresh, scan = true })

-- Brings a cloth up to now and redraws it at once (after a lay or a take). Returns its record.
function World.updateCloth(cloth)
    local sessionState = tracker.track(cloth)
    if sessionState then refresh(cloth, sessionState) end
    return DryingCloth.recordOf(cloth)
end

Weather.onReading(function(now, climate)
    DryingCloth.recordWeather(now, climate:getTemperature())
end)

tracker.start()
