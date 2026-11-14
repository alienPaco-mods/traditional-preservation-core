-- Traditional Preservation core: the Stone Hearth is worked from its right-click menu. Vanilla's own menu lights and
-- feeds the fire; ours, inside vanilla's submenu, banks a lit fire or stokes it up again. One menu serves it fitted or
-- not: Info (Hearth Info, or Firebox Info with nothing fitted) and Bank / Stoke, then what is fitted adds its own rows
-- and Remove (Hearth.attach's status and menu: the cauldron's are CauldronUI's), or a bare one has Fit for each
-- attachment that has a fit (Fit Cauldron). Both have Connect for each connection with something beside the fire to
-- join (Hearth.connect: the Smokehouse's flue), or Disconnect for the one joined (HearthUI.addConnect,
-- HearthUI.addDisconnect: the joined thing's own menu may offer them too). The fire's own rows
-- (HearthUI.addFireboxMenu) and notes (HearthUI.addFireboxNotes) show on both. A Stone Hearth can't be picked up while
-- it burns or while something is fitted or joined. Clicking one opens its Info too.
require "TimedActions/TPHearthFire"
require "TimedActions/TPHearthFit"
require "TimedActions/TPHearthConnect"
local UI = require "TraditionalPreservationCore/UI"
local Hearth = require "TraditionalPreservationCore/Hearth"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"

local HearthUI = {}

local say, tooltipFor = UI.say, UI.tooltip
local LINE = " <LINE> " -- a line break in a hover
local FUEL_SCALE_MIN = 12 * 60 -- a full Fuel bar: 12 hours of burning
local FUEL_COLOUR = { 0.75, 0.42, 0.18 }
local FIT_ICON = "media/textures/Item_TPCauldron.png"
local TOOL_NAMES = { PLIERS = "IGUI_TraditionalPreservationCore_ToolPliers" }

-- How a bare Stone Hearth (the Firebox) shows: its icon, title, Info row and the icons for its fire banked or burning
-- up again. A fitted one shows as its attachment's display says (the same fields, given with Hearth.attach), or as the
-- cauldron's when it gives none.
local FIREBOX_DISPLAY = { icon = "media/textures/Item_TPFirebox.png", title = "IGUI_CraftingWindow_TPFirebox",
    info = "ContextMenu_TraditionalPreservationCore_FireboxInfo",
    fire = { bank = "media/textures/Item_TPFireboxBanked.png", stoke = "media/textures/Item_TPFireboxLit.png" } }

local function lookOf(fire)
    if Hearth.isFirebox(fire) then return FIREBOX_DISPLAY end
    local spec = Hearth.attachmentOf(fire)
    return spec and spec.display or Hearth.attachment(Hearth.CAULDRON).display
end

-- Menu

local function onFireAction(playerObj, hearth, mode)
    if not luautils.walkAdj(playerObj, hearth:getSquare(), true) then return end
    ISTimedActionQueue.add(TPHearthFire:new(playerObj, hearth, mode))
end

HearthUI.fireAction = onFireAction

-- The Hearth or the Firebox as its fire will be, banked or burning up again.
function HearthUI.fireIcon(fire, mode)
    return lookOf(fire).fire[mode]
end

local function addFireOption(menu, playerObj, hearth)
    if not Hearth.isBurning(hearth) then return end
    local banked = Hearth.isBanked(hearth)
    local mode = banked and "stoke" or "bank"
    local option = menu:addOption(getText(banked and "ContextMenu_TraditionalPreservationCore_StokeFire"
        or "ContextMenu_TraditionalPreservationCore_BankFire"), playerObj, onFireAction, hearth, mode)
    option.iconTexture = getTexture(HearthUI.fireIcon(hearth, mode))
    tooltipFor(option, getText(banked and "IGUI_TraditionalPreservationCore_StokeHelp" or "IGUI_TraditionalPreservationCore_BankHelp"))
end

-- Vanilla gives every fire its own submenu, named after the tile (ISBBQMenu): ours go in there too, so there is one
-- menu, not two.
local function hearthSubMenu(context, hearth)
    local vanilla = context:getOptionFromName(hearth:getTileName())
    local menu = vanilla and vanilla.subOption and context:getSubMenu(vanilla.subOption)
    if menu then return menu end
    local look = lookOf(hearth)
    local option = context:addOption(getText(look.title))
    option.iconTexture = getTexture(look.icon)
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

-- Kits: an attachment's fit and a connection's kits are both { items = { {full type, count} }, tool (an ItemTag's
-- name, kept), toolText (its text key, else TOOL_NAMES) }.

local function itemList(items)
    local names = {}
    for _, need in ipairs(items) do table.insert(names, need[2] .. " " .. getItemNameFromFullType(need[1])) end
    return table.concat(names, ", ")
end

local function kitToolName(kit)
    return getText(kit.toolText or TOOL_NAMES[kit.tool] or kit.tool)
end

-- What of a kit is in reach, in one look through every container: its items by full type, and an unbroken tool.
local function kitInReach(playerObj, kit)
    local found, tool, tag = {}, nil, ItemTag[kit.tool]
    for _, need in ipairs(kit.items) do found[need[1]] = {} end
    UI.findItems(playerObj, function(item)
        local items = found[item:getFullType()]
        if items then table.insert(items, item) end
        if not tool and item:hasTag(tag) and not item:isBroken() then tool = item end
        return false
    end)
    return found, tool
end

-- Brings the kit's tool to hand, and its items too when they are to be used.
local function bringKit(playerObj, kit, withItems)
    local found, tool = kitInReach(playerObj, kit)
    if withItems then
        for _, need in ipairs(kit.items) do
            for i = 1, need[2] do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, found[need[1]][i]) end
        end
    end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, tool)
end

-- A kit's hover lines: its help (a text key, or nil), what it needs, the tool kept, what is missing; and whether
-- anything is.
local function kitLines(playerObj, kit, help)
    local found, tool = kitInReach(playerObj, kit)
    local counts = {}
    for fullType, items in pairs(found) do counts[fullType] = #items end
    local missing, noTool = Hearth.kitMissing(kit, counts, tool ~= nil)
    local lines = {}
    if help then table.insert(lines, getText(help)) end
    table.insert(lines, say("IGUI_TraditionalPreservationCore_KitNeeds", itemList(kit.items)))
    table.insert(lines, say("IGUI_TraditionalPreservationCore_KitTool", kitToolName(kit)))
    local short = itemList(missing)
    if noTool then short = short ~= "" and (short .. ", " .. kitToolName(kit)) or kitToolName(kit) end
    if short ~= "" then table.insert(lines, say("IGUI_TraditionalPreservationCore_KitMissing", short)) end
    return lines, short ~= ""
end

-- Disabled with the lines as its hover when blocked, else the lines as its hover.
local function hover(option, lines, blocked)
    local text = table.concat(lines, LINE)
    if blocked then return UI.disable(option, text) end
    tooltipFor(option, text)
end

-- Fit and Remove

local function onFit(playerObj, fire, spec, fitting)
    bringKit(playerObj, spec.fit, fitting)
    if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    ISTimedActionQueue.add(TPHearthFit:new(playerObj, fire, fitting and spec.id or nil))
end

-- Fit <attachment>: its items and tool, what is missing, or why not now.
local function addFitOption(menu, playerObj, fire, spec)
    local option = menu:addOption(say("ContextMenu_TraditionalPreservationCore_Fit", getText(spec.name)), playerObj, onFit, fire, spec, true)
    option.iconTexture = getTexture(spec.fitIcon or FIT_ICON)
    local lines, short = kitLines(playerObj, spec.fit, spec.fitHelp)
    local refusal = Hearth.fitRefusal(fire, spec)
    if Hearth.isBurning(fire) then table.insert(lines, getText("IGUI_TraditionalPreservationCore_FireBurning")) end
    if refusal == "Blocked" then table.insert(lines, getText("IGUI_TraditionalPreservationCore_FitBlocked")) end
    hover(option, lines, short or refusal)
end

-- Remove <attachment>: what comes back, or why not now (burning, or it holds something).
local function addRemoveOption(menu, playerObj, fire, spec)
    local option = menu:addOption(say("ContextMenu_TraditionalPreservationCore_Remove", getText(spec.name)), playerObj, onFit, fire, spec, false)
    option.iconTexture = getTexture(spec.fitIcon or FIT_ICON)
    local lines = { say("IGUI_TraditionalPreservationCore_RemoveHelp", itemList(Hearth.fitBack(spec)), kitToolName(spec.fit)) }
    local ok, why = Hearth.canRemove(fire)
    if not ok then
        table.insert(lines, getText(why == "Burning" and "IGUI_TraditionalPreservationCore_FireBurning" or "IGUI_TraditionalPreservationCore_RemoveFull"))
    elseif not select(2, kitInReach(playerObj, spec.fit)) then
        table.insert(lines, say("IGUI_TraditionalPreservationCore_KitMissing", kitToolName(spec.fit)))
    end
    hover(option, lines, #lines > 1)
end

-- Connect and Disconnect

local function onConnect(playerObj, fire, target, spec, kind)
    bringKit(playerObj, spec.kits[kind], true)
    if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    ISTimedActionQueue.add(TPHearthConnect:new(playerObj, fire, target, spec.id, kind))
end

local function onDisconnect(playerObj, fire, target, spec, kit)
    bringKit(playerObj, kit, false)
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
        hover(choice, kitLines(playerObj, kit, kit.help))
    end
end

-- Disconnect what is joined to fire (target: what it goes into, nil when that is gone): what comes back, or why not
-- now (burning, or no tool).
function HearthUI.addDisconnect(menu, playerObj, fire, target, spec)
    local kit = spec.kits[Hearth.joinOf(fire:getModData()[Hearth.KEY])]
    if not kit then return end
    local option = menu:addOption(getText(spec.disconnectText), playerObj, onDisconnect, fire, target, spec, kit)
    if spec.icon then option.iconTexture = getTexture(spec.icon) end
    local lines = { say(spec.disconnectHelp, itemList(Hearth.kitBack(kit)), kitToolName(kit)) }
    if Hearth.isBurning(fire) then
        table.insert(lines, getText("IGUI_TraditionalPreservationCore_FireBurning"))
    elseif not select(2, kitInReach(playerObj, kit)) then
        table.insert(lines, say("IGUI_TraditionalPreservationCore_KitMissing", kitToolName(kit)))
    end
    hover(option, lines, #lines > 1)
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

local FIREBOX_MENUS = {}

-- fn(menu, playerObj, fire, state) adds rows for the fire itself, fitted or not (a connection's: the Smokehouse's
-- flue), last in its menu. state is the fire's.
function HearthUI.addFireboxMenu(fn)
    table.insert(FIREBOX_MENUS, fn)
end

-- A Stone Hearth's menu: what is fitted says what it holds first, then Info and Bank / Stoke; then what is fitted
-- adds its own rows and Remove, or a bare one has Fit for each attachment; then the connection's rows and the fire's.
local function addFireMenu(context, playerObj, fire)
    local look = lookOf(fire)
    local spec, part = Hearth.attachmentOf(fire)
    local menu = hearthSubMenu(context, fire)
    fixFuelLine(menu, fire)

    if spec and spec.status then
        local text, icon = spec.status(part)
        local status = menu:addOption(text)
        status.isDisabled = true
        status.iconTexture = getTexture(icon)
    end
    local info = menu:addOption(getText(look.info), playerObj, HearthWindow.open, fire)
    info.iconTexture = getTexture(look.icon)
    addFireOption(menu, playerObj, fire)
    if Hearth.isFirebox(fire) then
        for _, each in ipairs(Hearth.attachments()) do
            if each.fit and each.name then addFitOption(menu, playerObj, fire, each) end
        end
    else
        if spec and spec.menu then spec.menu(menu, playerObj, fire, part) end
        if spec and spec.fit then addRemoveOption(menu, playerObj, fire, spec) end
    end
    addConnectionRows(menu, playerObj, fire)
    local state = Hearth.fireStateOf(fire)
    for _, fn in ipairs(FIREBOX_MENUS) do fn(menu, playerObj, fire, state) end
end

local function onFillContextMenu(playerNum, context, worldobjects, test)
    for _, object in ipairs(worldobjects) do
        if Hearth.isFire(object) then
            -- Vanilla's probe for a controller's prompt: say there is a menu, do no work.
            if test then return ISWorldObjectContextMenu.setTest() end
            -- A hearth built this session isn't tracked until its area reloads, so its menu starts it.
            if Hearth.World then Hearth.World.track(object) end
            return addFireMenu(context, getSpecificPlayer(playerNum), object)
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

local FIREBOX_NOTES = {}

-- Notes on the fire itself, fitted or not, last in its Info (after the connection's own notes). info is HearthUI.notes'.
function HearthUI.addFireboxNotes(fn)
    table.insert(FIREBOX_NOTES, fn)
end

-- What Info says of a fire, from info = { part (the attachment's state, nil with nothing fitted), spec (its
-- attachment), state (the fire's), joinedSpec and joined (the connection and its state, if any), lit, banked, fuelMin,
-- burnHours, firebox }: a bare one's help, the attachment's notes, the connection's, then the fire's.
function HearthUI.notes(info)
    local notes = {}
    if info.firebox then
        table.insert(notes, getText(info.banked and "IGUI_TraditionalPreservationCore_FireboxHelpBanked"
            or info.lit and "IGUI_TraditionalPreservationCore_FireboxHelpLit" or "IGUI_TraditionalPreservationCore_FireboxHelpOut"))
    end
    if info.spec and info.spec.notes then info.spec.notes(info, notes) end
    if info.joinedSpec and info.joinedSpec.notes then info.joinedSpec.notes(info, notes, info.joined) end
    for _, fn in ipairs(FIREBOX_NOTES) do fn(info, notes) end
    return notes
end

HearthWindow = InfoWindow:derive("TraditionalPreservationCoreHearthWindow")

function HearthWindow:new(playerObj, hearth)
    local o = InfoWindow.new(self, playerObj, hearth)
    o.title = getText(lookOf(hearth).title)
    return o
end

function HearthWindow.open(playerObj, hearth)
    InfoWindow.open(HearthWindow, playerObj, hearth)
end

function HearthWindow:refresh()
    local hearth = self.station
    local spec, part = Hearth.attachmentOf(hearth)
    local joinedSpec, joined = Hearth.connectionOf(hearth)
    self.info = { part = part, spec = spec, state = Hearth.fireStateOf(hearth), joinedSpec = joinedSpec, joined = joined,
        lit = Hearth.isBurning(hearth), banked = Hearth.isBanked(hearth), fuelMin = hearth:getFuelAmount(),
        burnHours = Hearth.fuelHours(hearth), firebox = Hearth.isFirebox(hearth) }
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
    if info.spec and info.spec.rows then y = info.spec.rows(self, y, info) end
    self:drawNotes(y, HearthUI.notes(info))
end

-- Clicking a Hearth or Firebox opens its Info, as clicking a TP station opens its window (its firebox is still in the loot
-- window beside it).
InfoWindow.clickOpens(Hearth.isFire, function(playerObj, hearth)
    if Hearth.World then Hearth.World.track(hearth) end
    HearthWindow.open(playerObj, hearth)
end)

return HearthUI
