-- Traditional Preservation core: a station's own lines inside vanilla's crafting window, under In Progress, Done and
-- Take All: rows of label and value, a bar for each running batch and wrapped notes, kept up to date while the
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

local StationInfo = {}

StationInfo.MIN_WIDTH = 300     -- the widget is at least this wide with a block in it, so notes don't wrap word by word
StationInfo.LABEL_WIDTH = 110
StationInfo.PADDING = 8
StationInfo.BAR_HEIGHT = 12
StationInfo.REFRESH_TICKS = 30
StationInfo.GOOD_COLOUR, StationInfo.SLOW_COLOUR = { 0.35, 0.6, 0.3 }, { 0.75, 0.55, 0.2 }

local KEY = "IGUI_TraditionalPreservationCore_"

local providers = {}

local Panel = ISPanel:derive("TraditionalPreservationCoreStationInfoPanel")
StationInfo.Panel = Panel

function Panel:new(widget, provider)
    local o = ISPanel.new(self, 0, 0, StationInfo.MIN_WIDTH, 10)
    o.widget, o.provider = widget, provider
    o.background = false
    o.ticks = 0
    o.info = provider(widget.entity)
    return o
end

local function lineHeight()
    return getTextManager():getFontHeight(UIFont.Small)
end

-- Each note's lines at this width, kept until its text or the width changes (wrapping measures every word).
function Panel:noteLines(width)
    if self.noteWidth ~= width then self.noteWidth, self.noteTexts, self.wrapped = width, {}, {} end
    for index, note in ipairs(self.info.notes) do
        if self.noteTexts[index] ~= note then
            self.noteTexts[index], self.wrapped[index] = note, InfoWindow.wrapped(note, width)
        end
    end
    return self.wrapped
end

-- The block's height at this width; 0 with nothing to show.
function Panel:measure(width)
    local info = self.info
    if not info then return 0 end
    local height = StationInfo.PADDING + #info.rows * (lineHeight() + 2) + #info.bars * (lineHeight() + 4)
    local lines = self:noteLines(width - StationInfo.PADDING * 2)
    for index = 1, #info.notes do height = height + 4 + #lines[index] * lineHeight() end
    return height + StationInfo.PADDING
end

-- Asks the provider again twice a second; a block that grew or shrank has the window laid out again.
function Panel:update()
    ISPanel.update(self)
    self.ticks = self.ticks + 1
    if self.ticks < StationInfo.REFRESH_TICKS then return end
    self.ticks = 0
    self.info = self.provider(self.widget.entity)
    local change = self:measure(self.width) - self.height
    if change ~= 0 and self.widget.xuiRecalculateLayout then
        self.widget:xuiRecalculateLayout(nil, change < 0 and change or nil)
    end
end

function Panel:render()
    ISPanel.render(self)
    local info = self.info
    if not info then return end
    local padding, labelWidth, barHeight = StationInfo.PADDING, StationInfo.LABEL_WIDTH, StationInfo.BAR_HEIGHT
    local line = lineHeight()
    local y = padding
    self:drawRect(padding, 0, self.width - padding * 2, 1, 0.4, 0.5, 0.5, 0.5)
    for _, row in ipairs(info.rows) do
        self:drawText(getText(row[1]), padding, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
        self:drawText(row[2], padding + labelWidth, y, 1, 1, 1, 1, UIFont.Small)
        y = y + line + 2
    end
    local x = padding + labelWidth
    local width = self.width - x - padding
    for _, bar in ipairs(info.bars) do
        local top = y + (line - barHeight) / 2
        self:drawText(bar.text, padding, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
        self:drawRect(x, top, width, barHeight, 0.6, 0.1, 0.1, 0.1)
        self:drawRect(x, top, width * math.max(0, math.min(bar.share, 1)), barHeight, 0.9, bar.colour[1], bar.colour[2], bar.colour[3])
        self:drawRectBorder(x, top, width, barHeight, 0.8, 0.4, 0.4, 0.4)
        self:drawTextCentre(bar.value, x + width / 2, y, 1, 1, 1, 1, UIFont.Small)
        y = y + line + 4
    end
    local lines = self:noteLines(self.width - padding * 2)
    for index = 1, #info.notes do
        y = y + 4
        for _, text in ipairs(lines[index]) do
            self:drawText(text, padding, y, 0.8, 0.8, 0.65, 1, UIFont.Small)
            y = y + line
        end
    end
end

local hooked = false

local function hook()
    if hooked then return end
    hooked = true
    local vanillaChildren = ISWidgetCraftLogicOutputProgress.createDynamicChildren
    local vanillaLayout = ISWidgetCraftLogicOutputProgress.calculateLayout

    function ISWidgetCraftLogicOutputProgress:createDynamicChildren()
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
    end

    -- Vanilla lays its rows out from the top and takes the height it is given, so the block goes under them: vanilla
    -- gets the height less the block's, and the widget is that much taller again.
    function ISWidgetCraftLogicOutputProgress:calculateLayout(preferredWidth, preferredHeight)
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
    end
end

-- The last station asked about and its window logic: one window is open at a time, and the logic is costly to make.
local cached = { entity = nil, entry = {} }

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
-- its running batches furthest along first, each { data = its recipe data, progress = 0 to 1, count = items in it }. Nil for anything
-- without a CraftLogic, or before there is a player.
function StationInfo.contents(entity)
    local resources = entity:getComponent(ComponentType.Resources)
    local logic = entity:getComponent(ComponentType.CraftLogic)
    if not (resources and logic) then return nil end
    if cached.entity ~= entity then cached.entity, cached.entry = entity, {} end
    local uiLogic = Station.uiLogic(entity, cached.entry, logic)
    if not uiLogic then return nil end
    local batches = {}
    for craftData, items in pairs(uiLogic:getItemsInProgress()) do
        local count = 0
        for _, amount in pairs(items) do count = count + tonumber(tostring(amount)) end
        table.insert(batches, { data = craftData, progress = logic:getProgress(craftData), count = count })
    end
    table.sort(batches, function(a, b) return a.progress > b.progress end)
    return { logic = logic, batches = batches,
        waiting = storedItems(resources, logic:getInputsGroupName(), ResourceIO.Input),
        finished = storedItems(resources, logic:getOutputsGroupName(), ResourceIO.Output) }
end

-- A block for a plain station, in the series' order. options:
--   place: Weather's or the Hearth's place word; temperature and rate (0 to 1), when the station works by the
--     weather (the rate in the slow colour under UI.SLOW_RATE); rows: the mod's own { labelKey, value } after them;
--   batches: { name, progress, hoursLeft }, a bar each, numbered when numbered is true;
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
        local hours = math.ceil(batch.hoursLeft)
        table.insert(bars, {
            text = options.numbered and UI.say(KEY .. "InfoBatch", tostring(index), batch.name) or batch.name,
            share = batch.progress,
            value = UI.say(KEY .. "InfoLeft", UI.percent(batch.progress), tostring(math.floor(hours / 24)), tostring(hours % 24)),
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
    hook()
    table.insert(providers, provider)
end

return StationInfo
