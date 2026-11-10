-- Traditional Preservation core: the Hearth is worked from its right-click menu. Vanilla's own menu lights and feeds
-- the fire; ours, inside vanilla's Hearth submenu, shows the copper and pours a fluid into it or fills a container
-- from it. Hearth Info, also on the menu, shows the fire, its fuel and the copper. A Hearth can't be picked up while
-- it burns or its copper holds anything. Clicking a Hearth opens Hearth Info too. Mods add their own notes to Hearth
-- Info with HearthUI.addNotes.
require "TimedActions/ISHearthCopper"
require "Moveables/ISMoveableSpriteProps"
local UI = require "TraditionalPreservationCore/UI"
local Hearth = require "TraditionalPreservationCore/Hearth"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"

local HearthUI = {}

local say = UI.say
local HEARTH_ICON = "media/textures/Item_TPHearth.png"
local POUR_ICON = "Item_Pot_Water"
local FUEL_SCALE_MIN = 12 * 60 -- a full Fuel bar: 12 hours of burning
local BAR_COLOURS = { fuel = { 0.75, 0.42, 0.18 }, copper = { 0.72, 0.45, 0.3 } }

local function litresText(ml)
    return string.format("%.1f", ml / 1000)
end

local function degrees(celsius)
    return string.format("%.0f", celsius)
end

local function fluidName(name)
    local fluid = name and Fluid.Get(name)
    return fluid and fluid:getTranslatedName() or tostring(name)
end

-- Whole hours, or "under an hour".
local function hoursText(hours)
    if hours <= 1 then return getText("IGUI_TraditionalPreservationCore_UnderHour") end
    return say("IGUI_TraditionalPreservationCore_Hours", tostring(math.ceil(hours)))
end

local function tooltipFor(option, text)
    local tooltip = ISWorldObjectContextMenu.addToolTip()
    tooltip.description = text
    option.toolTip = tooltip
end

local function disableWith(option, text)
    option.isDisabled = true
    tooltipFor(option, text)
end

-- Every item on the player or in containers in reach that passes test.
local function findItems(playerObj, test)
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

-- Menu

local function onHearthAction(playerObj, hearth, item, mode)
    if not luautils.walkAdj(playerObj, hearth:getSquare(), true) then return end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    ISTimedActionQueue.add(ISHearthCopper:new(playerObj, hearth, item, mode))
end

local function copperStatus(copper)
    if (copper.ml or 0) <= 0 then return getText("IGUI_TraditionalPreservationCore_CopperEmpty") end
    return say("IGUI_TraditionalPreservationCore_CopperStatus", litresText(copper.ml), litresText(Hearth.COPPER_ML),
        fluidName(copper.fluid), degrees(copper.tempC))
end

-- Every container with a fluid in it. A mix, or a fluid other than the copper's, shows in red with the reason.
local function addPourInMenu(menu, playerObj, hearth, copper)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_PourIntoCopper"))
    option.iconTexture = getTexture(POUR_ICON)
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
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationCore_FluidItem", item:getDisplayName(),
            litresText(container:getAmount() * 1000)), playerObj, onHearthAction, hearth, item, "pourIn")
        entry.iconTexture = item:getTex()
        local fluid = ISHearthCopper.fluidIn(container)
        local refusal
        if not fluid then
            refusal = getText("IGUI_TraditionalPreservationCore_NotOneFluid")
        elseif select(2, Hearth.copperRoom(copper, fluid, 1)) == "Mixed" then
            refusal = say("IGUI_TraditionalPreservationCore_CopperMixed", fluidName(copper.fluid))
        end
        if refusal then
            entry.notAvailable = true
            tooltipFor(entry, refusal)
        end
    end
end

-- Empty containers, and those holding the copper's fluid with room left.
local function addFillMenu(menu, playerObj, hearth, copper)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_FillFromCopper"))
    option.iconTexture = getTexture(HEARTH_ICON)
    local items = findItems(playerObj, function(item)
        local container = item:getFluidContainer()
        return container ~= nil and ISHearthCopper.canFillFrom(container, copper)
    end)
    if #items == 0 then return disableWith(option, getText("IGUI_TraditionalPreservationCore_NoRoomItem")) end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, item in ipairs(items) do
        local entry = sub:addOption(say("ContextMenu_TraditionalPreservationCore_Holds", item:getDisplayName(),
            litresText(item:getFluidContainer():getCapacity() * 1000)), playerObj, onHearthAction, hearth, item, "fillFrom")
        entry.iconTexture = item:getTex()
    end
end

-- Vanilla gives every fire its own submenu, named after the tile (ISBBQMenu): the copper's options go in there too,
-- so there is one Hearth menu, not two.
local function hearthSubMenu(context, hearth)
    local vanilla = context:getOptionFromName(hearth:getTileName())
    local menu = vanilla and vanilla.subOption and context:getSubMenu(vanilla.subOption)
    if menu then return menu end
    local option = context:addOption(getText("IGUI_CraftingWindow_TPHearth"))
    option.iconTexture = getTexture(HEARTH_ICON)
    menu = context:getNew(context)
    context:addSubMenu(option, menu)
    return menu
end

local HearthWindow -- below

local function addHearthMenu(context, playerObj, hearth)
    local copper = Hearth.copperOf(hearth)
    local menu = hearthSubMenu(context, hearth)

    local status = menu:addOption(copperStatus(copper))
    status.isDisabled = true
    local info = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_HearthInfo"), playerObj, HearthWindow.open, hearth)
    info.iconTexture = getTexture(HEARTH_ICON)
    addPourInMenu(menu, playerObj, hearth, copper)
    if (copper.ml or 0) > 0 then addFillMenu(menu, playerObj, hearth, copper) end
end

local function onFillContextMenu(playerNum, context, worldobjects)
    for _, object in ipairs(worldobjects) do
        if Hearth.isHearth(object) then
            -- A hearth built this session isn't tracked until its area reloads, so its menu starts it.
            if Hearth.World then Hearth.World.track(object) end
            return addHearthMenu(context, getSpecificPlayer(playerNum), object)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

-- Picking the Hearth up while the fire burns or the copper holds anything would lose them.
local vanillaCanPickUp = ISMoveableSpriteProps.canPickUpMoveable
local vanillaInfoFlags = ISMoveableSpriteProps.getInfoPanelFlagsPerTile

local function mustStay(object)
    if not object or not Hearth.isHearth(object) then return false end
    return object:isLit() or (Hearth.stateOf(object:getModData()).ml or 0) > 0
end

function ISMoveableSpriteProps:canPickUpMoveable(character, square, object)
    if mustStay(object) then return false end
    return vanillaCanPickUp(self, character, square, object)
end

-- And the pick-up cursor says why, with vanilla's own line for a full container.
function ISMoveableSpriteProps:getInfoPanelFlagsPerTile(square, object, player, mode)
    vanillaInfoFlags(self, square, object, player, mode)
    if mode == "pickup" and mustStay(object) then InfoPanelFlags.hasItems = true end
end

-- Hearth Info: the fire, its fuel and the copper.

local NOTES = {}

-- fn(info, notes) adds lines to Hearth Info's notes. info = { copper, lit, fuelMin }.
function HearthUI.addNotes(fn)
    table.insert(NOTES, fn)
end

HearthWindow = InfoWindow:derive("TraditionalPreservationCoreHearthWindow")
HearthUI.HearthWindow = HearthWindow

function HearthWindow:new(playerObj, hearth)
    local o = InfoWindow.new(self, playerObj, hearth)
    o.title = getText("IGUI_CraftingWindow_TPHearth")
    return o
end

function HearthWindow.open(playerObj, hearth)
    InfoWindow.open(HearthWindow, playerObj, hearth)
end

function HearthWindow:refresh()
    local hearth = self.station
    self.info = { copper = Hearth.copperOf(hearth), lit = hearth:isLit(), fuelMin = hearth:getFuelAmount() }
end

-- Steaming already, or when it will be while the fire burns on.
local function steamText(info)
    local copper = info.copper
    if Hearth.isHot(copper) then return getText("IGUI_TraditionalPreservationCore_InfoHotYes") end
    local hotIn = info.lit and Hearth.hoursToHot(copper)
    if hotIn and hotIn <= info.fuelMin / 60 then return say("IGUI_TraditionalPreservationCore_InfoHotIn", hoursText(hotIn)) end
    return getText("IGUI_TraditionalPreservationCore_InfoHotNo")
end

function HearthWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.info then return end
    local info = self.info
    local copper, ml = info.copper, info.copper.ml or 0
    local y = self:top()

    y = self:row(y, "IGUI_TraditionalPreservationCore_InfoFire",
        getText(info.lit and "IGUI_TraditionalPreservationCore_InfoFireLit" or "IGUI_TraditionalPreservationCore_InfoFireOut"))
    local fuelMin = math.floor(info.fuelMin)
    y = self:bar(y, "IGUI_TraditionalPreservationCore_InfoFuel", fuelMin / FUEL_SCALE_MIN, BAR_COLOURS.fuel,
        say("IGUI_TraditionalPreservationCore_InfoFuelValue", tostring(math.floor(fuelMin / 60)), tostring(fuelMin % 60)))
    y = self:bar(y, "IGUI_TraditionalPreservationCore_InfoCopper", ml / Hearth.COPPER_ML, BAR_COLOURS.copper,
        say("IGUI_TraditionalPreservationCore_InfoLitres", litresText(ml), litresText(Hearth.COPPER_ML)))
    y = self:row(y, "IGUI_TraditionalPreservationCore_InfoFluid",
        ml > 0 and fluidName(copper.fluid) or getText("IGUI_TraditionalPreservationCore_InfoNothing"))
    y = self:row(y, "IGUI_TraditionalPreservationCore_InfoTemp",
        ml > 0 and say("IGUI_TraditionalPreservationCore_InfoDegrees", degrees(copper.tempC)) or "-")
    if ml > 0 then y = self:row(y, "IGUI_TraditionalPreservationCore_InfoHot", steamText(info)) end

    local notes = {}
    if ml <= 0 then
        table.insert(notes, getText("IGUI_TraditionalPreservationCore_HearthHelpEmpty"))
    elseif not info.lit then
        table.insert(notes, getText("IGUI_TraditionalPreservationCore_HearthHelpOut"))
    end
    for _, fn in ipairs(NOTES) do fn(info, notes) end
    self:drawNotes(y, notes)
end

-- Clicking a Hearth opens Hearth Info, as clicking a TP station opens its window (its firebox is still in the loot
-- window beside it). Not while paused, aiming or out of reach: vanilla's own checks for a click. The click handler is
-- in vanilla's server folder, which loads after this one, so it is wrapped once the game has started.
local function canClick(object, playerObj)
    return playerObj and not playerObj:isAiming()
        and not (UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0)
        and InfoWindow.inReach(playerObj, object)
end

local function wrapClickHandler()
    if not ISObjectClickHandler or ISObjectClickHandler.tpHearthClick then return end
    local vanillaClickObject = ISObjectClickHandler.doClickSpecificObject
    ISObjectClickHandler.tpHearthClick = true
    function ISObjectClickHandler.doClickSpecificObject(object, playerNum, playerObj)
        if object and Hearth.isHearth(object) and canClick(object, playerObj) then
            if Hearth.World then Hearth.World.track(object) end
            HearthWindow.open(playerObj, object)
            return true
        end
        return vanillaClickObject(object, playerNum, playerObj)
    end
end

Events.OnGameStart.Add(wrapClickHandler)

return HearthUI
