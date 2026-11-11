-- Traditional Preservation core: where a station stands decides its temperature, and running totals of the
-- weather in global ModData say how much work each place has done, even while a station was unloaded.
-- Rate curves stay in each mod. A ledger keeps one total and one last rate per kind of work and place,
-- under kind .. place ("" for a mod with one kind, so plain "Open", "OpenRate").
--
-- The weather itself is kept once for the whole series (Weather.shared): the last reading and the season's means.
-- Each mod's ledger copies them at every record, so a mod added to a running save agrees with the others about the
-- temperature under a roof from its first day, where a mean of its own would take ten days to catch up.
local Weather = {}

-- Outdoors goes by the day, a roof by the season (the mean of the last ten days or so, a bit warmer,
-- never hotter than thick walls allow), and a basement stays near the year's average all year.
Weather.PLACES = { "Open", "Sheltered", "Basement" }
Weather.SEASON_HOURS = 240
Weather.SHELTER_WARMTH = 10
Weather.SHELTER_MAX = 28
Weather.BASEMENT_TEMPERATURE = 15

local SECONDS_PER_HOUR = 3600

local function lerp(from, to, amount)
    return from + (to - from) * amount
end

-- A run of straight lines through { temperature, rate } points, flat past both ends.
function Weather.curve(points, celsius)
    if celsius <= points[1][1] then return points[1][2] end
    for index = 2, #points do
        local low, high = points[index - 1], points[index]
        if celsius <= high[1] then
            return lerp(low[2], high[2], (celsius - low[1]) / (high[1] - low[1]))
        end
    end
    return points[#points][2]
end

-- The sandbox's Temperature Sensitivity, the same four steps in every mod: Off, Forgiving, Normal, Harsh.
Weather.SENSITIVITY_SCALES = { 0, 0.5, 1, 1.5 }

-- The scale for a sandbox option's value; Normal for one out of range.
function Weather.sensitivity(option)
    return Weather.SENSITIVITY_SCALES[option] or 1
end

-- Sensitivity says how much of a temperature's slowdown applies: 0 (off) to 1.5 (harsh).
function Weather.scaled(rate, sensitivity, minRate)
    return math.max(1 - (1 - rate) * sensitivity, minRate)
end

-- Below ground is a basement, under a roof sheltered, anything else open. Asks the square, not the object: a
-- player's isOutside() only means "not in a room", while the square's exterior flag also clears under a floor
-- with no walls round it, as a station's isOutside() and the game's rain both see.
function Weather.placeOf(object)
    local square = object and object:getSquare()
    if not square then return "Open" end
    if square:getZ() < 0 then return "Basement" end
    if not square:isOutside() then return "Sheltered" end
    return "Open"
end

-- A roof gives the season's mean plus SHELTER_WARMTH, capped at SHELTER_MAX.
function Weather.shelterTemperature(seasonTemperature)
    return math.min(seasonTemperature + Weather.SHELTER_WARMTH, Weather.SHELTER_MAX)
end

-- The temperature a place has now, from the ledger's last reading.
function Weather.placeTemperature(ledger, place)
    if place == "Basement" then return Weather.BASEMENT_TEMPERATURE end
    local temperature = ledger.temperature or 0
    if place == "Sheltered" then
        temperature = Weather.shelterTemperature(ledger.seasonTemperature or temperature)
    end
    return temperature
end

-- Moves ledger[field] towards value as a running mean over SEASON_HOURS.
function Weather.seasonMean(ledger, field, value, hours)
    local share = math.min(hours / Weather.SEASON_HOURS, 1)
    ledger[field] = (ledger[field] or value) * (1 - share) + value * share
end

-- The series' weather: { lastHour, temperature, seasonTemperature, seasonHumidity }, in the core's global ModData.
-- Save key: never rename it.
Weather.SHARED_KEY = "TraditionalPreservationCore"

-- The state in use: the game's, once it runs. Nil in tests and tools, where each ledger grows its own means.
local shared

-- One reading into the series' weather.
function Weather.observe(state, now, temperature, humidity)
    local hours = math.max(now - (state.lastHour or now), 0)
    state.lastHour = now
    state.temperature = temperature
    Weather.seasonMean(state, "seasonTemperature", temperature, hours)
    if humidity then Weather.seasonMean(state, "seasonHumidity", humidity, hours) end
end

-- The series' weather, made on first use. Until its first record it would read 0 C, so it starts on the weather
-- there is now.
function Weather.shared()
    local data = ModData.getOrCreate(Weather.SHARED_KEY)
    data.ledger = data.ledger or { lastHour = getGameTime():getWorldAgeHours() }
    local state = data.ledger
    if state.temperature == nil then
        local climate = getClimateManager and getClimateManager()
        if climate then Weather.observe(state, state.lastHour, climate:getTemperature(), climate:getHumidity()) end
    end
    return state
end

-- For tests: the state Weather.season copies from, or nil for none.
function Weather.share(state)
    shared = state
end

-- A ledger's season mean (field is "seasonTemperature" or "seasonHumidity"): the series' own where there is one,
-- else a running mean of the ledger's own.
function Weather.season(ledger, field, value, hours)
    if shared and shared[field] ~= nil then
        ledger[field] = shared[field]
    else
        Weather.seasonMean(ledger, field, value, hours)
    end
end

-- kinds maps each kind of work to its rate at a temperature.
function Weather.newLedger(now, kinds)
    local ledger = { lastHour = now }
    return Weather.fillLedger(ledger, kinds)
end

-- A save from before a kind or place was added has no totals for it.
function Weather.fillLedger(ledger, kinds)
    for kind in pairs(kinds) do
        for _, place in ipairs(Weather.PLACES) do
            ledger[kind .. place] = ledger[kind .. place] or 0
        end
    end
    return ledger
end

-- Adds one stretch of weather to the totals. Returns the hours it covered, or nil if none had passed.
function Weather.advance(ledger, now, temperature, kinds)
    local hours = now - ledger.lastHour
    if hours <= 0 then return nil end
    ledger.lastHour = now

    Weather.season(ledger, "seasonTemperature", temperature, hours)
    ledger.temperature = temperature
    for kind, rateAt in pairs(kinds) do
        for _, place in ipairs(Weather.PLACES) do
            local rate = rateAt(Weather.placeTemperature(ledger, place))
            ledger[kind .. place .. "Rate"] = rate
            ledger[kind .. place] = (ledger[kind .. place] or 0) + rate * hours
        end
    end
    return hours
end

-- The mod's ledger in global ModData, made on first use.
function Weather.getLedger(key, newLedger)
    local data = ModData.getOrCreate(key)
    if not data.ledger then
        data.ledger = newLedger(getGameTime():getWorldAgeHours())
        -- Until its first record a new ledger would read 0 C: it starts on the series' weather.
        local state = Weather.shared()
        if data.ledger.temperature == nil then
            data.ledger.temperature = state.temperature
            data.ledger.seasonTemperature = data.ledger.seasonTemperature or state.seasonTemperature
        end
    end
    return data.ledger
end

-- Every ten in-game minutes, the weather's resolution in every mod: the series' weather takes its reading first,
-- then each mod's recorder adds the stretch to its own totals.
local recorders = {}
local started = false

local function onTenMinutes()
    local now, climate = getGameTime():getWorldAgeHours(), getClimateManager()
    shared = Weather.shared()
    Weather.observe(shared, now, climate:getTemperature(), climate:getHumidity())
    for _, record in ipairs(recorders) do record(now, climate) end
end

-- Starts the ten-minute readings. The core calls it; so does the first Weather.record.
function Weather.start()
    if started then return end
    started = true
    Events.EveryTenMinutes.Add(onTenMinutes)
end

-- Calls record(now, climate) at each reading.
function Weather.record(record)
    Weather.start()
    table.insert(recorders, record)
end

-- Marks are each place's total when a run or cask was last brought up to date. Work since then is the
-- difference, so a station catches up however long it was away.
function Weather.mark(marks, ledger, kind)
    for _, place in ipairs(Weather.PLACES) do marks[place] = ledger[kind .. place] end
    return marks
end

-- The work done at place since the marks, by the station's place now. Moves every mark on.
function Weather.catchUp(marks, ledger, kind, place)
    local total = ledger[kind .. place]
    local work = total - (marks[place] or total)
    Weather.mark(marks, ledger, kind)
    return work
end

-- The engine pools recipe data without clearing its ModData, so a mod's start hook clears its own fields too.
function Weather.startRun(modData, ledger, kind)
    modData.done = 0
    modData.last = Weather.mark({}, ledger, kind)
    modData.place = nil
end

-- Craft timers tick at a fixed speed whatever Day Length says, so this replaces their count with the work
-- done. Weather is only recorded every ten minutes, so the bar carries on at the last rate between
-- records. That part is only shown, and the next record replaces it.
function Weather.showProgress(craftRecipeData, ledger, kind, place, speed, now)
    local modData = craftRecipeData:getModData()
    local rate = ledger[kind .. place .. "Rate"] or 0
    local sinceRecord = math.max(now - ledger.lastHour, 0)
    local elapsed = (modData.done + sinceRecord * rate) * speed * SECONDS_PER_HOUR
    craftRecipeData:setElapsedTime(math.min(elapsed, craftRecipeData:getRecipe():getTime()))
end

-- Sets a craft recipe's time from the sandbox, so the bar's full length matches the hours of work it stands for.
-- tag names the mod in the log when the recipe is missing (a renamed or removed script).
function Weather.setRecipeHours(fullName, hours, tag)
    local recipe = ScriptManager.instance:getCraftRecipe(fullName)
    if not recipe then
        print("[" .. tag .. "] Could not find " .. fullName)
        return
    end
    recipe:Load(fullName, "{ time = " .. tostring(math.floor(hours * SECONDS_PER_HOUR)) .. ", }")
end

-- Work that goes by the clock alone (Fish's press, Salt's leaching) needs no ledger, only the hour it began.
-- The engine pools recipe data without clearing its ModData, so every run's OnStart must call startClock.
function Weather.startClock(craftRecipeData, key, now)
    craftRecipeData:getModData()[key] = now
end

-- A run with no start hour is left alone. The start hour saves with the recipe. speed (default 1) runs the
-- bar faster, for a run shorter than its recipe's time.
function Weather.showClock(craftRecipeData, key, now, speed)
    local startHour = craftRecipeData:getModData()[key]
    if not startHour then return end

    local elapsed = (now - startHour) * (speed or 1) * SECONDS_PER_HOUR
    craftRecipeData:setElapsedTime(math.min(elapsed, craftRecipeData:getRecipe():getTime()))
end

-- How a running batch is doing, for its popup. hoursLeft assumes the temperature holds.
function Weather.batchStatus(done, recipeHours, ledger, place, rateAt)
    local temperature = Weather.placeTemperature(ledger, place)
    local rate = rateAt(temperature)
    return {
        progress = math.min(done / recipeHours, 1),
        hoursLeft = math.max(recipeHours - done, 0) / rate,
        temperature = temperature,
        place = place,
        rate = rate,
    }
end

return Weather
