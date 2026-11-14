-- Traditional Preservation core: where a station stands decides its temperature, and running totals of the
-- weather in global ModData say how much work each place has done, even while a station was unloaded.
-- Rate curves stay in each mod. A ledger keeps one total and one last rate per kind of work and place,
-- under kind .. place ("" for a mod with one kind, so plain "Open", "OpenRate").
--
-- The weather itself is kept once for the whole series (Weather.shared): the last reading and the season's means.
-- Each mod's ledger copies them at every record, so a mod added to a running save agrees with the others about the
-- temperature under a roof from its first day, where a mean of its own would take ten days to catch up.
-- A craft recipe's bar and clock (startRun, showProgress, setRecipeHours, startClock, showClock, batchStatus) are
-- CraftClock's; Weather passes them on, so callers name Weather only.
local Weather = {}

-- Outdoors goes by the day; a room (Sheltered) and an open roof (Covered: a porch, an open shed) by the season,
-- the mean of the last ten days or so, as an unheated house or shed would; a room a little warmer in winter (ROOM_LIFT). A basement follows the ground: the
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
-- An unheated room is a little warmer than the season's air in the cold months: the house's own mass, the people in
-- it, the sun through its windows. ROOM_LIFT in full at a season of ROOM_LIFT_FULL or below, none from
-- ROOM_LIFT_NONE (a room in summer is the season's). A room (Sheltered) and a loft; never while the grid is on.
Weather.ROOM_LIFT = 2
Weather.ROOM_LIFT_FULL = 10
Weather.ROOM_LIFT_NONE = 18
-- Places by a fire, which the ledger keeps no totals for: work there counts by the clock (Hearth.catchUp). Hearth
-- adds them: place -> { celsius, under, lift }. A fire indoors (no under) holds celsius whatever the weather; one
-- under an open roof or in the open warms that place's air by lift, never past celsius.
Weather.FIRE_PLACES = {}
-- Where something stands when nothing says: a room. (Hearth.DEFAULT_UNDER and FluidAgeing.DEFAULT_PLACE are this.)
Weather.DEFAULT_PLACE = "Sheltered"

local NO_SQUARE_PLACE = "Open"   -- placeOf for an object on no square
local UPSTAIRS_Z = 1             -- the first floor above the ground, where a loft can be
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

-- Below ground is a basement, in a room sheltered, under a roof that isn't a room covered (a porch, an open shed),
-- anything else open. Asks the square, not the object: a player's isOutside() only means "not in a room", while
-- the square's exterior flag also clears under a floor with no walls round it, as a station's isOutside() and the
-- game's rain both see. A player-built shed with walls and a whole roof is a room.
function Weather.placeOf(object)
    local square = object and object:getSquare()
    if not square then return NO_SQUARE_PLACE end
    if square:getZ() < 0 then return "Basement" end
    if not square:isOutside() then
        if not square:isInARoom() then return "Covered" end
        -- A loft is the top storey: upstairs, with no room on the square above (a roof's square is in none).
        if square:getZ() >= UPSTAIRS_Z then
            local above = square:getSquareAbove()
            if not (above and above:isInARoom()) then return "Loft" end
        end
        return "Sheltered"
    end
    return "Open"
end

-- A basement by the ground's temperature: BASEMENT_ANCHOR plus BASEMENT_SWING of the ground's distance from it.
function Weather.basementTemperature(groundTemperature)
    return Weather.BASEMENT_ANCHOR + Weather.BASEMENT_SWING * (groundTemperature - Weather.BASEMENT_ANCHOR)
end

-- An unheated room by the season's mean, with its winter lift (ROOM_LIFT).
function Weather.roomTemperature(seasonTemperature)
    local share = Weather.curve({ { Weather.ROOM_LIFT_FULL, 1 }, { Weather.ROOM_LIFT_NONE, 0 } }, seasonTemperature)
    return seasonTemperature + Weather.ROOM_LIFT * share
end

-- A loft by the season's mean: a room's, plus LOFT_LIFT of what the season is above LOFT_ANCHOR.
function Weather.loftTemperature(seasonTemperature)
    return Weather.roomTemperature(seasonTemperature)
        + Weather.LOFT_LIFT * math.max(seasonTemperature - Weather.LOFT_ANCHOR, 0)
end

-- Each place in Weather.PLACES by the ledger's readings: day (the last), season (its mean) and the ledger, for the
-- grid and the ground. The open air and a shed in it (Enclosed) go by the day's.
local function byDay(day) return day end
local PLACE_RULES = {
    Open = byDay,
    Enclosed = byDay,
    Covered = function(_, season) return season end,
    Sheltered = function(_, season, ledger)
        if ledger.gridOn then return Weather.GRID_ROOM_C end
        return Weather.roomTemperature(season)
    end,
    Loft = function(_, season, ledger)
        if ledger.gridOn then return Weather.GRID_ROOM_C end
        return Weather.loftTemperature(season)
    end,
    -- A ledger from before the ground's mean (or a test's) goes by the season.
    Basement = function(_, season, ledger) return Weather.basementTemperature(ledger.groundTemperature or season) end,
}
for _, place in ipairs(Weather.PLACES) do assert(PLACE_RULES[place], "Weather: no rule for the place " .. place) end

-- The temperature a place has now, from the ledger's last reading. A place Weather doesn't know goes by the day.
function Weather.placeTemperature(ledger, place)
    local fire = Weather.FIRE_PLACES[place]
    if fire then
        if not fire.under then return fire.celsius end
        return math.min(Weather.placeTemperature(ledger, fire.under) + fire.lift, fire.celsius)
    end
    local temperature = ledger.temperature or 0
    return (PLACE_RULES[place] or byDay)(temperature, ledger.seasonTemperature or temperature, ledger)
end

-- Moves state[field] towards value as a running mean over length hours (SEASON_HOURS if not given).
local function seasonMean(state, field, value, hours, length)
    local share = math.min(hours / (length or Weather.SEASON_HOURS), 1)
    state[field] = (state[field] or value) * (1 - share) + value * share
end

-- Moves the season's mean towards temperature, and the ground's (GROUND_HOURS behind) towards the season's.
local function addSeason(state, temperature, hours)
    seasonMean(state, "seasonTemperature", temperature, hours)
    seasonMean(state, "groundTemperature", state.seasonTemperature, hours, Weather.GROUND_HOURS)
end

-- For tools: a year of daily means in calendar order (each with .month and .mean), settled as a long-running save
-- has them: the year goes round twice first, so January follows December. Returns at(month, offset), the season's
-- and the ground's means at the start of that day of the month; an offset below 0 counts back into the month before.
function Weather.settledMeans(year)
    local state = { seasonTemperature = year[#year].mean }
    local season, ground, first = {}, {}, {}
    for index, day in ipairs(year) do first[day.month] = first[day.month] or index end
    for round = 1, SETTLE_ROUNDS do
        for index, day in ipairs(year) do
            if round == SETTLE_ROUNDS then season[index], ground[index] = state.seasonTemperature, state.groundTemperature end
            addSeason(state, day.mean, HOURS_PER_DAY)
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
    addSeason(state, temperature, hours)
    if humidity then seasonMean(state, "seasonHumidity", humidity, hours) end
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

-- For tests: the state Weather.seasonTemperature and seasonHumidity copy from, or nil for none.
function Weather.share(state)
    shared = state
end

-- A ledger's season temperature, with the grid's state and the ground's: the series' own where there is one, else
-- running means of the ledger's own.
function Weather.seasonTemperature(ledger, temperature, hours)
    if shared then ledger.gridOn = shared.gridOn end
    if shared and shared.seasonTemperature ~= nil then
        ledger.seasonTemperature = shared.seasonTemperature
        ledger.groundTemperature = shared.groundTemperature
    else
        addSeason(ledger, temperature, hours)
    end
end

-- A ledger's season humidity: the series' where there is one, else a running mean of the ledger's own.
function Weather.seasonHumidity(ledger, humidity, hours)
    if shared and shared.seasonHumidity ~= nil then
        ledger.seasonHumidity = shared.seasonHumidity
    else
        seasonMean(ledger, "seasonHumidity", humidity, hours)
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

    Weather.seasonTemperature(ledger, temperature, hours)
    ledger.temperature = temperature
    -- Each place's temperature once: it is the same for every kind.
    local temperatures = {}
    for _, place in ipairs(Weather.PLACES) do temperatures[place] = Weather.placeTemperature(ledger, place) end
    for kind, rateAt in pairs(kinds) do
        for _, place in ipairs(Weather.PLACES) do
            local rate = rateAt(temperatures[place])
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

-- Moved to CraftClock, still reached here (DEVGUIDE refactoring rule 5). CraftClock requires Weather, so it is
-- required the first time one of its functions is called.
local craftClock
for _, name in ipairs({ "startRun", "showProgress", "setRecipeHours", "startClock", "showClock", "batchStatus" }) do
    Weather[name] = function(...)
        craftClock = craftClock or require("TraditionalPreservationCore/CraftClock")
        return craftClock[name](...)
    end
end

return Weather
