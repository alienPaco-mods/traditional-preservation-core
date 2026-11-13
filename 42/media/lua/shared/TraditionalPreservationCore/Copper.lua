-- Traditional Preservation core: the copper, the Hearth's first attachment, registered with Hearth.attach as any
-- mod's would be. Its fluid rules stay in Hearth.lua (pourInto, take, advance, the hooks), so mods that use them
-- (Fish & Meat's fat, Dairy's milk) reach it as before. Its menu and Info rows are CopperUI's, its simmer HearthWorld's.
local Hearth = require "TraditionalPreservationCore/Hearth"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Weather = require "TraditionalPreservationCore/Weather"

local Copper = Hearth.attach({
    id = Hearth.COPPER,
    name = "IGUI_TraditionalPreservationCore_InfoCopper",
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

return Copper
