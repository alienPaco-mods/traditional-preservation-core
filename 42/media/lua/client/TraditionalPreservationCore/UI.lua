-- Traditional Preservation core: text and popups for the station windows, and what the right-click menus share.
require "Entity/ISUI/Components/Crafting/ISWidgetCraftLogicOutputProgress"
require "Entity/ISUI/Components/Crafting/ISCraftLogicPanel"
require "Entity/ISUI/Controls/ISItemSlot"
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

-- 0.4 -> "40%". Pass the result as a value through UI.say, never into getText's pattern.
function UI.percent(share)
    return string.format("%.0f%%", share * 100)
end

-- Days and hours, rounded up to the hour, through a text with %1 days and %2 hours.
function UI.timeText(hours, key)
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

-- A fluid's name as the game shows it, from its type ("CowMilk").
function UI.fluidName(name)
    local fluid = name and Fluid.Get(name)
    return fluid and fluid:getTranslatedName() or tostring(name)
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

-- A station's own input rules in place of vanilla's free-slot limit. One refusal decides adding (each queued
-- action asks again when it runs, as the slot may have filled since), the slot's green border while dragging,
-- and the halo when a drop is refused, so the border never promises what adding then refuses.
--   station(entity)              the entity's crafting component and anything the refusal needs, or nil for an
--                                entity that isn't the mod's
--   refusal(slot, item, queued)  a translation key, or nil if item may go in. slot = { entity, component,
--                                resource, extra }; queued lists the items already on their way in this add
--   added(entity)                optional, before an add: start tracking a station built this session
-- Wraps ISCraftLogicPanel.ItemSlotAddItems (its add loop is copied here), ISItemSlot.defaultVerifyItem and
-- ISItemSlot.onMouseUp: compare them with vanilla after a game update. Each mod's call wraps the last, so
-- other entities pass through every mod to vanilla.
function UI.slotRules(rules)
    -- An item can be a crafting entity too, and has no sprite for a mod's station() to read.
    local modStation = rules.station
    local function station(entity)
        if not instanceof(entity, "IsoObject") then return nil end
        return modStation(entity)
    end
    local vanillaAddItems = ISCraftLogicPanel.ItemSlotAddItems
    local vanillaVerifyItem = ISItemSlot.defaultVerifyItem
    local vanillaMouseUp = ISItemSlot.onMouseUp

    local function canAdd(action)
        return not rules.refusal(action.tpSlot, action.item, {})
    end

    function ISCraftLogicPanel.ItemSlotAddItems(player, entity, itemSlot, itemList, component)
        local ours, extra = station(entity)
        if not ours then return vanillaAddItems(player, entity, itemSlot, itemList, component) end
        if rules.added then rules.added(entity) end

        local slot = { entity = entity, component = component, resource = itemSlot.resource, extra = extra }
        local queued = {}
        for index, item in ipairs(itemList) do
            local reason = rules.refusal(slot, item, queued)
            if reason then
                HaloTextHelper.addBadText(player, getText(reason))
                return
            end
            if index == 1 and not ISEntityUI.WalkToEntity(player, entity) then return end

            local action = ISItemSlotAddAction:new(player, entity, item, itemSlot.resource, itemSlot)
            action.component = component
            action.tpSlot = slot
            action.canAddItem = canAdd
            ISTimedActionQueue.add(action)
            table.insert(queued, item)
        end
    end

    -- The mod's input slot an item slot shows, or nil for any other slot.
    local function slotOf(itemSlot)
        local resource = itemSlot and itemSlot.resource
        if not resource or resource:getIO() ~= ResourceIO.Input then return nil end
        local entity = resource:getGameEntity()
        local component, extra = station(entity)
        if not component then return nil end
        return { entity = entity, component = component, resource = resource, extra = extra }
    end

    function ISItemSlot:defaultVerifyItem(itemSlot, item)
        if not vanillaVerifyItem(self, itemSlot, item) then return false end
        local slot = slotOf(itemSlot)
        return not slot or not rules.refusal(slot, item, {})
    end

    -- The reason to show when nothing being dragged can go in this slot.
    local function dropRefusal(itemSlot)
        if not ISMouseDrag.dragging or ISMouseDrag.draggingFocus == itemSlot then return nil end
        local slot = slotOf(itemSlot)
        if not slot then return nil end

        local reason
        for _, item in ipairs(ISInventoryPane.getActualItems(ISMouseDrag.dragging)) do
            local itemReason = rules.refusal(slot, item, {})
            if not itemReason then return nil end
            reason = reason or itemReason
        end
        return reason
    end

    -- A refused drop does nothing in vanilla, so this says why.
    function ISItemSlot:onMouseUp(x, y)
        local reason = dropRefusal(self)
        if reason then HaloTextHelper.addBadText(getPlayer(), getText(reason)) end
        return vanillaMouseUp(self, x, y)
    end
end

-- Picking a station up can break it, and one that holds something would lose it. mustStay(object) is true for a
-- station that has to stay where it is; the pick-up cursor then says why, with vanilla's own line for a full
-- container. Wraps ISMoveableSpriteProps.canPickUpMoveable and getInfoPanelFlagsPerTile, once for every mod.
local stayTests = {}

local function mustStay(object)
    if not object then return false end
    for _, test in ipairs(stayTests) do
        if test(object) then return true end
    end
    return false
end

local function wrapPickUp()
    local vanillaCanPickUp = ISMoveableSpriteProps.canPickUpMoveable
    local vanillaInfoFlags = ISMoveableSpriteProps.getInfoPanelFlagsPerTile

    function ISMoveableSpriteProps:canPickUpMoveable(character, square, object)
        if mustStay(object) then return false end
        return vanillaCanPickUp(self, character, square, object)
    end

    function ISMoveableSpriteProps:getInfoPanelFlagsPerTile(square, object, player, mode)
        vanillaInfoFlags(self, square, object, player, mode)
        if mode == "pickup" and mustStay(object) then InfoPanelFlags.hasItems = true end
    end
end

function UI.keepInPlace(test)
    if #stayTests == 0 then wrapPickUp() end
    table.insert(stayTests, test)
end

-- Refuses these sprites on a square that fails fits, when a moveable is put down.
local function placeOnly(sprites, fits)
    local vanillaCanPlace = ISMoveableSpriteProps.canPlaceMoveable
    function ISMoveableSpriteProps:canPlaceMoveable(character, square, item)
        if sprites[self.spriteName] and square and not fits(square) then return false end
        return vanillaCanPlace(self, character, square, item)
    end
end

-- Stations built for the open refuse an indoor square, and this stops one being picked up and carried in,
-- as placing a moveable doesn't run that check. sprites is a set of sprite names.
function UI.outdoorOnly(sprites)
    placeOnly(sprites, function(square) return square:isOutside() end)
end

-- The same for stations that may stand under a roof (a porch, an open shed) but not in a room.
function UI.notInRooms(sprites)
    placeOnly(sprites, function(square) return not square:isInARoom() end)
end

local APPLIANCES = { "IsoStove", "IsoClothingWasher", "IsoClothingDryer", "IsoCombinationWasherDryer" }
local COLD_CONTAINERS = { fridge = true, freezer = true }

-- A stove, a fridge or freezer, or a washer or dryer: something that heats, chills or shakes what stands on it.
function UI.isAppliance(object)
    for _, class in ipairs(APPLIANCES) do
        if instanceof(object, class) then return true end
    end
    for index = 0, (object.getContainerCount and object:getContainerCount() or 0) - 1 do
        local container = object:getContainerByIndex(index)
        if container and COLD_CONTAINERS[container:getType()] then return true end
    end
    return false
end

-- Table-top stations refuse a square holding an appliance. Vanilla only asks for IsTable, which electric stoves
-- and chest freezers carry, and the build ghost of an IsStackable tile asks canPlaceMoveable too, so this covers
-- building and putting down. sprites is a set of sprite names.
function UI.offAppliances(sprites)
    local vanillaCanPlace = ISMoveableSpriteProps.canPlaceMoveable
    function ISMoveableSpriteProps:canPlaceMoveable(character, square, item)
        if sprites[self.spriteName] and square then
            local objects = square:getObjects()
            for index = 0, objects:size() - 1 do
                if UI.isAppliance(objects:get(index)) then return false end
            end
        end
        return vanillaCanPlace(self, character, square, item)
    end
end

return UI
