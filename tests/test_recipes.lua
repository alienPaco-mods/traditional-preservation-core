-- Checks Recipes (more fluids for a vanilla recipe's fluid line) on stand-ins for the engine. Run from
-- TraditionalPreservationCore: luajit tests/test_recipes.lua
local H = dofile("tests/harness.lua")
local check = H.check
package.path = "42/media/lua/shared/?.lua;" .. package.path

local Recipes = require "TraditionalPreservationCore/Recipes"

local SOUR = { CowMilk = { "SourCowMilk" }, SheepMilk = { "SourSheepMilk" } }

-- The line
check("one milk", Recipes.widenLine("fluid 1.0 [CowMilk]", SOUR) == "fluid 1.0 [CowMilk;SourCowMilk]")
check("two milks, flags kept", Recipes.widenLine("fluid 5.0 [CowMilk;SheepMilk] mode:mixture", SOUR)
    == "fluid 5.0 [CowMilk;SheepMilk;SourCowMilk;SourSheepMilk] mode:mixture")
check("several to add", Recipes.widenLine("fluid 0.3 [CowMilk]", { CowMilk = { "A", "B" } })
    == "fluid 0.3 [CowMilk;A;B]")
check("a line with them already is left", Recipes.widenLine("fluid 1.0 [CowMilk;SourCowMilk]", SOUR) == nil)
check("so is one with no milk", Recipes.widenLine("fluid 1.0 [Water]", SOUR) == nil)
check("and one with no list", Recipes.widenLine("fluid 1.0 Water", SOUR) == nil)

-- The engine: a Java list from 0, with the calls Recipes makes.
local function jlist(items)
    local l = { items = items }
    function l:size() return #self.items end
    function l:get(i) return self.items[i + 1] end
    function l:indexOf(o)
        for i, v in ipairs(self.items) do if v == o then return i - 1 end end
        return -1
    end
    function l:remove(o)
        for i, v in ipairs(self.items) do if v == o then table.remove(self.items, i) return true end end
        return false
    end
    function l:set(i, o) self.items[i + 1] = o end
    function l:add(o) self.items[#self.items + 1] = o end
    return l
end

local function script(line, fluid)
    return { line = line, fluid = fluid,
        getOriginalLine = function(self) return self.line end,
        hasConsumeFromItem = function(self) return self.fluid ~= nil end,
        getConsumeFromItemScript = function(self) return self.fluid end }
end

-- A recipe as the engine loads MakeCakeBatter's tail: a bowl, any container with its milk, then yeast.
local bowl = script("item 1 [Base.Bowl]")
local milk = script("fluid 1.0 [CowMilk]")
local jug = script("item 1 [*]", milk)
local yeast = script("item 1 [Base.Yeast]")
local recipe = { name = "MakeCakeBatter", inputs = jlist({ bowl, jug, yeast }), lines = jlist({ bowl, jug, milk, yeast }) }
function recipe:getName() return self.name end
function recipe:getInputs() return self.inputs end
function recipe:getIoLines() return self.lines end
local loaded = {}
function recipe:Load(name, text)
    loaded[#loaded + 1] = { name = name, text = text }
    local itemLine, fluidLine = text:match("{ inputs { (.-), %-(.-), } }")
    local newFluid = script(fluidLine)
    local newItem = script(itemLine, newFluid)
    self.inputs:add(newItem)
    self.lines:add(newItem)
    self.lines:add(newFluid)
end
ScriptManager = { instance = { getCraftRecipe = function(_, name) return name == "Base.MakeCakeBatter" and recipe or nil end } }

check("one line changed", Recipes.addFluids("Base.MakeCakeBatter", SOUR, "T") == 1)
check("loaded under its own name, item line kept", loaded[1].name == "MakeCakeBatter"
    and loaded[1].text == "{ inputs { item 1 [*], -fluid 1.0 [CowMilk;SourCowMilk], } }")
local inputs, lines = recipe.inputs.items, recipe.lines.items
check("inputs keep their count and order", #inputs == 3 and inputs[1] == bowl and inputs[3] == yeast)
check("the new pair took the old one's place", inputs[2] ~= jug and inputs[2].line == "item 1 [*]"
    and inputs[2].fluid.line == "fluid 1.0 [CowMilk;SourCowMilk]")
check("lines too", #lines == 4 and lines[1] == bowl and lines[2] == inputs[2] and lines[3] == inputs[2].fluid
    and lines[4] == yeast)
check("a second world changes nothing", Recipes.addFluids("Base.MakeCakeBatter", SOUR, "T") == 0 and #loaded == 1)
check("a missing recipe is skipped", Recipes.addFluids("Base.Nothing", SOUR, "T") == 0)

-- Magazines
local listed = Recipes.withLearned({ "base:kitchentools", "Forge_Cooking_Pot" }, "TraditionalPreservationCore.Forge_TPCauldron")
check("a magazine's list keeps what it had and gains the recipe", listed and #listed == 3 and listed[1] == "base:kitchentools"
    and listed[3] == "TraditionalPreservationCore.Forge_TPCauldron")
check("and is left alone when it has it already", Recipes.withLearned(listed, "TraditionalPreservationCore.Forge_TPCauldron") == nil)

H.done()
