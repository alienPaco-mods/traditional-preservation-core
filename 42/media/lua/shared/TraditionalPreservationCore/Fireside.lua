-- Traditional Preservation core: "by a fire", a place of its own (Fire.PLACE, at Fire.FIRE_C): any lit fire within
-- Fire.FIRE_RADIUS tiles on the same floor, one of ours or not. Indoors it holds FIRE_C whatever the weather; under an
-- open roof or in the open the air takes the heat away, so there it is that place's air plus Fire.FIRE_LIFT, never
-- past FIRE_C (places PLACE .. "Covered", .. "Open"; a campfire in a January field is cold at the back). Beside banked
-- embers it is Fire.EMBERS. It is opt-in: Weather.placeOf never returns it, placeOf here does, so only a mod that
-- asks for it gets it. And the weather-timed work done there: catchUp, the craft runs, notePlace.
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
    if not fire or (fire.under and not ledger) then return nil end
    return Weather.placeTemperature(ledger or {}, place)
end

function Fireside.isFirePlace(place)
    return Weather.FIRE_PLACES[place] ~= nil
end

-- A fire's place (PLACE or EMBERS) where it warms under (Weather.placeOf): its own outside, plain indoors.
function Fireside.firePlace(place, under)
    if Fire.FIRE_LIFT[under] then return place .. under end
    return place
end

-- Fireplaces, antique ovens, braziers, cooking pits and burn barrels are IsoFireplace; a player's campfire is a
-- plain object named "Campfire" whose lit state the camping system copies into its modData (ENGINE_NOTES).
local function isLitFire(object)
    if instanceof(object, "IsoFireplace") then return Fire.isBurning(object) end
    return object:getName() == "Campfire" and object:getModData().isLit == true
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
    return Fireside.near(square, function(object) return Fire.isFitted(object, id) end)
end

-- The opt-in place: by a fire (or by banked embers), else below ground, under a roof or in the open. The fire, if any, comes second.
function Fireside.placeOf(object)
    local square = object and object:getSquare()
    local fire, place
    if square then fire, place = warmestFire(square) end
    if fire then return Fireside.firePlace(place, Weather.placeOf(object)), fire end
    return Weather.placeOf(object)
end

-- The work done since the marks at place, which may be by a fire (placeOf), and moves the marks on (Weather.mark).
-- The ledger keeps totals for the weather's places only, so time by a fire counts by the clock at its heat, rateAt
-- the work's rate at a temperature, until the fire's noted fuel ran out (state.fireUntil, noteFire). The ledger's
-- totals can't be split at that hour, so the place under the fire (state.under, else Fire.DEFAULT_UNDER) gets its
-- share of the gap's weather by time. Marks taken without an hour count from the ledger's last record.
function Fireside.catchUp(state, marks, ledger, kind, place, rateAt)
    local work
    if Fireside.isFirePlace(place) then
        local from, to = marks.hour or ledger.lastHour, ledger.lastHour
        local byFire = math.max(math.min(state.fireUntil or to, to) - from, 0)
        work = byFire * rateAt(Fireside.fireC(place, ledger))
        if to - from > byFire then
            local under = state.under or Fire.DEFAULT_UNDER
            work = work + Weather.catchUp(marks, ledger, kind, under) * (to - from - byFire) / (to - from)
        end
    else
        work = Weather.catchUp(marks, ledger, kind, place)
    end
    Weather.mark(marks, ledger, kind)
    return work
end

-- A weather-timed craft run (Yeast's culture, Vinegar's malt and wort, the template's batch): its recipe data's
-- modData keeps done (hours of work), last (the marks) and the place notePlace wrote. These bring one up to now at
-- that place, by a fire or not; a run not yet started (no done or no marks) is left alone.
function Fireside.catchUpRun(modData, ledger, kind, place, rateAt)
    if not (modData.done and modData.last) then return end
    modData.done = modData.done + Fireside.catchUp(modData, modData.last, ledger, kind, place, rateAt)
end

-- A run's OnUpdate: catches it up and sets the craft's bar from the work done (Weather.showProgress).
function Fireside.updateRun(craftRecipeData, ledger, kind, place, rateAt, speed)
    local modData = craftRecipeData:getModData()
    if not (modData.done and modData.last) then return end
    Fireside.catchUpRun(modData, ledger, kind, place, rateAt)
    Weather.showProgress(craftRecipeData, ledger, kind, place, speed or 1, getGameTime():getWorldAgeHours(), rateAt)
end

-- Where a station stands for its work, written into state (a run's or a station's modData): its place now, with
-- the fire's fuel noted when it is by one. A move brings the work up to now first, at the place it left
-- (catchUp(state), the mod's own), so the hours by a fire count even when the station is seen again after it went out.
function Fireside.notePlace(state, object, now, catchUp)
    local place, fire = Fire.placeOf(object)
    if state.place ~= nil and state.place ~= place and catchUp then catchUp(state) end
    state.place = place
    Fireside.noteFire(state, object, fire, now)
    return place
end

-- Notes on a station's state where it stands: by a fire, until when the fuel lasts and what it stands in without
-- the fire. A station's catch-up reads them for the time it was away.
function Fireside.noteFire(state, object, fire, now)
    if not fire then
        state.fireUntil, state.under = nil, nil
        return
    end
    local hours = Fire.fuelHours(fire)
    state.fireUntil = hours and now + hours or nil
    state.under = Weather.placeOf(object)
end

return Fireside
