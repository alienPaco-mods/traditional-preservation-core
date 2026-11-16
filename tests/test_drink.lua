-- Checks Cooldown (timers kept on a player) and Drink (fluids that ease food sickness, through the one wrap of
-- vanilla's drink action), on stand-ins for the engine. Run from TraditionalPreservationCore:
-- luajit tests/test_drink.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near
package.path = "42/media/lua/shared/?.lua;" .. package.path
H.preloadVanilla()
H.installClock(100)

-- Cooldown
local Cooldown = require "TraditionalPreservationCore/Cooldown"
local function newPlayer(healthy)
    local data, removed = {}, {}
    return {
        getModData = function() return data end,
        getStats = function() return {
            remove = function(_, stat, amount) table.insert(removed, { stat, amount }) end,
            isAboveMinimum = function(_, stat) return stat == "FOOD_SICKNESS" and not healthy end,
        } end,
        data = data, removed = removed,
    }
end
local player = newPlayer()
check("a key never started is ready, with nothing left, and writes nothing",
    Cooldown.ready(player, "foodSickness") and Cooldown.left(player, "foodSickness") == 0 and player.data[Cooldown.KEY] == nil)
Cooldown.start(player, "foodSickness", 3)
check("started, it is not ready and has its hours left", not Cooldown.ready(player, "foodSickness")
    and near(Cooldown.left(player, "foodSickness"), 3))
check("it is kept in the player's modData as the hour it runs out", player.data[Cooldown.KEY].foodSickness == 103)
check("another key is apart from it", Cooldown.ready(player, "tpy:other"))
H.setHours(102)
check("an hour before the end, an hour left", near(Cooldown.left(player, "foodSickness"), 1) and not Cooldown.ready(player, "foodSickness"))
H.setHours(103)
check("at its end it is ready", Cooldown.ready(player, "foodSickness") and Cooldown.left(player, "foodSickness") == 0)
H.setHours(110)
check("long after, nothing left (never negative)", Cooldown.left(player, "foodSickness") == 0)
check("the plain-table forms agree", Cooldown.leftIn({ k = 5 }, "k", 4) == 1 and Cooldown.leftIn(nil, "k", 4) == 0)

-- Drink
CharacterStat = { FOOD_SICKNESS = "FOOD_SICKNESS" }
Fluid = { Get = function(name) return { name = name } end }
local calls = 0
ISDrinkFluidAction = {}
-- Vanilla drinks a share of what is left each step; the stand-in takes `step` litres of each fluid.
function ISDrinkFluidAction:updateEat(delta)
    calls = calls + 1
    for name, litres in pairs(self.fluidContainer.fluids) do
        self.fluidContainer.fluids[name] = math.max(litres - self.step, 0)
    end
    return "drank"
end
local Drink = require "TraditionalPreservationCore/Drink"
check("vanilla is left alone until a fluid is registered", ISDrinkFluidAction.updateEat ~= nil and calls == 0)
Drink.cure("CowKefir", { foodSickness = 10, cooldown = "foodSickness", hours = 3 })
Drink.cure("PlainCure", { foodSickness = 4 })
check("a cure needs its foodSickness", not pcall(Drink.cure, "X", {}))
check("a cooldown needs its hours", not pcall(Drink.cure, "Y", { foodSickness = 1, cooldown = "k" }))
check("a fluid is registered once", not pcall(Drink.cure, "PlainCure", { foodSickness = 1 }))

local function container(fluids)
    return { fluids = fluids, getSpecificFluidAmount = function(self, fluid) return self.fluids[fluid.name] or 0 end }
end
local function drink(who, fluids, step, steps)
    local action = setmetatable({ character = who, fluidContainer = container(fluids), step = step }, { __index = ISDrinkFluidAction })
    local result
    for _ = 1, steps do result = action:updateEat(1) end
    return action, result
end
local function eased(who)
    local total = 0
    for _, entry in ipairs(who.removed) do
        assert(entry[1] == "FOOD_SICKNESS")
        total = total + entry[2]
    end
    return total
end

H.setHours(200)
player = newPlayer()
local _, result = drink(player, { CowKefir = 1.0 }, 0.25, 2)
check("vanilla's result is passed back", result == "drank")
check("half a litre of kefir in two steps eases 5, per litre", near(eased(player), 5))
check("the drink started the shared cooldown for its hours", near(Cooldown.left(player, "foodSickness"), 3))
drink(player, { CowKefir = 1.0 }, 0.5, 1)
check("another drink inside the cooldown eases nothing", near(eased(player), 5))
H.setHours(203.5)
drink(player, { CowKefir = 1.0 }, 0.1, 1)
check("once it has run out the next drink eases again", near(eased(player), 6))

player = newPlayer()
Cooldown.start(player, "foodSickness", 1)
drink(player, { PlainCure = 1.0 }, 0.5, 2)
check("a cure with no cooldown eases every litre, the cooldown or not", near(eased(player), 4))
check("and starts no cooldown of its own", near(Cooldown.left(player, "foodSickness"), 1))

player = newPlayer()
drink(player, { CowKefir = 0.5, Water = 0.5 }, 0.25, 1)
check("in a mix only the registered fluid counts", near(eased(player), 2.5))
player = newPlayer()
drink(player, { Water = 1.0 }, 0.5, 1)
check("water alone eases nothing and starts nothing", #player.removed == 0 and player.data[Cooldown.KEY] == nil)

player = newPlayer(true)
drink(player, { CowKefir = 1.0 }, 0.5, 1)
check("a healthy drinker is eased of nothing and starts no cooldown, as vanilla's food",
    #player.removed == 0 and Cooldown.ready(player, "foodSickness"))

local opened = {}
local asked = 0
local function ready() asked = asked + 1 return false end
check("a drink that opened shut stays shut and asks once",
    Drink.eased({ CowKefir = 1 }, { CowKefir = 0.5 }, opened, ready, function() end, true) == 0
    and Drink.eased({ CowKefir = 0.5 }, { CowKefir = 0 }, opened, ready, function() end, true) == 0 and asked == 1)

H.done()
