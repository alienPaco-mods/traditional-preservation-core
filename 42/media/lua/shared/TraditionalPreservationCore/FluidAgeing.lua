-- Traditional Preservation core: fluids that go off. Vanilla fluids never age, so a mod registers a kind of fluid
-- (Dairy: milk) with its fresh fluids, the twin each turns into, the fluid each ends as and a rate curve, and the
-- core keeps an age record on whatever holds it: an item's modData or a world object's, under KEY. The age is in
-- hours at the curve's reference (rate 1), counted on the mod's weather ledger by place, like a station's work, so
-- an item left alone catches up when it is next looked at, at the place it was seen in last. A powered fridge
-- counts at FRIDGE_C by the clock, a powered freezer not at all.
--
-- Stages: Fresh, then Turned (each fresh fluid swapped for its twin: soured milk) at turnHours, then Spoiled (each
-- fresh fluid and its twin swapped for the fresh one's spoiled fluid: rotten milk) at spoilHours. A steamed record never turns: scalding kills what
-- would sour it, so it stays fresh until spoilHours and then spoils.
--
-- Pouring: the older age wins, and a raw share makes the whole lot raw again. An empty container takes the source's
-- record, so pouring never makes milk young. Sealed items (store milk) keep their own fluid without a record; poured
-- out, it counts as steamed. Every rule here works on plain tables; the engine parts are at the end.
local Weather = require "TraditionalPreservationCore/Weather"

local FluidAgeing = {}

-- Save key: never rename it once the mod is out. Inside: kind, age, steamed, place, marks, hour.
FluidAgeing.KEY = "tpFluidAge"
FluidAgeing.FRIDGE = "Fridge"
FluidAgeing.FREEZER = "Freezer"
FluidAgeing.FRIDGE_C = 4

-- spec = { kind, rate(celsius), turnHours, spoilHours, fresh = { name = twin }, spoiled = { fresh name = spoiled },
--          sealed = { fullType = true }, getLedger(), enabled(), speed() }. enabled and speed are asked each time, so
--          the sandbox can change them.
local specs = {}
local byFluid = {}

function FluidAgeing.register(spec)
    specs[spec.kind] = spec
    -- What each of the kind's fluids ends as: a fresh fluid, its twin and its spoiled one all end as the spoiled one.
    spec.spoiledOf = {}
    for fresh, twin in pairs(spec.fresh) do
        local spoiled = spec.spoiled[fresh]
        byFluid[fresh], byFluid[twin], byFluid[spoiled] = spec, spec, spec
        spec.spoiledOf[fresh], spec.spoiledOf[twin], spec.spoiledOf[spoiled] = spoiled, spoiled, spoiled
    end
    return spec
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
    if record.age >= spec.spoilHours then return "Spoiled" end
    if not record.steamed and record.age >= spec.turnHours then return "Turned" end
    return "Fresh"
end

-- Hours at the reference until the next stage, or nil when spoiled.
function FluidAgeing.hoursLeft(record, spec)
    local stage = FluidAgeing.stage(record, spec)
    if stage == "Spoiled" then return nil end
    local next = stage == "Fresh" and not record.steamed and spec.turnHours or spec.spoilHours
    return next - record.age
end

-- A new record: nothing done yet, marked on the ledger now.
function FluidAgeing.newRecord(spec, ledger, now, place, steamed)
    return { kind = spec.kind, age = 0, steamed = steamed or nil, place = place, hour = now,
        marks = Weather.mark({}, ledger, spec.kind) }
end

function FluidAgeing.copy(record)
    local marks = {}
    for k, v in pairs(record.marks or {}) do marks[k] = v end
    return { kind = record.kind, age = record.age, steamed = record.steamed, place = record.place, hour = record.hour,
        marks = marks }
end

-- Brings the record up to now: the time since it was last seen counts at the place it was seen in then. place is
-- where it is now, and counts from here on.
function FluidAgeing.advance(record, spec, ledger, now, place)
    local was, work = record.place, 0
    if was == FluidAgeing.FRIDGE then
        work = math.max(now - (record.hour or now), 0) * spec.rate(FluidAgeing.FRIDGE_C)
    elseif was ~= FluidAgeing.FREEZER and was then
        local total = ledger[spec.kind .. was] or 0
        work = total - ((record.marks or {})[was] or total)
    end
    record.marks = Weather.mark(record.marks or {}, ledger, spec.kind)
    record.age = record.age + math.max(work, 0) * (spec.speed and spec.speed() or 1)
    record.hour, record.place = now, place
    return record
end

-- into takes from: the older age, and steamed only while both were.
function FluidAgeing.merge(into, from)
    into.age = math.max(into.age, from.age)
    into.steamed = (into.steamed and from.steamed) or nil
    return into
end

-- Engine parts

-- The ml of each of the spec's fluids in a container ({ name = litres }), and their total.
function FluidAgeing.amounts(container, spec)
    local found, total = {}, 0
    local function add(name)
        local fluid = Fluid.Get(name)
        local amount = fluid and container:getSpecificFluidAmount(fluid) or 0
        if amount > 0 then
            found[name] = amount
            total = total + amount
        end
    end
    for name in pairs(spec.spoiledOf) do add(name) end
    return found, total
end

-- The registered spec whose fluids the container holds, or nil.
function FluidAgeing.specIn(container)
    if not container or container:isEmpty() then return nil end
    for _, spec in pairs(specs) do
        local _, total = FluidAgeing.amounts(container, spec)
        if total > 0 then return spec end
    end
end

-- adjustSpecificFluidAmount sets the amount (dropping the fluid at 0), so a swap is: read, zero, add the other.
local function swap(container, from, to, amount)
    container:adjustSpecificFluidAmount(Fluid.Get(from), 0)
    container:addFluid(to, amount)
end

-- The name a fluid goes by at a stage: a fresh fluid's twin once turned, its spoiled fluid once spoiled.
local function nameAt(spec, stage, name)
    if stage == "Spoiled" then return spec.spoiledOf[name] or name end
    if stage == "Turned" and spec.fresh[name] then return spec.fresh[name] end
    return name
end

-- Swaps the fluids for the record's stage. Returns true if anything changed.
function FluidAgeing.apply(container, record, spec)
    local stage = FluidAgeing.stage(record, spec)
    if stage == "Fresh" then return false end
    local changed = false
    for name, amount in pairs(FluidAgeing.amounts(container, spec)) do
        local target = nameAt(spec, stage, name)
        if target ~= name then
            swap(container, name, target, amount)
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

local function isSealed(owner, spec)
    return spec.sealed and instanceof(owner, "InventoryItem") and spec.sealed[owner:getFullType()] or false
end

-- Brings the fluid an owner (an item or a world object) holds up to now, swapping it if it turned. A container
-- with none of a kind's fluid loses its record; a sealed one with no record is left alone. Returns the record and
-- spec, or nil.
function FluidAgeing.look(owner, now, place)
    local container = owner and owner:getFluidContainer()
    local modData = owner and owner:getModData()
    local spec = FluidAgeing.specIn(container)
    if not spec or not isOn(spec) then
        if modData and modData[FluidAgeing.KEY] and not spec then modData[FluidAgeing.KEY] = nil end
        return nil
    end
    local record = modData[FluidAgeing.KEY]
    place = place or placeOfOwner(owner) or (record and record.place) or "Sheltered"
    local ledger = spec.getLedger()
    if not record or record.kind ~= spec.kind then
        if isSealed(owner, spec) then return nil end
        record = FluidAgeing.newRecord(spec, ledger, now, place)
        modData[FluidAgeing.KEY] = record
        return record, spec
    end
    FluidAgeing.advance(record, spec, ledger, now, place)
    FluidAgeing.apply(container, record, spec)
    return record, spec
end

-- The age of the fluid leaving an owner, brought up to now: its record, or for a sealed item (store milk) a new
-- steamed one, since it was pasteurised. Nil when it holds none of a kind's fluid. Call it before the fluid leaves.
function FluidAgeing.sourceRecord(source, now)
    local record, spec = FluidAgeing.look(source, now)
    if record then return FluidAgeing.copy(record), spec end
    spec = FluidAgeing.specIn(source and source:getFluidContainer())
    if not spec or not isOn(spec) or not isSealed(source, spec) then return nil end
    return FluidAgeing.newRecord(spec, spec.getLedger(), now, placeOfOwner(source) or "Sheltered", true), spec
end

-- holder (a modData table, or a copper's state) gets fluid of age record: it takes the record if it held none of
-- the kind (hadSome false), else the older age.
function FluidAgeing.receive(holder, record, hadSome, place)
    local into = hadSome and holder[FluidAgeing.KEY]
    if into and into.kind == record.kind then
        FluidAgeing.merge(into, record)
    else
        local copy = FluidAgeing.copy(record)
        copy.place = place or copy.place
        holder[FluidAgeing.KEY] = copy
    end
end

-- Brings what a copper's state ({ ml, fluid, parts }, Hearth's) holds up to now at the Hearth's place and renames
-- its fluids for their stage, as a container's are swapped, so turned milk in the copper is no longer milk to
-- anything that reads it. Milk in a steaming copper (hot) is scalded: steamed from then on. An empty copper forgets.
function FluidAgeing.updateCopper(copper, now, place, hot)
    local record = copper[FluidAgeing.KEY]
    if (copper.ml or 0) <= 0 then
        copper[FluidAgeing.KEY] = nil
        return nil
    end
    local spec = record and specs[record.kind]
    if not spec or not isOn(spec) then return nil end
    FluidAgeing.advance(record, spec, spec.getLedger(), now, place)
    local stage = FluidAgeing.stage(record, spec)
    if hot and stage == "Fresh" then record.steamed = true end
    if stage == "Fresh" then return record, spec end
    if copper.parts then
        local parts, count, most = {}, 0, nil
        for name, part in pairs(copper.parts) do
            local renamed = nameAt(spec, stage, name)
            if not parts[renamed] then count = count + 1 end
            parts[renamed] = (parts[renamed] or 0) + part
        end
        for name, part in pairs(parts) do
            if not most or part > parts[most] or (part == parts[most] and name < most) then most = name end
        end
        copper.parts = count > 1 and parts or nil
        copper.fluid = most
    elseif copper.fluid then
        copper.fluid = nameAt(spec, stage, copper.fluid)
    end
    return record, spec
end

-- A copy of the age of what a copper's state holds, brought up to now, or nil.
function FluidAgeing.copperRecord(copper, now, place)
    local record = FluidAgeing.updateCopper(copper, now, place)
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
    if modData and modData[FluidAgeing.KEY] and not FluidAgeing.specIn(owner:getFluidContainer()) then
        modData[FluidAgeing.KEY] = nil
    end
end

-- Marks the fluid an owner holds as steamed (drawn hot from the Hearth's copper): a fresh record, or the one it has.
function FluidAgeing.markSteamed(owner, now)
    local record = FluidAgeing.look(owner, now)
    if record and FluidAgeing.stage(record, FluidAgeing.spec(record.kind)) == "Fresh" then record.steamed = true end
end

local function hasFluid(item)
    return item:getFluidContainer() ~= nil
end

-- Brings every fluid item in an item container (and the bags inside it) up to now.
function FluidAgeing.lookIn(container, now)
    local items = container and container:getAllEvalRecurse(hasFluid)
    for i = 0, items and items:size() - 1 or -1 do FluidAgeing.look(items:get(i), now) end
end

return FluidAgeing
