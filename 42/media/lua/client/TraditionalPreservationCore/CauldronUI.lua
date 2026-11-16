-- Traditional Preservation core: the cauldron's menu rows and its fire's Info rows (Stone Hearth Info), given to Fire.attach as any mod's
-- attachment would give its own. The status row says what it holds; Pour into Cauldron takes a container of one fluid
-- (or a blend), Fill from Cauldron and Empty Cauldron only when it holds something; mods' rows (CauldronUI.addMenu) go
-- between. The fire's Info shows its litres, fluid, heat and when it steams, then its notes and mods' (CauldronUI.addNotes).
require "TimedActions/TPCauldronWork"
local UI = require "TraditionalPreservationCore/UI"
local Fire = require "TraditionalPreservationCore/Fire"
local Cauldron = require "TraditionalPreservationCore/Cauldron"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local PiecesUI = require "TraditionalPreservationCore/PiecesUI"
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

local function onCauldronAction(playerObj, fire, item, mode)
    if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    if item then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    ISTimedActionQueue.add(TPCauldronWork:new(playerObj, fire, item, mode))
end

-- The cauldron's fluid by name; a blend names each, the largest share first.
local function holds(cauldron)
    local parts = CauldronFluid.partsOf(cauldron)
    local names = {}
    for name in pairs(parts) do table.insert(names, name) end
    if #names < 2 then return fluidName(cauldron.fluid) end
    table.sort(names, function(a, b) return parts[a] > parts[b] or (parts[a] == parts[b] and a < b) end)
    for index, name in ipairs(names) do names[index] = fluidName(name) end
    return table.concat(names, " + ")
end

local function cauldronStatus(cauldron)
    if mlOf(cauldron) <= 0 then return getText("IGUI_TraditionalPreservationCore_CauldronEmpty") end
    return say("IGUI_TraditionalPreservationCore_CauldronStatus", litresText(cauldron.ml), litresText(CauldronFluid.CAULDRON_ML),
        holds(cauldron), degrees(cauldron.tempC))
end

-- The option's submenu: one option per item, labelled by label(item), drawn as the inventory draws it (a bucket shows
-- the colour of what is in it), queuing mode on the fire. Returns each option with its item.
local function itemSubMenu(menu, option, playerObj, fire, items, label, mode)
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    local rows = {}
    for _, item in ipairs(items) do
        local itemOption = sub:addOption(label(item), playerObj, onCauldronAction, fire, item, mode)
        itemOption.itemForTexture = item
        table.insert(rows, { option = itemOption, item = item })
    end
    return rows
end

-- Every container with a fluid in it. A mix, or a fluid that doesn't go with the cauldron's, shows in red with the
-- reason. One that taints the cauldron's, or is tainted by it, says the lot will be tainted (unless the sandbox keeps
-- the taint from the player), and that it boils clean again when it does.
local function addPourInMenu(menu, playerObj, fire, cauldron)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_PourIntoCauldron"))
    option.iconTexture = getTexture(CAULDRON_ICON)
    if mlOf(cauldron) >= CauldronFluid.CAULDRON_ML then return disableWith(option, getText("IGUI_TraditionalPreservationCore_CauldronFull")) end
    local items = findItems(playerObj, function(item)
        local container = item:getFluidContainer()
        return container ~= nil and not container:isEmpty()
    end)
    if #items == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationCore_NoFluidItem")) end
    local rows = itemSubMenu(menu, option, playerObj, fire, items, function(item)
        return say("ContextMenu_TraditionalPreservationCore_FluidItem", UI.itemName(item),
            litresText(item:getFluidContainer():getAmount() * 1000))
    end, "pourIn")
    for _, row in ipairs(rows) do
        local option = row.option
        local parts = CauldronFluid.partsIn(row.item:getFluidContainer())
        local refusal
        if not parts then
            refusal = getText("IGUI_TraditionalPreservationCore_NotOneFluid")
        elseif select(2, CauldronFluid.cauldronRoom(cauldron, parts, 1)) == "Mixed" then
            refusal = say("IGUI_TraditionalPreservationCore_CauldronMixed", holds(cauldron))
        end
        local tainted = not refusal and CauldronFluid.taintedBy(cauldron, parts)
        if refusal then
            option.notAvailable = true
            tooltipFor(option, refusal)
        elseif tainted and not UI.hidesTaint(tainted) then
            local lines = { say("IGUI_TraditionalPreservationCore_CauldronTaints", fluidName(tainted)) }
            if CauldronFluid.BOILED[tainted] then table.insert(lines, getText("IGUI_TraditionalPreservationCore_CauldronBoilAgain")) end
            tooltipFor(option, table.concat(lines, " <LINE> "))
        end
    end
end

-- Empty containers, and those holding the cauldron's fluid (or one that blends with it) with room left.
local function addFillMenu(menu, playerObj, fire, cauldron)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_FillFromCauldron"))
    option.iconTexture = getTexture(CAULDRON_FULL_ICON)
    if not CauldronFluid.poursOut(cauldron) then return disableWith(option, say("IGUI_TraditionalPreservationCore_CauldronStaysIn", holds(cauldron))) end
    local items = findItems(playerObj, function(item)
        local container = item:getFluidContainer()
        return container ~= nil and TPCauldronWork.canFillFrom(container, cauldron)
    end)
    if #items == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationCore_NoRoomItem")) end
    itemSubMenu(menu, option, playerObj, fire, items, function(item)
        return say("ContextMenu_TraditionalPreservationCore_Holds", UI.itemName(item),
            litresText(item:getFluidContainer():getCapacity() * 1000))
    end, "fillFrom")
end

-- Pours the cauldron away, whatever it holds: rotten milk would otherwise go out a container at a time.
local function addEmptyOption(menu, playerObj, fire, cauldron)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_EmptyCauldron"), playerObj, onCauldronAction,
        fire, false, "empty")
    option.iconTexture = getTexture(CAULDRON_ICON)
    tooltipFor(option, say("IGUI_TraditionalPreservationCore_EmptyCauldronHelp", litresText(cauldron.ml), holds(cauldron)))
end

-- Steaming already, or when it will be while the fire burns on.
local function steamText(fireView)
    local cauldron = fireView.part
    if CauldronFluid.isHot(cauldron) then return getText("IGUI_TraditionalPreservationCore_InfoHotYes") end
    if fireView.banked then return getText("IGUI_TraditionalPreservationCore_InfoHotBanked") end
    local hotIn = fireView.lit and CauldronFluid.hoursToHot(cauldron)
    if hotIn and hotIn <= fireView.burnHours then return say("IGUI_TraditionalPreservationCore_InfoHotIn", hoursText(hotIn)) end
    return getText("IGUI_TraditionalPreservationCore_InfoHotNo")
end

local function cauldronRows(window, y, fireView)
    local cauldron, ml = fireView.part, mlOf(fireView.part)
    y = window:bar(y, "IGUI_TraditionalPreservationCore_InfoCauldron", ml / CauldronFluid.CAULDRON_ML, CauldronFluid.liquidColour(cauldron) or IRON_COLOUR,
        say("IGUI_TraditionalPreservationCore_InfoLitres", litresText(ml), litresText(CauldronFluid.CAULDRON_ML)))
    y = window:row(y, "IGUI_TraditionalPreservationCore_InfoFluid",
        ml > 0 and holds(cauldron) or getText("IGUI_TraditionalPreservationCore_InfoNothing"))
    y = window:row(y, "IGUI_TraditionalPreservationCore_InfoTemp",
        ml > 0 and say("IGUI_TraditionalPreservationCore_InfoDegrees", degrees(cauldron.tempC)) or "-")
    if ml > 0 then y = window:row(y, "IGUI_TraditionalPreservationCore_InfoHot", steamText(fireView)) end
    return y
end

local MENUS, NOTES = {}, {}

-- fn(menu, playerObj, fire, cauldron) adds a mod's own rows to the cauldron's menu, after Pour into Cauldron.
function CauldronUI.addMenu(fn)
    table.insert(MENUS, fn)
end

-- fn(fireView, notes) adds lines to the fire's Info notes, after the cauldron's own; fireView.part is the cauldron's modData
-- (FireUI.notes has the rest of fireView).
function CauldronUI.addNotes(fn)
    table.insert(NOTES, fn)
end

-- A menu row putting pieces in the cauldron as a fluid (PiecesUI, TPPutPieces), with a sub-row for each fluid carried,
-- the pieces counted and rotten ones left out, One or All; only someone carrying some sees it. piecesMenu: { title,
-- icon (a texture name), pieceMl, hoursLeft = function(item), fluidRows = { { fluid, items = { [fullType] = true }, label = function(count) } },
-- help, noRoom (finished text), refusal = optional function(playerObj) giving finished text when the player can't }.
function CauldronUI.addPieces(piecesMenu)
    CauldronUI.addMenu(function(menu, playerObj, fire, cauldron)
        local carried = {}
        for _, fluidRow in ipairs(piecesMenu.fluidRows) do
            local pieces = findItems(playerObj, function(item) return fluidRow.items[item:getFullType()] and not item:isRotten() end)
            if #pieces > 0 then table.insert(carried, { fluidRow = fluidRow, pieces = pieces }) end
        end
        if #carried == 0 then return end
        local option = menu:addOption(piecesMenu.title)
        option.iconTexture = getTexture(piecesMenu.icon)
        local sub = menu:getNew(menu)
        menu:addSubMenu(option, sub)
        local refusal = piecesMenu.refusal and piecesMenu.refusal(playerObj)
        for _, carriedRow in ipairs(carried) do
            local asFluid = { fluid = carriedRow.fluidRow.fluid, pieceMl = piecesMenu.pieceMl, hoursLeft = piecesMenu.hoursLeft }
            local row = PiecesUI.row(sub, { label = carriedRow.fluidRow.label(#carriedRow.pieces),
                room = CauldronFluid.pieceRoom(cauldron, carriedRow.fluidRow.fluid, piecesMenu.pieceMl),
                pieces = PiecesUI.oldestFirst(carriedRow.pieces, piecesMenu.hoursLeft),
                refusal = refusal, help = piecesMenu.help, noRoom = piecesMenu.noRoom }, function(chosen)
                if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
                PiecesUI.queue(playerObj, Cauldron.piecesInto(fire), asFluid, chosen)
            end)
            row.itemForTexture = carriedRow.pieces[1]
        end
    end)
end

local function cauldronNotes(fireView, notes)
    if mlOf(fireView.part) <= 0 then
        table.insert(notes, getText("IGUI_TraditionalPreservationCore_CauldronHelpEmpty"))
    elseif not fireView.lit then
        table.insert(notes, getText("IGUI_TraditionalPreservationCore_CauldronHelpOut"))
    end
    if fireView.banked then table.insert(notes, getText("IGUI_TraditionalPreservationCore_CauldronHelpBanked")) end
    for _, fn in ipairs(NOTES) do fn(fireView, notes) end
end

Fire.attach({
    id = Cauldron.ID,
    fitIcon = "media/textures/Item_TPCauldronFit.png",
    display = { icon = "media/textures/Item_TPStoneHearthCauldron.png", title = "IGUI_CraftingWindow_TPStoneHearthCauldron",
        infoText = "ContextMenu_TraditionalPreservationCore_StoneHearthCauldronInfo",
        fire = { bank = "media/textures/Item_TPStoneHearthCauldronBanked.png", stoke = "media/textures/Item_TPStoneHearthCauldronLit.png" } },
    status = function(cauldron) return cauldronStatus(cauldron), mlOf(cauldron) > 0 and CAULDRON_FULL_ICON or CAULDRON_ICON end,
    menu = function(menu, playerObj, fire, cauldron)
        addPourInMenu(menu, playerObj, fire, cauldron)
        for _, fn in ipairs(MENUS) do fn(menu, playerObj, fire, cauldron) end
        if mlOf(cauldron) > 0 then
            addFillMenu(menu, playerObj, fire, cauldron)
            addEmptyOption(menu, playerObj, fire, cauldron)
        end
    end,
    rows = cauldronRows,
    notes = cauldronNotes,
})

return CauldronUI
