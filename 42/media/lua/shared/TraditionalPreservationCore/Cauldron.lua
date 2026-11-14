-- Traditional Preservation core: the cauldron, the Hearth's first attachment, registered with Hearth.attach as any
-- mod's would be: the Forged Cauldron (user, 2026-11-13: forged iron; copper is kept for Dairy's cheese vat). Fit
-- Cauldron hangs it from two metal pipes set in the stone and a heavy chain on a large hook; Remove gives them all
-- back. The cauldron is forged as the forged pot is, learned from the same magazine or researched from the cauldron
-- itself. Its fluid rules are CauldronFluid's (pourInto, take, advance, the hooks), reached through Hearth, so mods that
-- use them (Fish & Meat's fat, Dairy's milk) name Hearth only. Its menu and Info rows are CauldronUI's, its simmer HearthWorld's.
local Hearth = require "TraditionalPreservationCore/Hearth"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Weather = require "TraditionalPreservationCore/Weather"
local Recipes = require "TraditionalPreservationCore/Recipes"

Hearth.CAULDRON_ITEM = "TraditionalPreservationCore.ForgedCauldron"
Hearth.CAULDRON_RECIPE = "TraditionalPreservationCore.Forge_TPCauldron"

local Cauldron = Hearth.attach({
    id = Hearth.CAULDRON,
    name = "IGUI_TraditionalPreservationCore_InfoCauldron",
    fitHelp = "IGUI_TraditionalPreservationCore_FitCauldronHelp",
    -- About an hour's work: the pipes set in the stone, the chain hung, the cauldron on the hook.
    fit = {
        items = { { Hearth.CAULDRON_ITEM, 1 }, { "Base.MetalPipe", 2 }, { "Base.HeavyChain", 1 }, { "Base.LargeHook", 1 } },
        tool = "PLIERS",
        ticks = 600,
        removeTicks = 300,
        xp = { "Blacksmith", 5 },
    },
    -- Off only empty: its fluid would be lost.
    canRemove = function(cauldron)
        if (cauldron.ml or 0) > 0 then return false, "Full" end
        return true
    end,
    look = function(cauldron) return Hearth.look(cauldron) end,
    -- Heated as the fire was until now, cooled to the air after; its fluid aged where the Hearth stands.
    heats = function(cauldron, fire, now, fireState, airC)
        Hearth.advance(cauldron, now, airC, fireState)
        FluidAgeing.updateCauldron(cauldron, now, Weather.placeOf(fire), Hearth.heldHours(cauldron))
    end,
})

Events.OnInitGlobalModData.Add(function()
    Recipes.teach("Base.SmithingMag2", Hearth.CAULDRON_RECIPE, "TP")
    Recipes.researchable(Hearth.CAULDRON_ITEM, Hearth.CAULDRON_RECIPE)
end)

return Cauldron
