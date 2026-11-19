-- Checks the Smokehouse's World outside the game: its four tiles, the record tile, the pieces by the door, the vent's
-- smoke and the flue's entry.
-- Run from TraditionalPreservationCore: luajit tests/test_smokehouse_world.lua
local H = dofile("tests/harness.lua")
local check, list = H.check, H.list
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
function isClient() return false end
ArrayList = { new = function() return list({}) end }
local loaders = {}
MapObjects = { OnLoadWithSprite = function(name, handler) loaders[name] = handler end }
function getPlayer() return nil end

local squares = {}
function getCell()
    return { getGridSquare = function(_, x, y, z) return squares[x .. "," .. y .. "," .. z] end }
end
local function square(x, y)
    local s = { objects = {} }
    function s:getX() return x end
    function s:getY() return y end
    function s:getZ() return 0 end
    function s:getObjects() return list(self.objects) end
    squares[x .. "," .. y .. ",0"] = s
    return s
end

local Tiles = require "TraditionalPreservationCore/Tiles"
local Fire = require "TraditionalPreservationCore/Fire"
local StoneHearth = require "TraditionalPreservationCore/StoneHearth"
local Smokehouse = require "TraditionalPreservationCore/Smokehouse"
dofile("42/media/lua/server/TraditionalPreservationCore/SmokehouseWorld.lua")
local World = Smokehouse.World

-- A chamber tile on its square.
local function chamber(x, y, index)
    local object = { square = square(x, y), sprites = {}, clears = 0 }
    table.insert(object.square.objects, object)
    function object:getSprite() return { getName = function() return Tiles.PREFIX .. index end } end
    function object:getSquare() return self.square end
    function object:clearAttachedAnimSprite() self.sprites = {} self.clears = self.clears + 1 end
    function object:addAttachedAnimSpriteByName(name) table.insert(self.sprites, name) end
    return object
end

-- What a mod's record says is finished in each shed, by its record tile (Smokehouse.countsFinished).
local finishedIn = {}

-- A shed facing S with its back-left tile (the record tile) at x, y: { backLeft, frontLeft, backRight, frontRight },
-- finished pieces waiting in it.
local function shed(x, y, finished)
    local backLeft = chamber(x, y, Tiles.CHAMBER)
    finishedIn[backLeft] = finished
    return { backLeft = backLeft, frontLeft = chamber(x, y + 1, Tiles.CHAMBER + 1),
        backRight = chamber(x + 1, y, Tiles.CHAMBER + 2), frontRight = chamber(x + 1, y + 1, Tiles.CHAMBER + 3) }
end
local function refreshAll(s)
    for _, key in ipairs({ "backLeft", "frontLeft", "backRight", "frontRight" }) do World.refresh(s[key]) end
end
local function shows(tile) return table.concat(tile.sprites, " ") end
local function sprite(index) return Tiles.PREFIX .. index end

check("the map loader knows all eight chamber tiles", loaders[Tiles.CHAMBERS[1]] and loaders[Tiles.CHAMBERS[8]])

local empty = shed(10, 10)
refreshAll(empty)
check("an empty shed shows nothing", shows(empty.backLeft) == "" and shows(empty.frontLeft) == "" and shows(empty.frontRight) == "")
check("any tile finds all four", #Smokehouse.chamberTiles(empty.frontRight) == 4 and #Smokehouse.chamberTiles(empty.backLeft) == 4)
check("the record tile is the back left one, from any tile", Smokehouse.recordTile(empty.frontRight) == empty.backLeft
    and Smokehouse.recordTile(empty.backRight) == empty.backLeft and Smokehouse.recordTile(empty.backLeft) == empty.backLeft)
local askedWith
Smokehouse.countsFinished(function(record) askedWith = record return finishedIn[record] end)
finishedIn[empty.backLeft] = 2
check("a mod's count of finished pieces is asked of the record tile", Smokehouse.finishedPieces(empty.frontLeft) == 2
    and askedWith == empty.backLeft)
finishedIn[empty.backLeft] = nil
check("a count is a function", not pcall(Smokehouse.countsFinished, 3))

-- Two sheds side by side: neither takes the other's tiles.
local beside = shed(12, 10)
check("a shed next door keeps its own tiles", #Smokehouse.chamberTiles(empty.backRight) == 4 and #Smokehouse.chamberTiles(beside.backLeft) == 4
    and Smokehouse.recordTile(beside.frontLeft) == beside.backLeft and Smokehouse.recordTile(empty.backRight) == empty.backLeft)

local one = shed(20, 20, 1)
refreshAll(one)
check("one finished piece hangs the ham by the door, front-left", shows(one.frontLeft) == sprite(Tiles.CHAMBER_PIECES)
    and shows(one.frontRight) == "" and shows(one.backLeft) == "")
local five = shed(24, 20, 5)
refreshAll(five)
check("five: the ham, and the chicken and the rabbit front-right, no more", shows(five.frontLeft) == sprite(Tiles.CHAMBER_PIECES)
    and shows(five.frontRight) == sprite(Tiles.CHAMBER_PIECES + 1) .. " " .. sprite(Tiles.CHAMBER_PIECES + 2))
local two = shed(28, 20)

-- A Stone Hearth on the side in view (east, facing S) of the back-right tile, its flue a clay pipe into it.
local stoneHearth = { square = square(12, 30), modData = {}, lit = false }
table.insert(stoneHearth.square.objects, stoneHearth)
local joined = shed(10, 30)
function stoneHearth:getModData() return self.modData end
function stoneHearth:getSquare() return self.square end
function stoneHearth:getX() return 12 end
function stoneHearth:getY() return 30 end
function stoneHearth:isLit() return self.lit end
local isStoneHearth, flueSquare, isBanked = StoneHearth.isStoneHearth, Fire.flueSquare, Fire.isBanked
local banked = false
StoneHearth.isStoneHearth = function(object) return object == stoneHearth end
Fire.flueSquare = function(_, side) return side == "Left" and squares["11,30,0"] or nil end
Fire.isBanked = function(object) return object == stoneHearth and banked end
Fire.join(Fire.fireModData(stoneHearth.modData), Smokehouse.ID, "Pipe", "Left")
refreshAll(joined)
check("the joined Stone Hearth's pipe shows where it enters", shows(joined.backRight) == sprite(Tiles.CHAMBER_ENTRY))
check("the shed knows its fire from any tile", Smokehouse.joinedStoneHearth(joined.frontLeft) == stoneHearth and Smokehouse.fireOf(joined.backLeft) ~= nil)
check("the fire out: no smoke", shows(joined.frontLeft) == "" and shows(joined.frontRight) == "" and Smokehouse.smokeLook(joined.frontLeft) == nil)
stoneHearth.lit = true
refreshAll(joined)
check("stoked: the plume over both front tiles", shows(joined.frontLeft) == sprite(Tiles.CHAMBER_SMOKE)
    and shows(joined.frontRight) == sprite(Tiles.CHAMBER_SMOKE + 1) and shows(joined.backRight) == sprite(Tiles.CHAMBER_ENTRY))
stoneHearth.lit, banked = false, true
refreshAll(joined)
check("banked: the wisp", shows(joined.frontLeft) == sprite(Tiles.CHAMBER_SMOKE + 2) and shows(joined.frontRight) == sprite(Tiles.CHAMBER_SMOKE + 3))
local redraws = joined.backRight.clears
World.refresh(joined.backRight)
check("and doesn't redraw while nothing changes", joined.backRight.clears == redraws)

-- The connection's lookups find the tile from the Stone Hearth's own squares, and refuse a tile it isn't beside.
local flue = Fire.connection(Smokehouse.ID)
check("finds: the chamber tile on the flue's side", flue.finds(stoneHearth) == joined.backRight and flue.joined(stoneHearth) == joined.backRight)
check("a shed already joined refuses another", flue.refusal(stoneHearth, joined.backRight) == "IGUI_TraditionalPreservationCore_FlueChamberJoined")
check("a tile the Stone Hearth isn't beside counts as not allowed", flue.refusal(stoneHearth, two.backLeft) == "IGUI_TraditionalPreservationCore_FlueDoorEnd")

-- Connect on a shed with two Stone Hearths beside it offers the one that may join, whichever is found first (rule 9).
local function stoneHearthAt(x, y)
    local fire = { square = square(x, y), modData = {} }
    table.insert(fire.square.objects, fire)
    function fire:getModData() return self.modData end
    function fire:getSquare() return self.square end
    function fire:isLit() return false end
    return fire
end
local candidates = shed(40, 40)
local west, east = stoneHearthAt(39, 40), stoneHearthAt(42, 41)
local refusal = Fire.connectRefusal
StoneHearth.isStoneHearth = function(object) return object == west or object == east end
for _, refused in ipairs({ west, east }) do
    Fire.connectRefusal = function(fire) return fire == refused and "refused" or nil end
    local found = Smokehouse.connectCandidate(candidates.backLeft)
    check("two Stone Hearths, " .. (refused == west and "west" or "east") .. " refused: the other is offered",
        found ~= nil and found.stoneHearth ~= refused)
end
Fire.connectRefusal = function() return "refused" end
check("both refused: the first found, for its refusal",
    Smokehouse.connectCandidate(candidates.backLeft).stoneHearth == Smokehouse.stoneHearthsBy(candidates.backLeft)[1].stoneHearth)
Fire.connectRefusal = refusal
StoneHearth.isStoneHearth, Fire.flueSquare, Fire.isBanked = isStoneHearth, flueSquare, isBanked

H.done()
