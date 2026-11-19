-- Traditional Preservation core: the Stone Hearth, a low stone firebox with a lined hole in its top, shared by every TP
-- mod; with the cauldron fitted (Stone Hearth (Cauldron), "cauldron" in the code) the Forged Cauldron hangs over the
-- hole. It is a kind of fire (Fire.kind): Fire banks and stokes it, counts its fuel and keeps what is fitted on it and
-- joined to it; this file is the stone itself: its tiles, what shows in its hole, its door, and the build.
-- The built tile is swapped for a vanilla fireplace, as the Barrel Oven's is (BuildRecipeCode.barrelOven.OnCreate),
-- so vanilla gives it fuel, lighting, burn time, room heat and a firebox to cook in.
--
-- A Stone Hearth with nothing fitted is "bare" in the code (Fire.isBare): a cooking source through the hole, banked and
-- stoked the same way. What shows in the hole is its look (StoneHearth.holeLook): open, a forged pot when a stove food
-- or a fluid is inside (StoneHearth.cooksOn), a lid when only oven food is. Something may be joined to its back or
-- either flank, never the door's side (FireConnect): its tile is picked by facing and hole alone, the hole lidded under
-- a connection that takes the smoke.
local Fire = require "TraditionalPreservationCore/Fire"
local Station = require "TraditionalPreservationCore/Station"
local Tiles = require "TraditionalPreservationCore/Tiles"
local Doors = require "TraditionalPreservationCore/Doors"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"

local StoneHearth = {}

-- The attachment its cauldron tiles show (Cauldron.lua registers it under this id).
StoneHearth.CAULDRON = "cauldron"

-- Tiles: one per fire (out, lit, banked), still or steaming, and facing, all of them fireplaces. The fire's glow is
-- drawn in them, so the overlay is free for the liquid: the one thing the game tints per object (ENGINE_NOTES).
StoneHearth.CAULDRON_LOOKS = Tiles.CAULDRON_LOOKS or {}
StoneHearth.CAULDRON_SPRITES = Tiles.CAULDRON_SPRITES or {}
StoneHearth.FACE_COUNT = Tiles.FACE_COUNT or 2

-- The hearth's own sprite is swapped among its looks, so each look is a "kind" of tile here.
local _, CAULDRON_TILES = Station.kinds(Tiles.PREFIX, StoneHearth.FACE_COUNT, StoneHearth.CAULDRON_LOOKS)

-- The facing (0 S, 1 E) of a cauldron tile, whatever the cauldron shows; nil for any other tile.
function StoneHearth.cauldronFace(spriteName)
    return spriteName and CAULDRON_TILES.face[spriteName]
end

-- The tile for the cauldron's look (Empty, Full, Hot: Hot steams) and the fire, lit or banked; out if neither is given.
function StoneHearth.cauldronSprite(look, face, burning, banked)
    local tile = (burning and (banked and "Banked" or "Lit") or "") .. (look == "Hot" and "Steam" or "")
    return Tiles.PREFIX .. (StoneHearth.CAULDRON_LOOKS[tile ~= "" and tile or "Cold"] + face)
end

-- What the cauldron holds, as the overlay: a pale surface in the kettle's mouth, tinted the colour of its fluids (each
-- vanilla fluid's own, mixed by their shares). Nil when it is empty.
StoneHearth.LIQUID = Tiles.LIQUID

function StoneHearth.liquidOverlay(cauldron, face)
    if not StoneHearth.LIQUID or (cauldron.ml or 0) <= 0 then return nil end
    return Tiles.PREFIX .. (StoneHearth.LIQUID + face), CauldronFluid.liquidColour(cauldron)
end

-- The Stone Hearth with nothing fitted: one tile per hole look and facing (BARE_LOOKS: Open, Lid, Pot), its glow by
-- fire, smoke and hole. Connections draw their own sprites, so the stone has no flue tiles (dropped 2026-11-14).
StoneHearth.BARE_LOOKS = Tiles.BARE_LOOKS or {}
StoneHearth.BARE_SPRITES = Tiles.BARE_SPRITES or {}
StoneHearth.BARE_GLOWS = Tiles.BARE_GLOWS or {}
StoneHearth.OPEN, StoneHearth.LID, StoneHearth.POT = "Open", "Lid", "Pot"
local _, BARE_TILES = Station.kinds(Tiles.PREFIX, StoneHearth.FACE_COUNT, StoneHearth.BARE_LOOKS)

function StoneHearth.bareFace(spriteName)
    return spriteName and BARE_TILES.face[spriteName]
end

-- What is fitted shows as whole-hearth tiles of its own: the cauldron's here, a mod's in its own tileset (Salt's pan).
-- StoneHearth.fittedTiles(id, sprites, faces) makes them Stone Hearth tiles: sprites is their list, faces their facing
-- by name (Station.kinds' tiles.face). Called in shared Lua, before FireWorld's tracker reads Fire.sprites. A tile
-- with nothing noted (a Stone Hearth picked up and put down) shows that id fitted.
local FITTED_TILES = {}   -- spriteName -> { id, face }

-- The facing of any fitted tile, whatever is fitted; nil for any other tile.
function StoneHearth.fittedFace(spriteName)
    local tile = spriteName and FITTED_TILES[spriteName]
    return tile and tile.face
end

-- The facing of any Stone Hearth tile, fitted or not.
function StoneHearth.face(spriteName)
    return StoneHearth.bareFace(spriteName) or StoneHearth.fittedFace(spriteName)
end

-- With a connection that takes the smoke (smoke true) the hole is never open: the smoke must go up the flue.
function StoneHearth.bareSprite(smoke, hole, face)
    local look = hole or StoneHearth.OPEN
    if smoke and look == StoneHearth.OPEN then look = StoneHearth.LID end
    return Tiles.PREFIX .. ((StoneHearth.BARE_LOOKS[look] or StoneHearth.BARE_LOOKS[StoneHearth.OPEN]) + face)
end

function StoneHearth.bareGlow(lit, banked, smoke, hole, face)
    if not lit then return nil end
    local glowFrom = smoke and "Flue" or (hole == StoneHearth.OPEN or hole == StoneHearth.POT) and hole or ""
    local base = StoneHearth.BARE_GLOWS[(banked and "Banked" or "Lit") .. glowFrom]
    return base and Tiles.PREFIX .. (base + face) or nil
end

-- Every Stone Hearth tile, fitted or not (the kind's sprites: fitted tiles added later join the same list).
StoneHearth.SPRITES = {}
local STONE_TILES = {}

-- The Stone Hearth's door need their front tile free (Doors), every look of each.
StoneHearth.FACE_NAMES = { [0] = "S", [1] = "E" }   -- a face number (StoneHearth.face, Smokehouse.chamberOn) as Doors names it

local function addStoneTiles(sprites)
    local doorFacings = {}
    for _, name in ipairs(sprites) do
        if not STONE_TILES[name] then table.insert(StoneHearth.SPRITES, name) end
        STONE_TILES[name] = true
        doorFacings[name] = StoneHearth.FACE_NAMES[StoneHearth.face(name)]
    end
    Doors.register(doorFacings)
end

function StoneHearth.fittedTiles(id, sprites, faces)
    for _, name in ipairs(sprites) do
        assert(faces[name], "StoneHearth.fittedTiles " .. tostring(id) .. ": no facing for " .. name)
        FITTED_TILES[name] = { id = id, face = faces[name] }
    end
    addStoneTiles(sprites)
end

-- The id of what a fitted tile shows fitted, or nil.
function StoneHearth.fittedByTile(spriteName)
    local tile = spriteName and FITTED_TILES[spriteName]
    return tile and tile.id
end

StoneHearth.fittedTiles(StoneHearth.CAULDRON, StoneHearth.CAULDRON_SPRITES, CAULDRON_TILES.face)
addStoneTiles(StoneHearth.BARE_SPRITES)

-- Any Stone Hearth, fitted or not.
function StoneHearth.isStoneHearth(isoObject)
    local sprite = isoObject and isoObject:getSprite()
    return sprite ~= nil and STONE_TILES[sprite:getName()] == true and instanceof(isoObject, "IsoFireplace")
end

-- Stove or oven: where a food is cooked, which picks what shows in the hole. A stove food (a pot on the hob: stews,
-- soups) or a fluid sets the forged pot in it; anything else is oven food (clay pots, roasting pans), under the lid.
-- Every food is oven food unless a mod says otherwise: StoneHearth.cooksOn("stove", "Base.PotOfStew", ...).
StoneHearth.STOVE, StoneHearth.OVEN = "stove", "oven"
local COOKS_ON = {}

function StoneHearth.cooksOn(where, ...)
    assert(where == StoneHearth.STOVE or where == StoneHearth.OVEN,
        "StoneHearth.cooksOn: where is stove or oven, not " .. tostring(where))
    for _, fullType in ipairs({ ... }) do COOKS_ON[fullType] = where end
end

function StoneHearth.cookedOn(item)
    return COOKS_ON[item:getFullType()] or StoneHearth.OVEN
end

-- Vanilla's stews, soups, stir-fries, omelettes, pasta and rice go on the hob.
StoneHearth.cooksOn(StoneHearth.STOVE, "Base.PotOfStew", "Base.PotForgedStew", "Base.BucketOfStew", "Base.PotOfSoup",
    "Base.PotOfSoupRecipe", "Base.PotForgedSoupRecipe", "Base.BucketOfSoup", "Base.PanFriedVegetables",
    "Base.PanFriedVegetables2", "Base.PanFriedVegetablesForged", "Base.GriddlePanFriedVegetables", "Base.OmeletteRecipe",
    "Base.OmeletteRecipeForged", "Base.EggOmelette", "Base.PastaPot", "Base.PastaPotForged", "Base.RicePot",
    "Base.RicePotForged", "Base.WaterPotPasta", "Base.WaterPotForgedPasta", "Base.WaterPotRice",
    "Base.WaterPotForgedRice", "Base.PastaPan", "Base.PastaPanCopper", "Base.RicePan", "Base.RicePanCopper",
    "Base.WaterSaucepanPasta", "Base.WaterSaucepanPastaCopper", "Base.WaterSaucepanRice", "Base.WaterSaucepanRiceCopper")

-- What shows in the hole, by what is in the fire's container (a Java list of items): the pot for any stove food or
-- container with fluid in it, the lid for anything else, open when it is empty.
function StoneHearth.holeLook(items)
    local look = StoneHearth.OPEN
    for i = 0, items and items:size() - 1 or -1 do
        local item = items:get(i)
        local fluid = item:getFluidContainer()
        if (fluid and not fluid:isEmpty()) or StoneHearth.cookedOn(item) == StoneHearth.STOVE then return StoneHearth.POT end
        look = StoneHearth.LID
    end
    return look
end

-- The look of an attachment that gives none: the empty cauldron's.
local NO_LOOK = "Empty"

-- The sprite and glow a Stone Hearth shows now: its attachment's look (drawn by the attachment's sprite and overlay),
-- or its hole (StoneHearth.holeLook; lidded under a connection that takes the smoke), and its fire.
local function showing(fire, fireModData, burning, banked)
    local face = StoneHearth.face(fire:getSprite():getName())
    if not face then return nil end
    local attachment, part = Fire.attachmentOf(fire)
    if attachment then
        local look = attachment.look and attachment.look(part, fire) or NO_LOOK
        local overlay, colour
        if attachment.overlay then overlay, colour = attachment.overlay(part, face, burning, banked) end
        return attachment.sprite(look, face, burning, banked), overlay, colour
    end
    local container = fire:getContainer()
    local hole = StoneHearth.holeLook(container and container:getItems())
    local smoke = Fire.takesSmoke(fireModData)
    return StoneHearth.bareSprite(smoke, hole, face),
        StoneHearth.bareGlow(burning, banked, smoke, smoke and StoneHearth.LID or hole, face)
end

-- Its fire box holds a full metal bucket of brine (11: Salt boils it in the fire) but not two; the tiles say the same.
StoneHearth.FIREBOX_CAPACITY = 15

StoneHearth.kind = Fire.kind({
    id = "stoneHearth",
    fireboxCapacity = StoneHearth.FIREBOX_CAPACITY,
    is = StoneHearth.isStoneHearth,
    face = StoneHearth.face,
    sprites = StoneHearth.SPRITES,
    fittedByTile = StoneHearth.fittedByTile,
    showing = showing,
    -- How a bare Stone Hearth shows in its menu and Info window, its fire banked or burning up again, and its help.
    display = { icon = "media/textures/Item_TPStoneHearth.png", title = "IGUI_CraftingWindow_TPStoneHearth",
        infoText = "ContextMenu_TraditionalPreservationCore_StoneHearthInfo",
        fire = { bank = "media/textures/Item_TPStoneHearthBanked.png", stoke = "media/textures/Item_TPStoneHearthLit.png" },
        help = { out = "IGUI_TraditionalPreservationCore_StoneHearthHelpOut",
            lit = "IGUI_TraditionalPreservationCore_StoneHearthHelpLit",
            banked = "IGUI_TraditionalPreservationCore_StoneHearthHelpBanked" },
        lore = "IGUI_TraditionalPreservationCore_StoneHearthLore" },
    refusals = { joined = "IGUI_TraditionalPreservationCore_FlueStoneHearthJoined",
        door = "IGUI_TraditionalPreservationCore_FlueStoneHearthDoor" },
})

-- Building: the entity script's OnCreate, so a global.
TraditionalPreservationCore = TraditionalPreservationCore or {}

local function toFireplace(params, faceOf)
    local thumpable = params.thumpable
    local sprite = thumpable and thumpable:getSprite()
    local name = sprite and sprite:getName()
    if not faceOf(name) then return nil end
    local square = thumpable:getSquare()
    local fire = IsoFireplace.new(getCell(), square, getSprite(name))
    square:AddTileObject(fire)
    if thumpable:getSquare() ~= nil then
        thumpable:removeFromWorld()
        thumpable:removeFromSquare()
        thumpable:setSquare(nil)
    end
    return { replaceObject = true, object = fire }
end

function TraditionalPreservationCore.OnCreateStoneHearth(params)
    return toFireplace(params, StoneHearth.bareFace)
end

return StoneHearth
