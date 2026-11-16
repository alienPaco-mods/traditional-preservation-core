-- Checks Loot (a mod's item into vanilla's loot lists) outside the game.
-- Run from TraditionalPreservationCore: luajit tests/test_loot.lua
local H = dofile("tests/harness.lua")
local check = H.check
H.useModPaths()

ProceduralDistributions = { list = {
    KitchenDryFood = { items = { "Salt", 20 } },
    CrateFarming = { items = {} },
    Untouched = { items = { "Salt", 1 } },
    NoItems = {},
} }
local Loot = require "TraditionalPreservationCore/Loot"

local function weightsOf(listName, fullType)
    local items, weights = ProceduralDistributions.list[listName].items, {}
    for i = 1, #items, 2 do
        if items[i] == fullType then table.insert(weights, items[i + 1]) end
    end
    return weights
end

Loot.add("Mod.Thing", { KitchenDryFood = 0.5, CrateFarming = 1, Missing = 2, NoItems = 3 })
check("added once to each list, at its weight", #weightsOf("KitchenDryFood", "Mod.Thing") == 1
    and weightsOf("KitchenDryFood", "Mod.Thing")[1] == 0.5 and weightsOf("CrateFarming", "Mod.Thing")[1] == 1)
check("vanilla entries kept, the item after them", ProceduralDistributions.list.KitchenDryFood.items[1] == "Salt"
    and ProceduralDistributions.list.KitchenDryFood.items[2] == 20 and ProceduralDistributions.list.KitchenDryFood.items[3] == "Mod.Thing")
check("lists not named are left alone", #ProceduralDistributions.list.Untouched.items == 2)
check("a list the game doesn't have, or one without items, is skipped",
    ProceduralDistributions.list.Missing == nil and ProceduralDistributions.list.NoItems.items == nil)
H.done()
