-- Traditional Preservation core: fluids that go off. Vanilla fluids never age, so a mod registers a kind of fluid
-- (Dairy: milk) with its fresh fluids, the twin each turns into, the fluid each ends as and a rate curve, and the
-- core keeps an age record on whatever holds it: an item's modData or a world object's, under KEY. The age is in
-- hours at the curve's reference (rate 1), counted on the mod's weather ledger by place, like a station's work, so
-- an item left alone catches up when it is next looked at, at the place it was seen in last. A powered fridge
-- counts at FRIDGE_C by the clock, a powered freezer not at all.
--
-- Stages: Fresh, then Turned (each fresh fluid swapped for its twin: soured milk) at turnHours, then Spoiled (each
-- fresh fluid and its twin swapped for the fresh one's spoiled fluid: rotten milk) at spoilHours.
--
-- States (optional): a kind may name variants of its fresh fluid, each with its own name for each fresh fluid and,
-- if it keeps longer, its own spoilHours (Fish & Meat's blood: Cured; Dairy's milk: Scalded, Cow's Milk (Scalded)).
-- A record keeps the treatments done (treated = { Cured = true }); its state is the one whose treatments match
-- exactly. A record in a state never turns: it stays fresh until its spoilHours and then spoils. Fluid seen for the
-- first time under a state's name takes that state; a mix of two states' names takes none.
-- Most states are done by hand (FluidTreat). One state may be made by heat instead (heat = true: scalding kills what
-- would sour milk): a kind may name a scalding heat (scaldHeat, vanilla item heat), and fluid seen in an item that
-- hot, on a stove or a fire, takes the heat state from then on, as vanilla's boiling makes tainted water clean. With a
-- hold (scaldHold, hours) only once it has been that hot for so long in all: an item counts its hours under HELD_KEY,
-- a cauldron by Hearth.heldHours. The hold is counted even with the kind's ageing off, for mods that keep their own
-- scalded flag. A fluid is in one state at a time: heat leaves a fluid already in a state as it is, and a treatment
-- by hand replaces the heat state.
--
-- Pouring: the older age wins, and a raw share makes the whole lot raw again (a mix keeps only the treatments both
-- sides had). An empty container takes the source's record, so pouring never makes milk young. Sealed items (store
-- milk) keep their own fluid without a record; poured out, it is in the heat state. Every rule here works on plain tables; the engine parts are at the end. Treating by hand
-- (the treat menu, the uses it takes) is FluidTreat's; its functions are reached here too.
local Weather = require "TraditionalPreservationCore/Weather"
local Station = require "TraditionalPreservationCore/Station"

local FluidAgeing = {}

-- Save key: never rename it once the mod is out. Inside: kind, age, treated, place, marks, hour.
FluidAgeing.KEY = "tpFluidAge"
FluidAgeing.FRIDGE = "Fridge"
FluidAgeing.FREEZER = "Freezer"
FluidAgeing.FRIDGE_C = 4
-- An item's hours at its kind's scalding heat: { hours, at }, at the hour it was last seen hot (nil once seen cooler).
FluidAgeing.HELD_KEY = "tpHeldHot"
-- Where fluid is when nothing says (no place given, none of its own, no record).
FluidAgeing.DEFAULT_PLACE = Weather.DEFAULT_PLACE
-- Vanilla's Food Spoilage sandbox steps (Food.getFoodRotSpeed: very fast to very slow).
local FOOD_ROT_SPEEDS = { 1.7, 1.4, 1, 0.7, 0.4 }

-- The multiplier vanilla's Food Spoilage setting puts on food's age (Normal 1): a spec's speed for anything that
-- should go off as food does.
function FluidAgeing.foodRotSpeed()
    return FOOD_ROT_SPEEDS[SandboxVars and SandboxVars.FoodRotSpeed] or 1
end
-- A first look on the heat counts as this many hours, so the hold has started.
local FIRST_HOT_LOOK = 1e-6

-- spec = {
--   kind          the ledger kind it ages on; also the record's kind
--   rate          function(celsius): work per hour at that temperature
--   turnHours     hours at the reference until Turned
--   spoilHours    hours at the reference until Spoiled
--   fresh         { fresh name = its turned twin }
--   spoiled       { fresh name = what it ends as }
--   getLedger     function(): the mod's weather ledger
--   optional:
--   scaldHeat     vanilla item heat that brings about the heat state
--   scaldHold     hours at scaldHeat before it does
--   sealed        { item fullType = true }: holds the fluid with no record (store milk)
--   enabled       function(): false while the kind's ageing is off
--   speed         function(): the sandbox's multiplier on the age (FluidAgeing.foodRotSpeed: vanilla's Food Spoilage)
--   states        { name = { fluids = { fresh name = its name in this state }, spoilHours (default the kind's),
--                   of = { treatment names } (default { name }), heat (true: made by heat, not by hand; one at most),
--                   kind, rate (the state's own ledger kind and curve, when it slows in the cold unlike the plain
--                   fluid; the mod's ledger must count that kind) } }
--   treatments, litresPerUse, treatMenu, treatTooltip: treating by hand (FluidTreat)
-- }
-- enabled and speed are asked each time, so the sandbox can change them. register adds spoiledOf, plainOf,
-- stateOfFluid, heatState and isSpoiled to the spec, and name and treatments (sorted) to each state.
local specs = {}
local byFluid = {}
local lowestHeat

-- Notes a fluid the spec claims (claimed: a set, taken only once every check has passed); another kind can't have it.
local function claim(spec, claimed, name)
    local owner = byFluid[name]
    assert(not owner or owner.kind == spec.kind,
        "FluidAgeing.register: " .. spec.kind .. " claims " .. tostring(name) .. ", already " .. tostring(owner and owner.kind))
    claimed[name] = true
end

local function need(spec, field)
    assert(spec[field] ~= nil, "FluidAgeing.register: " .. tostring(spec.kind) .. " has no " .. field)
end

function FluidAgeing.register(spec)
    for _, field in ipairs({ "kind", "rate", "turnHours", "spoilHours", "fresh", "spoiled", "getLedger" }) do
        need(spec, field)
    end
    -- What each of the kind's fluids ends as: a fresh fluid, its twin and its spoiled one all end as the spoiled one.
    local claimed = {}
    spec.spoiledOf, spec.plainOf, spec.isSpoiled = {}, {}, {}
    for fresh, twin in pairs(spec.fresh) do
        local spoiled = spec.spoiled[fresh]
        assert(spoiled, "FluidAgeing.register: " .. spec.kind .. " has no spoiled fluid for " .. fresh)
        claim(spec, claimed, fresh)
        claim(spec, claimed, twin)
        claim(spec, claimed, spoiled)
        spec.spoiledOf[fresh], spec.spoiledOf[twin], spec.spoiledOf[spoiled] = spoiled, spoiled, spoiled
        spec.isSpoiled[spoiled] = true
    end
    -- Each state's treatments, sorted; no two states may have the same ones. A state's fluid ends as its fresh one's
    -- spoiled fluid, and goes back to the fresh one (plainOf) when raw is mixed in.
    local keys = {}
    spec.stateOfFluid, spec.heatState = {}, nil
    for name, state in pairs(spec.states or {}) do
        local of = {}
        for _, treatment in ipairs(state.of or { name }) do table.insert(of, treatment) end
        table.sort(of)
        state.name, state.treatments = name, of
        local key = table.concat(of, "+")
        assert(not keys[key], "FluidAgeing.register: " .. spec.kind .. " has two states done by " .. key)
        keys[key] = true
        if state.heat then
            assert(not spec.heatState, "FluidAgeing.register: " .. spec.kind .. " has two states made by heat")
            assert(#of == 1 and of[1] == name, "FluidAgeing.register: " .. spec.kind .. "'s heat state " .. name .. " is done by hand")
            spec.heatState = state
        end
        for fresh, named in pairs(state.fluids) do
            claim(spec, claimed, named)
            spec.spoiledOf[named], spec.plainOf[named] = spec.spoiled[fresh], fresh
            spec.stateOfFluid[named] = state
        end
    end
    for name in pairs(claimed) do byFluid[name] = spec end
    specs[spec.kind] = spec
    lowestHeat = nil
    for _, each in pairs(specs) do
        if each.scaldHeat and (not lowestHeat or each.scaldHeat < lowestHeat) then lowestHeat = each.scaldHeat end
    end
    return spec
end

-- The state a record is in (a spec.states entry), or nil when untreated or no state has exactly its treatments.
function FluidAgeing.state(record, spec)
    if not record.treated or not spec.states then return nil end
    local count = 0
    for _ in pairs(record.treated) do count = count + 1 end
    for _, state in pairs(spec.states) do
        if #state.treatments == count then
            local all = true
            for _, treatment in ipairs(state.treatments) do all = all and record.treated[treatment] ~= nil end
            if all then return state end
        end
    end
    return nil
end

-- Hours at the reference until the record spoils: its state's, else the kind's.
function FluidAgeing.spoilHours(record, spec)
    local state = FluidAgeing.state(record, spec)
    return state and state.spoilHours or spec.spoilHours
end

-- The ledger kind and rate curve a record ages by: its state's own, else the kind's.
local function agingOf(record, spec)
    local state = FluidAgeing.state(record, spec)
    if state and state.kind then return state.kind, state.rate end
    return spec.kind, spec.rate
end

-- True if nothing will turn the record before it spoils: it is in a state.
local function neverTurns(record)
    return record.treated ~= nil
end

-- True if the record is in the state called name (Dairy's "Scalded").
function FluidAgeing.inState(record, name)
    return record ~= nil and record.treated ~= nil and record.treated[name] == true
end

function FluidAgeing.spec(kind)
    return specs[kind]
end

-- The spec a fluid belongs to, or nil.
function FluidAgeing.specOfFluid(name)
    return byFluid[name]
end

local function isOn(spec)
    return not spec.enabled or spec.enabled()
end

-- Fresh, Turned or Spoiled.
function FluidAgeing.stage(record, spec)
    if record.age >= FluidAgeing.spoilHours(record, spec) then return "Spoiled" end
    if not neverTurns(record) and record.age >= spec.turnHours then return "Turned" end
    return "Fresh"
end

-- Hours at the reference until the next stage, or nil when spoiled.
function FluidAgeing.hoursLeft(record, spec)
    local stage = FluidAgeing.stage(record, spec)
    if stage == "Spoiled" then return nil end
    local spoil = FluidAgeing.spoilHours(record, spec)
    local next = stage == "Fresh" and not neverTurns(record) and math.min(spec.turnHours, spoil) or spoil
    return next - record.age
end

-- A new record, marked on the ledger now: nothing done yet, or in the state called stateName.
function FluidAgeing.newRecord(spec, ledger, now, place, stateName)
    return { kind = spec.kind, age = 0, treated = stateName and { [stateName] = true } or nil, place = place, hour = now,
        marks = Weather.mark({}, ledger, spec.kind) }
end

local function shallowCopy(t)
    if not t then return nil end
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

function FluidAgeing.copy(record)
    return { kind = record.kind, age = record.age, treated = shallowCopy(record.treated),
        markKind = record.markKind, place = record.place, hour = record.hour, marks = shallowCopy(record.marks or {}) }
end

-- Puts a fresh record in the kind's heat state (scalding kills what would sour it), unless it is in a state already.
-- Returns true if it is fresh.
local function scaldIfFresh(record, spec)
    if FluidAgeing.stage(record, spec) ~= "Fresh" then return false end
    if spec.heatState and not record.treated then record.treated = { [spec.heatState.name] = true } end
    return true
end

-- Brings the record up to now: the time since it was last seen counts at the place it was seen in then. place is
-- where it is now, and counts from here on.
function FluidAgeing.advance(record, spec, ledger, now, place)
    -- A state with its own curve counts on its own ledger kind. The marks are of the kind they were taken on
    -- (markKind, nil for the spec's own): when the state has changed since, the stretch is lost (one look's worth).
    local kind, rate = agingOf(record, spec)
    local was, work = record.place, 0
    if was == FluidAgeing.FRIDGE then
        work = math.max(now - (record.hour or now), 0) * rate(FluidAgeing.FRIDGE_C)
    elseif was ~= FluidAgeing.FREEZER and was and (record.markKind or spec.kind) == kind then
        local total = ledger[kind .. was] or 0
        work = total - ((record.marks or {})[was] or total)
    end
    record.marks = Weather.mark(record.marks or {}, ledger, kind)
    record.markKind = kind ~= spec.kind and kind or nil
    record.age = record.age + math.max(work, 0) * (spec.speed and spec.speed() or 1)
    record.hour, record.place = now, place
    return record
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

-- The engine's Fluid for one of the spec's names, looked up once (not at register: fluids may not exist yet).
local function fluidOf(spec, name)
    spec.fluidObjects = spec.fluidObjects or {}
    local fluid = spec.fluidObjects[name]
    if not fluid then
        fluid = Fluid.Get(name)
        spec.fluidObjects[name] = fluid
    end
    return fluid
end

-- The ml of each of the spec's fluids in a container ({ name = litres }), and their total.
function FluidAgeing.amounts(container, spec)
    local found, total = {}, 0
    for name in pairs(spec.spoiledOf) do
        local fluid = fluidOf(spec, name)
        local amount = fluid and container:getSpecificFluidAmount(fluid) or 0
        if amount > 0 then
            found[name] = amount
            total = total + amount
        end
    end
    return found, total
end

-- The registered spec whose fluids the container holds, with what it holds of them (as amounts), or nil.
function FluidAgeing.specIn(container)
    if not container or container:isEmpty() then return nil end
    for _, spec in pairs(specs) do
        local found, total = FluidAgeing.amounts(container, spec)
        if total > 0 then return spec, found, total end
    end
end

-- adjustSpecificFluidAmount sets the amount (dropping the fluid at 0), so a swap is: read, zero, add the other.
local function swap(container, spec, from, to, amount)
    container:adjustSpecificFluidAmount(fluidOf(spec, from), 0)
    container:addFluid(to, amount)
end

-- The name a fluid goes by at a stage: a fresh fluid's twin once turned, its spoiled fluid once spoiled; while fresh,
-- its state's name when in one (state, a spec.states entry), else its plain one.
local function nameAt(spec, stage, name, state)
    if stage == "Spoiled" then return spec.spoiledOf[name] or name end
    local plain = spec.plainOf[name] or name
    if stage == "Turned" then return spec.fresh[plain] or name end
    if state then return state.fluids[plain] or name end
    return plain
end
FluidAgeing.nameAt = nameAt

-- The treatments of the fluid in found ({ name = litres }) if every fresh share of it goes by one state's name: a
-- container seen for the first time with cured blood is cured, with scalded milk scalded. Turned and spoiled shares
-- say nothing either way; a plain or other state's share makes it nil.
local function treatedIn(spec, found)
    local state
    for name in pairs(found) do
        local named = spec.stateOfFluid[name]
        if spec.fresh[name] or (named and state and named ~= state) then
            return nil
        end
        state = named or state
    end
    if not state then return nil end
    local treated = {}
    for _, treatment in ipairs(state.treatments) do treated[treatment] = true end
    return treated
end

-- A new record for the fluid in found ({ name = litres }): in the state its names say, else in the heat state if it
-- scalds.
local function startRecord(spec, found, now, place, scalds)
    local record = FluidAgeing.newRecord(spec, spec.getLedger(), now, place)
    record.treated = treatedIn(spec, found)
    if scalds then scaldIfFresh(record, spec) end
    return record
end

-- Swaps the fluids for the record's stage (found: the container's amounts, when already read and nothing has been
-- swapped since). Returns true if anything changed.
function FluidAgeing.apply(container, record, spec, found)
    local stage = FluidAgeing.stage(record, spec)
    local state = FluidAgeing.state(record, spec)
    local changed = false
    for name, amount in pairs(found or FluidAgeing.amounts(container, spec)) do
        local target = nameAt(spec, stage, name, state)
        if target ~= name then
            swap(container, spec, name, target, amount)
            changed = true
        end
    end
    return changed
end

-- Where an item is for ageing: a powered fridge or freezer, else the weather place of whatever holds it (a player,
-- a world container, the floor, a vehicle). Nil when nothing says.
function FluidAgeing.placeOfItem(item)
    local container = item:getOutermostContainer()
    if container then
        local kind = container:getType()
        if (kind == "fridge" or kind == "freezer") and container:isPowered() then
            return kind == "freezer" and FluidAgeing.FREEZER or FluidAgeing.FRIDGE
        end
        local parent = container:getParent()
        if parent then return Weather.placeOf(parent) end
        local part = container:getVehiclePart()
        if part and part:getVehicle() then return Weather.placeOf(part:getVehicle()) end
    end
    local world = item:getWorldItem()
    if world then return Weather.placeOf(world) end
    return nil
end

local function placeOfOwner(owner)
    if instanceof(owner, "InventoryItem") then return FluidAgeing.placeOfItem(owner) end
    return Weather.placeOf(owner)
end

-- True if the owner is an item as hot as the kind scalds at (on a stove or a fire: an item's heat follows what holds it).
local function scalding(owner, spec)
    return spec.scaldHeat ~= nil and instanceof(owner, "InventoryItem") and owner:getItemHeat() >= spec.scaldHeat
end

-- True if hours at the scalding heat meet the kind's hold.
function FluidAgeing.heldLongEnough(spec, hours)
    return (hours or 0) > 0 and hours >= (spec.scaldHold or 0)
end

-- Counts an owner's hours at the scalding heat: from one look to the next while it stays that hot. Returns them.
local function noteHeat(owner, spec, now)
    local modData = owner:getModData()
    local held = modData[FluidAgeing.HELD_KEY]
    if not scalding(owner, spec) then
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

local function isSealed(owner, spec)
    return spec.sealed and instanceof(owner, "InventoryItem") and spec.sealed[owner:getFullType()] or false
end

-- An owner forgets the age and the heat of fluid it no longer holds.
local function forget(modData)
    modData[FluidAgeing.KEY], modData[FluidAgeing.HELD_KEY] = nil, nil
end

-- look's work. Returns the record and spec, or nil; for a sealed item with no record, nil, nil and its spec.
local function see(owner, now, place)
    local container = owner and owner:getFluidContainer()
    local modData = owner and owner:getModData()
    local spec, found = FluidAgeing.specIn(container)
    if not spec then
        if modData then forget(modData) end
        return nil
    end
    -- The hold is counted even with the kind's ageing off.
    local scalds = FluidAgeing.heldLongEnough(spec, noteHeat(owner, spec, now))
    if not isOn(spec) then return nil end
    local record = modData[FluidAgeing.KEY]
    place = place or placeOfOwner(owner) or (record and record.place) or FluidAgeing.DEFAULT_PLACE
    if not record or record.kind ~= spec.kind then
        if isSealed(owner, spec) then return nil, nil, spec end
        record = startRecord(spec, found, now, place, scalds)
        modData[FluidAgeing.KEY] = record
    else
        FluidAgeing.advance(record, spec, spec.getLedger(), now, place)
        if scalds then scaldIfFresh(record, spec) end
    end
    FluidAgeing.apply(container, record, spec, found)
    return record, spec
end

-- Brings the fluid an owner (an item or a world object) holds up to now, swapping it if it turned. A container
-- with none of a kind's fluid loses its record; a sealed one with no record is left alone. Returns the record and
-- spec, or nil.
function FluidAgeing.look(owner, now, place)
    local record, spec = see(owner, now, place)
    return record, spec
end

-- The age of the fluid leaving an owner, brought up to now: its record, or for a sealed item (store milk) a new
-- one in the heat state, since it was pasteurised. Nil when it holds none of a kind's fluid. Call it before the fluid leaves.
function FluidAgeing.sourceRecord(source, now)
    local record, spec, sealed = see(source, now)
    if record then return FluidAgeing.copy(record), spec end
    if not sealed then return nil end
    return FluidAgeing.newRecord(sealed, sealed.getLedger(), now, placeOfOwner(source) or FluidAgeing.DEFAULT_PLACE,
        sealed.heatState and sealed.heatState.name), sealed
end

-- holder (a modData table, or a cauldron's state) gets fluid of age record: it takes the record if it held none of
-- the kind (hadSome false), else the older age.
function FluidAgeing.receive(holder, record, hadSome, place)
    -- Fluid coming in not in the heat state starts the hold at the heat over.
    local spec = specs[record.kind]
    if not (spec and spec.heatState and FluidAgeing.inState(record, spec.heatState.name)) then
        holder[FluidAgeing.HELD_KEY] = nil
    end
    local into = hadSome and holder[FluidAgeing.KEY]
    if into and into.kind == record.kind then
        FluidAgeing.merge(into, record)
    else
        local copy = FluidAgeing.copy(record)
        copy.place = place or copy.place
        holder[FluidAgeing.KEY] = copy
    end
end

-- Brings what a cauldron's state ({ ml, fluid, parts }, Hearth's) holds up to now at the Hearth's place and renames
-- its fluids for their stage, as a container's are swapped, so turned milk in the cauldron is no longer milk to
-- anything that reads it. Milk that has steamed in the cauldron for the kind's hold (heldHours, Hearth.heldHours) is
-- in the heat state from then on, and renamed so; raw milk poured onto it makes it plain again. An empty cauldron forgets; one holding a kind's fluid with no record (filled before
-- the kind aged, or by a debug command) starts one.
function FluidAgeing.updateCauldron(cauldron, now, place, heldHours)
    local record = cauldron[FluidAgeing.KEY]
    if (cauldron.ml or 0) <= 0 then
        cauldron[FluidAgeing.KEY] = nil
        return nil
    end
    if not record then
        local found = cauldron.parts or { [cauldron.fluid or ""] = cauldron.ml }
        local spec = cauldron.fluid and byFluid[cauldron.fluid]
        if not spec or not isOn(spec) then return nil end
        record = startRecord(spec, found, now, place)
        cauldron[FluidAgeing.KEY] = record
    end
    local spec = specs[record.kind]
    if not spec or not isOn(spec) then return nil end
    FluidAgeing.advance(record, spec, spec.getLedger(), now, place)
    if FluidAgeing.heldLongEnough(spec, heldHours) then scaldIfFresh(record, spec) end
    local stage = FluidAgeing.stage(record, spec)
    local state = FluidAgeing.state(record, spec)
    if cauldron.parts then
        local parts, count, most, changed = {}, 0, nil, false
        for name, part in pairs(cauldron.parts) do
            local renamed = nameAt(spec, stage, name, state)
            if not parts[renamed] then count = count + 1 end
            parts[renamed] = (parts[renamed] or 0) + part
            changed = changed or renamed ~= name
        end
        if not changed then return record, spec end
        for name, part in pairs(parts) do
            if not most or part > parts[most] or (part == parts[most] and name < most) then most = name end
        end
        cauldron.parts = count > 1 and parts or nil
        cauldron.fluid = most
    elseif cauldron.fluid then
        cauldron.fluid = nameAt(spec, stage, cauldron.fluid, state)
    end
    return record, spec
end

-- A copy of the age of what a cauldron's state holds, brought up to now (heldHours as for updateCauldron), or nil.
function FluidAgeing.cauldronRecord(cauldron, now, place, heldHours)
    local record = FluidAgeing.updateCauldron(cauldron, now, place, heldHours)
    return record and FluidAgeing.copy(record) or nil
end

-- Before fluid goes from one owner to another: the target takes the source's age.
function FluidAgeing.pour(source, target, now)
    local record = FluidAgeing.sourceRecord(source, now)
    if not record then return end
    local hadSome = FluidAgeing.look(target, now) ~= nil
    FluidAgeing.receive(target:getModData(), record, hadSome, placeOfOwner(target))
end

-- Forgets the record of an owner holding none of the kind's fluid, so new fluid starts fresh (before milking).
function FluidAgeing.clearIfEmpty(owner)
    local modData = owner and owner:getModData()
    if modData and modData[FluidAgeing.KEY] and not FluidAgeing.specIn(owner:getFluidContainer()) then forget(modData) end
end

-- Looks at an owner's fluid and lets change(record, spec) change its record; when it says it did (true), renames
-- the fluid for the record. Returns true if it did.
local function changeRecord(owner, now, change)
    local record, spec = FluidAgeing.look(owner, now)
    if not record or not change(record, spec) then return false end
    FluidAgeing.apply(owner:getFluidContainer(), record, spec)
    return true
end

-- Puts the fluid an owner holds in the kind's heat state (drawn hot from the Hearth's cauldron): a fresh record, or
-- the one it has. Its fresh fluids are renamed to the state's.
function FluidAgeing.markScalded(owner, now)
    changeRecord(owner, now, scaldIfFresh)
end

-- Adds a treatment to the fluid an owner holds (Add Salt to Blood), while it is fresh, and renames it for its new
-- state. Returns true if it took.
function FluidAgeing.treat(owner, now, treatment)
    return changeRecord(owner, now, function(record, spec)
        if FluidAgeing.stage(record, spec) ~= "Fresh" then return false end
        -- A treatment by hand replaces the heat state: one state at a time.
        if spec.heatState and FluidAgeing.inState(record, spec.heatState.name) then record.treated = nil end
        record.treated = record.treated or {}
        record.treated[treatment] = true
        return true
    end)
end

-- Forgets the treatments of the fluid an owner holds (fresh fluid gathered into it, as vanilla adds blood): a raw
-- share makes the whole lot untreated, as pouring does.
function FluidAgeing.untreat(owner, now)
    changeRecord(owner, now, function(record)
        if not record.treated then return false end
        record.treated = nil
        return true
    end)
end

-- Treating by hand lives in FluidTreat (it needs the character's uses); still reached here, so no mod changes.
for _, name in ipairs({ "litresIn", "treatUses", "treatableSpec", "treatRefusal", "treatBy" }) do
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

FluidAgeing.HEAT_RADIUS = 8

-- Looks at the fluid items in every hot container (a lit stove, fireplace, barbecue or campfire) within HEAT_RADIUS of
-- a square on its level, so milk left on the heat scalds with nobody looking at it.
function FluidAgeing.lookOnHeat(square, now)
    local heat = FluidAgeing.lowestScaldHeat()
    if not heat then return end
    Station.hotContainers(square, FluidAgeing.HEAT_RADIUS, heat, function(container) FluidAgeing.lookIn(container, now) end)
end

return FluidAgeing
