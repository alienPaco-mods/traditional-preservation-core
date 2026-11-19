-- Traditional Preservation core: keeps track of every Smokehouse chamber tile and draws its look. The chamber is
-- closed: nothing hangs in sight. Each tile shows where a joined Stone Hearth's flue enters it; the front row what
-- hangs by the door while finished pieces wait (Smokehouse.pieceSprites) and the vent's smoke while the joined fire
-- burns (Smokehouse.smokeSprite). What hangs inside is each mod's record, stepped by that mod.
if isClient() then return end

local Smokehouse = require "TraditionalPreservationCore/Smokehouse"
local Station = require "TraditionalPreservationCore/Station"
local Tiles = require "TraditionalPreservationCore/Tiles"

local World = {}
Smokehouse.World = World

local function refresh(station, sessionState)
    local face, part, col = Smokehouse.tileOf(station)
    local sprites = {}
    local flue = Smokehouse.chamberEntry(station)
    if flue then table.insert(sprites, Smokehouse.spriteName(flue)) end
    if part == 1 then
        for _, piece in ipairs(Smokehouse.pieceSprites(face, part, col, Smokehouse.finishedPieces(station))) do
            table.insert(sprites, Smokehouse.spriteName(piece))
        end
        local smoke = Smokehouse.smokeSprite(face, part, col, Smokehouse.smokeLook(station))
        if smoke then table.insert(sprites, Smokehouse.spriteName(smoke)) end
    end
    Station.showSprites(station, sessionState, table.concat(sprites, ","), sprites)
end

local function newSessionState(station)
    if not Smokehouse.isChamber(station) then return nil end
    return {}
end

local tracker = Station.tracker({ sprites = Tiles.CHAMBERS, newSessionState = newSessionState, refresh = refresh, scan = true })

World.track = tracker.track

-- Redraws a chamber tile now, without waiting for the next tick, e.g. after the flue is laid.
function World.refresh(station)
    local sessionState = tracker.track(station)
    if sessionState then refresh(station, sessionState) end
end

tracker.start()

return World
