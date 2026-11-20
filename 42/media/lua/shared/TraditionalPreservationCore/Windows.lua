-- Traditional Preservation core: whether air from outside reaches a square in a room, for Weather's aired room. The
-- air comes in through a window open, smashed or without its glass, an empty frame, a door open or an empty doorway
-- (its door broken off), not barricaded, or a gap where a wall was knocked out; it reaches a square within AIR_STEPS
-- steps of it, walking through squares with nothing shut between them, room to room through open inside doors,
-- doorways and knocked-through walls, on the square's own level. A wall, a shut door or a shut window stops it. Read
-- edge by edge through the game's own lookups (getWindowTo, getWindowFrameTo, getWindowThumpableTo, getDoorTo,
-- isWallTo: one call each, either side of the wall), so nothing else on the square is touched; a step onto a square
-- in no room (isInARoom) is the outside air. A square's answer is kept for a reading (ten minutes): a window opened
-- counts from the next one.
local Windows = {}

Windows.AIR_STEPS = 6            -- the steps from the station's square out through an opening, at most
local READING_HOURS = 1 / 6      -- how long a square's answer is kept: the weather's ten-minute reading
-- The frame budget: at most one walk in this many real milliseconds. A square due for a new answer inside it keeps
-- its last one (or reads shut) until the next look, so many stations never walk in the same frame.
Windows.SCAN_GAP_MS = 20

local STEPS = { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }

-- Engine calls made by a walk, for TPC.windows().
local calls = 0

-- Whether one window, frame, built window or door lets air through.
local function letsAirIn(isoObject)
    if instanceof(isoObject, "IsoWindow") then
        calls = calls + 4
        return not isoObject:isBarricaded() and (isoObject:IsOpen() or isoObject:isSmashed() or isoObject:isGlassRemoved())
    elseif instanceof(isoObject, "IsoWindowFrame") then
        -- A frame with a window in it: the window says.
        calls = calls + 2
        return not isoObject:hasWindow() and not isoObject:isBarricaded()
    elseif instanceof(isoObject, "IsoThumpable") or instanceof(isoObject, "IsoDoor") then
        -- A built window or door, or a map door: open and not barricaded.
        calls = calls + 2
        return not isoObject:isBarricaded() and isoObject:IsOpen()
    end
    return false
end

-- Whether air passes the edge between square and its neighbour (a step away): a window there decides, else an empty
-- frame, else a built window, else a door; else an empty doorway (a door frame, the wall's DoorWallN or DoorWallW
-- flag on the square that owns the wall: walls stand on a square's north and west edges) lets it through, else a
-- wall stops it, else nothing stands between. A neighbour out of the loaded world stops it.
local function edgeOpen(square, neighbour, step)
    if not neighbour then return false end
    calls = calls + 1
    local window = square:getWindowTo(neighbour)
    if window then return letsAirIn(window) end
    calls = calls + 1
    local frame = square:getWindowFrameTo(neighbour)
    if frame then return letsAirIn(frame) end
    calls = calls + 1
    local built = square:getWindowThumpableTo(neighbour)
    if built then return letsAirIn(built) end
    calls = calls + 1
    local door = square:getDoorTo(neighbour)
    if door then return letsAirIn(door) end
    local owner = (step[1] == 1 or step[2] == 1) and neighbour or square
    calls = calls + 1
    if owner:has(step[2] ~= 0 and IsoFlagType.DoorWallN or IsoFlagType.DoorWallW) then return true end
    calls = calls + 1
    return not square:isWallTo(neighbour)
end

local function at(x, y) return x .. "," .. y end

-- Whether air reaches square from outside within AIR_STEPS steps, then how many indoor squares the walk read. Each
-- queued square carries its coordinates and its steps from square, so only square is asked for its own.
local function walk(square)
    local cell = getCell()
    calls = calls + 4
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local seen, queue, head = { [at(x, y)] = true }, { { square, x, y, 0 } }, 1
    while queue[head] do
        local current = queue[head]
        head = head + 1
        for _, step in ipairs(STEPS) do
            local nextX, nextY = current[2] + step[1], current[3] + step[2]
            local where = at(nextX, nextY)
            if not seen[where] then
                calls = calls + 1
                local neighbour = cell:getGridSquare(nextX, nextY, z)
                if edgeOpen(current[1], neighbour, step) then
                    calls = calls + 1
                    if not neighbour:isInARoom() then return true, head - 1 end
                    if current[4] + 1 < Windows.AIR_STEPS then
                        seen[where] = true
                        table.insert(queue, { neighbour, nextX, nextY, current[4] + 1 })
                    end
                end
            end
        end
    end
    return false, head - 1
end

-- Each square's answer this reading, and the reading before's (kept for a square the frame budget makes wait); a new
-- reading moves them on, so only the squares looked at lately are kept.
local answers, previous, answersReading = {}, {}, nil
local lastScanMs

-- Whether the frame budget allows a walk now (no clock, as in tests: always).
local function mayScan()
    if not getTimestampMs then return true end
    local now = getTimestampMs()
    if lastScanMs and now - lastScanMs < Windows.SCAN_GAP_MS then return false end
    lastScanMs = now
    return true
end

local function keyOf(square)
    return square:getX() .. "," .. square:getY() .. "," .. square:getZ()
end

local function thisReading()
    return math.floor(getGameTime():getWorldAgeHours() / READING_HOURS)
end

-- Whether air from outside reaches square. A square in no room: false.
function Windows.aired(square)
    if not square:isInARoom() then return false end
    local key = keyOf(square)
    local reading = thisReading()
    if reading ~= answersReading then answers, previous, answersReading = {}, answers, reading end
    if answers[key] == nil then
        if not mayScan() then return previous[key] == true end
        answers[key] = walk(square)
    end
    return answers[key]
end

-- For TPC.windows(): one fresh walk from square, kept as the square's answer for this reading (so TPC.here() and a
-- station there agree with it at once). nil for a square in no room, else { aired, squares (indoor squares read),
-- calls (engine calls, about) }.
function Windows.measure(square)
    calls = 0
    if not square:isInARoom() then return nil end
    local aired, squares = walk(square)
    if answersReading == thisReading() then answers[keyOf(square)] = aired end
    return { aired = aired, squares = squares, calls = calls }
end

-- For tests: forget every square's answer.
function Windows.forget()
    answers, previous, answersReading, lastScanMs = {}, {}, nil, nil
end

-- For tests: how many squares have an answer kept.
function Windows.keptCount()
    local count = 0
    for _ in pairs(answers) do count = count + 1 end
    return count
end

return Windows
