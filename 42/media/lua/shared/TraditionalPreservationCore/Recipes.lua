-- Traditional Preservation core: more fluids for a vanilla craft recipe's fluid line, so baking takes a mod's soured
-- milk where it took milk. A script can't do it: a second `craftRecipe` of the same name loads on top of the first
-- and its inputs are added, not swapped, and so does `recipe:Load`. So this loads the line's item and fluid again
-- with the longer list (they go on the end) and puts the new pair where the old one was.
--
-- Run it from OnInitWorld: the game builds each fluid line's filter after that (WorldDictionary init) and seals it.
-- A line that already names every fluid is left alone, so a second world in one session changes nothing.
--     Recipes.addFluids("Base.MakeCakeBatter", { CowMilk = { "SourCowMilk" } }, "TPD")
local log = require "TraditionalPreservationCore/Log"

local Recipes = {}

-- The fluid line with the fluids its list should also take, or nil when it takes them already. extra maps a fluid
-- the line names to the ones to add after it: { CowMilk = { "SourCowMilk" } }.
function Recipes.widenLine(line, extra)
    local head, list, tail = line:match("^(.-%[)([^%]]*)(%].*)$")
    if not list then return nil end
    local names, has = {}, {}
    for name in list:gmatch("[^;]+") do
        names[#names + 1] = name
        has[name] = true
    end
    local added, named = false, #names
    for i = 1, named do
        local name = names[i]
        for _, more in ipairs(extra[name] or {}) do
            if not has[more] then
                names[#names + 1] = more
                has[more] = true
                added = true
            end
        end
    end
    return added and head .. table.concat(names, ";") .. tail or nil
end

-- Engine parts

-- list:set swaps by index; old and new are found by object, so Kahlua never has to pick a remove(int) overload.
local function swapIn(list, old, new)
    local at = list:indexOf(old)
    list:remove(new)
    list:set(at, new)
end

-- Widens every fluid line of the recipe (fullName, "Base.MakeCakeBatter") that names a fluid in extra. Returns the
-- number of lines changed; tag names the mod in the log.
function Recipes.addFluids(fullName, extra, tag)
    local recipe = ScriptManager.instance:getCraftRecipe(fullName)
    if not recipe then
        print("[" .. tag .. "] Could not find " .. fullName)
        return 0
    end
    local inputs, lines, changed = recipe:getInputs(), recipe:getIoLines(), 0
    for i = 0, inputs:size() - 1 do
        local item = inputs:get(i)
        local fluid = item:hasConsumeFromItem() and item:getConsumeFromItemScript()
        local wider = fluid and Recipes.widenLine(fluid:getOriginalLine(), extra)
        if wider then
            -- Loaded alone, the pair goes on the end of both lists: the item line on inputs (the fluid hangs off it),
            -- both on the lines the recipe window counts by.
            recipe:Load(recipe:getName(), "{ inputs { " .. item:getOriginalLine() .. ", -" .. wider .. ", } }")
            local newItem = inputs:get(inputs:size() - 1)
            local newFluid = newItem:getConsumeFromItemScript()
            swapIn(inputs, item, newItem)
            swapIn(lines, item, newItem)
            swapIn(lines, fluid, newFluid)
            changed = changed + 1
            log(tag, "%s now takes %s", fullName, wider)
        end
    end
    return changed
end

return Recipes
