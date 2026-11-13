-- Traditional Preservation core: the copper, the Hearth's first attachment, registered with Hearth.attach as any
-- mod's would be. In game it is the Forged Cauldron (user, 2026-11-13: forged iron; copper is kept for Dairy's cheese
-- vat); the code and the save keep the copper's name. Fit Cauldron hangs it from two metal pipes set in the stone and
-- a heavy chain on a large hook; Remove gives them all back. The cauldron is forged as the forged pot is, learned from
-- the same magazine or researched from the cauldron itself. Its fluid rules stay in Hearth.lua (pourInto, take, advance, the hooks), so mods that use them
-- (Fish & Meat's fat, Dairy's milk) reach it as before. Its menu and Info rows are CopperUI's, its simmer HearthWorld's.
local Hearth = require "TraditionalPreservationCore/Hearth"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Weather = require "TraditionalPreservationCore/Weather"
local Recipes = require "TraditionalPreservationCore/Recipes"

Hearth.CAULDRON = "TraditionalPreservationCore.ForgedCauldron"
Hearth.CAULDRON_RECIPE = "TraditionalPreservationCore.Forge_TPCauldron"

local Copper = Hearth.attach({
    id = Hearth.COPPER,
    name = "IGUI_TraditionalPreservationCore_InfoCopper",
    fitHelp = "IGUI_TraditionalPreservationCore_FitCauldronHelp",
    -- About an hour's work: the pipes set in the stone, the chain hung, the cauldron on the hook.
    fit = {
        items = { { Hearth.CAULDRON, 1 }, { "Base.MetalPipe", 2 }, { "Base.HeavyChain", 1 }, { "Base.LargeHook", 1 } },
        tool = "PLIERS",
        ticks = 600,
        removeTicks = 300,
        xp = { "Blacksmith", 5 },
    },
    -- Off only empty: its fluid would be lost.
    canRemove = function(copper)
        if (copper.ml or 0) > 0 then return false, "Full" end
        return true
    end,
    look = function(copper) return Hearth.look(copper) end,
    -- Heated as the fire was until now, cooled to the air after; its fluid aged where the Hearth stands.
    heats = function(copper, fire, now, fireState, airC)
        copper.fireUntil, copper.banked = fireState.fireUntil, fireState.banked
        Hearth.advance(copper, now, airC)
        FluidAgeing.updateCopper(copper, now, Weather.placeOf(fire), Hearth.heldHours(copper))
    end,
})

Events.OnInitGlobalModData.Add(function()
    Recipes.teach("Base.SmithingMag2", Hearth.CAULDRON_RECIPE, "TP")
    Recipes.researchable(Hearth.CAULDRON, Hearth.CAULDRON_RECIPE)
end)

return Copper
