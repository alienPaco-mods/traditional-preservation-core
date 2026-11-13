-- Checks the Smokehouse's World outside the game: the recipe tag, the ham by the door and the flue's entry.
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
local Hearth = require "TraditionalPreservationCore/Hearth"
local Smokehouse = require "TraditionalPreservationCore/Smokehouse"
dofile("42/media/lua/server/TraditionalPreservationCore/SmokehouseWorld.lua")
local World = Smokehouse.World

-- A chamber tile on its square; slots (true) gives it the slots, with finished items in its outputs.
local function chamber(x, y, index, slots, finished)
    local object = { square = square(x, y), sprites = {}, clears = 0 }
    table.insert(object.square.objects, object)
    local logic = slots and { tag = "DryingFrame" }
    if logic then
        function logic:getRecipeTagQuery() return self.tag end
        function logic:setRecipeTagQuery(tag) self.tag = tag end
        function logic:getOutputsGroupName() return "out" end
    end
    local resources = slots and {
        getResourcesFromGroup = function() return list({ { storedSize = function() return finished or 0 end } }) end,
    }
    function object:getComponent(kind) return kind == "Resources" and resources or kind == "DryingCraftLogic" and logic or nil end
    function object:getSprite() return { getName = function() return Tiles.PREFIX .. index end } end
    function object:getSquare() return self.square end
    function object:clearAttachedAnimSprite() self.sprites = {} self.clears = self.clears + 1 end
    function object:addAttachedAnimSpriteByName(name) table.insert(self.sprites, name) end
    return object, logic
end

check("the map loader knows all four chamber tiles", loaders[Tiles.CHAMBERS[1]] and loaders[Tiles.CHAMBERS[4]])

-- Facing S: the back tile at 10,10 holds the slots, the door's tile at 10,11.
local back, logic = chamber(10, 10, Tiles.CHAMBER, true, 0)
local door = chamber(10, 11, Tiles.CHAMBER + 1, false)
World.refresh(back)
World.refresh(door)
check("one built before its recipe tag gets it", logic.tag == Smokehouse.RECIPES)
check("an empty shed shows nothing", #back.sprites == 0 and #door.sprites == 0)
check("either tile finds the slots", Smokehouse.slotTile(door) == back and Smokehouse.slotTile(back) == back)

local full = chamber(20, 20, Tiles.CHAMBER, true, 2)
local fullDoor = chamber(20, 21, Tiles.CHAMBER + 1, false)
World.refresh(fullDoor)
check("finished stacks waiting hang a ham by the door", table.concat(fullDoor.sprites, " ") == Tiles.PREFIX .. Tiles.CHAMBER_HAM)
World.refresh(full)
check("never on the back tile", #full.sprites == 0)

-- A Firebox on the visible long side (east, facing S) of the back tile, its flue a clay pipe into it.
local firebox = { square = square(11, 10), modData = {} }
table.insert(firebox.square.objects, firebox)
function firebox:getModData() return self.modData end
function firebox:getSquare() return self.square end
function firebox:getX() return 11 end
function firebox:getY() return 10 end
local isFirebox, flueSquare = Hearth.isFirebox, Hearth.flueSquare
Hearth.isFirebox = function(object) return object == firebox end
Hearth.flueSquare = function(_, side) return side == "Left" and squares["10,10,0"] or nil end
Hearth.setFlue(Hearth.stateOf(firebox.modData), "Pipe", "Left")
World.refresh(back)
check("the joined Firebox's pipe shows where it enters", table.concat(back.sprites, " ") == Tiles.PREFIX .. Tiles.CHAMBER_ENTRY)
check("the shed knows its fire", Smokehouse.joinedFirebox(door) == firebox and Smokehouse.fireOf(back) ~= nil)
local redraws = back.clears
World.refresh(back)
check("and doesn't redraw while nothing changes", back.clears == redraws)
Hearth.isFirebox, Hearth.flueSquare = isFirebox, flueSquare

H.done()
