-- Traditional Preservation core: a station's own lines inside vanilla's crafting window, under In Progress, Done and
-- Take All: rows of label and value (a long value wraps), a bar for each running batch and wrapped notes, kept up to date while the
-- window is open. A mod adds a provider:
--     StationInfo.add(function(entity) return { rows = { { labelKey, value } }, bars = { { text, share, value, colour } },
--         notes = { "..." } } end)
-- which returns nil for any entity that isn't its station (cheaply: every crafting window asks). The first provider
-- with an answer when the window opens keeps the station. StationInfo.contents and StationInfo.block do the common
-- part for a plain CraftLogic station (Yeast's shelf, Vinegar's floor and vessel, Salt's vat).
-- Wraps ISWidgetCraftLogicOutputProgress.createDynamicChildren and calculateLayout (the widget grows by the block's
-- height): compare them with vanilla after a game update.
require "ISUI/ISPanel"
require "Entity/ISUI/Components/Crafting/ISWidgetCraftLogicOutputProgress"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local Station = require "TraditionalPreservationCore/Station"
local UI = require "TraditionalPreservationCore/UI"
local Wrap = require "TraditionalPreservationCore/Wrap"

local StationInfo = {}

StationInfo.MIN_WIDTH = 300     -- the widget is at least this wide with a block in it, so notes don't wrap word by word
StationInfo.LABEL_WIDTH = 110
StationInfo.PADDING = 8
StationInfo.BAR_HEIGHT = 12
StationInfo.REFRESH_TICKS = 30
StationInfo.GOOD_COLOUR, StationInfo.SLOW_COLOUR = { 0.35, 0.6, 0.3 }, { 0.75, 0.55, 0.2 }

local LAYOUT = { padding = StationInfo.PADDING, labelWidth = StationInfo.LABEL_WIDTH, barHeight = StationInfo.BAR_HEIGHT }

local KEY = "IGUI_TraditionalPreservationCore_"

local providers = {}

local Panel = ISPanel:derive("TraditionalPreservationCoreStationInfoPanel")
StationInfo.Panel = Panel

function Panel:new(widget, provider)
    local o = ISPanel.new(self, 0, 0, StationInfo.MIN_WIDTH, 10)
    o.widget, o.provider = widget, provider
    o.background = false
    o.ticks = 0
    o.stationView = provider(widget.entity)
    return o
end

-- The block's height at this width; 0 with nothing to show.
function Panel:measure(width)
    local stationView = self.stationView
    if not stationView then return 0 end
    local line = InfoWindow.lineHeight()
    local height = StationInfo.PADDING + #stationView.bars * (line + InfoWindow.BAR_GAP)
    for _, row in ipairs(stationView.rows) do
        height = height + #InfoWindow.rowLines(self, LAYOUT, row[2], width) * line + InfoWindow.ROW_GAP
    end
    local lines = InfoWindow.noteLines(self, LAYOUT, stationView.notes, width)
    for index = 1, #stationView.notes do height = height + InfoWindow.NOTE_GAP + #lines[index] * line end
    return height + StationInfo.PADDING
end

-- Asks the provider again twice a second; a block that grew or shrank has the window laid out again.
function Panel:update()
    ISPanel.update(self)
    self.ticks = self.ticks + 1
    if self.ticks < StationInfo.REFRESH_TICKS then return end
    self.ticks = 0
    self.stationView = self.provider(self.widget.entity)
    local change = self:measure(self.width) - self.height
    if change ~= 0 and self.widget.xuiRecalculateLayout then
        self.widget:xuiRecalculateLayout(nil, change < 0 and change or nil)
    end
end

function Panel:render()
    ISPanel.render(self)
    local stationView = self.stationView
    if not stationView then return end
    local padding = StationInfo.PADDING
    local y = padding
    self:drawRect(padding, 0, self.width - padding * 2, 1, 0.4, 0.5, 0.5, 0.5)
    for _, row in ipairs(stationView.rows) do y = InfoWindow.drawRow(self, LAYOUT, y, getText(row[1]), row[2]) end
    for _, bar in ipairs(stationView.bars) do y = InfoWindow.drawBar(self, LAYOUT, y, bar.text, bar.share, bar.colour, bar.progressText) end
    InfoWindow.drawNoteLines(self, LAYOUT, y, stationView.notes)
end

local hooked = false

local function hook()
    if hooked then return end
    hooked = true
    Wrap.method("ISWidgetCraftLogicOutputProgress", "createDynamicChildren", function(vanillaChildren, self)
        vanillaChildren(self)
        for _, provider in ipairs(providers) do
            if provider(self.entity) then
                self.tpInfo = Panel:new(self, provider)
                self.tpInfo:initialise()
                self.tpInfo:instantiate()
                self:addChild(self.tpInfo)
                return
            end
        end
    end)

    -- Vanilla lays its rows out from the top and takes the height it is given, so the block goes under them: vanilla
    -- gets the height less the block's, and the widget is that much taller again.
    Wrap.method("ISWidgetCraftLogicOutputProgress", "calculateLayout", function(vanillaLayout, self, preferredWidth, preferredHeight)
        local panel = self.tpInfo
        if not panel then return vanillaLayout(self, preferredWidth, preferredHeight) end
        preferredWidth = math.max(preferredWidth or 0, StationInfo.MIN_WIDTH)
        vanillaLayout(self, preferredWidth, 0)
        local extra = panel:measure(self:getWidth())
        vanillaLayout(self, preferredWidth, math.max((preferredHeight or 0) - extra, 0))
        panel:setX(0)
        panel:setY(self:getHeight())
        panel:setWidth(self:getWidth())
        panel:setHeight(extra)
        self:setHeight(self:getHeight() + extra)
    end)
end

-- The last station asked about and its window logic: one window is open at a time, and the logic is costly to make.
local cached = { entity = nil, sessionState = {} }

-- The order of running batches: furthest along first; at the same progress (put in together) by recipe name, then
-- by item count, so the bars keep their rows whatever order the engine lists them in (rule 9).
function StationInfo.batchBefore(a, b)
    if a.progress ~= b.progress then return a.progress > b.progress end
    if a.name ~= b.name then return a.name < b.name end
    return a.count > b.count
end

local function storedItems(resources, group, io)
    local items = {}
    local slots = Station.itemSlots(resources, group, io)
    for i = 0, slots:size() - 1 do
        local stored = slots:get(i):getStoredItems()
        for j = 0, stored:size() - 1 do table.insert(items, stored:get(j)) end
    end
    return items
end

-- What a CraftLogic station holds now: the items in its input slots (waiting) and its output slots (finished), and
-- its running batches furthest along first, each { craftRecipeData = its recipe data, progress = 0 to 1, count = items in it }. Nil for anything
-- without a CraftLogic, or before there is a player.
function StationInfo.contents(entity)
    local resources = entity:getComponent(ComponentType.Resources)
    local logic = entity:getComponent(ComponentType.CraftLogic)
    if not (resources and logic) then return nil end
    if cached.entity ~= entity then cached.entity, cached.sessionState = entity, {} end
    local uiLogic = Station.uiLogic(entity, cached.sessionState, logic)
    if not uiLogic then return nil end
    local batches = {}
    for craftData, items in pairs(uiLogic:getItemsInProgress()) do
        local count = 0
        for _, amount in pairs(items) do count = count + tonumber(tostring(amount)) end
        local recipe = craftData:getRecipe()
        table.insert(batches, { craftRecipeData = craftData, progress = logic:getProgress(craftData), count = count,
            name = recipe and recipe:getName() or "" })
    end
    table.sort(batches, StationInfo.batchBefore)
    return { logic = logic, batches = batches,
        waiting = storedItems(resources, logic:getInputsGroupName(), ResourceIO.Input),
        finished = storedItems(resources, logic:getOutputsGroupName(), ResourceIO.Output) }
end

-- A block for a plain station, in the series' order. options:
--   place: Weather's or the Stone Hearth's place word; temperature and rate (0 to 1), when the station works by the
--     weather (the rate in the slow colour under UI.SLOW_RATE); rows: the mod's own { labelKey, value } after them;
--   batches: { name, progress, hoursLeft }, a bar each (hoursLeft nil: paused, frozen), numbered when numbered is true;
--   waiting, finished: counts for the notes (0 or nil for none); notes: the mod's own, last.
-- The note that times assume the temperature holds comes with a temperature and a running batch.
function StationInfo.block(options)
    local rows, bars, notes = {}, {}, {}
    table.insert(rows, { KEY .. "InfoPlace", UI.placeName(options.place) })
    local rate = options.rate
    if options.temperature then
        table.insert(rows, { KEY .. "InfoAir", UI.say(KEY .. "InfoDegrees", UI.degrees(options.temperature)) })
        table.insert(rows, { KEY .. "InfoRate", UI.percent(rate) })
    end
    for _, row in ipairs(options.rows or {}) do table.insert(rows, row) end
    local slow = rate and rate < UI.SLOW_RATE
    for index, batch in ipairs(options.batches or {}) do
        local days, hours
        if batch.hoursLeft then days, hours = UI.daysHours(batch.hoursLeft) end
        table.insert(bars, {
            text = options.numbered and UI.say(KEY .. "InfoBatch", tostring(index), batch.name) or batch.name,
            share = batch.progress,
            progressText = days and UI.say(KEY .. "InfoLeft", UI.percent(batch.progress), days, hours)
                or UI.say(KEY .. "InfoPaused", UI.percent(batch.progress)),
            colour = slow and StationInfo.SLOW_COLOUR or StationInfo.GOOD_COLOUR,
        })
    end
    if (options.waiting or 0) > 0 then table.insert(notes, UI.say(KEY .. "InfoWaiting", tostring(options.waiting))) end
    if (options.finished or 0) > 0 then table.insert(notes, UI.say(KEY .. "InfoFinished", tostring(options.finished))) end
    for _, note in ipairs(options.notes or {}) do table.insert(notes, note) end
    if options.temperature and #bars > 0 then table.insert(notes, getText(KEY .. "InfoAssumes")) end
    if #bars == 0 and #notes == 0 then table.insert(notes, getText(KEY .. "InfoEmpty")) end
    return { rows = rows, bars = bars, notes = notes }
end

-- Adds a provider (see above). The first call installs the wraps.
function StationInfo.add(provider)
    assert(type(provider) == "function", "StationInfo.add: a provider (a function) needed")
    hook()
    table.insert(providers, provider)
end

return StationInfo
