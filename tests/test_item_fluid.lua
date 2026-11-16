-- Checks ItemFluid (fluid that turns, goes off and burns in a pot or saucepan) and Action.replaceItem, on stand-ins
-- for the engine. Run from TraditionalPreservationCore: luajit tests/test_item_fluid.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near
package.path = "42/media/lua/shared/?.lua;" .. package.path
H.preloadVanilla()
H.installClock(0)

local ItemFluid = require "TraditionalPreservationCore/ItemFluid"
local Action = require "TraditionalPreservationCore/Action"

check("nothing named: no look at the stoves", ItemFluid.lookHeat() == nil)
ItemFluid.turnsHot("Raw", "Clear", 1)
ItemFluid.goesOff("Raw", "Spoilt")
ItemFluid.burns("Clear", 1, { ["Base.Pot"] = "Mod.BurntPot" })
ItemFluid.staysIn("Raw")
check("named: the stoves are looked at, at steaming heat", ItemFluid.lookHeat() == ItemFluid.HOT_HEAT)
check("a fluid is named once", not pcall(ItemFluid.turnsHot, "Raw", "Other", 1)
    and not pcall(ItemFluid.goesOff, "Raw", "Other") and not pcall(ItemFluid.burns, "Clear", 1, {}))
check("burns needs a mapper", not pcall(ItemFluid.burns, "Other", 1))

-- The rules, on a plain record. Looks a minute apart while hot.
local function steam(record, fluid, from, to, vessel)
    local burnt
    for minute = from, to do
        fluid, burnt = ItemFluid.advance(record, fluid, minute / 60, true, vessel or "Base.Pot")
        if burnt then return fluid, true, minute end
    end
    return fluid, false
end

local record = {}
ItemFluid.putPieces(record, { 100, 30, 50 }, 0)
check("pieces: the lot goes off with the oldest", record.offAt == 30 and record.hot == 0)
local fluid = steam(record, "Raw", 0, 59)
check("59 minutes steaming: still raw", fluid == "Raw" and near(record.hot, 59 / 60))
fluid = steam(record, "Raw", 60, 60)
check("an hour in all: it turns, and no longer goes off", fluid == "Clear" and record.offAt == nil and near(record.hot, 0))
local burnt, at
fluid, burnt, at = steam(record, fluid, 61, 200)
check("an hour more steaming: it burns", burnt and fluid == "Clear" and at == 120)
local saucepan = {}
local _, never = steam(saucepan, "Clear", 0, 200, "Base.Bucket")
check("a vessel the mapper doesn't name never burns", not never)

local cooled = {}
steam(cooled, "Raw", 0, 30)
ItemFluid.advance(cooled, "Raw", 31 / 60, false)
steam(cooled, "Raw", 40, 45)
check("off the heat the count stops; back on, a long gap doesn't count", near(cooled.hot, 35 / 60))
ItemFluid.putPieces(cooled, { 10 }, 1)
check("more pieces start the hour over", cooled.hot == 0 and cooled.offAt == 11)
check("unheated it goes off at offAt", ItemFluid.advance(cooled, "Raw", 11, false) == "Spoilt" and cooled.offAt == nil)
check("only a fluid that goes off does", ItemFluid.advance({ offAt = 0 }, "Clear", 5, false) == "Clear")
check("hours left to turn and to burn", near(ItemFluid.hoursToTurn({ hot = 0.25 }, "Raw"), 0.75)
    and near(ItemFluid.hoursToBurn({ hot = 0.5 }, "Clear"), 0.5) and ItemFluid.hoursToTurn({}, "Clear") == nil)

check("room: a 1.5 L pot takes 6 quarter litres, a 0.6 L saucepan 2",
    ItemFluid.pieceRoom(1.5, 0, false, 250) == 6 and ItemFluid.pieceRoom(0.6, 0, false, 250) == 2)
check("a pot holding a litre of the fluid 2 more, of anything else none",
    ItemFluid.pieceRoom(1.5, 1.0, true, 250) == 2 and ItemFluid.pieceRoom(1.5, 1.0, false, 250) == 0)
check("float error doesn't lose a piece", ItemFluid.pieceRoom(1.5, 0.7499999, true, 250) == 3)

-- The engine: a pot on a stove, swapped for its burnt item where it lies.
Fluid = { Get = function(name) return name end }
local function pot(fullType, heat)
    local fluids = {}
    local function total()
        local sum = 0
        for _, litres in pairs(fluids) do sum = sum + litres end
        return sum
    end
    local container = {
        isEmpty = function() return total() <= 0 end,
        getAmount = total,
        getCapacity = function() return 1.5 end,
        getPrimaryFluid = function()
            local most
            for name, litres in pairs(fluids) do if not most or litres > fluids[most] then most = name end end
            return most and { getFluidTypeString = function() return most end }
        end,
        getPrimaryFluidAmount = function()
            local most = 0
            for _, litres in pairs(fluids) do most = math.max(most, litres) end
            return most
        end,
        addFluid = function(_, name, litres) fluids[name] = (fluids[name] or 0) + litres end,
        adjustSpecificFluidAmount = function(_, name, litres) fluids[name] = litres > 0 and litres or nil end,
        Empty = function() for name in pairs(fluids) do fluids[name] = nil end end,
        canEmpty = true,
    }
    function container:setCanPlayerEmpty(b) self.canEmpty = b end
    local item = { fluids = fluids, heat = heat or 1, modData = {}, condition = 7 }
    function item:getFluidContainer() return container end
    function item:getModData() return self.modData end
    function item:getItemHeat() return self.heat end
    function item:getFullType() return fullType end
    function item:getCondition() return self.condition end
    function item:getWorldItem() return nil end
    function item:getContainer() return self.inside end
    return item
end
local stove = { items = {} }
function stove:Remove(item) for i, held in ipairs(self.items) do if held == item then table.remove(self.items, i) end end end
function stove:AddItem(item) table.insert(self.items, item) item.inside = self return item end
function instanceItem(fullType)
    local made = { fullType = fullType }
    function made:setCondition(c) self.condition = c end
    function made:setBurnt(b) self.burnt = b end
    return made
end

local cookPot = pot("Base.Pot", ItemFluid.HOT_HEAT)
stove:AddItem(cookPot)
check("room for 6 in an empty pot", ItemFluid.roomFor(cookPot, "Raw", 250) == 6)
check("3 pieces go in as three quarter litres", ItemFluid.addPieces(cookPot, "Raw", 250, { 48, 24, 72 }, 0) == 3
    and near(cookPot.fluids.Raw, 0.75) and cookPot.modData.tpItemFluid.offAt == 24)
check("raw, the pot can't be poured, emptied or drunk from", cookPot:getFluidContainer().canEmpty == false)
check("3 more fit, and no more", ItemFluid.roomFor(cookPot, "Raw", 250) == 3
    and ItemFluid.addPieces(cookPot, "Raw", 250, { 10, 10, 10, 10 }, 0) == 3 and near(cookPot.fluids.Raw, 1.5)
    and cookPot.modData.tpItemFluid.offAt == 10)
for minute = 1, 62 do ItemFluid.look(cookPot, minute / 60) end
check("an hour on the stove: all of it clarified, and it pours again", cookPot.fluids.Raw == nil
    and near(cookPot.fluids.Clear, 1.5) and cookPot:getFluidContainer().canEmpty == true)
check("a clarified pot takes no raw pieces", ItemFluid.roomFor(cookPot, "Raw", 250) == 0)
for minute = 63, 125 do ItemFluid.look(cookPot, minute / 60) end
local burntPot = stove.items[1]
check("another hour: emptied and swapped in place for the burnt pot, its condition kept", #stove.items == 1
    and burntPot.fullType == "Mod.BurntPot" and burntPot.burnt and burntPot.condition == 7 and cookPot.fluids.Clear == nil)

local cold = pot("Base.Pot", 1)
stove:AddItem(cold)
ItemFluid.addPieces(cold, "Raw", 250, { 5 }, 0)
ItemFluid.look(cold, 6)
check("unheated it goes off by its oldest piece, and can be emptied", near(cold.fluids.Spoilt, 0.25) and cold.fluids.Raw == nil
    and cold:getFluidContainer().canEmpty == true)
cold.fluids.Spoilt = nil
cold.fluids.Water = 1
ItemFluid.look(cold, 7)
check("a pot of anything not named forgets its record", cold.modData.tpItemFluid == nil)
local sealed = pot("Base.Pot")
sealed:getFluidContainer().canEmpty = false
sealed.fluids.Milk = 1
ItemFluid.look(sealed, 8)
check("a sealed item with no record is left sealed", sealed:getFluidContainer().canEmpty == false)

local changedMind = pot("Base.Pot")
ItemFluid.addPieces(changedMind, "Raw", 250, { 100 }, 0)
check("raw, it is sealed", changedMind:getFluidContainer().canEmpty == false)
changedMind:getFluidContainer():Empty()
ItemFluid.look(changedMind, 1)
check("emptied (TPEmptyFluid), it forgets the butter and is unsealed", changedMind:getFluidContainer().canEmpty == true
    and changedMind.modData.tpItemFluid == nil)

-- Action.replaceItem: in a container, and nowhere.
local loose = pot("Base.Pot")
check("an item held by nothing isn't replaced", Action.replaceItem(loose, instanceItem("X")) == nil)

H.done()
