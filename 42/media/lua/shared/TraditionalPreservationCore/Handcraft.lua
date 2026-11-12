-- Traditional Preservation core: the one wrap of vanilla's ISHandcraftAction.performRecipe, which runs a hand
-- craft. Vanilla deletes what a craft uses up, so a mod that gives something back for it (Salt's empty shaker and
-- paper bag, Vinegar's bottle) adds a handler here instead of wrapping it again: one place to compare with vanilla
-- after a game update.
--   Handcraft.around(before, after)  before(action) runs first and may return something to keep; after(action,
--                                    recipeData, kept) runs once vanilla has crafted, for a craft with recipe data
--   Handcraft.after(after)           the same with nothing to keep
-- Handlers run as nested wraps would: the last one added is outermost, so its before runs first and its after last.
-- Outside the game (tests) there may be no hand craft action: then nothing is wrapped.
local Handcraft = {}

local handlers = {}
local installed = false

local function install()
    if installed then return end
    if not ISHandcraftAction then pcall(require, "Entity/TimedActions/ISHandcraftAction") end
    if not ISHandcraftAction then return end
    installed = true
    local vanillaPerformRecipe = ISHandcraftAction.performRecipe
    function ISHandcraftAction:performRecipe()
        local kept = {}
        for index = #handlers, 1, -1 do
            local before = handlers[index].before
            if before then kept[index] = before(self) end
        end
        local result = vanillaPerformRecipe(self)
        local recipeData = self.logic and self.logic:getRecipeData()
        if recipeData then
            for index, handler in ipairs(handlers) do handler.after(self, recipeData, kept[index]) end
        end
        return result
    end
end

function Handcraft.around(before, after)
    install()
    table.insert(handlers, { before = before, after = after })
end

function Handcraft.after(after)
    Handcraft.around(nil, after)
end

return Handcraft
