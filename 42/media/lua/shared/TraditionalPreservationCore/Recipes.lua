-- Traditional Preservation core: more fluids for a vanilla craft recipe's fluid line, so baking takes a mod's soured
-- milk where it took milk. A script can't do it: a second `craftRecipe` of the same name loads on top of the first
-- and its inputs are added, not swapped, and so does `recipe:Load`. So this loads the line's item and fluid again
-- with the longer list (they go on the end) and puts the new pair where the old one was.
--
-- Run it from OnInitWorld: the game builds each fluid line's filter after that (WorldDictionary init) and seals it.
-- A line that already names every fluid is left alone, so a second world in one session changes nothing.
--     Recipes.addFluids("Base.MakeCakeBatter", { CowMilk = { "SourCowMilk" } }, "TPD")
-- Also what every OnCreate asks of its recipe data: the items it made and the ones it used up (created, consumed).
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

-- What a craft made or used up, as a Lua list. wanted is a full type, a set of them ({ [fullType] = true }) or nil
-- for every item: a recipe's OnCreate reads its own items out of all of them.
local function listed(items, wanted)
    local found = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local fullType = item:getFullType()
        if not wanted or wanted == fullType or (type(wanted) == "table" and wanted[fullType]) then table.insert(found, item) end
    end
    return found
end

function Recipes.created(craftRecipeData, wanted)
    return listed(craftRecipeData:getAllCreatedItems(), wanted)
end

function Recipes.consumed(craftRecipeData, wanted)
    return listed(craftRecipeData:getAllConsumedItems(), wanted)
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

-- OnCreate for a recipe whose food comes out cooked (Fish & Meat's black pudding turned out of its pan): each
-- cookable food it made is set cooked, so it reads Cooked and can be warmed again. Scripts name it
-- TraditionalPreservationCore.OnCreateCooked.
function Recipes.cookOutputs(craftRecipeData)
    local created = craftRecipeData:getAllCreatedItems()
    for i = 0, created:size() - 1 do
        local item = created:get(i)
        if instanceof(item, "Food") and item:isCookable() then item:setCooked(true) end
    end
end

TraditionalPreservationCore = TraditionalPreservationCore or {}
TraditionalPreservationCore.OnCreateCooked = Recipes.cookOutputs

-- Magazines and research

-- A magazine's recipes as a list of names, with name added if it isn't there: the entries DoParam's
-- LearnedRecipes takes (it replaces the list). nil when nothing needs adding.
function Recipes.withLearned(names, name)
    for _, have in ipairs(names) do
        if have == name then return nil end
    end
    local all = {}
    for _, have in ipairs(names) do table.insert(all, have) end
    table.insert(all, name)
    return all
end

-- Teaches recipeName (a craft recipe's full name) from a vanilla magazine too (magazineType, "Base.SmithingMag2").
-- The magazine's script item holds the list and every copy reads it, so magazines already in the world teach it too
-- (ENGINE_NOTES). Known by the recipe's own name, as the character's known list is checked.
function Recipes.teach(magazineType, recipeName, tag)
    local magazine = ScriptManager.instance:getItem(magazineType)
    local recipe = ScriptManager.instance:getCraftRecipe(recipeName)
    if not magazine or not recipe then
        print("[" .. tag .. "] Could not find " .. (magazine and recipeName or magazineType))
        return false
    end
    local learned, names = magazine:getLearnedRecipes(), {}
    for i = 0, learned and learned:size() - 1 or -1 do table.insert(names, learned:get(i)) end
    local all = Recipes.withLearned(names, recipe:getName())
    if all then
        magazine:DoParam("LearnedRecipes = " .. table.concat(all, ";"))
        log(tag, "%s teaches %s", magazineType, recipe:getName())
    end
    return true
end

-- Lets an item be researched for recipeName (Research Recipes on its menu), as ResearchableRecipes in its script.
function Recipes.researchable(itemType, recipeName)
    local item = ScriptManager.instance:getItem(itemType)
    if item then item:DoParam("ResearchableRecipes = " .. recipeName) end
end

return Recipes
