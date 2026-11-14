-- Traditional Preservation core: the rules for what the cauldron holds (Cauldron.lua, the Hearth's first attachment).
-- One fluid at a time, or a blend of fluids a mod has said may share it (blend: Dairy's milks). It heats towards
-- MAX_C (water boils, and boils clean) while the fire burns and cools to the room when it is out. Its state is a plain
-- table (the fire's modData under Hearth.KEY, then Hearth.CAULDRON); every rule here works on it without the engine.
-- The few that touch the engine (a container's fluids, an item's heat, a fluid's colour) are at the bottom.
-- Hearth passes every function and constant here on, so mods keep calling Hearth.pourInto, Hearth.advance and so on.
local CauldronFluid = {}

CauldronFluid.CAULDRON_ML = 60000     -- a farmhouse cauldron's size (real ones 40 to 100 L)
CauldronFluid.TAU_ML = 10000          -- the litres the time constants below are for; more heats and cools slower
CauldronFluid.MAX_C = 95              -- over a fire; nothing in it quite boils
CauldronFluid.HOT_C = 85              -- steaming
CauldronFluid.LIT_TAU = 0.75          -- hours, for 10 L over a lit fire: 20 to 85 C in about an hour and a half
CauldronFluid.OUT_TAU = 2.0           -- hours, for 10 L once the fire is out: the stone holds its heat
CauldronFluid.FLOOR_ML = 1000         -- a splash heats as fast as a litre
CauldronFluid.BANKED_C = 50           -- the cauldron's heat over banked embers

-- Water is let boil: over a lit fire it heats towards WATER_FIRE_C and holds at BOIL_C. Tainted water kept at the
-- boil for BOIL_HOURS turns clean (BOILED). Every other fluid is kept off the boil, at MAX_C.
CauldronFluid.BOIL_C = 100
CauldronFluid.WATER_FIRE_C = 110
CauldronFluid.BOIL_HOURS = 1 / 6
CauldronFluid.BOILS = { Water = true, TaintedWater = true }
CauldronFluid.BOILED = { TaintedWater = "Water" }

-- Vanilla's item heat, for fluids poured between the cauldron and the player's containers. Vanilla cools a
-- container in the player's hands to room heat within seconds.
CauldronFluid.ROOM_C = 20
CauldronFluid.HEAT_PER_DEGREE = 1 / 133   -- itemHeat 1.0 is room temperature; 1.6 (water turns clean) is about 100 C
CauldronFluid.COLD_HEAT = 0.2             -- the engine's floor: an item in a powered fridge or freezer
CauldronFluid.COLD_C = 4                  -- what that reads as; below room heat the scale is gentler than above it

-- Vanilla's fluid amounts are litres, the cauldron's ml; a container holding a hair more than its fluids add up to
-- (float error) still holds only them.
CauldronFluid.ML_PER_L = 1000
CauldronFluid.AMOUNT_TOLERANCE_L = 0.001

-- What an empty cauldron's state keeps of its fluid: nothing (Hearth.take clears them).
local FLUID_FIELDS = { "ml", "fluid", "parts", "tempC", "last", "boiled", "hot", "held", "offAt" }

-- Newton's law: tempC after hours at placeC, for a time constant tau.
function CauldronFluid.cool(tempC, placeC, hours, tau)
    return placeC + (tempC - placeC) * math.exp(-hours / tau)
end

-- Hours for a fluid at fromC, moving towards target with time constant tau, to reach toC (toC between the two).
local function hoursTo(fromC, toC, target, tau)
    return tau * math.log((target - fromC) / (target - toC))
end

local COLD_PER_DEGREE = (1 - CauldronFluid.COLD_HEAT) / (CauldronFluid.ROOM_C - CauldronFluid.COLD_C)

function CauldronFluid.heatCelsius(itemHeat)
    itemHeat = itemHeat or 1
    if itemHeat < 1 then
        return CauldronFluid.ROOM_C + (math.max(itemHeat, CauldronFluid.COLD_HEAT) - 1) / COLD_PER_DEGREE
    end
    return math.min(CauldronFluid.ROOM_C + (itemHeat - 1) / CauldronFluid.HEAT_PER_DEGREE, CauldronFluid.MAX_C)
end

-- The other way, for fluid poured back out: it starts at the heat it had.
function CauldronFluid.itemHeat(celsius)
    if celsius < CauldronFluid.ROOM_C then
        return math.max(1 + (celsius - CauldronFluid.ROOM_C) * COLD_PER_DEGREE, CauldronFluid.COLD_HEAT)
    end
    return 1 + (celsius - CauldronFluid.ROOM_C) * CauldronFluid.HEAT_PER_DEGREE
end

function CauldronFluid.cauldronTau(ml, lit)
    local base = lit and CauldronFluid.LIT_TAU or CauldronFluid.OUT_TAU
    return base * (math.max(ml, CauldronFluid.FLOOR_ML) / CauldronFluid.TAU_ML) ^ (1 / 3)
end

-- Whether the cauldron's fluid is let boil: water on its own.
function CauldronFluid.boils(cauldron)
    return CauldronFluid.BOILS[cauldron.fluid] == true and not cauldron.parts
end

-- The heat the cauldron heats towards while the fire burns, lit or banked.
function CauldronFluid.fireTarget(cauldron, banked)
    if banked then return CauldronFluid.BANKED_C end
    return CauldronFluid.boils(cauldron) and CauldronFluid.WATER_FIRE_C or CauldronFluid.MAX_C
end

-- Fluids that may share the cauldron, as a cow's and a sheep's milk do: a mod names each group, a fluid in one
-- group only. Anything else is one fluid at a time.
local BLENDS = {}

function CauldronFluid.blend(...)
    local group = {}
    for _, name in ipairs({ ... }) do
        assert(BLENDS[name] == nil, "Hearth.blend: fluid " .. tostring(name) .. " is already in a blend")
        group[name] = true
        BLENDS[name] = group
    end
end

function CauldronFluid.blends(a, b)
    return a == b or (BLENDS[a] ~= nil and BLENDS[a][b] == true)
end

-- parts ({ name = ml }) in the same shares, adding up to ml.
local function share(parts, ml)
    local total, shares = 0, {}
    for _, part in pairs(parts) do total = total + part end
    if total <= 0 then return shares end
    for name, part in pairs(parts) do shares[name] = part * ml / total end
    return shares
end

-- What ml of a store (the cauldron, or a mod's own: anything with ml, fluid and parts) is, by fluid: { name = ml }.
-- parts is kept only for a blend, and only its shares count; fluid is then the largest of them.
function CauldronFluid.partsOf(state, ml)
    ml = ml or state.ml or 0
    if state.parts then return share(state.parts, ml) end
    return state.fluid and ml > 0 and { [state.fluid] = ml } or {}
end

-- Notes ml of a fluid (a name, or parts for a blend) going into a store. Call it before the store's ml grows.
function CauldronFluid.addParts(state, fluid, ml)
    local parts = CauldronFluid.partsOf(state)
    local added = type(fluid) == "table" and share(fluid, ml) or { [fluid] = ml }
    for name, part in pairs(added) do parts[name] = (parts[name] or 0) + part end
    local count, most = 0, nil
    for name, part in pairs(parts) do
        count = count + 1
        if not most or part > parts[most] or (part == parts[most] and name < most) then most = name end
    end
    state.fluid = most
    state.parts = count > 1 and parts or nil
end

-- Fluids the cauldron changes, as a mod names them (Fish & Meat's fat), each named once.
-- turnsHot(from, to, hours): from, on its own and kept steaming (HOT_C or more) for hours in all, becomes to:
-- raw fat renders. The hours are kept in the cauldron's hot, and start over when more is put in.
-- goesOff(from, to): from becomes to at the cauldron's offAt (offBy sets it), unless it turned first.
-- staysIn(name): the cauldron holds it, but no container can be filled with it.
local TURNS, OFF, STAYS = {}, {}, {}

function CauldronFluid.turnsHot(from, to, hours)
    assert(TURNS[from] == nil, "Hearth.turnsHot: fluid " .. tostring(from) .. " already turns")
    TURNS[from] = { to = to, hours = hours }
end

function CauldronFluid.goesOff(from, to)
    assert(OFF[from] == nil, "Hearth.goesOff: fluid " .. tostring(from) .. " already goes off")
    OFF[from] = to
end

function CauldronFluid.staysIn(name)
    STAYS[name] = true
end

-- Whether containers can be filled with what the cauldron holds.
function CauldronFluid.poursOut(cauldron)
    return not STAYS[cauldron.fluid]
end

-- The cauldron's fluid goes off at the hour at, or sooner if it was already going to.
function CauldronFluid.offBy(cauldron, at)
    cauldron.offAt = math.min(cauldron.offAt or at, at)
end

-- Hours of steaming still to go before the cauldron's fluid turns; nil if it never will.
function CauldronFluid.hoursToTurn(cauldron)
    local turn = (cauldron.ml or 0) > 0 and not cauldron.parts and TURNS[cauldron.fluid]
    if not turn then return nil end
    return math.max(turn.hours - (cauldron.hot or 0), 0)
end

-- How much of ml of a fluid (a name, or parts) fits, or 0 with the reason: one fluid at a time, unless they blend.
function CauldronFluid.cauldronRoom(cauldron, fluid, ml)
    if (cauldron.ml or 0) > 0 then
        for name in pairs(type(fluid) == "table" and fluid or { [fluid] = true }) do
            if not CauldronFluid.blends(cauldron.fluid, name) then return 0, "Mixed" end
        end
    end
    local room = CauldronFluid.CAULDRON_ML - (cauldron.ml or 0)
    if room <= 0 then return 0, "Full" end
    return math.min(ml, room)
end

-- Pours a fluid (a name, or parts) in; the temperatures mix by volume. Returns the ml taken (0 with a reason when
-- refused).
function CauldronFluid.pourInto(cauldron, fluid, ml, fluidC, now)
    local taken, reason = CauldronFluid.cauldronRoom(cauldron, fluid, ml)
    if taken <= 0 then return 0, reason end
    local had = cauldron.ml or 0
    cauldron.tempC = had > 0 and (cauldron.tempC * had + fluidC * taken) / (had + taken) or fluidC
    cauldron.boiled = nil
    cauldron.hot = nil
    cauldron.held = nil
    CauldronFluid.addParts(cauldron, fluid, taken)
    cauldron.ml = had + taken
    cauldron.last = cauldron.last or now
    return taken
end

-- Takes up to maxMl out, all of it if left out. Returns the ml, the main fluid, its temperature, and the ml by
-- fluid ({ name = ml }: more than one name when the cauldron holds a blend).
function CauldronFluid.take(cauldron, maxMl)
    local ml = math.min(cauldron.ml or 0, maxMl or cauldron.ml or 0)
    if ml <= 0 then return 0 end
    local fluid, tempC, parts = cauldron.fluid, cauldron.tempC, CauldronFluid.partsOf(cauldron, ml)
    cauldron.ml = cauldron.ml - ml
    if cauldron.ml <= 0 then
        for _, key in ipairs(FLUID_FIELDS) do cauldron[key] = nil end
    end
    return ml, fluid, tempC, parts
end

-- The hours out of hours that a cauldron at tempC, moving towards target, spends at HOT_C or more.
local function hoursHot(tempC, target, hours, tau)
    local hot = CauldronFluid.HOT_C
    if tempC >= hot and target >= hot then return hours end
    if tempC < hot and target <= hot then return 0 end
    local cross = hoursTo(tempC, hot, target, tau)
    if tempC < hot then return math.max(hours - cross, 0) end
    return math.min(hours, cross)
end

-- Before tempC moves towards target: counts the hours at HOT_C or more of whatever the cauldron holds, in all since
-- it was last poured into (heldHours: a mod can ask for a hold at the heat, as Dairy's scald does), and the steaming
-- hours of a fluid that turns hot (turnsHot), turning it when it has had them all. What has turned no longer goes off.
local function countHot(cauldron, target, hours, tau)
    local hot = hoursHot(cauldron.tempC, target, hours, tau)
    cauldron.held = (cauldron.held or 0) + hot
    local turn = not cauldron.parts and TURNS[cauldron.fluid]
    if not turn then return end
    cauldron.hot = (cauldron.hot or 0) + hot
    if cauldron.hot >= turn.hours then
        cauldron.fluid, cauldron.hot, cauldron.offAt = turn.to, nil, nil
    end
end

-- A fluid past its offAt becomes what it goes off to (goesOff).
local function goOff(cauldron, now)
    if not cauldron.offAt or cauldron.offAt > now then return end
    if OFF[cauldron.fluid] and not cauldron.parts then cauldron.fluid = OFF[cauldron.fluid] end
    cauldron.hot, cauldron.offAt = nil, nil
end

-- Hours of a fire under the cauldron, lit or banked: water stops at BOIL_C, and the time it spends there counts
-- towards boiling tainted water clean.
local function heat(cauldron, hours, banked)
    local target, tau = CauldronFluid.fireTarget(cauldron, banked), CauldronFluid.cauldronTau(cauldron.ml, not banked)
    countHot(cauldron, target, hours, tau)
    if target <= CauldronFluid.BOIL_C then
        cauldron.tempC = CauldronFluid.cool(cauldron.tempC, target, hours, tau)
        return
    end
    local toBoil = cauldron.tempC >= CauldronFluid.BOIL_C and 0 or hoursTo(cauldron.tempC, CauldronFluid.BOIL_C, target, tau)
    if hours <= toBoil then
        cauldron.tempC = CauldronFluid.cool(cauldron.tempC, target, hours, tau)
        return
    end
    cauldron.tempC = CauldronFluid.BOIL_C
    cauldron.boiled = (cauldron.boiled or 0) + hours - toBoil
    if cauldron.boiled >= CauldronFluid.BOIL_HOURS and CauldronFluid.BOILED[cauldron.fluid] then
        cauldron.fluid = CauldronFluid.BOILED[cauldron.fluid]
    end
end

-- Brings the cauldron up to now by the fire's state (Hearth.stateOf: fireUntil, banked; nil for no fire): heating
-- while the fire burns (to fireUntil), cooling to roomC after. Over banked embers it settles at BANKED_C, as slowly
-- as it cools: the fire is low and the stone holds the heat.
function CauldronFluid.advance(cauldron, now, roomC, fire)
    if (cauldron.ml or 0) <= 0 then return end
    local t = cauldron.last or now
    local fireUntil = fire and fire.fireUntil
    goOff(cauldron, t)
    if fireUntil and fireUntil > t then
        local stop = math.min(fireUntil, now)
        heat(cauldron, stop - t, fire.banked)
        t = stop
    end
    if now > t then
        local tau = CauldronFluid.cauldronTau(cauldron.ml, false)
        countHot(cauldron, roomC, now - t, tau)
        cauldron.tempC = CauldronFluid.cool(cauldron.tempC, roomC, now - t, tau)
        cauldron.boiled = nil
    end
    goOff(cauldron, now)
    cauldron.last = now
end

-- What the cauldron shows: Empty, Full or Hot (steaming, whatever the fluid).
function CauldronFluid.look(cauldron)
    if (cauldron.ml or 0) <= 0 then return "Empty" end
    return cauldron.tempC >= CauldronFluid.HOT_C and "Hot" or "Full"
end

function CauldronFluid.isHot(cauldron)
    return (cauldron.ml or 0) > 0 and (cauldron.tempC or 0) >= CauldronFluid.HOT_C
end

-- Hours what the cauldron holds has spent at HOT_C or more, in all, since it was last poured into.
function CauldronFluid.heldHours(cauldron)
    return (cauldron.ml or 0) > 0 and cauldron.held or 0
end

-- Hours until the cauldron is hot if the fire burns on; 0 if it is already, nil if it is empty or the fire banked.
function CauldronFluid.hoursToHot(cauldron, banked)
    if (cauldron.ml or 0) <= 0 then return nil end
    if cauldron.tempC >= CauldronFluid.HOT_C then return 0 end
    if banked then return nil end
    return hoursTo(cauldron.tempC, CauldronFluid.HOT_C, CauldronFluid.fireTarget(cauldron),
        CauldronFluid.cauldronTau(cauldron.ml, true))
end

-- Hooks: other mods' say on fluid going in and out of the cauldron. Each is a list of functions, called in order.
--   heatOf(item, now, character)  the heat in C of the fluid in item, or nil to let the next one (or vanilla's
--                                 item heat) say. A container that keeps its own heat answers here.
--   taken(item, ml)               ml left item for the cauldron.
--   filled(item, fill)            fill = { ml, fluid, parts, tempC, hot, hadMl, hadC, now, character }: ml went into
--                                 item from the cauldron. Return true if it set the item's heat itself.
local HOOKS = { heatOf = {}, taken = {}, filled = {} }

function CauldronFluid.hook(name, fn)
    assert(HOOKS[name], "Hearth.hook: no hook named " .. tostring(name))
    assert(type(fn) == "function", "Hearth.hook: " .. name .. " needs a function")
    table.insert(HOOKS[name], fn)
end

-- The engine

-- Vanilla's fluid objects, looked up the first time each is asked for (the engine may not have them at load).
local fluidObjects = {}

local function fluidObject(name)
    local fluid = fluidObjects[name]
    if not fluid then
        fluid = Fluid.Get(name)
        fluidObjects[name] = fluid
    end
    return fluid
end

-- What a fluid container holds, { name = ml }, and its main fluid: one fluid, or a blend of fluids that may share
-- the cauldron. nil for none, or for any other mixture.
function CauldronFluid.partsIn(container)
    if not container or container:isEmpty() then return nil end
    local primary = container:getPrimaryFluid()
    local name = primary and primary:getFluidTypeString()
    if not name then return nil end
    local found = container:getPrimaryFluidAmount()
    local parts = { [name] = found * CauldronFluid.ML_PER_L }
    for other in pairs(BLENDS[name] or {}) do
        local fluid = other ~= name and fluidObject(other)
        local amount = fluid and container:getSpecificFluidAmount(fluid) or 0
        if amount > 0 then
            parts[other] = amount * CauldronFluid.ML_PER_L
            found = found + amount
        end
    end
    if found < container:getAmount() - CauldronFluid.AMOUNT_TOLERANCE_L then return nil end
    return parts, name
end

-- The heat of an item's fluid, by the hooks, else vanilla's item heat.
function CauldronFluid.heatOf(item, now, character)
    for _, fn in ipairs(HOOKS.heatOf) do
        local celsius = fn(item, now, character)
        if celsius then return celsius end
    end
    return CauldronFluid.heatCelsius(item:getItemHeat())
end

function CauldronFluid.tookFrom(item, ml)
    for _, fn in ipairs(HOOKS.taken) do fn(item, ml) end
end

-- After a fill from the cauldron: the hooks first, else vanilla's item heat is set to the cauldron's.
function CauldronFluid.filledFrom(item, fill)
    local handled = false
    for _, fn in ipairs(HOOKS.filled) do handled = fn(item, fill) or handled end
    if not handled then item:setItemHeat(CauldronFluid.itemHeat(fill.tempC)) end
end

-- What the cauldron holds, coloured: each vanilla fluid's own colour, mixed by their shares. nil when it is empty.
local fluidColours = {}

local function fluidColour(name)
    if fluidColours[name] == nil then
        local fluid = Fluid and Fluid.Get and Fluid.Get(name)
        local c = fluid and fluid:getColor()
        fluidColours[name] = c and { c:getRedFloat(), c:getGreenFloat(), c:getBlueFloat() } or false
    end
    return fluidColours[name] or nil
end

function CauldronFluid.liquidColour(state)
    local total, mix = 0, { 0, 0, 0 }
    for name, ml in pairs(CauldronFluid.partsOf(state)) do
        local c = fluidColour(name) or { 1, 1, 1 }
        for i = 1, 3 do mix[i] = mix[i] + c[i] * ml end
        total = total + ml
    end
    if total <= 0 then return nil end
    return { mix[1] / total, mix[2] / total, mix[3] / total }
end

return CauldronFluid
