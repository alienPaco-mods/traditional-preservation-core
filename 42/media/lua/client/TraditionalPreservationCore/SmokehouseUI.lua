-- Traditional Preservation core: the Smokehouse's flue is a Stone Hearth connection, so Connect the Stone Hearth and
-- Disconnect the Stone Hearth are Core's (FireUI.addConnect / addDisconnect, in the fire's own menu); the chamber's
-- right-click offers them too. The shed doesn't pick up while joined (the fire is Core's rule), and the fire's Info
-- says where its flue goes. SmokehouseUI.band is the shed's Info band: its joined Stone Hearth's fire, as the hearth's.
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local UI = require "TraditionalPreservationCore/UI"
local FireUI = require "TraditionalPreservationCore/FireUI"
local Fire = require "TraditionalPreservationCore/Fire"
local Smokehouse = require "TraditionalPreservationCore/Smokehouse"

local SmokehouseUI = {}

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
    for _, isoObject in ipairs(worldobjects) do
        if Smokehouse.isChamber(isoObject) then
            if test then return end
            if Smokehouse.World then Smokehouse.World.track(isoObject) end
            local playerObj = getSpecificPlayer(playerNum)
            local connection = Fire.connection(Smokehouse.ID)
            local stoneHearth, joined = Smokehouse.joinedStoneHearth(isoObject)
            if stoneHearth then return FireUI.addDisconnect(context, playerObj, stoneHearth, joined.tile, connection) end
            local found = Smokehouse.connectCandidate(isoObject)
            if found then FireUI.addConnect(context, playerObj, found.stoneHearth, found.tile, connection) end
            return
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillChamberMenu)

-- The shed doesn't pick up while the flue joins it.
UI.keepInPlace(function(isoObject)
    if Smokehouse.isChamber(isoObject) then return Smokehouse.joinedStoneHearth(isoObject) ~= nil end
end)

-- The shed stands in the open or under an open roof, never in a room, and keeps its door's front free.
UI.notInRooms(Smokehouse.CHAMBER_NAMES)
UI.keepDoorsFree(Smokehouse.CHAMBER_NAMES)

-- The band of the shed's Info (window an InfoWindow, chamberTile any of its tiles), drawn: the joined Stone Hearth
-- stoked (hot smoke), banked (cold smoke, or too warm for it when the mod says the day is: tooWarm) or out, in the
-- hearth's colours with its Light / Put Out button; grey with no button when none is joined. Returns the y under it.
function SmokehouseUI.band(window, chamberTile, tooWarm)
    local stoneHearth = Smokehouse.joinedStoneHearth(chamberTile)
    if not stoneHearth then
        local idle = InfoWindow.BAND_IDLE
        return window:band(getText("IGUI_TraditionalPreservationCore_SmokeBandNoFire"),
            getText("IGUI_TraditionalPreservationCore_SmokeBandNone"), idle[1], idle[2])
    end
    local banked = Fire.isBanked(stoneHearth)
    local state = banked and "banked" or Fire.isBurning(stoneHearth) and "lit" or "out"
    local look = FireUI.BANDS[state]
    local time = FireUI.burnTime(Fire.fuelHours(stoneHearth))
    local text
    if state == "lit" then text = UI.say("IGUI_TraditionalPreservationCore_SmokeBandStoked", time)
    elseif banked then
        text = UI.say(tooWarm and "IGUI_TraditionalPreservationCore_SmokeBandBankedWarm" or "IGUI_TraditionalPreservationCore_SmokeBandBanked", time)
    elseif stoneHearth:getFuelAmount() > 0 then text = UI.say("IGUI_TraditionalPreservationCore_SmokeBandOut", time)
    else text = getText("IGUI_TraditionalPreservationCore_SmokeBandNoWood") end
    local word = getText(look.word or (banked and "IGUI_TraditionalPreservationCore_InfoFireBanked" or "IGUI_TraditionalPreservationCore_InfoFireOut"))
    return window:band(word, text, look.colour, look.dark, FireUI.bandButton(window, stoneHearth))
end

return SmokehouseUI
