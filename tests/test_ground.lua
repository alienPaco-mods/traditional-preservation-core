-- Checks Ground: where something set into the earth may be dug. Run from TraditionalPreservationCore:
-- luajit tests/test_ground.lua
local H = dofile("tests/harness.lua")
local check = H.check
package.path = "42/media/lua/shared/?.lua;" .. package.path

local Ground = require "TraditionalPreservationCore/Ground"

IsoFlagType = { canBeRemoved = "canBeRemoved" }
local function square(outside, furrowOk, grass)
    local objects = { { getProperties = function() return { has = function(_, flag) return grass and flag == "canBeRemoved" end } end } }
    return { outside = outside, furrowOk = furrowOk, isOutside = function(self) return self.outside end,
        getObjects = function() return { size = function() return #objects end, get = function(_, i) return objects[i + 1] end } end }
end

check("without vanilla's farming menu nothing is diggable", not Ground.diggable(square(true, true)))
ISFarmingMenu = { canDigHereSquare = function(s) return s.furrowOk end }
check("outdoors where vanilla would dig a furrow: diggable", Ground.diggable(square(true, true)))
check("not where vanilla wouldn't (grass not cleared, a road, a plant)", not Ground.diggable(square(true, false)))
check("not under a roof, even where vanilla would dig", not Ground.diggable(square(false, true)))
check("not with no square", not Ground.diggable(nil))
check("not with grass still on it, though vanilla's furrow would dig through it", not Ground.diggable(square(true, true, true))
    and Ground.hasGrass(square(true, true, true)) and not Ground.hasGrass(square(true, true, false)))

H.done()
