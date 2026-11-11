-- Traditional Preservation core: the Hearth is worked from its right-click menu. Vanilla's own menu lights and feeds
-- the fire; ours, inside vanilla's Hearth submenu, shows the copper and pours a fluid into it, fills a container
-- from it or empties it, and banks a lit fire or stokes it up again. Hearth Info, also on the menu, shows the fire, its fuel and the copper. A Hearth can't be picked up while
-- it burns or its copper holds anything. Clicking a Hearth opens Hearth Info too. Mods add their own notes to Hearth
-- Info with HearthUI.addNotes.
-- A Firebox has the same menu without the copper: Firebox Info and Bank / Stoke, plus a mod's rows
-- (HearthUI.addFireboxMenu, Fish & Meat's flue) and notes (HearthUI.addFireboxNotes).
require "TimedActions/TPHearthCopper"
require "TimedActions/TPHearthFire"
local UI = require "TraditionalPreservationCore/UI"
local Hearth = require "TraditionalPreservationCore/Hearth"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"

local HearthUI = {}

local say = UI.say
local HEARTH_ICON = "media/textures/Item_TPHearth.png"
local COPPER_ICON = "media/textures/Item_TPCopper.png"
local COPPER_FULL_ICON = "media/textures/Item_TPCopperFull.png"
local FIRE_ICONS = { bank = "media/textures/Item_TPHearthBanked.png", stoke = "media/textures/Item_TPHearthLit.png" }
local FIREBOX_ICON = "media/textures/Item_TPFirebox.png"
local FIREBOX_FIRE_ICONS = { bank = "media/textures/Item_TPFireboxBanked.png", stoke = "media/textures/Item_TPFireboxLit.png" }
local FUEL_SCALE_MIN = 12 * 60 -- a full Fuel bar: 12 hours of burning
local BAR_COLOURS = { fuel = { 0.75, 0.42, 0.18 }, copper = { 0.72, 0.45, 0.3 } }

local litresText, degrees, fluidName, hoursText = UI.litres, UI.degrees, UI.fluidName, UI.hoursText
local tooltipFor, disableWith, findItems = UI.tooltip, UI.disable, UI.findItems

-- Menu

local function onHearthAction(playerObj, hearth, item, mode)
    if not luautils.walkAdj(playerObj, hearth:getSquare(), true) then return end
    if item then ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    ISTimedActionQueue.add(TPHearthCopper:new(playerObj, hearth, item, mode))
end

local function onFireAction(playerObj, hearth, mode)
    if not luautils.walkAdj(playerObj, hearth:getSquare(), true) then return end
    ISTimedActionQueue.add(TPHearthFire:new(playerObj, hearth, mode))
end

HearthUI.fireAction = onFireAction
HearthUI.FIRE_ICONS = FIRE_ICONS

-- The Hearth or the Firebox as its fire will be, banked or burning up again.
function HearthUI.fireIcon(fire, mode)
    return (Hearth.isFirebox(fire) and FIREBOX_FIRE_ICONS or FIRE_ICONS)[mode]
end

local function addFireOption(menu, playerObj, hearth)
    if not Hearth.isBurning(hearth) then return end
    local banked = Hearth.isBanked(hearth)
    local mode = banked and "stoke" or "bank"
    local option = menu:addOption(getText(banked and "ContextMenu_TraditionalPreservationCore_StokeFire"
        or "ContextMenu_TraditionalPreservationCore_BankFire"), playerObj, onFireAction, hearth, mode)
    -- The Hearth as the fire will be: banked, or burning up again.
    option.iconTexture = getTexture(HearthUI.fireIcon(hearth, mode))
    tooltipFor(option, getText(banked and "IGUI_TraditionalPreservationCore_StokeHelp" or "IGUI_TraditionalPreservationCore_BankHelp"))
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

-- Vanilla gives every fire its own submenu, named after the tile (ISBBQMenu): the copper's options go in there too,
-- so there is one Hearth menu, not two.
local function hearthSubMenu(context, hearth)
    local vanilla = context:getOptionFromName(hearth:getTileName())
    local menu = vanilla and vanilla.subOption and context:getSubMenu(vanilla.subOption)
    if menu then return menu end
    local firebox = Hearth.isFirebox(hearth)
    local option = context:addOption(getText(firebox and "IGUI_CraftingWindow_TPFirebox" or "IGUI_CraftingWindow_TPHearth"))
    option.iconTexture = getTexture(firebox and FIREBOX_ICON or HEARTH_ICON)
    menu = context:getNew(context)
    context:addSubMenu(option, menu)
    return menu
end

-- A banked Hearth's vanilla fire is out, so vanilla's fuel line says Unlit: it says Banked, with the time the embers
-- burn on.
local function fixFuelLine(menu, hearth)
    if not Hearth.isBanked(hearth) then return end
    local unlit = " (" .. getText("IGUI_Fireplace_Unlit") .. ")"
    for _, option in ipairs(menu.options or {}) do
        if type(option.name) == "string" and option.name:sub(-#unlit) == unlit then
            option.name = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(math.floor(Hearth.fuelHours(hearth) * 60 + 0.5)))
                .. " (" .. getText("IGUI_TraditionalPreservationCore_InfoFireBanked") .. ")"
        end
    end
end

-- Vanilla offers to light a fire that is out: a banked Hearth's is, so Put out Fire takes its place there (in the
-- right-click menu and the loot window's controller menu), and it unbanks.
local doLightFireOption = ISCampingMenu.doLightFireOption
function ISCampingMenu.doLightFireOption(playerObj, context, worldobjects, hasFuel, fuelInfo, target, ...)
    if instanceof(target, "IsoFireplace") and Hearth.isBanked(target) then
        return context:addOption(getText("ContextMenu_Put_out_fire"), playerObj, onFireAction, target, "out")
    end
    return doLightFireOption(playerObj, context, worldobjects, hasFuel, fuelInfo, target, ...)
end

local HearthWindow -- below

local MENUS = {}

-- fn(menu, playerObj, hearth, copper) adds a mod's own rows to the Hearth's menu, after Pour into Copper.
function HearthUI.addMenu(fn)
    table.insert(MENUS, fn)
end

local function addHearthMenu(context, playerObj, hearth)
    local copper = Hearth.copperOf(hearth)
    local menu = hearthSubMenu(context, hearth)
    fixFuelLine(menu, hearth)

    local status = menu:addOption(copperStatus(copper))
    status.isDisabled = true
    status.iconTexture = getTexture((copper.ml or 0) > 0 and COPPER_FULL_ICON or COPPER_ICON)
    local info = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_HearthInfo"), playerObj, HearthWindow.open, hearth)
    info.iconTexture = getTexture(HEARTH_ICON)
    addFireOption(menu, playerObj, hearth)
    addPourInMenu(menu, playerObj, hearth, copper)
    for _, fn in ipairs(MENUS) do fn(menu, playerObj, hearth, copper) end
    if (copper.ml or 0) > 0 then
        addFillMenu(menu, playerObj, hearth, copper)
        addEmptyOption(menu, playerObj, hearth, copper)
    end
end

local FIREBOX_MENUS = {}

-- fn(menu, playerObj, firebox, state) adds a mod's own rows to the Firebox's menu, after Bank / Stoke.
function HearthUI.addFireboxMenu(fn)
    table.insert(FIREBOX_MENUS, fn)
end

local function addFireboxMenu(context, playerObj, firebox)
    local state = Hearth.copperOf(firebox)
    local menu = hearthSubMenu(context, firebox)
    fixFuelLine(menu, firebox)
    local info = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_FireboxInfo"), playerObj, HearthWindow.open, firebox)
    info.iconTexture = getTexture(FIREBOX_ICON)
    addFireOption(menu, playerObj, firebox)
    for _, fn in ipairs(FIREBOX_MENUS) do fn(menu, playerObj, firebox, state) end
end

local function onFillContextMenu(playerNum, context, worldobjects, test)
    for _, object in ipairs(worldobjects) do
        if Hearth.isFire(object) then
            -- Vanilla's probe for a controller's prompt: say there is a menu, do no work.
            if test then return ISWorldObjectContextMenu.setTest() end
            -- A hearth built this session isn't tracked until its area reloads, so its menu starts it.
            if Hearth.World then Hearth.World.track(object) end
            if Hearth.isFirebox(object) then return addFireboxMenu(context, getSpecificPlayer(playerNum), object) end
            return addHearthMenu(context, getSpecificPlayer(playerNum), object)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

-- Picking the Hearth up while the fire burns (lit or banked) or the copper holds anything would lose them; a
-- Firebox, while its fire burns.
UI.keepInPlace(function(object)
    if Hearth.isFirebox(object) then return Hearth.isBurning(object) end
    return Hearth.isHearth(object) and (Hearth.isBurning(object) or (Hearth.stateOf(object:getModData()).ml or 0) > 0)
end)

-- Hearth Info: the fire, its fuel and the copper.

local NOTES, FIREBOX_NOTES = {}, {}

-- fn(info, notes) adds lines to Hearth Info's notes. info = { copper, lit, banked, fuelMin, burnHours }.
function HearthUI.addNotes(fn)
    table.insert(NOTES, fn)
end

-- The same for Firebox Info: info = { copper (its state: flue, flueSide), lit, banked, fuelMin, burnHours, firebox }.
function HearthUI.addFireboxNotes(fn)
    table.insert(FIREBOX_NOTES, fn)
end

HearthWindow = InfoWindow:derive("TraditionalPreservationCoreHearthWindow")
HearthUI.HearthWindow = HearthWindow

function HearthWindow:new(playerObj, hearth)
    local o = InfoWindow.new(self, playerObj, hearth)
    o.title = getText(Hearth.isFirebox(hearth) and "IGUI_CraftingWindow_TPFirebox" or "IGUI_CraftingWindow_TPHearth")
    return o
end

function HearthWindow.open(playerObj, hearth)
    InfoWindow.open(HearthWindow, playerObj, hearth)
end

function HearthWindow:refresh()
    local hearth = self.station
    self.info = { copper = Hearth.copperOf(hearth), lit = Hearth.isBurning(hearth), banked = Hearth.isBanked(hearth),
        fuelMin = hearth:getFuelAmount(), burnHours = Hearth.fuelHours(hearth), firebox = Hearth.isFirebox(hearth) }
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

function HearthWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.info then return end
    local info = self.info
    local copper, ml = info.copper, info.copper.ml or 0
    local y = self:top()

    local fire = info.banked and "IGUI_TraditionalPreservationCore_InfoFireBanked"
        or info.lit and "IGUI_TraditionalPreservationCore_InfoFireLit" or "IGUI_TraditionalPreservationCore_InfoFireOut"
    y = self:row(y, "IGUI_TraditionalPreservationCore_InfoFire", getText(fire))
    -- The bar is the wood; the time is how long it burns, three times as long banked.
    local burnMin = math.floor(info.burnHours * 60)
    y = self:bar(y, "IGUI_TraditionalPreservationCore_InfoFuel", info.fuelMin / FUEL_SCALE_MIN, BAR_COLOURS.fuel,
        say("IGUI_TraditionalPreservationCore_InfoFuelValue", tostring(math.floor(burnMin / 60)), tostring(burnMin % 60)))
    if info.firebox then
        local notes = { getText(info.banked and "IGUI_TraditionalPreservationCore_FireboxHelpBanked"
            or info.lit and "IGUI_TraditionalPreservationCore_FireboxHelpLit" or "IGUI_TraditionalPreservationCore_FireboxHelpOut") }
        for _, fn in ipairs(FIREBOX_NOTES) do fn(info, notes) end
        self:drawNotes(y, notes)
        return
    end
    y = self:bar(y, "IGUI_TraditionalPreservationCore_InfoCopper", ml / Hearth.COPPER_ML, BAR_COLOURS.copper,
        say("IGUI_TraditionalPreservationCore_InfoLitres", litresText(ml), litresText(Hearth.COPPER_ML)))
    y = self:row(y, "IGUI_TraditionalPreservationCore_InfoFluid",
        ml > 0 and holds(copper) or getText("IGUI_TraditionalPreservationCore_InfoNothing"))
    y = self:row(y, "IGUI_TraditionalPreservationCore_InfoTemp",
        ml > 0 and say("IGUI_TraditionalPreservationCore_InfoDegrees", degrees(copper.tempC)) or "-")
    if ml > 0 then y = self:row(y, "IGUI_TraditionalPreservationCore_InfoHot", steamText(info)) end

    local notes = {}
    if ml <= 0 then
        table.insert(notes, getText("IGUI_TraditionalPreservationCore_HearthHelpEmpty"))
    elseif not info.lit then
        table.insert(notes, getText("IGUI_TraditionalPreservationCore_HearthHelpOut"))
    end
    if info.banked then table.insert(notes, getText("IGUI_TraditionalPreservationCore_HearthHelpBanked")) end
    for _, fn in ipairs(NOTES) do fn(info, notes) end
    self:drawNotes(y, notes)
end

-- Clicking a Hearth or Firebox opens its Info, as clicking a TP station opens its window (its firebox is still in the loot
-- window beside it).
InfoWindow.clickOpens(Hearth.isFire, function(playerObj, hearth)
    if Hearth.World then Hearth.World.track(hearth) end
    HearthWindow.open(playerObj, hearth)
end)

return HearthUI
