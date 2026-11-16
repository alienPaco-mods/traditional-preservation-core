-- Traditional Preservation core: puts a mod's item into vanilla's loot lists. Each list is one a room rolls
-- (ProceduralDistributions.lua, named by Distributions.lua); its items run name, weight, name, weight. A list the
-- game doesn't have is skipped, so a renamed list costs only that list. Each mod keeps its own item and weights in its
-- server/<Mod>Loot.lua, with the reasons for the numbers.
require "Items/ProceduralDistributions"

local Loot = {}

-- Adds `fullType` to each list in `weights` ({ listName = weight }) at that weight.
function Loot.add(fullType, weights)
    for distributionName, weight in pairs(weights) do
        local distribution = ProceduralDistributions.list[distributionName]
        if distribution and distribution.items then
            table.insert(distribution.items, fullType)
            table.insert(distribution.items, weight)
        end
    end
end

return Loot
