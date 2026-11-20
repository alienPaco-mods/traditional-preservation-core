-- Traditional Preservation core: where a station stands decides its temperature, and running totals of the
-- weather in global ModData say how much work each place has done, even while a station was unloaded.
-- Rate curves stay in each mod. A ledger keeps one total and one last rate per process (kind of work) and place,
-- under process .. place ("" for a mod with one process, so plain "Open", "OpenRate").
--
-- The weather itself is kept once for the whole series (Weather.weatherModData): the last reading and the season's means.
-- Each mod's ledger copies them at every record, so a mod added to a running save agrees with the others about the
-- temperature under a roof from its first day, where a mean of its own would take ten days to catch up.
local Windows = require "TraditionalPreservationCore/Windows"

local Weather = {}

-- Outdoors and under an open roof (Covered: a porch, an open shed) go by the hour's air: a roof keeps off rain and
-- sun, which are each process's own rules, not the air's. A shut room (Sheltered: every window shut or barricaded)
-- lags the weather by its walls, the mean of the last three days (ROOM_HOURS), a few degrees warmer in winter
-- (ROOM_LIFT) and stuffy in summer (ROOM_SUMMER_LIFT). An aired room (a window open, smashed, without its glass or an
-- empty frame; Windows.aired) follows the day's mean (AIRED_HOURS), at most AIRED_LIFT warmer in winter. A basement
-- follows the ground: the season's mean (SEASON_HOURS, about ten days) over a further GROUND_HOURS (a month behind,
-- so a cellar is coldest in March and warmest in August), and only BASEMENT_SWING as far from BASEMENT_ANCHOR: the
-- ground round it keeps it cool in summer and above frost in winter (about 5 C to 13). Every place is a square's:
-- the Smokehouse is a station, not a place, and its air is an aired room's (Smokehouse.PLACE).
-- Save values: a station's noted place and the ledger's totals are named by these. Never rename them.
Weather.PLACES = { "Open", "Covered", "Sheltered", "AiredRoom", "Basement" }
Weather.SEASON_HOURS = 240
Weather.GROUND_HOURS = 720
Weather.ROOM_HOURS = 72
Weather.AIRED_HOURS = 24
Weather.BASEMENT_ANCHOR = 10
Weather.BASEMENT_SWING = 0.4
-- While the grid is on, vanilla keeps every room at 22 C (ClimateManager.getAirTemperatureForSquare); a shut room and
-- an aired one do here too. An open roof and a basement don't: vanilla's 22 C is for squares in a room above ground.
Weather.GRID_ROOM_C = 22
-- An unheated room is a little warmer than the air in the cold months: the house's own mass, the people in it, the
-- sun through its windows. ROOM_LIFT in full at a mean of ROOM_LIFT_FULL or below, none from ROOM_LIFT_NONE. An
-- aired room keeps AIRED_LIFT of it. Never while the grid is on.
Weather.ROOM_LIFT = 2
Weather.AIRED_LIFT = 1
Weather.ROOM_LIFT_FULL = 10
Weather.ROOM_LIFT_NONE = 18
-- A shut room in summer is hot and stuffy: the sun through the glass and on the roof, nowhere for the heat to go.
-- None at a mean of ROOM_LIFT_NONE, ROOM_SUMMER_LIFT in full from ROOM_SUMMER_FULL. An open window lets it out.
Weather.ROOM_SUMMER_LIFT = 2
Weather.ROOM_SUMMER_FULL = 21
-- Places by a fire, which the ledger keeps no totals for: work there counts by the clock (Fire.catchUp). Fire
-- adds them: place -> { celsius, under, lift }. A fire indoors (no under) holds celsius whatever the weather; one
-- under an open roof or in the open warms that place's air by lift, never past celsius.
Weather.FIRE_PLACES = {}
-- Inside a station that is a building of its own (the Smokehouse): its word -> the place whose air it has, never
-- warmed by the grid (a shed is no room). A station adds itself; the ledger keeps no totals for it.
Weather.STATION_PLACES = {}
-- Where something stands when nothing says: a room. (Fire.DEFAULT_PLACE_WITHOUT_FIRE and FluidAgeing.DEFAULT_PLACE are this.)
Weather.DEFAULT_PLACE = "Sheltered"
-- Where a station's run or stack counts before its World first says where the station stands (a few seconds): the
-- open air. Fish & Meat's stacks and tubs, Vinegar's floor and vessel runs.
Weather.NEW_RUN_PLACE = "Open"

local NO_SQUARE_PLACE = "Open"   -- placeOf for an isoObject on no square
local HOURS_PER_DAY = 24
local SETTLE_ROUNDS = 3          -- settledMeans: the year twice to settle, the third read

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
local SENSITIVITY_SCALES = { 0, 0.5, 1, 1.5 }

-- The scale for a sandbox option's value; Normal for one out of range.
function Weather.sensitivity(option)
    return SENSITIVITY_SCALES[option] or 1
end

-- Sensitivity says how much of a temperature's slowdown applies: 0 (off) to 1.5 (harsh).
function Weather.scaled(rate, sensitivity, minRate)
    return math.max(1 - (1 - rate) * sensitivity, minRate)
end

-- At or below its freezing point (default 0 C) a culture, a ferment or a cure stops: its water is ice. Paused, not
-- killed: it goes on once thawed. A stop outside the scaling, the same on Forgiving, Normal and Harsh, and under any
-- minRate (a floor holds above freezing only); Off alone ignores it, as Off means temperature never matters.
function Weather.frozen(celsius, sensitivity, freezeC)
    return sensitivity > 0 and celsius <= (freezeC or 0)
end

-- A culture's, a ferment's or a cure's speed at celsius: 0 frozen (at or below freezeC, default 0 C), else the
-- curve's rate after the sensitivity, never under minRate (default 0).
function Weather.rate(curve, celsius, sensitivity, minRate, freezeC)
    if Weather.frozen(celsius, sensitivity, freezeC) then return 0 end
    return Weather.scaled(Weather.curve(curve, celsius), sensitivity, minRate or 0)
end

-- Below ground is a basement, in a room an aired room or a shut one (sheltered) by its windows, under a roof that
-- isn't a room covered (a porch, an open shed), anything else open. Asks the square, not the object: a player's
-- isOutside() only means "not in a room", while the square's exterior flag also clears under a floor with no walls
-- round it, as a station's isOutside() and the game's rain both see. A player-built shed with walls and a whole roof
-- is a room.
function Weather.placeOf(isoObject)
    local square = isoObject and isoObject:getSquare()
    if not square then return NO_SQUARE_PLACE end
    if square:getZ() < 0 then return "Basement" end
    if not square:isOutside() then
        if not square:isInARoom() then return "Covered" end
        if Windows.aired(square) then return "AiredRoom" end
        return "Sheltered"
    end
    return "Open"
end

-- A basement by the ground's temperature: BASEMENT_ANCHOR plus BASEMENT_SWING of the ground's distance from it.
function Weather.basementTemperature(groundTemperature)
    return Weather.BASEMENT_ANCHOR + Weather.BASEMENT_SWING * (groundTemperature - Weather.BASEMENT_ANCHOR)
end

-- How much of the winter lift a room has at a mean temperature: 1 in the cold, 0 from ROOM_LIFT_NONE.
local function winterShare(celsius)
    return Weather.curve({ { Weather.ROOM_LIFT_FULL, 1 }, { Weather.ROOM_LIFT_NONE, 0 } }, celsius)
end

-- An unheated shut room by the three-day mean: its winter lift (ROOM_LIFT) or its summer one (ROOM_SUMMER_LIFT).
function Weather.roomTemperature(threeDayTemperature)
    local summer = Weather.curve({ { Weather.ROOM_LIFT_NONE, 0 }, { Weather.ROOM_SUMMER_FULL, 1 } }, threeDayTemperature)
    return threeDayTemperature + Weather.ROOM_LIFT * winterShare(threeDayTemperature) + Weather.ROOM_SUMMER_LIFT * summer
end

-- An unheated aired room by the day's mean, with AIRED_LIFT of a winter lift.
function Weather.airedRoomTemperature(dayTemperature)
    return dayTemperature + Weather.AIRED_LIFT * winterShare(dayTemperature)
end

-- Each place in Weather.PLACES by the ledger's readings: day (the last), season (its mean) and the ledger, for the
-- grid, the room's means and the ground; offGrid for a station's own building, which the grid doesn't warm. The open air and an open roof go by the hour's. A ledger from before the
-- room's means (or a test's) goes by the season in a shut room and by the hour in an aired one.
local function byDay(day) return day end
local PLACE_RULES = {
    Open = byDay,
    Covered = byDay,
    Sheltered = function(_, season, ledger, offGrid)
        if ledger.gridOn and not offGrid then return Weather.GRID_ROOM_C end
        return Weather.roomTemperature(ledger.threeDayTemperature or season)
    end,
    AiredRoom = function(day, _, ledger, offGrid)
        if ledger.gridOn and not offGrid then return Weather.GRID_ROOM_C end
        return Weather.airedRoomTemperature(ledger.dayTemperature or day)
    end,
    -- A ledger from before the ground's mean (or a test's) goes by the season.
    Basement = function(_, season, ledger) return Weather.basementTemperature(ledger.groundTemperature or season) end,
}
for _, place in ipairs(Weather.PLACES) do assert(PLACE_RULES[place], "Weather: no rule for the place " .. place) end

-- The temperature a place has now, from the ledger's last reading. A place Weather doesn't know goes by the day.
function Weather.placeTemperature(ledger, place)
    local stationAir = Weather.STATION_PLACES[place]
    place = stationAir or place
    local fire = Weather.FIRE_PLACES[place]
    if fire then
        if not fire.placeWithoutFire then return fire.celsius end
        return math.min(Weather.placeTemperature(ledger, fire.placeWithoutFire) + fire.lift, fire.celsius)
    end
    local temperature = ledger.temperature or 0
    return (PLACE_RULES[place] or byDay)(temperature, ledger.seasonTemperature or temperature, ledger, stationAir ~= nil)
end

-- Moves means[field] towards reading as a running mean over length hours (SEASON_HOURS if not given).
local function seasonMean(means, field, reading, hours, length)
    local share = math.min(hours / (length or Weather.SEASON_HOURS), 1)
    means[field] = (means[field] or reading) * (1 - share) + reading * share
end

-- Moves the season's mean, a shut room's (ROOM_HOURS) and an aired room's (AIRED_HOURS) towards temperature, and the
-- ground's (GROUND_HOURS behind) towards the season's.
local function addSeason(means, temperature, hours)
    seasonMean(means, "seasonTemperature", temperature, hours)
    seasonMean(means, "threeDayTemperature", temperature, hours, Weather.ROOM_HOURS)
    seasonMean(means, "dayTemperature", temperature, hours, Weather.AIRED_HOURS)
    seasonMean(means, "groundTemperature", means.seasonTemperature, hours, Weather.GROUND_HOURS)
end

-- The running means a ledger copies from the series' weather.
local MEANS = { "seasonTemperature", "threeDayTemperature", "dayTemperature", "groundTemperature" }

-- For tools: a year of daily means in calendar order (each with .month and .mean), settled as a long-running save
-- has them: the year goes round twice first, so January follows December. Returns at(month, offset), the season's
-- and the ground's means at the start of that day of the month; an offset below 0 counts back into the month before.
function Weather.settledMeans(year)
    local means = { seasonTemperature = year[#year].mean }
    local season, ground, first = {}, {}, {}
    for index, day in ipairs(year) do first[day.month] = first[day.month] or index end
    for round = 1, SETTLE_ROUNDS do
        for index, day in ipairs(year) do
            if round == SETTLE_ROUNDS then season[index], ground[index] = means.seasonTemperature, means.groundTemperature end
            addSeason(means, day.mean, HOURS_PER_DAY)
        end
    end
    return function(month, offset)
        local index = (first[month] - 1 + offset) % #year + 1
        return season[index], ground[index]
    end
end

-- The series' weather: { lastHour, temperature, seasonTemperature, threeDayTemperature, dayTemperature,
-- seasonHumidity, groundTemperature, gridOn }, in the core's global ModData.
-- Save key: never rename it.
Weather.SHARED_KEY = "TraditionalPreservationCore"

-- The series' weather in use: the game's, once it runs. Nil in tests and tools, where each ledger grows its own means.
local sharedWeather

-- One reading into the series' weather. gridOn: the power grid is still on.
function Weather.observe(means, now, temperature, humidity, gridOn)
    local hours = math.max(now - (means.lastHour or now), 0)
    means.lastHour = now
    means.temperature = temperature
    means.gridOn = gridOn or nil
    addSeason(means, temperature, hours)
    if humidity then seasonMean(means, "seasonHumidity", humidity, hours) end
end

-- The series' weather, made on first use. Until its first record it would read 0 C, so it starts on the weather
-- there is now. Not while a save loads: the climate reads 0 C until its first update, so the first ten-minute
-- reading starts it instead.
function Weather.weatherModData()
    local coreModData = ModData.getOrCreate(Weather.SHARED_KEY)
    coreModData.ledger = coreModData.ledger or { lastHour = getGameTime():getWorldAgeHours() }
    local weatherModData = coreModData.ledger
    if weatherModData.temperature == nil then
        local climate = getClimateManager and getClimateManager()
        if climate and climate:isUpdated() then
            Weather.observe(weatherModData, weatherModData.lastHour, climate:getTemperature(), climate:getHumidity())
        end
    end
    return weatherModData
end

-- For tests: the weather Weather.seasonTemperature and seasonHumidity copy from, or nil for none.
function Weather.useWeatherModData(weatherModData)
    sharedWeather = weatherModData
end

-- A ledger's season temperature, with the grid's state, the rooms' means and the ground's: the series' own where
-- there is one, else running means of the ledger's own.
function Weather.seasonTemperature(ledger, temperature, hours)
    if sharedWeather then ledger.gridOn = sharedWeather.gridOn end
    if sharedWeather and sharedWeather.seasonTemperature ~= nil then
        for _, field in ipairs(MEANS) do ledger[field] = sharedWeather[field] end
    else
        addSeason(ledger, temperature, hours)
    end
end

-- A ledger's season humidity: the series' where there is one, else a running mean of the ledger's own.
function Weather.seasonHumidity(ledger, humidity, hours)
    if sharedWeather and sharedWeather.seasonHumidity ~= nil then
        ledger.seasonHumidity = sharedWeather.seasonHumidity
    else
        seasonMean(ledger, "seasonHumidity", humidity, hours)
    end
end

-- processes maps each process of work to its rate at a temperature.
function Weather.newLedger(now, processes)
    local ledger = { lastHour = now }
    return Weather.fillLedger(ledger, processes)
end

-- A save from before a process or place was added has no totals for it.
function Weather.fillLedger(ledger, processes)
    for process in pairs(processes) do
        for _, place in ipairs(Weather.PLACES) do
            ledger[process .. place] = ledger[process .. place] or 0
        end
    end
    return ledger
end

-- Adds one stretch of weather to the totals. Returns the hours it covered, or nil if none had passed.
function Weather.advance(ledger, now, temperature, processes)
    local hours = now - ledger.lastHour
    if hours <= 0 then return nil end
    ledger.lastHour = now

    Weather.seasonTemperature(ledger, temperature, hours)
    ledger.temperature = temperature
    -- Each place's temperature once: it is the same for every process.
    local temperatures = {}
    for _, place in ipairs(Weather.PLACES) do temperatures[place] = Weather.placeTemperature(ledger, place) end
    for process, rateAt in pairs(processes) do
        for _, place in ipairs(Weather.PLACES) do
            local rate = rateAt(temperatures[place])
            ledger[process .. place .. "Rate"] = rate
            ledger[process .. place] = (ledger[process .. place] or 0) + rate * hours
        end
    end
    return hours
end

-- The mod's ledger in global ModData, made on first use.
function Weather.getLedger(key, newLedger)
    local ledgerModData = ModData.getOrCreate(key)
    if not ledgerModData.ledger then
        ledgerModData.ledger = newLedger(getGameTime():getWorldAgeHours())
        -- Until its first record a new ledger would read 0 C: it starts on the series' weather.
        local weatherModData = Weather.weatherModData()
        if ledgerModData.ledger.temperature == nil then
            ledgerModData.ledger.temperature = weatherModData.temperature
            for _, field in ipairs(MEANS) do
                ledgerModData.ledger[field] = ledgerModData.ledger[field] or weatherModData[field]
            end
        end
    end
    return ledgerModData.ledger
end

-- Every ten in-game minutes, the weather's resolution in every mod: the series' weather takes its reading first,
-- then each mod's recorder adds the stretch to its own totals.
local recorders = {}
local started = false

local function onTenMinutes()
    local now, climate = getGameTime():getWorldAgeHours(), getClimateManager()
    sharedWeather = Weather.weatherModData()
    local world = getWorld and getWorld()
    Weather.observe(sharedWeather, now, climate:getTemperature(), climate:getHumidity(), world and world:isHydroPowerOn())
    for _, recorder in ipairs(recorders) do recorder(now, climate) end
end

-- Starts the ten-minute readings. The core calls it; so does the first Weather.onReading.
function Weather.start()
    if started then return end
    started = true
    Events.EveryTenMinutes.Add(onTenMinutes)
end

-- Calls recorder(now, climate) at each reading.
function Weather.onReading(recorder)
    Weather.start()
    table.insert(recorders, recorder)
end

-- Marks are each place's total when a run or cask was last brought up to date, and the ledger's hour then (for
-- time by a fire, Fire.catchUp). Work since then is the difference, so a station catches up however long it was away.
function Weather.mark(marks, ledger, process)
    for _, place in ipairs(Weather.PLACES) do marks[place] = ledger[process .. place] end
    marks.hour = ledger.lastHour
    return marks
end

-- The work done at place since the marks, by the station's place now. Moves every mark on.
function Weather.catchUp(marks, ledger, process, place)
    local total = ledger[process .. place]
    local work = total - (marks[place] or total)
    Weather.mark(marks, ledger, process)
    return work
end

-- A run's record starts at nothing, marked on the ledger now (Yeast's cultures). A record that is used again
-- (a culture refreshed) clears its place and fire too.
function Weather.startRun(modData, ledger, process)
    modData.workHours = 0
    modData.marks = Weather.mark({}, ledger, process)
    modData.place, modData.fireUntil, modData.placeWithoutFire = nil, nil, nil
end

return Weather
