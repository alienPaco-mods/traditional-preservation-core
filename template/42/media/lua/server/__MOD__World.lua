-- Traditional Preservation (__NAME__) B42: keeps track of every __STATION__, records the weather and tells each
-- running batch where its station stands. TEMPLATE: layer attached sprites here to show the station's state
-- (Station.showSprites; Yeast's shelf shows one jar per culture).
if isClient() then return end

__MOD__World = __MOD__World or {}
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"
local Tiles = require "__MOD__/Tiles"

local function refresh(station, entry)
    local logic = station:getComponent(ComponentType.CraftLogic)
    if not logic then return end
    local uiLogic = Station.uiLogic(station, entry, logic)
    if not uiLogic then return end
    local now = getGameTime():getWorldAgeHours()
    for craftData in pairs(uiLogic:getItemsInProgress()) do
        __MOD__.notePlace(craftData:getModData(), station, now)
    end
end

local tracker = Station.tracker({ sprites = Tiles.STATIONS, refresh = refresh })

__MOD__World.track = tracker.track

Weather.record(function(now, climate)
    local M = __MOD__
    M.advance(M.getLedger(), now, climate:getTemperature())
end)

tracker.start()
