-- Traditional Preservation core: the Hearth is worked from its right-click menu. Vanilla's own menu lights and feeds
-- the fire; ours, inside vanilla's Hearth submenu, banks a lit fire or stokes it up again and has what is fitted
-- add its own rows (Hearth.attach's status and menu: the copper's are CopperUI's). Hearth Info, also on the menu,
-- shows the fire, its fuel and the attachment's rows and notes. A Hearth can't be picked up while it burns or while
-- something is fitted. Clicking a Hearth opens Hearth Info too. Mods add their own rows
-- to the copper's menu with HearthUI.addMenu and notes to Hearth Info with HearthUI.addNotes.
-- A Firebox has the same menu without the copper: Firebox Info and Bank / Stoke, and Fit for each attachment that has
-- a fit (Fit Cauldron); a fitted Hearth has Remove. Both have Connect for each connection with something beside the
-- fire to join (Hearth.connect: the Smokehouse's flue), or Disconnect for the one joined (HearthUI.addConnect,
-- HearthUI.addDisconnect: the joined thing's own menu may offer them too). The fire's own rows
-- (HearthUI.addFireboxMenu) and notes (HearthUI.addFireboxNotes) show on both, fitted or not.
require "TimedActions/TPHearthFire"
require "TimedActions/TPHearthFit"
require "TimedActions/TPHearthConnect"
local UI = require "TraditionalPreservationCore/UI"
local Hearth = require "TraditionalPreservationCore/Hearth"
require "TraditionalPreservationCore/Copper"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"

local HearthUI = {}

local say = UI.say
local HEARTH_ICON = "media/textures/Item_TPHearth.png"
local FIRE_ICONS = { bank = "media/textures/Item_TPHearthBanked.png", stoke = "media/textures/Item_TPHearthLit.png" }
local FIREBOX_ICON = "media/textures/Item_TPFirebox.png"
local FIREBOX_FIRE_ICONS = { bank = "media/textures/Item_TPFireboxBanked.png", stoke = "media/textures/Item_TPFireboxLit.png" }
local FUEL_SCALE_MIN = 12 * 60 -- a full Fuel bar: 12 hours of burning
local FUEL_COLOUR = { 0.75, 0.42, 0.18 }

local tooltipFor = UI.tooltip
local FIT_ICON = "media/textures/Item_TPCauldron.png"
local TOOL_NAMES = { PLIERS = "IGUI_TraditionalPreservationCore_ToolPliers" }

-- Menu

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

-- Fit and Remove

local function itemList(items)
    local names = {}
    for _, need in ipairs(items) do table.insert(names, need[2] .. " " .. getItemNameFromFullType(need[1])) end
    return table.concat(names, ", ")
end

local function fitTool(playerObj, spec)
    local tag = ItemTag[spec.fit.tool]
    return UI.findItems(playerObj, function(item) return item:hasTag(tag) and not item:isBroken() end)[1]
end

local function toolName(spec)
    return getText(TOOL_NAMES[spec.fit.tool] or spec.fit.tool)
end

local function onFit(playerObj, fire, spec, fitting)
    if fitting then
        for _, need in ipairs(spec.fit.items) do
            local items = UI.findItems(playerObj, function(item) return item:getFullType() == need[1] end)
            for i = 1, need[2] do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, items[i]) end
        end
    end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, fitTool(playerObj, spec))
    if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    ISTimedActionQueue.add(TPHearthFit:new(playerObj, fire, fitting and spec.id or nil))
end

-- Fit <attachment>: its items and tool, what is missing, or why not now.
local function addFitOption(menu, playerObj, fire, spec)
    local option = menu:addOption(UI.say("ContextMenu_TraditionalPreservationCore_Fit", getText(spec.name)), playerObj, onFit, fire, spec, true)
    option.iconTexture = getTexture(spec.fitIcon or FIT_ICON)
    local lines = {}
    if spec.fitHelp then table.insert(lines, getText(spec.fitHelp)) end
    table.insert(lines, UI.say("IGUI_TraditionalPreservationCore_FlueNeeds", itemList(spec.fit.items)))
    table.insert(lines, UI.say("IGUI_TraditionalPreservationCore_FlueTool", toolName(spec)))
    local missing = {}
    for _, need in ipairs(spec.fit.items) do
        local short = need[2] - #UI.findItems(playerObj, function(item) return item:getFullType() == need[1] end)
        if short > 0 then table.insert(missing, { need[1], short }) end
    end
    local short = itemList(missing)
    if not fitTool(playerObj, spec) then short = short ~= "" and (short .. ", " .. toolName(spec)) or toolName(spec) end
    if short ~= "" then table.insert(lines, UI.say("IGUI_TraditionalPreservationCore_FlueMissing", short)) end
    if Hearth.isBurning(fire) then table.insert(lines, getText("IGUI_TraditionalPreservationCore_FlueBurning")) end
    if Hearth.fitRefusal(fire, spec) == "Blocked" then table.insert(lines, getText("IGUI_TraditionalPreservationCore_FitBlocked")) end
    if short ~= "" or Hearth.fitRefusal(fire, spec) then return UI.disable(option, table.concat(lines, " <LINE> ")) end
    tooltipFor(option, table.concat(lines, " <LINE> "))
end

-- Remove <attachment>: what comes back, or why not now (burning, or it holds something).
local function addRemoveOption(menu, playerObj, fire, spec)
    local option = menu:addOption(UI.say("ContextMenu_TraditionalPreservationCore_Remove", getText(spec.name)), playerObj, onFit, fire, spec, false)
    option.iconTexture = getTexture(spec.fitIcon or FIT_ICON)
    local help = UI.say("IGUI_TraditionalPreservationCore_RemoveHelp", itemList(Hearth.fitBack(spec)), toolName(spec))
    local ok, why = Hearth.canRemove(fire)
    if not ok then
        local reason = why == "Burning" and "IGUI_TraditionalPreservationCore_FlueBurning" or "IGUI_TraditionalPreservationCore_RemoveFull"
        return UI.disable(option, help .. " <LINE> " .. getText(reason))
    end
    if not fitTool(playerObj, spec) then
        return UI.disable(option, help .. " <LINE> " .. UI.say("IGUI_TraditionalPreservationCore_FlueMissing", toolName(spec)))
    end
    tooltipFor(option, help)
end

-- Connect and Disconnect

local function kitTool(playerObj, kit)
    local tag = ItemTag[kit.tool]
    return UI.findItems(playerObj, function(item) return item:hasTag(tag) and not item:isBroken() end)[1]
end

local function kitToolName(kit)
    return getText(kit.toolText or TOOL_NAMES[kit.tool] or kit.tool)
end

local function onConnect(playerObj, fire, target, spec, kind)
    local kit = spec.kits[kind]
    for _, need in ipairs(kit.items) do
        local items = UI.findItems(playerObj, function(item) return item:getFullType() == need[1] end)
        for i = 1, need[2] do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, items[i]) end
    end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, kitTool(playerObj, kit))
    if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    ISTimedActionQueue.add(TPHearthConnect:new(playerObj, fire, target, spec.id, kind))
end

local function onDisconnect(playerObj, fire, target, spec, kit)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, kitTool(playerObj, kit))
    if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    ISTimedActionQueue.add(TPHearthConnect:new(playerObj, fire, target, spec.id, nil))
end

-- Connect <fire> to target by spec: a row per kit, each with its items and tool, what is missing; greyed with the
-- reason when it can't be done now.
function HearthUI.addConnect(menu, playerObj, fire, target, spec)
    local option = menu:addOption(getText(spec.connectText))
    if spec.icon then option.iconTexture = getTexture(spec.icon) end
    local refusal = Hearth.connectRefusal(fire, spec, target)
    if refusal then return UI.disable(option, getText(refusal)) end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, kind in ipairs(spec.kinds) do
        local kit = spec.kits[kind]
        local choice = sub:addOption(getText(kit.text), playerObj, onConnect, fire, target, spec, kind)
        local counts = {}
        for _, need in ipairs(kit.items) do
            counts[need[1]] = #UI.findItems(playerObj, function(item) return item:getFullType() == need[1] end)
        end
        local missing, noTool = Hearth.kitMissing(kit, counts, kitTool(playerObj, kit) ~= nil)
        local lines = {}
        if kit.help then table.insert(lines, getText(kit.help)) end
        table.insert(lines, say("IGUI_TraditionalPreservationCore_FlueNeeds", itemList(kit.items)))
        table.insert(lines, say("IGUI_TraditionalPreservationCore_FlueTool", kitToolName(kit)))
        if #missing > 0 or noTool then
            local short = itemList(missing)
            if noTool then short = short ~= "" and (short .. ", " .. kitToolName(kit)) or kitToolName(kit) end
            table.insert(lines, say("IGUI_TraditionalPreservationCore_FlueMissing", short))
            UI.disable(choice, table.concat(lines, " <LINE> "))
        else
            tooltipFor(choice, table.concat(lines, " <LINE> "))
        end
    end
end

-- Disconnect what is joined to fire (target: what it goes into, nil when that is gone): what comes back, or why not
-- now.
function HearthUI.addDisconnect(menu, playerObj, fire, target, spec)
    local kit = spec.kits[Hearth.joinOf(fire:getModData()[Hearth.KEY])]
    if not kit then return end
    local option = menu:addOption(getText(spec.disconnectText), playerObj, onDisconnect, fire, target, spec, kit)
    if spec.icon then option.iconTexture = getTexture(spec.icon) end
    local help = say(spec.disconnectHelp, itemList(Hearth.kitBack(kit)), kitToolName(kit))
    if Hearth.isBurning(fire) then
        UI.disable(option, getText("IGUI_TraditionalPreservationCore_FlueBurning"))
    elseif not kitTool(playerObj, kit) then
        UI.disable(option, help .. " <LINE> " .. say("IGUI_TraditionalPreservationCore_FlueMissing", kitToolName(kit)))
    else
        tooltipFor(option, help)
    end
end

-- The fire's connection rows: Disconnect what is joined, else Connect for each connection with something beside it.
local function addConnectionRows(menu, playerObj, fire)
    local joined, part = Hearth.connectionOf(fire)
    if joined then
        return HearthUI.addDisconnect(menu, playerObj, fire, joined.joined and joined.joined(fire, part), joined)
    end
    for _, spec in ipairs(Hearth.connections()) do
        local target = spec.finds and spec.finds(fire)
        if target then HearthUI.addConnect(menu, playerObj, fire, target, spec) end
    end
end

local MENUS = {}

-- fn(menu, playerObj, hearth, copper) adds a mod's own rows to the Hearth's menu, after Pour into Copper.
function HearthUI.addMenu(fn)
    table.insert(MENUS, fn)
end

-- The rows HearthUI.addMenu gave, for the copper's menu to place.
function HearthUI.modRows(menu, playerObj, hearth, copper)
    for _, fn in ipairs(MENUS) do fn(menu, playerObj, hearth, copper) end
end

local FIREBOX_MENUS = {}

-- fn(menu, playerObj, fire, state) adds rows for the fire itself, fitted or not (a connection's: the Smokehouse's
-- flue), last in its menu. state is the fire's.
function HearthUI.addFireboxMenu(fn)
    table.insert(FIREBOX_MENUS, fn)
end

local function addFireRows(menu, playerObj, fire, state)
    for _, fn in ipairs(FIREBOX_MENUS) do fn(menu, playerObj, fire, state) end
end

-- A Hearth: what is fitted says what it holds first, then Hearth Info, Bank / Stoke and the attachment's own rows.
local function addHearthMenu(context, playerObj, hearth)
    local state = Hearth.fireStateOf(hearth)
    local spec, part = Hearth.attachmentOf(hearth)
    local menu = hearthSubMenu(context, hearth)
    fixFuelLine(menu, hearth)

    if spec and spec.status then
        local text, icon = spec.status(part)
        local status = menu:addOption(text)
        status.isDisabled = true
        status.iconTexture = getTexture(icon)
    end
    local info = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_HearthInfo"), playerObj, HearthWindow.open, hearth)
    info.iconTexture = getTexture(HEARTH_ICON)
    addFireOption(menu, playerObj, hearth)
    if spec and spec.menu then spec.menu(menu, playerObj, hearth, part) end
    if spec and spec.fit then addRemoveOption(menu, playerObj, hearth, spec) end
    addConnectionRows(menu, playerObj, hearth)
    addFireRows(menu, playerObj, hearth, state)
end

local function addFireboxMenu(context, playerObj, firebox)
    local state = Hearth.fireStateOf(firebox)
    local menu = hearthSubMenu(context, firebox)
    fixFuelLine(menu, firebox)
    local info = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_FireboxInfo"), playerObj, HearthWindow.open, firebox)
    info.iconTexture = getTexture(FIREBOX_ICON)
    addFireOption(menu, playerObj, firebox)
    for _, spec in ipairs(Hearth.attachments()) do
        if spec.fit and spec.name then addFitOption(menu, playerObj, firebox, spec) end
    end
    addConnectionRows(menu, playerObj, firebox)
    addFireRows(menu, playerObj, firebox, state)
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

UI.keepDoorsFree()

-- Picking a Stone Hearth up while the fire burns (lit or banked) would lose it, and with something fitted or joined
-- that comes off first (Remove, Disconnect): the stone alone is carried. The cursor says Too hot for the fire, Has
-- items for the rest.
UI.keepInPlace(function(object)
    if not Hearth.isFire(object) then return nil end
    if Hearth.isBurning(object) then return "tooHot" end
    return (Hearth.attachedTo(object) ~= nil or Hearth.connectedTo(object:getModData()[Hearth.KEY]) ~= nil) or nil
end)

-- Hearth Info: the fire, its fuel and the attachment's rows and notes.

local NOTES, FIREBOX_NOTES = {}, {}

-- fn(info, notes) adds lines to Hearth Info's notes, after the attachment's. info = { copper (the attachment's state),
-- state (the fire's), lit, banked, fuelMin, burnHours }.
function HearthUI.addNotes(fn)
    table.insert(NOTES, fn)
end

-- Notes on the fire itself, fitted or not, last in its Info (after the connection's own notes). info = { state
-- (the fire's), joined (the connection's state, if any), copper (the attachment's state, or the fire's when nothing is fitted), lit, banked,
-- fuelMin, burnHours, firebox }.
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
    local state = Hearth.fireStateOf(hearth)
    local spec, part = Hearth.attachmentOf(hearth)
    local joinedSpec, joined = Hearth.connectionOf(hearth)
    self.info = { copper = part or state, state = state, spec = spec, joinedSpec = joinedSpec, joined = joined, lit = Hearth.isBurning(hearth),
        banked = Hearth.isBanked(hearth), fuelMin = hearth:getFuelAmount(), burnHours = Hearth.fuelHours(hearth),
        firebox = Hearth.isFirebox(hearth) }
end

function HearthWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.info then return end
    local info = self.info
    local y = self:top()

    local fire = info.banked and "IGUI_TraditionalPreservationCore_InfoFireBanked"
        or info.lit and "IGUI_TraditionalPreservationCore_InfoFireLit" or "IGUI_TraditionalPreservationCore_InfoFireOut"
    y = self:row(y, "IGUI_TraditionalPreservationCore_InfoFire", getText(fire))
    -- The bar is the wood; the time is how long it burns, three times as long banked.
    local burnMin = math.floor(info.burnHours * 60)
    y = self:bar(y, "IGUI_TraditionalPreservationCore_InfoFuel", info.fuelMin / FUEL_SCALE_MIN, FUEL_COLOUR,
        say("IGUI_TraditionalPreservationCore_InfoFuelValue", tostring(math.floor(burnMin / 60)), tostring(burnMin % 60)))
    if info.firebox then
        local notes = { getText(info.banked and "IGUI_TraditionalPreservationCore_FireboxHelpBanked"
            or info.lit and "IGUI_TraditionalPreservationCore_FireboxHelpLit" or "IGUI_TraditionalPreservationCore_FireboxHelpOut") }
        if info.joinedSpec and info.joinedSpec.notes then info.joinedSpec.notes(info, notes, info.joined) end
        for _, fn in ipairs(FIREBOX_NOTES) do fn(info, notes) end
        self:drawNotes(y, notes)
        return
    end
    local spec, notes = info.spec, {}
    if spec and spec.rows then y = spec.rows(self, y, info) end
    if spec and spec.notes then spec.notes(info, notes) end
    for _, fn in ipairs(NOTES) do fn(info, notes) end
    if info.joinedSpec and info.joinedSpec.notes then info.joinedSpec.notes(info, notes, info.joined) end
    for _, fn in ipairs(FIREBOX_NOTES) do fn(info, notes) end
    self:drawNotes(y, notes)
end

-- Clicking a Hearth or Firebox opens its Info, as clicking a TP station opens its window (its firebox is still in the loot
-- window beside it).
InfoWindow.clickOpens(Hearth.isFire, function(playerObj, hearth)
    if Hearth.World then Hearth.World.track(hearth) end
    HearthWindow.open(playerObj, hearth)
end)

return HearthUI
