-- Traditional Preservation core: the Hearth is worked from its right-click menu. Vanilla's own menu lights and feeds
-- the fire; ours, inside vanilla's Hearth submenu, banks a lit fire or stokes it up again and has what is fitted
-- add its own rows (Hearth.attach's status and menu: the copper's are CopperUI's). Hearth Info, also on the menu,
-- shows the fire, its fuel and the attachment's rows and notes. A Hearth can't be picked up while it burns or while
-- its attachment can't come off (Hearth.canRemove). Clicking a Hearth opens Hearth Info too. Mods add their own rows
-- to the copper's menu with HearthUI.addMenu and notes to Hearth Info with HearthUI.addNotes.
-- A Firebox has the same menu without the copper: Firebox Info and Bank / Stoke, plus a mod's rows
-- (HearthUI.addFireboxMenu, Fish & Meat's flue) and notes (HearthUI.addFireboxNotes).
require "TimedActions/TPHearthFire"
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

local MENUS = {}

-- fn(menu, playerObj, hearth, copper) adds a mod's own rows to the Hearth's menu, after Pour into Copper.
function HearthUI.addMenu(fn)
    table.insert(MENUS, fn)
end

-- The rows HearthUI.addMenu gave, for the copper's menu to place.
function HearthUI.modRows(menu, playerObj, hearth, copper)
    for _, fn in ipairs(MENUS) do fn(menu, playerObj, hearth, copper) end
end

-- A Hearth: what is fitted says what it holds first, then Hearth Info, Bank / Stoke and the attachment's own rows.
local function addHearthMenu(context, playerObj, hearth)
    Hearth.fireStateOf(hearth)
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
end

local FIREBOX_MENUS = {}

-- fn(menu, playerObj, firebox, state) adds a mod's own rows to the Firebox's menu, after Bank / Stoke.
function HearthUI.addFireboxMenu(fn)
    table.insert(FIREBOX_MENUS, fn)
end

local function addFireboxMenu(context, playerObj, firebox)
    local state = Hearth.fireStateOf(firebox)
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

UI.keepDoorsFree()

-- Picking a Hearth or Firebox up while the fire burns (lit or banked), or while what is fitted can't come off (the
-- copper holding anything), would lose them. The cursor says Too hot for the fire, Has items for the rest.
UI.keepInPlace(function(object)
    if not Hearth.isFire(object) then return nil end
    local ok, why = Hearth.canRemove(object)
    if ok then return nil end
    return why == "Burning" and "tooHot" or true
end)

-- Hearth Info: the fire, its fuel and the attachment's rows and notes.

local NOTES, FIREBOX_NOTES = {}, {}

-- fn(info, notes) adds lines to Hearth Info's notes, after the attachment's. info = { copper (the attachment's state),
-- state (the fire's), lit, banked, fuelMin, burnHours }.
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
    local state = Hearth.fireStateOf(hearth)
    local spec, part = Hearth.attachmentOf(hearth)
    self.info = { copper = part or state, state = state, spec = spec, lit = Hearth.isBurning(hearth),
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
        for _, fn in ipairs(FIREBOX_NOTES) do fn(info, notes) end
        self:drawNotes(y, notes)
        return
    end
    local spec, notes = info.spec, {}
    if spec and spec.rows then y = spec.rows(self, y, info) end
    if spec and spec.notes then spec.notes(info, notes) end
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
