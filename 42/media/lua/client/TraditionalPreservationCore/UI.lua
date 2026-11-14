-- Traditional Preservation core: text and popups for the station windows, and what the right-click menus share.
require "Entity/ISUI/Components/Crafting/ISWidgetCraftLogicOutputProgress"
require "Entity/ISUI/Components/Crafting/ISCraftLogicPanel"

local UI = {}

UI.TOOLTIP_PADDING = 5
UI.TOOLTIP_MIN_WIDTH = 150
UI.SLOW_RATE = 0.5
UI.SLOW_COLOUR = { 1, 0.7, 0.4 }
UI.WARNING_COLOUR = { 1, 0.35, 0.3 }
-- A popup's title and a line's label, vanilla's pale yellow.
UI.LABEL_COLOUR = { 1, 1, 0.8 }

-- An option's fields that move with it when a lone recipe option becomes a submenu.
local OPTION_FIELDS = { "target", "onSelect", "param1", "param2", "param3", "param4", "param5", "param6", "param7",
    "param8", "param9", "param10", "iconTexture", "color", "toolTip", "notAvailable" }

-- The submenu named after an item that holds its recipes (Gut Fish, Pack Fish in Salt; a bucket's Cure Blood), so a
-- mod's options sit with vanilla's. Vanilla makes one only for two recipes or more; a lone recipe option is turned
-- into it where it stands, and with no recipe it is added. (Was Fish & Meat's fishSubMenu.)
function UI.itemSubMenu(context, item)
    local name = item:getDisplayName()
    local lone
    for _, option in ipairs(context.options) do
        if option.name == name and option.subOption then return context:getSubMenu(option.subOption) end
        if not lone and option.onSelect and option.onSelect == ISInventoryPaneContextMenu.OnNewCraft then lone = option end
    end
    local subMenu = context:getNew(context)
    local parent = lone
    if lone then
        local recipe = subMenu:addOption(lone.name)
        for _, field in ipairs(OPTION_FIELDS) do
            recipe[field] = lone[field]
            lone[field] = nil
        end
        lone.name = name
    else
        parent = context:addOption(name)
    end
    parent.iconTexture = item:getTexture()
    context:addSubMenu(parent, subMenu)
    return subMenu
end

-- The game's translator reads a finished line again as a format pattern, so a percentage followed by a
-- word ("40% soured") makes it throw, and so does a line with %1 given no values. So it is given plain
-- tokens, and the values go in here.
function UI.say(key, ...)
    local values = { ... }
    local tokens = {}
    for index = 1, select("#", ...) do tokens[index] = "@" .. index .. "@" end
    return (string.gsub(getText(key, unpack(tokens)), "@(%d)@", function(index) return tostring(values[tonumber(index)]) end))
end

-- 0.4 -> "40%". Pass the result as a value through UI.say, never into getText's pattern.
function UI.percent(share)
    return string.format("%.0f%%", share * 100)
end

-- A place's word, one set for the series: Weather's places and the Hearth's (Open air, Under an open roof, Indoors,
-- Loft, Basement, In a shed, By a fire, By banked embers).
function UI.placeName(place)
    return getText("IGUI_TraditionalPreservationCore_Place" .. tostring(place))
end

-- A place's temperature with its word: "12 C (Indoors)".
function UI.placeText(place, celsius)
    return UI.say("IGUI_TraditionalPreservationCore_PlaceAt", UI.degrees(celsius), UI.placeName(place))
end

-- Days and hours, rounded up to the hour, through a text with %1 days and %2 hours.
function UI.timeText(hours, key)
    if not hours then return getText("IGUI_TraditionalPreservationCore_Paused") end
    local whole = math.ceil(hours)
    return UI.say(key, string.format("%.0f", math.floor(whole / 24)), string.format("%.0f", whole % 24))
end

-- An item's name in a menu: vanilla's, unless a mod has a say (UI.nameHook): Dairy names a wrapped pot "Wrapped
-- Cooking Pot", which vanilla's display name never shows.
local NAME_HOOKS = {}

function UI.nameHook(fn)
    table.insert(NAME_HOOKS, fn)
end

function UI.itemName(item)
    for _, fn in ipairs(NAME_HOOKS) do
        local name = fn(item)
        if name then return name end
    end
    return item:getDisplayName()
end

-- Millilitres as litres to one decimal: 2500 -> "2.5".
function UI.litres(ml)
    return string.format("%.1f", ml / 1000)
end

-- Whole degrees.
function UI.degrees(celsius)
    return string.format("%.0f", celsius)
end

-- Whole hours, or "under an hour".
function UI.hoursText(hours)
    if hours <= 1 then return getText("IGUI_TraditionalPreservationCore_UnderHour") end
    return UI.say("IGUI_TraditionalPreservationCore_Hours", tostring(math.ceil(hours)))
end

-- Vanilla names tainted water "Water" and adds its "(Tainted)" only when the sandbox's tainted water text is on
-- (ENGINE_NOTES: getUiName; sinks and rain barrels ask the same option).
local TAINTED = "TaintedWater"

local function showsTainted()
    local option = getSandboxOptions():getOptionByName("EnableTaintedWaterText")
    return option ~= nil and option:getValue() == true
end

-- Whether a fluid's taint is kept from the player: tainted water while the sandbox's tainted water text is off.
function UI.hidesTaint(name)
    return name == TAINTED and not showsTainted()
end

-- The game's fluids by type, looked up once each.
local fluids = {}

local function fluidOf(name)
    local fluid = fluids[name]
    if not fluid then
        fluid = Fluid.Get(name)
        fluids[name] = fluid
    end
    return fluid
end

-- A fluid's name as the game shows it, from its type ("CowMilk"): tainted water as vanilla names it.
function UI.fluidName(name)
    local fluid = name and fluidOf(name)
    if not fluid then return tostring(name) end
    local text = fluid:getTranslatedName()
    if name == TAINTED and showsTainted() then text = text .. " " .. getText("Fluid_Tainted") end
    return text
end

-- Right-click menus

-- Every item on the player or in containers in reach that passes test. Favourites are left alone.
function UI.findItems(playerObj, test)
    local found = {}
    local containers = ISInventoryPaneContextMenu.getContainers(playerObj)
    for i = 0, containers:size() - 1 do
        local items = containers:get(i):getItems()
        for j = 0, items:size() - 1 do
            local item = items:get(j)
            if not item:isFavorite() and test(item) then table.insert(found, item) end
        end
    end
    return found
end

-- A menu option's hover. text is finished text, not a key.
function UI.tooltip(option, text)
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    tooltip.description = text
    option.toolTip = tooltip
end

-- Greys the option out, with the reason as its hover.
function UI.disable(option, text)
    option.isDisabled = true
    UI.tooltip(option, text)
end

-- colour is { r, g, b }, white if left out.
function UI.addLine(layout, label, value, colour)
    local item = layout:addItem()
    local lr, lg, lb = unpack(UI.LABEL_COLOUR)
    item:setLabel(getText(label) .. ":", lr, lg, lb, 1)
    local r, g, b = 1, 1, 1
    if colour then r, g, b = colour[1], colour[2], colour[3] end
    item:setValue(value, r, g, b, 1)
end

-- A rate line, in the slow colour below SLOW_RATE.
function UI.addRateLine(layout, label, rate)
    UI.addLine(layout, label, UI.percent(rate), rate < UI.SLOW_RATE and UI.SLOW_COLOUR or nil)
end

-- A popup's title line; returns where the first line below it goes.
local function drawTitle(tooltip, title)
    local r, g, b = unpack(UI.LABEL_COLOUR)
    tooltip:DrawText(tooltip:getFont(), title, UI.TOOLTIP_PADDING, UI.TOOLTIP_PADDING, r, g, b, 1)
    tooltip:adjustWidth(UI.TOOLTIP_PADDING, title)
    return UI.TOOLTIP_PADDING + tooltip:getLineSpacing()
end

-- A popup's size, its last line ending at bottom.
local function closeTooltip(tooltip, bottom)
    tooltip:setHeight(bottom + UI.TOOLTIP_PADDING)
    tooltip:setWidth(math.max(tooltip:getWidth(), UI.TOOLTIP_MIN_WIDTH))
end

-- A popup titled like vanilla's, with fill(layout) adding the lines. It runs twice, once to measure and once to draw.
function UI.drawTooltip(tooltip, fill)
    local top = drawTitle(tooltip, getText("EC_CraftLogic_Progress"))
    local layout = tooltip:beginLayout()
    fill(layout)
    local bottom = layout:render(UI.TOOLTIP_PADDING, top, tooltip)
    tooltip:endLayout(layout)
    closeTooltip(tooltip, bottom)
end

-- A recipe's name without its module.
function UI.shortName(recipe)
    return (string.gsub(recipe:getName(), "^.*%.", ""))
end

-- Each handler runs for every slot of every station's progress list, as handler(slot, name, widget), name
-- being the running recipe's short name. A batch that has just finished hands its data back to the engine's
-- pool with no recipe, so name can be nil.
local slotHandlers = {}
local hooked = false

local function hook()
    if hooked then return end
    hooked = true
    local vanillaProgressItems = ISWidgetCraftLogicOutputProgress.updateProgressItems
    function ISWidgetCraftLogicOutputProgress:updateProgressItems()
        vanillaProgressItems(self)
        for _, slot in ipairs(self.progressItems:getItemSlots()) do
            local recipe = slot.craftRecipeData and slot.craftRecipeData:getRecipe()
            local name = recipe and UI.shortName(recipe)
            for _, handler in ipairs(slotHandlers) do handler(slot, name, self) end
        end
    end
end

-- Adds a handler (see above). The first call installs the one wrap.
function UI.onProgressSlot(handler)
    hook()
    table.insert(slotHandlers, handler)
end

-- Vanilla's popup on a running batch goes by the recipe's time alone. draws maps recipe short names to
-- draw(slot, tooltip, name, entity). Other recipes' slots keep whatever popup they had.
function UI.progressTooltips(draws)
    UI.onProgressSlot(function(slot, name, widget)
        local draw = name and draws[name]
        if not draw then return end
        local entity = widget.entity
        -- Vanilla updates the list many times a second: the slot's popup is only made anew when it would differ.
        if slot.tpDraw == draw and slot.tpName == name and slot.tpEntity == entity then return end
        slot.tpDraw, slot.tpName, slot.tpEntity = draw, name, entity
        slot.drawTooltip = function(itemSlot, tooltip)
            -- A batch that has just finished hands its data back before the slot goes.
            local data = itemSlot.craftRecipeData
            if data and data:getRecipe() then draw(itemSlot, tooltip, name, entity) end
        end
    end)
end

-- The Output slot of a station's window names the script's one output (Charque) for a recipe whose OnCreate may
-- make others. draws maps recipe short names to draw(tooltip, name, entity), the popup in its place; other
-- recipes keep vanilla's. Wraps ISWidgetCraftLogicInputControl.createChildren, which the recipe panel runs anew
-- whenever the selected recipe changes: compare it with vanilla after a game update. Slots copy the panel's
-- drawTooltip when made, so the output slots are made again.
local outputDraws = {}
local outputHooked = false
function UI.outputTooltips(draws)
    if not outputHooked then
        outputHooked = true
        local vanillaCreateChildren = ISWidgetCraftLogicInputControl.createChildren
        function ISWidgetCraftLogicInputControl:createChildren()
            vanillaCreateChildren(self)
            local name = self.recipe and UI.shortName(self.recipe)
            local draw = name and self.outputItems and outputDraws[name]
            if not draw then return end
            local entity = self.entity
            self.outputItems.drawTooltip = function(_itemSlot, tooltip) draw(tooltip, name, entity) end
            self:updateOutputItems()
        end
    end
    for name, draw in pairs(draws) do outputDraws[name] = draw end
end

-- A popup with its own title and plain lines of finished text, for UI.outputTooltips.
function UI.drawListTooltip(tooltip, title, lines)
    local y = drawTitle(tooltip, title)
    for _, line in ipairs(lines) do
        tooltip:DrawText(tooltip:getFont(), line, UI.TOOLTIP_PADDING, y, 1, 1, 1, 1)
        tooltip:adjustWidth(UI.TOOLTIP_PADDING, line)
        y = y + tooltip:getLineSpacing()
    end
    closeTooltip(tooltip, y)
end

-- Functions moved to their own files, still reached here so no caller changes (DEVGUIDE refactoring rule 5). Each
-- file is required the first time one of its functions is called.
local function passOn(file, names)
    local module
    for _, name in ipairs(names) do
        UI[name] = function(...)
            module = module or require("TraditionalPreservationCore/" .. file)
            return module[name](...)
        end
    end
end

passOn("SlotRules", { "slotRules" })
passOn("Placement", { "keepInPlace", "outdoorOnly", "notInRooms", "keepDoorsFree", "offAppliances" })

return UI
