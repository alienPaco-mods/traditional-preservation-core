-- Traditional Preservation core: fluid that changes in an item, as the cauldron's does (CauldronFluid.turnsHot,
-- goesOff), and fluid that burns there. A pot or a saucepan on any stove or fire: a mod names what turns, what goes
-- off and what burns, and the core keeps a record in the item's modData under KEY. A fluid only changes while it is
-- all the item holds.
-- turnsHot(from, to, hours): from, kept steaming (the item's heat at CauldronFluid.HOT_C or more) for hours in all,
--   becomes to. The hours start over when more pieces go in (putPieces).
-- goesOff(from, to): from becomes to at the itemFluid's offAt, unless it turned first. Pieces put in set it by the
--   oldest (putPieces); counted by the clock, at any place.
-- burns(fluid, hours, mapper): fluid kept steaming hours more burns: the item is emptied and swapped where it lies for
--   mapper[its full type], flagged burnt, its condition kept. An item the mapper doesn't name never burns.
-- staysIn(name): the item can't be poured from or into, or drunk from, while it holds name (vanilla's
--   canPlayerEmpty, as a sealed carton's): raw butter keeps its clock in its pot, as it stays in the cauldron. It can
--   always be thrown away (ItemFluidUI's Empty, TPEmptyFluid).
-- Hot hours are counted from one look to the next while the item stays hot (as OnHeat's minutes): every minute on
-- the heat near a player (ItemFluidWorld), so a pot left on a stove nobody is near counts nothing.
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local Action = require "TraditionalPreservationCore/Action"

local ItemFluid = {}

-- Save key: never rename it once the mod is out. Inside: hot (hours), at (the hour last seen hot), offAt (an hour).
ItemFluid.KEY = "tpItemFluid"
ItemFluid.HOT_C = CauldronFluid.HOT_C
-- Only a gap of a look or two counts as hot: an item off the heat isn't looked at each minute.
ItemFluid.MAX_GAP_HOURS = 2 / 60
-- A container holding a hair more than its one fluid (float error) still holds only it.
ItemFluid.AMOUNT_TOLERANCE_L = CauldronFluid.AMOUNT_TOLERANCE_L

local TURNS, OFF, BURNS, STAYS = {}, {}, {}, {}
local watchesHeat = false   -- anything turns or burns: the stoves near players are looked at

function ItemFluid.turnsHot(from, to, hours)
    assert(type(from) == "string" and type(to) == "string", "ItemFluid.turnsHot: from and to must be fluid names")
    assert(TURNS[from] == nil, "ItemFluid.turnsHot: fluid " .. from .. " already turns")
    assert(type(hours) == "number" and hours > 0, "ItemFluid.turnsHot: " .. from .. " needs hours")
    TURNS[from] = { to = to, hours = hours }
    watchesHeat = true
end

function ItemFluid.goesOff(from, to)
    assert(type(from) == "string" and type(to) == "string", "ItemFluid.goesOff: from and to must be fluid names")
    assert(OFF[from] == nil, "ItemFluid.goesOff: fluid " .. from .. " already goes off")
    OFF[from] = to
end

function ItemFluid.burns(fluid, hours, mapper)
    assert(type(fluid) == "string", "ItemFluid.burns: fluid must be a fluid name")
    assert(BURNS[fluid] == nil, "ItemFluid.burns: fluid " .. fluid .. " already burns")
    assert(type(hours) == "number" and hours > 0, "ItemFluid.burns: " .. fluid .. " needs hours")
    assert(type(mapper) == "table", "ItemFluid.burns: " .. fluid .. " needs a mapper { vessel = burnt item }")
    BURNS[fluid] = { hours = hours, mapper = mapper }
    watchesHeat = true
end

function ItemFluid.staysIn(name)
    assert(type(name) == "string", "ItemFluid.staysIn: name must be a fluid name")
    STAYS[name] = true
end

function ItemFluid.isNamed(fluid)
    return TURNS[fluid] ~= nil or OFF[fluid] ~= nil or BURNS[fluid] ~= nil or STAYS[fluid] ~= nil
end

-- Whether an item holding fluid (nil: none, or a mixture) may be poured, emptied and drunk from.
function ItemFluid.canEmpty(fluid)
    return not (fluid and STAYS[fluid])
end

-- The burnt item a vessel holding fluid becomes, or nil if it never burns.
function ItemFluid.burntItem(fluid, vesselType)
    local burn = BURNS[fluid]
    return burn and burn.mapper[vesselType]
end

-- The rules, on a plain itemFluid table

-- Pieces going in: the hot hours start over, and the lot goes off when its oldest piece would have. hoursLeft has,
-- for each piece, the hours until it would have gone off.
function ItemFluid.putPieces(itemFluid, hoursLeft, now)
    itemFluid.steamedHours, itemFluid.at = 0, nil
    for _, left in ipairs(hoursLeft) do
        local at = now + math.max(left, 0)
        itemFluid.offAt = math.min(itemFluid.offAt or at, at)
    end
end

-- Brings an itemFluid table up to now for the fluid it holds (fluid, all the item holds), seen hot or not. Returns what the
-- fluid is now (fluid when unchanged), and true when it has burnt (only for a vessel burns' mapper names).
function ItemFluid.advance(itemFluid, fluid, now, hot, vesselType)
    if itemFluid.offAt and itemFluid.offAt <= now and OFF[fluid] then
        itemFluid.steamedHours, itemFluid.at, itemFluid.offAt = 0, nil, nil
        return OFF[fluid], false
    end
    if not hot then
        itemFluid.at = nil
        return fluid, false
    end
    local gap = itemFluid.at and now - itemFluid.at
    if gap and gap > 0 and gap <= ItemFluid.MAX_GAP_HOURS then itemFluid.steamedHours = (itemFluid.steamedHours or 0) + gap end
    itemFluid.at = now
    local turn = TURNS[fluid]
    if turn and (itemFluid.steamedHours or 0) >= turn.hours then
        -- What has turned no longer goes off, and its steaming from here on counts towards burning.
        itemFluid.steamedHours, itemFluid.offAt = itemFluid.steamedHours - turn.hours, nil
        fluid = turn.to
    end
    local burn = BURNS[fluid]
    if burn and burn.mapper[vesselType] and (itemFluid.steamedHours or 0) >= burn.hours then return fluid, true end
    return fluid, false
end

-- Hours of steaming still to go before the fluid turns, or burns once turned; nil if neither ever will.
function ItemFluid.hoursToTurn(itemFluid, fluid)
    local turn = TURNS[fluid]
    return turn and math.max(turn.hours - (itemFluid.steamedHours or 0), 0) or nil
end

function ItemFluid.hoursToBurn(itemFluid, fluid)
    local burn = BURNS[fluid]
    return burn and math.max(burn.hours - (itemFluid.steamedHours or 0), 0) or nil
end

-- How many pieces of pieceMl fit in a vessel holding amountL of capacityL: none if it holds anything but fluid.
function ItemFluid.pieceRoom(capacityL, amountL, holdsOnly, pieceMl)
    if amountL > ItemFluid.AMOUNT_TOLERANCE_L and not holdsOnly then return 0 end
    local roomMl = (capacityL - amountL) * CauldronFluid.ML_PER_L
    return math.max(math.floor((roomMl + ItemFluid.AMOUNT_TOLERANCE_L * CauldronFluid.ML_PER_L) / pieceMl), 0)
end

-- The engine

-- The one fluid a container holds, by name, with its litres; nil when empty or a mixture.
function ItemFluid.oneFluid(container)
    if not container or container:isEmpty() then return nil end
    local primary = container:getPrimaryFluid()
    local name = primary and primary:getFluidTypeString()
    local amount = container:getPrimaryFluidAmount()
    if not name or amount < container:getAmount() - ItemFluid.AMOUNT_TOLERANCE_L then return nil end
    return name, amount
end

-- How many pieces of fluid fit in the item now (0 for a non-vessel).
function ItemFluid.roomFor(item, fluid, pieceMl)
    local container = item:getFluidContainer()
    if not container then return 0 end
    return ItemFluid.pieceRoom(container:getCapacity(), container:getAmount(), ItemFluid.oneFluid(container) == fluid, pieceMl)
end

ItemFluid.HOT_HEAT = CauldronFluid.itemHeat(ItemFluid.HOT_C)

-- Adds fluid to a vessel whatever its lock: vanilla's canAddFluid refuses anything while the player can't empty it,
-- which a fluid that stays in sets (staysIn). The caller sets the lock for what it now holds.
local function addFluid(container, fluid, litres)
    container:setCanPlayerEmpty(true)
    container:addFluid(fluid, litres)
end

local function swap(container, from, to, litres)
    container:adjustSpecificFluidAmount(Fluid.Get(from), 0)
    addFluid(container, to, litres)
end

-- The burnt item, where the vessel was: emptied, its condition kept.
local function burn(item, burntType)
    local container = item:getFluidContainer()
    container:Empty()
    container:setCanPlayerEmpty(true)
    local burnt = instanceItem(burntType)
    burnt:setCondition(item:getCondition())
    burnt:setBurnt(true)
    return Action.replaceItem(item, burnt)
end

-- Brings the fluid in an item up to now, turning, going off or burning it. An item with none of a named fluid, or a
-- mixture, forgets its record (and may be emptied again). Returns the item (the burnt one if it burnt).
function ItemFluid.look(item, now)
    local container = item:getFluidContainer()
    local fluid, litres = ItemFluid.oneFluid(container)
    local modData = item:getModData()
    if not fluid or not ItemFluid.isNamed(fluid) then
        if modData[ItemFluid.KEY] then
            modData[ItemFluid.KEY] = nil
            container:setCanPlayerEmpty(true)
        end
        return item
    end
    local itemFluid = modData[ItemFluid.KEY] or { steamedHours = 0 }
    modData[ItemFluid.KEY] = itemFluid
    local became, burnt = ItemFluid.advance(itemFluid, fluid, now, item:getItemHeat() >= ItemFluid.HOT_HEAT, item:getFullType())
    if burnt then return burn(item, BURNS[became].mapper[item:getFullType()]) or item end
    if became ~= fluid then swap(container, fluid, became, litres) end
    container:setCanPlayerEmpty(ItemFluid.canEmpty(became))
    return item
end

-- Puts pieces into a vessel as fluid, as many as fit. hoursLeft has, for each piece, the hours until it would have
-- gone off. Returns how many went in.
function ItemFluid.addPieces(item, fluid, pieceMl, hoursLeft, now)
    local count = math.min(#hoursLeft, ItemFluid.roomFor(item, fluid, pieceMl))
    if count <= 0 then return 0 end
    ItemFluid.look(item, now)
    local modData = item:getModData()
    local itemFluid = modData[ItemFluid.KEY] or { steamedHours = 0 }
    local taken = {}
    for index = 1, count do taken[index] = hoursLeft[index] end
    ItemFluid.putPieces(itemFluid, taken, now)
    modData[ItemFluid.KEY] = itemFluid
    local container = item:getFluidContainer()
    addFluid(container, fluid, count * pieceMl / CauldronFluid.ML_PER_L)
    container:setCanPlayerEmpty(ItemFluid.canEmpty(fluid))
    return count
end

-- Where TPPutPieces puts pieces into a pot or saucepan the character carries, as many as fit, as a fluid.
function ItemFluid.piecesInto(item)
    return {
        item = item,
        here = function(character) return character:getInventory():containsRecursive(item) end,
        room = function(asFluid) return ItemFluid.roomFor(item, asFluid.fluid, asFluid.pieceMl) end,
        put = function(asFluid, hoursLeft, now) return ItemFluid.addPieces(item, asFluid.fluid, asFluid.pieceMl, hoursLeft, now) end,
    }
end

local function hasFluid(item)
    return item:getFluidContainer() ~= nil
end

-- Brings every fluid item in an item container (and the bags inside it) up to now.
function ItemFluid.lookIn(container, now)
    local items = container and container:getAllEvalRecurse(hasFluid)
    for i = 0, items and items:size() - 1 or -1 do ItemFluid.look(items:get(i), now) end
end

-- The heat to look for on the stoves near players: HOT_HEAT once anything is named, else nil (no look).
function ItemFluid.lookHeat()
    return watchesHeat and ItemFluid.HOT_HEAT or nil
end

return ItemFluid
