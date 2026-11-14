-- Traditional Preservation core: the Smokehouse's flue is a Hearth connection, so Connect the Stone Hearth and
-- Disconnect the Stone Hearth are Core's (HearthUI.addConnect / addDisconnect, in the fire's own menu); the chamber's
-- right-click offers them too. The shed doesn't pick up while joined (the fire is Core's rule), and the fire's Info
-- says where its flue goes.
local UI = require "TraditionalPreservationCore/UI"
local HearthUI = require "TraditionalPreservationCore/HearthUI"
local Hearth = require "TraditionalPreservationCore/Hearth"
local Smokehouse = require "TraditionalPreservationCore/Smokehouse"
local Tiles = require "TraditionalPreservationCore/Tiles"

Hearth.connect({
    id = Smokehouse.ID,
    notes = function(_, notes, part)
        local kit = part and Smokehouse.FLUE_KITS[part.kind]
        if kit then table.insert(notes, UI.say("IGUI_TraditionalPreservationCore_FlueJoined", getText(kit.name))) end
    end,
})

-- The chamber's right-click: the joined Stone Hearth's Disconnect, or Connect for the first Stone Hearth beside it.
local function onFillChamberMenu(playerNum, context, worldobjects, test)
    for _, object in ipairs(worldobjects) do
        if Smokehouse.isChamber(object) then
            if test then return end
            if Smokehouse.World then Smokehouse.World.track(object) end
            local playerObj = getSpecificPlayer(playerNum)
            local spec = Hearth.connection(Smokehouse.ID)
            local firebox, joined = Smokehouse.joinedFirebox(object)
            if firebox then return HearthUI.addDisconnect(context, playerObj, firebox, joined.tile, spec) end
            local candidates = Smokehouse.fireboxesBy(object)
            -- One that may join first, so a refusal shows only when none fits.
            table.sort(candidates, function(a, b) return (Smokehouse.connectRefusalFor(a) == nil) and (Smokehouse.connectRefusalFor(b) ~= nil) end)
            local found = candidates[1]
            if found then HearthUI.addConnect(context, playerObj, found.firebox, found.tile, spec) end
            return
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillChamberMenu)

-- The shed doesn't pick up while the flue joins it.
UI.keepInPlace(function(object)
    if Smokehouse.isChamber(object) then return Smokehouse.joinedFirebox(object) ~= nil end
end)

-- The shed stands in the open or under an open roof, never in a room, and keeps its door's front free.
local chambers = {}
for _, name in ipairs(Tiles.CHAMBERS) do chambers[name] = true end
UI.notInRooms(chambers)
UI.keepDoorsFree(chambers)
