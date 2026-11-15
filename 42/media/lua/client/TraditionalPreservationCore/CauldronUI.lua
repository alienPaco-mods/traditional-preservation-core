-- Traditional Preservation core: the cauldron's menu rows and Stone Hearth Info rows, given to Fire.attach as any mod's
-- attachment would give its own. The status row says what it holds; Pour into Cauldron takes a container of one fluid
-- (or a blend), Fill from Cauldron and Empty Cauldron only when it holds something; mods' rows (CauldronUI.addMenu) go
-- between. Stone Hearth Info shows its litres, fluid, heat and when it steams, then its notes and mods' (CauldronUI.addNotes).
require "TimedActions/TPCauldronWork"
local UI = require "TraditionalPreservationCore/UI"
local Fire = require "TraditionalPreservationCore/Fire"
require "TraditionalPreservationCore/Cauldron"

local CauldronUI = {}

local say = UI.say
local CAULDRON_ICON = "media/textures/Item_TPCauldron.png"
local CAULDRON_FULL_ICON = "media/textures/Item_TPCauldronFull.png"
local IRON_COLOUR = { 0.42, 0.42, 0.44 }   -- the bar with nothing to colour it: the cauldron's iron

local litresText, degrees, fluidName, hoursText = UI.litres, UI.degrees, UI.fluidName, UI.hoursText
local tooltipFor, disableWith, findItems = UI.tooltip, UI.disable, UI.findItems

local function mlOf(cauldron)
    return cauldron.ml or 0
end

local function onCauldronAction(playerObj, hearth, item, mode)
    if not luautils.walkAdj(playerObj, hearth:getSquare(), true) then return end
    if item then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    ISTimedActionQueue.add(TPCauldronWork:new(playerObj, hearth, item, mode))
end

-- The cauldron's fluid by name; a blend names each, the largest share first.
local function holds(cauldron)
    local parts = Fire.partsOf(cauldron)
    local names = {}
    for name in pairs(parts) do table.insert(names, name) end
    if #names < 2 then return fluidName(cauldron.fluid) end
    table.sort(names, function(a, b) return parts[a] > parts[b] or (parts[a] == parts[b] and a < b) end)
    for index, name in ipairs(names) do names[index] = fluidName(name) end
    return table.concat(names, " + ")
end

local function cauldronStatus(cauldron)
    if mlOf(cauldron) <= 0 then return getText("IGUI_TraditionalPreservationCore_CauldronEmpty") end
    return say("IGUI_TraditionalPreservationCore_CauldronStatus", litresText(cauldron.ml), litresText(Fire.CAULDRON_ML),
        holds(cauldron), degrees(cauldron.tempC))
end

-- The option's submenu: one entry per item, labelled by label(item), drawn as the inventory draws it (a bucket shows
-- the colour of what is in it), queuing mode on the hearth. Returns each entry with its item.
local function itemSubMenu(menu, option, playerObj, hearth, items, label, mode)
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    local entries = {}
    for _, item in ipairs(items) do
        local entry = sub:addOption(label(item), playerObj, onCauldronAction, hearth, item, mode)
        entry.itemForTexture = item
        table.insert(entries, { entry = entry, item = item })
    end
    return entries
end

-- Every container with a fluid in it. A mix, or a fluid that doesn't go with the cauldron's, shows in red with the
-- reason. One that taints the cauldron's, or is tainted by it, says the lot will be tainted (unless the sandbox keeps
-- the taint from the player), and that it boils clean again when it does.
local function addPourInMenu(menu, playerObj, hearth, cauldron)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_PourIntoCauldron"))
    option.iconTexture = getTexture(CAULDRON_ICON)
    if mlOf(cauldron) >= Fire.CAULDRON_ML then return disableWith(option, getText("IGUI_TraditionalPreservationCore_CauldronFull")) end
    local items = findItems(playerObj, function(item)
        local container = item:getFluidContainer()
        return container ~= nil and not container:isEmpty()
    end)
    if #items == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationCore_NoFluidItem")) end
    local entries = itemSubMenu(menu, option, playerObj, hearth, items, function(item)
        return say("ContextMenu_TraditionalPreservationCore_FluidItem", UI.itemName(item),
            litresText(item:getFluidContainer():getAmount() * 1000))
    end, "pourIn")
    for _, made in ipairs(entries) do
        local entry = made.entry
        local parts = Fire.partsIn(made.item:getFluidContainer())
        local refusal
        if not parts then
            refusal = getText("IGUI_TraditionalPreservationCore_NotOneFluid")
        elseif select(2, Fire.cauldronRoom(cauldron, parts, 1)) == "Mixed" then
            refusal = say("IGUI_TraditionalPreservationCore_CauldronMixed", holds(cauldron))
        end
        local tainted = not refusal and Fire.taintedBy(cauldron, parts)
        if refusal then
            entry.notAvailable = true
            tooltipFor(entry, refusal)
        elseif tainted and not UI.hidesTaint(tainted) then
            local lines = { say("IGUI_TraditionalPreservationCore_CauldronTaints", fluidName(tainted)) }
            if Fire.BOILED[tainted] then table.insert(lines, getText("IGUI_TraditionalPreservationCore_CauldronBoilAgain")) end
            tooltipFor(entry, table.concat(lines, " <LINE> "))
        end
    end
end

-- Empty containers, and those holding the cauldron's fluid (or one that blends with it) with room left.
local function addFillMenu(menu, playerObj, hearth, cauldron)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_FillFromCauldron"))
    option.iconTexture = getTexture(CAULDRON_FULL_ICON)
    if not Fire.poursOut(cauldron) then return disableWith(option, say("IGUI_TraditionalPreservationCore_CauldronStaysIn", holds(cauldron))) end
    local items = findItems(playerObj, function(item)
        local container = item:getFluidContainer()
        return container ~= nil and TPCauldronWork.canFillFrom(container, cauldron)
    end)
    if #items == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationCore_NoRoomItem")) end
    itemSubMenu(menu, option, playerObj, hearth, items, function(item)
        return say("ContextMenu_TraditionalPreservationCore_Holds", UI.itemName(item),
            litresText(item:getFluidContainer():getCapacity() * 1000))
    end, "fillFrom")
end

-- Pours the cauldron away, whatever it holds: rotten milk would otherwise go out a container at a time.
local function addEmptyOption(menu, playerObj, hearth, cauldron)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_EmptyCauldron"), playerObj, onCauldronAction,
        hearth, false, "empty")
    option.iconTexture = getTexture(CAULDRON_ICON)
    tooltipFor(option, say("IGUI_TraditionalPreservationCore_EmptyCauldronHelp", litresText(cauldron.ml), holds(cauldron)))
end

-- Steaming already, or when it will be while the fire burns on.
local function steamText(info)
    local cauldron = info.part
    if Fire.isHot(cauldron) then return getText("IGUI_TraditionalPreservationCore_InfoHotYes") end
    if info.banked then return getText("IGUI_TraditionalPreservationCore_InfoHotBanked") end
    local hotIn = info.lit and Fire.hoursToHot(cauldron)
    if hotIn and hotIn <= info.burnHours then return say("IGUI_TraditionalPreservationCore_InfoHotIn", hoursText(hotIn)) end
    return getText("IGUI_TraditionalPreservationCore_InfoHotNo")
end

local function cauldronRows(window, y, info)
    local cauldron, ml = info.part, mlOf(info.part)
    y = window:bar(y, "IGUI_TraditionalPreservationCore_InfoCauldron", ml / Fire.CAULDRON_ML, Fire.liquidColour(cauldron) or IRON_COLOUR,
        say("IGUI_TraditionalPreservationCore_InfoLitres", litresText(ml), litresText(Fire.CAULDRON_ML)))
    y = window:row(y, "IGUI_TraditionalPreservationCore_InfoFluid",
        ml > 0 and holds(cauldron) or getText("IGUI_TraditionalPreservationCore_InfoNothing"))
    y = window:row(y, "IGUI_TraditionalPreservationCore_InfoTemp",
        ml > 0 and say("IGUI_TraditionalPreservationCore_InfoDegrees", degrees(cauldron.tempC)) or "-")
    if ml > 0 then y = window:row(y, "IGUI_TraditionalPreservationCore_InfoHot", steamText(info)) end
    return y
end

local MENUS, NOTES = {}, {}

-- fn(menu, playerObj, hearth, cauldron) adds a mod's own rows to the cauldron's menu, after Pour into Cauldron.
function CauldronUI.addMenu(fn)
    table.insert(MENUS, fn)
end

-- fn(info, notes) adds lines to Stone Hearth Info's notes, after the cauldron's own; info.part is the cauldron's state
-- (FireUI.notes has the rest of info).
function CauldronUI.addNotes(fn)
    table.insert(NOTES, fn)
end

local function cauldronNotes(info, notes)
    if mlOf(info.part) <= 0 then
        table.insert(notes, getText("IGUI_TraditionalPreservationCore_CauldronHelpEmpty"))
    elseif not info.lit then
        table.insert(notes, getText("IGUI_TraditionalPreservationCore_CauldronHelpOut"))
    end
    if info.banked then table.insert(notes, getText("IGUI_TraditionalPreservationCore_CauldronHelpBanked")) end
    for _, fn in ipairs(NOTES) do fn(info, notes) end
end

Fire.attach({
    id = Fire.CAULDRON,
    fitIcon = "media/textures/Item_TPCauldronFit.png",
    display = { icon = "media/textures/Item_TPStoneHearthCauldron.png", title = "IGUI_CraftingWindow_TPStoneHearthCauldron",
        info = "ContextMenu_TraditionalPreservationCore_StoneHearthCauldronInfo",
        fire = { bank = "media/textures/Item_TPStoneHearthCauldronBanked.png", stoke = "media/textures/Item_TPStoneHearthCauldronLit.png" } },
    status = function(cauldron) return cauldronStatus(cauldron), mlOf(cauldron) > 0 and CAULDRON_FULL_ICON or CAULDRON_ICON end,
    menu = function(menu, playerObj, hearth, cauldron)
        addPourInMenu(menu, playerObj, hearth, cauldron)
        for _, fn in ipairs(MENUS) do fn(menu, playerObj, hearth, cauldron) end
        if mlOf(cauldron) > 0 then
            addFillMenu(menu, playerObj, hearth, cauldron)
            addEmptyOption(menu, playerObj, hearth, cauldron)
        end
    end,
    rows = cauldronRows,
    notes = cauldronNotes,
})

return CauldronUI
