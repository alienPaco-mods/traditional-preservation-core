-- Traditional Preservation core: the Drying Cloth, a Sheet spread on the floor with two Stones on its corners, where
-- things dry by the air of their place (Yeast's cakes, Dairy's kefir grains). It holds LOTS lots; a lot is what one
-- put laid down, of one kind. What a kind is belongs to its mod, which registers it here:
--   DryingCloth.register{ name, label = translation key of its lot ("%1" the count), types = { [fullType] = true } it
--     takes, perLot = most pieces in a lot, hours = hours to dry at full speed, curve = { { celsius, share } },
--     killAbove = optional celsius past which it dies (after KILL_HOURS there), sprite(lot, state) = the overlay for
--     lot 0 to 4 in state "wet", "dry" or "dead" (a tile of the mod's own art, cloth_art.lot_spot),
--     lay(items, now, place) = data kept with the lot (optional), give(lot, inventory, state) = puts what comes off in
--     the inventory (state "wet", "dry" or "dead"), goesOff(lot, now, place, fire, isoObject) = optional: brings what
--     keeps the lot (its own clock in lot.data) up to now and returns nil, or the share of the stretch since the last
--     look (0 to 1) at which it went off; whichever comes first, dry or gone off, wins (yeast cakes going Spent while
--     they lie wet) }
-- Everything that dries by air waits in a shut room's still air (the series' rule, as Dairy's kefir has always
-- done): a lot there dries nothing until a window is opened. Frost stops it as the curve says. Time keeps counting
-- while the cloth is unloaded: each lot holds a FluidAgeing age on the cloth's ledger, brought up to now at every
-- look. The lots are the cloth's own modData (KEY); a cloth with any lot on it can't be picked up.
local Weather = require "TraditionalPreservationCore/Weather"
local Fire = require "TraditionalPreservationCore/Fire"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Tiles = require "TraditionalPreservationCore/Tiles"

local DryingCloth = {}

DryingCloth.LOTS = 5
-- Save key on the cloth: never rename it once the mod is out. { lots = { [1..LOTS] = lot or false } }; a lot is
-- { kind, count, data, dry = a FluidAgeing age (hours at full drying), heat = one (hours past killAbove), dead,
-- spoiled (dead because it went off before it dried) }.
DryingCloth.KEY = "tpcCloth"
DryingCloth.LEDGER_KEY = "TraditionalPreservationCoreCloth"
DryingCloth.STILL_AIR_PLACE = "Sheltered"
DryingCloth.KILL_HOURS = 1
DryingCloth.SPRITES = Tiles.CLOTHS

local kinds, kindOrder = {}, {}
local processes = {}

local function dryProcess(name) return "cloth" .. name end
local function heatProcess(name) return "clothHeat" .. name end

function DryingCloth.register(kind)
    assert(kind.name and kind.types and kind.hours and kind.curve and kind.sprite and kind.give, "DryingCloth.register: a kind needs name, types, hours, curve, sprite and give")
    if not kinds[kind.name] then table.insert(kindOrder, kind.name) end
    kinds[kind.name] = kind
    kind.perLot = kind.perLot or 1
    kind.drying = { process = dryProcess(kind.name), rate = function(celsius) return Weather.curve(kind.curve, celsius) end }
    processes[kind.drying.process] = kind.drying.rate
    if kind.killAbove then
        kind.heating = { process = heatProcess(kind.name), rate = function(celsius) return celsius > kind.killAbove and 1 or 0 end }
        processes[kind.heating.process] = kind.heating.rate
    end
    return kind
end

function DryingCloth.kind(name) return kinds[name] end

-- The registered kinds, in the order their mods loaded.
function DryingCloth.kinds()
    local list = {}
    for _, name in ipairs(kindOrder) do table.insert(list, kinds[name]) end
    return list
end

-- The kind that takes an item, or nil.
function DryingCloth.kindOf(fullType)
    for _, name in ipairs(kindOrder) do
        if kinds[name].types[fullType] then return kinds[name] end
    end
end

function DryingCloth.newLedger(now)
    return Weather.newLedger(now, processes)
end

-- The ledger in global ModData, every kind's totals in it (a kind added since the save starts at nothing).
function DryingCloth.getLedger()
    return Weather.fillLedger(Weather.getLedger(DryingCloth.LEDGER_KEY, DryingCloth.newLedger), processes)
end

function DryingCloth.recordWeather(now, temperature)
    Weather.advance(DryingCloth.getLedger(), now, temperature, processes)
end

local CLOTHS = {}
for _, sprite in ipairs(Tiles.CLOTHS) do CLOTHS[sprite] = true end

function DryingCloth.isCloth(isoObject)
    local sprite = isoObject and isoObject.getSprite and isoObject:getSprite()
    return sprite ~= nil and CLOTHS[sprite:getName()] == true
end

-- The cloth's record, made on first use.
function DryingCloth.recordOf(isoObject)
    local modData = isoObject:getModData()
    local record = modData[DryingCloth.KEY]
    if not record then
        record = { lots = {} }
        for i = 1, DryingCloth.LOTS do record.lots[i] = false end
        modData[DryingCloth.KEY] = record
    end
    return record
end

-- Lot states, from its ages.
function DryingCloth.state(lot)
    if lot.dead then return "dead" end
    return lot.dry.age >= kinds[lot.kind].hours and "dry" or "wet"
end

function DryingCloth.isEmpty(record)
    for _, lot in ipairs(record.lots) do
        if lot then return false end
    end
    return true
end

function DryingCloth.freeLots(record)
    local free = 0
    for _, lot in ipairs(record.lots) do
        if not lot then free = free + 1 end
    end
    return free
end

-- Brings one lot up to now at place (where the cloth is now). A stretch in a shut room's still air dries nothing; a
-- stretch too hot for its kind may kill it, and a kind that goes off may go off first.
local function advanceLot(lot, ledger, now, place, fire, isoObject)
    local kind = kinds[lot.kind]
    if not kind or lot.dead then return end
    local was, age = lot.dry.place, lot.dry.age
    FluidAgeing.advance(lot.dry, kind.drying, ledger, now, place)
    if was == DryingCloth.STILL_AIR_PLACE then lot.dry.age = age end
    if isoObject then FluidAgeing.noteFire(lot.dry, fire, isoObject, now) end
    if kind.goesOff and age < kind.hours then
        local offShare = kind.goesOff(lot, now, place, fire, isoObject)
        local dryShare = lot.dry.age >= kind.hours and (kind.hours - age) / (lot.dry.age - age) or nil
        if offShare and (not dryShare or offShare < dryShare) then
            lot.dead, lot.spoiled = true, true
            return
        end
    end
    if kind.heating and lot.heat and DryingCloth.state(lot) ~= "dry" then
        FluidAgeing.advance(lot.heat, kind.heating, ledger, now, place)
        if lot.heat.age >= DryingCloth.KILL_HOURS then lot.dead = true end
    end
end

-- Brings every lot on a cloth up to now. place defaults to the cloth's own (by a fire, banked embers or a Weather
-- place). Returns the record and the place.
function DryingCloth.update(isoObject, now, place, ledger)
    now = now or getGameTime():getWorldAgeHours()
    ledger = ledger or DryingCloth.getLedger()
    local fire
    if not place then place, fire = Fire.placeOf(isoObject) end
    local record = DryingCloth.recordOf(isoObject)
    for _, lot in ipairs(record.lots) do
        if lot then advanceLot(lot, ledger, now, place, fire, isoObject) end
    end
    record.place = place
    return record, place
end

-- Lays items (all of one kind, at most perLot) on the first free lot. Returns the lot's index, or nil.
function DryingCloth.lay(isoObject, items, now, place, ledger)
    local kind = items[1] and DryingCloth.kindOf(items[1]:getFullType())
    if not kind then return nil end
    local record
    record, place = DryingCloth.update(isoObject, now, place, ledger)
    now = now or getGameTime():getWorldAgeHours()
    ledger = ledger or DryingCloth.getLedger()
    for i, lot in ipairs(record.lots) do
        if not lot then
            record.lots[i] = {
                kind = kind.name, count = #items, data = kind.lay and kind.lay(items, now, place) or nil,
                dry = FluidAgeing.newFluidAge(kind.drying, ledger, now, place),
                heat = kind.heating and FluidAgeing.newFluidAge(kind.heating, ledger, now, place) or nil,
            }
            return i
        end
    end
    return nil
end

-- Takes lot i off into the inventory, as its kind gives it. Returns its state, or nil if there was none.
function DryingCloth.take(isoObject, i, inventory)
    local record = DryingCloth.recordOf(isoObject)
    local lot = record.lots[i]
    if not lot then return nil end
    local state = DryingCloth.state(lot)
    local kind = kinds[lot.kind]
    if kind then kind.give(lot, inventory, state) end
    record.lots[i] = false
    return state
end

-- How a lot is doing at placeC (place: where the cloth is): { state, progress (0 to 1), rate, hoursLeft (nil: it
-- waits: a shut room or frozen), waits ("still" or "frozen") }.
function DryingCloth.status(lot, placeC, place)
    local kind = kinds[lot.kind]
    local state = DryingCloth.state(lot)
    local progress = math.min(lot.dry.age / kind.hours, 1)
    local status = { state = state, progress = progress, kind = kind, spoiled = lot.spoiled }
    if state ~= "wet" then return status end
    local rate = place == DryingCloth.STILL_AIR_PLACE and 0 or kind.drying.rate(placeC)
    status.rate = rate
    if rate > 0 then
        status.hoursLeft = (kind.hours - lot.dry.age) / rate
    else
        status.waits = place == DryingCloth.STILL_AIR_PLACE and "still" or "frozen"
    end
    status.tooHot = kind.killAbove ~= nil and placeC > kind.killAbove
    return status
end

-- The overlay sprites for a cloth's lots, in lot order (each kind draws its own; cloth_art.lot_spot).
function DryingCloth.lotSprites(record)
    local names = {}
    for i, lot in ipairs(record.lots) do
        local kind = lot and kinds[lot.kind]
        if kind then table.insert(names, kind.sprite(i - 1, DryingCloth.state(lot))) end
    end
    return names
end

-- A key that changes when what the cloth shows does.
function DryingCloth.lookKey(record)
    local parts = {}
    for i, lot in ipairs(record.lots) do parts[i] = lot and (lot.kind .. DryingCloth.state(lot)) or "-" end
    return table.concat(parts, ",")
end

return DryingCloth
