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
    function self:setWorldItem(worldItem) self.worldItem = worldItem end
    return self
end
local function recipe(used, created)
    return { getAllConsumedItems = function() return H.list(used) end, getAllCreatedItems = function() return H.list(created) end }
end
local function inventory()
    local self = { removed = {} }
    function self:Remove(it) table.insert(self.removed, it) end
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
-- Taken off as vanilla's transfer takes an item off the floor (Uses.remove): the square's removeWorldObject also
-- redraws the floor tile.
local taken = {}
local square = {
    transmitRemoveItemFromSquare = function(_, worldItem) table.insert(taken, worldItem) end,
    removeWorldObject = function(_, worldItem) table.insert(taken, "removed " .. worldItem.name) end,
}
local dropped = item("Base.BucketEmpty", true)
local onFloor = { name = "bucket", getSquare = function() return square end }
dropped.worldItem = onFloor
Container.giveBack(recipe({ brine }, { dropped }), "player", "Base.BucketEmpty")
check("a bucket dropped on the floor is swapped too", taken[1] == onFloor and taken[2] == "removed bucket"
    and #taken == 2 and #given == 2)
check("and no longer points at the floor", dropped.worldItem == nil)

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

-- Action.removeItem goes through vanilla's Remove, which also takes the item out of the hands; Remove doesn't.
local Action = require "TraditionalPreservationCore/Action"
local held = item("Base.Cup")
local bag = { removed = {}, done = {} }
function bag:Remove(it) table.insert(self.removed, it) end
function bag:DoRemoveItem(it) table.insert(self.done, it) end
held.container = bag
Action.removeItem(held)
check("removeItem takes it out through Remove (the hands too), not DoRemoveItem", bag.removed[1] == held and #bag.done == 0)
held.container = nil
Action.removeItem(held)
check("and does nothing to an item held by nothing", #bag.removed == 1)

-- A game-clock action: the job bar follows the clock, and it completes when the minutes are up.
local hours = 10
_G.getGameTime = function() return { getWorldAgeHours = function() return hours end } end
local tool = { delta = nil }
function tool:setJobDelta(d) self.delta = d end
local instant = false
local timed = { character = { isTimedActionInstant = function() return instant end }, completed = 0 }
function timed:forceComplete() self.completed = self.completed + 1 end
Action.startClock(timed)
hours = 10 + 1.5 / 60
Action.clockProgress(timed, tool, 3)
check("half the minutes: the bar is half way, not done", math.abs(tool.delta - 0.5) < 1e-9 and timed.completed == 0)
instant = true
Action.clockProgress(timed, tool, 3)
check("the instant cheat completes it at once", timed.completed == 1)
instant = false
hours = 10 + 4 / 60
Action.clockProgress(timed, tool, 3)
check("past the minutes the bar stops at full and it completes", tool.delta == 1 and timed.completed == 2)

H.done()
