-- Checks RecipeUI.oneOrAll (One and All on a vessel's recipe row) with stand-ins for the engine. Run from
-- TraditionalPreservationCore: luajit tests/test_recipe_menu.lua
local H = dofile("tests/harness.lua")
local check, list = H.check, H.list
package.path = "42/media/lua/shared/?.lua;42/media/lua/client/?.lua;" .. package.path
H.installEvents()
H.installGetText()

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end
local ui = H.installMenus()

-- A menu as vanilla's ISContextMenu keeps it: param1.. on each option, a submenu by its number.
local menus = {}
local function menu()
    local self = { options = {} }
    table.insert(menus, self)
    self.subOptionNums = #menus
    function self:addOption(name, target, onSelect, param1, param2, param3, param4)
        local option = { name = name, target = target, onSelect = onSelect, param1 = param1, param2 = param2,
            param3 = param3, param4 = param4 }
        table.insert(self.options, option)
        return option
    end
    function self:getNew() return menu() end
    function self:addSubMenu(option, sub) option.subOption = sub.subOptionNums end
    function self:getSubMenu(number) return menus[number] end
    return self
end
local function choose(option)
    option.onSelect(option.target, option.param1, option.param2, option.param3, option.param4)
end

-- The recipe takes half a litre of Broth; possible says how many the rest in reach allows.
local recipe = { getScriptObjectFullType = function() return "Mod.MakeSoup" end, isCanBeDoneFromFloor = function() return true end }
local possible, performable = 5, 0
local POTATO_WATER = {}
Fluid = { Get = function(name) return name == "Broth" and POTATO_WATER or nil end }
local function pot(litres)
    local item = H.vessel("Pot", "Broth", litres, 1.5, { class = "InventoryItem" })
    item.getFluidContainer().getSpecificFluidAmount = function(_, fluid) return fluid == POTATO_WATER and litres or 0 end
    return item
end
local logics = {}
HandcraftLogic = { new = function()
    local logic = { started = 0, stopped = 0 }
    function logic:findCraftSurface() end
    function logic:setIsoObject() end
    function logic:setContainers() end
    function logic:setRecipeFromContextClick(_, vessel) self.vessel = vessel end
    function logic:getPossibleCraftCount() return possible end
    function logic:canPerformCurrentRecipe() return performable > 0 end
    function logic:getRecipeData() return { getAllInputItems = function() return list({}) end,
        getAllPutBackInputItems = function() return list({}) end } end
    function logic:startCraftAction() self.started = self.started + 1 end
    function logic:stopCraftAction() self.stopped = self.stopped + 1 end
    table.insert(logics, logic)
    return logic
end }
-- Starts as vanilla's: queued, finished by calling its onComplete.
ISEntityUI.HandcraftStart = function(_, logic)
    local action = { logic = logic }
    function action:setOnComplete(fn) self.onComplete = fn end
    ISTimedActionQueue.add(action)
    return action
end
ISCraftingUI = { ReturnItemsToOriginalContainer = function() end }
local vanillaCrafts = 0
ISInventoryPaneContextMenu.OnNewCraft = function() vanillaCrafts = vanillaCrafts + 1 end

local RecipeUI = require "TraditionalPreservationCore/RecipeUI"
RecipeUI.oneOrAll({ recipe = "Mod.MakeSoup", fluid = "Broth", litres = 0.5 })
local onFill = H.handlers.OnFillInventoryObjectContextMenu[1]

-- Vanilla's row, at the top (one recipe) or in the item's submenu (two or more).
local function open(vessel, nested)
    menus = {}
    local context = menu()
    local where = context
    if nested then
        local parent = context:addOption("Pot")
        where = context:getNew(context)
        context:addSubMenu(parent, where)
        where:addOption("Something Else", vessel, function() end)
    end
    local row = where:addOption("Make Soup", vessel, ISInventoryPaneContextMenu.OnNewCraft, recipe, 0, false)
    row.iconTexture = "soup.png"
    onFill(0, context, { vessel })
    return row
end

local function subOf(row) return row.subOption and menus[row.subOption] end

-- A full pot: three
local fullPot = pot(1.5)
local row = open(fullPot)
local sub = subOf(row)
check("a full pot's row opens One and All", sub ~= nil and #sub.options == 2 and row.onSelect == nil)
check("One is vanilla's own craft, All counts three", sub.options[1].name == "ContextMenu_One"
    and sub.options[1].onSelect == ISInventoryPaneContextMenu.OnNewCraft and sub.options[1].param1 == recipe
    and sub.options[2].name == "ContextMenu_AllWithCount" and sub.options[2].param3 == 3)
check("both keep the row's icon", sub.options[1].iconTexture == "soup.png" and sub.options[2].iconTexture == "soup.png")
choose(sub.options[1])
check("One runs vanilla's craft", vanillaCrafts == 1)
row = open(pot(1.5), true)
check("in the item's submenu too", subOf(row) ~= nil and #subOf(row).options == 2)

-- All: one after the other, from the same pot, stopping when the next can't be made
row = open(fullPot)
ui.queued, logics, performable = {}, {}, 3
choose(subOf(row).options[2])
check("All queues one craft, not three at once", #ui.queued == 1 and logics[#logics].vessel == fullPot)
for _ = 1, 2 do
    performable = performable - 1
    ui.queued[#ui.queued].onComplete()
end
check("each done craft queues the next, three in all", #ui.queued == 3)
ui.queued[3].onComplete()
check("the third is the last", #ui.queued == 3)
ui.queued, performable = {}, 3
choose(subOf(open(fullPot)).options[2])
performable = 0
ui.queued[1].onComplete()
check("stops when the next can't be made", #ui.queued == 1)

-- Fewer
check("1 L: two", subOf(open(pot(1.0))).options[2].param3 == 2)
check("a hair under 1 L (float error): still two", subOf(open(pot(0.99999))).options[2].param3 == 2)
possible = 2
check("the jars and flour in reach cap it", subOf(open(pot(1.5))).options[2].param3 == 2)
possible = 5
row = open(pot(0.5))
check("one craft's worth: vanilla's row left as it is", row.subOption == nil and row.onSelect == ISInventoryPaneContextMenu.OnNewCraft)
possible = 1
row = open(pot(1.5))
check("one possible: left as it is", row.subOption == nil)
possible = 5

-- Not ours
local other = H.vessel("Pot", "Water", 1.5, 1.5, { class = "InventoryItem" })
other.getFluidContainer().getSpecificFluidAmount = function() return 0 end
check("a pot of something else: untouched", open(other).subOption == nil)
local greyed = pot(1.5)
menus = {}
local context = menu()
row = context:addOption("Make Soup", greyed, ISInventoryPaneContextMenu.OnNewCraft, recipe, 0, false)
row.notAvailable = true
onFill(0, context, { greyed })
check("a greyed row: untouched", row.subOption == nil)

H.done()
