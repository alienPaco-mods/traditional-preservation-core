-- Traditional Preservation core: the treat menu (a kind's treatments in FluidAgeing: Fish & Meat's Cure Blood). In the
-- container's own submenu (with vanilla's recipes for it), a submenu with each treatment and how much of it the player
-- carries, its tooltip saying the uses it takes; greyed, with the reason, when it can't be done. The action is
-- TPFluidTreat.
local FluidTreat = require "TraditionalPreservationCore/FluidTreat"
local UI = require "TraditionalPreservationCore/UI"
local Uses = require "TraditionalPreservationCore/Uses"

local function onTreat(playerObj, container, fluidKind, treatment)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, container)
    ISTimedActionQueue.add(TPFluidTreat:new(playerObj, container, fluidKind, treatment))
end

local function fillTreatMenu(playerNum, context, items)
    local container, fluidKind = UI.firstSelected(items, FluidTreat.treatableFluidKind)
    if not container then return end
    local playerObj = getSpecificPlayer(playerNum)
    local parent = UI.itemSubMenu(context, container):addOption(getText(fluidKind.treatMenu))
    parent.iconTexture = getTexture(fluidKind.treatments[1].icon)
    if fluidKind.treatTooltip then
        local about = ISWorldObjectContextMenu.addToolTip()
        about.description = getText(fluidKind.treatTooltip)
        parent.toolTip = about
    end
    local subMenu = context:getNew(context)
    context:addSubMenu(parent, subMenu)
    local litres = FluidTreat.litresIn(container:getFluidContainer(), fluidKind)
    local uses = FluidTreat.treatUses(fluidKind, litres)
    for _, treatment in ipairs(fluidKind.treatments) do
        -- The label counts what the player carries; the tooltip says what this takes.
        local owned = Uses.count(playerObj, treatment.tag())
        local option = subMenu:addOption(getText(treatment.label, tostring(owned)), playerObj, onTreat, container, fluidKind, treatment)
        option.iconTexture = getTexture(treatment.icon)
        local refusal = FluidTreat.treatRefusal(container, fluidKind, treatment, playerObj)
        option.notAvailable = refusal ~= nil
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = getText(refusal or "IGUI_TraditionalPreservationCore_TreatTakes", string.format("%.1f", litres),
            tostring(uses), tostring(owned))
        option.toolTip = tooltip
    end
end

Events.OnFillInventoryObjectContextMenu.Add(fillTreatMenu)
