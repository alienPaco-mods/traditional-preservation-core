-- Traditional Preservation core: the cauldron's menu rows and Hearth Info rows, given to Hearth.attach as any mod's
-- attachment would give its own. The status row says what it holds; Pour into Cauldron takes a container of one fluid
-- (or a blend), Fill from Cauldron and Empty Cauldron only when it holds something; mods' rows (HearthUI.addMenu) go
-- between. Hearth Info shows its litres, fluid, heat and when it steams.
require "TimedActions/TPHearthCauldron"
local UI = require "TraditionalPreservationCore/UI"
local Hearth = require "TraditionalPreservationCore/Hearth"
local HearthUI = require "TraditionalPreservationCore/HearthUI"
require "TraditionalPreservationCore/Cauldron"

local say = UI.say
local CAULDRON_ICON = "media/textures/Item_TPCauldron.png"
local CAULDRON_FULL_ICON = "media/textures/Item_TPCauldronFull.png"
local IRON_COLOUR = { 0.42, 0.42, 0.44 }   -- the bar with nothing to colour it: the cauldron's iron

local litresText, degrees, fluidName, hoursText = UI.litres, UI.degrees, UI.fluidName, UI.hoursText
local tooltipFor, disableWith, findItems = UI.tooltip, UI.disable, UI.findItems

local function onHearthAction(playerObj, hearth, item, mode)
    if not luautils.walkAdj(playerObj, hearth:getSquare(), true) then return end
    if item then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    ISTimedActionQueue.add(TPHearthCauldron:new(playerObj, hearth, item, mode))
end

-- The cauldron's fluid by name; a blend names each, the largest share first.
local function holds(cauldron)
    local names = {}
    for name in pairs(Hearth.partsOf(cauldron)) do table.insert(names, name) end
    if #names < 2 then return fluidName(cauldron.fluid) end
    local parts = cauldron.parts
    table.sort(names, function(a, b) return parts[a] > parts[b] or (parts[a] == parts[b] and a < b) end)
    for index, name in ipairs(names) do names[index] = fluidName(name) end
    return table.concat(names, " + ")
end

local function cauldronStatus(cauldron)
    if (cauldron.ml or 0) <= 0 then return getText("IGUI_TraditionalPreservationCore_CauldronEmpty") end
    return say("IGUI_TraditionalPreservationCore_CauldronStatus", litresText(cauldron.ml), litresText(Hearth.CAULDRON_ML),
        holds(cauldron), degrees(cauldron.tempC))
end

-- Every container with a fluid in it. A mix, or a fluid that doesn't go with the cauldron's, shows in red with the
-- reason.
local function addPourInMenu(menu, playerObj, hearth, cauldron)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_PourIntoCauldron"))
    option.iconTexture = getTexture(CAULDRON_ICON)
    if (cauldron.ml or 0) >= Hearth.CAULDRON_ML then return disableWith(option, getText("IGUI_TraditionalPreservationCore_CauldronFull")) end
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
        elseif select(2, Hearth.cauldronRoom(cauldron, parts, 1)) == "Mixed" then
            refusal = say("IGUI_TraditionalPreservationCore_CauldronMixed", holds(cauldron))
        end
        if refusal then
            entry.notAvailable = true
            tooltipFor(entry, refusal)
        end
    end
end

-- Empty containers, and those holding the cauldron's fluid (or one that blends with it) with room left.
local function addFillMenu(menu, playerObj, hearth, cauldron)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_FillFromCauldron"))
    option.iconTexture = getTexture(CAULDRON_FULL_ICON)
    if not Hearth.poursOut(cauldron) then return disableWith(option, say("IGUI_TraditionalPreservationCore_CauldronStaysIn", holds(cauldron))) end
    local items = findItems(playerObj, function(item)
        local container = item:getFluidContainer()
        return container ~= nil and TPHearthCauldron.canFillFrom(container, cauldron)
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

-- Pours the cauldron away, whatever it holds: rotten milk would otherwise go out a container at a time.
local function addEmptyOption(menu, playerObj, hearth, cauldron)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_EmptyCauldron"), playerObj, onHearthAction,
        hearth, false, "empty")
    option.iconTexture = getTexture(CAULDRON_ICON)
    tooltipFor(option, say("IGUI_TraditionalPreservationCore_EmptyCauldronHelp", litresText(cauldron.ml), holds(cauldron)))
end

-- Steaming already, or when it will be while the fire burns on.
local function steamText(info)
    local cauldron = info.cauldron
    if Hearth.isHot(cauldron) then return getText("IGUI_TraditionalPreservationCore_InfoHotYes") end
    if info.banked then return getText("IGUI_TraditionalPreservationCore_InfoHotBanked") end
    local hotIn = info.lit and Hearth.hoursToHot(cauldron)
    if hotIn and hotIn <= info.burnHours then return say("IGUI_TraditionalPreservationCore_InfoHotIn", hoursText(hotIn)) end
    return getText("IGUI_TraditionalPreservationCore_InfoHotNo")
end

local function cauldronRows(window, y, info)
    local cauldron, ml = info.cauldron, info.cauldron.ml or 0
    y = window:bar(y, "IGUI_TraditionalPreservationCore_InfoCauldron", ml / Hearth.CAULDRON_ML, Hearth.liquidColour(cauldron) or IRON_COLOUR,
        say("IGUI_TraditionalPreservationCore_InfoLitres", litresText(ml), litresText(Hearth.CAULDRON_ML)))
    y = window:row(y, "IGUI_TraditionalPreservationCore_InfoFluid",
        ml > 0 and holds(cauldron) or getText("IGUI_TraditionalPreservationCore_InfoNothing"))
    y = window:row(y, "IGUI_TraditionalPreservationCore_InfoTemp",
        ml > 0 and say("IGUI_TraditionalPreservationCore_InfoDegrees", degrees(cauldron.tempC)) or "-")
    if ml > 0 then y = window:row(y, "IGUI_TraditionalPreservationCore_InfoHot", steamText(info)) end
    return y
end

local function cauldronNotes(info, notes)
    local ml = info.cauldron.ml or 0
    if ml <= 0 then
        table.insert(notes, getText("IGUI_TraditionalPreservationCore_HearthHelpEmpty"))
    elseif not info.lit then
        table.insert(notes, getText("IGUI_TraditionalPreservationCore_HearthHelpOut"))
    end
    if info.banked then table.insert(notes, getText("IGUI_TraditionalPreservationCore_HearthHelpBanked")) end
end

Hearth.attach({
    id = Hearth.CAULDRON,
    fitIcon = "media/textures/Item_TPCauldronFit.png",
    status = function(cauldron) return cauldronStatus(cauldron), (cauldron.ml or 0) > 0 and CAULDRON_FULL_ICON or CAULDRON_ICON end,
    menu = function(menu, playerObj, hearth, cauldron)
        addPourInMenu(menu, playerObj, hearth, cauldron)
        HearthUI.modRows(menu, playerObj, hearth, cauldron)
        if (cauldron.ml or 0) > 0 then
            addFillMenu(menu, playerObj, hearth, cauldron)
            addEmptyOption(menu, playerObj, hearth, cauldron)
        end
    end,
    rows = cauldronRows,
    notes = cauldronNotes,
})
