-- Traditional Preservation core: whether a room lets air in, for Weather's aired room. A window open, smashed or
-- without its glass, or an empty frame, and not barricaded, on any wall between the room and the outside air, on the
-- room's own level. A room is a map room (its squares share a room id) or one a player built (its squares share a
-- world region, IsoWorldRegion:isPlayerRoom): found by walking from the station's square through squares of the same
-- room. Read square by square because a map room's own list stays empty (42.22.2: IsoRoom:getWindows() is never
-- filled, IsoRoom.windows is only cleared). A room's answer is kept for a reading (ten minutes): a window opened counts
-- from the next one.
local Windows = {}

Windows.MAX_SQUARES = 400        -- a room bigger than this is read that far from the station (a warehouse floor)
local NO_ROOM_ID = -1            -- getRoomID on a square in no map room
local READING_HOURS = 1 / 6      -- how long a room's answer is kept: the weather's ten-minute reading

local STEPS = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }

-- Which room a square is in: the map room's id, else the player-built room's region, else nil.
function Windows.roomKey(square)
    local id = square:getRoomID()
    if id and id ~= NO_ROOM_ID then return "room" .. tostring(id) end
    local region = square:getIsoWorldRegion()
    if region and region:isPlayerRoom() then return "region" .. tostring(region:getID()) end
    return nil
end

-- Whether one window, frame or built window lets air through.
local function letsAirIn(isoObject)
    if instanceof(isoObject, "IsoWindow") then
        return not isoObject:isBarricaded() and (isoObject:IsOpen() or isoObject:isSmashed() or isoObject:isGlassRemoved())
    elseif instanceof(isoObject, "IsoWindowFrame") then
        -- A frame with a window in it: the window says.
        return not isoObject:hasWindow() and not isoObject:isBarricaded()
    elseif instanceof(isoObject, "IsoThumpable") and isoObject:isWindow() then
        return not isoObject:isBarricaded() and isoObject:IsOpen()
    end
    return false
end

-- Whether an object stands on a square's north edge (north) or its west edge.
local function onEdge(isoObject, north)
    if instanceof(isoObject, "IsoThumpable") then
        if north then return isoObject:isWindowN() end
        return isoObject:isWindowW()
    end
    return isoObject:isNorth() == north
end

-- Whether the wall between square and the neighbour a step away lets air in. Walls stand on a square's north and
-- west edges: the north and west walls are square's own, the south and east ones its neighbour's.
local function edgeAired(square, neighbour, step)
    local owner, north = square, step[2] ~= 0
    if step[1] == 1 or step[2] == 1 then owner = neighbour end
    if not owner then return false end
    local objects = owner:getObjects()
    for index = 0, objects:size() - 1 do
        local isoObject = objects:get(index)
        if onEdge(isoObject, north) and letsAirIn(isoObject) then return true end
    end
    return false
end

-- Whether the room square is in has a window to the outside air letting air in. Squares out of the loaded world are
-- outside air; a window to another room is not.
local function at(x, y) return x .. "," .. y end

local function scan(square, key)
    local cell = getCell()
    local seen, queue, head = { [at(square:getX(), square:getY())] = true }, { square }, 1
    while queue[head] and head <= Windows.MAX_SQUARES do
        local current = queue[head]
        head = head + 1
        local x, y, z = current:getX(), current:getY(), current:getZ()
        for _, step in ipairs(STEPS) do
            local neighbour = cell:getGridSquare(x + step[1], y + step[2], z)
            if neighbour and Windows.roomKey(neighbour) == key then
                local where = at(x + step[1], y + step[2])
                if not seen[where] then
                    seen[where] = true
                    table.insert(queue, neighbour)
                end
            elseif not (neighbour and neighbour:isInARoom()) and edgeAired(current, neighbour, step) then
                return true
            end
        end
    end
    return false
end

-- Each room's answer this reading; a new reading starts them all over, so only the rooms looked at lately are kept.
local answers, answersReading = {}, nil

-- Whether square's room lets air in. A square in no room: false.
function Windows.aired(square)
    local key = Windows.roomKey(square)
    if not key then return false end
    local reading = math.floor(getGameTime():getWorldAgeHours() / READING_HOURS)
    if reading ~= answersReading then answers, answersReading = {}, reading end
    if answers[key] == nil then answers[key] = scan(square, key) end
    return answers[key]
end

-- For tests: forget every room's answer.
function Windows.forget()
    answers, answersReading = {}, nil
end

-- For tests: how many rooms have an answer kept.
function Windows.keptCount()
    local count = 0
    for _ in pairs(answers) do count = count + 1 end
    return count
end

return Windows
