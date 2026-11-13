-- Traditional Preservation core: food eaten from a vessel a portion at a time (Dairy's Jar of Yogurt, Fish & Meat's
-- Crock of Potted Meat). The item's food values are its portions, so vanilla's Eat, Eat Half and Eat Quarter work on
-- it; what a mod adds is the name with the portions left (or a plain name: Portions.weigh), the vessel's weight under
-- them and the empty vessel back with the last bite. A mod keeps its own modData keys and one portion's food; this holds what the two share, and
-- the one wrap of vanilla's eat action (Portions.onEat), so a mod adds a handler instead of wrapping it again.
local Portions = {}

local KEY = "IGUI_TraditionalPreservationCore_"

-- Sets a food item's values to `portions` of one portion's food p ({ hunger, calories, carbohydrates, lipids,
-- proteins }, hunger as the engine keeps it); full is the portions of the whole item, for vanilla's eat shares.
function Portions.set(food, p, portions, full)
    food:setHungChange(p.hunger * portions)
    food:setBaseHunger(p.hunger * (full or portions))
    food:setCalories(p.calories * portions)
    food:setCarbohydrates(p.carbohydrates * portions)
    food:setLipids(p.lipids * portions)
    food:setProteins(p.proteins * portions)
end

-- Portions left in a food item, from the hunger it still holds and one portion's. Vanilla's Eat Half and Eat
-- Quarter may leave a part.
function Portions.left(hunger, portionHunger)
    return hunger / portionHunger
end

-- Portions as text: whole numbers plain, a part-portion to one place.
function Portions.text(left)
    local rounded = math.floor(left * 10 + 0.5) / 10
    if rounded == math.floor(rounded) then return tostring(math.floor(rounded)) end
    return string.format("%.1f", rounded)
end

-- "Jar of Yogurt (3 portions)": the vessel's name with what is left in it. By the text: the engine keeps hunger as
-- a 32-bit float, so one portion reads 1.00000001.
function Portions.name(baseName, left)
    local text = Portions.text(left)
    return getText(KEY .. (text == "1" and "OnePortion" or "Portions"), baseName, text)
end

-- Weighs the item: the empty vessel (a full type) plus what is left in it. The engine saves only a custom weight;
-- without one a reloaded item weighs a full one again.
function Portions.weigh(item, left, vesselType, portionWeight)
    local empty = ScriptManager.instance:getItem(vesselType)
    item:setActualWeight((empty and empty:getActualWeight() or 0) + left * portionWeight)
    item:setCustomWeight(true)
end

-- Names the item by its portions and weighs it (Portions.weigh).
function Portions.label(item, baseName, left, vesselType, portionWeight)
    item:setName(Portions.name(baseName, left))
    item:setCustomName(true)
    Portions.weigh(item, left, vesselType, portionWeight)
end

-- After any eat or spoonful: one with enough left (stillHolds(item), asked only while it is still in the container
-- it was in) is relabelled; an emptied one goes back to that container as its empty vessel (a full type). Returns
-- the empty vessel, if any.
function Portions.used(item, container, stillHolds, vesselType, relabel)
    if container and container:contains(item) and stillHolds(item) then
        relabel(item)
        return nil
    end
    if container and container:contains(item) then container:DoRemoveItem(item) end
    local target = container or item:getContainer()
    return target and target:AddItem(vesselType)
end

-- The eat action. before(item) runs while the item is as it was and may return something for after(item, container,
-- kept), which runs once vanilla has eaten; container is the one the item was in. complete eats what was asked;
-- serverStop eats the part done when the action is cut short.
local handlers = {}
local installed = false

local function wrap(name)
    local vanilla = ISEatFoodAction[name]
    ISEatFoodAction[name] = function(self, ...)
        local item = self.item
        local handler = item and handlers[item:getFullType()]
        if not handler then return vanilla(self, ...) end
        local container = item:getContainer()
        local kept = handler.before and handler.before(item)
        local result = vanilla(self, ...)
        handler.after(item, container, kept)
        return result
    end
end

-- Wraps ISEatFoodAction.complete and serverStop, once for every mod: compare them with vanilla after a game update.
-- Outside the game (tests) there is no eat action unless one is stubbed.
local function install()
    if installed then return end
    if not ISEatFoodAction then pcall(require, "TimedActions/ISEatFoodAction") end
    if not ISEatFoodAction then return end
    installed = true
    wrap("complete")
    wrap("serverStop")
end

-- Handlers for items of fullType eaten through vanilla's eat action.
function Portions.onEat(fullType, before, after)
    install()
    handlers[fullType] = { before = before, after = after }
end

return Portions
