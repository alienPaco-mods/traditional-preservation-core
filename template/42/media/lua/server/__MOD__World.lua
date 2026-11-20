-- Traditional Preservation (__NAME__) B42: keeps track of every __STATION__, records the weather and brings each
-- loaded station's batches up to now. TEMPLATE: layer attached sprites here to show the station's state
-- (Station.showSprites; the Drying Cloth shows one overlay a lot).
if isClient() then return end

__MOD__World = __MOD__World or {}
local World = __MOD__World
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"
local Tiles = require "__MOD__/Tiles"

local function newSessionState(isoObject)
    return __MOD__.isStation(isoObject) and {} or nil
end

local function refresh(station, _sessionState)
    __MOD__.update(station)
end

local tracker = Station.tracker({ sprites = Tiles.STATIONS, newSessionState = newSessionState, refresh = refresh, scan = true })

-- Brings a station up to now at once (after a put or a take). Returns its record.
function World.updateStation(station)
    local sessionState = tracker.track(station)
    if sessionState then refresh(station, sessionState) end
    return __MOD__.recordOf(station)
end

Weather.onReading(function(now, climate)
    local M = __MOD__
    M.advance(M.getLedger(), now, climate:getTemperature())
end)

tracker.start()
