-- Traditional Preservation core: a loot window brings the fluids in the containers it shows up to date (FluidAgeing), so
-- milk left in a fridge or a cupboard has turned by the time anyone looks at it. An item is looked at as it is moved,
-- while it is still where it was: taken off a stove, its heat is still the stove's, so hot milk scalds.
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local FluidTreat = require "TraditionalPreservationCore/FluidTreat"
local Transfer = require "TraditionalPreservationCore/Transfer"
local UI = require "TraditionalPreservationCore/UI"
local Uses = require "TraditionalPreservationCore/Uses"

Events.OnRefreshInventoryWindowContainers.Add(function(page, reason)
    if reason ~= "end" or page.onCharacter then return end
    local now = getGameTime():getWorldAgeHours()
    for _, button in ipairs(page.backpacks or {}) do FluidAgeing.lookIn(button.inventory, now) end
end)

Transfer.before(function(_, item)
    if item:getFluidContainer() then FluidAgeing.look(item, getGameTime():getWorldAgeHours()) end
end)

-- The treat menu (a kind's treatments: Fish & Meat's Cure Blood): in the container's own submenu (with vanilla's
-- recipes for it), a submenu with each treatment and how much of it the player carries, its tooltip saying the uses it
-- takes; greyed, with the reason, when it can't be done.
local function onTreat(playerObj, container, spec, treatment)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, container)
    ISTimedActionQueue.add(TPFluidTreat:new(playerObj, container, spec, treatment))
end

-- The first selected item holding a kind with treatments. A collapsed stack lists its first item twice.
local function firstTreatable(items)
    for _, entry in ipairs(items) do
        local item = instanceof(entry, "InventoryItem") and entry or (entry.items and entry.items[1])
        local spec = item and FluidTreat.treatableSpec(item)
        if spec then return item, spec end
    end
end

local function fillTreatMenu(playerNum, context, items)
    local container, spec = firstTreatable(items)
    if not container then return end
    local playerObj = getSpecificPlayer(playerNum)
    local parent = UI.itemSubMenu(context, container):addOption(getText(spec.treatMenu))
    parent.iconTexture = getTexture(spec.treatments[1].icon)
    if spec.treatTooltip then
        local about = ISWorldObjectContextMenu.addToolTip()
        about.description = getText(spec.treatTooltip)
        parent.toolTip = about
    end
    local subMenu = context:getNew(context)
    context:addSubMenu(parent, subMenu)
    local litres = FluidTreat.litresIn(container:getFluidContainer(), spec)
    local uses = FluidTreat.treatUses(spec, litres)
    for _, treatment in ipairs(spec.treatments) do
        -- The label counts what the player carries; the tooltip says what this takes.
        local owned = Uses.count(playerObj, treatment.tag())
        local option = subMenu:addOption(getText(treatment.label, tostring(owned)), playerObj, onTreat, container, spec, treatment)
        option.iconTexture = getTexture(treatment.icon)
        local refusal = FluidTreat.treatRefusal(container, spec, treatment, playerObj)
        option.notAvailable = refusal ~= nil
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = getText(refusal or "IGUI_TraditionalPreservationCore_TreatTakes", string.format("%.1f", litres),
            tostring(uses), tostring(owned))
        option.toolTip = tooltip
    end
end

Events.OnFillInventoryObjectContextMenu.Add(fillTreatMenu)
