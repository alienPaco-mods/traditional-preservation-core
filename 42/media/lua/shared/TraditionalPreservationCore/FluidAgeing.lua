-- Traditional Preservation core: fluids that go off. Vanilla fluids never age, so a mod registers a kind of fluid
-- (Dairy: milk) with its fresh fluids, the twin each turns into, the fluid each ends as and a rate curve, and the
-- core keeps an age fluidAge on whatever holds it: an item's modData or a world object's, under KEY. The age is in
-- hours at the curve's reference (rate 1), counted on the mod's weather ledger by place, like a station's work, so
-- an item left alone catches up when it is next looked at, at the place it was seen in last. A powered fridge
-- counts at FRIDGE_C by the clock, a powered freezer not at all, a place by a fire at its heat by the clock while
-- the fuel noted at the last look lasted (Fire.noteFire).
--
-- Stages: Fresh, then Turned (each fresh fluid swapped for its twin: soured milk) at turnHours, then Spoiled (each
-- fresh fluid and its twin swapped for the fresh one's spoiled fluid: rotten milk) at spoilHours.
--
-- States (optional): a kind may name variants of its fresh fluid, each with its own name for each fresh fluid and,
-- if it keeps longer, its own spoilHours (Fish & Meat's blood: Cured; Dairy's milk: Scalded, Cow's Milk (Scalded, Fresh)).
-- A fluidAge keeps the treatments done (treated = { Cured = true }); its state is the one whose treatments match
-- exactly. A fluidAge in a state never turns: it stays fresh until its spoilHours and then spoils. Fluid seen for the
-- first time under a state's name takes that state; a mix of two states' names takes none.
-- Most states are done by hand (FluidTreat). One state may be made by heat instead (heat = true: scalding kills what
-- would sour milk): a kind may name a scalding heat (scaldHeat, vanilla item heat), and fluid seen in an item that
-- hot, on a stove or a fire, takes the heat state from then on, as vanilla's boiling makes tainted water clean. With a
-- hold (scaldHold, hours) only once it has been that hot for so long in all: an item counts its hours under HELD_KEY,
-- a cauldron by CauldronFluid.heldHours. The hold is counted even with the kind's ageing off, for mods that keep their own
-- scalded flag. A fluid is in one state at a time: heat leaves a fluid already in a state as it is, and a treatment
-- by hand replaces the heat state.
--
-- Pouring: the older age wins, and a raw share makes the whole lot raw again (a mix keeps only the treatments both
-- sides had). An empty container takes the source's fluidAge, so pouring never makes milk young. Sealed items (store
-- milk) keep their own fluid without a fluidAge; poured out, it is in the heat state. Every rule here works on plain tables; the engine parts are at the end. Treating by hand
-- (the treat menu, the uses it takes) is FluidTreat's; its functions are reached here too.
local Weather = require "TraditionalPreservationCore/Weather"
local Fire = require "TraditionalPreservationCore/Fire"

local FluidAgeing = {}

-- Save key: never rename it once the mod is out. Inside: process, age, treated, place, marks, hour; by a fire,
-- fireUntil and placeWithoutFire (Fire.noteFire).
FluidAgeing.KEY = "tpFluidAge"
FluidAgeing.FRIDGE = "Fridge"
FluidAgeing.FREEZER = "Freezer"
FluidAgeing.FRIDGE_C = 4
-- An item's hours at its kind's scalding heat: { hours, at }, at the hour it was last seen hot (nil once seen cooler).
FluidAgeing.HELD_KEY = "tpHeldHot"
-- Where fluid is when nothing says (no place given, none of its own, no fluidAge).
FluidAgeing.DEFAULT_PLACE = Weather.DEFAULT_PLACE
-- Vanilla's Food Spoilage sandbox steps (Food.getFoodRotSpeed: very fast to very slow).
local FOOD_ROT_SPEEDS = { 1.7, 1.4, 1, 0.7, 0.4 }

-- The multiplier vanilla's Food Spoilage setting puts on food's age (Normal 1): a fluid kind's speed for anything that
-- should go off as food does.
function FluidAgeing.foodRotSpeed()
    return FOOD_ROT_SPEEDS[SandboxVars and SandboxVars.FoodRotSpeed] or 1
end
-- A first look on the heat counts as this many hours, so the hold has started.
local FIRST_HOT_LOOK = 1e-6

-- fluidKind = {
--   process       the ledger process it ages on (also its name); also the fluidAge's process
--   rate          function(celsius): work per hour at that temperature
--   turnHours     hours at the reference until Turned
--   spoilHours    hours at the reference until Spoiled
--   fresh         { fresh name = its turned twin }
--   spoiled       { fresh name = what it ends as }
--   getLedger     function(): the mod's weather ledger
--   optional:
--   scaldHeat     vanilla item heat that brings about the heat state
--   scaldHold     hours at scaldHeat before it does
--   sealed        { item fullType = true }: holds the fluid with no fluidAge (store milk)
--   enabled       function(): false while the kind's ageing is off
--   speed         function(): the sandbox's multiplier on the age (FluidAgeing.foodRotSpeed: vanilla's Food Spoilage)
--   states        { name = { fluids = { fresh name = its name in this state }, spoilHours (default the kind's),
--                   of = { treatment names } (default { name }), heat (true: made by heat, not by hand; one at most),
--                   process, rate (the state's own ledger process and curve, when it slows in the cold unlike the plain
--                   fluid; the mod's ledger must count that process) } }
--   treatments, litresPerUse, treatMenu, treatTooltip: treating by hand (FluidTreat)
-- }
-- enabled and speed are asked each time, so the sandbox can change them. register adds spoiledOf, plainOf,
-- stateOfFluid, heatState and isSpoiled to the fluid kind, and name and treatments (sorted) to each state.
local fluidKinds = {}
local byFluid = {}
local lowestHeat

-- Notes a fluid the fluid kind claims (claimed: a set, taken only once every check has passed); another kind can't have it.
local function claim(fluidKind, claimed, name)
    local owner = byFluid[name]
    assert(not owner or owner.process == fluidKind.process,
        "FluidAgeing.register: " .. fluidKind.process .. " claims " .. tostring(name) .. ", already " .. tostring(owner and owner.process))
    claimed[name] = true
end

local function need(fluidKind, field)
    assert(fluidKind[field] ~= nil, "FluidAgeing.register: " .. tostring(fluidKind.process) .. " has no " .. field)
end

function FluidAgeing.register(fluidKind)
    for _, field in ipairs({ "process", "rate", "turnHours", "spoilHours", "fresh", "spoiled", "getLedger" }) do
        need(fluidKind, field)
    end
    -- What each of the kind's fluids ends as: a fresh fluid, its twin and its spoiled one all end as the spoiled one.
    local claimed = {}
    fluidKind.spoiledOf, fluidKind.plainOf, fluidKind.isSpoiled = {}, {}, {}
    for fresh, twin in pairs(fluidKind.fresh) do
        local spoiled = fluidKind.spoiled[fresh]
        assert(spoiled, "FluidAgeing.register: " .. fluidKind.process .. " has no spoiled fluid for " .. fresh)
        claim(fluidKind, claimed, fresh)
        claim(fluidKind, claimed, twin)
        claim(fluidKind, claimed, spoiled)
        fluidKind.spoiledOf[fresh], fluidKind.spoiledOf[twin], fluidKind.spoiledOf[spoiled] = spoiled, spoiled, spoiled
        fluidKind.isSpoiled[spoiled] = true
    end
    -- Each state's treatments, sorted; no two states may have the same ones. A state's fluid ends as its fresh one's
    -- spoiled fluid, and goes back to the fresh one (plainOf) when raw is mixed in.
    local keys = {}
    fluidKind.stateOfFluid, fluidKind.heatState = {}, nil
    for name, state in pairs(fluidKind.states or {}) do
        local of = {}
        for _, treatment in ipairs(state.of or { name }) do table.insert(of, treatment) end
        table.sort(of)
        state.name, state.treatments = name, of
        local key = table.concat(of, "+")
        assert(not keys[key], "FluidAgeing.register: " .. fluidKind.process .. " has two states done by " .. key)
        keys[key] = true
        if state.heat then
            assert(not fluidKind.heatState, "FluidAgeing.register: " .. fluidKind.process .. " has two states made by heat")
            assert(#of == 1 and of[1] == name, "FluidAgeing.register: " .. fluidKind.process .. "'s heat state " .. name .. " is done by hand")
            fluidKind.heatState = state
        end
        for fresh, named in pairs(state.fluids) do
            claim(fluidKind, claimed, named)
            fluidKind.spoiledOf[named], fluidKind.plainOf[named] = fluidKind.spoiled[fresh], fresh
            fluidKind.stateOfFluid[named] = state
        end
    end
    for name in pairs(claimed) do byFluid[name] = fluidKind end
    fluidKinds[fluidKind.process] = fluidKind
    lowestHeat = nil
    for _, each in pairs(fluidKinds) do
        if each.scaldHeat and (not lowestHeat or each.scaldHeat < lowestHeat) then lowestHeat = each.scaldHeat end
    end
    return fluidKind
end

-- The state a fluidAge is in (a fluidKind.states entry), or nil when untreated or no state has exactly its treatments.
function FluidAgeing.state(fluidAge, fluidKind)
    if not fluidAge.treated or not fluidKind.states then return nil end
    local count = 0
    for _ in pairs(fluidAge.treated) do count = count + 1 end
    for _, state in pairs(fluidKind.states) do
        if #state.treatments == count then
            local all = true
            for _, treatment in ipairs(state.treatments) do all = all and fluidAge.treated[treatment] ~= nil end
            if all then return state end
        end
    end
    return nil
end

-- Hours at the reference until the fluidAge spoils: its state's, else the kind's.
function FluidAgeing.spoilHours(fluidAge, fluidKind)
    local state = FluidAgeing.state(fluidAge, fluidKind)
    return state and state.spoilHours or fluidKind.spoilHours
end

-- The ledger process and rate curve a fluidAge ages by: its state's own, else the kind's.
local function agingOf(fluidAge, fluidKind)
    local state = FluidAgeing.state(fluidAge, fluidKind)
    if state and state.process then return state.process, state.rate end
    return fluidKind.process, fluidKind.rate
end

-- After its state changed (treated, untreated, merged, started in a state): marks a fluidAge, already brought up to
-- now, on the ledger process it ages by now, so the next look counts from here. Left alone when the process is the
-- one it was marked on, so no stretch is lost.
local function markState(fluidAge, fluidKind, ledger)
    local process = agingOf(fluidAge, fluidKind)
    if fluidAge.marks and (fluidAge.markProcess or fluidKind.process) == process then return end
    fluidAge.marks = Weather.mark({}, ledger or fluidKind.getLedger(), process)
    fluidAge.markProcess = process ~= fluidKind.process and process or nil
end

-- True if nothing will turn the fluidAge before it spoils: it is in a state.
local function neverTurns(fluidAge)
    return fluidAge.treated ~= nil
end

-- True if the fluidAge is in the state called name (Dairy's "Scalded").
function FluidAgeing.inState(fluidAge, name)
    return fluidAge ~= nil and fluidAge.treated ~= nil and fluidAge.treated[name] == true
end

function FluidAgeing.fluidKind(process)
    return fluidKinds[process]
end

-- The fluid kind a fluid belongs to, or nil.
function FluidAgeing.fluidKindOf(name)
    return byFluid[name]
end

local function isOn(fluidKind)
    return not fluidKind.enabled or fluidKind.enabled()
end

-- Fresh, Turned or Spoiled.
function FluidAgeing.stage(fluidAge, fluidKind)
    if fluidAge.age >= FluidAgeing.spoilHours(fluidAge, fluidKind) then return "Spoiled" end
    if not neverTurns(fluidAge) and fluidAge.age >= fluidKind.turnHours then return "Turned" end
    return "Fresh"
end

-- Hours at the reference until the next stage, or nil when spoiled.
function FluidAgeing.hoursLeft(fluidAge, fluidKind)
    local stage = FluidAgeing.stage(fluidAge, fluidKind)
    if stage == "Spoiled" then return nil end
    local spoil = FluidAgeing.spoilHours(fluidAge, fluidKind)
    local next = stage == "Fresh" and not neverTurns(fluidAge) and math.min(fluidKind.turnHours, spoil) or spoil
    return next - fluidAge.age
end

-- A new fluidAge, marked on the ledger now: nothing done yet, or in the state called stateName.
function FluidAgeing.newFluidAge(fluidKind, ledger, now, place, stateName)
    local fluidAge = { process = fluidKind.process, age = 0, treated = stateName and { [stateName] = true } or nil, place = place, hour = now }
    markState(fluidAge, fluidKind, ledger)
    return fluidAge
end

local function shallowCopy(fields)
    if not fields then return nil end
    local copy = {}
    for k, v in pairs(fields) do copy[k] = v end
    return copy
end

function FluidAgeing.copy(fluidAge)
    return { process = fluidAge.process, age = fluidAge.age, treated = shallowCopy(fluidAge.treated),
        markProcess = fluidAge.markProcess, place = fluidAge.place, hour = fluidAge.hour, marks = shallowCopy(fluidAge.marks or {}),
        fireUntil = fluidAge.fireUntil, placeWithoutFire = fluidAge.placeWithoutFire }
end

-- Puts a fresh fluidAge in the kind's heat state (scalding kills what would sour it), unless it is in a state already.
-- Returns true if it is fresh.
local function scaldIfFresh(fluidAge, fluidKind)
    if FluidAgeing.stage(fluidAge, fluidKind) ~= "Fresh" then return false end
    if fluidKind.heatState and not fluidAge.treated then fluidAge.treated = { [fluidKind.heatState.name] = true } end
    return true
end

-- Brings the fluidAge up to now: the time since it was last seen counts at the place it was seen in then. place is
-- where it is now, and counts from here on. By a fire, fireNote (default the fluidAge) holds the fire noted then
-- (Fire.noteFire: fireUntil, placeWithoutFire); a station's own modData may stand in for it.
function FluidAgeing.advance(fluidAge, fluidKind, ledger, now, place, fireNote)
    -- A state with its own curve counts on its own ledger process. The marks are of the process they were taken on
    -- (markProcess, nil for the fluidKind's own). Every change of state re-marks at once (markState), so a mismatch is
    -- only an old save's record: its stretch is lost, once.
    local process, rate = agingOf(fluidAge, fluidKind)
    local was, work = fluidAge.place, 0
    local marked = (fluidAge.markProcess or fluidKind.process) == process
    local function sinceMarks(at)
        local total = ledger[process .. at] or 0
        return total - ((fluidAge.marks or {})[at] or total)
    end
    if was == FluidAgeing.FRIDGE then
        work = math.max(now - (fluidAge.hour or now), 0) * rate(FluidAgeing.FRIDGE_C)
    elseif Weather.FIRE_PLACES[was] then
        -- The ledger keeps no totals by a fire: the time counts by the clock at the fire's heat until its noted fuel
        -- ran out, the rest at the place under it by its share of the stretch (as Fire.catchUp).
        fireNote = fireNote or fluidAge
        local from = fluidAge.hour or now
        local byFire = math.max(math.min(fireNote.fireUntil or now, now) - from, 0)
        work = byFire * rate(Weather.placeTemperature(ledger, was))
        if now - from > byFire and marked then
            work = work + sinceMarks(fireNote.placeWithoutFire or Fire.DEFAULT_PLACE_WITHOUT_FIRE) * (now - from - byFire) / (now - from)
        end
    elseif was ~= FluidAgeing.FREEZER and was and marked then
        work = sinceMarks(was)
    end
    fluidAge.marks = Weather.mark(fluidAge.marks or {}, ledger, process)
    fluidAge.markProcess = process ~= fluidKind.process and process or nil
    fluidAge.age = fluidAge.age + math.max(work, 0) * (fluidKind.speed and fluidKind.speed() or 1)
    fluidAge.hour, fluidAge.place = now, place
    return fluidAge
end

-- into takes from: the older age and the treatments both had.
function FluidAgeing.merge(into, from)
    into.age = math.max(into.age, from.age)
    local shared
    for treatment in pairs(into.treated or {}) do
        if from.treated and from.treated[treatment] then
            shared = shared or {}
            shared[treatment] = true
        end
    end
    into.treated = shared
    return into
end

-- Engine parts

-- The engine's Fluid for one of the fluid kind's names, looked up once (not at register: fluids may not exist yet).
local function fluidOf(fluidKind, name)
    fluidKind.fluidObjects = fluidKind.fluidObjects or {}
    local fluid = fluidKind.fluidObjects[name]
    if not fluid then
        fluid = Fluid.Get(name)
        fluidKind.fluidObjects[name] = fluid
    end
    return fluid
end

-- The ml of each of the fluid kind's fluids in a container ({ name = litres }), and their total.
function FluidAgeing.amounts(container, fluidKind)
    local found, total = {}, 0
    for name in pairs(fluidKind.spoiledOf) do
        local fluid = fluidOf(fluidKind, name)
        local amount = fluid and container:getSpecificFluidAmount(fluid) or 0
        if amount > 0 then
            found[name] = amount
            total = total + amount
        end
    end
    return found, total
end

-- The registered fluid kind whose fluids the container holds, with what it holds of them (as amounts), or nil.
function FluidAgeing.fluidKindIn(container)
    if not container or container:isEmpty() then return nil end
    for _, fluidKind in pairs(fluidKinds) do
        local found, total = FluidAgeing.amounts(container, fluidKind)
        if total > 0 then return fluidKind, found, total end
    end
end

-- adjustSpecificFluidAmount sets the amount (dropping the fluid at 0), so a swap is: read, zero, add the other.
local function swap(container, fluidKind, from, to, amount)
    container:adjustSpecificFluidAmount(fluidOf(fluidKind, from), 0)
    container:addFluid(to, amount)
end

-- The name a fluid goes by at a stage: a fresh fluid's twin once turned, its spoiled fluid once spoiled; while fresh,
-- its state's name when in one (state, a fluidKind.states entry), else its plain one.
local function nameAt(fluidKind, stage, name, state)
    if stage == "Spoiled" then return fluidKind.spoiledOf[name] or name end
    local plain = fluidKind.plainOf[name] or name
    if stage == "Turned" then return fluidKind.fresh[plain] or name end
    if state then return state.fluids[plain] or name end
    return plain
end
FluidAgeing.nameAt = nameAt

-- The treatments of the fluid in found ({ name = litres }) if every fresh share of it goes by one state's name: a
-- container seen for the first time with cured blood is cured, with scalded milk scalded. Turned and spoiled shares
-- say nothing either way; a plain or other state's share makes it nil.
local function treatedIn(fluidKind, found)
    local state
    for name in pairs(found) do
        local named = fluidKind.stateOfFluid[name]
        if fluidKind.fresh[name] or (named and state and named ~= state) then
            return nil
        end
        state = named or state
    end
    if not state then return nil end
    local treated = {}
    for _, treatment in ipairs(state.treatments) do treated[treatment] = true end
    return treated
end

-- A new fluidAge for the fluid in found ({ name = litres }): in the state its names say, else in the heat state if it
-- scalds.
local function startFluidAge(fluidKind, found, now, place, scalds)
    local fluidAge = FluidAgeing.newFluidAge(fluidKind, fluidKind.getLedger(), now, place)
    fluidAge.treated = treatedIn(fluidKind, found)
    if scalds then scaldIfFresh(fluidAge, fluidKind) end
    markState(fluidAge, fluidKind)
    return fluidAge
end

-- Swaps the fluids for the record's stage (found: the container's amounts, when already read and nothing has been
-- swapped since). Returns true if anything changed.
function FluidAgeing.apply(container, fluidAge, fluidKind, found)
    local stage = FluidAgeing.stage(fluidAge, fluidKind)
    local state = FluidAgeing.state(fluidAge, fluidKind)
    local changed = false
    for name, amount in pairs(found or FluidAgeing.amounts(container, fluidKind)) do
        local target = nameAt(fluidKind, stage, name, state)
        if target ~= name then
            swap(container, fluidKind, name, target, amount)
            changed = true
        end
    end
    return changed
end

-- The place of whatever holds an item (or a world object itself), by a fire too (Fire.placeOf), with the fire. The
-- last answer is kept for its square and hour: a look through a crate asks once, not once an item.
local lastHolder = {}
local function placeOfHolder(holder)
    local square, hour = holder:getSquare(), getGameTime():getWorldAgeHours()
    if not (square and lastHolder.square == square and lastHolder.hour == hour) then
        local place, fire = Fire.placeOf(holder)
        lastHolder = { square = square, hour = hour, place = place, fire = fire }
    end
    return lastHolder.place, lastHolder.fire
end

-- Where an item is for ageing: a powered fridge or freezer, else the place of whatever holds it (a player, a world
-- container, the floor, a vehicle), by a fire or not. Nil when nothing says. By a fire, the fire and the holder
-- come second and third, for Fire.noteFire.
function FluidAgeing.placeOfItem(item)
    local holder
    local container = item:getOutermostContainer()
    if container then
        local containerType = container:getType()
        if (containerType == "fridge" or containerType == "freezer") and container:isPowered() then
            return containerType == "freezer" and FluidAgeing.FREEZER or FluidAgeing.FRIDGE
        end
        holder = container:getParent()
        local part = not holder and container:getVehiclePart()
        if part then holder = part:getVehicle() end
    end
    holder = holder or item:getWorldItem()
    if not holder then return nil end
    local place, fire = placeOfHolder(holder)
    return place, fire, holder
end

local function placeOfOwner(owner)
    if instanceof(owner, "InventoryItem") then return FluidAgeing.placeOfItem(owner) end
    local place, fire = placeOfHolder(owner)
    return place, fire, owner
end

-- Notes on a fluidAge seen at a place found here (placeOfItem) the fire it is by, or that it is by none (fire nil).
function FluidAgeing.noteFire(fluidAge, fire, holder, now)
    Fire.noteFire(fluidAge, holder, fire, now)
end

-- True if the owner is an item as hot as the kind scalds at (on a stove or a fire: an item's heat follows what holds it).
local function scalding(owner, fluidKind)
    return fluidKind.scaldHeat ~= nil and instanceof(owner, "InventoryItem") and owner:getItemHeat() >= fluidKind.scaldHeat
end

-- True if hours at the scalding heat meet the kind's hold.
function FluidAgeing.heldLongEnough(fluidKind, hours)
    return (hours or 0) > 0 and hours >= (fluidKind.scaldHold or 0)
end

-- Counts an owner's hours at the scalding heat: from one look to the next while it stays that hot. Returns them.
local function noteHeat(owner, fluidKind, now)
    local modData = owner:getModData()
    local held = modData[FluidAgeing.HELD_KEY]
    if not scalding(owner, fluidKind) then
        if held then held.at = nil end
        return held and held.hours or 0
    end
    held = held or { hours = 0 }
    if held.at then held.hours = held.hours + math.max(now - held.at, 0) end
    -- A first look on the heat counts as a moment: the hold starts here.
    held.hours, held.at = math.max(held.hours, FIRST_HOT_LOOK), now
    modData[FluidAgeing.HELD_KEY] = held
    return held.hours
end

-- An item's hours at its kind's scalding heat, in all, as last counted (0 when never).
function FluidAgeing.heldHours(owner)
    local held = owner and owner:getModData()[FluidAgeing.HELD_KEY]
    return held and held.hours or 0
end

local function isSealed(owner, fluidKind)
    return fluidKind.sealed and instanceof(owner, "InventoryItem") and fluidKind.sealed[owner:getFullType()] or false
end

-- An owner forgets the age and the heat of fluid it no longer holds.
local function forget(modData)
    modData[FluidAgeing.KEY], modData[FluidAgeing.HELD_KEY] = nil, nil
end

-- look's work. Returns the fluidAge and fluid kind, or nil; for a sealed item with no fluidAge, nil, nil and its fluid kind.
local function see(owner, now, place)
    local container = owner and owner:getFluidContainer()
    local modData = owner and owner:getModData()
    local fluidKind, found = FluidAgeing.fluidKindIn(container)
    if not fluidKind then
        if modData then forget(modData) end
        return nil
    end
    -- The hold is counted even with the kind's ageing off.
    local scalds = FluidAgeing.heldLongEnough(fluidKind, noteHeat(owner, fluidKind, now))
    if not isOn(fluidKind) then return nil end
    local fluidAge = modData[FluidAgeing.KEY]
    local fire, holder
    if not place then place, fire, holder = placeOfOwner(owner) end
    place = place or (fluidAge and fluidAge.place) or FluidAgeing.DEFAULT_PLACE
    if not fluidAge or fluidAge.process ~= fluidKind.process then
        if isSealed(owner, fluidKind) then return nil, nil, fluidKind end
        fluidAge = startFluidAge(fluidKind, found, now, place, scalds)
        modData[FluidAgeing.KEY] = fluidAge
    else
        FluidAgeing.advance(fluidAge, fluidKind, fluidKind.getLedger(), now, place)
        if scalds then scaldIfFresh(fluidAge, fluidKind) end
    end
    if holder then FluidAgeing.noteFire(fluidAge, fire, holder, now) end
    FluidAgeing.apply(container, fluidAge, fluidKind, found)
    return fluidAge, fluidKind
end

-- Brings the fluid an owner (an item or a world object) holds up to now, swapping it if it turned. A container
-- with none of a kind's fluid loses its fluidAge; a sealed one with no fluidAge is left alone. Returns the fluidAge and
-- fluid kind, or nil.
function FluidAgeing.look(owner, now, place)
    local fluidAge, fluidKind = see(owner, now, place)
    return fluidAge, fluidKind
end

-- The age of the fluid leaving an owner, brought up to now: its fluidAge, or for a sealed item (store milk) a new
-- one in the heat state, since it was pasteurised. Nil when it holds none of a kind's fluid. Call it before the fluid leaves.
function FluidAgeing.sourceFluidAge(source, now)
    local fluidAge, fluidKind, sealed = see(source, now)
    if fluidAge then return FluidAgeing.copy(fluidAge), fluidKind end
    if not sealed then return nil end
    return FluidAgeing.newFluidAge(sealed, sealed.getLedger(), now, placeOfOwner(source) or FluidAgeing.DEFAULT_PLACE,
        sealed.heatState and sealed.heatState.name), sealed
end

-- holder (a modData table, or a cauldron's state) gets fluid of age fluidAge: it takes the fluidAge if it held none of
-- the kind (hadSome false), else the older age.
function FluidAgeing.receive(holder, fluidAge, hadSome, place)
    -- Fluid coming in not in the heat state starts the hold at the heat over.
    local fluidKind = fluidKinds[fluidAge.process]
    if not (fluidKind and fluidKind.heatState and FluidAgeing.inState(fluidAge, fluidKind.heatState.name)) then
        holder[FluidAgeing.HELD_KEY] = nil
    end
    local into = hadSome and holder[FluidAgeing.KEY]
    if into and into.process == fluidAge.process then
        FluidAgeing.merge(into, fluidAge)
        if fluidKind then markState(into, fluidKind) end
    else
        local copy = FluidAgeing.copy(fluidAge)
        copy.place = place or copy.place
        holder[FluidAgeing.KEY] = copy
    end
end

-- Brings what a cauldron's state ({ ml, fluid, parts }, Stone Hearth's) holds up to now at the Stone Hearth's place and renames
-- its fluids for their stage, as a container's are swapped, so turned milk in the cauldron is no longer milk to
-- anything that reads it. Milk that has steamed in the cauldron for the kind's hold (heldHours, CauldronFluid.heldHours) is
-- in the heat state from then on, and renamed so; raw milk poured onto it makes it plain again. An empty cauldron forgets; one holding a kind's fluid with no fluidAge (filled before
-- the kind aged, or by a debug command) starts one.
function FluidAgeing.updateCauldron(cauldron, now, place, heldHours)
    local fluidAge = cauldron[FluidAgeing.KEY]
    if (cauldron.ml or 0) <= 0 then
        cauldron[FluidAgeing.KEY] = nil
        return nil
    end
    if not fluidAge then
        local found = cauldron.parts or { [cauldron.fluid or ""] = cauldron.ml }
        local fluidKind = cauldron.fluid and byFluid[cauldron.fluid]
        if not fluidKind or not isOn(fluidKind) then return nil end
        fluidAge = startFluidAge(fluidKind, found, now, place)
        cauldron[FluidAgeing.KEY] = fluidAge
    end
    local fluidKind = fluidKinds[fluidAge.process]
    if not fluidKind or not isOn(fluidKind) then return nil end
    FluidAgeing.advance(fluidAge, fluidKind, fluidKind.getLedger(), now, place)
    if FluidAgeing.heldLongEnough(fluidKind, heldHours) then scaldIfFresh(fluidAge, fluidKind) end
    local stage = FluidAgeing.stage(fluidAge, fluidKind)
    local state = FluidAgeing.state(fluidAge, fluidKind)
    if cauldron.parts then
        local parts, count, most, changed = {}, 0, nil, false
        for name, part in pairs(cauldron.parts) do
            local renamed = nameAt(fluidKind, stage, name, state)
            if not parts[renamed] then count = count + 1 end
            parts[renamed] = (parts[renamed] or 0) + part
            changed = changed or renamed ~= name
        end
        if not changed then return fluidAge, fluidKind end
        for name, part in pairs(parts) do
            if not most or part > parts[most] or (part == parts[most] and name < most) then most = name end
        end
        cauldron.parts = count > 1 and parts or nil
        cauldron.fluid = most
    elseif cauldron.fluid then
        cauldron.fluid = nameAt(fluidKind, stage, cauldron.fluid, state)
    end
    return fluidAge, fluidKind
end

-- A copy of the age of what a cauldron's state holds, brought up to now (heldHours as for updateCauldron), or nil.
function FluidAgeing.cauldronFluidAge(cauldron, now, place, heldHours)
    local fluidAge = FluidAgeing.updateCauldron(cauldron, now, place, heldHours)
    return fluidAge and FluidAgeing.copy(fluidAge) or nil
end

-- Before fluid goes from one owner to another: the target takes the source's age.
function FluidAgeing.pour(source, target, now)
    local fluidAge = FluidAgeing.sourceFluidAge(source, now)
    if not fluidAge then return end
    local hadSome = FluidAgeing.look(target, now) ~= nil
    local place, fire, holder = placeOfOwner(target)
    local modData = target:getModData()
    FluidAgeing.receive(modData, fluidAge, hadSome, place)
    local received = modData[FluidAgeing.KEY]
    if holder and received.place == place then FluidAgeing.noteFire(received, fire, holder, now) end
end

-- Forgets the fluidAge of an owner holding none of the kind's fluid, so new fluid starts fresh (before milking).
function FluidAgeing.clearIfEmpty(owner)
    local modData = owner and owner:getModData()
    if modData and modData[FluidAgeing.KEY] and not FluidAgeing.fluidKindIn(owner:getFluidContainer()) then forget(modData) end
end

-- Looks at an owner's fluid and lets change(fluidAge, fluidKind) change its fluidAge; when it says it did (true), renames
-- the fluid for the fluidAge. Returns true if it did.
local function changeFluidAge(owner, now, change)
    local fluidAge, fluidKind = FluidAgeing.look(owner, now)
    if not fluidAge or not change(fluidAge, fluidKind) then return false end
    markState(fluidAge, fluidKind)
    FluidAgeing.apply(owner:getFluidContainer(), fluidAge, fluidKind)
    return true
end

-- Puts the fluid an owner holds in the kind's heat state (drawn hot from the Stone Hearth's cauldron): a fresh fluidAge, or
-- the one it has. Its fresh fluids are renamed to the state's.
function FluidAgeing.markScalded(owner, now)
    changeFluidAge(owner, now, scaldIfFresh)
end

-- Adds a treatment to the fluid an owner holds (Add Salt to Blood), while it is fresh, and renames it for its new
-- state. Returns true if it took.
function FluidAgeing.treat(owner, now, treatment)
    return changeFluidAge(owner, now, function(fluidAge, fluidKind)
        if FluidAgeing.stage(fluidAge, fluidKind) ~= "Fresh" then return false end
        -- A treatment by hand replaces the heat state: one state at a time.
        if fluidKind.heatState and FluidAgeing.inState(fluidAge, fluidKind.heatState.name) then fluidAge.treated = nil end
        fluidAge.treated = fluidAge.treated or {}
        fluidAge.treated[treatment] = true
        return true
    end)
end

-- Forgets the treatments of the fluid an owner holds (fresh fluid gathered into it, as vanilla adds blood): a raw
-- share makes the whole lot untreated, as pouring does.
function FluidAgeing.untreat(owner, now)
    changeFluidAge(owner, now, function(fluidAge)
        if not fluidAge.treated then return false end
        fluidAge.treated = nil
        return true
    end)
end

-- Treating by hand lives in FluidTreat (it needs the character's uses); still reached here, so no mod changes.
for _, name in ipairs({ "litresIn", "treatUses", "treatableFluidKind", "treatRefusal", "treatBy" }) do
    FluidAgeing[name] = function(...)
        return require("TraditionalPreservationCore/FluidTreat")[name](...)
    end
end

local function hasFluid(item)
    return item:getFluidContainer() ~= nil
end

-- The lowest heat any kind scalds at, or nil (worked out at register).
function FluidAgeing.lowestScaldHeat()
    return lowestHeat
end

-- Brings every fluid item in an item container (and the bags inside it) up to now.
function FluidAgeing.lookIn(container, now)
    local items = container and container:getAllEvalRecurse(hasFluid)
    for i = 0, items and items:size() - 1 or -1 do FluidAgeing.look(items:get(i), now) end
end

return FluidAgeing
