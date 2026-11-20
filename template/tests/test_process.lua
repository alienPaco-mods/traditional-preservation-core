-- Checks the station's batches outside the game. Run from the mod folder: luajit tests/test_process.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(10)
H.installModData()
H.installEvents()
H.installGetText()
dofile("42/media/lua/shared/__MOD__.lua")
local M = __MOD__

local function station()
    local modData = {}
    return { getModData = function() return modData end }
end

local function inventory()
    local given = {}
    return { given = given, AddItem = function(_, fullType) table.insert(given, fullType) end }
end

local function weather(count, temperature)
    for _ = 1, count do
        H.setHours(H.hours + 1)
        M.advance(M.getLedger(), H.hours, temperature)
    end
end

-- Temperature
check("full speed at its best temperature", M.processRate(20) == 1)
check("slower in the cold, never stopped", M.processRate(-20) > 0 and M.processRate(-20) < M.processRate(10))
M.SENSITIVITY = 0
check("sensitivity off runs at full speed in any weather", M.processRate(-20) == 1)
M.SENSITIVITY = 1
check("a basement swings two fifths as far as the ground", M.placeTemperature({ temperature = -15, seasonTemperature = -5, groundTemperature = -10 }, "Basement") == 2)

-- Putting in
local press = station()
local first, count = M.put(press, 3, H.hours, "Open")
check("raw batches go in as one batch", first == 1 and count == 3 and M.used(M.recordOf(press)) == 3)
local second, more = M.put(press, 5, H.hours, "Open")
check("only as many as fit", second == 2 and more == 1 and M.fits(M.recordOf(press)) == 0)
check("a full station takes none", M.put(press, 1, H.hours, "Open") == nil)

-- Working
weather(24, 10)
local record = M.update(press, H.hours, "Open")
local rate = M.processRate(10)
local batch = M.batchById(record, first)
check("a batch counts the work at its place's temperature", near(batch.work.age, 24 * rate))
local status = M.status(batch, 10)
check("the time left assumes the rate holds", near(status.hoursLeft, (M.PROCESS_HOURS - 24 * rate) / rate) and not status.done)
weather(M.PROCESS_HOURS * 2, 22)
record = M.update(press, H.hours, "Open")
check("it is done at the process's hours", M.isDone(M.batchById(record, first)) and M.status(M.batchById(record, first), 22).progress == 1)

-- An unloaded station catches up at its old place
local cellar = station()
M.put(cellar, 1, H.hours, "Basement")
local before = M.getLedger()["processBasement"]
weather(48, 30)
record = M.update(cellar, H.hours, "Basement")
check("time away counts at the place it was seen in", near(record.batches[1].work.age, M.getLedger()["processBasement"] - before))

-- Taking out
local bag = inventory()
check("a done batch comes out finished", M.take(press, first, bag) == true and #bag.given == 3 and bag.given[1] == M.FINISHED)
local raw = inventory()
M.put(press, 1, H.hours, "Open")
local id = M.recordOf(press).batches[2].id
check("one not done comes back raw", M.take(press, id, raw) == false and raw.given[1] == M.RAW)
check("a batch taken is gone", M.take(press, id, raw) == nil and #M.recordOf(press).batches == 1)

-- Sandbox
SandboxVars = { __MOD__ = { ProcessDays = 2, TemperatureSensitivity = 1 } }
H.fire("OnInitGlobalModData")
check("the sandbox sets the time", M.PROCESS_HOURS == 48)
check("and the sensitivity", M.SENSITIVITY == 0)

-- Translations
check("the window's texts are translated", getText("IGUI___MOD___Left", "40%", "2 days") == "40%, about 2 days left"
    and getText("IGUI___MOD___BandEmpty") == "Empty")
check("with no formatter errors", #H.textWarnings == 0)
H.done()
