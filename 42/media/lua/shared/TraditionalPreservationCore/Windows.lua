-- Traditional Preservation core: whether a room lets air in, for Weather's aired room. A window open, smashed or
-- without its glass, or an empty frame, and not barricaded, on any wall between the room and the outside air, on the
-- room's own level. A room is a map room (its squares share a room id) or one a player built (its squares share a
-- world region, IsoWorldRegion:isPlayerRoom): found by walking from the station's square through squares of the same
-- room. Read square by square because a map room's own list stays empty (42.22.2: IsoRoom:getWindows() is never
-- filled, IsoRoom.windows is only cleared). Each outside wall is asked through the game's own lookups (getWindowTo,
-- getWindowFrameTo, getWindowThumpableTo: one call each, either side of the wall), so nothing else on the square is
-- touched. A room's answer is kept for a reading (ten minutes): a window opened counts from the next one.
local Windows = {}

Windows.MAX_SQUARES = 150        -- a room bigger than this is read that far from the station (a hall, a warehouse)
local NO_ROOM_ID = -1            -- getRoomID on a square in no map room
local READING_HOURS = 1 / 6      -- how long a room's answer is kept: the weather's ten-minute reading
-- The frame budget: at most one scan in this many real milliseconds. A room due for a new answer inside it keeps its
-- last one (or reads shut) until the next look, so many rooms never scan in the same frame.
Windows.SCAN_GAP_MS = 20

local STEPS = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }

-- Engine calls made by the scans, for TPC.windows().
local calls = 0

-- Which room a square is in: the map room's id, else the player-built room's region, else nil.
function Windows.roomKey(square)
    calls = calls + 1
    local id = square:getRoomID()
    if id and id ~= NO_ROOM_ID then return "room" .. tostring(id) end
    calls = calls + 1
    local region = square:getIsoWorldRegion()
    if not region then return nil end
    calls = calls + 1
    if not region:isPlayerRoom() then return nil end
    calls = calls + 1
    return "region" .. tostring(region:getID())
end

-- Whether one window, frame or built window lets air through.
local function letsAirIn(isoObject)
    if instanceof(isoObject, "IsoWindow") then
        calls = calls + 4
        return not isoObject:isBarricaded() and (isoObject:IsOpen() or isoObject:isSmashed() or isoObject:isGlassRemoved())
    elseif instanceof(isoObject, "IsoWindowFrame") then
        -- A frame with a window in it: the window says.
        calls = calls + 2
        return not isoObject:hasWindow() and not isoObject:isBarricaded()
    elseif instanceof(isoObject, "IsoThumpable") then
        calls = calls + 2
        return not isoObject:isBarricaded() and isoObject:IsOpen()
    end
    return false
end

-- Whether the wall between square and its neighbour lets air in: a window there, else an empty frame, else a built
-- window. A neighbour out of the loaded world is read as a wall with no window.
local function edgeAired(square, neighbour)
    if not neighbour then return false end
    calls = calls + 1
    local window = square:getWindowTo(neighbour)
    if window then return letsAirIn(window) end
    calls = calls + 1
    local frame = square:getWindowFrameTo(neighbour)
    if frame and letsAirIn(frame) then return true end
    calls = calls + 1
    local built = square:getWindowThumpableTo(neighbour)
    return built ~= nil and letsAirIn(built)
end

local function at(x, y) return x .. "," .. y end

-- Whether the room square is in (its key) has a window to the outside air letting air in, then how many squares and
-- outside walls it read. A window to another room is not to the outside. Each square carries its coordinates, so
-- only the station's own square is asked for them.
local function scan(square, key)
    local cell = getCell()
    calls = calls + 4
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local seen, queue, head, walls = { [at(x, y)] = true }, { { square, x, y } }, 1, 0
    while queue[head] and head <= Windows.MAX_SQUARES do
        local current = queue[head]
        head = head + 1
        for _, step in ipairs(STEPS) do
            local nextX, nextY = current[2] + step[1], current[3] + step[2]
            calls = calls + 1
            local neighbour = cell:getGridSquare(nextX, nextY, z)
            if neighbour and Windows.roomKey(neighbour) == key then
                local where = at(nextX, nextY)
                if not seen[where] then
                    seen[where] = true
                    table.insert(queue, { neighbour, nextX, nextY })
                end
            else
                if neighbour then calls = calls + 1 end
                if not (neighbour and neighbour:isInARoom()) then
                    walls = walls + 1
                    if edgeAired(current[1], neighbour) then return true, head - 1, walls end
                end
            end
        end
    end
    return false, head - 1, walls
end

-- Each room's answer this reading, and the reading before's (kept for a room the frame budget makes wait); a new
-- reading moves them on, so only the rooms looked at lately are kept.
local answers, previous, answersReading = {}, {}, nil
local lastScanMs

-- Whether the frame budget allows a scan now (no clock, as in tests: always).
local function mayScan()
    if not getTimestampMs then return true end
    local now = getTimestampMs()
    if lastScanMs and now - lastScanMs < Windows.SCAN_GAP_MS then return false end
    lastScanMs = now
    return true
end

-- Whether square's room lets air in. A square in no room: false.
function Windows.aired(square)
    local key = Windows.roomKey(square)
    if not key then return false end
    local reading = math.floor(getGameTime():getWorldAgeHours() / READING_HOURS)
    if reading ~= answersReading then answers, previous, answersReading = {}, answers, reading end
    if answers[key] == nil then
        if not mayScan() then return previous[key] == true end
        answers[key] = scan(square, key)
    end
    return answers[key]
end

-- For TPC.windows(): one fresh scan of square's room, not kept. nil for a square in no room, else
-- { aired, squares (read), walls (outside walls asked), calls (engine calls, about) }.
function Windows.measure(square)
    calls = 0
    local key = Windows.roomKey(square)
    if not key then return nil end
    local aired, squares, walls = scan(square, key)
    return { aired = aired, squares = squares, walls = walls, calls = calls }
end

-- For tests: forget every room's answer.
function Windows.forget()
    answers, previous, answersReading, lastScanMs = {}, {}, nil, nil
end

-- For tests: how many rooms have an answer kept.
function Windows.keptCount()
    local count = 0
    for _ in pairs(answers) do count = count + 1 end
    return count
end

return Windows
