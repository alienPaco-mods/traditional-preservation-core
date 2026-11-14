-- Traditional Preservation core: treating a kind's fluid by hand (FluidAgeing's treatments: Fish & Meat's Cure
-- Blood). One use of the treatment's tag for each litresPerUse litres of the kind's fluid that isn't spoiled, taken
-- from what the character carries (Uses). The treat menu is FluidAgeingUI's, the action TPFluidTreat.
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Uses = require "TraditionalPreservationCore/Uses"

local FluidTreat = {}

-- Litres of uses are rounded up, but not past a whole one by float error.
local ROUNDING = 1e-6

-- The litres of the kind's fluid in a container that isn't spoiled, and that is.
function FluidTreat.litresIn(container, spec)
    local usable, spoiled = 0, 0
    for name, amount in pairs((FluidAgeing.amounts(container, spec))) do
        if spec.isSpoiled[name] then spoiled = spoiled + amount else usable = usable + amount end
    end
    return usable, spoiled
end

function FluidTreat.treatUses(spec, litres)
    return math.max(1, math.ceil(litres / (spec.litresPerUse or 1) - ROUNDING))
end

-- The kind with treatments whose fluid an owner holds (spoiled or not), or nil.
function FluidTreat.treatableSpec(owner)
    local spec = FluidAgeing.specIn(owner and owner:getFluidContainer())
    return spec and spec.treatments and spec or nil
end

-- treatRefusal's work, also giving the usable litres it read.
local function refusal(owner, spec, treatment, character, now)
    local usable, spoiled = FluidTreat.litresIn(owner:getFluidContainer(), spec)
    if usable <= 0 then
        return spoiled > 0 and "IGUI_TraditionalPreservationCore_TreatSpoiled" or "IGUI_TraditionalPreservationCore_TreatNoFluid", usable
    end
    local record = FluidAgeing.look(owner, now or getGameTime():getWorldAgeHours())
    if record and FluidAgeing.stage(record, spec) ~= "Fresh" then return "IGUI_TraditionalPreservationCore_TreatSpoiled", usable end
    if record and record.treated and record.treated[treatment.name] then return "IGUI_TraditionalPreservationCore_TreatDone", usable end
    if character and Uses.count(character, treatment.tag()) < FluidTreat.treatUses(spec, usable) then
        return "IGUI_TraditionalPreservationCore_TreatShort", usable
    end
    return nil, usable
end

-- Why an owner's fluid can't take a treatment now (an IGUI key, its text taking the litres and the uses), or nil
-- when it can: none of the kind's fluid, spoiled, done already, or not enough carried (character optional).
function FluidTreat.treatRefusal(owner, spec, treatment, character, now)
    return (refusal(owner, spec, treatment, character, now))
end

-- Treats an owner's fluid and takes the uses from the character. Returns true if it took.
function FluidTreat.treatBy(owner, spec, treatment, character, now)
    now = now or getGameTime():getWorldAgeHours()
    local refused, usable = refusal(owner, spec, treatment, character, now)
    if refused then return false end
    local uses = FluidTreat.treatUses(spec, usable)
    if not FluidAgeing.treat(owner, now, treatment.name) then return false end
    Uses.take(character, treatment.tag(), uses)
    if owner.sendSyncEntity then owner:sendSyncEntity(nil) end
    return true
end

return FluidTreat
