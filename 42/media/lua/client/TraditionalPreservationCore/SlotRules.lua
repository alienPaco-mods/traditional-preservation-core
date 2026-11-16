-- Traditional Preservation core: a station's own input rules in its window, in place of vanilla's free-slot limit.
-- Reached as UI.slotRules.
require "Entity/ISUI/Components/Crafting/ISCraftLogicPanel"
require "Entity/ISUI/Components/Crafting/ISWidgetCraftLogicControl"
require "Entity/ISUI/Controls/ISItemSlot"

local UI = require "TraditionalPreservationCore/UI"
local Wrap = require "TraditionalPreservationCore/Wrap"

local SlotRules = {}

-- Each mod's rules are a layer over the last, as nested wraps would be: the last added runs first and passes what
-- isn't its own down to the one before, and the first to vanilla. One Wrap a function holds the layers.
local OWNERS = { ItemSlotAddItems = "ISCraftLogicPanel", defaultVerifyItem = "ISItemSlot", onMouseUp = "ISItemSlot",
    startCraft = "ISWidgetCraftLogicControl" }
local layers = { ItemSlotAddItems = {}, defaultVerifyItem = {}, onMouseUp = {}, startCraft = {} }

local function run(list, index, vanilla, ...)
    if index == 0 then return vanilla(...) end
    return list[index](function(...) return run(list, index - 1, vanilla, ...) end, ...)
end

-- layer(next, ...) gets the call's arguments and next, the layer below it (vanilla under the first).
local function addLayer(name, layer)
    local list = layers[name]
    if #list == 0 then
        Wrap.method(OWNERS[name], name, function(vanilla, ...) return run(list, #list, vanilla, ...) end)
    end
    table.insert(list, layer)
end

-- One refusal decides adding (each queued action asks again when it runs, as the slot may have filled since), the
-- slot's green border while dragging, and the halo when a drop is refused, so the border never promises what adding
-- then refuses.
--   station(entity)              the entity's crafting component and anything the refusal needs, or nil for an
--                                entity that isn't the mod's
--   refusal(slot, item, queued)  a translation key, or nil if item may go in. slot = { entity, component,
--                                resource, extra }; queued lists the items already on their way in this add
--   added(entity)                optional, before an add: start tracking a station built this session
--   recipeRefusal(slot, item)    optional: a translation key if item can't go in for the window's selected recipe
--                                (slot.recipe, its short name, from the station's CraftLogic; never called
--                                without one). The slot's border goes red and a
--                                drop says why, as for refusal; and since the recipe can change after loading,
--                                Craft also refuses to start while any stored input fails it.
--   owns(entity, item)           optional, for a station several mods use (TP Core's Smokehouse): true for the
--                                items this mod judges there; any other item passes on to the next mod's rules and
--                                vanilla, and an add with one in it is left to them whole
-- Wraps ISCraftLogicPanel.ItemSlotAddItems (its add loop is copied here), ISItemSlot.defaultVerifyItem,
-- ISItemSlot.onMouseUp and, with recipeRefusal, ISWidgetCraftLogicControl.startCraft, through Wrap (late, guarded):
-- compare them with vanilla after a game update. Each mod's call is a layer over the last, so other entities pass
-- through every mod to vanilla.
function SlotRules.slotRules(rules)
    -- An item can be a crafting entity too, and has no sprite for a mod's station() to read.
    local modStation = rules.station
    local function station(entity)
        if not instanceof(entity, "IsoObject") then return nil end
        return modStation(entity)
    end
    -- A station several mods use (the Smokehouse): rules.owns(entity, item) says which items are this mod's to
    -- judge; any other passes on to the next mod's rules and vanilla.
    local function mine(entity, item)
        return not rules.owns or rules.owns(entity, item)
    end

    -- The station's own rules, then the selected recipe's.
    local function refusal(slot, item, queued)
        if not mine(slot.entity, item) then return nil end
        local reason = rules.refusal(slot, item, queued)
        if reason or not rules.recipeRefusal or not slot.recipe then return reason end
        return rules.recipeRefusal(slot, item)
    end

    -- The short name of the recipe selected in the station's window: selecting one sets it on the station's
    -- CraftLogic too (its craft test data, which getCurrentRecipe reads). Every crafting component a station() gives
    -- has it (CraftLogic, DryingCraftLogic, FurnaceLogic, MashingLogic), and CraftLogic's never fails.
    local function selectedRecipe(component)
        local recipe = component:getCurrentRecipe()
        return recipe and UI.shortName(recipe) or nil
    end

    -- The slot record the rules are given.
    local function slotRecord(entity, component, extra, resource)
        return { entity = entity, component = component, resource = resource, extra = extra,
            recipe = selectedRecipe(component) }
    end

    local function canAdd(action)
        return not refusal(action.tpSlot, action.item, {})
    end

    addLayer("ItemSlotAddItems", function(vanillaAddItems, player, entity, itemSlot, itemList, component)
        local ours, extra = station(entity)
        if ours then
            for _, item in ipairs(itemList) do
                if not mine(entity, item) then ours = nil end
            end
        end
        if not ours then return vanillaAddItems(player, entity, itemSlot, itemList, component) end
        if rules.added then rules.added(entity) end

        local slot = slotRecord(entity, component, extra, itemSlot.resource)
        local queued = {}
        for index, item in ipairs(itemList) do
            local reason = refusal(slot, item, queued)
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
    end)

    -- The mod's input slot an item slot shows, or nil for any other slot.
    local function slotOf(itemSlot)
        local resource = itemSlot and itemSlot.resource
        if not resource or resource:getIO() ~= ResourceIO.Input then return nil end
        local entity = resource:getGameEntity()
        local component, extra = station(entity)
        if not component then return nil end
        return slotRecord(entity, component, extra, resource)
    end

    addLayer("defaultVerifyItem", function(vanillaVerifyItem, self, itemSlot, item)
        if not vanillaVerifyItem(self, itemSlot, item) then return false end
        local slot = slotOf(itemSlot)
        return not slot or not refusal(slot, item, {})
    end)

    -- The reason to show when nothing being dragged can go in this slot.
    local function dropRefusal(itemSlot)
        if not ISMouseDrag.dragging or ISMouseDrag.draggingFocus == itemSlot then return nil end
        local slot = slotOf(itemSlot)
        if not slot then return nil end

        local reason
        for _, item in ipairs(ISInventoryPane.getActualItems(ISMouseDrag.dragging)) do
            local itemReason = refusal(slot, item, {})
            if not itemReason then return nil end
            reason = reason or itemReason
        end
        return reason
    end

    -- A refused drop does nothing in vanilla, so this says why.
    addLayer("onMouseUp", function(vanillaMouseUp, self, x, y)
        local reason = dropRefusal(self)
        if reason then HaloTextHelper.addBadText(getPlayer(), getText(reason)) end
        return vanillaMouseUp(self, x, y)
    end)

    if not rules.recipeRefusal then return end
    -- Loaded under one recipe, started under another: vanilla would run the new one on what it accepts and leave
    -- the rest in the slots, so Craft says why instead.
    addLayer("startCraft", function(vanillaStartCraft, self)
        local component, extra = station(self.entity)
        local slot = component and slotRecord(self.entity, component, extra)
        local resources = slot and slot.recipe and self.entity:getComponent(ComponentType.Resources)
        if resources then
            local group = self.logic:getCraftLogic():getInputsGroupName()
            local inputs = resources:getResourcesFromGroup(group, ArrayList.new(), ResourceIO.Input, ResourceType.Item)
            for i = 0, inputs:size() - 1 do
                slot.resource = inputs:get(i)
                local stored = slot.resource:getStoredItems()
                for j = 0, stored:size() - 1 do
                    local reason = mine(self.entity, stored:get(j)) and rules.recipeRefusal(slot, stored:get(j))
                    if reason then
                        HaloTextHelper.addBadText(self.player, getText(reason))
                        return
                    end
                end
            end
        end
        return vanillaStartCraft(self)
    end)
end

-- Craft on a station that can't run says why instead of doing nothing: refuse(control) gives a translation key, or
-- nil to go on (control is vanilla's ISWidgetCraftLogicControl: .entity, .player). A layer on the same one wrap of
-- startCraft as slotRules' recipe check. Reached as UI.craftRefusal.
function SlotRules.craftRefusal(refuse)
    addLayer("startCraft", function(vanillaStartCraft, self)
        local reason = refuse(self)
        if reason then
            HaloTextHelper.addBadText(self.player, getText(reason))
            return
        end
        return vanillaStartCraft(self)
    end)
end

return SlotRules
