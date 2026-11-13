-- Traditional Preservation core: the Smokehouse (moved from Fish & Meat 2026-11-13, so Dairy and later mods share it).
-- A plank chamber two tiles long; Connect the Firebox lays a clay pipe (2 Clay Pipe Segments + 1 Clay, a mason's
-- trowel) or a trench roofed with flat stones (3 Flat Stones + 2 Clay, a shovel or spade) from a Firebox to a chamber
-- tile beside it; Disconnect takes it up again, the pipe or stones back, the clay lost. The link lives on the Firebox
-- alone (Hearth's flue and flueSide): the chamber tile it joins is the square on that side. Each chamber tile is
-- checked on its own, so a bigger shed can reuse the rules.
-- What hangs inside is each mod's: a stack records its owner when it starts (startCounters), and a mod steps only
-- its own stacks. The core counts the joined fire for them: hot, the hours of the stoked session now running
-- (Hearth.logFire), and cold, banked hours and the hours of stoked sessions that broke off (fireStep).
local Hearth = require "TraditionalPreservationCore/Hearth"
local Doors = require "TraditionalPreservationCore/Doors"
local Tiles = require "TraditionalPreservationCore/Tiles"

local Smokehouse = {}

Smokehouse.CONNECT_TICKS = 400
Smokehouse.DISCONNECT_TICKS = 200
Smokehouse.CONNECT_XP = 5

-- The recipe tag the chamber lists; a mod's smoking recipes carry it.
Smokehouse.RECIPES = "Smokehouse"
Smokehouse.STACKS = Tiles.CHAMBER_STACKS

-- The two ways to join them, in menu order. Items are { full type, count }; the tool (an ItemTag's name) stays.
Smokehouse.FLUE_KINDS = { "Pipe", "Stones" }
Smokehouse.FLUE_KITS = {
    Pipe = { tool = "MASONS_TROWEL", items = { { "Base.ClayPipeSegment", 2 }, { "Base.Clay", 1 } }, back = "Base.ClayPipeSegment" },
    Stones = { tool = "DIG_GRAVE", items = { { "Base.FlatStone", 3 }, { "Base.Clay", 2 } }, back = "Base.FlatStone" },
}

local FACES = #Tiles.CHAMBERS / 2
-- World steps (+x east, +y south) by facing (0 S, 1 E): towards the door's end, and to the long side the camera sees.
local DOOR_STEP = { [0] = { 0, 1 }, [1] = { 1, 0 } }
local VISIBLE_STEP = { [0] = { 1, 0 }, [1] = { 0, 1 } }
local SIDES = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- Each chamber sprite's facing and part, by name: CHAMBERS lists back then door tile, face S then E.
local TILE_OF = {}
for n, name in ipairs(Tiles.CHAMBERS) do TILE_OF[name] = { math.floor((n - 1) / 2), (n - 1) % 2 } end

-- The door's tile of each facing needs its front free, as the Firebox's door does (Doors).
do
    local doors = {}
    for face = 0, FACES - 1 do doors[Tiles.CHAMBERS[face * 2 + 2]] = face == 0 and "S" or "E" end
    Doors.register(doors)
end

-- A chamber tile's facing (0 S, 1 E) and part (0 the back tile, 1 the door's), from its sprite's name, or nil.
function Smokehouse.tileOfName(name)
    local found = name and TILE_OF[name]
    if found then return found[1], found[2] end
end

function Smokehouse.tileOf(object)
    local sprite = object and object:getSprite()
    return Smokehouse.tileOfName(sprite and sprite:getName())
end

function Smokehouse.isChamber(object)
    return Smokehouse.tileOf(object) ~= nil
end

-- The sprite name of a tile number in the core's sheet.
function Smokehouse.spriteName(index)
    return Tiles.PREFIX .. index
end

-- The step from a chamber tile to the shed's other tile.
function Smokehouse.otherStep(face, part)
    local step = DOOR_STEP[face]
    local sign = part == 0 and 1 or -1
    return step[1] * sign, step[2] * sign
end

-- Whether a Firebox one step (dx, dy) from this chamber tile may join it: a long side, or the back gable of the
-- back tile; never the door's end, nor the shed's other tile.
function Smokehouse.sideAllowed(face, part, dx, dy)
    if math.abs(dx) + math.abs(dy) ~= 1 then return false end
    local door = DOOR_STEP[face]
    if dx == door[1] and dy == door[2] then return false end
    local ox, oy = Smokehouse.otherStep(face, part)
    return not (dx == ox and dy == oy)
end

-- The overlay's tile number showing where the flue enters, on the long side the camera sees; nil anywhere else.
function Smokehouse.entrySprite(kind, face, part, dx, dy)
    local step = VISIBLE_STEP[face]
    if dx ~= step[1] or dy ~= step[2] then return nil end
    local kindIndex = kind == "Stones" and 1 or kind == "Pipe" and 0
    if not kindIndex then return nil end
    return Tiles.CHAMBER_ENTRY + (kindIndex * FACES + face) * 2 + part
end

-- The ham hung by the door while finished stacks wait in the shed (user's idea): on the door's tile only, by facing.
function Smokehouse.hamSprite(face, part, finished)
    if part ~= 1 or not finished then return nil end
    return Tiles.CHAMBER_HAM + face
end

-- Why Connect can't be done, as a translation key, or nil. c = { burning, fireboxJoined, chamberJoined, allowed,
-- flueSide (Hearth.flueSideTo: nil on the Firebox's door side) }.
function Smokehouse.connectRefusal(c)
    if c.fireboxJoined then return "IGUI_TraditionalPreservationCore_FlueFireboxJoined" end
    if c.chamberJoined then return "IGUI_TraditionalPreservationCore_FlueChamberJoined" end
    if not c.allowed then return "IGUI_TraditionalPreservationCore_FlueDoorEnd" end
    if not c.flueSide then return "IGUI_TraditionalPreservationCore_FlueFireboxDoor" end
    if c.burning then return "IGUI_TraditionalPreservationCore_FlueBurning" end
    return nil
end

-- What a kit lacks from counts (full type -> how many) and whether the tool is there: { {type, missing} }.
function Smokehouse.kitMissing(kind, counts, hasTool)
    local missing = {}
    for _, need in ipairs(Smokehouse.FLUE_KITS[kind].items) do
        local short = need[2] - (counts[need[1]] or 0)
        if short > 0 then table.insert(missing, { need[1], short }) end
    end
    return missing, not hasTool
end

-- The world

local function squareAt(square, dx, dy)
    return getCell():getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
end

-- The chamber tile on a square, with its facing and part.
function Smokehouse.chamberOn(square)
    if not square then return nil end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local face, part = Smokehouse.tileOf(object)
        if face then return object, face, part end
    end
end

local function fireboxOn(square)
    if not square then return nil end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if Hearth.isFirebox(object) then return object end
    end
end

-- A Firebox's flue kind (Pipe or Stones) and side if it's joined to anything, else nil.
function Smokehouse.flueOf(firebox)
    local state = Hearth.stateOf(firebox:getModData())
    return state.flue, state.flueSide
end

-- The chamber tile a joined Firebox's flue goes into, or nil (capped, or its shed is gone).
function Smokehouse.joinedChamber(firebox)
    local flue, side = Smokehouse.flueOf(firebox)
    if not flue then return nil end
    return Smokehouse.chamberOn(Hearth.flueSquare(firebox, side))
end

-- Both tiles of a chamber, from either: { {tile, face, part} }.
function Smokehouse.chamberTiles(tile)
    local face, part = Smokehouse.tileOf(tile)
    if not face then return {} end
    local tiles = { { tile, face, part } }
    local ox, oy = Smokehouse.otherStep(face, part)
    local other, otherFace, otherPart = Smokehouse.chamberOn(squareAt(tile:getSquare(), ox, oy))
    if other and otherFace == face then table.insert(tiles, { other, otherFace, otherPart }) end
    return tiles
end

-- The tile of a chamber that holds its slots (the engine's master tile), from either; the tile itself if neither
-- has them yet.
function Smokehouse.slotTile(tile)
    for _, found in ipairs(Smokehouse.chamberTiles(tile)) do
        if found[1]:getComponent(ComponentType.DryingCraftLogic) then return found[1] end
    end
    return tile
end

-- Every Firebox beside a chamber tile, joined or not: { firebox, tile, face, part, dx, dy, allowed }.
function Smokehouse.fireboxesBy(tile)
    local found = {}
    for _, entry in ipairs(Smokehouse.chamberTiles(tile)) do
        local here, face, part = entry[1], entry[2], entry[3]
        for _, step in ipairs(SIDES) do
            local firebox = fireboxOn(squareAt(here:getSquare(), step[1], step[2]))
            if firebox then
                table.insert(found, { firebox = firebox, tile = here, face = face, part = part, dx = -step[1], dy = -step[2],
                    allowed = Smokehouse.sideAllowed(face, part, step[1], step[2]) })
            end
        end
    end
    return found
end

-- The Firebox joined to this chamber (either tile), with its entry from fireboxesBy, or nil.
function Smokehouse.joinedFirebox(tile)
    for _, found in ipairs(Smokehouse.fireboxesBy(tile)) do
        local into = Smokehouse.joinedChamber(found.firebox)
        if into == found.tile then return found.firebox, found end
    end
end

-- The joined Firebox's fire record (Hearth's state), or nil with no Firebox joined.
function Smokehouse.fireOf(tile)
    local firebox = Smokehouse.joinedFirebox(tile)
    return firebox and Hearth.stateOf(firebox:getModData()) or nil, firebox
end

-- The chamber tile beside a Firebox that it could join, or the one it's joined to: { tile, ... } as fireboxesBy, or nil.
function Smokehouse.chamberBy(firebox)
    for _, side in ipairs({ "Back", "Left", "Right" }) do
        local tile = Smokehouse.chamberOn(Hearth.flueSquare(firebox, side))
        if tile then
            for _, found in ipairs(Smokehouse.fireboxesBy(tile)) do
                if found.firebox == firebox and found.tile == tile then return found end
            end
        end
    end
end

-- The refusal for joining this Firebox to the chamber tile in found (fireboxesBy's), or nil.
function Smokehouse.connectRefusalFor(found)
    return Smokehouse.connectRefusal({
        burning = Hearth.isBurning(found.firebox),
        fireboxJoined = Smokehouse.flueOf(found.firebox) ~= nil,
        chamberJoined = Smokehouse.joinedFirebox(found.tile) ~= nil,
        allowed = found.allowed,
        flueSide = Hearth.flueSideTo(found.firebox, found.tile:getSquare()),
    })
end

-- Lays the flue, or takes it up (kind nil). The Firebox and both chamber tiles redraw at once.
function Smokehouse.setFlue(firebox, tile, kind)
    local side = kind and Hearth.flueSideTo(firebox, tile:getSquare())
    Hearth.setFlue(Hearth.stateOf(firebox:getModData()), kind, side)
    if Hearth.World then Hearth.World.refresh(firebox) end
    if Smokehouse.World then
        for _, entry in ipairs(Smokehouse.chamberTiles(tile)) do Smokehouse.World.refresh(entry[1]) end
    end
end

-- The overlay a chamber tile shows now: where a joined Firebox's flue enters it, if the camera sees that side.
function Smokehouse.chamberEntry(tile)
    local face, part = Smokehouse.tileOf(tile)
    if not face then return nil end
    local step = VISIBLE_STEP[face]
    local firebox = fireboxOn(squareAt(tile:getSquare(), step[1], step[2]))
    if not firebox or Smokehouse.joinedChamber(firebox) ~= tile then return nil end
    return Smokehouse.entrySprite(Smokehouse.flueOf(firebox), face, part, step[1], step[2])
end

-- The stacks

-- Starts a new stack's fire counters: owner is the mod whose recipe hung it (its id), hotNeed the stoked hours in
-- a row its cook takes (nil for a stack that never cooks).
function Smokehouse.startCounters(modData, owner, hotNeed)
    modData.smokeOwner = owner
    modData.hotNeed = hotNeed
    modData.hot, modData.hotCool, modData.cold = 0, 0, 0
    modData.smokeFrom, modData.smokeSession, modData.lastStoked, modData.lastBanked = nil, nil, nil, nil
end

-- Whether a stack is this mod's to step.
function Smokehouse.owns(modData, owner)
    return modData.smokeOwner == owner
end

local function hotToCold(modData)
    modData.cold = (modData.cold or 0) + (modData.hotCool or modData.hot or 0)
    modData.hot, modData.hotCool = 0, 0
end

-- Brings a stack's counters up to the fire's record (a Firebox's Hearth state), or none (not joined). A new or
-- rebuilt Firebox starts from what it has now; whatever hot the stack had becomes cold, as it does when the session
-- it counted in ends. Of the stoked hours since the last look, those in a session that has since begun are hot.
-- coolShare (default 1) is the share of the hours since the last look that were cool enough for cold smoke: fire
-- hours count as cold only then, stoked or banked, so hot keeps its cool part (hotCool) for when its session breaks
-- off. A stack marked noHot takes no cook: its stoked hours are smoke at once.
-- Returns the stoked and banked hours since the last look for the mod's own use (its drying by the fire's warmth),
-- or nil when the stack starts counting from this fire (none, or another).
function Smokehouse.fireStep(modData, fire, coolShare)
    coolShare = coolShare or 1
    modData.burning = fire and fire.fireMode or nil
    if not fire or fire.fireId ~= modData.smokeFrom or (fire.stokedHours or 0) < (modData.lastStoked or 0) then
        hotToCold(modData)
        if fire and fire.fireId then
            modData.smokeFrom, modData.smokeSession = fire.fireId, fire.session
            modData.lastStoked, modData.lastBanked = fire.stokedHours or 0, fire.bankedHours or 0
        else
            modData.smokeFrom, modData.smokeSession = nil, nil
        end
        return nil
    end
    local stoked = (fire.stokedHours or 0) - modData.lastStoked
    local banked = math.max((fire.bankedHours or 0) - (modData.lastBanked or 0), 0)
    -- No session running now: whatever was stoked since belonged to one that has ended (even one that began and
    -- ended between two looks, while away).
    if not fire.session or fire.session ~= modData.smokeSession then
        local inNew = fire.session and math.min(stoked, (fire.stokedHours or 0) - fire.sessionBase) or 0
        hotToCold(modData)
        modData.cold = modData.cold + (stoked - inNew) * coolShare
        modData.hot, modData.hotCool = inNew, inNew * coolShare
        modData.smokeSession = fire.session
    else
        modData.hotCool = (modData.hotCool or modData.hot) + stoked * coolShare
        modData.hot = modData.hot + stoked
    end
    modData.cold = modData.cold + banked * coolShare
    modData.lastStoked, modData.lastBanked = fire.stokedHours or 0, fire.bankedHours or 0
    if modData.noHot then hotToCold(modData) end
    return stoked, banked
end

-- Whether a stack's hot counter has done its cook.
function Smokehouse.hotDone(modData)
    return modData.hotNeed ~= nil and not modData.noHot and (modData.hot or 0) >= modData.hotNeed
end

TraditionalPreservationCore = TraditionalPreservationCore or {}

-- The chamber's SpriteConfig OnIsValid: in the open or under an open roof, not in a room, and its door's front free
-- (Doors). Putting one down asks the same through UI.notInRooms and UI.keepDoorsFree (SmokehouseUI).
function TraditionalPreservationCore.notInRoom(params)
    local name = params.tileInfo and params.tileInfo:getSpriteName()
    return not params.square:isInARoom() and Doors.fits(params.square, name)
end

return Smokehouse
