-- Checks the Smokehouse's World outside the game: the recipe tag, its four tiles, the pieces by the door, the vent's
-- smoke and the flue's entry.
-- Run from TraditionalPreservationCore: luajit tests/test_smokehouse_world.lua
local H = dofile("tests/harness.lua")
local check, list = H.check, H.list
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
function isClient() return false end
ComponentType = { Resources = "Resources", DryingCraftLogic = "DryingCraftLogic" }
ResourceIO = { Output = "Output" }
ResourceType = { Item = "Item" }
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

-- A chamber tile on its square; slots (true) gives it the slots, with finished items in its outputs: one a stackId in
-- finished (false for an item with none).
local function chamber(x, y, index, slots, finished)
    local object = { square = square(x, y), sprites = {}, clears = 0 }
    table.insert(object.square.objects, object)
    local logic = slots and { tag = "DryingFrame" }
    if logic then
        function logic:getRecipeTagQuery() return self.tag end
        function logic:setRecipeTagQuery(tag) self.tag = tag end
        function logic:getOutputsGroupName() return "out" end
    end
    local items = {}
    for _, stackId in ipairs(finished or {}) do
        local modData = { stackId = stackId or nil }
        table.insert(items, { getModData = function() return modData end })
    end
    local resources = slots and {
        getResourcesFromGroup = function() return list({ { storedSize = function() return #items end,
            getStoredItems = function() return list(items) end } }) end,
    }
    function object:getComponent(kind) return kind == "Resources" and resources or kind == "DryingCraftLogic" and logic or nil end
    function object:getSprite() return { getName = function() return Tiles.PREFIX .. index end } end
    function object:getSquare() return self.square end
    function object:clearAttachedAnimSprite() self.sprites = {} self.clears = self.clears + 1 end
    function object:addAttachedAnimSpriteByName(name) table.insert(self.sprites, name) end
    return object, logic
end

-- A shed facing S with its back-left tile at x, y (the slots there): { backLeft, frontLeft, backRight, frontRight }.
local function shed(x, y, finished)
    local backLeft, logic = chamber(x, y, Tiles.CHAMBER, true, finished)
    return { backLeft = backLeft, frontLeft = chamber(x, y + 1, Tiles.CHAMBER + 1, false),
        backRight = chamber(x + 1, y, Tiles.CHAMBER + 2, false), frontRight = chamber(x + 1, y + 1, Tiles.CHAMBER + 3, false), logic = logic }
end
local function refreshAll(s)
    for _, key in ipairs({ "backLeft", "frontLeft", "backRight", "frontRight" }) do World.refresh(s[key]) end
end
local function shows(tile) return table.concat(tile.sprites, " ") end
local function sprite(index) return Tiles.PREFIX .. index end

check("the map loader knows all eight chamber tiles", loaders[Tiles.CHAMBERS[1]] and loaders[Tiles.CHAMBERS[8]])

local empty = shed(10, 10)
refreshAll(empty)
check("one built before its recipe tag gets it", empty.logic.tag == Smokehouse.RECIPES)
check("an empty shed shows nothing", shows(empty.backLeft) == "" and shows(empty.frontLeft) == "" and shows(empty.frontRight) == "")
check("any tile finds the slots", Smokehouse.slotTile(empty.frontRight) == empty.backLeft and Smokehouse.slotTile(empty.backLeft) == empty.backLeft)
check("any tile finds all four", #Smokehouse.chamberTiles(empty.frontRight) == 4 and #Smokehouse.chamberTiles(empty.backLeft) == 4)

-- Two sheds side by side: neither takes the other's tiles.
local beside = shed(12, 10)
check("a shed next door keeps its own tiles", #Smokehouse.chamberTiles(empty.backRight) == 4 and #Smokehouse.chamberTiles(beside.backLeft) == 4
    and Smokehouse.slotTile(beside.frontLeft) == beside.backLeft and Smokehouse.slotTile(empty.backRight) == empty.backLeft)

local two = shed(20, 20, { 1, 1, 1, 2 })
refreshAll(two)
check("two finished stacks hang the ham by the door, front-left", shows(two.frontLeft) == sprite(Tiles.CHAMBER_PIECES)
    and shows(two.frontRight) == "" and shows(two.backLeft) == "")
local five = shed(24, 20, { 1, 2, 3, 4, 5 })
refreshAll(five)
check("five: the ham, and the chicken and the rabbit front-right", shows(five.frontLeft) == sprite(Tiles.CHAMBER_PIECES)
    and shows(five.frontRight) == sprite(Tiles.CHAMBER_PIECES + 1) .. " " .. sprite(Tiles.CHAMBER_PIECES + 2))
local plain = shed(28, 20, { false, false, false })
refreshAll(plain)
check("pieces without a stackId count as one stack", shows(plain.frontLeft) == sprite(Tiles.CHAMBER_PIECES) and shows(plain.frontRight) == "")

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
