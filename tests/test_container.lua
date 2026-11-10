-- Checks that a container's kind follows it through a chain of recipes. Run from TraditionalPreservationCore:
-- luajit tests/test_container.lua
local H = dofile("tests/harness.lua")
local check = H.check
package.path = "42/media/lua/shared/?.lua;" .. package.path
local Container = require "TraditionalPreservationCore/Container"

local function item(fullType, holdsFluid)
    local self = { modData = {}, emptied = false }
    function self:getFullType() return fullType end
    function self:getModData() return self.modData end
    function self:getFluidContainer() return holdsFluid and { Empty = function() self.emptied = true end } or nil end
    function self:getContainer() return self.container end
    function self:getWorldItem() return self.worldItem end
    return self
end
local function recipe(used, created)
    return { getAllConsumedItems = function() return H.list(used) end, getAllCreatedItems = function() return H.list(created) end }
end
local function inventory()
    local self = { removed = {} }
    function self:DoRemoveItem(it) table.insert(self.removed, it) end
    return self
end

local given = {}
instanceItem = function(fullType) return item(fullType, true) end
Actions = { addOrDropItem = function(character, it) table.insert(given, it) end }

-- Salt's chain: bucket -> charge -> brine -> (boiled) crust -> bucket
local forged, soil = item("Base.BucketForged", true), item("Salt.Soil")
local charge, sandbag = item("Salt.Charge"), item("Base.EmptySandbag")
Container.note(recipe({ soil, forged }, { charge, sandbag }), "Salt.Charge")
check("the first recipe notes the bucket on what it made", charge.modData[Container.KEY] == "Base.BucketForged")
check("and only on the item named", sandbag.modData[Container.KEY] == nil)
check("the note is one the cooking swap keeps", Container.KEY:find("^condition:") ~= nil)

local brine = item("Salt.Brine")
Container.pass(recipe({ charge }, { brine }))
check("a recipe in between hands it on", brine.modData[Container.KEY] == "Base.BucketForged")

local bag = inventory()
local plain, salt = item("Base.BucketEmpty", true), item("Salt.Loose")
plain.container = bag
local back = Container.giveBack(recipe({ item("Tool.Knife"), brine }, { salt, plain }), "player", "Base.BucketEmpty")
check("the last recipe gives back the bucket that went in", back:getFullType() == "Base.BucketForged" and given[1] == back)
check("empty", back.emptied)
check("in place of the script's bucket", bag.removed[1] == plain and #bag.removed == 1)

-- A placeholder dropped at the player's feet (no room to carry it)
local taken = {}
local dropped = item("Base.BucketEmpty", true)
dropped.worldItem = {
    getSquare = function() return { transmitRemoveItemFromSquare = function(_, worldItem) table.insert(taken, worldItem) end } end,
    removeFromWorld = function() table.insert(taken, "world") end,
    removeFromSquare = function() table.insert(taken, "square") end,
}
Container.giveBack(recipe({ brine }, { dropped }), "player", "Base.BucketEmpty")
check("a bucket dropped on the floor is swapped too", taken[1] == dropped.worldItem and #taken == 3 and #given == 2)

-- Nothing to swap
given = {}
local same = item("Salt.Crust")
same.modData[Container.KEY] = "Base.BucketEmpty"
local kept = item("Base.BucketEmpty", true)
check("a plain bucket is the script's own", Container.giveBack(recipe({ same }, { kept }), "player", "Base.BucketEmpty") == kept and #given == 0)
check("an item from before the note gives the script's bucket", Container.giveBack(recipe({ item("Salt.Crust") }, { kept }), "player", "Base.BucketEmpty") == kept and #given == 0)
check("a recipe with no note hands nothing on", (function()
    local out = item("Salt.Brine")
    Container.pass(recipe({ item("Salt.Charge") }, { out }))
    return out.modData[Container.KEY] == nil
end)())
instanceItem = function() return nil end
same.modData[Container.KEY] = "Gone.Bucket"
check("a bucket type that no longer exists gives the script's bucket", Container.giveBack(recipe({ same }, { kept }), "player", "Base.BucketEmpty") == kept)

H.done()
