-- Traditional Preservation core: fluid containers. What one holds (fluidIn, ml, isEmptyVessel), and a bucket that goes through
-- several items coming back as the bucket it was: a recipe that uses a container up turns it into another item,
-- so its type is noted on that item and handed on at each step, until the last recipe gives the container back.
local Container = {}

-- The fluid in a fluid container if it is all one kind, else nil (empty, or a mixture).
function Container.fluidIn(container)
    if not container or container:isEmpty() then return nil end
    local fluid = container:getPrimaryFluid()
    if not fluid or container:getPrimaryFluidAmount() < container:getAmount() - 0.001 then return nil end
    return fluid:getFluidTypeString()
end

-- Whole millilitres in a fluid container.
function Container.ml(container)
    return math.floor(container:getAmount() * 1000 + 0.5)
end

-- An item that can take a fluid and holds none: only these are filled, so nothing is ever topped up into a mixture.
function Container.isEmptyVessel(item)
    local container = item:getFluidContainer()
    return container ~= nil and container:isEmpty() and container:getCapacity() > 0
end

-- The engine's cooking swap (ReplaceOnCooked) carries over only the modData keys that start with "condition:"
-- (InventoryItem.copyConditionModData), so the note is one of those.
Container.KEY = "condition:tpContainer"

-- The type noted on an item the recipe used up, or nil.
function Container.noted(craftRecipeData)
    local used = craftRecipeData:getAllConsumedItems()
    for i = 0, used:size() - 1 do
        local fullType = used:get(i):getModData()[Container.KEY]
        if fullType then return fullType end
    end
    return nil
end

-- Writes the note on what the recipe made: every item, or only those of targetType.
local function write(craftRecipeData, fullType, targetType)
    local created = craftRecipeData:getAllCreatedItems()
    for i = 0, created:size() - 1 do
        local item = created:get(i)
        if not targetType or item:getFullType() == targetType then item:getModData()[Container.KEY] = fullType end
    end
end

-- OnCreate of the first recipe: notes the fluid container it used up.
function Container.note(craftRecipeData, targetType)
    local used = craftRecipeData:getAllConsumedItems()
    for i = 0, used:size() - 1 do
        local item = used:get(i)
        if item:getFluidContainer() then return write(craftRecipeData, item:getFullType(), targetType) end
    end
end

-- OnCreate of a recipe in between: hands the note on. Cooking needs no help (see KEY).
function Container.pass(craftRecipeData, targetType)
    local fullType = Container.noted(craftRecipeData)
    if fullType then write(craftRecipeData, fullType, targetType) end
end

local function remove(item)
    local container = item:getContainer()
    if container then return container:DoRemoveItem(item) end
    local worldItem = item:getWorldItem()
    if not worldItem then return end
    worldItem:getSquare():transmitRemoveItemFromSquare(worldItem)
    worldItem:removeFromWorld()
    worldItem:removeFromSquare()
end

-- OnCreate of the last recipe, whose script gives back placeholderType: swaps that for the container noted.
-- Returns the item the player ends up with, empty. An item from before the note comes back as the placeholder.
function Container.giveBack(craftRecipeData, character, placeholderType)
    local created = craftRecipeData:getAllCreatedItems()
    local placeholder
    for i = 0, created:size() - 1 do
        if created:get(i):getFullType() == placeholderType then placeholder = created:get(i) break end
    end
    local fullType = Container.noted(craftRecipeData)
    if not placeholder or not character or not fullType or fullType == placeholderType then return placeholder end

    local item = instanceItem(fullType)
    if not item then return placeholder end
    local fluid = item:getFluidContainer()
    if fluid then fluid:Empty() end
    remove(placeholder)
    Actions.addOrDropItem(character, item)
    return item
end

return Container
