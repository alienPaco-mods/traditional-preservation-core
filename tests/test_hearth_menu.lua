-- Checks the Hearth's right-click menu and its pick-up rule with stand-ins for the engine. Run from
-- TraditionalPreservationCore: luajit tests/test_hearth_menu.lua
local H = dofile("tests/harness.lua")
local check = H.check
package.path = "42/media/lua/shared/?.lua;42/media/lua/client/?.lua;" .. package.path
H.installClock(100)
H.installModData()
H.installEvents()
H.installGetText()

-- The core's own modules and actions load for real, vanilla's are left out.
local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") or name:find("^TimedActions/TP") then return realRequire(name) end
end

local ui = H.installMenus()

local Hearth = require "TraditionalPreservationCore/Hearth"
require "TraditionalPreservationCore/HearthUI"
local onFillMenu = H.handlers.OnFillWorldObjectContextMenu[1]

local menu = H.menu

local function named(aMenu, key)
    return aMenu:getOptionFromName(getText(key))
end

local function hearth(copper, lit)
    local modData = { [Hearth.KEY] = copper or {} }
    local square = { getX = function() return 5 end, getY = function() return 5 end, getZ = function() return 0 end }
    return {
        class = "IsoFireplace",
        lit = lit or false,
        getSprite = function() return { getName = function() return Hearth.sprite("Empty", 0) end } end,
        getModData = function() return modData end,
        getSquare = function() return square end,
        getTileName = function() return "Stone Oven" end,
        isLit = function(self) return self.lit end,
        getFuelAmount = function() return 120 end,
    }
end

-- Vanilla's fireplace: the same class, another tile.
local fireplace = { class = "IsoFireplace", getSprite = function() return { getName = function() return "fixtures_fireplaces_01_0" end } end }

-- Opens the menu on a hearth and returns the Hearth submenu.
local function open(aHearth, context)
    context = context or menu()
    onFillMenu(0, context, { fireplace, aHearth }, false)
    local option = context:getOptionFromName("Stone Oven") or named(context, "IGUI_CraftingWindow_TPHearth")
    return option and option.subOption, context
end

-- The controller's probe, and other objects
local context = menu()
onFillMenu(0, context, { hearth() }, true)
check("the controller's probe is told there is a menu, and nothing is built", ui.probes == 1 and #context.options == 0)
onFillMenu(0, context, { fireplace }, false)
check("any other fireplace gets no menu from us", #context.options == 0)

-- An empty copper, nothing to pour
local sub = open(hearth())
check("a Hearth gets its own menu when vanilla has made none", sub ~= nil)
check("the first line is the copper's status, greyed", sub.options[1].name == getText("IGUI_TraditionalPreservationCore_CopperEmpty")
    and sub.options[1].isDisabled == true)
check("Hearth Info is on it", named(sub, "ContextMenu_TraditionalPreservationCore_HearthInfo") ~= nil)
local pour = named(sub, "ContextMenu_TraditionalPreservationCore_PourIntoCopper")
check("pouring is greyed with nothing to pour", pour.isDisabled == true and pour.subOption == nil
    and pour.toolTip.description == getText("IGUI_TraditionalPreservationCore_NoFluidItem"))
check("an empty copper has nothing to fill from", named(sub, "ContextMenu_TraditionalPreservationCore_FillFromCopper") == nil)
check("a cold hearth has no fire to bank", named(sub, "ContextMenu_TraditionalPreservationCore_BankFire") == nil
    and named(sub, "ContextMenu_TraditionalPreservationCore_StokeFire") == nil)

-- Vanilla's own submenu
context = menu()
local vanilla = context:addOption("Stone Oven")
context:addSubMenu(vanilla, menu())
sub = open(hearth(), context)
check("the copper's options go into vanilla's submenu, not a second one", #context.options == 1 and sub == vanilla.subOption
    and #sub.options >= 3)

-- The fire
local lit = hearth({}, true)
sub = open(lit)
local bank = named(sub, "ContextMenu_TraditionalPreservationCore_BankFire")
check("a lit fire can be banked", bank ~= nil and named(sub, "ContextMenu_TraditionalPreservationCore_StokeFire") == nil)
local character = { isTimedActionInstant = function() return false end }
bank.onSelect(character, unpack(bank.args))
check("choosing it walks over and queues the fire action", ui.walks == 1 and #ui.queued == 1 and ui.queued[1].Type == "TPHearthFire"
    and ui.queued[1].mode == "bank" and ui.queued[1].hearth == lit)
lit:getModData()[Hearth.KEY].banked = true
sub = open(lit)
check("a banked fire can be stoked", named(sub, "ContextMenu_TraditionalPreservationCore_StokeFire") ~= nil
    and named(sub, "ContextMenu_TraditionalPreservationCore_BankFire") == nil)

-- Pouring in
local milk, water = H.vessel("Pot of Milk", "CowMilk", 3, 5), H.vessel("Bucket of Water", "Water", 8, 10)
local mixture = H.vessel("Odd Bottle", "Mix", 1, 1)
local kept = H.vessel("My Flask", "Water", 1, 1, { isFavorite = function() return true end })
local empty = H.vessel("Empty Bucket", nil, 0, 10)
ui.carried = { milk, water, mixture, kept, empty }
local holdsWater = hearth({ ml = 2000, fluid = "Water", tempC = 20 })
sub = open(holdsWater)
check("the status line reads the copper", sub.options[1].name:find("2.0", 1, true) ~= nil and sub.options[1].name:find("Water", 1, true) ~= nil)
pour = named(sub, "ContextMenu_TraditionalPreservationCore_PourIntoCopper")
local entries = pour.subOption.options
check("pouring lists every container with fluid in it, favourites and empties left out", #entries == 3
    and entries[1].args[2] == milk and entries[2].args[2] == water and entries[3].args[2] == mixture)
check("each with its litres", entries[2].name:find("Bucket of Water", 1, true) ~= nil and entries[2].name:find("8.0", 1, true) ~= nil)
check("another fluid than the copper's is red, with the reason", entries[1].notAvailable == true
    and entries[1].toolTip.description:find("Water", 1, true) ~= nil)
check("the copper's own fluid is offered", entries[2].notAvailable == nil and entries[2].toolTip == nil)
check("a mixture is red too", entries[3].notAvailable == true
    and entries[3].toolTip.description == getText("IGUI_TraditionalPreservationCore_NotOneFluid"))
entries[2].onSelect(character, unpack(entries[2].args))
check("choosing one brings it to hand and queues the pour", ui.moved[1] == water and ui.queued[2].Type == "TPHearthCopper"
    and ui.queued[2].mode == "pourIn" and ui.queued[2].item == water and ui.queued[2].hearth == holdsWater)

sub = open(hearth({}))
entries = named(sub, "ContextMenu_TraditionalPreservationCore_PourIntoCopper").subOption.options
check("an empty copper takes any one fluid", entries[1].notAvailable == nil and entries[2].notAvailable == nil
    and entries[3].notAvailable == true)

sub = open(hearth({ ml = Hearth.COPPER_ML, fluid = "Water", tempC = 20 }))
pour = named(sub, "ContextMenu_TraditionalPreservationCore_PourIntoCopper")
check("a full copper takes no more", pour.isDisabled == true and pour.subOption == nil
    and pour.toolTip.description == getText("IGUI_TraditionalPreservationCore_CopperFull"))

-- Filling from the copper
sub = open(holdsWater)
local fill = named(sub, "ContextMenu_TraditionalPreservationCore_FillFromCopper")
entries = fill.subOption.options
check("filling lists empty containers and those of the copper's fluid with room", #entries == 2
    and entries[1].args[2] == water and entries[2].args[2] == empty)
entries[2].onSelect(character, unpack(entries[2].args))
check("choosing one queues the fill", ui.queued[3].Type == "TPHearthCopper" and ui.queued[3].mode == "fillFrom" and ui.queued[3].item == empty)
ui.carried = { milk, mixture }
fill = named(open(holdsWater), "ContextMenu_TraditionalPreservationCore_FillFromCopper")
check("with nothing to fill, the option is greyed with the reason", fill.isDisabled == true
    and fill.toolTip.description == getText("IGUI_TraditionalPreservationCore_NoRoomItem"))

-- Picking a Hearth up
local props = {}
check("a cold, empty Hearth can be picked up", ISMoveableSpriteProps.canPickUpMoveable(props, character, nil, hearth()) == true)
check("not while it burns", ISMoveableSpriteProps.canPickUpMoveable(props, character, nil, hearth({}, true)) == false)
check("nor while the copper holds anything", ISMoveableSpriteProps.canPickUpMoveable(props, character, nil, holdsWater) == false)
ISMoveableSpriteProps.getInfoPanelFlagsPerTile(props, nil, holdsWater, character, "pickup")
check("and the pick-up cursor says why", InfoPanelFlags.hasItems == true)
ISMoveableSpriteProps.getInfoPanelFlagsPerTile(props, nil, hearth(), character, "pickup")
check("but not for one that can go", InfoPanelFlags.hasItems == false)
ui.vanillaPickUp = false
check("vanilla's own refusal still stands", ISMoveableSpriteProps.canPickUpMoveable(props, character, nil, hearth()) == false)

check("no text would make the game's formatter warn" .. (H.textWarnings[1] and " (" .. table.concat(H.textWarnings, "; ") .. ")" or ""),
    #H.textWarnings == 0)

H.done()
