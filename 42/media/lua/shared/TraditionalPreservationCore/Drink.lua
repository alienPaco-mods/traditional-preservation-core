-- Traditional Preservation core: fluids that ease food sickness when drunk (Dairy's kefir). A fluid script's
-- foodSicknessChange never reaches the drinker (the engine leaves it out of what a drink carries: ENGINE_NOTES "Food
-- sickness"), so a mod registers the fluid here and the one wrap of vanilla's drink action
-- (ISDrinkFluidAction.updateEat, called a little at a time as the drink goes down) measures the litres of it drunk
-- and takes foodSickness per litre off the drinker, as vanilla's food does only while the drinker has food sickness:
-- a healthy drink does nothing and starts nothing. With a cooldown (a Core Cooldown key and its hours), a drink cures
-- only if the key has run out at its first sick step, and then the rest of it counts; it starts the key.
-- Auto-drink (thirst) takes only containers of Water-category fluid, so a registered Beverage is never drunk past this.
--   Drink.cure(fluidName, { foodSickness = per litre, cooldown = key, hours = h })
-- Wrapped through Wrap (late, guarded).
local Cooldown = require "TraditionalPreservationCore/Cooldown"
require "TimedActions/ISDrinkFluidAction"
local Wrap = require "TraditionalPreservationCore/Wrap"

local Drink = {}

local cures = {}
local fluids = {}
local installed = false

-- The litres of each registered fluid in a fluid container ({ name = litres }), and whether it holds any.
function Drink.amounts(container)
    local found, any = {}, false
    for name in pairs(cures) do
        fluids[name] = fluids[name] or Fluid.Get(name)
        local amount = fluids[name] and container:getSpecificFluidAmount(fluids[name]) or 0
        if amount > 0 then found[name], any = amount, true end
    end
    return found, any
end

-- The food sickness one step of a drink takes off: before and after are Drink.amounts either side of it, sick
-- whether the drinker has any. A cure with a cooldown asks ready(key) once a drink (kept in `opened`, the action's own
-- table) and, if it was, calls start(key, hours) and counts the rest of that drink.
function Drink.eased(before, after, opened, ready, start, sick)
    if not sick then return 0 end
    local total = 0
    for name, had in pairs(before) do
        local litres = had - (after[name] or 0)
        local cure = cures[name]
        if litres > 0 and cure then
            local key = cure.cooldown
            if key and opened[key] == nil then
                opened[key] = ready(key)
                if opened[key] then start(key, cure.hours) end
            end
            if not key or opened[key] then total = total + litres * cure.foodSickness end
        end
    end
    return total
end

local function wrap()
    Wrap.method("ISDrinkFluidAction", "updateEat", function(vanilla, self, ...)
        local container = self.fluidContainer
        local before, any
        if container then before, any = Drink.amounts(container) end
        local vanillaReturn = vanilla(self, ...)
        if any then
            local player = self.character
            local stats = player:getStats()
            self.tpDrinkOpened = self.tpDrinkOpened or {}
            local eased = Drink.eased(before, Drink.amounts(container), self.tpDrinkOpened,
                function(key) return Cooldown.ready(player, key) end,
                function(key, hours) Cooldown.start(player, key, hours) end,
                stats:isAboveMinimum(CharacterStat.FOOD_SICKNESS))
            if eased > 0 then stats:remove(CharacterStat.FOOD_SICKNESS, eased) end
        end
        return vanillaReturn
    end)
end

-- Wraps ISDrinkFluidAction.updateEat, once for every mod: compare it with vanilla after a game update.
local function install()
    if installed then return end
    installed = true
    wrap()
end

-- Registers a fluid (by name) that eases food sickness when drunk: cure.foodSickness per litre, and optionally
-- cure.cooldown (a Cooldown key) with cure.hours.
function Drink.cure(name, cure)
    assert(type(cure.foodSickness) == "number" and cure.foodSickness > 0, "Drink.cure " .. tostring(name) .. ": no foodSickness")
    assert(not cure.cooldown or (type(cure.hours) == "number" and cure.hours > 0), "Drink.cure " .. tostring(name) .. ": a cooldown needs hours")
    assert(not cures[name], "Drink.cure: " .. tostring(name) .. " is already registered")
    install()
    cures[name] = { foodSickness = cure.foodSickness, cooldown = cure.cooldown, hours = cure.hours }
end

return Drink
