-- Traditional Preservation core: the Smokehouse (moved from Fish & Meat 2026-11-13, so Dairy and later mods share it).
-- A plank shed on four tiles, two by two; Connect the Stone Hearth lays a clay pipe (2 Clay Pipe Segments + 1 Clay, a mason's
-- trowel) or a trench roofed with flat stones (3 Flat Stones + 2 Clay, a shovel or spade) from a Stone Hearth to a chamber
-- tile beside it; Disconnect takes it up again, the pipe or stones back, the clay lost. The flue is a Stone Hearth connection
-- (Fire.connect, id ID), so Core's Connect / Disconnect build it: the link lives on the Stone Hearth alone (its kit name and
-- side under ID in tpFire), the chamber tile it joins is the square on that side. It blocks only its own slot: the
-- Cauldron fits while it is joined. Each chamber tile is checked on its own.
-- What hangs inside is each mod's, counted by SmokehouseStacks (startCounters, fireStep, ...), passed on here.
local Fire = require "TraditionalPreservationCore/Fire"
local StoneHearth = require "TraditionalPreservationCore/StoneHearth"
local FireConnect = require "TraditionalPreservationCore/FireConnect"
local Doors = require "TraditionalPreservationCore/Doors"
local Tiles = require "TraditionalPreservationCore/Tiles"
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"
local squareAt = Station.squareAt

local Smokehouse = {}

-- Inside the chamber: a station, not a place. Its word (UI.placeName: "In the Smokehouse") is what a mod's stacks
-- carry, and the shed has an open roof's air, the season's mean (Weather.STATION_PLACES); the still air, out of the
-- rain and wind, is each mod's to count. Save value: never rename it.
Smokehouse.PLACE = "Smokehouse"
Smokehouse.AIR = "Covered"
Weather.STATION_PLACES[Smokehouse.PLACE] = Smokehouse.AIR

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
Smokehouse.FLUE_KIT_NAMES = { "Pipe", "Stones" }
local function kit(kitName, tool, toolText, items, back, anim)
    return { tool = tool, toolText = toolText, items = items, back = back, anim = anim,
        ticks = Smokehouse.CONNECT_TICKS, removeTicks = Smokehouse.DISCONNECT_TICKS, xp = { "Masonry", Smokehouse.CONNECT_XP },
        text = "ContextMenu_TraditionalPreservationCore_Connect" .. kitName, help = "IGUI_TraditionalPreservationCore_Flue" .. kitName .. "Help",
        name = "IGUI_TraditionalPreservationCore_Flue" .. kitName }
end
Smokehouse.FLUE_KITS = {
    Pipe = kit("Pipe", "MASONS_TROWEL", "IGUI_TraditionalPreservationCore_ToolTrowel",
        { { "Base.ClayPipeSegment", 2 }, { "Base.Clay", 1 } }, "Base.ClayPipeSegment", "Build"),
    Stones = kit("Stones", "DIG_GRAVE", "IGUI_TraditionalPreservationCore_ToolShovel",
        { { "Base.FlatStone", 3 }, { "Base.Clay", 2 } }, "Base.FlatStone", "DigShovel"),
}

local FACES = #Tiles.CHAMBERS / 4
-- Each facing's door, as Doors names it.
local FACE_LETTER = { [0] = "S", [1] = "E" }
-- The flue's entry overlays come in FLUE_KIT_NAMES order, as tools/build_tileset.py lays them out.
local ENTRY_ORDER = {}
for n, kitName in ipairs(Smokehouse.FLUE_KIT_NAMES) do ENTRY_ORDER[kitName] = n - 1 end
-- World steps (+x east, +y south) by facing (0 S, 1 E): towards the door's end (a row), and to the long side the
-- camera sees (a column).
local DOOR_STEP = { [0] = { 0, 1 }, [1] = { 1, 0 } }
local VISIBLE_STEP = { [0] = { 1, 0 }, [1] = { 0, 1 } }
local SIDES = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

-- Each chamber sprite's facing, row (0 the back, 1 the door's end) and column (0 the hidden long side, 1 the one in
-- view), by name: CHAMBERS lists each facing's four tiles, column by column, back row first; face S then E.
local TILE_OF = {}
for n, name in ipairs(Tiles.CHAMBERS) do
    local k = n - 1
    TILE_OF[name] = { math.floor(k / 4), k % 2, math.floor(k / 2) % 2 }
end

-- The chamber's sprite names as a set (name -> true), for the placement rules.
Smokehouse.CHAMBER_NAMES = {}
for name in pairs(TILE_OF) do Smokehouse.CHAMBER_NAMES[name] = true end

-- The doors span both tiles of the front row: each needs its front free, as the Stone Hearth's door does (Doors).
do
    local doors = {}
    for name, found in pairs(TILE_OF) do
        if found[2] == 1 then doors[name] = FACE_LETTER[found[1]] end
    end
    Doors.register(doors)
end

-- A chamber tile's facing (0 S, 1 E), row (part: 0 the back, 1 the door's end) and column (0 the hidden long side,
-- 1 the one in view), from its sprite's name, or nil.
function Smokehouse.tileOfName(name)
    local found = name and TILE_OF[name]
    if found then return found[1], found[2], found[3] end
end

function Smokehouse.tileOf(isoObject)
    local sprite = isoObject and isoObject:getSprite()
    return Smokehouse.tileOfName(sprite and sprite:getName())
end

function Smokehouse.isChamber(isoObject)
    return Smokehouse.tileOf(isoObject) ~= nil
end

-- The sprite name of a tile number in the core's sheet.
function Smokehouse.spriteName(index)
    return Tiles.PREFIX .. index
end

-- The world step from a chamber tile to the shed's tile at (row, col), from this one at (part, col).
function Smokehouse.stepTo(face, part, col, row, toCol)
    local door, visible = DOOR_STEP[face], VISIBLE_STEP[face]
    local dr, dc = row - part, toCol - col
    return door[1] * dr + visible[1] * dc, door[2] * dr + visible[2] * dc
end

-- Whether a Stone Hearth one step (dx, dy) from this chamber tile may join it: either long side or the back gable;
-- never the door's end, nor another tile of the shed.
function Smokehouse.sideAllowed(face, part, col, dx, dy)
    if math.abs(dx) + math.abs(dy) ~= 1 then return false end
    local door, visible = DOOR_STEP[face], VISIBLE_STEP[face]
    local row, column = part + dx * door[1] + dy * door[2], col + dx * visible[1] + dy * visible[2]
    if row == 2 then return false end
    return not (row >= 0 and row <= 1 and column >= 0 and column <= 1)
end

-- The overlay's tile number showing where the flue enters, on the long side the camera sees; nil anywhere else.
function Smokehouse.entrySprite(kitName, face, part, dx, dy)
    local step = VISIBLE_STEP[face]
    if dx ~= step[1] or dy ~= step[2] then return nil end
    local kitIndex = ENTRY_ORDER[kitName]
    if not kitIndex then return nil end
    return Tiles.CHAMBER_ENTRY + (kitIndex * FACES + face) * 2 + part
end

-- What hangs by the door while finished stacks wait in the shed, one piece for every two (a country ham, then a
-- smoked chicken, then a smoked rabbit; Tiles.CHAMBER_PIECE_COLUMNS says which front tile each is on): the overlays
-- of this tile, in order, or none.
Smokehouse.STACKS_A_PIECE = 2
function Smokehouse.pieceSprites(face, part, col, finishedStacks)
    local sprites = {}
    if part ~= 1 then return sprites end
    local count = math.min(#Tiles.CHAMBER_PIECE_COLUMNS, math.ceil((finishedStacks or 0) / Smokehouse.STACKS_A_PIECE))
    for k = 1, count do
        if Tiles.CHAMBER_PIECE_COLUMNS[k] == col then
            table.insert(sprites, Tiles.CHAMBER_PIECES + face * #Tiles.CHAMBER_PIECE_COLUMNS + k - 1)
        end
    end
    return sprites
end

-- Smoke out of the vent while the joined Stone Hearth burns: a plume stoked ("Lit"), a wisp banked; split over the
-- two front tiles. The overlay of this tile, or nil.
Smokehouse.SMOKE_LOOKS = { Lit = 0, Banked = 1 }
function Smokehouse.smokeSprite(face, part, col, look)
    local index = look and Smokehouse.SMOKE_LOOKS[look]
    if part ~= 1 or not index then return nil end
    return Tiles.CHAMBER_SMOKE + (face * 2 + index) * 2 + col
end

-- Why the shed refuses a flue, as translation keys (Smokehouse.chamberRefusal).
Smokehouse.REFUSALS = {
    flueChamberJoined = "IGUI_TraditionalPreservationCore_FlueChamberJoined",
    flueDoorEnd = "IGUI_TraditionalPreservationCore_FlueDoorEnd",
}

-- The shed's own refusal, as a translation key, or nil (Fire.connectRefusal asks it after "already joined").
-- c = { chamberJoined, allowed (the side of the chamber the Stone Hearth is on may take a flue) }.
function Smokehouse.chamberRefusal(c)
    if c.chamberJoined then return Smokehouse.REFUSALS.flueChamberJoined end
    if not c.allowed then return Smokehouse.REFUSALS.flueDoorEnd end
    return nil
end

-- What a kit lacks from counts (full type -> how many) and whether the tool is there: { {type, missing} }.
function Smokehouse.kitMissing(kitName, counts, hasTool)
    return Fire.kitMissing(Smokehouse.FLUE_KITS[kitName], counts, hasTool)
end

-- The world

-- The first object on a square that test(isoObject) answers, with the values test gave back.
local function firstOn(square, test)
    if not square then return nil end
    local isoObjects = square:getObjects()
    for i = 0, isoObjects:size() - 1 do
        local isoObject = isoObjects:get(i)
        local a, b, c = test(isoObject)
        if a then return isoObject, a, b, c end
    end
end

-- The chamber tile on a square, with its facing, row (part) and column.
function Smokehouse.chamberOn(square)
    return firstOn(square, Smokehouse.tileOf)
end

local function stoneHearthOn(square)
    return (firstOn(square, StoneHearth.isStoneHearth))
end

-- A Stone Hearth's flue kit name (Pipe or Stones) and side if it's joined to a Smokehouse, else nil.
function Smokehouse.flueOf(stoneHearth)
    local fireModData = stoneHearth:getModData()[Fire.KEY]
    if Fire.connectedTo(fireModData) ~= Smokehouse.ID then return nil end
    return Fire.joinOf(fireModData)
end

-- The chamber tile a joined Stone Hearth's flue goes into, or nil (capped, or its shed is gone).
function Smokehouse.joinedChamber(stoneHearth)
    local flue, side = Smokehouse.flueOf(stoneHearth)
    if not flue then return nil end
    return Smokehouse.chamberOn(Fire.flueSquare(stoneHearth, side))
end

-- The shed's tiles, from any of them, this one first: { {tile, face, part, col} }. Another shed's tile next to it
-- is never taken: each found tile must stand where its own row and column say.
function Smokehouse.chamberTiles(tile)
    local face, part, col = Smokehouse.tileOf(tile)
    if not face then return {} end
    local tiles = { { tile, face, part, col } }
    for row = 0, 1 do
        for toCol = 0, 1 do
            if row ~= part or toCol ~= col then
                local dx, dy = Smokehouse.stepTo(face, part, col, row, toCol)
                local other, otherFace, otherPart, otherCol = Smokehouse.chamberOn(squareAt(tile:getSquare(), dx, dy))
                if other and otherFace == face and otherPart == row and otherCol == toCol then
                    table.insert(tiles, { other, otherFace, otherPart, otherCol })
                end
            end
        end
    end
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
local function entryOf(stoneHearth, tile, face, part, col, sx, sy)
    return { stoneHearth = stoneHearth, tile = tile, face = face, part = part, col = col, dx = -sx, dy = -sy,
        allowed = Smokehouse.sideAllowed(face, part, col, sx, sy) }
end

-- Every Stone Hearth beside a chamber tile, joined or not: { stoneHearth, tile, face, part, col, dx, dy, allowed }.
function Smokehouse.stoneHearthsBy(tile)
    local found = {}
    for _, chamberTile in ipairs(Smokehouse.chamberTiles(tile)) do
        local here, face, part, col = chamberTile[1], chamberTile[2], chamberTile[3], chamberTile[4]
        for _, step in ipairs(SIDES) do
            local stoneHearth = stoneHearthOn(squareAt(here:getSquare(), step[1], step[2]))
            if stoneHearth then table.insert(found, entryOf(stoneHearth, here, face, part, col, step[1], step[2])) end
        end
    end
    return found
end

-- The Stone Hearth joined to this chamber (either tile), with its chamberTile from stoneHearthsBy, or nil.
function Smokehouse.joinedStoneHearth(tile)
    for _, found in ipairs(Smokehouse.stoneHearthsBy(tile)) do
        local into = Smokehouse.joinedChamber(found.stoneHearth)
        if into == found.tile then return found.stoneHearth, found end
    end
end

-- The joined Stone Hearth's fire record (Fire's state), or nil with no Stone Hearth joined.
function Smokehouse.fireOf(tile)
    local stoneHearth = Smokehouse.joinedStoneHearth(tile)
    return stoneHearth and Fire.fireModData(stoneHearth:getModData()) or nil, stoneHearth
end

-- The chamberTile stoneHearthsBy gives for this Stone Hearth beside this chamber tile, or nil, from the two squares alone (no scan
-- round the shed): the Stone Hearth one step away and the first fire on its square, as stoneHearthsBy finds it.
local function entryFor(stoneHearth, tile)
    local face, part, col = Smokehouse.tileOf(tile)
    local here, there = face and tile:getSquare(), stoneHearth:getSquare()
    if not (here and there) or here:getZ() ~= there:getZ() then return nil end
    local sx, sy = there:getX() - here:getX(), there:getY() - here:getY()
    if math.abs(sx) + math.abs(sy) ~= 1 or stoneHearthOn(there) ~= stoneHearth then return nil end
    return entryOf(stoneHearth, tile, face, part, col, sx, sy)
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
-- fits (then the first found); stoneHearthsBy's chamberTile, or nil with none beside it. Never by a sort (rule 9).
function Smokehouse.connectCandidate(tile)
    local candidates = Smokehouse.stoneHearthsBy(tile)
    for _, found in ipairs(candidates) do
        if Smokehouse.connectRefusalFor(found) == nil then return found end
    end
    return candidates[1]
end

local function redrawChamber(tile)
    if not (tile and Smokehouse.World) then return end
    for _, chamberTile in ipairs(Smokehouse.chamberTiles(tile)) do Smokehouse.World.refresh(chamberTile[1]) end
end

-- The flue as a Stone Hearth connection: Core's Connect / Disconnect build it; its menu texts, icon and notes are
-- SmokehouseUI's.
Fire.connect({
    id = Smokehouse.ID,
    kitNames = Smokehouse.FLUE_KIT_NAMES,
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

-- The overlay a chamber tile shows now: where a joined Stone Hearth's flue enters it, if the camera sees that side
-- (the column in view only).
function Smokehouse.chamberEntry(tile)
    local face, part, col = Smokehouse.tileOf(tile)
    if not face or col ~= 1 then return nil end
    local step = VISIBLE_STEP[face]
    local stoneHearth = stoneHearthOn(squareAt(tile:getSquare(), step[1], step[2]))
    if not stoneHearth or Smokehouse.joinedChamber(stoneHearth) ~= tile then return nil end
    return Smokehouse.entrySprite(Smokehouse.flueOf(stoneHearth), face, part, step[1], step[2])
end

-- The vent's smoke now: "Lit" while the joined Stone Hearth burns stoked, "Banked" while banked, else nil.
function Smokehouse.smokeLook(tile)
    local stoneHearth = Smokehouse.joinedStoneHearth(tile)
    if not stoneHearth then return nil end
    if stoneHearth:isLit() then return "Lit" end
    if Fire.isBanked(stoneHearth) then return "Banked" end
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
