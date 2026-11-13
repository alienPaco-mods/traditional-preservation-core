-- Traditional Preservation core: the copper's menu rows and Hearth Info rows, given to Hearth.attach as any mod's
-- attachment would give its own. The status row says what it holds; Pour into Copper takes a container of one fluid
-- (or a blend), Fill from Copper and Empty Copper only when it holds something; mods' rows (HearthUI.addMenu) go
-- between. Hearth Info shows its litres, fluid, heat and when it steams.
require "TimedActions/TPHearthCopper"
local UI = require "TraditionalPreservationCore/UI"
local Hearth = require "TraditionalPreservationCore/Hearth"
local HearthUI = require "TraditionalPreservationCore/HearthUI"
require "TraditionalPreservationCore/Copper"

local say = UI.say
local COPPER_ICON = "media/textures/Item_TPCauldron.png"
local COPPER_FULL_ICON = "media/textures/Item_TPCauldronFull.png"
local COPPER_COLOUR = { 0.72, 0.45, 0.3 }

local litresText, degrees, fluidName, hoursText = UI.litres, UI.degrees, UI.fluidName, UI.hoursText
local tooltipFor, disableWith, findItems = UI.tooltip, UI.disable, UI.findItems

local function onHearthAction(playerObj, hearth, item, mode)
    if not luautils.walkAdj(playerObj, hearth:getSquare(), true) then return end
    if item then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    ISTimedActionQueue.add(TPHearthCopper:new(playerObj, hearth, item, mode))
end

-- The copper's fluid by name; a blend names each, the largest share first.
local function holds(copper)
    local names = {}
    for name in pairs(Hearth.partsOf(copper)) do table.insert(names, name) end
    if #names < 2 then return fluidName(copper.fluid) end
    local parts = copper.parts
    table.sort(names, function(a, b) return parts[a] > parts[b] or (parts[a] == parts[b] and a < b) end)
    for index, name in ipairs(names) do names[index] = fluidName(name) end
    return table.concat(names, " + ")
end

local function copperStatus(copper)
    if (copper.ml or 0) <= 0 then return getText("IGUI_TraditionalPreservationCore_CopperEmpty") end
    return say("IGUI_TraditionalPreservationCore_CopperStatus", litresText(copper.ml), litresText(Hearth.COPPER_ML),
        holds(copper), degrees(copper.tempC))
end

-- Every container with a fluid in it. A mix, or a fluid that doesn't go with the copper's, shows in red with the
-- reason.
local function addPourInMenu(menu, playerObj, hearth, copper)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_PourIntoCopper"))
    option.iconTexture = getTexture(COPPER_ICON)
    if (copper.ml or 0) >= Hearth.COPPER_ML then return disableWith(option, getText("IGUI_TraditionalPreservationCore_CopperFull")) end
    local items = findItems(playerObj, function(item)
        local container = item:getFluidContainer()
        return container ~= nil and not container:isEmpty()
    end)
    if #items == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationCore_NoFluidItem")) end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(items) do
        local container = item:getFluidContainer()
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationCore_FluidItem", UI.itemName(item),
            litresText(container:getAmount() * 1000)), playerObj, onHearthAction, hearth, item, "pourIn")
        -- Drawn as the inventory draws it: a bucket shows the colour of what is in it.
        entry.itemForTexture = item
        local parts = Hearth.partsIn(container)
        local refusal
        if not parts then
            refusal = getText("IGUI_TraditionalPreservationCore_NotOneFluid")
        elseif select(2, Hearth.copperRoom(copper, parts, 1)) == "Mixed" then
            refusal = say("IGUI_TraditionalPreservationCore_CopperMixed", holds(copper))
        end
        if refusal then
            entry.notAvailable = true
            tooltipFor(entry, refusal)
        end
    end
end

-- Empty containers, and those holding the copper's fluid (or one that blends with it) with room left.
local function addFillMenu(menu, playerObj, hearth, copper)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_FillFromCopper"))
    option.iconTexture = getTexture(COPPER_FULL_ICON)
    if not Hearth.poursOut(copper) then return disableWith(option, say("IGUI_TraditionalPreservationCore_CopperStaysIn", holds(copper))) end
    local items = findItems(playerObj, function(item)
        local container = item:getFluidContainer()
        return container ~= nil and TPHearthCopper.canFillFrom(container, copper)
    end)
    if #items == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationCore_NoRoomItem")) end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(items) do
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationCore_Holds", UI.itemName(item),
            litresText(item:getFluidContainer():getCapacity() * 1000)), playerObj, onHearthAction, hearth, item, "fillFrom")
        entry.itemForTexture = item
    end
end

-- Pours the copper away, whatever it holds: rotten milk would otherwise go out a container at a time.
local function addEmptyOption(menu, playerObj, hearth, copper)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_EmptyCopper"), playerObj, onHearthAction,
        hearth, false, "empty")
    option.iconTexture = getTexture(COPPER_ICON)
    tooltipFor(option, say("IGUI_TraditionalPreservationCore_EmptyCopperHelp", litresText(copper.ml), holds(copper)))
end

-- Steaming already, or when it will be while the fire burns on.
local function steamText(info)
    local copper = info.copper
    if Hearth.isHot(copper) then return getText("IGUI_TraditionalPreservationCore_InfoHotYes") end
    if info.banked then return getText("IGUI_TraditionalPreservationCore_InfoHotBanked") end
    local hotIn = info.lit and Hearth.hoursToHot(copper)
    if hotIn and hotIn <= info.burnHours then return say("IGUI_TraditionalPreservationCore_InfoHotIn", hoursText(hotIn)) end
    return getText("IGUI_TraditionalPreservationCore_InfoHotNo")
end

local function copperRows(window, y, info)
    local copper, ml = info.copper, info.copper.ml or 0
    y = window:bar(y, "IGUI_TraditionalPreservationCore_InfoCopper", ml / Hearth.COPPER_ML, COPPER_COLOUR,
        say("IGUI_TraditionalPreservationCore_InfoLitres", litresText(ml), litresText(Hearth.COPPER_ML)))
    y = window:row(y, "IGUI_TraditionalPreservationCore_InfoFluid",
        ml > 0 and holds(copper) or getText("IGUI_TraditionalPreservationCore_InfoNothing"))
    y = window:row(y, "IGUI_TraditionalPreservationCore_InfoTemp",
        ml > 0 and say("IGUI_TraditionalPreservationCore_InfoDegrees", degrees(copper.tempC)) or "-")
    if ml > 0 then y = window:row(y, "IGUI_TraditionalPreservationCore_InfoHot", steamText(info)) end
    return y
end

local function copperNotes(info, notes)
    local ml = info.copper.ml or 0
    if ml <= 0 then
        table.insert(notes, getText("IGUI_TraditionalPreservationCore_HearthHelpEmpty"))
    elseif not info.lit then
        table.insert(notes, getText("IGUI_TraditionalPreservationCore_HearthHelpOut"))
    end
    if info.banked then table.insert(notes, getText("IGUI_TraditionalPreservationCore_HearthHelpBanked")) end
end

Hearth.attach({
    id = Hearth.COPPER,
    fitIcon = "media/textures/Item_TPCauldronFit.png",
    status = function(copper) return copperStatus(copper), (copper.ml or 0) > 0 and COPPER_FULL_ICON or COPPER_ICON end,
    menu = function(menu, playerObj, hearth, copper)
        addPourInMenu(menu, playerObj, hearth, copper)
        HearthUI.modRows(menu, playerObj, hearth, copper)
        if (copper.ml or 0) > 0 then
            addFillMenu(menu, playerObj, hearth, copper)
            addEmptyOption(menu, playerObj, hearth, copper)
        end
    end,
    rows = copperRows,
    notes = copperNotes,
})
