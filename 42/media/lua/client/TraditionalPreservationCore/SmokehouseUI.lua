-- Traditional Preservation core: the Smokehouse's flue is a Stone Hearth connection, so Connect the Stone Hearth and
-- Disconnect the Stone Hearth are Core's (FireUI.addConnect / addDisconnect, in the fire's own menu); the chamber's
-- right-click offers them too. The shed doesn't pick up while joined (the fire is Core's rule), and the fire's Info
-- says where its flue goes.
local UI = require "TraditionalPreservationCore/UI"
local FireUI = require "TraditionalPreservationCore/FireUI"
local Fire = require "TraditionalPreservationCore/Fire"
local Smokehouse = require "TraditionalPreservationCore/Smokehouse"

Fire.connect({
    id = Smokehouse.ID,
    connectText = "ContextMenu_TraditionalPreservationCore_ConnectStoneHearth",
    disconnectText = "ContextMenu_TraditionalPreservationCore_DisconnectStoneHearth",
    disconnectHelp = "IGUI_TraditionalPreservationCore_DisconnectHelp",
    icon = "media/textures/Item_TPStoneHearth.png",
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
            local spec = Fire.connection(Smokehouse.ID)
            local stoneHearth, joined = Smokehouse.joinedStoneHearth(object)
            if stoneHearth then return FireUI.addDisconnect(context, playerObj, stoneHearth, joined.tile, spec) end
            local found = Smokehouse.connectCandidate(object)
            if found then FireUI.addConnect(context, playerObj, found.stoneHearth, found.tile, spec) end
            return
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillChamberMenu)

-- The shed doesn't pick up while the flue joins it.
UI.keepInPlace(function(object)
    if Smokehouse.isChamber(object) then return Smokehouse.joinedStoneHearth(object) ~= nil end
end)

-- The shed stands in the open or under an open roof, never in a room, and keeps its door's front free.
UI.notInRooms(Smokehouse.CHAMBER_NAMES)
UI.keepDoorsFree(Smokehouse.CHAMBER_NAMES)
