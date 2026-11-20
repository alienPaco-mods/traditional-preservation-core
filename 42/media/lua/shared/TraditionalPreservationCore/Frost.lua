-- Traditional Preservation core: frost. Hours at or below a freezing point, counted by place on one ledger for the
-- whole series, at Core's place temperature (Weather.placeTemperature), so a thing left alone catches up when it is
-- next looked at, as kept food does (PlaceKeeping). A mod names the freezing points its things have (Frost.point) at
-- load; each look brings a thing's frost record up to now and gives the hours it spent frozen since the last look,
-- which the mod turns into what frost does to it (a crop ruined, a starter weakened). A powered fridge never freezes
-- (FluidAgeing.FRIDGE_C), a powered freezer counts nothing (vanilla's own frozen food, vanilla's rules), a place by a
-- fire goes by the fire's heat while its noted fuel lasted, as every FluidAgeing age does (FluidAgeing.advance).
-- Recorded every ten minutes by FrostWorld.lua.
local Weather = require "TraditionalPreservationCore/Weather"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"

local Frost = {}

-- Save key of the ledger: never rename it. Its totals are named "frostAt<celsius>" .. place (Frost.point).
Frost.LEDGER_KEY = "TraditionalPreservationCoreFrost"

-- Each freezing point named so far: process -> its rate (1 an hour at or below the point, else 0).
local processes = {}
local kinds = {}
local filledLedger, filledCount, count = nil, 0, 0

-- The frost kind for things that freeze at celsius, made on first use (a FluidAgeing fluid kind: process, rate).
-- Its process name is a save key: "frostAt" and the point (frostAt-1, frostAt-2.5). Named at load, before the first
-- reading, so every stretch is counted.
function Frost.point(celsius)
    local process = "frostAt" .. string.format("%g", celsius)
    if not kinds[process] then
        local function rate(placeC) return placeC <= celsius and 1 or 0 end
        kinds[process] = { process = process, rate = rate, celsius = celsius }
        processes[process] = rate
        count = count + 1
    end
    return kinds[process]
end

-- The ledger, with totals for every point named (a save from before a point was added starts it at 0).
function Frost.ledger()
    local ledger = Weather.getLedger(Frost.LEDGER_KEY, function(now) return Weather.newLedger(now, processes) end)
    if ledger ~= filledLedger or filledCount ~= count then
        Weather.fillLedger(ledger, processes)
        filledLedger, filledCount = ledger, count
    end
    return ledger
end

-- Adds a stretch of weather to the ledger (every ten minutes). Nothing while no mod has named a point.
function Frost.recordWeather(now, temperature)
    if count == 0 then return end
    Weather.advance(Frost.ledger(), now, temperature, processes)
end

-- A new frost record for a thing that freezes as kind, seen now at place: none frozen yet.
function Frost.newRecord(kind, now, place, ledger)
    return FluidAgeing.newFluidAge(kind, ledger or Frost.ledger(), now, place)
end

-- Brings a frost record up to now: the time since the last look counts at the place it was seen in then, and it
-- counts from place on (fireNote as FluidAgeing.advance's). Returns the hours it spent frozen since the last look.
-- The record's age is its frozen hours in all.
function Frost.catchUp(record, kind, now, place, fireNote, ledger)
    local before = record.age
    FluidAgeing.advance(record, kind, ledger or Frost.ledger(), now, place, fireNote)
    return record.age - before
end

-- Hours of frost that freeze a thing through (a jar, a pot, a heap): the one-time changes (a culture Hungry, kefir
-- Separated, yoghurt Thawed, kraut soft, a sprout dead) come once a thing has been frozen this long in all.
Frost.THROUGH_HOURS = 6
-- Hours of frost that take a live starter from where it is to spent (Active Culture, a yoghurt starter, a mother in
-- a jar): milder than a vegetable's, as real starters mostly live through freezing (user, session 76).
Frost.STARTER_RUIN_HOURS = 48

-- Brings an item's frost up to now under modData[key]: the time since the last look counts at the place it was seen
-- in then, and seen (a FluidAgeing age just brought up to now, with the fire noted at this look: a PlaceKeeping
-- clock's fluidAge) says where it is now. The first look starts the record. Returns the hours frozen since the last
-- look, and the record (its age the frozen hours in all).
function Frost.see(modData, key, kind, now, seen)
    local record = modData[key]
    if not record then
        record = Frost.newRecord(kind, now, seen.place)
        record.fireUntil, record.placeWithoutFire = seen.fireUntil, seen.placeWithoutFire
        modData[key] = record
        return 0, record
    end
    local hours = Frost.catchUp(record, kind, now, seen.place, record)
    record.fireUntil, record.placeWithoutFire = seen.fireUntil, seen.placeWithoutFire
    return hours, record
end

-- True if a record crossed THROUGH_HOURS in all with the last hours added: the one-time change is due now. A hair of
-- slack: six hours of ten-minute readings add up to a whisker under 6.
local THROUGH_SLACK = 1e-6
function Frost.frozenThrough(record, hours)
    local through = Frost.THROUGH_HOURS - THROUGH_SLACK
    return record.age >= through and record.age - hours < through
end

-- Moves an item hours of frost nearer rotten (its script's DaysTotallyRotten), ruinHours taking it all the way,
-- never past rotten. With a PlaceKeeping clock its base moves too, so the keeping goes on from there.
function Frost.bite(item, hours, ruinHours, clock)
    local age = item:getAge()
    local rotten = item:getOffAgeMax()
    local frosted = math.min(age + hours / ruinHours * rotten, math.max(age, rotten))
    if clock then clock.base = clock.base + frosted - age end
    item:setAge(frosted)
end

-- True if a place is at or below the kind's freezing point now (a fridge never; a freezer always, by vanilla's rules).
function Frost.freezingAt(kind, place, ledger)
    if place == FluidAgeing.FRIDGE then return false end
    if place == FluidAgeing.FREEZER then return true end
    return kind.rate(Weather.placeTemperature(ledger or Frost.ledger(), place or Weather.DEFAULT_PLACE)) > 0
end

return Frost
