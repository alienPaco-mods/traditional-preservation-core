-- Checks Portions (food eaten from a vessel a portion at a time, and the one wrap of vanilla's eat action) on
-- stand-ins for the engine. Run from TraditionalPreservationCore: luajit tests/test_portions.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near
package.path = "42/media/lua/shared/?.lua;" .. package.path
H.installGetText(H.loadTranslations("42/media/lua/shared/Translate/EN"))

local eaten = {}
ISEatFoodAction = {}
function ISEatFoodAction:complete(...)
    table.insert(eaten, "complete " .. self.item:getFullType())
    self.item.hunger = self.item.hunger * (1 - self.share)
    if self.item.hunger > -0.01 and self.item.container then self.item.container:DoRemoveItem(self.item) end
    return "eaten"
end
function ISEatFoodAction:serverStop() table.insert(eaten, "stop " .. self.item:getFullType()) end

ScriptManager = { instance = { getItem = function(_, fullType)
    return fullType == "Base.ClayJar" and { getActualWeight = function() return 0.5 end } or nil
end } }

local function bag()
    local self = { items = {}, added = {} }
    function self:contains(item) return self.items[item] == true end
    function self:DoRemoveItem(item) self.items[item] = nil end
    function self:AddItem(fullType) table.insert(self.added, fullType) return fullType end
    return self
end
local function food(fullType, hunger, container)
    local self = { hunger = hunger, container = container }
    function self:getFullType() return fullType end
    function self:getContainer() return self.container end
    function self:setHungChange(x) self.hunger = x end
    function self:setBaseHunger(x) self.base = x end
    function self:setCalories(x) self.calories = x end
    function self:setCarbohydrates(x) self.carbs = x end
    function self:setLipids(x) self.lipids = x end
    function self:setProteins(x) self.proteins = x end
    function self:setName(x) self.name = x end
    function self:setCustomName(x) self.customName = x end
    function self:setActualWeight(x) self.weight = x end
    function self:setCustomWeight(x) self.customWeight = x end
    if container then container.items[self] = true end
    return self
end

local Portions = require "TraditionalPreservationCore/Portions"
local P = { hunger = -0.1, calories = 30, carbohydrates = 1, lipids = 2, proteins = 5 }

-- Food values
local jar = food("Mod.Jar", 0)
Portions.set(jar, P, 3, 4)
check("three portions of a jar of four", near(jar.hunger, -0.3) and near(jar.base, -0.4) and near(jar.calories, 90)
    and near(jar.carbs, 3) and near(jar.lipids, 6) and near(jar.proteins, 15))
Portions.set(jar, P, 2)
check("with no full given, the whole item is the portions", near(jar.base, -0.2))
check("portions left come from the hunger", near(Portions.left(-0.25, P.hunger), 2.5))

-- Text and label
check("whole portions read plain", Portions.text(3) == "3" and Portions.text(1.00000001) == "1")
check("a part-portion to one place", Portions.text(2.5) == "2.5" and Portions.text(0.449) == "0.4")
check("the name has the portions", Portions.name("Jar of Yogurt", 3) == "Jar of Yogurt (3 portions)")
check("one reads singular", Portions.name("Jar of Yogurt", 1.00000001) == "Jar of Yogurt (1 portion)")
Portions.label(jar, "Jar of Yogurt", 2, "Base.ClayJar", 0.25)
check("labelled and weighed: the empty vessel plus what is left", jar.name == "Jar of Yogurt (2 portions)" and jar.customName
    and near(jar.weight, 1.0) and jar.customWeight)
Portions.label(jar, "Jar of Yogurt", 2, "Base.Unknown", 0.25)
check("a vessel the game doesn't know weighs nothing", near(jar.weight, 0.5))

-- After a use
local shelf = bag()
local crock = food("Mod.Crock", -0.3, shelf)
local relabelled = 0
local function relabel() relabelled = relabelled + 1 end
check("one with enough left is relabelled", Portions.used(crock, shelf, function() return true end, "Base.ClayJar", relabel) == nil
    and relabelled == 1 and shelf:contains(crock))
check("an emptied one gives its vessel back where it was", Portions.used(crock, shelf, function() return false end, "Base.ClayJar", relabel) == "Base.ClayJar"
    and not shelf:contains(crock) and shelf.added[1] == "Base.ClayJar" and relabelled == 1)
local asked = false
Portions.used(crock, shelf, function() asked = true return true end, "Base.ClayJar", relabel)
check("one the engine already used up isn't asked what it holds", not asked and #shelf.added == 2)

-- The eat action
local seen = {}
Portions.onEat("Mod.Jar", function(item) table.insert(seen, "before " .. item.hunger) return "kept" end,
    function(item, container, kept) table.insert(seen, "after " .. tostring(container == shelf) .. " " .. kept) end)
local mine = food("Mod.Jar", -0.4, shelf)
local action = setmetatable({ item = mine, share = 0.5 }, { __index = ISEatFoodAction })
check("vanilla's result is passed back", action:complete() == "eaten")
check("before, vanilla, then after with the container it was in and what before kept",
    table.concat(seen, "|") == "before -0.4|after true kept" and eaten[1] == "complete Mod.Jar" and near(mine.hunger, -0.2))
seen, eaten = {}, {}
setmetatable({ item = food("Base.Apple", -0.2), share = 1 }, { __index = ISEatFoodAction }):complete()
check("other food passes straight through", #seen == 0 and eaten[1] == "complete Base.Apple")
setmetatable({ item = mine, share = 0 }, { __index = ISEatFoodAction }):serverStop()
check("a cut-short eat is handled too", #seen == 2 and eaten[2] == "stop Mod.Jar")
Portions.onEat("Mod.Crock", nil, function() table.insert(seen, "crock") end)
seen, eaten = {}, {}
setmetatable({ item = crock, share = 0 }, { __index = ISEatFoodAction }):complete()
check("a second kind is added without wrapping twice, and needs no before", #eaten == 1 and seen[1] == "crock")
H.done()
