-- Traditional Preservation core: "by a fire", a place of its own (Fire.PLACE, at Fire.FIRE_C): any lit fire within
-- Fire.FIRE_RADIUS tiles on the same floor, one of ours or not. Indoors it holds FIRE_C whatever the weather; under an
-- open roof or in the open the air takes the heat away, so there it is that place's air plus Fire.FIRE_LIFT, never
-- past FIRE_C (places PLACE .. "Covered", .. "Open"; a campfire in a January field is cold at the back). Beside banked
-- embers it is Fire.EMBERS. It is opt-in: Weather.placeOf never returns it, placeOf here does, so only a mod that
-- asks for it gets it. And the weather-timed work done there: catchUp, notePlace.
-- Fire passes every function here on (Fire.placeOf, Fire.catchUp, ...), so callers name Fire only; the
-- places' numbers are Fire's (they are registered with Weather when Fire loads).
local Weather = require "TraditionalPreservationCore/Weather"
local Station = require "TraditionalPreservationCore/Station"
local Fire = require "TraditionalPreservationCore/Fire"

local Fireside = {}

-- The heat of a place by a fire, lit or banked, by the ledger's weather; nil for any other place, and for a fire
-- under a roof or in the open without a ledger.
function Fireside.fireC(place, ledger)
    local fire = Weather.FIRE_PLACES[place]
    if not fire or (fire.placeWithoutFire and not ledger) then return nil end
    return Weather.placeTemperature(ledger or {}, place)
end

function Fireside.isFirePlace(place)
    return Weather.FIRE_PLACES[place] ~= nil
end

-- A fire's place (PLACE or EMBERS) where it warms under (Weather.placeOf): its own outside, plain indoors.
function Fireside.firePlace(place, placeWithoutFire)
    if Fire.FIRE_LIFT[placeWithoutFire] then return place .. placeWithoutFire end
    return place
end

-- Fireplaces, antique ovens, braziers, cooking pits and burn barrels are IsoFireplace; a player's campfire is a
-- plain object named "Campfire" whose lit state the camping system copies into its modData (ENGINE_NOTES).
local function isLitFire(isoObject)
    if instanceof(isoObject, "IsoFireplace") then return Fire.isBurning(isoObject) end
    return isoObject:getName() == "Campfire" and isoObject:getModData().isLit == true
end

-- Every object within FIRE_RADIUS tiles on the same floor that passes test, nearest first.
function Fireside.near(square, test)
    return Station.near(square, Fire.FIRE_RADIUS, test)
end

-- The warmest lit fire within FIRE_RADIUS tiles on the same floor, the nearest of those, with its place (PLACE, or
-- EMBERS for a banked fire); nil if there is none.
local function warmestFire(square)
    local fires = Fireside.near(square, isLitFire)
    for _, fire in ipairs(fires) do
        if not Fire.isBanked(fire) then return fire, Fire.PLACE end
    end
    if fires[1] then return fires[1], Fire.EMBERS end
end

-- Fires with the attachment id fitted within FIRE_RADIUS tiles, nearest first.
function Fireside.fittedNear(square, id)
    return Fireside.near(square, function(isoObject) return Fire.isFitted(isoObject, id) end)
end

-- The opt-in place: by a fire (or by banked embers), else below ground, under a roof or in the open. The fire, if any, comes second.
function Fireside.placeOf(isoObject)
    local square = isoObject and isoObject:getSquare()
    local fire, place
    if square then fire, place = warmestFire(square) end
    if fire then return Fireside.firePlace(place, Weather.placeOf(isoObject)), fire end
    return Weather.placeOf(isoObject)
end

-- The work done since the marks at place, which may be by a fire (placeOf), and moves the marks on (Weather.mark).
-- The ledger keeps totals for the weather's places only, so time by a fire counts by the clock at its heat, rateAt
-- the work's rate at a temperature, until the fire's noted fuel ran out (stationModData.fireUntil, noteFire). The ledger's
-- totals can't be split at that hour, so the place under the fire (stationModData.placeWithoutFire, else Fire.DEFAULT_PLACE_WITHOUT_FIRE) gets its
-- share of the gap's weather by time. Marks taken without an hour count from the ledger's last record.
function Fireside.catchUp(stationModData, marks, ledger, process, place, rateAt)
    local work
    if Fireside.isFirePlace(place) then
        local from, to = marks.hour or ledger.lastHour, ledger.lastHour
        local byFire = math.max(math.min(stationModData.fireUntil or to, to) - from, 0)
        work = byFire * rateAt(Fireside.fireC(place, ledger))
        if to - from > byFire then
            local placeWithoutFire = stationModData.placeWithoutFire or Fire.DEFAULT_PLACE_WITHOUT_FIRE
            work = work + Weather.catchUp(marks, ledger, process, placeWithoutFire) * (to - from - byFire) / (to - from)
        end
    else
        work = Weather.catchUp(marks, ledger, process, place)
    end
    Weather.mark(marks, ledger, process)
    return work
end

-- Where a station stands for its work, written into stationModData (a run's or a station's): its place now, with
-- the fire's fuel noted when it is by one. A move brings the work up to now first, at the place it left
-- (catchUp(stationModData), the mod's own), so the hours by a fire count even when the station is seen again after it went out.
function Fireside.notePlace(stationModData, station, now, catchUp)
    local place, fire = Fire.placeOf(station)
    if stationModData.place ~= nil and stationModData.place ~= place and catchUp then catchUp(stationModData) end
    stationModData.place = place
    Fireside.noteFire(stationModData, station, fire, now)
    return place
end

-- Notes in a station's modData where it stands: by a fire, until when the fuel lasts and what it stands in without
-- the fire. A station's catch-up reads them for the time it was away.
function Fireside.noteFire(stationModData, station, fire, now)
    if not fire then
        stationModData.fireUntil, stationModData.placeWithoutFire = nil, nil
        return
    end
    local hours = Fire.fuelHours(fire)
    stationModData.fireUntil = hours and now + hours or nil
    stationModData.placeWithoutFire = Weather.placeOf(station)
end

return Fireside
