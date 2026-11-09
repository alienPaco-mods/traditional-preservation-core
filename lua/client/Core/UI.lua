-- Traditional Preservation core: text and popups for the station windows.
require "Entity/ISUI/Components/Crafting/ISWidgetCraftLogicOutputProgress"
require "Moveables/ISMoveableSpriteProps"

local UI = {}

UI.TOOLTIP_PADDING = 5
UI.TOOLTIP_MIN_WIDTH = 150
UI.SLOW_RATE = 0.5
UI.SLOW_COLOUR = { 1, 0.7, 0.4 }
UI.WARNING_COLOUR = { 1, 0.35, 0.3 }

-- The game's translator reads a finished line again as a format pattern, so a percentage followed by a
-- word ("40% soured") makes it throw, and so does a line with %1 given no values. So it is given plain
-- tokens, and the values go in here.
function UI.say(key, ...)
    local values = { ... }
    local tokens = {}
    for index = 1, select("#", ...) do tokens[index] = "@" .. index .. "@" end
    return (string.gsub(getText(key, unpack(tokens)), "@(%d)@", function(index) return tostring(values[tonumber(index)]) end))
end

function UI.percent(share)
    return string.format("%.0f%%", share * 100)
end

-- Days and hours, rounded up to the hour, through a text with %1 days and %2 hours.
function UI.timeText(hours, key)
    local whole = math.ceil(hours)
    return UI.say(key, string.format("%.0f", math.floor(whole / 24)), string.format("%.0f", whole % 24))
end

-- colour is { r, g, b }, white if left out.
function UI.addLine(layout, label, value, colour)
    local item = layout:addItem()
    item:setLabel(getText(label) .. ":", 1, 1, 0.8, 1)
    local r, g, b = 1, 1, 1
    if colour then r, g, b = colour[1], colour[2], colour[3] end
    item:setValue(value, r, g, b, 1)
end

-- A rate line, in the slow colour below SLOW_RATE.
function UI.addRateLine(layout, label, rate)
    UI.addLine(layout, label, UI.percent(rate), rate < UI.SLOW_RATE and UI.SLOW_COLOUR or nil)
end

-- A popup titled like vanilla's, with fill(layout) adding the lines. It runs twice, once to measure and once to draw.
function UI.drawTooltip(tooltip, fill)
    local title = getText("EC_CraftLogic_Progress")
    tooltip:DrawText(tooltip:getFont(), title, UI.TOOLTIP_PADDING, UI.TOOLTIP_PADDING, 1, 1, 0.8, 1)
    tooltip:adjustWidth(UI.TOOLTIP_PADDING, title)
    local layout = tooltip:beginLayout()
    fill(layout)
    local bottom = layout:render(UI.TOOLTIP_PADDING, UI.TOOLTIP_PADDING + tooltip:getLineSpacing(), tooltip)
    tooltip:endLayout(layout)
    tooltip:setHeight(bottom + UI.TOOLTIP_PADDING)
    tooltip:setWidth(math.max(tooltip:getWidth(), UI.TOOLTIP_MIN_WIDTH))
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
        slot.drawTooltip = function(itemSlot, tooltip)
            -- A batch that has just finished hands its data back before the slot goes.
            local data = itemSlot.craftRecipeData
            if data and data:getRecipe() then draw(itemSlot, tooltip, name, entity) end
        end
    end)
end

-- Stations built for the open refuse an indoor square, and this stops one being picked up and carried in,
-- as placing a moveable doesn't run that check. sprites is a set of sprite names.
function UI.outdoorOnly(sprites)
    local vanillaCanPlace = ISMoveableSpriteProps.canPlaceMoveable
    function ISMoveableSpriteProps:canPlaceMoveable(character, square, item)
        if sprites[self.spriteName] and square and not square:isOutside() then return false end
        return vanillaCanPlace(self, character, square, item)
    end
end

return UI
