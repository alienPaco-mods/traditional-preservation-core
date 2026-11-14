-- Traditional Preservation core: a station's own input rules in its window, in place of vanilla's free-slot limit.
-- Reached as UI.slotRules.
require "Entity/ISUI/Components/Crafting/ISCraftLogicPanel"
require "Entity/ISUI/Components/Crafting/ISWidgetCraftLogicControl"
require "Entity/ISUI/Controls/ISItemSlot"

local UI = require "TraditionalPreservationCore/UI"

local SlotRules = {}

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
-- ISItemSlot.onMouseUp and, with recipeRefusal, ISWidgetCraftLogicControl.startCraft: compare them with vanilla
-- after a game update. Each mod's call wraps the last, so other entities pass through every mod to vanilla.
function SlotRules.slotRules(rules)
    -- An item can be a crafting entity too, and has no sprite for a mod's station() to read.
    local modStation = rules.station
    local function station(entity)
        if not instanceof(entity, "IsoObject") then return nil end
        return modStation(entity)
    end
    local vanillaAddItems = ISCraftLogicPanel.ItemSlotAddItems
    local vanillaVerifyItem = ISItemSlot.defaultVerifyItem
    local vanillaMouseUp = ISItemSlot.onMouseUp

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
    -- CraftLogic too (its craft test data, which getCurrentRecipe reads). Guarded: another station may lack it.
    local function selectedRecipe(component)
        local ok, recipe = pcall(function() return component:getCurrentRecipe() end)
        return ok and recipe and UI.shortName(recipe) or nil
    end

    -- The slot record the rules are given.
    local function slotRecord(entity, component, extra, resource)
        return { entity = entity, component = component, resource = resource, extra = extra,
            recipe = selectedRecipe(component) }
    end

    local function canAdd(action)
        return not refusal(action.tpSlot, action.item, {})
    end

    function ISCraftLogicPanel.ItemSlotAddItems(player, entity, itemSlot, itemList, component)
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
    end

    -- The mod's input slot an item slot shows, or nil for any other slot.
    local function slotOf(itemSlot)
        local resource = itemSlot and itemSlot.resource
        if not resource or resource:getIO() ~= ResourceIO.Input then return nil end
        local entity = resource:getGameEntity()
        local component, extra = station(entity)
        if not component then return nil end
        return slotRecord(entity, component, extra, resource)
    end

    function ISItemSlot:defaultVerifyItem(itemSlot, item)
        if not vanillaVerifyItem(self, itemSlot, item) then return false end
        local slot = slotOf(itemSlot)
        return not slot or not refusal(slot, item, {})
    end

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
    function ISItemSlot:onMouseUp(x, y)
        local reason = dropRefusal(self)
        if reason then HaloTextHelper.addBadText(getPlayer(), getText(reason)) end
        return vanillaMouseUp(self, x, y)
    end

    if not rules.recipeRefusal then return end
    -- Loaded under one recipe, started under another: vanilla would run the new one on what it accepts and leave
    -- the rest in the slots, so Craft says why instead.
    local vanillaStartCraft = ISWidgetCraftLogicControl.startCraft
    function ISWidgetCraftLogicControl:startCraft()
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
    end
end

return SlotRules
