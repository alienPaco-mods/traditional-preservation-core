-- Traditional Preservation core: the Drying Cloth's right-click menus: Spread Drying Cloth on a floor with a Sheet and
-- two Stones in the inventory (no build menu: user, session 77), and on a cloth lay each kind a mod registered, take
-- dry lots, take everything off, Pick Up Drying Cloth once empty (the Sheet and Stones back); and Cloth Info (TP Core's
-- InfoWindow), opened from the menu. Not a moveable; none is spread in front of a door.
require "TimedActions/TPDryingCloth"
local DryingCloth = require "TraditionalPreservationCore/DryingCloth"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local Holds = require "TraditionalPreservationCore/Holds"
local PiecesUI = require "TraditionalPreservationCore/PiecesUI"
local UI = require "TraditionalPreservationCore/UI"
local Weather = require "TraditionalPreservationCore/Weather"
local Doors = require "TraditionalPreservationCore/Doors"

local say = UI.say
local CLOTH_ICON = "media/textures/Item_TPDryingCloth.png"
local STATION_ICON = "media/textures/TPStation_DryingCloth.png"   -- Cloth Info's Station block (tools/station_icons.py)
local CRAFTED_ICON, RETURNED_ICON = "media/ui/Entity/Icon_Crafted_48x48.png", "media/ui/Entity/Icon_Returned_48x48.png"
local ClothWindow -- the info window, below the menu
local DryingClothUI = {}

local function clothNow(station)
    if TraditionalPreservationCoreDryingCloth then return TraditionalPreservationCoreDryingCloth.updateCloth(station) end
    return (DryingCloth.update(station))
end

local function lotName(lot)
    return say("IGUI_TraditionalPreservationCore_ClothLot", getText(DryingCloth.kind(lot.kind).title), tostring(lot.count))
end

-- What a lot is doing, for the window's bars and the menu's hover.
local function lotText(status)
    if status.state == "dry" then return getText("IGUI_TraditionalPreservationCore_ClothDry") end
    if status.state == "dead" then return getText(status.spoiled and "IGUI_TraditionalPreservationCore_ClothSpoiled" or "IGUI_TraditionalPreservationCore_ClothDead") end
    if status.waits then return getText("IGUI_TraditionalPreservationCore_ClothWaits_" .. status.waits) end
    local text = say("IGUI_TraditionalPreservationCore_ClothLeft", UI.percent(status.progress), UI.durationText(status.hoursLeft))
    if status.tooHot then text = text .. " " .. getText("IGUI_TraditionalPreservationCore_ClothTooHot") end
    return text
end

local function view(station)
    local record, place = clothNow(station), nil
    place = record.place or Weather.DEFAULT_PLACE
    local temperature = Weather.placeTemperature(DryingCloth.getLedger(), place)
    local lots = {}
    for _, lot in ipairs(record.lots) do
        table.insert(lots, { id = lot.id, lot = lot, status = DryingCloth.status(lot, temperature, place) })
    end
    return { record = record, place = place, temperature = temperature, lots = lots }
end

-- The pieces into the inventory first, then the walk, then the action: vanilla's order.
local function queue(playerObj, station, mode, items, lots)
    for _, item in ipairs(items or {}) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    if not UI.walkTo(playerObj, station) then return end
    ISTimedActionQueue.add(TPDryingCloth:new(playerObj, station, mode, items, lots))
end

-- Lays groups (each one kind's pieces), one action a lot.
local function onLay(playerObj, station, groups)
    for _, group in ipairs(groups) do queue(playerObj, station, "lay", group) end
end

-- Each kind's carried pieces (rows One and All, as many as fit; PiecesUI).
local function addLayRows(menu, playerObj, station, record)
    for _, kind in ipairs(DryingCloth.kinds()) do
        local pieces = UI.findItems(playerObj, function(item)
            return kind.types[item:getFullType()] == true and (not kind.layable or kind.layable(item) == nil)
        end)
        if #pieces > 0 then
            local fits = DryingCloth.fits(record, kind)
            while #pieces > math.max(fits, 1) do table.remove(pieces) end
            PiecesUI.row(menu, { label = say("ContextMenu_TraditionalPreservationCore_ClothLay", getText(kind.title)),
                room = fits, pieces = pieces, help = say("IGUI_TraditionalPreservationCore_ClothLayHelp", tostring(fits)),
                noRoom = getText("IGUI_TraditionalPreservationCore_ClothFull") },
                function(chosen) onLay(playerObj, station, DryingCloth.lotsOf(kind, chosen)) end)
        end
    end
end

-- The ids of the lots done (dry or dead) and of every lot.
local function takeIds(clothView)
    local done, all = {}, {}
    for _, entry in ipairs(clothView.lots) do
        table.insert(all, entry.id)
        if entry.status.state ~= "wet" then table.insert(done, entry.id) end
    end
    return done, all
end

local function addTakeRows(menu, playerObj, station, clothView)
    local done, all = takeIds(clothView)
    if #done > 0 then
        menu:addOption(say("ContextMenu_TraditionalPreservationCore_ClothTakeDone", tostring(#done)), playerObj, queue, station, "take", nil, done)
    end
    if #all > #done then
        local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_ClothTakeAll"), playerObj, queue, station, "take", nil, all)
        UI.tooltip(option, getText("IGUI_TraditionalPreservationCore_ClothTakeAllHelp"))
    end
end

local CLOTH_REFUSALS = { NoRoom = "IGUI_TraditionalPreservationCore_ClothNoRoom", NoKit = "IGUI_TraditionalPreservationCore_ClothNoKit",
    NotEmpty = "IGUI_TraditionalPreservationCore_ClothNotEmpty" }

-- Whether a cloth of sprite can lie on square: a floor, nothing standing on it that takes the square (furniture, a
-- station, another cloth), not in front of a door.
local function squareTakes(square, sprite)
    if not square or not square:getFloor() or not square:isFree(false) then return false end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local properties = objects:get(i):getProperties()
        if properties and properties:has("BlocksPlacement") then return false end
    end
    return Doors.fits(square, sprite)
end

-- The cloth's kit in what the character carries, bags too: its items, or nil if any is missing.
local function kitInReach(playerObj)
    local wanted, found = {}, {}
    for _, need in ipairs(DryingCloth.KIT) do wanted[need[1]] = need[2] end
    UI.findItems(playerObj, function(item)
        local fullType = item:getFullType()
        if (wanted[fullType] or 0) > 0 then
            wanted[fullType] = wanted[fullType] - 1
            table.insert(found, item)
        end
        return false
    end)
    for _, left in pairs(wanted) do
        if left > 0 then return nil end
    end
    return found
end

-- The kit out of the bags into the main inventory first (the action takes it from there), then the walk.
local function onSpread(playerObj, square, sprite, free, kit)
    for _, item in ipairs(kit) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    if not luautils.walkAdj(playerObj, square, true) then return end
    ISTimedActionQueue.add(TPDryingCloth.spreadOn(playerObj, square, sprite, free))
end

-- Spread Drying Cloth on the square clicked, offered only with the whole kit (a Sheet and 2 Stones) carried, in a bag
-- or not (user, session 77; a Sheet alone is carried too often to offer it), greyed where it can't lie. Returns true
-- if it added the row.
local function addSpreadRow(context, playerObj, square, test)
    local kit = square and kitInReach(playerObj)
    if not kit then return false end
    if test then ISWorldObjectContextMenu.setTest() return true end
    local dir = playerObj:getDir()
    local sprite = DryingCloth.spriteFacing(dir == IsoDirections.N or dir == IsoDirections.S)
    local free = squareTakes(square, sprite)
    local option = context:addOption(getText("ContextMenu_TraditionalPreservationCore_SpreadCloth"), playerObj, onSpread, square, sprite, free, kit)
    option.iconTexture = getTexture(CLOTH_ICON)
    local refusal = DryingCloth.spreadRefusal(free, true)
    if refusal then
        UI.refuse(option, getText(CLOTH_REFUSALS[refusal]))
    else
        UI.tooltip(option, getText("Tooltip_craft_TPDryingClothDesc"))
    end
    return true
end

local function addPickUpRow(menu, playerObj, station, record)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_PickUpCloth"), playerObj, queue, station, "pickup")
    option.iconTexture = getTexture(CLOTH_ICON)
    local refusal = DryingCloth.pickUpRefusal(record)
    if refusal then UI.refuse(option, getText(CLOTH_REFUSALS[refusal])) end
end

local function addClothMenu(context, playerObj, station)
    local clothView = view(station)
    local option = context:addOption(getText("IGUI_CraftingWindow_TP_DryingCloth"))
    option.iconTexture = getTexture(CLOTH_ICON)
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = menu:addOption(say("IGUI_TraditionalPreservationCore_ClothLots", UI.percent(DryingCloth.roomUsed(clothView.record) / DryingCloth.ROOM)))
    status.isDisabled = true
    local lines = { UI.placeText(clothView.place, clothView.temperature) }
    for _, entry in ipairs(clothView.lots) do table.insert(lines, lotName(entry.lot) .. ": " .. lotText(entry.status)) end
    UI.tooltip(status, table.concat(lines, " <LINE> "))
    local info = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_ClothInfo"), playerObj, ClothWindow.open, station)
    info.iconTexture = getTexture(CLOTH_ICON)
    UI.topInfo(context, getText("ContextMenu_TraditionalPreservationCore_ClothInfo"), getTexture(CLOTH_ICON), playerObj, ClothWindow.open, station)
    addLayRows(menu, playerObj, station, clothView.record)
    addTakeRows(menu, playerObj, station, clothView)
    addPickUpRow(menu, playerObj, station, clothView.record)
end

-- Drying Cloth Info (all_info_mock): a band with the cloth's state, the place, its room as cells with the cloth's lore
-- beside them, then a list row for each lot (its share dried and time left, or why it waits), and Take Done / Take All.
local BAR_COLOURS = { wet = { 0.62, 0.66, 0.38 }, dry = { 0.35, 0.7, 0.35 }, dead = { 0.6, 0.3, 0.25 } }
local CELL_COLOUR = { 0.78, 0.73, 0.59 }

ClothWindow = InfoWindow:derive("TraditionalPreservationCoreClothWindow")

function ClothWindow:new(playerObj, station)
    local o = InfoWindow.new(self, playerObj, station)
    o.title = getText("IGUI_TraditionalPreservationCore_ClothInfo")
    return o
end

function ClothWindow.open(playerObj, station)
    InfoWindow.open(ClothWindow, playerObj, station)
end

-- The icon of the first item a kind takes.
local function kindIcon(kind)
    for fullType in pairs(kind.types) do
        local script = getScriptManager():FindItem(fullType)
        if script then return script:getNormalTexture() end
    end
end

-- The band: empty, a lot lost, a lot too hot, a lot waiting, all dry, or drying; the worst first. Returns the word's
-- key, the finished text and the colours.
local BANDS = {
    empty = { "IGUI_TraditionalPreservationCore_ClothBandEmpty", "IGUI_TraditionalPreservationCore_ClothBandEmptyText", InfoWindow.BAND_IDLE },
    lost = { "IGUI_TraditionalPreservationCore_ClothBandLost", "IGUI_TraditionalPreservationCore_ClothBandLostText", InfoWindow.BAND_AT_RISK },
    hot = { "IGUI_TraditionalPreservationCore_ClothBandTooHot", "IGUI_TraditionalPreservationCore_ClothBandTooHotText", InfoWindow.BAND_AT_RISK },
    still = { "IGUI_TraditionalPreservationCore_ClothBandWaiting", "IGUI_TraditionalPreservationCore_ClothBandWaitingText_still", InfoWindow.BAND_WAITING },
    frozen = { "IGUI_TraditionalPreservationCore_ClothBandWaiting", "IGUI_TraditionalPreservationCore_ClothBandWaitingText_frozen", InfoWindow.BAND_WAITING },
    dry = { "IGUI_TraditionalPreservationCore_ClothBandDry", "IGUI_TraditionalPreservationCore_ClothBandDryText", InfoWindow.BAND_WORKING },
    drying = { "IGUI_TraditionalPreservationCore_ClothBandDrying", "IGUI_TraditionalPreservationCore_ClothBandDryingText", InfoWindow.BAND_WORKING },
}
local WARNINGS = { hot = "IGUI_TraditionalPreservationCore_ClothWarnTooHot", still = "IGUI_TraditionalPreservationCore_ClothWarn_still",
    frozen = "IGUI_TraditionalPreservationCore_ClothWarn_frozen" }

function DryingClothUI.band(clothView)
    local lots, dry, dead, hot, waits = #clothView.lots, 0, 0, false, nil
    for _, entry in ipairs(clothView.lots) do
        local status = entry.status
        if status.state == "dry" then dry = dry + 1 end
        if status.state == "dead" then dead = dead + 1 end
        if status.state == "wet" and status.tooHot then hot = true end
        if status.state == "wet" and status.waits then waits = waits or status.waits end
    end
    local state = lots == 0 and "empty" or dead > 0 and "lost" or hot and "hot" or waits or (dry == lots and "dry") or "drying"
    local band = BANDS[state] or BANDS.drying
    return band[1], say(band[2], tostring(state == "lost" and dead or dry), tostring(lots)), band[3]
end

-- A list row a lot; a lot that waits or is too hot says so in amber.
local function lotRows(clothView)
    local rows = {}
    for _, entry in ipairs(clothView.lots) do
        local status, kind = entry.status, DryingCloth.kind(entry.lot.kind)
        local warning
        local why = status.state == "wet" and (status.tooHot and "hot" or status.waits) or nil
        if why and WARNINGS[why] then warning = getText(WARNINGS[why]) end
        local text = (status.state == "wet" and status.waits) and getText("IGUI_TraditionalPreservationCore_ClothWaiting")
            or (status.state == "wet" and say("IGUI_TraditionalPreservationCore_ClothLeft", UI.percent(status.progress), UI.durationText(status.hoursLeft)))
            or lotText(status)
        table.insert(rows, { icon = kind and kindIcon(kind), name = lotName(entry.lot), warning = warning,
            share = status.state == "dead" and 1 or status.progress, colour = BAR_COLOURS[status.state], text = text })
    end
    return rows
end

-- What is dragged onto the cloth's cells, as lots: each kind's pieces one lot (or perLot each), while there is room. Returns the groups
-- and the room they take.
local function dropGroups(record, items)
    local byKind, order = {}, {}
    for _, item in ipairs(items) do
        local kind = DryingCloth.kindOf(item:getFullType())
        if kind and (not kind.layable or kind.layable(item) == nil) then
            if not byKind[kind.name] then byKind[kind.name] = {} table.insert(order, kind) end
            table.insert(byKind[kind.name], item)
        end
    end
    local groups, free = {}, DryingCloth.ROOM - DryingCloth.roomUsed(record)
    for _, kind in ipairs(order) do
        local group = {}
        for _, item in ipairs(byKind[kind.name]) do
            if free < kind.room then break end
            table.insert(group, item)
            free = free - kind.room
        end
        for _, lot in ipairs(DryingCloth.lotsOf(kind, group)) do table.insert(groups, lot) end
    end
    return groups, DryingCloth.ROOM - DryingCloth.roomUsed(record) - free
end

-- The cells' drop: what goes on, how many lots, and why the rest doesn't.
local function clothDrop(window)
    local function judge(items)
        local record = clothNow(window.station)
        local groups, room = dropGroups(record, items)
        local take = {}
        for _, group in ipairs(groups) do
            for _, item in ipairs(group) do table.insert(take, item) end
        end
        local first = groups[1] and DryingCloth.kindOf(groups[1][1]:getFullType())
        local used = DryingCloth.roomUsed(record)
        local before = Holds.filledCells({ share = used / DryingCloth.ROOM })
        local after = Holds.filledCells({ share = (used + room) / DryingCloth.ROOM })
        local judged = { take = take, cells = room > 0 and math.max(after - before, 1) or 0, lines = {}, pattern = first and first.pattern }
        if #groups > 0 then
            table.insert(judged.lines, say("IGUI_TraditionalPreservationCore_ClothDropLay", tostring(#groups), tostring(#take)))
        end
        if #take < #items then
            local titles = {}
            for _, kind in ipairs(DryingCloth.kinds()) do table.insert(titles, getText(kind.title)) end
            local layable = 0
            for _, item in ipairs(items) do
                local kind = DryingCloth.kindOf(item:getFullType())
                if kind and (not kind.layable or kind.layable(item) == nil) then layable = layable + 1 end
            end
            judged.refused = layable > #take and getText("IGUI_TraditionalPreservationCore_ClothFull")
                or say("IGUI_TraditionalPreservationCore_ClothDropOnly", table.concat(titles, ", "))
            if #take == 0 then judged.lines = { judged.refused } end
        end
        return judged
    end
    local function drop(take)
        local groups = dropGroups(clothNow(window.station), take)
        onLay(window.playerObj, window.station, groups)
    end
    return { judge = judge, drop = drop }
end

function ClothWindow:refresh()
    self.clothView = view(self.station)
    self.clothView.rows = lotRows(self.clothView)
    self.drop = self.drop or clothDrop(self)
end

-- The room's cells, each kind in its pattern by the room it takes (Holds.byShare).
function DryingClothUI.parts(clothView)
    local byKind, parts = {}, {}
    for _, entry in ipairs(clothView.lots) do
        local kind = DryingCloth.kind(entry.lot.kind)
        if kind and kind.pattern then
            if not byKind[kind.name] then
                byKind[kind.name] = { pattern = kind.pattern, weight = 0 }
                table.insert(parts, byKind[kind.name])
            end
            byKind[kind.name].weight = byKind[kind.name].weight + entry.lot.count * kind.room
        end
    end
    return #parts > 0 and parts or nil
end

function ClothWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.clothView then return end
    local clothView = self.clothView
    local word, text, look = DryingClothUI.band(clothView)
    local y = self:band(getText(word), text, look[1], look[2])
    y = self:stationBlock(y, STATION_ICON, clothView.place, clothView.temperature)
    y = self:section(y, "IGUI_TraditionalPreservationCore_SectionHolds")
    local share = DryingCloth.roomUsed(clothView.record) / DryingCloth.ROOM
    y = self:holds(y, { { kind = "cells", name = getText("IGUI_TraditionalPreservationCore_ClothInfoLots"),
        amount = say("IGUI_TraditionalPreservationCore_ClothInfoLotsValue", UI.percent(share)), share = share, colour = CELL_COLOUR,
        parts = DryingClothUI.parts(clothView), drop = self.drop } },
        getText("IGUI_TraditionalPreservationCore_DryingClothLore"))
    if #clothView.rows > 0 then
        y = self:pieceListBlock(y, "IGUI_TraditionalPreservationCore_SectionOnCloth",
            say("IGUI_TraditionalPreservationCore_ClothListCount", tostring(#clothView.rows)), clothView.rows)
    end
    local station, playerObj = self.station, self.playerObj
    local done, all = takeIds(clothView)
    y = self:buttonRow(y, {
        { title = say("IGUI_TraditionalPreservationCore_ClothButtonTakeDone", tostring(#done)), icon = CRAFTED_ICON,
          enabled = #done > 0, tooltip = #done == 0 and #all > 0 and getText("IGUI_TraditionalPreservationCore_ClothNoneDry") or nil,
          onClick = function() queue(playerObj, station, "take", nil, done) end },
        { title = say("IGUI_TraditionalPreservationCore_ClothButtonTakeAll", tostring(#all)), icon = RETURNED_ICON,
          enabled = #all > 0, tooltip = #all > #done and getText("IGUI_TraditionalPreservationCore_ClothTakeAllHelp") or nil,
          onClick = function() queue(playerObj, station, "take", nil, all) end },
    })
    self:drawNotes(y, { getText("IGUI_TraditionalPreservationCore_ClothNoteDrag"), getText("IGUI_TraditionalPreservationCore_ClothNoteAir") })
end

local function onFillContextMenu(playerNum, context, worldobjects, test)
    local playerObj = getSpecificPlayer(playerNum)
    local seen, onCloth = {}, false
    for _, isoObject in ipairs(worldobjects) do
        if DryingCloth.isCloth(isoObject) and not seen[isoObject] then
            if test then return ISWorldObjectContextMenu.setTest() end
            seen[isoObject] = true
            onCloth = true
            addClothMenu(context, playerObj, isoObject)
        end
    end
    if not onCloth then
        local clicked = worldobjects[1] and worldobjects[1]:getSquare()
        if addSpreadRow(context, playerObj, clicked, test) and test then return true end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

return DryingClothUI
