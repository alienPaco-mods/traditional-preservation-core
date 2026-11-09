-- Traditional Preservation core: keeps a table of a mod's stations, found by the map loader or added when a
-- player uses one, and refreshes each every half second or so while it is loaded. SpriteOverlayConfig can
-- only show one sprite, so stations layer their own with attached sprites.
local Station = {}

Station.TICKS_PER_REFRESH = 30
Station.MAP_PRIORITY = 5

-- An unloaded object keeps its square and index until its chunk has been saved and reused, but the cell
-- stops returning that square as soon as the chunk unloads (ENGINE_NOTES, "Chunk unload and generators").
function Station.isLoaded(object)
    local square = object:getSquare()
    return square ~= nil and object:getObjectIndex() >= 0
        and getCell():getGridSquare(square:getX(), square:getY(), square:getZ()) == square
end

-- options:
--   sprites  sprite names the map loader reports
--   entry    function(object): a new station's entry table, or nil to leave the object alone. Default {}.
--   refresh  function(object, entry), for each loaded station
--   ticks    ticks between refreshes (default TICKS_PER_REFRESH)
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

    function tracker.entry(object)
        return tracker.tracked[object]
    end

    function tracker.forget(object)
        tracker.tracked[object] = nil
    end

    -- A refresh may track another station, so this goes through a list made first.
    function tracker.refreshAll()
        local objects = {}
        for object in pairs(tracker.tracked) do table.insert(objects, object) end
        for _, object in ipairs(objects) do
            if not Station.isLoaded(object) then
                tracker.tracked[object] = nil
            elseif tracker.tracked[object] then
                options.refresh(object, tracker.tracked[object])
            end
        end
    end

    function tracker.onTick()
        ticksSinceRefresh = ticksSinceRefresh + 1
        if ticksSinceRefresh < ticks then return end
        ticksSinceRefresh = 0
        tracker.refreshAll()
    end

    function tracker.start()
        Events.OnTick.Add(tracker.onTick)
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
