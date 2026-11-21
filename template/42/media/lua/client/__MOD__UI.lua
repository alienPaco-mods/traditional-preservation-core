-- Traditional Preservation (__NAME__) B42: the __STATION__'s right-click menu (put raw batches in, take finished ones,
-- take everything out) and its Info window (TP Core's InfoWindow), opened from the menu. A station with anything
-- in it stays where it is; none is put down in front of a door.
require "TimedActions/TP__STATION_TAG__"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local StationReport = require "TraditionalPreservationCore/StationReport"
local PiecesUI = require "TraditionalPreservationCore/PiecesUI"
local UI = require "TraditionalPreservationCore/UI"
local Weather = require "TraditionalPreservationCore/Weather"
local Tiles = require "__MOD__/Tiles"

local M = __MOD__
local say = UI.say
local STATION_ICON = "media/textures/Item___STATION_TAG__.png"   -- TEMPLATE: Info's Station block takes a TPStation_<Name>.png outline (Core's tools/station_icons.py)
local CRAFTED_ICON, RETURNED_ICON = "media/ui/Entity/Icon_Crafted_48x48.png", "media/ui/Entity/Icon_Returned_48x48.png"
local StationWindow -- the info window, below the menu

local function stationNow(station)
    if __MOD__World then return __MOD__World.updateStation(station) end
    return (M.update(station))
end

local function view(station)
    local record = stationNow(station)
    local place = record.place or Weather.DEFAULT_PLACE
    local temperature = Weather.placeTemperature(M.getLedger(), place)
    local batches, done, all = {}, {}, {}
    for _, batch in ipairs(record.batches) do
        local status = M.status(batch, temperature)
        table.insert(batches, { batch = batch, status = status })
        table.insert(all, batch.id)
        if status.done then table.insert(done, batch.id) end
    end
    return { record = record, place = place, temperature = temperature, batches = batches, done = done, all = all }
end

local function batchText(status)
    if status.done then return getText("IGUI___MOD___Done") end
    return say("IGUI___MOD___Left", UI.percent(status.progress), UI.durationText(status.hoursLeft))
end

-- The raw batches into the inventory first, then the walk, then the action: vanilla's order.
local function queue(playerObj, station, mode, items, batches)
    for _, item in ipairs(items or {}) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    if not UI.walkTo(playerObj, station) then return end
    ISTimedActionQueue.add(TP__STATION_TAG__:new(playerObj, station, mode, items, batches))
end

local function rawBatches(playerObj)
    return UI.findItems(playerObj, function(item) return item:getFullType() == M.RAW end)
end

local function addMenu(context, playerObj, station)
    local stationView = view(station)
    local icon = getTexture(STATION_ICON)
    local option = context:addOption(getText("IGUI_CraftingWindow___STATION_TAG__"))
    option.iconTexture = icon
    local menu = context:getNew(context)
    context:addSubMenu(option, menu)

    local status = menu:addOption(say("IGUI___MOD___Holding", tostring(M.used(stationView.record)), tostring(M.ROOM)))
    status.isDisabled = true
    local lines = { UI.placeText(stationView.place, stationView.temperature) }
    for _, entry in ipairs(stationView.batches) do
        table.insert(lines, say("IGUI___MOD___BatchName", tostring(entry.batch.count)) .. ": " .. batchText(entry.status))
    end
    UI.tooltip(status, table.concat(lines, " <LINE> "))
    local info = menu:addOption(getText("ContextMenu___MOD___Info"), playerObj, StationWindow.open, station)
    info.iconTexture = icon
    UI.topInfo(context, getText("ContextMenu___MOD___Info"), icon, playerObj, StationWindow.open, station)

    local raw = rawBatches(playerObj)
    if #raw > 0 then
        local fits = M.fits(stationView.record)
        while #raw > math.max(fits, 1) do table.remove(raw) end
        local put = PiecesUI.row(menu, { label = getText("ContextMenu___MOD___Put"), room = fits, pieces = raw,
            help = say("IGUI___MOD___PutHelp", tostring(fits)), noRoom = getText("IGUI___MOD___Full") },
            function(chosen) queue(playerObj, station, "put", chosen) end)
        put.iconTexture = raw[1]:getTex()
    end
    if #stationView.done > 0 then
        local take = menu:addOption(say("ContextMenu___MOD___TakeDone", tostring(#stationView.done)), playerObj, queue, station, "take", nil, stationView.done)
        take.iconTexture = getTexture(CRAFTED_ICON)
    end
    if #stationView.all > #stationView.done then
        local takeAll = menu:addOption(getText("ContextMenu___MOD___TakeAll"), playerObj, queue, station, "take", nil, stationView.all)
        takeAll.iconTexture = getTexture(RETURNED_ICON)
        UI.tooltip(takeAll, getText("IGUI___MOD___TakeAllHelp"))
    end
end

-- __STATION__ Info: a band with the station's state, the place, the batches held as cells (a real count) with a lore
-- line beside them, a list row a batch, and Take Done / Take All.
local CELL_COLOUR = { 0.78, 0.73, 0.59 }   -- TEMPLATE: the cells' colour, or a pattern (Core's tools/cell_patterns.py)
local BAR_COLOURS = { working = { 0.62, 0.66, 0.38 }, done = { 0.35, 0.7, 0.35 } }

StationWindow = InfoWindow:derive("__MOD__Window")

function StationWindow:new(playerObj, station)
    local o = InfoWindow.new(self, playerObj, station)
    o.title = getText("IGUI_CraftingWindow___STATION_TAG__")
    return o
end

function StationWindow.open(playerObj, station)
    InfoWindow.open(StationWindow, playerObj, station)
end
StationReport.add(StationWindow, function(isoObject) return M.isStation(isoObject) and isoObject or nil end)

-- The band: empty, all done, or working.
local function band(stationView)
    if #stationView.batches == 0 then
        return getText("IGUI___MOD___BandEmpty"), getText("IGUI___MOD___BandEmptyText"), InfoWindow.BAND_IDLE
    end
    local text = say("IGUI___MOD___BandText", tostring(#stationView.done), tostring(#stationView.batches))
    if #stationView.done == #stationView.batches then return getText("IGUI___MOD___BandDone"), text, InfoWindow.BAND_WORKING end
    return getText("IGUI___MOD___BandWorking"), text, InfoWindow.BAND_WORKING
end

local function rows(stationView)
    local list, icon = {}, getScriptManager():FindItem(M.RAW)
    icon = icon and icon:getNormalTexture()
    for _, entry in ipairs(stationView.batches) do
        local status = entry.status
        table.insert(list, { icon = icon, name = say("IGUI___MOD___BatchName", tostring(entry.batch.count)),
            share = status.progress, colour = status.done and BAR_COLOURS.done or BAR_COLOURS.working, text = batchText(status) })
    end
    return list
end

-- Raw batches dragged onto the cells go in, as many as fit.
local function stationDrop(window)
    local function judge(items)
        local fits = M.fits(stationNow(window.station))
        local take = {}
        for _, item in ipairs(items) do
            if item:getFullType() == M.RAW and #take < fits then table.insert(take, item) end
        end
        local judged = { take = take, cells = #take, lines = {} }
        if #take > 0 then table.insert(judged.lines, say("IGUI___MOD___DropPut", tostring(#take))) end
        if #take < #items then
            judged.refused = fits == 0 and getText("IGUI___MOD___Full") or getText("IGUI___MOD___DropOnly")
            if #take == 0 then judged.lines = { judged.refused } end
        end
        return judged
    end
    local function drop(take)
        queue(window.playerObj, window.station, "put", take)
    end
    return { judge = judge, drop = drop }
end

function StationWindow:refresh()
    self.stationView = view(self.station)
    self.stationView.rows = rows(self.stationView)
    self.drop = self.drop or stationDrop(self)
end

function StationWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.stationView then return end
    local stationView = self.stationView
    local word, text, look = band(stationView)
    local y = self:band(word, text, look[1], look[2])
    y = self:stationBlock(y, STATION_ICON, stationView.place, stationView.temperature)
    y = self:section(y, "IGUI_TraditionalPreservationCore_SectionHolds")
    local used = M.used(stationView.record)
    y = self:holds(y, { { kind = "cells", name = getText("IGUI___MOD___Cells"),
        amount = say("IGUI___MOD___CellsValue", tostring(used), tostring(M.ROOM)), cells = M.ROOM, filled = used,
        colour = CELL_COLOUR, drop = self.drop } },
        getText("IGUI___MOD___Lore"))
    if #stationView.rows > 0 then
        y = self:pieceListBlock(y, "IGUI___MOD___SectionBatches",
            say("IGUI___MOD___ListCount", tostring(#stationView.rows)), stationView.rows)
    end
    local station, playerObj = self.station, self.playerObj
    local done, all = stationView.done, stationView.all
    y = self:buttonRow(y, {
        { title = say("IGUI___MOD___ButtonTakeDone", tostring(#done)), icon = CRAFTED_ICON,
          enabled = #done > 0, tooltip = #done == 0 and #all > 0 and getText("IGUI___MOD___NoneDone") or nil,
          onClick = function() queue(playerObj, station, "take", nil, done) end },
        { title = say("IGUI___MOD___ButtonTakeAll", tostring(#all)), icon = RETURNED_ICON,
          enabled = #all > 0, tooltip = #all > #done and getText("IGUI___MOD___TakeAllHelp") or nil,
          onClick = function() queue(playerObj, station, "take", nil, all) end },
    })
    self:drawNotes(y, { getText("IGUI___MOD___NoteDrag"), getText("IGUI___MOD___NoteTime") })
end

local function onFillContextMenu(playerNum, context, worldobjects, test)
    local seen = {}
    for _, isoObject in ipairs(worldobjects) do
        if M.isStation(isoObject) and not seen[isoObject] then
            if test then return ISWorldObjectContextMenu.setTest() end
            seen[isoObject] = true
            addMenu(context, getSpecificPlayer(playerNum), isoObject)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

-- Anything in the station keeps it where it is (no station moves mid-process).
UI.keepInPlace(function(isoObject)
    if not M.isStation(isoObject) or not isoObject:hasModData() then return nil end
    local movableData = isoObject:getModData().movableData
    local record = movableData and movableData[M.KEY]
    return (record ~= nil and not M.isEmpty(record)) or nil
end)
UI.keepDoorsFree(Tiles.STATIONS)
