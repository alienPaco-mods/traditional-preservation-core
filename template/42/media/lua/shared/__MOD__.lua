-- Traditional Preservation (__NAME__) B42: how a batch works on the __STATION__.
-- Made by `tp new` from ~/MODS/TraditionalPreservationCore/template: a working one-station skeleton. Lines marked TEMPLATE are
-- placeholders to replace with the real technique (~/MODS/WIP/TPCore/SERIES.md, "Designing a new mod").
-- A piece-record station (DEVGUIDE, "Which kind of station?"): each Put In is a batch with its own clock, kept in the
-- station's movableData (KEY). A batch works by the temperature where the station stands: its age counts on the mod's
-- weather ledger by place (TP Core's FluidAgeing), so it keeps working while its area is unloaded and catches up
-- at the next look.
__MOD__ = __MOD__ or {}
local M = __MOD__
local Weather = require "TraditionalPreservationCore/Weather"
local Fire = require "TraditionalPreservationCore/Fire"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Station = require "TraditionalPreservationCore/Station"
local Tiles = require "__MOD__/Tiles"

M.PROCESS_HOURS = 72  -- TEMPLATE: hours at the best temperature
M.ROOM = 4            -- TEMPLATE: how many raw batches the station holds
M.RAW = "__MOD__.RawBatch"
M.FINISHED = "__MOD__.FinishedBatch"
-- Save keys: never rename these once the mod is out (DEVGUIDE, "Rules that keep saves and the game happy").
M.MOD_DATA_KEY = "__MOD__"
-- On the station: { batches = { { id, count, work = a FluidAgeing age (hours at full speed) }, ... } in the order put
-- in, nextId }.
M.KEY = "__LOWER__Station"
-- The ledger's totals are "<kind><place>", e.g. "processOpen".
local KIND = "process"

-- TEMPLATE: { temperature, share of full speed } points, joined by straight lines.
local PROCESS_CURVE = { { -5, 0.05 }, { 0, 0.1 }, { 5, 0.2 }, { 10, 0.4 }, { 18, 1 }, { 30, 1 }, { 35, 0.6 }, { 40, 0.1 } }
M.SENSITIVITY = 1
M.MIN_RATE = 0.02

-- Places and their temperatures are shared with the other Traditional Preservation mods; these are the
-- mod's public names for them, used by the Dev console and the tests. A station within reach of a lit fire is by a
-- fire (TP Core's Fire); PLACES are the weather's, which the ledger keeps totals for.
M.PLACES = Weather.PLACES
M.placeTemperature = Weather.placeTemperature
M.placeOf = Fire.placeOf

function M.processRate(celsius)
    return Weather.scaled(Weather.curve(PROCESS_CURVE, celsius), M.SENSITIVITY, M.MIN_RATE)
end

local KINDS = { [KIND] = function(celsius) return M.processRate(celsius) end }
local WORK = { process = KIND, rate = M.processRate }

function M.newLedger(now)
    return Weather.newLedger(now, KINDS)
end

-- Adds one stretch of weather to the totals.
function M.advance(ledger, now, temperature)
    Weather.advance(ledger, now, temperature, KINDS)
end

function M.getLedger()
    return Weather.getLedger(M.MOD_DATA_KEY, M.newLedger)
end

local STATIONS = {}
for _, name in ipairs(Tiles.STATIONS) do STATIONS[name] = true end

function M.isStation(isoObject)
    local sprite = isoObject and isoObject.getSprite and isoObject:getSprite()
    return sprite ~= nil and STATIONS[sprite:getName()] == true
end

-- The station's record, made on first use.
function M.recordOf(station)
    local movableData = Station.movableData(station)
    local record = movableData[M.KEY]
    if not record then
        record = { batches = {}, nextId = 1 }
        movableData[M.KEY] = record
    end
    return record
end

function M.isEmpty(record)
    return #record.batches == 0
end

function M.isDone(batch)
    return batch.work.age >= M.PROCESS_HOURS
end

function M.used(record)
    local used = 0
    for _, batch in ipairs(record.batches) do used = used + batch.count end
    return used
end

-- How many more raw batches fit.
function M.fits(record)
    return math.max(M.ROOM - M.used(record), 0)
end

function M.batchById(record, id)
    for i, batch in ipairs(record.batches) do
        if batch.id == id then return batch, i end
    end
end

-- Brings every batch up to now. place defaults to the station's own (by a fire, banked embers or a Weather place).
-- Returns the record and the place.
function M.update(station, now, place, ledger)
    now = now or getGameTime():getWorldAgeHours()
    ledger = ledger or M.getLedger()
    local fire
    if not place then place, fire = Fire.placeOf(station) end
    local record = M.recordOf(station)
    for _, batch in ipairs(record.batches) do
        if not M.isDone(batch) then
            FluidAgeing.advance(batch.work, WORK, ledger, now, place)
            FluidAgeing.noteFire(batch.work, fire, station, now)
        end
    end
    record.place = place
    return record, place
end

-- Puts raw batches in as one batch, as many as fit. Returns its id and how many went in, or nil.
function M.put(station, count, now, place, ledger)
    local record
    record, place = M.update(station, now, place, ledger)
    count = math.min(count, M.fits(record))
    if count <= 0 then return nil end
    local id = record.nextId
    record.nextId = id + 1
    table.insert(record.batches, { id = id, count = count,
        work = FluidAgeing.newFluidAge(WORK, ledger or M.getLedger(), now or getGameTime():getWorldAgeHours(), place) })
    return id, count
end

-- Takes the batch with this id out into the inventory: finished, or raw as it went in. Returns true if it was done,
-- false if not, nil if there was none.
function M.take(station, id, inventory)
    local record = M.recordOf(station)
    local batch, i = M.batchById(record, id)
    if not batch then return nil end
    local done = M.isDone(batch)
    for _ = 1, batch.count do inventory:AddItem(done and M.FINISHED or M.RAW) end
    table.remove(record.batches, i)
    return done
end

-- How a batch is doing at placeC: { done, progress (0 to 1), rate, hoursLeft (nil when done) }. hoursLeft assumes
-- the temperature holds.
function M.status(batch, placeC)
    local done = M.isDone(batch)
    local status = { done = done, progress = math.min(batch.work.age / M.PROCESS_HOURS, 1) }
    if done then return status end
    status.rate = M.processRate(placeC)
    status.hoursLeft = (M.PROCESS_HOURS - batch.work.age) / status.rate
    return status
end

function M.applySandbox()
    local options = SandboxVars and SandboxVars.__MOD__
    if not options then return end
    if options.ProcessDays then M.PROCESS_HOURS = options.ProcessDays * 24 end
    if options.TemperatureSensitivity then M.SENSITIVITY = Weather.sensitivity(options.TemperatureSensitivity) end
end

Events.OnInitGlobalModData.Add(M.applySandbox)
