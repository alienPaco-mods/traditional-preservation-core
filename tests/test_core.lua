-- Checks the shared core in 42/media/lua. Run from TraditionalPreservationCore: luajit tests/test_core.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near

package.path = "42/media/lua/shared/?.lua;" .. package.path
local Weather = require "TraditionalPreservationCore/Weather"
local Windows = require "TraditionalPreservationCore/Windows"
local Station = dofile("42/media/lua/shared/TraditionalPreservationCore/Station.lua")

-- Weather
local points = { { 0, 0.1 }, { 10, 0.5 }, { 20, 1 } }
check("curve: flat below the first point", Weather.curve(points, -5) == 0.1)
check("curve: flat past the last point", Weather.curve(points, 30) == 1)
check("curve: straight between points", near(Weather.curve(points, 5), 0.3) and near(Weather.curve(points, 15), 0.75))
check("scaled: off runs at full speed", Weather.scaled(0.2, 0, 0.02) == 1)
check("scaled: harsh slows more, down to the floor", near(Weather.scaled(0.8, 1.5, 0.02), 0.7) and Weather.scaled(0, 1.5, 0.02) == 0.02)
check("frozen: at or below the freezing point on any sensitivity but Off", Weather.frozen(0, 1) and Weather.frozen(-5, 0.5)
    and Weather.frozen(-3, 1.5, -3) and not Weather.frozen(-2, 1, -3) and not Weather.frozen(0.5, 1) and not Weather.frozen(-20, 0))
local testCurve = { { 0, 0.2 }, { 20, 1 } }
check("rate: frozen is 0, else the curve after the sensitivity, never under the floor", Weather.rate(testCurve, 0, 1) == 0
    and Weather.rate(testCurve, -2, 1, 0.5, -3) == 0.5 and near(Weather.rate(testCurve, 10, 1), 0.6)
    and near(Weather.rate(testCurve, 10, 1.5), 0.4) and Weather.rate(testCurve, 10, 1.5, 0.5) == 0.5
    and Weather.rate(testCurve, -5, 0) == 1)
check("an unknown place goes by the day; every place has a rule", Weather.placeTemperature({ temperature = 7, seasonTemperature = 15 }, "Nowhere") == 7
    and Weather.DEFAULT_PLACE == "Sheltered")
check("a batch paused there has no time left", Weather.batchStatus(5, 10, { temperature = -5, seasonTemperature = -5 }, "Open",
    function() return 0 end).hoursLeft == nil)
check("a running batch's recipe hours are its script time", Weather.recipeHours({ getRecipe = function()
    return { getTime = function() return 5 * 3600 end } end }) == 5)
local ledger = { temperature = 30, seasonTemperature = 12 }
check("place: open goes by the hour", Weather.placeTemperature(ledger, "Open") == 30)
check("place: an open roof by the hour too", Weather.placeTemperature(ledger, "Covered") == 30)
check("place: a shut room with no three-day mean yet by the season, a little warmer in a cool one",
    near(Weather.placeTemperature(ledger, "Sheltered"), 13.5))
check("place: a shut room by the three-day mean", near(Weather.placeTemperature({ temperature = 30, seasonTemperature = 12,
    threeDayTemperature = 4 }, "Sheltered"), 6))
check("room: 2 C warmer from a 10 C mean down, nothing at 18 C", Weather.roomTemperature(-5) == -3
    and Weather.roomTemperature(10) == 12 and near(Weather.roomTemperature(14), 15) and Weather.roomTemperature(18) == 18)
check("room: stuffy in summer, up to 2 C from a 21 C mean", near(Weather.roomTemperature(19.5), 20.5)
    and Weather.roomTemperature(21) == 23 and Weather.roomTemperature(25) == 27)
check("aired room: 1 C warmer from a 10 C mean down, nothing from 18 C, never stuffy",
    Weather.airedRoomTemperature(-5) == -4 and near(Weather.airedRoomTemperature(14), 14.5)
    and Weather.airedRoomTemperature(25) == 25)
check("place: an aired room by the day's mean, by the hour with none yet",
    Weather.placeTemperature({ temperature = 30, seasonTemperature = 12, dayTemperature = 0 }, "AiredRoom") == 1
    and Weather.placeTemperature(ledger, "AiredRoom") == 30)
check("place: a basement with no ground mean yet swings two fifths as far as the season", near(Weather.placeTemperature(ledger, "Basement"), 10.8))
check("place: a basement goes by the ground once there is one", near(Weather.placeTemperature({ temperature = 30, seasonTemperature = 12,
    groundTemperature = 20 }, "Basement"), 14))
check("basement: about 5 C at the ground's coldest (March), 13 at its warmest (August)", near(Weather.basementTemperature(-2.6), 4.96)
    and near(Weather.basementTemperature(18.6), 13.44))
local gridOn = { temperature = 0, seasonTemperature = -5, gridOn = true }
check("place: both rooms are 22 C while the grid is on, an open roof and a basement are not",
    Weather.placeTemperature(gridOn, "Sheltered") == Weather.GRID_ROOM_C
    and Weather.placeTemperature(gridOn, "AiredRoom") == Weather.GRID_ROOM_C
    and Weather.placeTemperature(gridOn, "Covered") == 0 and Weather.placeTemperature(gridOn, "Basement") < 10)
check("basement: the anchor holds still", Weather.basementTemperature(Weather.BASEMENT_ANCHOR) == Weather.BASEMENT_ANCHOR)
Weather.STATION_PLACES.TestShed = "AiredRoom"
check("a station's inside goes by the air it names (the Smokehouse: an aired room's), never the grid's",
    Weather.placeTemperature({ temperature = 2, seasonTemperature = 8, dayTemperature = 12, gridOn = true }, "TestShed") == 12.75)
Weather.STATION_PLACES.TestShed = nil

-- Squares: a small world of them, in rooms or not, with windows on their north and west edges.
H.installClock(0)
function instanceof(object, name) return type(object) == "table" and object.class == name end
local world = {}
getCell = function() return { getGridSquare = function(_, x, y, z) return world[x .. "," .. y .. "," .. z] end } end
-- The game's per-wall lookups (IsoGridSquare.getEdgeElementTo): the object of a class on the wall between a and b.
-- Walls stand on a square's north and west edges, so the wall to the north or west is a's own, else b's.
local function onWall(a, b, isKind)
    local dx, dy = b:getX() - a:getX(), b:getY() - a:getY()
    local owner, north = a, dy ~= 0
    if dx == 1 or dy == 1 then owner = b end
    for _, isoObject in ipairs(owner.objects) do
        if isKind(isoObject) then
            local edgeNorth = isoObject.class == "IsoThumpable" and isoObject:isWindowN() or isoObject.class ~= "IsoThumpable" and isoObject:isNorth()
            if (edgeNorth == true) == north then return isoObject end
        end
    end
    return nil
end
IsoFlagType = { DoorWallN = "DoorWallN", DoorWallW = "DoorWallW" }
local function square(x, y, z, roomId, region)
    local sq = { objects = {}, flags = {} }
    function sq:has(flag) return sq.flags[flag] == true end
    function sq:getX() return x end
    function sq:getY() return y end
    function sq:getZ() return z end
    function sq:isOutside() return roomId == nil and region == nil end
    function sq:isInARoom() return roomId ~= nil or region ~= nil end
    function sq:getRoomID() return roomId or -1 end
    function sq:getIsoWorldRegion()
        return region and { isPlayerRoom = function() return true end, getID = function() return region end } or nil
    end
    function sq:getWindowTo(next) return onWall(sq, next, function(o) return o.class == "IsoWindow" end) end
    function sq:getWindowFrameTo(next) return onWall(sq, next, function(o) return o.class == "IsoWindowFrame" end) end
    function sq:getWindowThumpableTo(next)
        return onWall(sq, next, function(o) return o.class == "IsoThumpable" and o:isWindow() end)
    end
    function sq:getDoorTo(next)
        return onWall(sq, next, function(o) return o.class == "IsoDoor" or o.class == "IsoThumpable" and o.door end)
    end
    world[x .. "," .. y .. "," .. z] = sq
    return sq
end
-- A 3 x 3 room (id 7) at 0..2, 0..2 on level z, with the outside round it; a neighbouring room (id 8) to the east at x 3.
local function house(z, room, region)
    for x = -1, 4 do
        for y = -1, 3 do
            local inside = x >= 0 and x <= 2 and y >= 0 and y <= 2
            local next = x == 3 and y >= 0 and y <= 2
            square(x, y, z, inside and room or (next and 8 or nil), inside and region or nil)
        end
    end
end
local function window(state)
    local w = { class = "IsoWindow", north = state.north or false }
    function w:isNorth() return self.north end
    function w:IsOpen() return state.open or false end
    function w:isSmashed() return state.smashed or false end
    function w:isGlassRemoved() return state.glassRemoved or false end
    function w:isBarricaded() return state.barricaded or false end
    return w
end
local function frame(state)
    local f = { class = "IsoWindowFrame" }
    function f:isNorth() return state.north or false end
    function f:hasWindow() return state.hasWindow or false end
    function f:isBarricaded() return state.barricaded or false end
    return f
end
-- What else stands on a square, as in game: a wall, the floor, a crate, a built door. None has isNorth (calling it
-- would fail, as the first build did in game: "tried to call nil in onEdge").
local others = { { class = "IsoObject" }, { class = "IsoWorldInventoryObject" },
    { class = "IsoThumpable", isWindow = function() return false end } }
local function on(isoObject, x, y, z)
    Windows.forget()
    local objects = { isoObject }
    for _, other in ipairs(others) do table.insert(objects, 1, other) end
    world[x .. "," .. y .. "," .. z].objects = objects
    return isoObject
end
local function standing(x, y, z) return { getSquare = function() return world[x .. "," .. y .. "," .. z] end } end
house(0, 7)
for _, where in ipairs({ "0,1,0", "1,0,0", "1,3,0", "3,1,0" }) do world[where].objects = { others[1], others[3] } end
check("placeOf: a room with every window shut is sheltered", Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
on(window({ open = true }), 0, 1, 0)
check("placeOf: an open window on the room's west wall airs it, wherever the station stands in the room",
    Weather.placeOf(standing(1, 1, 0)) == "AiredRoom" and Weather.placeOf(standing(2, 2, 0)) == "AiredRoom")
on(window({ open = true, barricaded = true }), 0, 1, 0)
check("placeOf: a barricaded one doesn't", Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
on(window({ smashed = true }), 0, 1, 0)
check("placeOf: a smashed window airs it", Weather.placeOf(standing(1, 1, 0)) == "AiredRoom")
on(window({ glassRemoved = true }), 0, 1, 0)
check("placeOf: so does one with its glass taken out", Weather.placeOf(standing(1, 1, 0)) == "AiredRoom")
on(window({}), 0, 1, 0)
check("placeOf: a shut window doesn't", Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
on(window({ open = true, north = true }), 1, 0, 0)
check("placeOf: an open window on the north wall", Weather.placeOf(standing(1, 1, 0)) == "AiredRoom")
world["1,0,0"].objects = {}
on(window({ open = true, north = true }), 1, 3, 0)
check("placeOf: on the south wall (the square south of the room holds it)", Weather.placeOf(standing(1, 1, 0)) == "AiredRoom")
world["1,3,0"].objects = {}
on(frame({}), 0, 2, 0)
check("placeOf: an empty window frame airs it", Weather.placeOf(standing(1, 1, 0)) == "AiredRoom")
on(frame({ barricaded = true }), 0, 2, 0)
check("placeOf: not once boarded", Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
on(frame({ hasWindow = true }), 0, 2, 0)
check("placeOf: a frame with a window in it goes by the window", Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
world["0,2,0"].objects = {}
on(window({ open = true }), 3, 1, 0)
check("placeOf: an open window into the next room doesn't air this one", Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
local function door(state)
    local d = { class = "IsoDoor" }
    function d:isNorth() return state.north or false end
    function d:IsOpen() return state.open or false end
    function d:isBarricaded() return state.barricaded or false end
    return d
end
on(door({ open = true }), 0, 1, 0)
check("placeOf: an open outside door airs it", Weather.placeOf(standing(1, 1, 0)) == "AiredRoom")
on(door({}), 0, 1, 0)
check("placeOf: a shut one doesn't", Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
on(door({ open = true, barricaded = true }), 0, 1, 0)
check("placeOf: nor a barricaded one", Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
world["0,1,0"].objects = {}
on(door({ open = true }), 3, 1, 0)
check("placeOf: an open door into the next room doesn't air this one", Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
world["3,1,0"].objects = {}
local builtDoor = { class = "IsoThumpable", door = true }
function builtDoor:isWindow() return false end
function builtDoor:isWindowN() return true end
function builtDoor:IsOpen() return true end
function builtDoor:isBarricaded() return false end
on(builtDoor, 1, 0, 0)
check("placeOf: an open built door to the outside airs it", Weather.placeOf(standing(1, 1, 0)) == "AiredRoom")
world["1,0,0"].objects = {}
Windows.forget()
world["0,1,0"].flags.DoorWallW = true
check("placeOf: an empty doorway (its door broken off) on the west wall airs it", Weather.placeOf(standing(1, 1, 0)) == "AiredRoom")
on(door({}), 0, 1, 0)
check("placeOf: with a shut door in it, it doesn't", Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
world["0,1,0"].objects, world["0,1,0"].flags = {}, {}
Windows.forget()
world["1,3,0"].flags.DoorWallN = true
check("placeOf: an empty doorway on the south wall (the square south of the room owns it)",
    Weather.placeOf(standing(1, 1, 0)) == "AiredRoom")
world["1,3,0"].flags = {}
Windows.forget()
world["3,1,0"].flags.DoorWallW = true
check("placeOf: an empty doorway into the next room doesn't", Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
world["3,1,0"].flags = {}
world["3,1,0"].objects = {}
on(window({ open = true, north = true }), 1, 0, 0)
Weather.placeOf(standing(1, 1, 0))
H.setHours(1 / 12)
local wall = world["1,0,0"].objects
wall[#wall] = window({ north = true })
check("placeOf: a room's answer holds for the reading", Weather.placeOf(standing(1, 1, 0)) == "AiredRoom")
H.setHours(1 / 6)
check("a window shut counts from the next reading", Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
Weather.placeOf(standing(3, 1, 0))
local both = Windows.keptCount()
H.setHours(2 / 6)
Weather.placeOf(standing(1, 1, 0))
check("a new reading keeps only the rooms looked at since", both == 2 and Windows.keptCount() == 1)
-- The frame budget: one scan in SCAN_GAP_MS of real time; a room due inside it keeps the last reading's answer.
local clockMs = 1000
getTimestampMs = function() return clockMs end
Windows.forget()
H.setHours(3 / 6)
world["1,0,0"].objects = { window({ open = true, north = true }) }
check("a scan when the budget allows", Weather.placeOf(standing(1, 1, 0)) == "AiredRoom")
H.setHours(4 / 6)
world["1,0,0"].objects = { window({ north = true }) }
clockMs = clockMs + 5
local waited = Weather.placeOf(standing(3, 1, 0))
local kept = Weather.placeOf(standing(1, 1, 0))
check("a second room inside the budget waits: no answer before (shut), and a room due again keeps its last",
    waited == "Sheltered" and kept == "AiredRoom")
clockMs = clockMs + Windows.SCAN_GAP_MS
check("once the budget allows, it is read again", Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
getTimestampMs = nil
world["1,0,0"].objects = { window({ open = true, north = true }) }
Windows.forget()
H.setHours(5 / 6)
Weather.placeOf(standing(1, 1, 0))
world["1,0,0"].objects = { window({ north = true }) }
check("measure: a fresh scan replaces the room's kept answer at once", Weather.placeOf(standing(1, 1, 0)) == "AiredRoom"
    and Windows.measure(world["1,1,0"]).aired == false and Weather.placeOf(standing(1, 1, 0)) == "Sheltered")
local measured = Windows.measure(world["1,1,0"])
check("measure: a fresh scan of the room, its squares, outside walls (12 less the 3 to the room next door) and calls",
    measured.aired == false and measured.squares == 9 and measured.walls == 9 and measured.calls > 0 and Windows.measure(world["-1,-1,0"]) == nil)
local saved = Windows.MAX_SQUARES
Windows.MAX_SQUARES = 4
check("a room past the cap is read that far from the station", Windows.measure(world["1,1,0"]).squares == 4)
Windows.MAX_SQUARES = saved
house(1, nil, 42)
local built = { class = "IsoThumpable" }
function built:isWindow() return true end
function built:isWindowN() return false end
function built:isWindowW() return true end
function built:IsOpen() return true end
function built:isBarricaded() return false end
on(built, 0, 1, 1)
check("placeOf: a room a player built (a world region), upstairs, with its built window open", Weather.placeOf(standing(1, 1, 1)) == "AiredRoom")
function built:IsOpen() return false end
Windows.forget()
check("placeOf: shut, sheltered", Weather.placeOf(standing(1, 1, 1)) == "Sheltered")

local function object(z, outside)
    return { getSquare = function() return square(9, 9, z, not outside and 99 or nil) end }
end
check("placeOf: below ground", Weather.placeOf(object(-1, false)) == "Basement")
check("placeOf: in a room", Weather.placeOf(object(0, false)) == "Sheltered")
check("placeOf: outdoors", Weather.placeOf(object(1, true)) == "Open")
-- A player under a floor with no walls: the player's own isOutside() says yes (not in a room), the square says no.
local player = object(0, false)
function player:isOutside() return true end
check("placeOf: asks the square, not a player", Weather.placeOf(player) == "Sheltered")
check("placeOf: nothing to stand on is open", Weather.placeOf({ getSquare = function() return nil end }) == "Open")
local porch = square(20, 20, 0)
function porch:isOutside() return false end
check("placeOf: a porch is covered", Weather.placeOf({ getSquare = function() return porch end }) == "Covered")

local kinds = { [""] = function(celsius) return celsius >= 10 and 1 or 0.5 end }
ledger = Weather.newLedger(0, kinds)
check("ledger: zero totals for every place", ledger.Open == 0 and ledger.Covered == 0
    and ledger.Sheltered == 0 and ledger.Basement == 0)
check("advance: nothing when no time has passed", Weather.advance(ledger, 0, 20, kinds) == nil)
check("advance: returns its hours", Weather.advance(ledger, 2, 5, kinds) == 2)
check("advance: open counts the day", ledger.Open == 1 and ledger.OpenRate == 0.5)
check("advance: an open roof counts the hour, a room its means", ledger.Covered == 1 and ledger.Sheltered == 1
    and ledger.AiredRoom == 1 and near(ledger.threeDayTemperature, 5) and near(ledger.dayTemperature, 5))
check("advance: the first record is the season", near(ledger.seasonTemperature, 5))
Weather.advance(ledger, 2 + Weather.SEASON_HOURS * 2, 25, kinds)
check("season: a gap longer than a season replaces it", near(ledger.seasonTemperature, 25))
local filled = Weather.fillLedger({ malting = nil }, { malting = true, acetic = true })
check("fillLedger: adds missing totals", filled.maltingBasement == 0 and filled.aceticOpen == 0)

-- Catching up
ledger = { Open = 10, Sheltered = 20, Basement = 30 }
local marks = Weather.mark({}, ledger, "")
ledger.Open, ledger.Sheltered, ledger.Basement = 14, 25, 36
check("catchUp: the work at the station's place", Weather.catchUp(marks, ledger, "", "Sheltered") == 5)
check("catchUp: moves every mark on", marks.Open == 14 and marks.Sheltered == 25 and marks.Basement == 36)
check("catchUp: a new place with no mark counts nothing", Weather.catchUp({}, ledger, "", "Open") == 0)

-- The plain clock
local recipe = { modData = {}, elapsed = 12 }
function recipe:getModData() return self.modData end
function recipe:setElapsedTime(value) self.elapsed = value end
function recipe:getRecipe() return { getTime = function() return 7200 end } end
Weather.showClock(recipe, "runStartHour", 100)
check("showClock: a run with no start hour is left alone", recipe.elapsed == 12)
Weather.startClock(recipe, "runStartHour", 100)
Weather.showClock(recipe, "runStartHour", 101)
check("showClock: one hour is 3600 seconds", recipe.elapsed == 3600)
Weather.showClock(recipe, "runStartHour", 150)
check("showClock: time away finishes the run, and no further", recipe.elapsed == 7200)
Weather.startClock(recipe, "runStartHour", 100)
Weather.showClock(recipe, "runStartHour", 100.5, 3)
check("showClock: a speed runs the bar faster", recipe.elapsed == 1.5 * 3600)

H.installClock(50)
H.installModData()
local made = 0
local function newLedger(now) made = made + 1 return Weather.newLedger(now, kinds) end
local first = Weather.getLedger("Key", newLedger)
check("getLedger: made once, in ModData", Weather.getLedger("Key", newLedger) == first and made == 1 and first.lastHour == 50)
check("getLedger: no climate yet, no reading yet", first.temperature == nil)
local outside, damp, updated = 12, 60, false
getClimateManager = function()
    return { isUpdated = function() return updated end, getTemperature = function() return outside end,
        getHumidity = function() return damp end }
end
local loading = Weather.getLedger("Loading", newLedger)
check("getLedger: a save loading, the climate not yet run, is not read", loading.temperature == nil
    and Weather.weatherModData().temperature == nil and Weather.weatherModData().seasonTemperature == nil)
updated = true
local seeded = Weather.getLedger("Seeded", newLedger)
check("getLedger: a new ledger starts on the weather there is", Weather.placeTemperature(seeded, "Open") == 12
    and Weather.placeTemperature(seeded, "Covered") == 12)

-- One weather for the series: every mod's ledger copies its season means at each record.
H.installEvents()
local series = Weather.weatherModData()
check("shared: the core's own ModData, read once at the start", H.modData[Weather.SHARED_KEY].ledger == series
    and series.temperature == 12 and series.seasonTemperature == 12 and series.seasonHumidity == 60)
local old = Weather.getLedger("OldMod", newLedger)
local recorded = 0
Weather.onReading(function(now, climate)
    recorded = recorded + 1
    Weather.advance(old, now, climate:getTemperature(), kinds)
end)
Weather.onReading(function() recorded = recorded + 1 end)
for hour = 51, 50 + Weather.SEASON_HOURS do
    H.setHours(hour)
    outside = 30
    H.fire("EveryTenMinutes")
end
check("onReading: every recorder runs at each reading", recorded == 2 * Weather.SEASON_HOURS)
check("shared: the season mean follows the weather", series.temperature == 30 and series.seasonTemperature > 22
    and series.seasonTemperature < 30)
check("a ledger's season mean is the series' own", old.seasonTemperature == series.seasonTemperature)
local late = Weather.getLedger("AddedLater", newLedger)
check("a mod added later agrees with the others from its first day", late.temperature == 30
    and Weather.placeTemperature(late, "Sheltered") == Weather.placeTemperature(old, "Sheltered"))
local own = { lastHour = 0 }
Weather.seasonHumidity(own, 40, 1)
check("season: the series' humidity too", own.seasonHumidity == series.seasonHumidity)
Weather.observe(series, series.lastHour + 1, 5, 50, true)
Weather.seasonTemperature(own, 5, 1)
check("season: a ledger learns the grid is on from the series", own.gridOn == true)
Weather.observe(series, series.lastHour + 1, 5, 50, false)
Weather.seasonTemperature(own, 5, 1)
check("and that it went off", own.gridOn == nil)
Weather.useWeatherModData(nil)
Weather.seasonHumidity(own, 40, Weather.SEASON_HOURS)
check("season: with no series' weather a ledger grows its own mean", own.seasonHumidity == 40)
getClimateManager = nil

-- Station
local cellSquares = {}
getCell = function()
    return { getGridSquare = function(_, x, y, z) return cellSquares[x .. "," .. y .. "," .. z] end }
end
local function square(x, y, z)
    return { getX = function() return x end, getY = function() return y end, getZ = function() return z end }
end
local function worldObject(sq, index)
    return { square = sq, index = index or 0,
        getSquare = function(self) return self.square end,
        getObjectIndex = function(self) return self.index end }
end
local here = square(1, 2, 0)
cellSquares["1,2,0"] = here
local loaded = worldObject(here)
check("isLoaded: on a square the cell still has", Station.isLoaded(loaded))
local unloaded = worldObject(square(1, 2, 0))
check("isLoaded: not once the cell has let go of its square", not Station.isLoaded(unloaded))
check("isLoaded: not when removed", not Station.isLoaded(worldObject(here, -1)))
check("isLoaded: not without a square", not Station.isLoaded(worldObject(nil)))

H.installEvents()
local loadHandlers = {}
MapObjects = { OnLoadWithSprite = function(name, handler, priority) loadHandlers[name] = { handler, priority } end }
local refreshed = {}
local other = worldObject(square(3, 3, 0))
cellSquares["3,3,0"] = other.square
local tracker
tracker = Station.tracker({
    sprites = { "a_0", "a_1" },
    newSessionState = function() return { made = true } end,
    ticks = 2,
    refresh = function(station, sessionState)
        table.insert(refreshed, station)
        if station == loaded then tracker.track(other) end
    end,
})
tracker.start()
check("start: registers every sprite with the map loader", loadHandlers.a_0 and loadHandlers.a_1[2] == Station.MAP_PRIORITY)
check("start: hands the loader track", loadHandlers.a_0[1] == tracker.track)
local sessionState = tracker.track(loaded)
check("track: makes the session state once", sessionState.made and tracker.track(loaded) == sessionState and tracker.sessionStateOf(loaded) == sessionState)
tracker.track(unloaded)
H.fire("OnTick")
check("onTick: waits its ticks", #refreshed == 0)
H.fire("OnTick")
check("onTick: refreshes the loaded station", #refreshed == 1 and refreshed[1] == loaded)
check("onTick: drops the unloaded one", tracker.sessionStateOf(unloaded) == nil)
check("onTick: a refresh can track another station", tracker.sessionStateOf(other) ~= nil)
local refusing = Station.tracker({ sprites = {}, newSessionState = function() return nil end, refresh = function() end })
check("track: a session state of nil leaves the object alone", refusing.track(loaded) == nil and refusing.sessionStateOf(loaded) == nil)
check("track: the default session state is a table", Station.tracker({ sprites = {}, refresh = function() end }).track(loaded) ~= nil)

local shown = { names = {}, clears = 0 }
local drawn = {
    clearAttachedAnimSprite = function() shown.clears = shown.clears + 1 shown.names = {} end,
    addAttachedAnimSpriteByName = function(_, name) table.insert(shown.names, name) end,
}
local spriteEntry = {}
Station.showSprites(drawn, spriteEntry, "1,2", { "x_1", "x_2" })
check("showSprites: layers in order", shown.names[1] == "x_1" and shown.names[2] == "x_2")
Station.showSprites(drawn, spriteEntry, "1,2", { "x_1", "x_2" })
check("showSprites: leaves an unchanged station alone", shown.clears == 1)
local movable = { modData = {} }
function movable:getModData() return self.modData end
Station.movableData(movable).ml = 5
check("movableData: kept in modData.movableData", movable.modData.movableData.ml == 5)

-- UI
H.installGetText({ T_Time = "%1 d %2 h", T_Soured = "%1 soured", T_None = "plain" })
-- Stand-ins for the requires and the vanilla classes it wraps: the core's own modules load for real.
H.useModPaths()
local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end
ISWidgetCraftLogicOutputProgress = { updateProgressItems = function(self) self.vanillaRan = true end }
local placed
ISMoveableSpriteProps = { canPlaceMoveable = function() placed = true return true end }
local UI = require "TraditionalPreservationCore/UI"
check("say: values go in after the translator", UI.say("T_Soured", UI.percent(0.4)) == "40% soured" and #H.textWarnings == 0)
check("say: a text with no values", UI.say("T_None") == "plain")
check("timeText: rounds up to the hour", UI.timeText(25.2, "T_Time") == "1 d 2 h")
check("timeText: whole days", UI.timeText(48, "T_Time") == "2 d 0 h")
-- Selected items: a collapsed stack lists its first item twice.
local selInstanceof = instanceof
instanceof = function(object, class) return class == "InventoryItem" and object.item == true end
local loose, a1, a2, b1 = { item = true, n = 1 }, { item = true, n = 2 }, { item = true, n = 3 }, { item = true, n = 4 }
local picked = { loose, { items = { a1, a1, a2 } }, { items = { b1, b1 } } }
local all = UI.selectedItems(picked)
check("selectedItems: each once", #all == 4 and all[1] == loose and all[2] == a1 and all[3] == a2 and all[4] == b1)
local odd = UI.selectedItems(picked, function(item) return item.n % 2 == 0 end)
check("selectedItems: only those wanted", #odd == 2 and odd[1] == a1 and odd[2] == b1)
local first, why = UI.firstSelected(picked, function(item) return item.n > 1 and "yes" end)
check("firstSelected: a stack by its first item, with what wanted gave", first == a1 and why == "yes")
check("firstSelected: none", UI.firstSelected(picked, function() return nil end) == nil)
instanceof = selInstanceof
-- Tainted water: "Water", plus vanilla's "(Tainted)" only when the sandbox's tainted water text is on.
H.texts.Fluid_Tainted = "(Tainted)"
local savedFluid, taintedText = Fluid, true
Fluid = { Get = function(name) return { getTranslatedName = function() return name == "CowMilk" and "Cow's Milk" or "Water" end } end }
getSandboxOptions = function()
    return { getOptionByName = function(_, option)
        return option == "EnableTaintedWaterText" and { getValue = function() return taintedText end } or nil
    end }
end
check("fluidName: tainted water says so when the sandbox shows it", UI.fluidName("TaintedWater") == "Water (Tainted)"
    and UI.fluidName("Water") == "Water" and UI.fluidName("CowMilk") == "Cow's Milk")
taintedText = false
check("fluidName: and is plain Water when it doesn't", UI.fluidName("TaintedWater") == "Water")
Fluid, getSandboxOptions = savedFluid, nil
local fakeTexts = H.texts
H.installGetText()
local words = {}
for _, place in ipairs({ "Open", "Covered", "Sheltered", "Basement", "Smokehouse", "Fireside", "Embers" }) do table.insert(words, UI.placeName(place)) end
check("place words: one set for the series", table.concat(words, ", ")
    == "Open air, Under an open roof, Indoors, Basement, In the Smokehouse, By a fire, By banked embers")
check("placeText: the temperature, then the place", UI.placeText("Sheltered", 12.4) == "12°C (Indoors)" and #H.textWarnings == 0)
H.installGetText(fakeTexts)

local function slot(name)
    local recipe = name and { getName = function() return "Mod." .. name end }
    return { craftRecipeData = { getRecipe = function() return recipe end } }
end
local seen = {}
UI.onProgressSlot(function(s, name) table.insert(seen, tostring(name)) end)
local drew
UI.progressTooltips({ Ferment = function(s, tooltip, name, entity) drew = { name, entity } end })
local slots = { slot("Ferment"), slot("Other"), slot(nil) }
local widget = { entity = "shelf", progressItems = { getItemSlots = function() return slots end } }
ISWidgetCraftLogicOutputProgress.updateProgressItems(widget)
check("progress hook: runs vanilla first", widget.vanillaRan)
check("progress hook: every slot, by short name", table.concat(seen, ",") == "Ferment,Other,nil")
check("progressTooltips: only the named recipe", slots[1].drawTooltip and not slots[2].drawTooltip and not slots[3].drawTooltip)
slots[1].drawTooltip(slots[1], {})
check("progressTooltips: draws with the name and station", drew[1] == "Ferment" and drew[2] == "shelf")

UI.outdoorOnly({ beam_0 = true })
local inside = { isOutside = function() return false end }
check("outdoorOnly: refuses an indoor square", ISMoveableSpriteProps.canPlaceMoveable({ spriteName = "beam_0" }, nil, inside) == false and not placed)
check("outdoorOnly: other sprites go to vanilla", ISMoveableSpriteProps.canPlaceMoveable({ spriteName = "cask_0" }, nil, inside) and placed)
local placeWrap = ISMoveableSpriteProps.canPlaceMoveable
UI.notInRooms({ rack_0 = true })
check("placement: every put-down rule shares one wrap", ISMoveableSpriteProps.canPlaceMoveable == placeWrap)
local porch = { isOutside = function() return false end, isInARoom = function() return false end }
local room = { isOutside = function() return false end, isInARoom = function() return true end }
check("notInRooms: takes a porch", ISMoveableSpriteProps.canPlaceMoveable({ spriteName = "rack_0" }, nil, porch))
check("notInRooms: refuses a room", ISMoveableSpriteProps.canPlaceMoveable({ spriteName = "rack_0" }, nil, room) == false)

-- offAppliances: an object is instanceof its .class; containers by type.
instanceof = function(object, class) return object.class == class end
local function thing(class, ...)
    local types = { ... }
    return { class = class, getContainerCount = function() return #types end,
             getContainerByIndex = function(_, i) return { getType = function() return types[i + 1] end } end }
end
local function squareWith(...)
    local list = { ... }
    return { isOutside = function() return true end,
             getObjects = function() return { size = function() return #list end, get = function(_, i) return list[i + 1] end } end }
end
UI.offAppliances({ crock_2 = true })
local crock = { spriteName = "crock_2" }
for _, case in ipairs({
    { "a stove", thing("IsoStove") },
    { "a chest freezer", thing("IsoObject", "freezer") },
    { "a fridge-freezer", thing("IsoObject", "fridge", "freezer") },
    { "a washer", thing("IsoClothingWasher") },
}) do
    placed = false
    check("offAppliances: refuses " .. case[1], ISMoveableSpriteProps.canPlaceMoveable(crock, nil, squareWith(thing("IsoObject"), case[2])) == false and not placed)
end
placed = false
check("offAppliances: a counter with drawers goes to vanilla", ISMoveableSpriteProps.canPlaceMoveable(crock, nil, squareWith(thing("IsoObject", "counter"))) and placed)
placed = false
check("offAppliances: other sprites go to vanilla", ISMoveableSpriteProps.canPlaceMoveable({ spriteName = "cask_0" }, nil, squareWith(thing("IsoStove"))) and placed)

-- keepDoorsFree takes a mod's Tiles.STATIONS list as well as a set.
local Doors = require "TraditionalPreservationCore/Doors"
local savedFits, asked = Doors.fits, {}
Doors.fits = function(_, name) table.insert(asked, name) return false end
UI.keepDoorsFree({ "cask_0", "cask_1" })
UI.keepDoorsFree({ shelf_0 = true })
local refused = 0
for _, name in ipairs({ "cask_0", "cask_1", "shelf_0", "rug_0" }) do
    placed = false
    if ISMoveableSpriteProps.canPlaceMoveable({ spriteName = name }, nil, squareWith()) == false then refused = refused + 1 end
end
check("keepDoorsFree: a list or a set, other sprites not asked", refused == 3 and #asked == 3)
Doors.fits = savedFits

-- slotRules, twice as two mods would: each mod's stations go to its own rules, the rest on to vanilla.
ResourceIO = { Input = "in", Output = "out" }
local vanillaAdds, vanillaUps, halos, queuedActions = 0, 0, {}, {}
ISCraftLogicPanel = { ItemSlotAddItems = function() vanillaAdds = vanillaAdds + 1 end }
ISItemSlot = { defaultVerifyItem = function() return true end, onMouseUp = function() vanillaUps = vanillaUps + 1 end }
HaloTextHelper = { addBadText = function(_, text) table.insert(halos, text) end }
ISEntityUI = { WalkToEntity = function() return true end }
ISItemSlotAddAction = { new = function(_, _, _, item) return { item = item } end }
instanceof = function(object, class) return class == "IsoObject" and not object.isItem end
ISTimedActionQueue = { add = function(action) table.insert(queuedActions, action) end }
ISMouseDrag = {}
ISInventoryPane = { getActualItems = function(dragging) return dragging end }
function getPlayer() return "player" end
local function station(name, free)
    local entity = { name = name, component = { free = free, getCurrentRecipe = function() return nil end } }
    local resource = { getIO = function() return ResourceIO.Input end, getGameEntity = function() return entity end }
    return { resource = resource }, entity
end
local tracked = {}
local function rulesFor(name, refusalKey)
    UI.slotRules{
        station = function(entity) if entity and entity.name == name then return entity.component, name end end,
        refusal = function(s, item, queued)
            if item == "wrong" then return refusalKey end
            if #queued >= s.component.free then return "T_Full" end
        end,
        added = function(entity) tracked[entity] = true end,
    }
end
rulesFor("cask", "T_NotCask")
rulesFor("shelf", "T_NotShelf")
local caskSlot, cask = station("cask", 2)
ISCraftLogicPanel.ItemSlotAddItems("player", cask, caskSlot, { "a", "b", "c" }, cask.component)
check("slotRules: adds until the refusal, then says why", #queuedActions == 2 and halos[1] == getText("T_Full") and tracked[cask])
check("slotRules: each queued action asks again", queuedActions[1].tpSlot.extra == "cask" and queuedActions[1].canAddItem(queuedActions[1]))
halos, queuedActions = {}, {}
local shelfSlot, shelf = station("shelf", 5)
ISCraftLogicPanel.ItemSlotAddItems("player", shelf, shelfSlot, { "wrong" }, shelf.component)
check("slotRules: the other mod's station gets its own rules", #queuedActions == 0 and halos[1] == getText("T_NotShelf"))
local otherSlot, other = station("barrel", 5)
ISCraftLogicPanel.ItemSlotAddItems("player", other, otherSlot, { "a" }, {})
check("slotRules: anything else goes to vanilla", vanillaAdds == 1)
local itemSlot, craftedItem = station("cask", 2)
craftedItem.isItem = true
ISCraftLogicPanel.ItemSlotAddItems("player", craftedItem, itemSlot, { "a" }, {})
check("slotRules: an item that crafts is never asked for a sprite", vanillaAdds == 2 and #queuedActions == 0)
check("slotRules: green border follows the refusal", ISItemSlot.defaultVerifyItem({}, caskSlot, "a") and not ISItemSlot.defaultVerifyItem({}, caskSlot, "wrong"))
local outSlot = station("cask", 2)
outSlot.resource.getIO = function() return ResourceIO.Output end
check("slotRules: output slots are left alone", ISItemSlot.defaultVerifyItem({}, outSlot, "wrong"))
halos = {}
ISMouseDrag.dragging = { "wrong" }
ISItemSlot.onMouseUp(caskSlot, 0, 0)
check("slotRules: a refused drop says why, and vanilla still runs", halos[1] == getText("T_NotCask") and vanillaUps == 1)
halos = {}
ISMouseDrag.dragging = { "wrong", "a" }
ISItemSlot.onMouseUp(caskSlot, 0, 0)
check("slotRules: a drag that can partly go in says nothing", #halos == 0 and vanillaUps == 2)
ISMouseDrag.dragging = nil

-- recipeRefusal: what the selected recipe can't take. The station's CraftLogic says which recipe, by its full name.
local vanillaStarts = 0
ISWidgetCraftLogicControl = { startCraft = function() vanillaStarts = vanillaStarts + 1 end }
ComponentType = { Resources = "resources" }
ResourceType = { Item = "item" }
ArrayList = { new = function() return H.list({}) end }
UI.slotRules{
    station = function(entity) if entity and entity.name == "tub" then return entity.component, "tub" end end,
    refusal = function() return nil end,
    recipeRefusal = function(s, item) if s.recipe == "Short" and item == "leg" then return "T_TooThick" end end,
}
local tubSlot, tub = station("tub", 5)
local function select(name)
    tub.component.getCurrentRecipe = function() return name and { getName = function() return "Mod." .. name end } end
end
select("Short")
check("recipeRefusal: the selected recipe turns the border red, by its short name", not ISItemSlot.defaultVerifyItem({}, tubSlot, "leg")
    and ISItemSlot.defaultVerifyItem({}, tubSlot, "cut"))
select("Long")
check("recipeRefusal: another recipe takes it", ISItemSlot.defaultVerifyItem({}, tubSlot, "leg"))
select(nil)
check("recipeRefusal: no recipe, no recipe rule", ISItemSlot.defaultVerifyItem({}, tubSlot, "leg"))
halos = {}
select("Short")
ISMouseDrag.dragging = { "leg" }
ISItemSlot.onMouseUp(tubSlot, 0, 0)
check("recipeRefusal: a refused drop says why", halos[1] == getText("T_TooThick"))
ISMouseDrag.dragging = nil
local stored = { "cut" }
local inputSlot = { getStoredItems = function() return H.list(stored) end }
tub.getComponent = function(_, kind)
    return kind == ComponentType.Resources and { getResourcesFromGroup = function() return H.list({ inputSlot }) end } or nil
end
local logic = { getCraftLogic = function() return { getInputsGroupName = function() return "inputs" end } end }
halos = {}
ISWidgetCraftLogicControl.startCraft({ entity = tub, player = "player", logic = logic })
check("recipeRefusal: Craft starts when every stored input fits", vanillaStarts == 1)
stored = { "cut", "leg" }
ISWidgetCraftLogicControl.startCraft({ entity = tub, player = "player", logic = logic })
check("recipeRefusal: loaded under one recipe, Craft under another says why", vanillaStarts == 1 and halos[1] == getText("T_TooThick"))
select("Long")
ISWidgetCraftLogicControl.startCraft({ entity = tub, player = "player", logic = logic })
ISWidgetCraftLogicControl.startCraft({ entity = cask, player = "player", logic = logic })
check("recipeRefusal: other recipes and stations start as vanilla", vanillaStarts == 3)

-- Yeast, Fish and Vinegar were checked here against their old code when each moved onto the core (2026-11-09).
-- Their golden outputs and their own tests keep them in step now.

H.done()
