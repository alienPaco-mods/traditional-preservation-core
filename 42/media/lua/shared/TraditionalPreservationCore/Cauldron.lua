-- Traditional Preservation core: the cauldron, the Stone Hearth's first attachment, registered with Fire.attach as any
-- mod's would be: the Forged Cauldron (forged iron; copper is kept for Dairy's cheese vat). Fit Cauldron hangs it from
-- two metal pipes set in the stone and a heavy chain on a large hook; Remove gives them all back. The cauldron is
-- forged as the forged pot is, learned from the same magazine or researched from the cauldron itself. Cauldron is the
-- name for the cauldron as an attachment (ID, its state, Cauldron.of); its fluid rules (pourInto, take, advance, the
-- hooks) are CauldronFluid's, by that name. Its tiles are the Stone Hearth's (StoneHearth.cauldronSprite), its menu and
-- Info rows CauldronUI's, its simmer FireWorld's.
local Fire = require "TraditionalPreservationCore/Fire"
local StoneHearth = require "TraditionalPreservationCore/StoneHearth"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Recipes = require "TraditionalPreservationCore/Recipes"

local Cauldron = {}

-- Its attachment id: the cauldron's state is under it in the fire's (Fire.partState). Inside: ml, fluid, parts, tempC,
-- last, boiled, hot, held, offAt (CauldronFluid's).
Cauldron.ID = StoneHearth.CAULDRON
Cauldron.ITEM = "TraditionalPreservationCore.ForgedCauldron"
Cauldron.RECIPE = "TraditionalPreservationCore.Forge_TPCauldron"

function Cauldron.state(modData)
    return Fire.partState(modData, Cauldron.ID)
end

-- The cauldron's state, brought up to now where the World runs (Fire.fireStateOf).
function Cauldron.of(fire)
    Fire.fireStateOf(fire)
    return Cauldron.state(fire:getModData())
end

Cauldron.spec = Fire.attach({
    id = Cauldron.ID,
    name = "IGUI_TraditionalPreservationCore_InfoCauldron",
    fitHelp = "IGUI_TraditionalPreservationCore_FitCauldronHelp",
    -- About an hour's work: the pipes set in the stone, the chain hung, the cauldron on the hook.
    fit = {
        items = { { Cauldron.ITEM, 1 }, { "Base.MetalPipe", 2 }, { "Base.HeavyChain", 1 }, { "Base.LargeHook", 1 } },
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
    look = CauldronFluid.look,
    sprite = StoneHearth.cauldronSprite,
    overlay = StoneHearth.liquidOverlay,
    -- Heated as the fire was until now, cooled to the air after; its fluid aged where the Stone Hearth stands.
    heats = function(cauldron, fire, now, fireState, airC, place)
        CauldronFluid.advance(cauldron, now, airC, fireState)
        FluidAgeing.updateCauldron(cauldron, now, place, CauldronFluid.heldHours(cauldron))
    end,
})

Events.OnInitGlobalModData.Add(function()
    Recipes.teach("Base.SmithingMag2", Cauldron.RECIPE, "TP")
    Recipes.researchable(Cauldron.ITEM, Cauldron.RECIPE, "TP")
end)

return Cauldron
