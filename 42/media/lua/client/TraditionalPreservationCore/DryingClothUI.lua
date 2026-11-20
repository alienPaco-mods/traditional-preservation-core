-- Traditional Preservation core: the Drying Cloth's right-click menu (lay each kind a mod registered, take dry lots,
-- take everything off) and Cloth Info (TP Core's InfoWindow), opened from the menu or by clicking the cloth. A cloth
-- with anything on it stays where it is; none is put down in front of a door.
require "TimedActions/TPDryingCloth"
local DryingCloth = require "TraditionalPreservationCore/DryingCloth"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local UI = require "TraditionalPreservationCore/UI"
local Weather = require "TraditionalPreservationCore/Weather"

local say = UI.say
local CLOTH_ICON = "media/textures/Item_TPDryingCloth.png"
local STATION_ICON = "media/textures/TPStation_DryingCloth.png"   -- Cloth Info's Station block (tools/station_icons.py)
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
    for i, lot in ipairs(record.lots) do
        if lot then table.insert(lots, { index = i, lot = lot, status = DryingCloth.status(lot, temperature, place) }) end
    end
    return { record = record, place = place, temperature = temperature, lots = lots }
end

-- The pieces into the inventory first, then the walk, then the action: vanilla's order.
local function queue(playerObj, station, mode, items, lots)
    for _, item in ipairs(items or {}) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    if not UI.walkTo(playerObj, station) then return end
    ISTimedActionQueue.add(TPDryingCloth:new(playerObj, station, mode, items, lots))
end

-- Lays groups (each a lot's pieces), one action a lot.
local function onLay(playerObj, station, groups)
    for _, group in ipairs(groups) do queue(playerObj, station, "lay", group) end
end

-- The kind's carried pieces in lots of perLot, at most free lots of them.
local function groupsOf(pieces, perLot, free)
    local groups = {}
    for i, item in ipairs(pieces) do
        local g = math.floor((i - 1) / perLot) + 1
        if g > free then break end
        groups[g] = groups[g] or {}
        table.insert(groups[g], item)
    end
    return groups
end

local function addLayRows(menu, playerObj, station, record)
    local free = DryingCloth.freeLots(record)
    for _, kind in ipairs(DryingCloth.kinds()) do
        local pieces = UI.findItems(playerObj, function(item)
            return kind.types[item:getFullType()] == true and (not kind.layable or kind.layable(item) == nil)
        end)
        if #pieces > 0 then
            local label = say("ContextMenu_TraditionalPreservationCore_ClothLay", getText(kind.title))
            local groups = groupsOf(pieces, kind.perLot, free)
            local option
            if #groups <= 1 then
                option = menu:addOption(label, playerObj, onLay, station, groups)
            else
                option = menu:addOption(label)
                local sub = menu:getNew(menu)
                menu:addSubMenu(option, sub)
                sub:addOption(getText("ContextMenu_TraditionalPreservationCore_ClothOneLot"), playerObj, onLay, station, { groups[1] })
                sub:addOption(say("ContextMenu_TraditionalPreservationCore_ClothAllLots", tostring(#groups)), playerObj, onLay, station, groups)
            end
            if free == 0 then
                UI.refuse(option, getText("IGUI_TraditionalPreservationCore_ClothFull"))
            else
                UI.tooltip(option, say("IGUI_TraditionalPreservationCore_ClothLayHelp", tostring(kind.perLot)))
            end
        end
    end
end

local function addTakeRows(menu, playerObj, station, clothView)
    local done, all = {}, {}
    for _, entry in ipairs(clothView.lots) do
        table.insert(all, entry.index)
        if entry.status.state ~= "wet" then table.insert(done, entry.index) end
    end
    if #done > 0 then
        menu:addOption(say("ContextMenu_TraditionalPreservationCore_ClothTakeDone", tostring(#done)), playerObj, queue, station, "take", nil, done)
    end
    if #all > #done then
        local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_ClothTakeAll"), playerObj, queue, station, "take", nil, all)
        UI.tooltip(option, getText("IGUI_TraditionalPreservationCore_ClothTakeAllHelp"))
    end
end

local function addClothMenu(context, playerObj, station)
    local clothView = view(station)
    local option = context:addOption(getText("IGUI_CraftingWindow_TP_DryingCloth"))
    option.iconTexture = getTexture(CLOTH_ICON)
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local used = DryingCloth.LOTS - DryingCloth.freeLots(clothView.record)
    local status = menu:addOption(say("IGUI_TraditionalPreservationCore_ClothLots", tostring(used), tostring(DryingCloth.LOTS)))
    status.isDisabled = true
    local lines = { UI.placeText(clothView.place, clothView.temperature) }
    for _, entry in ipairs(clothView.lots) do table.insert(lines, entry.index .. ". " .. lotName(entry.lot) .. ": " .. lotText(entry.status)) end
    UI.tooltip(status, table.concat(lines, " <LINE> "))
    local info = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_ClothInfo"), playerObj, ClothWindow.open, station)
    info.iconTexture = getTexture(CLOTH_ICON)
    UI.topInfo(context, getText("ContextMenu_TraditionalPreservationCore_ClothInfo"), getTexture(CLOTH_ICON), playerObj, ClothWindow.open, station)
    addLayRows(menu, playerObj, station, clothView.record)
    addTakeRows(menu, playerObj, station, clothView)
end

-- Drying Cloth Info (all_info_mock): a band with the cloth's state, the place, the lots as cells with the cloth's lore
-- beside them, then a list row for each lot (its share dried and time left, or why it waits).
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
        table.insert(rows, { icon = kind and kindIcon(kind), name = entry.index .. ". " .. lotName(entry.lot), warning = warning,
            share = status.state == "dead" and 1 or status.progress, colour = BAR_COLOURS[status.state], text = text })
    end
    return rows
end

-- What is dragged onto the cloth's cells, as lots: each kind's pieces in lots of its perLot, while lots are free.
-- Returns the groups.
local function dropGroups(record, items)
    local byKind, order = {}, {}
    for _, item in ipairs(items) do
        local kind = DryingCloth.kindOf(item:getFullType())
        if kind and (not kind.layable or kind.layable(item) == nil) then
            if not byKind[kind.name] then byKind[kind.name] = {} table.insert(order, kind) end
            table.insert(byKind[kind.name], item)
        end
    end
    local groups, free = {}, DryingCloth.freeLots(record)
    for _, kind in ipairs(order) do
        for _, group in ipairs(groupsOf(byKind[kind.name], kind.perLot, free - #groups)) do table.insert(groups, group) end
    end
    return groups
end

-- The cells' drop: what goes on, how many lots, and why the rest doesn't.
local function clothDrop(window)
    local function judge(items)
        local record = clothNow(window.station)
        local groups = dropGroups(record, items)
        local take = {}
        for _, group in ipairs(groups) do
            for _, item in ipairs(group) do table.insert(take, item) end
        end
        local first = groups[1] and DryingCloth.kindOf(groups[1][1]:getFullType())
        local judged = { take = take, cells = #groups, lines = {}, pattern = first and first.pattern }
        if #groups > 0 then
            table.insert(judged.lines, say("IGUI_TraditionalPreservationCore_ClothDropLay", tostring(#groups), tostring(#take)))
        end
        if #take < #items then
            local titles = {}
            for _, kind in ipairs(DryingCloth.kinds()) do table.insert(titles, getText(kind.title)) end
            judged.refused = DryingCloth.freeLots(record) == 0 and getText("IGUI_TraditionalPreservationCore_ClothFull")
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

-- The lots' cells, each kind in its pattern (one cell a lot, so the split is exact).
function DryingClothUI.parts(clothView)
    local byKind, parts = {}, {}
    for _, entry in ipairs(clothView.lots) do
        local kind = DryingCloth.kind(entry.lot.kind)
        if kind and kind.pattern then
            if not byKind[kind.name] then
                byKind[kind.name] = { pattern = kind.pattern, weight = 0 }
                table.insert(parts, byKind[kind.name])
            end
            byKind[kind.name].weight = byKind[kind.name].weight + 1
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
    local used = DryingCloth.LOTS - DryingCloth.freeLots(clothView.record)
    y = self:holds(y, { { kind = "cells", name = getText("IGUI_TraditionalPreservationCore_ClothInfoLots"),
        amount = say("IGUI_TraditionalPreservationCore_ClothInfoLotsValue", tostring(used), tostring(DryingCloth.LOTS)),
        cells = DryingCloth.LOTS, filled = used, share = used / DryingCloth.LOTS, colour = CELL_COLOUR,
        parts = DryingClothUI.parts(clothView), drop = self.drop } },
        getText("IGUI_TraditionalPreservationCore_DryingClothLore"))
    if #clothView.rows > 0 then
        y = self:pieceListBlock(y, "IGUI_TraditionalPreservationCore_SectionOnCloth",
            say("IGUI_TraditionalPreservationCore_ClothListCount", tostring(#clothView.rows)), clothView.rows)
    end
    self:drawNotes(y, { getText("IGUI_TraditionalPreservationCore_ClothNoteDrag"), getText("IGUI_TraditionalPreservationCore_ClothNoteAir") })
end

local function onFillContextMenu(playerNum, context, worldobjects, test)
    local seen = {}
    for _, isoObject in ipairs(worldobjects) do
        if DryingCloth.isCloth(isoObject) and not seen[isoObject] then
            if test then return ISWorldObjectContextMenu.setTest() end
            seen[isoObject] = true
            addClothMenu(context, getSpecificPlayer(playerNum), isoObject)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

-- Anything on the cloth keeps it where it is (no station moves mid-process).
UI.keepInPlace(function(isoObject)
    if not DryingCloth.isCloth(isoObject) or not isoObject:hasModData() then return nil end
    local record = isoObject:getModData()[DryingCloth.KEY]
    return (record ~= nil and not DryingCloth.isEmpty(record)) or nil
end)
UI.keepDoorsFree(DryingCloth.SPRITES)

return DryingClothUI
