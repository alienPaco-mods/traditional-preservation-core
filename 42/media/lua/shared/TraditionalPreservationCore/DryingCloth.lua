-- Traditional Preservation core: the Drying Cloth, a Sheet spread on the floor with two Stones on its corners, where
-- things dry by the air of their place (Yeast's cakes, Dairy's kefir grains). It has ROOM room, as the Drying Frame
-- has its weight: each piece takes its kind's room, and a lot is what one lay put down, of one kind, with its own
-- clock (any number of lots while there is room). What a kind is belongs to its mod, which registers it here:
--   DryingCloth.register{ name, title = translation key of its name, types = { [fullType] = true } it takes, room =
--     the cloth's room one piece takes (of ROOM), perLot = optional most pieces in one lot (a kind whose lay data
--     is one piece's, as yeast cakes' age: 1; none, any number), hours = hours to dry at full speed, curve = { { celsius, share } },
--     killAbove = optional celsius past which it dies (after KILL_HOURS there), sprite(spot, state) = the overlay for
--     the cloth's spot 0 to SPOTS - 1 in state "wet", "dry" or "dead" (a tile of the mod's own art, cloth_art.lot_spot;
--     a spot shows the lot covering most of its share of the room),
--     lay(items, now, place) = data kept with the lot (optional), give(lot, inventory, state) = puts what comes off in
--     the inventory (state "wet", "dry" or "dead"), goesOff(lot, now, place, fire, isoObject) = optional: brings what
--     keeps the lot (its own clock in lot.data) up to now and returns nil, or the share of the stretch since the last
--     look (0 to 1) at which it went off; whichever comes first, dry or gone off, wins (yeast cakes going Spent while
--     they lie wet), pattern = optional texture its lots' cells are drawn in on Info (TPCell_<Name>.png of the mod's
--     own, tools/cell_patterns.py) }
-- Everything that dries by air waits in a shut room's still air (the series' rule, as Dairy's kefir has always
-- done): a lot there dries nothing until a window is opened. Frost stops it as the curve says. Time keeps counting
-- while the cloth is unloaded: each lot holds a FluidAgeing age on the cloth's ledger, brought up to now at every
-- look. The lots are the cloth's own modData (KEY); a cloth with any lot on it can't be picked up.
local Weather = require "TraditionalPreservationCore/Weather"
local Fire = require "TraditionalPreservationCore/Fire"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"
local Tiles = require "TraditionalPreservationCore/Tiles"

local DryingCloth = {}

DryingCloth.ROOM = 50     -- a batch of yeast cakes takes 10, a kefir grain 1: five batches or fifty grains (user)
DryingCloth.SPOTS = 5     -- the art's spots, each a fifth of the room
-- Save key on the cloth: never rename it once the mod is out. { lots = { lot, ... } in the order laid, nextId }; a lot
-- is { id, kind, count, data, dry = a FluidAgeing age (hours at full drying), heat = one (hours past killAbove), dead,
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
    assert(kind.name and kind.types and kind.room and kind.hours and kind.curve and kind.sprite and kind.give, "DryingCloth.register: a kind needs name, types, room, hours, curve, sprite and give")
    if not kinds[kind.name] then table.insert(kindOrder, kind.name) end
    kinds[kind.name] = kind
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

-- Spread from a right-click on the floor with its kit in the inventory, picked up the same way once empty, the kit
-- back (user, session 77: the build menu is for what is built of wood): a Sheet and two Stones. Not a moveable.
DryingCloth.KIT = { { "Base.Sheet", 1 }, { "Base.Stone2", 2 } }

-- Why a cloth can't be spread on a square now, or nil. free: nothing on the square stands in its way (a floor, no
-- furniture or station, not in front of a door); hasKit: the kit in the inventory.
function DryingCloth.spreadRefusal(free, hasKit)
    if not free then return "NoRoom" end
    if not hasKit then return "NoKit" end
    return nil
end

-- Why a cloth can't be picked up now, or nil: anything still on it.
function DryingCloth.pickUpRefusal(record)
    if not DryingCloth.isEmpty(record) then return "NotEmpty" end
    return nil
end

-- The cloth's sprite for a character's facing: lying along the way they look.
function DryingCloth.spriteFacing(northSouth)
    return DryingCloth.SPRITES[northSouth and 1 or 2]
end

-- Spreads a cloth on square (its tile's object, as vanilla puts a tile down). Returns it.
function DryingCloth.spread(square, spriteName)
    local cloth = IsoObject.new(getCell(), square, getSprite(spriteName))
    square:AddTileObject(cloth)
    return cloth
end

function DryingCloth.isCloth(isoObject)
    local sprite = isoObject and isoObject.getSprite and isoObject:getSprite()
    return sprite ~= nil and CLOTHS[sprite:getName()] == true
end

-- The cloth's record, made on first use. A cloth from before the room (five fixed lots, false when free) is packed
-- into the list.
function DryingCloth.recordOf(isoObject)
    local modData = isoObject:getModData()
    local record = modData[DryingCloth.KEY]
    if not record then
        record = { lots = {}, nextId = 1 }
        modData[DryingCloth.KEY] = record
    end
    if not record.nextId then
        local lots = {}
        for i = 1, DryingCloth.SPOTS do
            if record.lots[i] then table.insert(lots, record.lots[i]) end
        end
        for i, lot in ipairs(lots) do lot.id = i end
        record.lots, record.nextId = lots, #lots + 1
    end
    return record
end

-- Lot states, from its ages.
function DryingCloth.state(lot)
    if lot.dead then return "dead" end
    return lot.dry.age >= kinds[lot.kind].hours and "dry" or "wet"
end

function DryingCloth.isEmpty(record)
    return #record.lots == 0
end

-- The room a lot takes.
function DryingCloth.lotRoom(lot)
    local kind = kinds[lot.kind]
    return lot.count * (kind and kind.room or 1)
end

function DryingCloth.roomUsed(record)
    local used = 0
    for _, lot in ipairs(record.lots) do used = used + DryingCloth.lotRoom(lot) end
    return used
end

-- How many pieces of a kind still fit.
function DryingCloth.fits(record, kind)
    return math.max(math.floor((DryingCloth.ROOM - DryingCloth.roomUsed(record)) / kind.room), 0)
end

-- Pieces of one kind in lots: perLot each, or one lot.
function DryingCloth.lotsOf(kind, pieces)
    local per, lots = kind.perLot or math.max(#pieces, 1), {}
    for i, item in ipairs(pieces) do
        local n = math.floor((i - 1) / per) + 1
        lots[n] = lots[n] or {}
        table.insert(lots[n], item)
    end
    return lots
end

-- A lot by its id, and its place in the list.
function DryingCloth.lotById(record, id)
    for i, lot in ipairs(record.lots) do
        if lot.id == id then return lot, i end
    end
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
    for _, lot in ipairs(record.lots) do advanceLot(lot, ledger, now, place, fire, isoObject) end
    record.place = place
    return record, place
end

-- Lays items (all of one kind) as one lot, as many as there is room for (at most the kind's perLot), the first first. Returns the lot's id and
-- how many went on, or nil.
function DryingCloth.lay(isoObject, items, now, place, ledger)
    local kind = items[1] and DryingCloth.kindOf(items[1]:getFullType())
    if not kind then return nil end
    local record
    record, place = DryingCloth.update(isoObject, now, place, ledger)
    local count = math.min(#items, DryingCloth.fits(record, kind), kind.perLot or #items)
    if count == 0 then return nil end
    local laid = {}
    for i = 1, count do laid[i] = items[i] end
    now = now or getGameTime():getWorldAgeHours()
    ledger = ledger or DryingCloth.getLedger()
    local id = record.nextId
    record.nextId = id + 1
    table.insert(record.lots, {
        id = id, kind = kind.name, count = count, data = kind.lay and kind.lay(laid, now, place) or nil,
        dry = FluidAgeing.newFluidAge(kind.drying, ledger, now, place),
        heat = kind.heating and FluidAgeing.newFluidAge(kind.heating, ledger, now, place) or nil,
    })
    return id, count
end

-- Takes the lot with this id off into the inventory, as its kind gives it. Returns its state, or nil if there was
-- none.
function DryingCloth.take(isoObject, id, inventory)
    local record = DryingCloth.recordOf(isoObject)
    local lot, i = DryingCloth.lotById(record, id)
    if not lot then return nil end
    local state = DryingCloth.state(lot)
    local kind = kinds[lot.kind]
    if kind then kind.give(lot, inventory, state) end
    table.remove(record.lots, i)
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

-- The lot each spot shows, or false: the lots fill the room in the order laid, and a spot shows the lot covering most
-- of its share (the first on a tie), when anything lies there.
function DryingCloth.spotLots(record)
    local spots, span = {}, DryingCloth.ROOM / DryingCloth.SPOTS
    for spot = 1, DryingCloth.SPOTS do
        local from, to = (spot - 1) * span, spot * span
        local start, best, most = 0, false, 0
        for _, lot in ipairs(record.lots) do
            local finish = start + DryingCloth.lotRoom(lot)
            local cover = math.min(finish, to) - math.max(start, from)
            if cover > most and kinds[lot.kind] then best, most = lot, cover end
            start = finish
        end
        spots[spot] = best
    end
    return spots
end

-- The overlay sprites for a cloth's spots (each kind draws its own; cloth_art.lot_spot).
function DryingCloth.lotSprites(record)
    local names = {}
    for i, lot in ipairs(DryingCloth.spotLots(record)) do
        if lot then table.insert(names, kinds[lot.kind].sprite(i - 1, DryingCloth.state(lot))) end
    end
    return names
end

-- A key that changes when what the cloth shows does.
function DryingCloth.lookKey(record)
    local parts = {}
    for i, lot in ipairs(DryingCloth.spotLots(record)) do parts[i] = lot and (lot.kind .. DryingCloth.state(lot)) or "-" end
    return table.concat(parts, ",")
end

return DryingCloth
