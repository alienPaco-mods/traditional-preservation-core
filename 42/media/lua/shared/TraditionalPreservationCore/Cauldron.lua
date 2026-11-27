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

-- Its attachment id: the cauldron's state is under it in the fire's (Fire.partModData). Inside: ml, fluid, parts, tempC,
-- last, boiled, hot, held, offAt (CauldronFluid's).
Cauldron.ID = StoneHearth.CAULDRON
Cauldron.ITEM = "TraditionalPreservationCore.ForgedCauldron"
Cauldron.RECIPE = "TraditionalPreservationCore.Forge_TPCauldron"

function Cauldron.cauldronModData(modData)
    return Fire.partModData(modData, Cauldron.ID)
end

-- The cauldron's state, brought up to now where the World runs (Fire.fireModDataNow).
function Cauldron.of(fire)
    Fire.fireModDataNow(fire)
    return Cauldron.cauldronModData(fire:getModData())
end

Cauldron.CROSSBARS = { "Base.MetalPipe", "Base.MetalBar", "Base.SteelBar", "Base.IronBar" }

Cauldron.attachment = Fire.attach({
    id = Cauldron.ID,
    name = "IGUI_TraditionalPreservationCore_InfoCauldron",
    fitHelp = "IGUI_TraditionalPreservationCore_FitCauldronHelp",
    -- About an hour's work: two crossbars set in the stone, the chain hung, the cauldron on the hook. A crossbar is
    -- any full-length iron or steel bar or pipe (user, 2026-11-27): an Iron Pipe, Steel Rod, Steel Bar or Iron Bar,
    -- mixed as they come; not a Lead Pipe (soft, it melts near 330 C) nor a half or quarter bar (too short to span).
    fit = {
        items = { { Cauldron.ITEM, 1 }, { Cauldron.CROSSBARS, 2 }, { "Base.HeavyChain", 1 }, { "Base.LargeHook", 1 } },
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
    heats = function(cauldron, fire, now, fireModData, airC, place)
        CauldronFluid.advance(cauldron, now, airC, fireModData)
        FluidAgeing.updateCauldron(cauldron, now, place, CauldronFluid.heldHours(cauldron))
    end,
})

-- Where TPPutPieces puts pieces (fat, butter) into a fire's cauldron, as many as fit, as a fluid.
function Cauldron.piecesInto(fire)
    return {
        station = fire,
        here = function() return fire:getSquare() ~= nil end,
        room = function(asFluid) return CauldronFluid.pieceRoom(Cauldron.cauldronModData(fire:getModData()), asFluid.fluid, asFluid.pieceMl) end,
        -- Brought up to the minute first, so the pieces mix with the cauldron as it is now.
        put = function(asFluid, hoursLeft, now)
            return CauldronFluid.putPieces(Cauldron.of(fire), asFluid.fluid, asFluid.pieceMl, hoursLeft, now)
        end,
        after = function() Fire.redraw(fire) end,
    }
end

Events.OnInitGlobalModData.Add(function()
    Recipes.teach("Base.SmithingMag2", Cauldron.RECIPE, "TP")
    Recipes.researchable(Cauldron.ITEM, Cauldron.RECIPE, "TP")
end)

return Cauldron
