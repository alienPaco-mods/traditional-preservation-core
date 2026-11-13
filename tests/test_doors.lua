-- Checks that a station's door or fire mouth keeps its front tile free. Run from TraditionalPreservationCore: luajit tests/test_doors.lua
local H = dofile("tests/harness.lua")
local check = H.check
package.path = "42/media/lua/shared/?.lua;" .. package.path
IsoFlagType = { collideN = "collideN", WallN = "WallN", WallNW = "WallNW", collideW = "collideW", WallW = "WallW",
    solid = "solid", solidtrans = "solidtrans" }

-- A tiny map: squares by "x,y", each with its edge flags and the sprites (name, blocks) standing on it.
local grid = {}
local function square(x, y, sprites, flags)
    local s = { x = x, y = y, sprites = sprites or {}, flags = flags or {} }
    function s:getX() return self.x end
    function s:getY() return self.y end
    function s:getZ() return 0 end
    function s:getProperties()
        local flagSet = self.flags
        return { has = function(_, flag) return flagSet[flag] == true end }
    end
    function s:getObjects()
        local objects = {}
        for i, sprite in ipairs(self.sprites) do
            objects[i] = { getSprite = function() return { getName = function() return sprite[1] end,
                getProperties = function() return { has = function(_, prop) return sprite[2] and prop == "BlocksPlacement" end } end } end }
        end
        return { size = function() return #objects end, get = function(_, i) return objects[i + 1] end }
    end
    grid[x .. "," .. y] = s
    return s
end
function getCell() return { getGridSquare = function(_, x, y) return grid[x .. "," .. y] end } end

local Hearth = require "TraditionalPreservationCore/Hearth"
local Doors = require "TraditionalPreservationCore/Doors"

local hearthS, hearthE = Hearth.sprite("Empty", 0), Hearth.sprite("Empty", 1)
local fireboxS, fireboxE = Hearth.fireboxSprite(nil, nil, nil, 0), Hearth.fireboxSprite(nil, nil, nil, 1)
check("the Hearth's mouth opens its way, every look", Doors.facingOf(hearthS) == "S" and Doors.facingOf(hearthE) == "E"
    and Doors.facingOf(Hearth.sprite("Hot", 1)) == "E")
check("so does the Stone Hearth's door, with any flue or hole", Doors.facingOf(fireboxS) == "S" and Doors.facingOf(fireboxE) == "E"
    and Doors.facingOf(Hearth.fireboxSprite("Pipe", "Left", "Pot", 0)) == "S"
    and Doors.facingOf(Hearth.fireboxSprite("Stones", "Right", "Lid", 1)) == "E")
check("anything else has no door", Doors.facingOf("vanilla_crate") == nil and Doors.facingOf(nil) == nil)

-- Its own front: facing S the tile south, facing E the tile east.
local open = square(0, 0)
check("open ground in front: it fits", Doors.fits(open, fireboxS) and Doors.fits(open, fireboxE))
square(0, 1, { { "crate", true } })
check("a crate south: facing S refused", not Doors.fits(open, fireboxS))
check("but facing E it's beside, not in front", Doors.fits(open, fireboxE))
square(1, 0, { { "rug", false } })
check("a rug (nothing that blocks placing) doesn't count", Doors.fits(open, fireboxE))
check("no square there at all is open ground", Doors.fits(square(50, 50), fireboxS))
local walled = square(10, 10)
square(10, 11, {}, { collideN = true })
check("a wall between it and its front tile: refused", not Doors.fits(walled, hearthS))
square(11, 10, {}, { WallN = true })
check("a wall on the front tile's other edge doesn't count", Doors.fits(walled, hearthE))

-- In front of another one's door.
square(20, 20, { { fireboxS, true } })
check("nothing stands in front of a Firebox's door", not Doors.fits(square(20, 21), "vanilla_crate")
    and not Doors.fits(grid["20,21"], hearthE))
check("its back and flanks are fine", Doors.fits(square(20, 19), "vanilla_crate") and Doors.fits(square(21, 20), fireboxS))
square(30, 30, { { hearthE, true } })
check("nor in front of the Hearth's mouth", not Doors.fits(square(31, 30), fireboxS) and Doors.fits(square(30, 31), fireboxE))
check("a mod's door counts once registered", (function()
    square(40, 40, { { "shed_door", true } })
    local before = Doors.fits(square(40, 41), "vanilla_crate")
    Doors.register({ shed_door = "S" })
    return before and not Doors.fits(grid["40,41"], "vanilla_crate")
end)())

-- The build menu's check: the ghost's tile on its square.
local function params(sq, name) return { square = sq, tileInfo = { getSpriteName = function() return name end } } end
check("the build ghost asks the same", not TraditionalPreservationCore.doorFits(params(open, fireboxS))
    and TraditionalPreservationCore.doorFits(params(open, fireboxE)))

H.done()
