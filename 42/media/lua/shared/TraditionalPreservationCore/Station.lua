-- Traditional Preservation core: keeps a table of a mod's stations, found by the map loader or added when a
-- player uses one, and refreshes each every half second or so while it is loaded. SpriteOverlayConfig can
-- only show one sprite, so stations layer their own with attached sprites.
local Station = {}

Station.TICKS_PER_REFRESH = 30
Station.MAP_PRIORITY = 5
Station.SCAN_TICKS = 30
Station.SCAN_NEAR = 3

-- An unloaded object keeps its square and index until its chunk has been saved and reused, but the cell
-- stops returning that square as soon as the chunk unloads (ENGINE_NOTES, "Chunk unload and generators").
function Station.isLoaded(object)
    local square = object:getSquare()
    return square ~= nil and object:getObjectIndex() >= 0
        and getCell():getGridSquare(square:getX(), square:getY(), square:getZ()) == square
end

-- Which of a mod's stations an object is, by one table lookup on its sprite's name. Nothing is cut out of the
-- name and nothing allocated, which counts where every object round a player is asked (a tracker's scan).
--   prefix  the tileset's prefix (Tiles.PREFIX)
--   faces   tiles per station, one for each facing (Tiles.FACE_COUNT)
--   bases   each kind's first tile: { vessel = Tiles.VESSEL, cask = Tiles.CASK }
-- Returns kindOf(object), giving the kind and the facing (from 0), or nil for anything else, and the lookup
-- itself: tiles.kind[spriteName] and tiles.face[spriteName].
function Station.kinds(prefix, faces, bases)
    local tiles = { kind = {}, face = {} }
    for kind, base in pairs(bases) do
        for face = 0, faces - 1 do
            tiles.kind[prefix .. (base + face)] = kind
            tiles.face[prefix .. (base + face)] = face
        end
    end
    local function kindOf(object)
        local sprite = object and object:getSprite()
        local name = sprite and sprite:getName()
        if not name then return nil end
        return tiles.kind[name], tiles.face[name]
    end
    return kindOf, tiles
end

-- Every player here: all of them on a server, the local ones otherwise. A Java list.
function Station.players()
    if isServer() then return getOnlinePlayers() end
    local list = ArrayList.new()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then list:add(player) end
    end
    return list
end

-- Calls fn(container, object) for every item container at heat or hotter (vanilla's container temperature: 1.0 is
-- cold, a lit stove or fire more) on any object within radius tiles of square on its level.
function Station.hotContainers(square, radius, heat, fn)
    if not square then return end
    local cell = getCell()
    for dx = -radius, radius do
        for dy = -radius, radius do
            local there = cell:getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
            local objects = there and there:getObjects()
            for i = 0, objects and objects:size() - 1 or -1 do
                local object = objects:get(i)
                for c = 0, object:getContainerCount() - 1 do
                    local container = object:getContainerByIndex(c)
                    if container:getTemperature() >= heat then fn(container, object) end
                end
            end
        end
    end
end

-- A station just built or put down isn't known to the map loader. For the trackers that ask (options.scan), the
-- squares round each player are looked over twice a second, once for all of them, so a new one shows at once.
local scanning = {}
local scanTicks = 0

local function scanNear(player)
    local cell, px, py, z = getCell(), math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    for x = px - Station.SCAN_NEAR, px + Station.SCAN_NEAR do
        for y = py - Station.SCAN_NEAR, py + Station.SCAN_NEAR do
            local square = cell:getGridSquare(x, y, z)
            local objects = square and square:getObjects()
            for i = 0, objects and objects:size() - 1 or -1 do
                local object = objects:get(i)
                for _, tracker in ipairs(scanning) do tracker.found(object) end
            end
        end
    end
end

local function onScanTick()
    scanTicks = scanTicks + 1
    if scanTicks < Station.SCAN_TICKS then return end
    scanTicks = 0
    local list = Station.players()
    for i = 0, list:size() - 1 do scanNear(list:get(i)) end
end

-- options:
--   sprites  sprite names the map loader reports
--   entry    function(object): a new station's entry table, or nil to leave the object alone. Default {}.
--   refresh  function(object, entry), for each loaded station
--   ticks    ticks between refreshes (default TICKS_PER_REFRESH)
--   dropped  function(object, entry), optional: a station's area unloaded or it is gone; it won't be refreshed again
--   scan     true to find stations built or put down this session as soon as a player is near (see above).
--            entry must then turn down every object that isn't the mod's, and cheaply (Station.kinds).
function Station.tracker(options)
    local tracker = { tracked = {} }
    local ticks = options.ticks or Station.TICKS_PER_REFRESH
    local ticksSinceRefresh = 0

    -- The station's entry, made the first time. Nil if options.entry turned it down.
    function tracker.track(object)
        local entry = tracker.tracked[object]
        if entry then return entry end
        if options.entry then
            entry = options.entry(object)
        else
            entry = {}
        end
        tracker.tracked[object] = entry
        return entry
    end

    -- The station's entry, or nil if it isn't tracked. Never makes one.
    function tracker.entry(object)
        return tracker.tracked[object]
    end

    -- For a station picked up or destroyed, so it isn't refreshed again.
    function tracker.forget(object)
        tracker.tracked[object] = nil
    end

    -- A refresh may track another station, so this goes through a list made first.
    function tracker.refreshAll()
        local objects = {}
        for object in pairs(tracker.tracked) do table.insert(objects, object) end
        for _, object in ipairs(objects) do
            if not Station.isLoaded(object) then
                if options.dropped then options.dropped(object, tracker.tracked[object]) end
                tracker.tracked[object] = nil
            elseif tracker.tracked[object] then
                options.refresh(object, tracker.tracked[object])
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

    -- Tracks and refreshes object now if it is a station not seen before.
    function tracker.found(object)
        if tracker.tracked[object] then return end
        local entry = tracker.track(object)
        if entry then options.refresh(object, entry) end
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

-- The station's CraftLogicUILogic, which lists its running batches. Its constructor reads the player's mod
-- data, so it needs a real player: nil until there is one.
function Station.uiLogic(object, entry, logic)
    if not entry.uiLogic or entry.uiLogic:getCraftLogic() ~= logic then
        local player = getPlayer()
        if not player then return nil end
        entry.uiLogic = CraftLogicUILogic.new(player, object, logic)
    end
    return entry.uiLogic
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
function Station.showSprites(object, entry, signature, names)
    if signature == entry.signature then return end
    entry.signature = signature
    object:clearAttachedAnimSprite()
    for _, name in ipairs(names) do
        object:addAttachedAnimSpriteByName(name)
    end
end

-- State kept in movableData goes onto the item when vanilla picks a station up, and back when it is placed.
function Station.movableData(object)
    local modData = object:getModData()
    modData.movableData = modData.movableData or {}
    return modData.movableData
end

return Station
