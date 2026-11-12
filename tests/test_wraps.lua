-- Checks Handcraft and Pour (the one wrap each of vanilla's hand craft and fluid transfer actions), Station.near and
-- the recipe and container helpers, on stand-ins for the engine. Run from TraditionalPreservationCore:
-- luajit tests/test_wraps.lua
local H = dofile("tests/harness.lua")
local check = H.check
package.path = "42/media/lua/shared/?.lua;" .. package.path

-- Handcraft
local seen = {}
ISHandcraftAction = {}
function ISHandcraftAction:performRecipe()
    table.insert(seen, "vanilla")
    return "done"
end
local Handcraft = require "TraditionalPreservationCore/Handcraft"
Handcraft.after(function(action, recipeData) table.insert(seen, "salt after " .. recipeData) end)
Handcraft.around(function(action) table.insert(seen, "vinegar before") return action.carried end,
    function(action, recipeData, kept) table.insert(seen, "vinegar after " .. recipeData .. " " .. kept) end)
local craft = setmetatable({ carried = "bottles", logic = { getRecipeData = function() return "data" end } }, { __index = ISHandcraftAction })
check("vanilla's result is passed back", craft:performRecipe() == "done")
check("the last added is outermost: its before first, its after last, with what it kept",
    table.concat(seen, "|") == "vinegar before|vanilla|salt after data|vinegar after data bottles")
seen = {}
setmetatable({ carried = "x" }, { __index = ISHandcraftAction }):performRecipe()
check("a craft with no recipe data runs no afters", table.concat(seen, "|") == "vinegar before|vanilla")

-- Pour
seen = {}
instanceof = function(object, class) return object ~= nil and object.class == class end
ISFluidTransferAction = {}
for _, name in ipairs({ "start", "stop", "complete" }) do
    ISFluidTransferAction[name] = function() table.insert(seen, "vanilla " .. name) return name .. "ed" end
end
local Pour = require "TraditionalPreservationCore/Pour"
Pour.before("start", function() table.insert(seen, "core start") end)
Pour.after("stop", function() table.insert(seen, "core stop") end)
Pour.after("complete", function() table.insert(seen, "core complete") end)
Pour.before("start", function() table.insert(seen, "dairy start") end)
Pour.before("stop", function() table.insert(seen, "dairy stop") end)
Pour.after("complete", function() table.insert(seen, "dairy complete") end)
local pour = setmetatable({}, { __index = ISFluidTransferAction })
check("each passes vanilla's result back", pour:start() == "started" and pour:stop() == "stoped" and pour:complete() == "completeed")
check("as nested wraps would run: the later mod's before first, the core's after first", table.concat(seen, "|")
    == "dairy start|core start|vanilla start|dairy stop|vanilla stop|core stop|vanilla complete|core complete|dairy complete")
local item, object = { class = "InventoryItem" }, { class = "IsoObject" }
check("the owner of a pour's end is its item or its world object",
    Pour.owner({ getOwner = function() return item end }) == item and Pour.owner({ getOwner = function() return object end }) == object
    and Pour.owner({ getOwner = function() return { class = "Other" } end }) == nil and Pour.owner(nil) == nil)

-- Station.near
local Station = require "TraditionalPreservationCore/Station"
local map = {}
local function put(x, y, name)
    map[x .. "," .. y] = map[x .. "," .. y] or {}
    table.insert(map[x .. "," .. y], name)
end
getCell = function()
    return { getGridSquare = function(_, x, y, z)
        local objects = z == 0 and map[x .. "," .. y]
        return objects and { getObjects = function() return H.list(objects) end } or nil
    end }
end
put(10, 10, "here") put(12, 10, "east2") put(10, 11, "south1") put(9, 10, "west1") put(13, 10, "far") put(10, 11, "south1b")
local square = { getX = function() return 10 end, getY = function() return 10 end, getZ = function() return 0 end }
local found = Station.near(square, 2, function(name) return name ~= "here" end)
check("nearest first; of two as near, the first the scan meets; nothing past the radius",
    table.concat(found, " ") == "west1 south1 south1b east2")
check("by coordinates too, where no square is loaded under the asker", Station.nearAt(11, 10, 0, 1, function() return true end)[1] == "here")
check("no square, nothing found", #Station.near(nil, 2, function() return true end) == 0)

-- Recipes: what a craft made and used up
package.preload["TraditionalPreservationCore/Log"] = function() return function() end end
local Recipes = require "TraditionalPreservationCore/Recipes"
local function thing(fullType) return { getFullType = function() return fullType end } end
local data = { getAllCreatedItems = function() return H.list({ thing("A.Pot"), thing("A.Lid"), thing("A.Pot") }) end,
    getAllConsumedItems = function() return H.list({ thing("A.Fat"), thing("A.Meat") }) end }
check("created by full type, by a set, or all", #Recipes.created(data, "A.Pot") == 2 and #Recipes.created(data, { ["A.Lid"] = true }) == 1
    and #Recipes.created(data) == 3)
check("consumed the same, in order", Recipes.consumed(data, { ["A.Meat"] = true, ["A.Fat"] = true })[1]:getFullType() == "A.Fat"
    and #Recipes.consumed(data, "A.None") == 0)

-- Container: millilitres and empty vessels
local Container = require "TraditionalPreservationCore/Container"
local function vessel(litres, capacity)
    return { getFluidContainer = function() return capacity and { getAmount = function() return litres end,
        isEmpty = function() return litres <= 0 end, getCapacity = function() return capacity end } or nil end }
end
check("whole millilitres", Container.ml(vessel(0.2999999, 1):getFluidContainer()) == 300)
check("an empty vessel takes a fluid; a full one, one with no room at all and a plain item don't",
    Container.isEmptyVessel(vessel(0, 1)) and not Container.isEmptyVessel(vessel(0.5, 1))
    and not Container.isEmptyVessel(vessel(0, 0)) and not Container.isEmptyVessel(vessel(0)))
H.done()
