-- Traditional Preservation core: keeps a table of a mod's stations, found by the map loader or added when a
-- player uses one, and refreshes each every half second or so while it is loaded. SpriteOverlayConfig can
-- only show one sprite, so stations layer their own with attached sprites.
local Station = {}

Station.TICKS_PER_REFRESH = 30
Station.MAP_PRIORITY = 5
Station.SCAN_TICKS = 30
Station.SCAN_NEAR = 3

-- An unloaded station keeps its square and index until its chunk has been saved and reused, but the cell
-- stops returning that square as soon as the chunk unloads (ENGINE_NOTES, "Chunk unload and generators").
function Station.isLoaded(station)
    local square = station:getSquare()
    return square ~= nil and station:getObjectIndex() >= 0
        and getCell():getGridSquare(square:getX(), square:getY(), square:getZ()) == square
end

-- Which of a mod's stations an object is, by one table lookup on its sprite's name. Nothing is cut out of the
-- name and nothing allocated, which counts where every object round a player is asked (a tracker's scan).
--   prefix  the tileset's prefix (Tiles.PREFIX)
--   faces   tiles per station, one for each facing (Tiles.FACE_COUNT)
--   bases   each kind's first tile: { vessel = Tiles.VESSEL, cask = Tiles.CASK }
-- Returns kindOf(isoObject), giving the kind and the facing (from 0), or nil for anything else, and the lookup
-- itself: tiles.kind[spriteName] and tiles.face[spriteName].
function Station.kinds(prefix, faces, bases)
    local tiles = { kind = {}, face = {} }
    for kind, base in pairs(bases) do
        for face = 0, faces - 1 do
            tiles.kind[prefix .. (base + face)] = kind
            tiles.face[prefix .. (base + face)] = face
        end
    end
    local function kindOf(isoObject)
        local sprite = isoObject and isoObject:getSprite()
        local name = sprite and sprite:getName()
        if not name then return nil end
        return tiles.kind[name], tiles.face[name]
    end
    return kindOf, tiles
end

-- The square dx, dy from square on its level, or nil (not loaded).
function Station.squareAt(square, dx, dy)
    return getCell():getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
end

-- Calls fn(isoObject, dx, dy) for every object on the squares within radius tiles of x, y on level z: west to east,
-- then north to south, then by its place on the square.
local function eachObject(x, y, z, radius, fn)
    local cell = getCell()
    for dx = -radius, radius do
        for dy = -radius, radius do
            local there = cell:getGridSquare(x + dx, y + dy, z)
            local isoObjects = there and there:getObjects()
            for i = 0, isoObjects and isoObjects:size() - 1 or -1 do fn(isoObjects:get(i), dx, dy) end
        end
    end
end

-- Every player here: all of them on a server, the local ones otherwise. A Java list.
function Station.players()
    if isServer() then return getOnlinePlayers() end
    local players = ArrayList.new()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then players:add(player) end
    end
    return players
end

-- Calls fn(player) for every player here (Station.players).
function Station.eachPlayer(fn)
    local players = Station.players()
    for i = 0, players:size() - 1 do fn(players:get(i)) end
end

-- Every object within radius tiles of the square at x, y on level z that passes test, nearest first; of two as near,
-- the one the scan meets first (west to east, then north to south, then by its place on the square).
function Station.nearAt(x, y, z, radius, test)
    local found = {}
    eachObject(x, y, z, radius, function(isoObject, dx, dy)
        if test(isoObject) then table.insert(found, { isoObject = isoObject, distance = dx * dx + dy * dy, order = #found }) end
    end)
    table.sort(found, function(a, b)
        if a.distance ~= b.distance then return a.distance < b.distance end
        return a.order < b.order
    end)
    local nearest = {}
    for index, nearby in ipairs(found) do nearest[index] = nearby.isoObject end
    return nearest
end

-- The same round a square.
function Station.near(square, radius, test)
    if not square then return {} end
    return Station.nearAt(square:getX(), square:getY(), square:getZ(), radius, test)
end

-- Calls fn(container, isoObject) for every item container at heat or hotter (vanilla's container temperature: 1.0 is
-- cold, a lit stove or fire more) on any object within radius tiles of square on its level.
function Station.hotContainers(square, radius, heat, fn)
    if not square then return end
    eachObject(square:getX(), square:getY(), square:getZ(), radius, function(isoObject)
        for c = 0, isoObject:getContainerCount() - 1 do
            local container = isoObject:getContainerByIndex(c)
            if container:getTemperature() >= heat then fn(container, isoObject) end
        end
    end)
end

-- Things kept on the heat near a player (FluidAgeing's scalding, OnHeat's frying): one look a game minute over the
-- squares within HEAT_NEAR of each player, shared by everyone who asks, each told only of containers at its own
-- heat or hotter. Not on a client: the server (or a single player game) keeps the items.
Station.HEAT_NEAR = 8

local hotWatchers = {}
local hotStarted = false

-- The watchers with a heat now, and the lowest of those heats (nil when none has one).
local function readyWatchers()
    local ready, lowest = {}, nil
    for _, watcher in ipairs(hotWatchers) do
        local heat = watcher.heat
        if type(heat) == "function" then heat = heat() end
        if heat then
            table.insert(ready, { heat = heat, fn = watcher.fn })
            lowest = math.min(lowest or heat, heat)
        end
    end
    return ready, lowest
end

local function lookAtHeat()
    local ready, lowest = readyWatchers()
    if not lowest then return end
    local now = getGameTime():getWorldAgeHours()
    Station.eachPlayer(function(player)
        Station.hotContainers(player:getSquare(), Station.HEAT_NEAR, lowest, function(container, isoObject)
            local temperature = container:getTemperature()
            for _, watcher in ipairs(ready) do
                if temperature >= watcher.heat then watcher.fn(container, now, isoObject) end
            end
        end)
    end)
end

-- Calls fn(container, now, isoObject) every game minute for each container at heat or hotter near a player (isoObject: the
-- stove, fire or whatever holds it). heat is a vanilla
-- container temperature, or a function giving one (nil: nothing to look for this minute).
function Station.onHeatNear(heat, fn)
    assert(type(heat) == "number" or type(heat) == "function", "Station.onHeatNear: heat must be a number or a function")
    assert(type(fn) == "function", "Station.onHeatNear: fn must be a function")
    table.insert(hotWatchers, { heat = heat, fn = fn })
    -- Outside the game (tests) there may be no clock to hang it on.
    if hotStarted or not Events or (isClient and isClient()) then return end
    hotStarted = true
    Events.EveryOneMinute.Add(lookAtHeat)
end

-- A station just built or put down isn't known to the map loader. For the trackers that ask (options.scan), the
-- squares round each player are looked over twice a second, once for all of them, so a new one shows at once.
local scanning = {}
local scanTicks = 0

local function foundByAll(isoObject)
    for _, tracker in ipairs(scanning) do tracker.found(isoObject) end
end

local function scanNear(player)
    eachObject(math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()), Station.SCAN_NEAR, foundByAll)
end

local function onScanTick()
    scanTicks = scanTicks + 1
    if scanTicks < Station.SCAN_TICKS then return end
    scanTicks = 0
    local players = Station.players()
    for i = 0, players:size() - 1 do scanNear(players:get(i)) end
end

-- options:
--   sprites          sprite names the map loader reports
--   newSessionState  function(isoObject): a new station's session state (a table kept while it is loaded, never
--                    saved), or nil to leave the object alone. Default {}.
--   refresh          function(station, sessionState), for each loaded station
--   ticks            ticks between refreshes (default TICKS_PER_REFRESH)
--   dropped          function(station, sessionState), optional: a station's area unloaded or it is gone; it won't
--                    be refreshed again
--   scan             true to find stations built or put down this session as soon as a player is near (see above).
--                    newSessionState must then turn down every object that isn't the mod's, and cheaply
--                    (Station.kinds).
function Station.tracker(options)
    assert(type(options.sprites) == "table", "Station.tracker: sprites (a list of sprite names) needed")
    assert(type(options.refresh) == "function", "Station.tracker: refresh (a function) needed")
    local tracker = { tracked = {} }
    local ticks = options.ticks or Station.TICKS_PER_REFRESH
    local ticksSinceRefresh = 0

    -- The station's session state, made the first time. Nil if options.newSessionState turned the object down.
    function tracker.track(isoObject)
        local sessionState = tracker.tracked[isoObject]
        if sessionState then return sessionState end
        if options.newSessionState then
            sessionState = options.newSessionState(isoObject)
        else
            sessionState = {}
        end
        tracker.tracked[isoObject] = sessionState
        return sessionState
    end

    -- The station's session state, or nil if it isn't tracked. Never makes one.
    function tracker.sessionStateOf(station)
        return tracker.tracked[station]
    end

    -- For a station picked up or destroyed, so it isn't refreshed again.
    function tracker.forget(station)
        tracker.tracked[station] = nil
    end

    -- A refresh may track another station, so this goes through a list made first.
    function tracker.refreshAll()
        local stations = {}
        for station in pairs(tracker.tracked) do table.insert(stations, station) end
        for _, station in ipairs(stations) do
            if not Station.isLoaded(station) then
                if options.dropped then options.dropped(station, tracker.tracked[station]) end
                tracker.tracked[station] = nil
            elseif tracker.tracked[station] then
                options.refresh(station, tracker.tracked[station])
            end
        end
    end

    -- Refreshes every station once each `ticks` ticks.
    function tracker.onTick()
        ticksSinceRefresh = ticksSinceRefresh + 1
        if ticksSinceRefresh < ticks then return end
        ticksSinceRefresh = 0
        tracker.refreshAll()
    end

    -- Tracks and refreshes isoObject now if it is a station not seen before.
    function tracker.found(isoObject)
        if tracker.tracked[isoObject] then return end
        local sessionState = tracker.track(isoObject)
        if sessionState then options.refresh(isoObject, sessionState) end
    end

    -- Call once at load: starts the tick loop and asks the map loader for the stations.
    function tracker.start()
        Events.OnTick.Add(tracker.onTick)
        if options.scan then
            if #scanning == 0 then Events.OnTick.Add(onScanTick) end
            table.insert(scanning, tracker)
        end
        for _, name in ipairs(options.sprites) do
            MapObjects.OnLoadWithSprite(name, tracker.track, Station.MAP_PRIORITY)
        end
    end

    return tracker
end

-- The station's CraftLogicUILogic, which lists its running batches, kept in its session state. Its constructor
-- reads the player's mod data, so it needs a real player: nil until there is one.
function Station.uiLogic(station, sessionState, logic)
    if not sessionState.uiLogic or sessionState.uiLogic:getCraftLogic() ~= logic then
        local player = getPlayer()
        if not player then return nil end
        sessionState.uiLogic = CraftLogicUILogic.new(player, station, logic)
    end
    return sessionState.uiLogic
end

-- The item slots of one resource group, input or output, as a Java list.
function Station.itemSlots(resources, group, io)
    return resources:getResourcesFromGroup(group, ArrayList.new(), io, ResourceType.Item)
end

-- How many items the group's slots hold.
function Station.countItems(resources, group, io)
    local count = 0
    local slots = Station.itemSlots(resources, group, io)
    for i = 0, slots:size() - 1 do
        count = count + slots:get(i):storedSize()
    end
    return count
end

-- Shows these sprites on the station, in order, unless signature says nothing has changed since last time.
function Station.showSprites(station, sessionState, signature, names)
    if signature == sessionState.signature then return end
    sessionState.signature = signature
    station:clearAttachedAnimSprite()
    for _, name in ipairs(names) do
        station:addAttachedAnimSpriteByName(name)
    end
end

-- State kept in movableData goes onto the item when vanilla picks a station up, and back when it is placed.
function Station.movableData(station)
    local modData = station:getModData()
    modData.movableData = modData.movableData or {}
    return modData.movableData
end

return Station
