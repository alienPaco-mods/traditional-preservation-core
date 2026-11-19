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
local ClothWindow -- the info window, below the menu

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

-- Cloth Info: the place and its heat, then a bar for each lot (its share dried and time left, or why it waits).
local BAR_COLOURS = { wet = { 0.62, 0.66, 0.38 }, dry = { 0.35, 0.7, 0.35 }, dead = { 0.6, 0.3, 0.25 } }

ClothWindow = InfoWindow:derive("TraditionalPreservationCoreClothWindow")

function ClothWindow:new(playerObj, station)
    local o = InfoWindow.new(self, playerObj, station)
    o.title = getText("IGUI_TraditionalPreservationCore_ClothInfo")
    return o
end

function ClothWindow.open(playerObj, station)
    InfoWindow.open(ClothWindow, playerObj, station)
end

function ClothWindow:refresh()
    self.clothView = view(self.station)
end

function ClothWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.clothView then return end
    local clothView = self.clothView
    local y = self:top()
    y = self:row(y, "IGUI_TraditionalPreservationCore_ClothInfoPlace", UI.placeText(clothView.place, clothView.temperature))
    local used = DryingCloth.LOTS - DryingCloth.freeLots(clothView.record)
    y = self:row(y, "IGUI_TraditionalPreservationCore_ClothInfoLots", say("IGUI_TraditionalPreservationCore_ClothInfoLotsValue", tostring(used), tostring(DryingCloth.LOTS)))
    for _, entry in ipairs(clothView.lots) do
        local status = entry.status
        y = self:barNamed(y, entry.index .. ". " .. lotName(entry.lot), status.state == "dead" and 1 or status.progress,
            BAR_COLOURS[status.state], lotText(status))
    end
    local notes = { getText("IGUI_TraditionalPreservationCore_ClothNoteAir") }
    if #clothView.lots == 0 then table.insert(notes, 1, getText("IGUI_TraditionalPreservationCore_ClothNoteEmpty")) end
    self:drawNotes(y, notes)
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
