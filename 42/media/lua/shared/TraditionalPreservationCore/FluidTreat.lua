-- Traditional Preservation core: treating a kind's fluid by hand (FluidAgeing's treatments: Fish & Meat's Cure
-- Blood). One use of the treatment's tag for each litresPerUse litres of the kind's fluid that isn't spoiled, taken
-- from what the character carries (Uses). The treat menu is FluidTreatUI's, the action TPFluidTreat.
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Uses = require "TraditionalPreservationCore/Uses"

local FluidTreat = {}

-- Litres of uses are rounded up, but not past a whole one by float error.
local ROUNDING = 1e-6

-- The litres of the kind's fluid in a container that isn't spoiled, and that is.
function FluidTreat.litresIn(container, fluidKind)
    local usable, spoiled = 0, 0
    for name, amount in pairs((FluidAgeing.amounts(container, fluidKind))) do
        if fluidKind.isSpoiled[name] then spoiled = spoiled + amount else usable = usable + amount end
    end
    return usable, spoiled
end

function FluidTreat.treatUses(fluidKind, litres)
    return math.max(1, math.ceil(litres / (fluidKind.litresPerUse or 1) - ROUNDING))
end

-- The kind with treatments whose fluid an owner holds (spoiled or not), or nil.
function FluidTreat.treatableFluidKind(owner)
    local fluidKind = FluidAgeing.fluidKindIn(owner and owner:getFluidContainer())
    return fluidKind and fluidKind.treatments and fluidKind or nil
end

-- Why a fluid can't be treated now, as translation keys (FluidTreat.treatRefusal).
FluidTreat.REFUSALS = {
    treatSpoiled = "IGUI_TraditionalPreservationCore_TreatSpoiled",
    treatNoFluid = "IGUI_TraditionalPreservationCore_TreatNoFluid",
    treatDone = "IGUI_TraditionalPreservationCore_TreatDone",
    treatShort = "IGUI_TraditionalPreservationCore_TreatShort",
}

-- treatRefusal's work, also giving the usable litres it read.
local function refusal(owner, fluidKind, treatment, character, now)
    local usable, spoiled = FluidTreat.litresIn(owner:getFluidContainer(), fluidKind)
    if usable <= 0 then
        return spoiled > 0 and FluidTreat.REFUSALS.treatSpoiled or FluidTreat.REFUSALS.treatNoFluid, usable
    end
    local fluidAge = FluidAgeing.look(owner, now or getGameTime():getWorldAgeHours())
    if fluidAge and FluidAgeing.stage(fluidAge, fluidKind) ~= "Fresh" then return FluidTreat.REFUSALS.treatSpoiled, usable end
    if fluidAge and fluidAge.treated and fluidAge.treated[treatment.name] then return FluidTreat.REFUSALS.treatDone, usable end
    if character and Uses.count(character, treatment.tag()) < FluidTreat.treatUses(fluidKind, usable) then
        return FluidTreat.REFUSALS.treatShort, usable
    end
    return nil, usable
end

-- Why an owner's fluid can't take a treatment now (an IGUI key, its text taking the litres and the uses), or nil
-- when it can: none of the kind's fluid, spoiled, done already, or not enough carried (character optional).
function FluidTreat.treatRefusal(owner, fluidKind, treatment, character, now)
    return (refusal(owner, fluidKind, treatment, character, now))
end

-- Treats an owner's fluid and takes the uses from the character. Returns true if it took.
function FluidTreat.treatBy(owner, fluidKind, treatment, character, now)
    now = now or getGameTime():getWorldAgeHours()
    local refused, usable = refusal(owner, fluidKind, treatment, character, now)
    if refused then return false end
    local uses = FluidTreat.treatUses(fluidKind, usable)
    if not FluidAgeing.treat(owner, now, treatment.name) then return false end
    Uses.take(character, treatment.tag(), uses)
    owner:sendSyncEntity(nil)
    return true
end

return FluidTreat
