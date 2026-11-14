-- Traditional Preservation core: the Stone Hearth, a low stone firebox with a lined hole in its top, shared by every TP
-- mod; with the cauldron fitted (Stone Hearth (Cauldron), "the Hearth" in the code) the Forged Cauldron hangs over the hole.
-- The built tile is swapped for a vanilla fireplace, as the Barrel Oven's is (BuildRecipeCode.barrelOven.OnCreate),
-- so vanilla gives it fuel, lighting, burn time, room heat and a firebox to cook in. The cauldron holds one fluid at
-- a time, or a blend of fluids a mod has said may share it (Hearth.blend: Dairy's milks): it heats towards MAX_C (water boils, and boils clean) while the fire burns and cools to the room when it is out. Its state is a plain
-- table in the fireplace's modData under KEY; every rule here works on it without the engine.
--
-- "By a fire" is a place of its own (PLACE, at FIRE_C): any lit fire within FIRE_RADIUS tiles on the same floor,
-- the Hearth or not. Indoors it holds FIRE_C whatever the weather; under an open roof or in the open the air takes
-- the heat away, so there it is that place's air plus FIRE_LIFT, never past FIRE_C (places PLACE .. "Covered", ..
-- "Open"; a campfire in a January field is cold at the back). It is opt-in: Weather.placeOf never returns it, Hearth.placeOf does, so only a mod that asks
-- for it gets it. Mods hook into the cauldron with Hearth.hook (see HOOKS below).
--
-- What sits on the fire is an attachment (Hearth.attach, ATTACHMENTS below): the cauldron is the first, written in
-- Cauldron.lua, CauldronUI.lua and HearthWorld against that registry alone, so a mod can add its own (Salt's salt pan).
-- Two slots (user, 2026-11-13): one attachment fitted on the fire (the Cauldron, later Salt's pan) and one connection
-- built onto it (Hearth.connect: the Smokehouse's flue), each free of the other unless the connection blocks both. The fire's state names the attachment (attached:
-- false once one has come off), and the attachment's own state is kept under its id there. Fit and Remove are
-- Core's (Hearth.canFit, Hearth.fit, Hearth.unfit; TPHearthFit), by the attachment's fit.
--
-- A lit Hearth can be banked: the fire raked down under its ash. It burns BANKED_BURN of the wood a lit fire does,
-- the cauldron settles at BANKED_C, and beside it is a place of its own (EMBERS, at EMBERS_C). Vanilla's fireplace has
-- one speed and heats and lights 8 tiles whatever its fuel (ENGINE_NOTES), so a banked Hearth's vanilla fire is out:
-- the mod counts its fuel from the clock (Hearth.reckonFuel) and sets vanilla's to the count, gives it its own small
-- heat and faint light, and keeps the firebox hot (HearthWorld). Hearth.isBurning is a fire lit or banked.
--
-- A Stone Hearth with nothing fitted is "the Firebox" in the code (Hearth.isFirebox): a cooking source through the
-- hole, banked and stoked the same way. Its state is the same table (no attachment). What shows in the hole is its
-- look (Hearth.holeLook): open, a forged pot when a stove food or a fluid is inside (Hearth.cooksOn), a lid when only
-- oven food is. Any Stone Hearth, fitted or not, may have something joined to its back or either flank, never the
-- door's side (Hearth.connect, CONNECTIONS below; the Smokehouse's flue): its tile is picked by facing and hole alone.
-- A connection draws itself on its own object (the Smokehouse's entry overlay draws the flue, Smokehouse.entrySprite);
-- the stone only puts its lid on when the connection takes the smoke (spec.smoke). Hearth.isFire is any Stone Hearth, fitted or not.
local Weather = require "TraditionalPreservationCore/Weather"
local Station = require "TraditionalPreservationCore/Station"
local Tiles = require "TraditionalPreservationCore/Tiles"
local Doors = require "TraditionalPreservationCore/Doors"

local Hearth = {}

-- Save key: never rename it once the mod is out (DEVGUIDE, "Rules that keep saves and the game happy").
-- Inside: fireUntil; banked, fuel, fuelAt, fuelSet; attached (the id of what is fitted); connected (the id of what is
-- joined, its kind and side under that id);
-- the fire's record (Hearth.logFire):
-- fireId, fireAt, fireMode, fireEnds, stokedHours, bankedHours, session, sessionBase, stokedLast; and each attachment's
-- state under its id: the cauldron's (CAULDRON) ml, fluid, parts, tempC, last, boiled, hot, held, offAt, with fireUntil and
-- banked copied from the fire as it heats.
Hearth.KEY = "tpHearth"
Hearth.CAULDRON = "cauldron"

-- By a fire. A fireplace, an antique stove or a campfire, never an electric or gas stove.
Hearth.PLACE = "Hearth"
Hearth.FIRE_C = 28
Hearth.FIRE_RADIUS = 2

-- Banked
Hearth.BANKED_C = 50               -- the cauldron's heat over banked embers
Hearth.BANKED_BURN = 1 / 3         -- of the wood a lit fire burns: a banked fire lasts three times as long
Hearth.EMBERS = "Embers"           -- the place by a banked Hearth
Hearth.EMBERS_C = 24
Hearth.BANKED_HEAT_RADIUS = 2      -- tiles of room heat around banked embers (a lit fire: 8)
Hearth.BANKED_HEAT_C = 25          -- that heat (a lit fire: 35 C)
Hearth.BANKED_LIGHT_RADIUS = 1
Hearth.BANKED_LIGHT = { 0.6, 0.25, 0.1 }
Hearth.BANKED_FIREBOX = 1.8        -- the firebox's heat (vanilla's container temperature): it cooks, a third as fast

-- What a fire adds to the air under an open roof (the season's) and in the open (the day's), lit and banked.
Hearth.FIRE_LIFT = { Covered = 15, Open = 10 }
Hearth.EMBERS_LIFT = { Covered = 10, Open = 5 }

-- Save values: a station's noted place. Never rename them.
for _, fire in ipairs({ { Hearth.PLACE, Hearth.FIRE_C, Hearth.FIRE_LIFT }, { Hearth.EMBERS, Hearth.EMBERS_C, Hearth.EMBERS_LIFT } }) do
    local place, celsius, lifts = fire[1], fire[2], fire[3]
    Weather.FIRE_PLACES[place] = { celsius = celsius }
    for under, lift in pairs(lifts) do
        Weather.FIRE_PLACES[place .. under] = { celsius = celsius, under = under, lift = lift }
    end
end

-- The fire's record, for whatever hangs over it (Fish & Meat's Smokehouse). Hours of stoked (lit) and banked fire,
-- and the stoked session now running: unbroken stoking, a gap of up to SESSION_GRACE hours (more wood, a dip) kept.
Hearth.SESSION_GRACE = 1
Hearth.STOKED = "stoked"
Hearth.BANKED = "banked"

-- Adds the time since the last look to the record, as the fire was then (mode, burning until ends), and notes the
-- fire as it is now. Hours count only up to when the fire was due to go out: vanilla burns a lit fire's time away
-- in one go when its chunk loads again (ENGINE_NOTES), so its fuel afterwards can't say when it went out. A session
-- ends once the fire hasn't been stoked for more than SESSION_GRACE hours; stoking again starts a new one (session =
-- when it began, sessionBase = the stoked hours before it). fireId tells one fire's record from a rebuilt one's.
function Hearth.logFire(state, now, mode, ends)
    state.fireId = state.fireId or now
    local at = state.fireAt
    if at and now > at and state.fireMode then
        local stop = math.max(math.min(now, state.fireEnds or now), at)
        local hours = stop - at
        if state.fireMode == Hearth.STOKED then
            state.stokedHours = (state.stokedHours or 0) + hours
            state.stokedLast = stop
        else
            state.bankedHours = (state.bankedHours or 0) + hours
        end
    end
    if state.session and now - (state.stokedLast or now) > Hearth.SESSION_GRACE then
        state.session, state.sessionBase = nil, nil
    end
    if mode == Hearth.STOKED and not state.session then
        state.session, state.sessionBase, state.stokedLast = now, state.stokedHours or 0, now
    end
    state.fireAt, state.fireMode, state.fireEnds = now, mode, ends
end

-- The stoked hours of the session now running, or 0.
function Hearth.sessionHours(state)
    if not state.session then return 0 end
    return (state.stokedHours or 0) - (state.sessionBase or 0)
end

-- The heat of a place by a fire, lit or banked, by the ledger's weather; nil for any other place, and for a fire
-- under a roof or in the open without a ledger.
function Hearth.fireC(place, ledger)
    local fire = Weather.FIRE_PLACES[place]
    if not fire or (fire.under and not ledger) then return nil end
    return Weather.placeTemperature(ledger or {}, place)
end

function Hearth.isFirePlace(place)
    return Weather.FIRE_PLACES[place] ~= nil
end

-- A fire's place (PLACE or EMBERS) where it warms under (Weather.placeOf): its own outside, plain indoors.
function Hearth.firePlace(place, under)
    if Hearth.FIRE_LIFT[under] then return place .. under end
    return place
end

-- The cauldron
Hearth.CAULDRON_ML = 60000            -- a farmhouse copper's size (real ones 40 to 100 L)
Hearth.TAU_ML = 10000              -- the litres the time constants below are for; more heats and cools slower
Hearth.MAX_C = 95                  -- over a fire; nothing in it quite boils
Hearth.HOT_C = 85                  -- steaming
Hearth.LIT_TAU = 0.75              -- hours, for 10 L over a lit fire: 20 to 85 C in about an hour and a half
Hearth.OUT_TAU = 2.0               -- hours, for 10 L once the fire is out: the stone holds its heat
Hearth.FLOOR_ML = 1000             -- a splash heats as fast as a litre

-- Water is let boil: over a lit fire it heats towards WATER_FIRE_C and holds at BOIL_C. Tainted water kept at the
-- boil for BOIL_HOURS turns clean (BOILED). Every other fluid is kept off the boil, at MAX_C.
Hearth.BOIL_C = 100
Hearth.WATER_FIRE_C = 110
Hearth.BOIL_HOURS = 1 / 6
Hearth.BOILS = { Water = true, TaintedWater = true }
Hearth.BOILED = { TaintedWater = "Water" }

-- Vanilla's item heat, for fluids poured between the cauldron and the player's containers. Vanilla cools a
-- container in the player's hands to room heat within seconds.
Hearth.ROOM_C = 20
Hearth.HEAT_PER_DEGREE = 1 / 133   -- itemHeat 1.0 is room temperature; 1.6 (water turns clean) is about 100 C
Hearth.COLD_HEAT = 0.2             -- the engine's floor: an item in a powered fridge or freezer
Hearth.COLD_C = 4                  -- what that reads as; below room heat the scale is gentler than above it

-- Newton's law: tempC after hours at placeC, for a time constant tau.
function Hearth.cool(tempC, placeC, hours, tau)
    return placeC + (tempC - placeC) * math.exp(-hours / tau)
end

local COLD_PER_DEGREE = (1 - Hearth.COLD_HEAT) / (Hearth.ROOM_C - Hearth.COLD_C)

function Hearth.heatCelsius(itemHeat)
    itemHeat = itemHeat or 1
    if itemHeat < 1 then
        return Hearth.ROOM_C + (math.max(itemHeat, Hearth.COLD_HEAT) - 1) / COLD_PER_DEGREE
    end
    return math.min(Hearth.ROOM_C + (itemHeat - 1) / Hearth.HEAT_PER_DEGREE, Hearth.MAX_C)
end

-- The other way, for fluid poured back out: it starts at the heat it had.
function Hearth.itemHeat(celsius)
    if celsius < Hearth.ROOM_C then
        return math.max(1 + (celsius - Hearth.ROOM_C) * COLD_PER_DEGREE, Hearth.COLD_HEAT)
    end
    return 1 + (celsius - Hearth.ROOM_C) * Hearth.HEAT_PER_DEGREE
end

function Hearth.stateOf(modData)
    modData[Hearth.KEY] = modData[Hearth.KEY] or {}
    return modData[Hearth.KEY]
end

-- An attachment's own state, under its id in the fire's.
function Hearth.partState(modData, id)
    local state = Hearth.stateOf(modData)
    state[id] = state[id] or {}
    return state[id]
end

function Hearth.cauldronState(modData)
    return Hearth.partState(modData, Hearth.CAULDRON)
end

-- Attachments: what is fitted on a fire, one at a time. Hearth.attach(spec) registers one by spec.id, or adds the
-- fields given to one already registered, so its rules can be given in shared Lua and its menu in client Lua. Each
-- function gets the attachment's own state (part) and the fireplace; fireState is the fire's.
--   name                                  its text key
--   fit                                   what Fit takes: { items = { {full type, count} }, tool (an ItemTag's
--                                         name, kept), ticks, removeTicks, xp = { perk, amount }, lost = { full type
--                                         = true } }; Remove gives the items back, all but lost ones
--   fitHelp, fitIcon                      client: Fit's tooltip line (a text key) and Fit / Remove's icon path
--   canRemove(part, fire)                 true, or false and a reason; never asked while the fire burns
--   look(part, fire)                      the look its tile shows (the cauldron's: Empty, Full, Hot)
--   sprite(look, face, burning, banked)   its tile by look, facing and fire, the fire's glow drawn in it (the
--                                         cauldron's Hearth.sprite if left out)
--   overlay(part, face, burning, banked)  its overlay sprite and, to tint it, { r, g, b } (0-1), or nil (the
--                                         cauldron's Hearth.liquidOverlay if left out: what it holds, coloured)
--   heats(part, fire, now, fireState, airC)  brings what it holds up to now, by the fire and the place's air
--   onFire(part, fire, now, fireState)    after each refresh, the look and glow set
--   status(part)                          client: the menu's first row, text and icon
--   menu(menu, playerObj, fire, part)     client: its rows, after Bank / Stoke
--   rows(window, y, info) -> y            client: its rows in the Info window; info.cauldron is the part
--   notes(info, notes)                    client: its Info notes, before HearthUI.addNotes'
local ATTACHMENTS, ORDER = {}, {}

function Hearth.attach(spec)
    if not ATTACHMENTS[spec.id] then table.insert(ORDER, spec.id) end
    local known = ATTACHMENTS[spec.id] or {}
    for key, value in pairs(spec) do known[key] = value end
    ATTACHMENTS[spec.id] = known
    return known
end

function Hearth.attachment(id)
    return ATTACHMENTS[id]
end

-- Every attachment, in the order registered.
function Hearth.attachments()
    local list = {}
    for _, id in ipairs(ORDER) do table.insert(list, ATTACHMENTS[id]) end
    return list
end

-- Cauldron rules

function Hearth.cauldronTau(ml, lit)
    local base = lit and Hearth.LIT_TAU or Hearth.OUT_TAU
    return base * (math.max(ml, Hearth.FLOOR_ML) / Hearth.TAU_ML) ^ (1 / 3)
end

-- Whether the cauldron's fluid is let boil: water on its own.
function Hearth.boils(cauldron)
    return Hearth.BOILS[cauldron.fluid] == true and not cauldron.parts
end

-- The heat the cauldron heats towards while the fire burns.
function Hearth.fireTarget(cauldron)
    if cauldron.banked then return Hearth.BANKED_C end
    return Hearth.boils(cauldron) and Hearth.WATER_FIRE_C or Hearth.MAX_C
end

-- Fluids that may share the cauldron, as a cow's and a sheep's milk do: a mod names each group. Anything else is
-- one fluid at a time.
local BLENDS = {}

function Hearth.blend(...)
    local group = {}
    for _, name in ipairs({ ... }) do
        group[name] = true
        BLENDS[name] = group
    end
end

function Hearth.blends(a, b)
    return a == b or (BLENDS[a] ~= nil and BLENDS[a][b] == true)
end

-- parts ({ name = ml }) in the same shares, adding up to ml.
function Hearth.share(parts, ml)
    local total, shares = 0, {}
    for _, part in pairs(parts) do total = total + part end
    if total <= 0 then return shares end
    for name, part in pairs(parts) do shares[name] = part * ml / total end
    return shares
end

-- What ml of a store (the cauldron, or a mod's own: anything with ml, fluid and parts) is, by fluid: { name = ml }.
-- parts is kept only for a blend, and only its shares count; fluid is then the largest of them.
function Hearth.partsOf(state, ml)
    ml = ml or state.ml or 0
    if state.parts then return Hearth.share(state.parts, ml) end
    return state.fluid and ml > 0 and { [state.fluid] = ml } or {}
end

-- Notes ml of a fluid (a name, or parts for a blend) going into a store. Call it before the store's ml grows.
function Hearth.addParts(state, fluid, ml)
    local parts = Hearth.partsOf(state)
    local added = type(fluid) == "table" and Hearth.share(fluid, ml) or { [fluid] = ml }
    for name, part in pairs(added) do parts[name] = (parts[name] or 0) + part end
    local count, most = 0, nil
    for name, part in pairs(parts) do
        count = count + 1
        if not most or part > parts[most] or (part == parts[most] and name < most) then most = name end
    end
    state.fluid = most
    state.parts = count > 1 and parts or nil
end

-- What a fluid container holds, { name = ml }, and its main fluid: one fluid, or a blend of fluids that may share
-- the cauldron. nil for none, or for any other mixture.
function Hearth.partsIn(container)
    if not container or container:isEmpty() then return nil end
    local primary = container:getPrimaryFluid()
    local name = primary and primary:getFluidTypeString()
    if not name then return nil end
    local found = container:getPrimaryFluidAmount()
    local parts = { [name] = found * 1000 }
    for other in pairs(BLENDS[name] or {}) do
        local fluid = other ~= name and Fluid.Get(other)
        local amount = fluid and container:getSpecificFluidAmount(fluid) or 0
        if amount > 0 then
            parts[other] = amount * 1000
            found = found + amount
        end
    end
    if found < container:getAmount() - 0.001 then return nil end
    return parts, name
end

-- Fluids the cauldron changes, as a mod names them (Fish & Meat's fat).
-- Hearth.turnsHot(from, to, hours): from, on its own and kept steaming (HOT_C or more) for hours in all, becomes to:
-- raw fat renders. The hours are kept in the cauldron's hot, and start over when more is put in.
-- Hearth.goesOff(from, to): from becomes to at the cauldron's offAt (Hearth.offBy sets it), unless it turned first.
-- Hearth.staysIn(name): the cauldron holds it, but no container can be filled with it.
local TURNS, OFF, STAYS = {}, {}, {}

function Hearth.turnsHot(from, to, hours)
    TURNS[from] = { to = to, hours = hours }
end

function Hearth.goesOff(from, to)
    OFF[from] = to
end

function Hearth.staysIn(name)
    STAYS[name] = true
end

-- Whether containers can be filled with what the cauldron holds.
function Hearth.poursOut(cauldron)
    return not STAYS[cauldron.fluid]
end

-- The cauldron's fluid goes off at the hour at, or sooner if it was already going to.
function Hearth.offBy(cauldron, at)
    cauldron.offAt = math.min(cauldron.offAt or at, at)
end

-- Hours of steaming still to go before the cauldron's fluid turns; nil if it never will.
function Hearth.hoursToTurn(cauldron)
    local turn = (cauldron.ml or 0) > 0 and not cauldron.parts and TURNS[cauldron.fluid]
    if not turn then return nil end
    return math.max(turn.hours - (cauldron.hot or 0), 0)
end

-- How much of ml of a fluid (a name, or parts) fits, or 0 with the reason: one fluid at a time, unless they blend.
function Hearth.cauldronRoom(cauldron, fluid, ml)
    if (cauldron.ml or 0) > 0 then
        for name in pairs(type(fluid) == "table" and fluid or { [fluid] = true }) do
            if not Hearth.blends(cauldron.fluid, name) then return 0, "Mixed" end
        end
    end
    local room = Hearth.CAULDRON_ML - (cauldron.ml or 0)
    if room <= 0 then return 0, "Full" end
    return math.min(ml, room)
end

-- Pours a fluid (a name, or parts) in; the temperatures mix by volume. Returns the ml taken (0 with a reason when
-- refused).
function Hearth.pourInto(cauldron, fluid, ml, fluidC, now)
    local taken, reason = Hearth.cauldronRoom(cauldron, fluid, ml)
    if taken <= 0 then return 0, reason end
    local had = cauldron.ml or 0
    cauldron.tempC = had > 0 and (cauldron.tempC * had + fluidC * taken) / (had + taken) or fluidC
    cauldron.boiled = nil
    cauldron.hot = nil
    cauldron.held = nil
    Hearth.addParts(cauldron, fluid, taken)
    cauldron.ml = had + taken
    cauldron.last = cauldron.last or now
    return taken
end

-- Takes up to maxMl out, all of it if left out. Returns the ml, the main fluid, its temperature, and the ml by
-- fluid ({ name = ml }: more than one name when the cauldron holds a blend).
function Hearth.take(cauldron, maxMl)
    local ml = math.min(cauldron.ml or 0, maxMl or cauldron.ml or 0)
    if ml <= 0 then return 0 end
    local fluid, tempC, parts = cauldron.fluid, cauldron.tempC, Hearth.partsOf(cauldron, ml)
    cauldron.ml = cauldron.ml - ml
    if cauldron.ml <= 0 then
        for _, key in ipairs({ "ml", "fluid", "parts", "tempC", "last", "boiled", "hot", "held", "offAt" }) do cauldron[key] = nil end
    end
    return ml, fluid, tempC, parts
end

-- The hours out of hours that a cauldron at tempC, moving towards target, spends at HOT_C or more.
local function hoursHot(tempC, target, hours, tau)
    local hot = Hearth.HOT_C
    if tempC >= hot and target >= hot then return hours end
    if tempC < hot and target <= hot then return 0 end
    local cross = tau * math.log((target - tempC) / (target - hot))
    if tempC < hot then return math.max(hours - cross, 0) end
    return math.min(hours, cross)
end

-- Counts the steaming hours of a fluid that turns hot (Hearth.turnsHot), before tempC moves towards target, and
-- turns it when it has had them all. What has turned no longer goes off.
local function keepHot(cauldron, target, hours, tau)
    local turn = not cauldron.parts and TURNS[cauldron.fluid]
    if not turn then return end
    cauldron.hot = (cauldron.hot or 0) + hoursHot(cauldron.tempC, target, hours, tau)
    if cauldron.hot >= turn.hours then
        cauldron.fluid, cauldron.hot, cauldron.offAt = turn.to, nil, nil
    end
end

-- Counts the hours at HOT_C or more of whatever the cauldron holds, in all since it was last poured into
-- (Hearth.heldHours): a mod can ask for a hold at the heat, as Dairy's scald does.
local function countHeld(cauldron, target, hours, tau)
    cauldron.held = (cauldron.held or 0) + hoursHot(cauldron.tempC, target, hours, tau)
end

-- A fluid past its offAt becomes what it goes off to (Hearth.goesOff).
local function goOff(cauldron, now)
    if not cauldron.offAt or cauldron.offAt > now then return end
    if OFF[cauldron.fluid] and not cauldron.parts then cauldron.fluid = OFF[cauldron.fluid] end
    cauldron.hot, cauldron.offAt = nil, nil
end

-- Hours of a lit fire under the cauldron: water stops at BOIL_C, and the time it spends there counts towards boiling
-- tainted water clean.
local function heat(cauldron, hours)
    local target, tau = Hearth.fireTarget(cauldron), Hearth.cauldronTau(cauldron.ml, not cauldron.banked)
    keepHot(cauldron, target, hours, tau)
    countHeld(cauldron, target, hours, tau)
    if target <= Hearth.BOIL_C then
        cauldron.tempC = Hearth.cool(cauldron.tempC, target, hours, tau)
        return
    end
    local toBoil = cauldron.tempC >= Hearth.BOIL_C and 0
        or tau * math.log((target - cauldron.tempC) / (target - Hearth.BOIL_C))
    if hours <= toBoil then
        cauldron.tempC = Hearth.cool(cauldron.tempC, target, hours, tau)
        return
    end
    cauldron.tempC = Hearth.BOIL_C
    cauldron.boiled = (cauldron.boiled or 0) + hours - toBoil
    if cauldron.boiled >= Hearth.BOIL_HOURS and Hearth.BOILED[cauldron.fluid] then
        cauldron.fluid = Hearth.BOILED[cauldron.fluid]
    end
end

-- Brings the cauldron up to now: heating while the fire burns (to fireUntil), cooling to roomC after. Over banked
-- embers it settles at BANKED_C, as slowly as it cools: the fire is low and the stone holds the heat.
function Hearth.advance(cauldron, now, roomC)
    if (cauldron.ml or 0) <= 0 then return end
    local t = cauldron.last or now
    goOff(cauldron, t)
    if cauldron.fireUntil and cauldron.fireUntil > t then
        local stop = math.min(cauldron.fireUntil, now)
        heat(cauldron, stop - t)
        t = stop
    end
    if now > t then
        local tau = Hearth.cauldronTau(cauldron.ml, false)
        keepHot(cauldron, roomC, now - t, tau)
        countHeld(cauldron, roomC, now - t, tau)
        cauldron.tempC = Hearth.cool(cauldron.tempC, roomC, now - t, tau)
        cauldron.boiled = nil
    end
    goOff(cauldron, now)
    cauldron.last = now
end

-- What the cauldron shows: Empty, Full or Hot (steaming, whatever the fluid).
function Hearth.look(cauldron)
    if (cauldron.ml or 0) <= 0 then return "Empty" end
    return cauldron.tempC >= Hearth.HOT_C and "Hot" or "Full"
end

function Hearth.isHot(cauldron)
    return (cauldron.ml or 0) > 0 and (cauldron.tempC or 0) >= Hearth.HOT_C
end

-- Hours what the cauldron holds has spent at HOT_C or more, in all, since it was last poured into.
function Hearth.heldHours(cauldron)
    return (cauldron.ml or 0) > 0 and cauldron.held or 0
end

-- Hours until the cauldron is hot if the fire burns on; 0 if it is already, nil if it is empty or banked.
function Hearth.hoursToHot(cauldron)
    if (cauldron.ml or 0) <= 0 then return nil end
    if cauldron.tempC >= Hearth.HOT_C then return 0 end
    if cauldron.banked then return nil end
    local target = Hearth.fireTarget(cauldron)
    return Hearth.cauldronTau(cauldron.ml, true) * math.log((target - cauldron.tempC) / (target - Hearth.HOT_C))
end

-- Banks the fire (banked true) or stokes it up again, with fuel minutes in vanilla's fireplace now.
function Hearth.setBanked(state, banked, fuel, now)
    state.banked = banked or nil
    if banked then
        state.fuel, state.fuelAt, state.fuelSet = fuel, now, fuel
    else
        state.fuel, state.fuelAt, state.fuelSet = nil, nil, nil
    end
end

-- The fuel a banked fire has left now, from vanilla's fuel (minutes) and whether vanilla's fire is lit (it is out
-- while banked). Returns the fuel to give vanilla's fireplace, nil to leave it alone. The count runs on the clock,
-- away time included; wood added since the last reckoning counts in full. Burnt down, the fire is out and no longer
-- banked. Lit by anything but stoking, it is a lit fire again.
function Hearth.reckonFuel(state, fuel, lit, now)
    if not state.banked then return nil end
    if lit then
        Hearth.setBanked(state, false)
        return nil
    end
    if not state.fuel then
        Hearth.setBanked(state, true, fuel, now)
        return nil
    end
    local left = state.fuel - (now - state.fuelAt) * 60 * Hearth.BANKED_BURN + math.max(fuel - state.fuelSet, 0)
    if left < 1 then
        Hearth.setBanked(state, false)
        return 0
    end
    state.fuel, state.fuelAt, state.fuelSet = left, now, math.ceil(left)
    return state.fuelSet
end

-- A banked firebox cooks as slowly as it burns: vanilla adds cooking time at full speed, so of the minutes cooked
-- since before, only BANKED_BURN count. Returns the cooking time the food should have.
function Hearth.bankedCooking(before, now)
    if now <= before then return now end
    return before + (now - before) * Hearth.BANKED_BURN
end

-- Hooks: other mods' say on fluid going in and out of the cauldron. Each is a list of functions, called in order.
--   heatOf(item, now, character)  the heat in C of the fluid in item, or nil to let the next one (or vanilla's
--                                 item heat) say. A container that keeps its own heat answers here.
--   taken(item, ml)               ml left item for the cauldron.
--   filled(item, fill)            fill = { ml, fluid, parts, tempC, hot, hadMl, hadC, now, character }: ml went into
--                                 item from the cauldron. Return true if it set the item's heat itself.
local HOOKS = { heatOf = {}, taken = {}, filled = {} }

function Hearth.hook(name, fn)
    table.insert(HOOKS[name], fn)
end

-- The heat of an item's fluid, by the hooks, else vanilla's item heat.
function Hearth.heatOf(item, now, character)
    for _, fn in ipairs(HOOKS.heatOf) do
        local celsius = fn(item, now, character)
        if celsius then return celsius end
    end
    return Hearth.heatCelsius(item:getItemHeat())
end

function Hearth.tookFrom(item, ml)
    for _, fn in ipairs(HOOKS.taken) do fn(item, ml) end
end

-- After a fill from the cauldron: the hooks first, else vanilla's item heat is set to the cauldron's.
function Hearth.filledFrom(item, fill)
    local handled = false
    for _, fn in ipairs(HOOKS.filled) do handled = fn(item, fill) or handled end
    if not handled then item:setItemHeat(Hearth.itemHeat(fill.tempC)) end
end

-- Tiles: one per fire (out, lit, banked), still or steaming, and facing, all of them fireplaces. The fire's glow is
-- drawn in them, so the overlay is free for the liquid: the one thing the game tints per object (ENGINE_NOTES).
Hearth.LOOKS = Tiles.HEARTH_LOOKS or {}
Hearth.SPRITES = Tiles.HEARTHS or {}
Hearth.FACE_COUNT = Tiles.FACE_COUNT or 2

-- The hearth's own sprite is swapped among its looks, so each look is a "kind" of tile here.
local _, HEARTH_TILES = Station.kinds(Tiles.PREFIX, Hearth.FACE_COUNT, Hearth.LOOKS)

-- The facing (0 S, 1 E) of a cauldron tile, whatever the cauldron shows; nil for any other tile.
function Hearth.face(spriteName)
    return spriteName and HEARTH_TILES.face[spriteName]
end

-- The tile for the cauldron's look (Empty, Full, Hot: Hot steams) and the fire, lit or banked; out if neither is given.
function Hearth.sprite(look, face, burning, banked)
    local tile = (burning and (banked and "Banked" or "Lit") or "") .. (look == "Hot" and "Steam" or "")
    return Tiles.PREFIX .. (Hearth.LOOKS[tile ~= "" and tile or "Cold"] + face)
end

-- What the cauldron holds, as the overlay: a pale surface in the kettle's mouth, tinted the colour of its fluids (each
-- vanilla fluid's own, mixed by their shares). Nil when it is empty.
Hearth.LIQUID = Tiles.LIQUID
local fluidColours = {}

function Hearth.fluidColour(name)
    if fluidColours[name] == nil then
        local fluid = Fluid and Fluid.Get and Fluid.Get(name)
        local c = fluid and fluid:getColor()
        fluidColours[name] = c and { c:getRedFloat(), c:getGreenFloat(), c:getBlueFloat() } or false
    end
    return fluidColours[name] or nil
end

function Hearth.liquidColour(state)
    local total, mix = 0, { 0, 0, 0 }
    for name, ml in pairs(Hearth.partsOf(state)) do
        local c = Hearth.fluidColour(name) or { 1, 1, 1 }
        for i = 1, 3 do mix[i] = mix[i] + c[i] * ml end
        total = total + ml
    end
    if total <= 0 then return nil end
    return { mix[1] / total, mix[2] / total, mix[3] / total }
end

function Hearth.liquidOverlay(cauldron, face)
    if not Hearth.LIQUID or (cauldron.ml or 0) <= 0 then return nil end
    return Tiles.PREFIX .. (Hearth.LIQUID + face), Hearth.liquidColour(cauldron)
end

-- The Stone Hearth with nothing fitted: one tile per hole look and facing (FIREBOX_LOOKS: Open, Lid, Pot), its glow by
-- fire, smoke and hole. Connections draw their own sprites, so the stone has no flue tiles (dropped 2026-11-14).
Hearth.FIREBOX_LOOKS = Tiles.FIREBOX_LOOKS or {}
Hearth.FIREBOX_SPRITES = Tiles.FIREBOXES or {}
Hearth.FIREBOX_GLOWS = Tiles.FIREBOX_GLOWS or {}
Hearth.OPEN, Hearth.LID, Hearth.POT = "Open", "Lid", "Pot"
-- The sides a connection may go to, by facing (0 S, 1 E), as world steps (+x east, +y south): the same table as FLUE_SIDES
-- in tools/build_tileset.py. The door's side is never one.
Hearth.FLUE_SIDES = {
    [0] = { Back = { 0, -1 }, Left = { -1, 0 }, Right = { 1, 0 } },
    [1] = { Back = { -1, 0 }, Left = { 0, -1 }, Right = { 0, 1 } },
}

local _, FIREBOX_TILES = Station.kinds(Tiles.PREFIX, Hearth.FACE_COUNT, Hearth.FIREBOX_LOOKS)

function Hearth.fireboxFace(spriteName)
    return spriteName and FIREBOX_TILES.face[spriteName]
end

-- The facing of any Stone Hearth tile, fitted or not.
function Hearth.fireFace(spriteName)
    return Hearth.fireboxFace(spriteName) or Hearth.face(spriteName)
end

-- With a connection that takes the smoke (smoke true) the hole is never open: the smoke must go up the flue.
function Hearth.fireboxSprite(smoke, hole, face)
    local look = hole or Hearth.OPEN
    if smoke and look == Hearth.OPEN then look = Hearth.LID end
    return Tiles.PREFIX .. ((Hearth.FIREBOX_LOOKS[look] or Hearth.FIREBOX_LOOKS[Hearth.OPEN]) + face)
end

function Hearth.fireboxGlow(lit, banked, smoke, hole, face)
    if not lit then return nil end
    local kind = smoke and "Flue" or (hole == Hearth.OPEN or hole == Hearth.POT) and hole or ""
    local base = Hearth.FIREBOX_GLOWS[(banked and "Banked" or "Lit") .. kind]
    return base and Tiles.PREFIX .. (base + face) or nil
end

-- Every Stone Hearth tile, fitted or not.
Hearth.FIRE_SPRITES = {}
local FIRE_TILES = {}
for _, list in ipairs({ Hearth.SPRITES, Hearth.FIREBOX_SPRITES }) do
    for _, name in ipairs(list) do
        table.insert(Hearth.FIRE_SPRITES, name)
        FIRE_TILES[name] = true
    end
end

-- Any Stone Hearth: a fire this mod banks, stokes and counts the fuel of.
function Hearth.isFire(object)
    local sprite = object and object:getSprite()
    return sprite ~= nil and FIRE_TILES[sprite:getName()] == true and instanceof(object, "IsoFireplace")
end

-- The id of what is fitted on a fire, or nil. A cauldron tile with nothing noted (a Hearth picked up and put down: its
-- modData doesn't go with it) is the cauldron fitted; attached false is nothing, whatever the tile shows until redrawn.
function Hearth.attachedTo(fire)
    local state = fire:getModData()[Hearth.KEY]
    local id = state and state.attached
    if id ~= nil then return id or nil end
    if Hearth.face(fire:getSprite():getName()) then return Hearth.CAULDRON end
end

-- A Stone Hearth with the cauldron fitted ("the Hearth").
function Hearth.isHearth(object)
    return Hearth.isFire(object) and Hearth.attachedTo(object) == Hearth.CAULDRON
end

-- A Stone Hearth with nothing fitted ("the Firebox").
function Hearth.isFirebox(object)
    return Hearth.isFire(object) and Hearth.attachedTo(object) == nil
end

-- What is fitted on a fire: its spec and state, or nil.
function Hearth.attachmentOf(fire)
    local id = Hearth.isFire(fire) and Hearth.attachedTo(fire)
    local spec = id and ATTACHMENTS[id]
    if not spec then return nil end
    return spec, Hearth.partState(fire:getModData(), id)
end

-- Whether what is fitted may come off (or the fire be picked up): never while the fire burns; else the
-- attachment's say. A fire with nothing fitted may.
function Hearth.canRemove(fire)
    if Hearth.isBurning(fire) then return false, "Burning" end
    local spec, part = Hearth.attachmentOf(fire)
    if not (spec and spec.canRemove) then return true end
    return spec.canRemove(part, fire)
end

-- Why spec can't be fitted on this fire now, as a reason (Burning, Fitted, NoFit, Blocked), or nil. A connection
-- blocks the attachment slot only when it says so (blocks "both"; the Smokehouse's flue doesn't: the Cauldron fits on
-- a Hearth joined to it).
function Hearth.fitRefusal(fire, spec)
    if not (spec and spec.fit) then return "NoFit" end
    if Hearth.attachedTo(fire) then return "Fitted" end
    if Hearth.isBurning(fire) then return "Burning" end
    local joined = Hearth.connectionOf(fire)
    if joined and joined.blocks == "both" then return "Blocked" end
    return nil
end

-- Fits the attachment id on a fire: its state starts empty.
function Hearth.fit(fire, id)
    local state = Hearth.stateOf(fire:getModData())
    state[id] = {}
    state.attached = id
end

-- Takes what is fitted off a fire, its state with it. Returns its id.
function Hearth.unfit(fire)
    local id = Hearth.attachedTo(fire)
    local state = Hearth.stateOf(fire:getModData())
    if id then state[id] = nil end
    state.attached = false
    return id
end

-- What Remove gives back of an attachment's fit: { {full type, count} }, lost items left out.
function Hearth.fitBack(spec)
    local back, lost = {}, spec.fit.lost or {}
    for _, need in ipairs(spec.fit.items) do
        if not lost[need[1]] then table.insert(back, need) end
    end
    return back
end

-- The Hearth's open mouth and the Firebox's door need their front tile free (Doors), every look of each.
local FACE_NAMES = { [0] = "S", [1] = "E" }
local doorFacings = {}
for _, name in ipairs(Hearth.FIRE_SPRITES) do doorFacings[name] = FACE_NAMES[Hearth.fireFace(name)] end
Doors.register(doorFacings)

-- Stove or oven: where a food is cooked, which picks what shows in the hole. A stove food (a pot on the hob: stews,
-- soups) or a fluid sets the forged pot in it; anything else is oven food (clay pots, roasting pans), under the lid.
-- Every food is oven food unless a mod says otherwise: Hearth.cooksOn("stove", "Base.PotOfStew", ...).
Hearth.STOVE, Hearth.OVEN = "stove", "oven"
local COOKS_ON = {}

function Hearth.cooksOn(where, ...)
    for _, fullType in ipairs({ ... }) do COOKS_ON[fullType] = where end
end

function Hearth.cookedOn(item)
    return COOKS_ON[item:getFullType()] or Hearth.OVEN
end

-- Vanilla's stews, soups, stir-fries, omelettes, pasta and rice go on the hob.
Hearth.cooksOn(Hearth.STOVE, "Base.PotOfStew", "Base.PotForgedStew", "Base.BucketOfStew", "Base.PotOfSoup",
    "Base.PotOfSoupRecipe", "Base.PotForgedSoupRecipe", "Base.BucketOfSoup", "Base.PanFriedVegetables",
    "Base.PanFriedVegetables2", "Base.PanFriedVegetablesForged", "Base.GriddlePanFriedVegetables", "Base.OmeletteRecipe",
    "Base.OmeletteRecipeForged", "Base.EggOmelette", "Base.PastaPot", "Base.PastaPotForged", "Base.RicePot",
    "Base.RicePotForged", "Base.WaterPotPasta", "Base.WaterPotForgedPasta", "Base.WaterPotRice",
    "Base.WaterPotForgedRice", "Base.PastaPan", "Base.PastaPanCopper", "Base.RicePan", "Base.RicePanCopper",
    "Base.WaterSaucepanPasta", "Base.WaterSaucepanPastaCopper", "Base.WaterSaucepanRice", "Base.WaterSaucepanRiceCopper")

-- What shows in the hole, by what is in the fire's container (a Java list of items): the pot for any stove food or
-- container with fluid in it, the lid for anything else, open when it is empty.
function Hearth.holeLook(items)
    local look = Hearth.OPEN
    for i = 0, items and items:size() - 1 or -1 do
        local item = items:get(i)
        local fluid = item:getFluidContainer()
        if (fluid and not fluid:isEmpty()) or Hearth.cookedOn(item) == Hearth.STOVE then return Hearth.POT end
        look = Hearth.LID
    end
    return look
end

-- Connections: what is built onto a fire in the second slot (Hearth.connect; the Smokehouse's flue is the first), one
-- at a time. The fire's state names it (connected), and its own state is kept under its id there: kind (the kit it
-- was built with) and side (Back, Left or Right, never the door's). Connect and Disconnect are Core's
-- (Hearth.connectRefusal, Hearth.join, Hearth.unjoin; TPHearthConnect), by the connection's kits, never while the fire
-- burns. A spec (fields after id are optional unless said):
--   id                                    its save key under tpHearth: never rename it once out
--   kinds, kits                           the ways to build it, in menu order (both needed), each kit { tool (an
--                                         ItemTag's name, kept), items = { {full type, count} }, back (the full type
--                                         Disconnect gives back, as many as went in; the rest is lost), ticks,
--                                         removeTicks, xp = { perk, amount }, anim (a CharacterActionAnims name),
--                                         text, help, name (text keys: its menu row, hover and Info word),
--                                         toolText (the tool's text key) }
--   blocks                                "connection" (the default: its own slot) or "both" (no Fit while joined,
--                                         no Connect while something is fitted)
--   finds(fire) -> target                 the object beside the fire it could join, or nil
--   joined(fire, part) -> target          what a joined fire goes into, or nil (it is gone)
--   refusal(fire, target)                 why not this target, as a text key, or nil
--   onChange(fire, target)                after it is built or taken up, the fire redrawn (target may be nil)
--   connectText, disconnectText, disconnectHelp, icon   client: its menu rows, Disconnect's hover (%1 what comes
--                                         back, %2 the tool), their icon path
--   notes(info, notes, part)              client: its Info notes
--   smoke                                 true when it takes the fire's smoke: the hole is lidded, the glow goes up
--                                         it (the Smokehouse's flue)
-- A connection owns its sprites: it draws itself on its own object (onChange redraws it), never on the stone.
local CONNECTIONS, CONNECTION_ORDER = {}, {}

function Hearth.connect(spec)
    if not CONNECTIONS[spec.id] then table.insert(CONNECTION_ORDER, spec.id) end
    local known = CONNECTIONS[spec.id] or {}
    for key, value in pairs(spec) do known[key] = value end
    CONNECTIONS[spec.id] = known
    return known
end

function Hearth.connection(id)
    return CONNECTIONS[id]
end

-- Every connection, in the order registered.
function Hearth.connections()
    local list = {}
    for _, id in ipairs(CONNECTION_ORDER) do table.insert(list, CONNECTIONS[id]) end
    return list
end

-- The id of what is joined to a fire's state, or nil.
function Hearth.connectedTo(state)
    return state and state.connected or nil
end

-- The kind and side of what is joined (Pipe, Back), or nil.
function Hearth.joinOf(state)
    local id = Hearth.connectedTo(state)
    local part = id and state[id]
    if not part then return nil end
    return part.kind, part.side
end

-- What is joined to a fire: its spec and state, or nil.
function Hearth.connectionOf(fire)
    local state = fire:getModData()[Hearth.KEY]
    local id = Hearth.connectedTo(state)
    local spec = id and CONNECTIONS[id]
    if not spec then return nil end
    return spec, Hearth.partState(fire:getModData(), id)
end

-- Joins connection id to a fire's state by a kit's kind on a side (Back, Left or Right). Anything else (an unknown
-- id or kind, the door's side) leaves nothing joined.
function Hearth.join(state, id, kind, side)
    Hearth.unjoin(state)
    local spec = CONNECTIONS[id]
    if spec and spec.kits[kind] and Hearth.FLUE_SIDES[0][side] then
        state.connected = id
        state[id] = { kind = kind, side = side }
    end
end

-- Takes what is joined off a fire's state. Returns its id and state.
function Hearth.unjoin(state)
    local id = Hearth.connectedTo(state)
    local part = id and state[id]
    if id then state[id] = nil end
    state.connected = nil
    return id, part
end

-- Why Connect can't be done, the first that applies, as a text key, or nil. c = { joined (something is), own (the
-- connection's refusal), side (the target's side of the fire: nil on the door's), burning, fitted (something is fitted
-- and the connection blocks both slots) }.
function Hearth.connectRefusalOf(c)
    if c.joined then return "IGUI_TraditionalPreservationCore_FlueFireboxJoined" end
    if c.own then return c.own end
    if not c.side then return "IGUI_TraditionalPreservationCore_FlueFireboxDoor" end
    if c.burning then return "IGUI_TraditionalPreservationCore_FlueBurning" end
    if c.fitted then return "IGUI_TraditionalPreservationCore_ConnectFitted" end
    return nil
end

function Hearth.connectRefusal(fire, spec, target)
    return Hearth.connectRefusalOf({
        joined = Hearth.connectedTo(fire:getModData()[Hearth.KEY]) ~= nil,
        own = spec.refusal and spec.refusal(fire, target),
        side = Hearth.flueSideTo(fire, target:getSquare()),
        burning = Hearth.isBurning(fire),
        fitted = spec.blocks == "both" and Hearth.attachedTo(fire) ~= nil,
    })
end

-- What a kit lacks from counts (full type -> how many) and whether its tool is there: { {type, missing} }, noTool.
function Hearth.kitMissing(kit, counts, hasTool)
    local missing = {}
    for _, need in ipairs(kit.items) do
        local short = need[2] - (counts[need[1]] or 0)
        if short > 0 then table.insert(missing, { need[1], short }) end
    end
    return missing, not hasTool
end

-- What Disconnect gives back of a kit: { {full type, count} }.
function Hearth.kitBack(kit)
    local back = {}
    for _, need in ipairs(kit.items) do
        if need[1] == kit.back then table.insert(back, need) end
    end
    return back
end

-- The side of a Firebox that square is on (Back, Left or Right): nil for its door's side, a square not beside it,
-- or anything but a Firebox.
function Hearth.flueSideTo(firebox, square)
    local face = Hearth.fireFace(firebox:getSprite():getName())
    local here = firebox:getSquare()
    if not face or not here or not square or square:getZ() ~= here:getZ() then return nil end
    local dx, dy = square:getX() - here:getX(), square:getY() - here:getY()
    for side, step in pairs(Hearth.FLUE_SIDES[face]) do
        if step[1] == dx and step[2] == dy then return side end
    end
end

-- The square on that side of a Firebox, or nil.
function Hearth.flueSquare(firebox, side)
    local face = Hearth.fireFace(firebox:getSprite():getName())
    local step = face and Hearth.FLUE_SIDES[face][side]
    local here = firebox:getSquare()
    if not step or not here then return nil end
    return getCell():getGridSquare(here:getX() + step[1], here:getY() + step[2], here:getZ())
end

-- The sprite and glow a Stone Hearth shows now: its attachment's look, or its hole (lidded under a smoke connection) (Hearth.holeLook), and
-- its fire. nil for anything else.
function Hearth.showing(fire, state, burning, banked)
    local face = Hearth.fireFace(fire:getSprite():getName())
    if not face then return nil end
    local spec, part = Hearth.attachmentOf(fire)
    if spec then
        local look = spec.look and spec.look(part, fire) or "Empty"
        local overlay, colour = (spec.overlay or Hearth.liquidOverlay)(part, face, burning, banked)
        return (spec.sprite or Hearth.sprite)(look, face, burning, banked), overlay, colour
    end
    local container = fire:getContainer()
    local hole = Hearth.holeLook(container and container:getItems())
    local id = Hearth.connectedTo(state)
    local smoke = id and CONNECTIONS[id] and CONNECTIONS[id].smoke and Hearth.joinOf(state) ~= nil or false
    return Hearth.fireboxSprite(smoke, hole, face),
        Hearth.fireboxGlow(burning, banked, smoke, smoke and Hearth.LID or hole, face)
end

-- The fire's state, brought up to now where the World runs (a server or single player).
function Hearth.fireStateOf(fire)
    if Hearth.World then return Hearth.World.update(fire, getGameTime():getWorldAgeHours()) end
    return Hearth.stateOf(fire:getModData())
end

-- The cauldron's state, brought up to now the same way.
function Hearth.cauldronOf(fire)
    Hearth.fireStateOf(fire)
    return Hearth.cauldronState(fire:getModData())
end

-- Fires

-- Fireplaces, antique ovens, braziers, cooking pits and burn barrels are IsoFireplace; a player's campfire is a
-- plain object named "Campfire" whose lit state the camping system copies into its modData (ENGINE_NOTES).
local function isLitFire(object)
    if instanceof(object, "IsoFireplace") then return Hearth.isBurning(object) end
    return object:getName() == "Campfire" and object:getModData().isLit == true
end

-- Every object within FIRE_RADIUS tiles on the same floor that passes test, nearest first.
function Hearth.near(square, test)
    return Station.near(square, Hearth.FIRE_RADIUS, test)
end

-- A Hearth or Firebox whose fire is banked (vanilla's fire is out meanwhile).
function Hearth.isBanked(object)
    return Hearth.isFire(object) and Hearth.stateOf(object:getModData()).banked == true
end

-- A fireplace whose fire burns, lit or banked.
function Hearth.isBurning(object)
    return object:isLit() or Hearth.isBanked(object)
end

-- The warmest lit fire within FIRE_RADIUS tiles on the same floor, the nearest of those, with its place (PLACE, or
-- EMBERS for a banked Hearth); nil if there is none.
local function warmestFire(square)
    local fires = Hearth.near(square, isLitFire)
    for _, fire in ipairs(fires) do
        if not Hearth.isBanked(fire) then return fire, Hearth.PLACE end
    end
    if fires[1] then return fires[1], Hearth.EMBERS end
end

function Hearth.fireNear(square)
    return (warmestFire(square))
end

-- Hearths within FIRE_RADIUS tiles, nearest first.
function Hearth.hearthsNear(square)
    return Hearth.near(square, Hearth.isHearth)
end

-- Hours of fuel the fire has left; nil if it can't be read (it is then taken to burn on).
function Hearth.fuelHours(fire)
    if Hearth.isBanked(fire) then return fire:getFuelAmount() / 60 / Hearth.BANKED_BURN end
    if instanceof(fire, "IsoFireplace") then return fire:getFuelAmount() / 60 end
    local minutes = fire:getModData().fuelAmt
    return minutes and minutes / 60 or nil
end

-- The opt-in place: by a fire (or by banked embers), else below ground, under a roof or in the open. The fire, if any, comes second.
function Hearth.placeOf(object)
    local square = object and object:getSquare()
    local fire, place
    if square then fire, place = warmestFire(square) end
    if fire then return Hearth.firePlace(place, Weather.placeOf(object)), fire end
    return Weather.placeOf(object)
end

-- Weather.placeTemperature knows the fire's places too (Weather.FIRE_PLACES); kept for the mods that call it here.
Hearth.placeTemperature = Weather.placeTemperature

-- Marks for Hearth.catchUp: Weather's, which keep the hour they were taken.
Hearth.mark = Weather.mark

-- The work done since the marks at place, which may be by a fire (Hearth.placeOf), and moves the marks on. The
-- ledger keeps totals for the weather's places only, so time by a fire counts by the clock at its heat, rateAt
-- the work's rate at a temperature, until the fire's noted fuel ran out (state.fireUntil, Hearth.noteFire). The
-- ledger's totals can't be split at that hour, so the place under the fire (state.under) gets its share of the
-- gap's weather by time. Marks taken without an hour count from the ledger's last record.
function Hearth.catchUp(state, marks, ledger, kind, place, rateAt)
    local work
    if Hearth.isFirePlace(place) then
        local from, to = marks.hour or ledger.lastHour, ledger.lastHour
        local byFire = math.max(math.min(state.fireUntil or to, to) - from, 0)
        work = byFire * rateAt(Hearth.fireC(place, ledger))
        if to - from > byFire then
            work = work + Weather.catchUp(marks, ledger, kind, state.under or "Sheltered") * (to - from - byFire) / (to - from)
        end
    else
        work = Weather.catchUp(marks, ledger, kind, place)
    end
    Hearth.mark(marks, ledger, kind)
    return work
end

-- A weather-timed craft run (Yeast's culture, Vinegar's malt and wort, the template's batch): its recipe data's
-- modData keeps done (hours of work), last (the marks) and the place Hearth.notePlace wrote. These bring one up to
-- now at that place, by a fire or not; a run not yet started (no done or no marks) is left alone.
function Hearth.catchUpRun(modData, ledger, kind, place, rateAt)
    if not (modData.done and modData.last) then return end
    modData.done = modData.done + Hearth.catchUp(modData, modData.last, ledger, kind, place, rateAt)
end

-- A run's OnUpdate: catches it up and sets the craft's bar from the work done (Weather.showProgress).
function Hearth.updateRun(craftRecipeData, ledger, kind, place, rateAt, speed)
    local modData = craftRecipeData:getModData()
    if not (modData.done and modData.last) then return end
    Hearth.catchUpRun(modData, ledger, kind, place, rateAt)
    Weather.showProgress(craftRecipeData, ledger, kind, place, speed or 1, getGameTime():getWorldAgeHours(), rateAt)
end

-- Where a station stands for its work, written into state (a run's or a station's modData): its place now, with
-- the fire's fuel noted when it is by one. A move brings the work up to now first, at the place it left
-- (catchUp(state), the mod's own), so the hours by a fire count even when the station is seen again after it went out.
function Hearth.notePlace(state, object, now, catchUp)
    local place, fire = Hearth.placeOf(object)
    if state.place ~= nil and state.place ~= place and catchUp then catchUp(state) end
    state.place = place
    Hearth.noteFire(state, object, fire, now)
    return place
end

-- Notes on a station's state where it stands: by a fire, until when the fuel lasts and what it stands in without
-- the fire. A station's catch-up reads them for the time it was away.
function Hearth.noteFire(state, object, fire, now)
    if not fire then
        state.fireUntil, state.under = nil, nil
        return
    end
    local hours = Hearth.fuelHours(fire)
    state.fireUntil = hours and now + hours or nil
    state.under = Weather.placeOf(object)
end

-- Building: the entity script's OnCreate, so a global.
TraditionalPreservationCore = TraditionalPreservationCore or {}

local function toFireplace(params, faceOf)
    local thumpable = params.thumpable
    local sprite = thumpable and thumpable:getSprite()
    local name = sprite and sprite:getName()
    if not faceOf(name) then return nil end
    local square = thumpable:getSquare()
    local fire = IsoFireplace.new(getCell(), square, getSprite(name))
    square:AddTileObject(fire)
    if thumpable:getSquare() ~= nil then
        thumpable:removeFromWorld()
        thumpable:removeFromSquare()
        thumpable:setSquare(nil)
    end
    return { replaceObject = true, object = fire }
end

function TraditionalPreservationCore.OnCreateFirebox(params)
    return toFireplace(params, Hearth.fireboxFace)
end

return Hearth
