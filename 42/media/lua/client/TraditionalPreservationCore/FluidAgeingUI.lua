-- Traditional Preservation core: a loot window brings the fluids in the containers it shows up to date (FluidAgeing), so
-- milk left in a fridge or a cupboard has turned by the time anyone looks at it. An item is looked at as it is moved,
-- while it is still where it was: taken off a stove, its heat is still the stove's, so hot milk scalds.
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Transfer = require "TraditionalPreservationCore/Transfer"

Events.OnRefreshInventoryWindowContainers.Add(function(page, reason)
    if reason ~= "end" or page.onCharacter then return end
    local now = getGameTime():getWorldAgeHours()
    for _, button in ipairs(page.backpacks or {}) do FluidAgeing.lookIn(button.inventory, now) end
end)

Transfer.before(function(_, item)
    if item:getFluidContainer() then FluidAgeing.look(item, getGameTime():getWorldAgeHours()) end
end)
