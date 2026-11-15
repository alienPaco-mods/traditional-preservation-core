-- Traditional Preservation core: the Smokehouse (moved from Fish & Meat 2026-11-13, so Dairy and later mods share it).
-- A plank chamber two tiles long; Connect the Stone Hearth lays a clay pipe (2 Clay Pipe Segments + 1 Clay, a mason's
-- trowel) or a trench roofed with flat stones (3 Flat Stones + 2 Clay, a shovel or spade) from a Stone Hearth to a chamber
-- tile beside it; Disconnect takes it up again, the pipe or stones back, the clay lost. The flue is a Stone Hearth connection
-- (Fire.connect, id ID), so Core's Connect / Disconnect build it: the link lives on the Stone Hearth alone (its kind and
-- side under ID in tpFire), the chamber tile it joins is the square on that side. It blocks only its own slot: the
-- Cauldron fits while it is joined. Each chamber tile is checked on its own, so a bigger shed can reuse the rules.
-- What hangs inside is each mod's, counted by SmokehouseStacks (startCounters, fireStep, ...), passed on here.
local Fire = require "TraditionalPreservationCore/Fire"
local StoneHearth = require "TraditionalPreservationCore/StoneHearth"
local FireConnect = require "TraditionalPreservationCore/FireConnect"
local Doors = require "TraditionalPreservationCore/Doors"
local Tiles = require "TraditionalPreservationCore/Tiles"
local Station = require "TraditionalPreservationCore/Station"
local squareAt = Station.squareAt

local Smokehouse = {}

-- The connection's id: its save key in tpFire, never renamed.
Smokehouse.ID = "smokehouse"
Smokehouse.CONNECT_TICKS = 400
Smokehouse.DISCONNECT_TICKS = 200
Smokehouse.CONNECT_XP = 5

-- The recipe tag the chamber lists; a mod's smoking recipes carry it.
Smokehouse.RECIPES = "Smokehouse"
Smokehouse.STACKS = Tiles.CHAMBER_STACKS

-- The two ways to join them, in menu order: the connection's kits (Fire.connect). Items are { full type, count };
-- the tool (an ItemTag's name) stays.
Smokehouse.FLUE_KINDS = { "Pipe", "Stones" }
local function kit(kind, tool, toolText, items, back, anim)
    return { tool = tool, toolText = toolText, items = items, back = back, anim = anim,
        ticks = Smokehouse.CONNECT_TICKS, removeTicks = Smokehouse.DISCONNECT_TICKS, xp = { "Masonry", Smokehouse.CONNECT_XP },
        text = "ContextMenu_TraditionalPreservationCore_Connect" .. kind, help = "IGUI_TraditionalPreservationCore_Flue" .. kind .. "Help",
        name = "IGUI_TraditionalPreservationCore_Flue" .. kind }
end
Smokehouse.FLUE_KITS = {
    Pipe = kit("Pipe", "MASONS_TROWEL", "IGUI_TraditionalPreservationCore_ToolTrowel",
        { { "Base.ClayPipeSegment", 2 }, { "Base.Clay", 1 } }, "Base.ClayPipeSegment", "Build"),
    Stones = kit("Stones", "DIG_GRAVE", "IGUI_TraditionalPreservationCore_ToolShovel",
        { { "Base.FlatStone", 3 }, { "Base.Clay", 2 } }, "Base.FlatStone", "DigShovel"),
}

local FACES = #Tiles.CHAMBERS / 2
-- Each facing's door, as Doors names it.
local FACE_LETTER = { [0] = "S", [1] = "E" }
-- The flue's entry overlays come in FLUE_KINDS order, as tools/build_tileset.py lays them out.
local ENTRY_ORDER = {}
for n, kind in ipairs(Smokehouse.FLUE_KINDS) do ENTRY_ORDER[kind] = n - 1 end
-- World steps (+x east, +y south) by facing (0 S, 1 E): towards the door's end, and to the long side the camera sees.
local DOOR_STEP = { [0] = { 0, 1 }, [1] = { 1, 0 } }
local VISIBLE_STEP = { [0] = { 1, 0 }, [1] = { 0, 1 } }
local SIDES = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- Each chamber sprite's facing and part, by name: CHAMBERS lists back then door tile, face S then E.
local TILE_OF = {}
for n, name in ipairs(Tiles.CHAMBERS) do TILE_OF[name] = { math.floor((n - 1) / 2), (n - 1) % 2 } end

-- The chamber's sprite names as a set (name -> true), for the placement rules.
Smokehouse.CHAMBER_NAMES = {}
for name in pairs(TILE_OF) do Smokehouse.CHAMBER_NAMES[name] = true end

-- The door's tile of each facing needs its front free, as the Stone Hearth's door does (Doors).
do
    local doors = {}
    for face = 0, FACES - 1 do doors[Tiles.CHAMBERS[face * 2 + 2]] = FACE_LETTER[face] end
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

-- Whether a Stone Hearth one step (dx, dy) from this chamber tile may join it: a long side, or the back gable of the
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
    local kindIndex = ENTRY_ORDER[kind]
    if not kindIndex then return nil end
    return Tiles.CHAMBER_ENTRY + (kindIndex * FACES + face) * 2 + part
end

-- The overlay hung by the door while finished stacks wait in the shed (a ham, the user's idea): on the door's tile
-- only, by facing.
function Smokehouse.readySprite(face, part, finished)
    if part ~= 1 or not finished then return nil end
    return Tiles.CHAMBER_READY + face
end

-- The shed's own refusal, as a translation key, or nil (Fire.connectRefusal asks it after "already joined").
-- c = { chamberJoined, allowed (the side of the chamber the Stone Hearth is on may take a flue) }.
function Smokehouse.chamberRefusal(c)
    if c.chamberJoined then return "IGUI_TraditionalPreservationCore_FlueChamberJoined" end
    if not c.allowed then return "IGUI_TraditionalPreservationCore_FlueDoorEnd" end
    return nil
end

-- What a kit lacks from counts (full type -> how many) and whether the tool is there: { {type, missing} }.
function Smokehouse.kitMissing(kind, counts, hasTool)
    return Fire.kitMissing(Smokehouse.FLUE_KITS[kind], counts, hasTool)
end

-- The world

-- The first object on a square that test(object) answers, with the two values test gave back.
local function firstOn(square, test)
    if not square then return nil end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local a, b = test(object)
        if a then return object, a, b end
    end
end

-- The chamber tile on a square, with its facing and part.
function Smokehouse.chamberOn(square)
    return firstOn(square, Smokehouse.tileOf)
end

local function stoneHearthOn(square)
    return (firstOn(square, StoneHearth.isStoneHearth))
end

-- A Stone Hearth's flue kind (Pipe or Stones) and side if it's joined to a Smokehouse, else nil.
function Smokehouse.flueOf(stoneHearth)
    local state = stoneHearth:getModData()[Fire.KEY]
    if Fire.connectedTo(state) ~= Smokehouse.ID then return nil end
    return Fire.joinOf(state)
end

-- The chamber tile a joined Stone Hearth's flue goes into, or nil (capped, or its shed is gone).
function Smokehouse.joinedChamber(stoneHearth)
    local flue, side = Smokehouse.flueOf(stoneHearth)
    if not flue then return nil end
    return Smokehouse.chamberOn(Fire.flueSquare(stoneHearth, side))
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

-- stoneHearthsBy's entry for a Stone Hearth one step (sx, sy) from a chamber tile.
local function entryOf(stoneHearth, tile, face, part, sx, sy)
    return { stoneHearth = stoneHearth, tile = tile, face = face, part = part, dx = -sx, dy = -sy,
        allowed = Smokehouse.sideAllowed(face, part, sx, sy) }
end

-- Every Stone Hearth beside a chamber tile, joined or not: { firebox, tile, face, part, dx, dy, allowed }.
function Smokehouse.stoneHearthsBy(tile)
    local found = {}
    for _, entry in ipairs(Smokehouse.chamberTiles(tile)) do
        local here, face, part = entry[1], entry[2], entry[3]
        for _, step in ipairs(SIDES) do
            local stoneHearth = stoneHearthOn(squareAt(here:getSquare(), step[1], step[2]))
            if stoneHearth then table.insert(found, entryOf(stoneHearth, here, face, part, step[1], step[2])) end
        end
    end
    return found
end

-- The Stone Hearth joined to this chamber (either tile), with its entry from stoneHearthsBy, or nil.
function Smokehouse.joinedStoneHearth(tile)
    for _, found in ipairs(Smokehouse.stoneHearthsBy(tile)) do
        local into = Smokehouse.joinedChamber(found.stoneHearth)
        if into == found.tile then return found.stoneHearth, found end
    end
end

-- The joined Stone Hearth's fire record (Fire's state), or nil with no Stone Hearth joined.
function Smokehouse.fireOf(tile)
    local stoneHearth = Smokehouse.joinedStoneHearth(tile)
    return stoneHearth and Fire.stateOf(stoneHearth:getModData()) or nil, stoneHearth
end

-- The entry stoneHearthsBy gives for this Stone Hearth beside this chamber tile, or nil, from the two squares alone (no scan
-- round the shed): the Stone Hearth one step away and the first fire on its square, as stoneHearthsBy finds it.
local function entryFor(stoneHearth, tile)
    local face, part = Smokehouse.tileOf(tile)
    local here, there = face and tile:getSquare(), stoneHearth:getSquare()
    if not (here and there) or here:getZ() ~= there:getZ() then return nil end
    local sx, sy = there:getX() - here:getX(), there:getY() - here:getY()
    if math.abs(sx) + math.abs(sy) ~= 1 or stoneHearthOn(there) ~= stoneHearth then return nil end
    return entryOf(stoneHearth, tile, face, part, sx, sy)
end

-- The chamber tile beside a Stone Hearth that it could join, or the one it's joined to: { tile, ... } as stoneHearthsBy, or nil.
local function chamberBy(stoneHearth)
    for _, side in ipairs(FireConnect.SIDES) do
        local tile = Smokehouse.chamberOn(Fire.flueSquare(stoneHearth, side))
        local found = tile and entryFor(stoneHearth, tile)
        if found then return found end
    end
end

-- The refusal for joining this Stone Hearth to the chamber tile in found (stoneHearthsBy's), or nil.
function Smokehouse.connectRefusalFor(found)
    return Fire.connectRefusal(found.stoneHearth, Fire.connection(Smokehouse.ID), found.tile)
end

-- The Stone Hearth the chamber's Connect offers: the first beside it that may join, so a refusal shows only when none
-- fits (then the first found); stoneHearthsBy's entry, or nil with none beside it. Never by a sort (rule 9).
function Smokehouse.connectCandidate(tile)
    local candidates = Smokehouse.stoneHearthsBy(tile)
    for _, found in ipairs(candidates) do
        if Smokehouse.connectRefusalFor(found) == nil then return found end
    end
    return candidates[1]
end

local function redrawChamber(tile)
    if not (tile and Smokehouse.World) then return end
    for _, entry in ipairs(Smokehouse.chamberTiles(tile)) do Smokehouse.World.refresh(entry[1]) end
end

-- The flue as a Stone Hearth connection: Core's Connect / Disconnect build it; its menu texts, icon and notes are
-- SmokehouseUI's.
Fire.connect({
    id = Smokehouse.ID,
    kinds = Smokehouse.FLUE_KINDS,
    kits = Smokehouse.FLUE_KITS,
    blocks = "connection",
    smoke = true,
    finds = function(fire)
        local found = chamberBy(fire)
        return found and found.tile
    end,
    joined = function(fire) return Smokehouse.joinedChamber(fire) end,
    refusal = function(fire, tile)
        local found = entryFor(fire, tile)
        return Smokehouse.chamberRefusal({ chamberJoined = Smokehouse.joinedStoneHearth(tile) ~= nil, allowed = found and found.allowed })
    end,
    onChange = function(_, tile) redrawChamber(tile) end,
})

-- The overlay a chamber tile shows now: where a joined Stone Hearth's flue enters it, if the camera sees that side.
function Smokehouse.chamberEntry(tile)
    local face, part = Smokehouse.tileOf(tile)
    if not face then return nil end
    local step = VISIBLE_STEP[face]
    local stoneHearth = stoneHearthOn(squareAt(tile:getSquare(), step[1], step[2]))
    if not stoneHearth or Smokehouse.joinedChamber(stoneHearth) ~= tile then return nil end
    return Smokehouse.entrySprite(Smokehouse.flueOf(stoneHearth), face, part, step[1], step[2])
end

-- The stacks: SmokehouseStacks', reached here so no caller changes (DEVGUIDE refactoring rule 5).
local SmokehouseStacks = require "TraditionalPreservationCore/SmokehouseStacks"
for _, name in ipairs({ "startCounters", "owns", "fireStep", "hotDone" }) do Smokehouse[name] = SmokehouseStacks[name] end

TraditionalPreservationCore = TraditionalPreservationCore or {}

-- The chamber's SpriteConfig OnIsValid: in the open or under an open roof, not in a room, and its door's front free
-- (Doors). Putting one down asks the same through UI.notInRooms and UI.keepDoorsFree (SmokehouseUI).
function TraditionalPreservationCore.notInRoom(params)
    local name = params.tileInfo and params.tileInfo:getSpriteName()
    return not params.square:isInARoom() and Doors.fits(params.square, name)
end

return Smokehouse
