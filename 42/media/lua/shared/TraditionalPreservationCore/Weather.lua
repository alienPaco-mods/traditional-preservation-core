-- Traditional Preservation core: where a station stands decides its temperature, and running totals of the
-- weather in global ModData say how much work each place has done, even while a station was unloaded.
-- Rate curves stay in each mod. A ledger keeps one total and one last rate per kind of work and place,
-- under kind .. place ("" for a mod with one kind, so plain "Open", "OpenRate").
--
-- The weather itself is kept once for the whole series (Weather.shared): the last reading and the season's means.
-- Each mod's ledger copies them at every record, so a mod added to a running save agrees with the others about the
-- temperature under a roof from its first day, where a mean of its own would take ten days to catch up.
local Weather = {}

-- Outdoors goes by the day; a room (Sheltered) and an open roof (Covered: a porch, an open shed) by the season,
-- the mean of the last ten days or so, as an unheated house or shed would. A basement follows the ground: the
-- season's mean over a further GROUND_HOURS (a month behind, so a cellar is coldest in March and warmest in August),
-- and only BASEMENT_SWING as far from BASEMENT_ANCHOR: the ground round it keeps it cool in summer and above frost
-- in winter (about 5 C to 13). A loft (a room above the ground floor with no room over it: the top storey, under the roof) is the basement's mirror: a room in the cold
-- months, and under the sun on the roof LOFT_LIFT of the season's distance above LOFT_ANCHOR warmer (about 24 C in
-- a 21 C July). Enclosed is a closed shed in the outside air (the Smokehouse): out of the rain and wind but not a room,
-- and with no thermal mass to speak of, so it goes by the day as the open air does, and the grid doesn't warm it. No
-- square says it: a station claims it (Fish & Meat's World entry), so Weather.placeOf never returns it.
Weather.PLACES = { "Open", "Covered", "Sheltered", "Loft", "Basement", "Enclosed" }
Weather.SEASON_HOURS = 240
Weather.GROUND_HOURS = 720
Weather.BASEMENT_ANCHOR = 10
Weather.BASEMENT_SWING = 0.4
Weather.LOFT_ANCHOR = 10
Weather.LOFT_LIFT = 0.3
-- While the grid is on, vanilla keeps every room at 22 C (ClimateManager.getAirTemperatureForSquare); a room and a
-- loft do here too. An open roof and a basement don't: vanilla's 22 C is for squares in a room above ground.
Weather.GRID_ROOM_C = 22
-- Places at a temperature of their own, whatever the weather: Hearth adds by a fire and by banked embers. The
-- ledger keeps no totals for them; work there counts by the clock (Hearth.catchUp).
Weather.FIXED_C = {}

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

-- Below ground is a basement, in a room sheltered, under a roof that isn't a room covered (a porch, an open shed),
-- anything else open. Asks the square, not the object: a player's isOutside() only means "not in a room", while
-- the square's exterior flag also clears under a floor with no walls round it, as a station's isOutside() and the
-- game's rain both see. A player-built shed with walls and a whole roof is a room.
function Weather.placeOf(object)
    local square = object and object:getSquare()
    if not square then return "Open" end
    if square:getZ() < 0 then return "Basement" end
    if not square:isOutside() then
        if not square:isInARoom() then return "Covered" end
        -- A loft is the top storey: upstairs, with no room on the square above (a roof's square is in none).
        local above = square:getZ() >= 1 and square:getSquareAbove()
        if square:getZ() >= 1 and not (above and above:isInARoom()) then return "Loft" end
        return "Sheltered"
    end
    return "Open"
end

-- A basement by the ground's temperature: BASEMENT_ANCHOR plus BASEMENT_SWING of the ground's distance from it.
function Weather.basementTemperature(groundTemperature)
    return Weather.BASEMENT_ANCHOR + Weather.BASEMENT_SWING * (groundTemperature - Weather.BASEMENT_ANCHOR)
end

-- A loft by the season's mean: a room's, plus LOFT_LIFT of what the season is above LOFT_ANCHOR.
function Weather.loftTemperature(seasonTemperature)
    return seasonTemperature + Weather.LOFT_LIFT * math.max(seasonTemperature - Weather.LOFT_ANCHOR, 0)
end

-- The temperature a place has now, from the ledger's last reading.
function Weather.placeTemperature(ledger, place)
    if Weather.FIXED_C[place] then return Weather.FIXED_C[place] end
    local temperature = ledger.temperature or 0
    local season = ledger.seasonTemperature or temperature
    -- A ledger from before the ground's mean (or a test's) goes by the season.
    if place == "Basement" then return Weather.basementTemperature(ledger.groundTemperature or season) end
    if (place == "Sheltered" or place == "Loft") and ledger.gridOn then return Weather.GRID_ROOM_C end
    if place == "Loft" then return Weather.loftTemperature(season) end
    if place == "Sheltered" or place == "Covered" then return season end
    -- The open air and a shed in it (Enclosed) by the day's.
    return temperature
end

-- Moves ledger[field] towards value as a running mean over length hours (SEASON_HOURS if not given).
function Weather.seasonMean(ledger, field, value, hours, length)
    local share = math.min(hours / (length or Weather.SEASON_HOURS), 1)
    ledger[field] = (ledger[field] or value) * (1 - share) + value * share
end

-- For tools: a year of daily means in calendar order (each with .month and .mean), settled as a long-running save
-- has them: the year goes round twice first, so January follows December. Returns at(month, offset), the season's
-- and the ground's means at the start of that day of the month; an offset below 0 counts back into the month before.
function Weather.settledMeans(year)
    local state = { seasonTemperature = year[#year].mean }
    local season, ground, first = {}, {}, {}
    for index, day in ipairs(year) do first[day.month] = first[day.month] or index end
    for round = 1, 3 do
        for index, day in ipairs(year) do
            if round == 3 then season[index], ground[index] = state.seasonTemperature, state.groundTemperature end
            Weather.seasonMean(state, "seasonTemperature", day.mean, 24)
            Weather.seasonMean(state, "groundTemperature", state.seasonTemperature, 24, Weather.GROUND_HOURS)
        end
    end
    return function(month, offset)
        local index = (first[month] - 1 + offset) % #year + 1
        return season[index], ground[index]
    end
end

-- The series' weather: { lastHour, temperature, seasonTemperature, seasonHumidity, groundTemperature, gridOn }, in the core's global ModData.
-- Save key: never rename it.
Weather.SHARED_KEY = "TraditionalPreservationCore"

-- The state in use: the game's, once it runs. Nil in tests and tools, where each ledger grows its own means.
local shared

-- One reading into the series' weather. gridOn: the power grid is still on.
function Weather.observe(state, now, temperature, humidity, gridOn)
    local hours = math.max(now - (state.lastHour or now), 0)
    state.lastHour = now
    state.temperature = temperature
    state.gridOn = gridOn or nil
    Weather.seasonMean(state, "seasonTemperature", temperature, hours)
    Weather.seasonMean(state, "groundTemperature", state.seasonTemperature, hours, Weather.GROUND_HOURS)
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
-- else a running mean of the ledger's own. The season's temperature brings the grid's state and the ground's
-- along.
function Weather.season(ledger, field, value, hours)
    local temperature = field == "seasonTemperature"
    if shared and temperature then ledger.gridOn = shared.gridOn end
    if shared and shared[field] ~= nil then
        ledger[field] = shared[field]
        if temperature then ledger.groundTemperature = shared.groundTemperature end
    else
        Weather.seasonMean(ledger, field, value, hours)
        if temperature then Weather.seasonMean(ledger, "groundTemperature", ledger.seasonTemperature, hours, Weather.GROUND_HOURS) end
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
            data.ledger.groundTemperature = data.ledger.groundTemperature or state.groundTemperature
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
    local world = getWorld and getWorld()
    Weather.observe(shared, now, climate:getTemperature(), climate:getHumidity(), world and world:isHydroPowerOn())
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

-- Marks are each place's total when a run or cask was last brought up to date, and the ledger's hour then (for
-- time by a fire, Hearth.catchUp). Work since then is the difference, so a station catches up however long it was away.
function Weather.mark(marks, ledger, kind)
    for _, place in ipairs(Weather.PLACES) do marks[place] = ledger[kind .. place] end
    marks.hour = ledger.lastHour
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
    modData.place, modData.fireUntil, modData.under = nil, nil, nil
end

-- Craft timers tick at a fixed speed whatever Day Length says, so this replaces their count with the work
-- done. Weather is only recorded every ten minutes, so the bar carries on at the last rate between
-- records. That part is only shown, and the next record replaces it. rateAt gives the rate at a fixed place
-- (Weather.FIXED_C), which the ledger keeps none for.
function Weather.showProgress(craftRecipeData, ledger, kind, place, speed, now, rateAt)
    local modData = craftRecipeData:getModData()
    local fixed = Weather.FIXED_C[place]
    local rate = fixed and rateAt and rateAt(fixed) or ledger[kind .. place .. "Rate"] or 0
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
