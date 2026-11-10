-- Traditional Preservation core: a loot window brings the fluids in the containers it shows up to date (FluidAgeing), so
-- milk left in a fridge or a cupboard has turned by the time anyone looks at it.
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"

Events.OnRefreshInventoryWindowContainers.Add(function(page, reason)
    if reason ~= "end" or page.onCharacter then return end
    local now = getGameTime():getWorldAgeHours()
    for _, button in ipairs(page.backpacks or {}) do FluidAgeing.lookIn(button.inventory, now) end
end)
