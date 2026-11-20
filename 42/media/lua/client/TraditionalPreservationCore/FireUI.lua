-- Traditional Preservation core: a fire (any Fire.kind: the Stone Hearth) is worked from its right-click menu.
-- Vanilla's own menu lights and feeds the fire; ours, inside vanilla's submenu, banks a lit fire or stokes it up again.
-- One menu serves it fitted or not: Info (its kind's or attachment's, Stone Hearth Info) and Bank / Stoke, then what is fitted adds its own rows
-- and Remove (Fire.attach's status and menu: the cauldron's are CauldronUI's), or a bare one has Fit for each
-- attachment that has a fit (Fit Cauldron). Both have Connect for each connection with something beside the fire to
-- join (Fire.connect: the Smokehouse's flue), or Disconnect for the one joined (FireUI.addConnect,
-- FireUI.addDisconnect: the joined thing's own menu may offer them too). The fire's own rows
-- (FireUI.addMenu) and notes (FireUI.addNotes) show on both. Its Info: a band under the title (the fire lit, banked
-- or out, and how long it burns), what it holds (the wood, then what
-- is fitted: Fire.attach's holds), Bank the Fire and Stoke the Fire as buttons, then the notes;
-- the band holds Light the Fire (vanilla's light menu) or Put Out the Fire. A fire can't be picked up while
-- it burns or while something is fitted or joined. Clicking one opens its Info too.
require "TimedActions/TPFireTend"
require "TimedActions/TPFireFit"
require "TimedActions/TPFireConnect"
local UI = require "TraditionalPreservationCore/UI"
local Fire = require "TraditionalPreservationCore/Fire"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local Wrap = require "TraditionalPreservationCore/Wrap"

local FireUI = {}

local say, tooltipFor = UI.say, UI.tooltip
local LINE = " <LINE> " -- a line break in a hover
local FUEL_SCALE_MIN = 12 * 60 -- five full Wood cells: 12 hours of burning
local LIGHT_ICON, OUT_ICON = "Item_Lighter", "Item_Extinguisher" -- the band's button: the game's own items
local FIT_ICON = "media/textures/Item_TPCauldron.png"
local TOOL_NAMES = { PLIERS = "IGUI_TraditionalPreservationCore_ToolPliers" }

-- How a fire shows: its icon, title, Info row and the icons for its fire banked or burning up again. A fitted one
-- shows as its attachment's display says (Fire.attach), a bare one, or one whose attachment gives none, as its
-- kind's (Fire.kind).
local function lookOf(fire)
    local attachment = Fire.attachmentOf(fire)
    return attachment and attachment.display or Fire.kindOf(fire).display
end

-- Menu

local function onFireAction(playerObj, fire, mode)
    if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    ISTimedActionQueue.add(TPFireTend:new(playerObj, fire, mode))
end

FireUI.fireAction = onFireAction

-- The fire as it will be, banked or burning up again.
function FireUI.fireIcon(fire, mode)
    return lookOf(fire).fire[mode]
end

local function addFireOption(menu, playerObj, fire)
    if not Fire.isBurning(fire) then return end
    local banked = Fire.isBanked(fire)
    local mode = banked and "stoke" or "bank"
    local option = menu:addOption(getText(banked and "ContextMenu_TraditionalPreservationCore_StokeFire"
        or "ContextMenu_TraditionalPreservationCore_BankFire"), playerObj, onFireAction, fire, mode)
    option.iconTexture = getTexture(FireUI.fireIcon(fire, mode))
    tooltipFor(option, getText(banked and "IGUI_TraditionalPreservationCore_StokeHelp" or "IGUI_TraditionalPreservationCore_BankHelp"))
end

-- Vanilla gives every fire its own submenu, named after the tile (ISBBQMenu): ours go in there too, so there is one
-- menu, not two.
local function fireSubMenu(context, fire)
    local vanilla = context:getOptionFromName(fire:getTileName())
    local menu = vanilla and vanilla.subOption and context:getSubMenu(vanilla.subOption)
    if menu then return menu end
    local look = lookOf(fire)
    local option = context:addOption(getText(look.title))
    option.iconTexture = getTexture(look.icon)
    menu = context:getNew(context)
    context:addSubMenu(option, menu)
    return menu
end

-- A banked fire's vanilla fire is out, so vanilla's fuel line says Unlit: it says Banked, with the time the embers
-- burn on.
local function fixFuelLine(menu, fire)
    if not Fire.isBanked(fire) then return end
    local unlit = " (" .. getText("IGUI_Fireplace_Unlit") .. ")"
    for _, option in ipairs(menu.options or {}) do
        if type(option.name) == "string" and option.name:sub(-#unlit) == unlit then
            option.name = getText("IGUI_BBQ_FuelAmount", ISCampingMenu.timeString(math.floor(Fire.fuelHours(fire) * 60 + 0.5)))
                .. " (" .. getText("IGUI_TraditionalPreservationCore_InfoFireBanked") .. ")"
        end
    end
end

-- Vanilla offers to light a fire that is out: a banked one's is, so Put out Fire takes its place there (in the
-- right-click menu and the loot window's controller menu), and it unbanks.
Wrap.method("ISCampingMenu", "doLightFireOption", function(doLightFireOption, playerObj, context, worldobjects, hasFuel, fuelInfo, target, ...)
    if instanceof(target, "IsoFireplace") and Fire.isBanked(target) then
        return context:addOption(getText("ContextMenu_Put_out_fire"), playerObj, onFireAction, target, "out")
    end
    return doLightFireOption(playerObj, context, worldobjects, hasFuel, fuelInfo, target, ...)
end)

local FireWindow -- below

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
    local missing, noTool = Fire.kitMissing(kit, counts, tool ~= nil)
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

local function onFit(playerObj, fire, attachment, fitting)
    bringKit(playerObj, attachment.fit, fitting)
    if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    ISTimedActionQueue.add(TPFireFit:new(playerObj, fire, fitting and attachment.id or nil))
end

-- Fit <attachment>: its items and tool, what is missing, or why not now.
local function addFitOption(menu, playerObj, fire, attachment)
    local option = menu:addOption(say("ContextMenu_TraditionalPreservationCore_Fit", getText(attachment.name)), playerObj, onFit, fire, attachment, true)
    option.iconTexture = getTexture(attachment.fitIcon or FIT_ICON)
    local lines, short = kitLines(playerObj, attachment.fit, attachment.fitHelp)
    local refusal = Fire.fitRefusal(fire, attachment)
    if Fire.isBurning(fire) then table.insert(lines, getText("IGUI_TraditionalPreservationCore_FireBurning")) end
    if refusal == "Blocked" then table.insert(lines, getText("IGUI_TraditionalPreservationCore_FitBlocked")) end
    hover(option, lines, short or refusal)
end

-- Remove <attachment>: what comes back, or why not now (burning, or it holds something).
local function addRemoveOption(menu, playerObj, fire, attachment)
    local option = menu:addOption(say("ContextMenu_TraditionalPreservationCore_Remove", getText(attachment.name)), playerObj, onFit, fire, attachment, false)
    option.iconTexture = getTexture(attachment.fitIcon or FIT_ICON)
    local lines = { say("IGUI_TraditionalPreservationCore_RemoveHelp", itemList(Fire.fitBack(attachment)), kitToolName(attachment.fit)) }
    local ok, why = Fire.canRemove(fire)
    if not ok then
        table.insert(lines, getText(why == "Burning" and "IGUI_TraditionalPreservationCore_FireBurning"
            or attachment.removeText and attachment.removeText[why] or "IGUI_TraditionalPreservationCore_RemoveFull"))
    elseif not select(2, kitInReach(playerObj, attachment.fit)) then
        table.insert(lines, say("IGUI_TraditionalPreservationCore_KitMissing", kitToolName(attachment.fit)))
    end
    hover(option, lines, #lines > 1)
end

-- Connect and Disconnect

local function onConnect(playerObj, fire, target, connection, kitName)
    bringKit(playerObj, connection.kits[kitName], true)
    if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    ISTimedActionQueue.add(TPFireConnect:new(playerObj, fire, target, connection.id, kitName))
end

local function onDisconnect(playerObj, fire, target, connection, kit)
    bringKit(playerObj, kit, false)
    if not luautils.walkAdj(playerObj, fire:getSquare(), true) then return end
    ISTimedActionQueue.add(TPFireConnect:new(playerObj, fire, target, connection.id, nil))
end

-- Connect <fire> to target by connection: a row per kit, each with its items and tool, what is missing; greyed with the
-- reason when it can't be done now.
function FireUI.addConnect(menu, playerObj, fire, target, connection)
    local option = menu:addOption(getText(connection.connectText))
    if connection.icon then option.iconTexture = getTexture(connection.icon) end
    local refusal = Fire.connectRefusal(fire, connection, target)
    if refusal then return UI.disable(option, getText(refusal)) end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, kitName in ipairs(connection.kitNames) do
        local kit = connection.kits[kitName]
        local choice = sub:addOption(getText(kit.text), playerObj, onConnect, fire, target, connection, kitName)
        hover(choice, kitLines(playerObj, kit, kit.help))
    end
end

-- Disconnect what is joined to fire (target: what it goes into, nil when that is gone): what comes back, or why not
-- now (burning, or no tool).
function FireUI.addDisconnect(menu, playerObj, fire, target, connection)
    local kit = connection.kits[Fire.joinOf(fire:getModData()[Fire.KEY])]
    if not kit then return end
    local option = menu:addOption(getText(connection.disconnectText), playerObj, onDisconnect, fire, target, connection, kit)
    if connection.icon then option.iconTexture = getTexture(connection.icon) end
    local lines = { say(connection.disconnectHelp, itemList(Fire.kitBack(kit)), kitToolName(kit)) }
    if Fire.isBurning(fire) then
        table.insert(lines, getText("IGUI_TraditionalPreservationCore_FireBurning"))
    elseif not select(2, kitInReach(playerObj, kit)) then
        table.insert(lines, say("IGUI_TraditionalPreservationCore_KitMissing", kitToolName(kit)))
    end
    hover(option, lines, #lines > 1)
end

-- The fire's connection rows: Disconnect what is joined, else Connect for each connection with something beside it.
local function addConnectionRows(menu, playerObj, fire)
    local joined, part = Fire.connectionOf(fire)
    if joined then
        return FireUI.addDisconnect(menu, playerObj, fire, joined.joined and joined.joined(fire, part), joined)
    end
    for _, connection in ipairs(Fire.connections()) do
        local target = connection.finds and connection.finds(fire)
        if target then FireUI.addConnect(menu, playerObj, fire, target, connection) end
    end
end

local MENUS = {}

-- fn(menu, playerObj, fire, state) adds rows for the fire itself, fitted or not (a connection's: the Smokehouse's
-- flue), last in its menu. state is the fire's.
function FireUI.addMenu(fn)
    table.insert(MENUS, fn)
end

-- A fire's menu: what is fitted says what it holds first, then Info and Bank / Stoke; then what is fitted
-- adds its own rows and Remove, or a bare one has Fit for each attachment; then the connection's rows and the fire's.
local function addFireMenu(context, playerObj, fire)
    local look = lookOf(fire)
    local attachment, part = Fire.attachmentOf(fire)
    local menu = fireSubMenu(context, fire)
    fixFuelLine(menu, fire)

    if attachment and attachment.status then
        local text, icon = attachment.status(part)
        local status = menu:addOption(text)
        status.isDisabled = true
        status.iconTexture = getTexture(icon)
    end
    local infoOption = menu:addOption(getText(look.infoText), playerObj, FireWindow.open, fire)
    infoOption.iconTexture = getTexture(look.icon)
    UI.topInfo(context, getText(look.infoText), getTexture(look.icon), playerObj, FireWindow.open, fire)
    addFireOption(menu, playerObj, fire)
    if Fire.isBare(fire) then
        for _, each in ipairs(Fire.attachments()) do
            if each.fit and each.name then addFitOption(menu, playerObj, fire, each) end
        end
    else
        if attachment and attachment.menu then attachment.menu(menu, playerObj, fire, part) end
        if attachment and attachment.fit then addRemoveOption(menu, playerObj, fire, attachment) end
    end
    addConnectionRows(menu, playerObj, fire)
    local fireModData = Fire.fireModDataNow(fire)
    for _, fn in ipairs(MENUS) do fn(menu, playerObj, fire, fireModData) end
end

local function onFillContextMenu(playerNum, context, worldobjects, test)
    for _, isoObject in ipairs(worldobjects) do
        if Fire.isFire(isoObject) then
            -- Vanilla's probe for a controller's prompt: say there is a menu, do no work.
            if test then return ISWorldObjectContextMenu.setTest() end
            -- A fire built this session isn't tracked until its area reloads, so its menu starts it.
            if Fire.World then Fire.World.track(isoObject) end
            return addFireMenu(context, getSpecificPlayer(playerNum), isoObject)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillContextMenu)

UI.keepDoorsFree()

-- Picking a fire up while it burns (lit or banked) would lose it, and with something fitted or joined that comes off
-- first (Remove, Disconnect): the fireplace alone is carried. The cursor says Too hot for the fire, Has
-- items for the rest.
UI.keepInPlace(function(isoObject)
    if not Fire.isFire(isoObject) then return nil end
    if Fire.isBurning(isoObject) then return "tooHot" end
    return (Fire.attachedTo(isoObject) ~= nil or Fire.connectedTo(isoObject:getModData()[Fire.KEY]) ~= nil) or nil
end)

-- A fire's Info (Stone Hearth Info): the fire, its fuel and the attachment's rows and notes.

local NOTES = {}

-- Notes on the fire itself, fitted or not, last in its Info (after the connection's own notes). fireView is FireUI.notes'.
function FireUI.addNotes(fn)
    table.insert(NOTES, fn)
end

-- What Info says of a fire, from fireView = { part (the attachment's state, nil with nothing fitted), attachment (what is
-- fitted), state (the fire's), connection and joined (the connection and its state, if any), lit, banked, fuelMin,
-- burnHours, firebox, help (a bare one's: its kind's display.help) }: a bare one's help, the attachment's notes, the
-- connection's, then the fire's.
function FireUI.notes(fireView)
    local notes = {}
    local help = fireView.help
    if help then table.insert(notes, getText(fireView.banked and help.banked or fireView.lit and help.lit or help.out)) end
    if fireView.attachment and fireView.attachment.notes then fireView.attachment.notes(fireView, notes) end
    if fireView.connection and fireView.connection.notes then fireView.connection.notes(fireView, notes, fireView.joined) end
    for _, fn in ipairs(NOTES) do fn(fireView, notes) end
    return notes
end

-- The heat of what sits on the fire, for its tank's heat bar (Holds): celsius (nil: nothing in it), a tick at the
-- boil and, if steams, at steaming (CauldronFluid.HOT_C).
function FireUI.heatOf(celsius, steams)
    local marks = {}
    local hot, boil = CauldronFluid.HOT_C, CauldronFluid.BOIL_C
    if steams then table.insert(marks, { hot, tostring(hot) }) end
    table.insert(marks, { boil, tostring(boil) })
    return { celsius = celsius, marks = marks }
end

FireWindow = InfoWindow:derive("TraditionalPreservationCoreFireWindow")

function FireWindow:new(playerObj, fire)
    local o = InfoWindow.new(self, playerObj, fire)
    o.title = getText(lookOf(fire).title)
    return o
end

function FireWindow.open(playerObj, fire)
    InfoWindow.open(FireWindow, playerObj, fire)
end

function FireWindow:refresh()
    local fire = self.station
    local attachment, part = Fire.attachmentOf(fire)
    local connection, joined = Fire.connectionOf(fire)
    self.fireView = { fire = fire, playerObj = self.playerObj, part = part, attachment = attachment, fireModData = Fire.fireModDataNow(fire), connection = connection, joined = joined,
        lit = Fire.isBurning(fire), banked = Fire.isBanked(fire), fuelMin = fire:getFuelAmount(),
        burnHours = Fire.fuelHours(fire), help = Fire.isBare(fire) and Fire.kindOf(fire).display.help or nil,
        lore = Fire.kindOf(fire).display.lore }
end

local FIRE_TEXTS = { banked = "IGUI_TraditionalPreservationCore_InfoFireBanked", lit = "IGUI_TraditionalPreservationCore_InfoFireLit",
    out = "IGUI_TraditionalPreservationCore_InfoFireOut" }
-- The band under the title, by the fire: red lit, orange banked, grey out (user, session 62), and what it says.
local FIRE_BANDS = {
    lit = { colour = { 0.67, 0.22, 0.16 }, dark = { 0.27, 0.1, 0.08 }, text = "IGUI_TraditionalPreservationCore_BandLit",
        word = "IGUI_TraditionalPreservationCore_BandStoked" },   -- STOKED, not LIT (user)
    banked = { colour = { 0.92, 0.55, 0.16 }, dark = { 0.47, 0.24, 0.06 }, text = "IGUI_TraditionalPreservationCore_BandBanked" },
    out = { colour = { 0.51, 0.51, 0.51 }, dark = { 0.18, 0.18, 0.18 }, text = "IGUI_TraditionalPreservationCore_BandOut" },
}

-- The wood as five cells of 12 hours, the time it burns on and how.
local function woodHolding(fireView, fireText)
    local burnMin = math.floor(fireView.burnHours * 60)
    return { kind = "cells", name = getText("IGUI_TraditionalPreservationCore_InfoWood"),
        share = fireView.fuelMin / FUEL_SCALE_MIN, pattern = "media/textures/TPCell_Wood.png",
        amount = say("IGUI_TraditionalPreservationCore_InfoFuelValue", tostring(math.floor(burnMin / 60)), tostring(burnMin % 60)),
        state = string.lower(fireText) }
end

-- Light the Fire opens vanilla's own light menu under the button (what to light it with, the fuel it needs), as
-- vanilla's loot window Light button does for a fireplace.
local function openLightMenu(window, fire, button)
    local playerObj = window.playerObj
    local x, y = window:getAbsoluteX() + button.x, window:getAbsoluteY() + button.y + button.height
    local context = ISContextMenu.get(playerObj:getPlayerNum(), x, y)
    ISCampingMenu.doLightFireOption(playerObj, context, nil, fire:hasFuel(), ISCampingMenu.getNearbyFuelInfo(playerObj),
        fire, ISBBQLightFromPetrol, ISBBQLightFromLiterature, ISBBQLightFromKindle)
end

-- The band's button (the Lighter or the Extinguisher, icon only): Light the Fire on a fire that is out, Put Out the Fire on a lit or banked one (vanilla's
-- extinguish for a lit one; a banked one's own, as the menu's Put out Fire).
local function lightOrOut(window, fireView)
    local fire, playerObj = window.station, window.playerObj
    if fireView.lit or fireView.banked then
        return { title = getText("ContextMenu_TraditionalPreservationCore_PutOutFire"), icon = OUT_ICON, enabled = true,
            tooltip = getText("IGUI_TraditionalPreservationCore_PutOutHelp"), onClick = function()
                if fireView.banked then return onFireAction(playerObj, fire, "out") end
                ISBBQMenu.onExtinguish(nil, playerObj:getPlayerNum(), fire)
            end }
    end
    return { title = getText("ContextMenu_TraditionalPreservationCore_LightFire"), icon = LIGHT_ICON, enabled = true,
        tooltip = getText("IGUI_TraditionalPreservationCore_LightHelp"),
        onClick = function(clicked) openLightMenu(window, fire, clicked) end }
end

-- Bank the Fire works on a burning fire, Stoke the Fire on a banked one; the other says why not.
local function fireButtons(window, fireView)
    local fire, playerObj = window.station, window.playerObj
    local function button(mode, title, help, refusal)
        local enabled = refusal == nil
        return { title = getText(title), icon = FireUI.fireIcon(fire, mode), enabled = enabled,
            tooltip = getText(enabled and help or refusal), onClick = function() onFireAction(playerObj, fire, mode) end }
    end
    local out = not fireView.lit and not fireView.banked
    return {
        button("bank", "ContextMenu_TraditionalPreservationCore_BankFire", "IGUI_TraditionalPreservationCore_BankHelp",
            out and "IGUI_TraditionalPreservationCore_FireIsOut" or fireView.banked and "IGUI_TraditionalPreservationCore_BankedAlready" or nil),
        button("stoke", "ContextMenu_TraditionalPreservationCore_StokeFire", "IGUI_TraditionalPreservationCore_StokeHelp",
            out and "IGUI_TraditionalPreservationCore_FireIsOut" or not fireView.banked and "IGUI_TraditionalPreservationCore_BurningAlready" or nil),
    }
end

function FireWindow:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed or not self.fireView then return end
    local fireView = self.fireView
    local y = self:top()

    local state = fireView.banked and "banked" or fireView.lit and "lit" or "out"
    local fireText = getText(FIRE_TEXTS[state])
    -- The band says it: lit or banked with the time it burns on, out with the wood in it, or none.
    local band = FIRE_BANDS[state]
    local burnMin = math.floor(fireView.burnHours * 60)
    local time = say("IGUI_TraditionalPreservationCore_InfoFuelValue", tostring(math.floor(burnMin / 60)), tostring(burnMin % 60))
    local bandText = (state ~= "out" or fireView.fuelMin > 0) and say(band.text, time) or getText("IGUI_TraditionalPreservationCore_BandNoWood")
    y = self:band(band.word and getText(band.word) or fireText, bandText, band.colour, band.dark, lightOrOut(self, fireView))
    -- What it holds: the wood, then what is fitted (its holds; an attachment with rows only draws them under).
    local holdings = { woodHolding(fireView, fireText) }
    local attachment = fireView.attachment
    if attachment and attachment.holds then attachment.holds(fireView, holdings) end
    -- Its kind's lore beside the holdings, when there is room.
    y = self:holds(y, holdings, fireView.lore and getText(fireView.lore) or nil)
    if attachment and attachment.rows then y = attachment.rows(self, y, fireView) end
    y = self:buttonRow(y + InfoWindow.BAR_GAP, fireButtons(self, fireView))
    self:drawNotes(y, FireUI.notes(fireView))
end

-- Clicking a fire opens its Info, as clicking a TP station opens its window (its firebox is still in the loot window
-- beside it).
return FireUI
