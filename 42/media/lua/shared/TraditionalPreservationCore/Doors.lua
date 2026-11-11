-- Traditional Preservation core: a station's door or fire mouth needs its front tile free. The Hearth's mouth, the
-- Firebox's door and mods' doors (Fish & Meat's Smokehouse) register their tiles with the way they open; none of them
-- is built or put down with something in front of its door, nor on a tile in front of another one's door. The build
-- menu asks TraditionalPreservationCore.doorFits (an entity's OnIsValid); putting a moveable down asks the same
-- through UI.keepDoorsFree. Vanilla's own furniture isn't checked.
local Doors = {}

-- The step to the tile in front, by facing (+x east, +y south), and the wall that would shut that tile off from the
-- door: walls sit on a square's north and west edges, so it is the front square's own.
Doors.FRONT = { S = { 0, 1 }, E = { 1, 0 }, N = { 0, -1 }, W = { -1, 0 } }
local FRONT_WALLS = { S = { "collideN", "WallN", "WallNW" }, E = { "collideW", "WallW", "WallNW" } }

local FACINGS = {}

-- names = { spriteName = "S" | "E" | ... }: these tiles open that way.
function Doors.register(names)
    for name, facing in pairs(names) do FACINGS[name] = facing end
end

function Doors.facingOf(spriteName)
    return spriteName and FACINGS[spriteName]
end

local function squareAt(square, step, sign)
    return getCell():getGridSquare(square:getX() + step[1] * sign, square:getY() + step[2] * sign, square:getZ())
end

-- What on a square would block a door, or nil: a wall on the edge facing the door ("wall collideN"), or a solid or
-- placement-blocking object (its sprite name and the property).
function Doors.blocker(front, facing)
    local properties = front:getProperties()
    for _, flag in ipairs(FRONT_WALLS[facing] or {}) do
        if properties:has(IsoFlagType[flag]) then return "wall " .. flag end
    end
    local objects = front:getObjects()
    for i = 0, objects:size() - 1 do
        local sprite = objects:get(i):getSprite()
        local props = sprite and sprite:getProperties()
        if props then
            if props:has("BlocksPlacement") then return sprite:getName() .. " BlocksPlacement" end
            if props:has(IsoFlagType.solid) then return sprite:getName() .. " solid" end
            if props:has(IsoFlagType.solidtrans) then return sprite:getName() .. " solidtrans" end
        end
    end
    return nil
end

local function blocked(front, facing)
    return Doors.blocker(front, facing) ~= nil
end

-- The tile in front of a door opening that way from square is free (no square there is open ground).
function Doors.frontFree(square, facing)
    local step = Doors.FRONT[facing]
    if not step then return true end
    local front = squareAt(square, step, 1)
    return not front or not blocked(front, facing)
end

-- The sprite name of a registered door on a neighbouring tile that opens onto square, or nil.
function Doors.doorOnto(square)
    for facing, step in pairs(Doors.FRONT) do
        local behind = squareAt(square, step, -1)
        local objects = behind and behind:getObjects()
        for i = 0, objects and objects:size() - 1 or -1 do
            local sprite = objects:get(i):getSprite()
            if sprite and FACINGS[sprite:getName()] == facing then return sprite:getName() end
        end
    end
    return nil
end

function Doors.facesInto(square)
    return Doors.doorOnto(square) ~= nil
end

-- Whether this tile (by its sprite name) may stand on square: its own door's front free, and not in front of
-- another door. Any tile, registered or not, is kept out of a door's front by the second test.
function Doors.fits(square, spriteName)
    if not square then return true end
    local facing = Doors.facingOf(spriteName)
    if facing and not Doors.frontFree(square, facing) then return false end
    return not Doors.facesInto(square)
end

TraditionalPreservationCore = TraditionalPreservationCore or {}

-- An entity's SpriteConfig OnIsValid: the build ghost's tile on params.square.
function TraditionalPreservationCore.doorFits(params)
    local name = params.tileInfo and params.tileInfo:getSpriteName()
    return Doors.fits(params.square, name)
end

return Doors
