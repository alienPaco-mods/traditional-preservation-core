-- Traditional Preservation core: One and All on a vessel's recipe row. Vanilla's right-click Craft row makes a recipe
-- once; RecipeUI.oneOrAll turns the row for a recipe that takes a fluid from the clicked vessel into a submenu, One
-- (vanilla's own craft) and All (n), n the crafts the vessel's fluid covers and the rest in reach allows. All makes
-- them one after the other from the same vessel, each started as vanilla starts one (ISInventoryPaneContextMenu
-- OnNewCraft), and stops when the next can't be made. The crafting window's own count is left as it is.
-- Also the Craft row (the crafting window filtered to recipes using the item) on an item only a mod's recipes use:
-- vanilla looks each recipe it lists up by its bare name, in Base only, so a recipe in any other module (every TP
-- recipe) is never found and the row left out (ENGINE_NOTES, "Craft row and modules").
local UI = require "TraditionalPreservationCore/UI"

local RecipeUI = {}

-- A little over the fluid's float error, so three thirds of a litre count as three.
local AMOUNT_TOLERANCE_L = 0.0001

-- The logic vanilla's craft row uses, set on this vessel.
local function handcraftLogic(playerObj, recipe, vessel)
    local logic = HandcraftLogic.new(playerObj, nil, nil)
    logic:setIsoObject(logic:findCraftSurface(playerObj, 2))
    logic:setContainers(ISInventoryPaneContextMenu.getContainers(playerObj))
    logic:setRecipeFromContextClick(recipe, vessel)
    return logic
end

-- One craft from the vessel, as vanilla's OnNewCraft; when it's done, the next of left.
local function craft(playerObj, recipe, vessel, left)
    local logic = handcraftLogic(playerObj, recipe, vessel)
    if not logic:canPerformCurrentRecipe() then return end
    local returnToContainer = {}
    if not recipe:isCanBeDoneFromFloor() then
        local items = logic:getRecipeData():getAllInputItems()
        local itemsToReturn = logic:getRecipeData():getAllPutBackInputItems()
        local moved = false
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item:getContainer() ~= playerObj:getInventory() then
                ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
                if itemsToReturn:contains(item) then table.insert(returnToContainer, item) end
                moved = true
            end
        end
        if moved then logic:setRecipeFromContextClick(recipe, vessel) end
    end
    local action = ISEntityUI.HandcraftStart(playerObj, logic, false, true)
    if not action then return end
    action:setOnComplete(function()
        logic:stopCraftAction()
        if left > 1 then craft(playerObj, recipe, vessel, left - 1) end
    end)
    logic:startCraftAction(action)
    ISCraftingUI.ReturnItemsToOriginalContainer(playerObj, returnToContainer)
end

-- Vanilla's craft row for the recipe, at the top or in the item's submenu.
local function vanillaRow(context, recipeName)
    local function find(menu)
        for _, option in ipairs(menu.options) do
            if option.onSelect == ISInventoryPaneContextMenu.OnNewCraft and option.param1
                and option.param1:getScriptObjectFullType() == recipeName then
                return option, menu
            end
            if option.subOption then
                local found, inMenu = find(context:getSubMenu(option.subOption))
                if found then return found, inMenu end
            end
        end
    end
    return find(context)
end

-- oneOrAll = {
--   recipe  the craftRecipe's full name (Module.Name)
--   fluid   the fluid it takes from the vessel      litres  how much one craft takes
-- }
function RecipeUI.oneOrAll(oneOrAll)
    Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
        local fluid = Fluid.Get(oneOrAll.fluid)
        local vessel, litres = UI.firstSelected(items, function(item)
            local container = item:getFluidContainer()
            local amount = container and fluid and container:getSpecificFluidAmount(fluid) or 0
            return amount + AMOUNT_TOLERANCE_L >= oneOrAll.litres and amount
        end)
        if not vessel then return end
        local row, menu = vanillaRow(context, oneOrAll.recipe)
        if not row or row.notAvailable then return end
        local playerObj = getSpecificPlayer(playerNum)
        local recipe = row.param1
        -- A context click sets manual select, which counts only the item type each input was given (one glass Jar
        -- beside Ceramic ones: 1); counted unset, every type in reach counts (ENGINE_NOTES, "Craft row and modules").
        local counter = handcraftLogic(playerObj, recipe, vessel)
        counter:setManualSelectInputs(false)
        local count = math.min(math.floor((litres + AMOUNT_TOLERANCE_L) / oneOrAll.litres), counter:getPossibleCraftCount(true))
        if count <= 1 then return end
        local sub = menu:getNew(menu)
        local one = sub:addOption(getText("ContextMenu_One"), row.target, row.onSelect, row.param1, row.param2, row.param3)
        one.iconTexture = row.iconTexture
        local all = sub:addOption(getText("ContextMenu_AllWithCount", count), playerObj, craft, recipe, vessel, count)
        all.iconTexture = row.iconTexture
        row.onSelect, row.target = nil, nil
        menu:addSubMenu(row, sub)
    end)
end

-- Whether vanilla's Craft row would find a recipe the item is used in: a bare name it can look up in Base.
local function vanillaFinds(scriptItem, playerObj)
    return scriptItem:getUsedInRecipes(playerObj):size() > 0
end

-- Whether any recipe using the item lives outside Base, where vanilla's lookup can't see it.
local function usedOutsideBase(scriptItem)
    local names = scriptItem:getUsedInRecipes()
    for i = 0, names:size() - 1 do
        if not getScriptManager():getCraftRecipe(names:get(i)) then return true end
    end
    return false
end

-- One item or one stack selected, as vanilla's row wants; its Craft row added when vanilla left it out.
Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    if #items ~= 1 then return end
    local item = UI.firstSelected(items, function() return true end)
    local scriptItem = item and item:getScriptItem()
    local playerObj = getSpecificPlayer(playerNum)
    if not scriptItem or vanillaFinds(scriptItem, playerObj) or not usedOutsideBase(scriptItem) then return end
    ISInventoryPaneContextMenu.doRecipeListForItem(context, getText("ContextMenu_ShowCraftRecipesUsed"), scriptItem, playerObj)
end)

return RecipeUI
