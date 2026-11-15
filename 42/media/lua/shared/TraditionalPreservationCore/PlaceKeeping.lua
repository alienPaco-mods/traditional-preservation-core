-- Traditional Preservation core: food that keeps by place (Fish & Meat's Crock of Potted Meat, Dairy's butter). The
-- item's script days are what it keeps in a 15 C cellar; a keeper's curve says how many days of age a day counts as at
-- a temperature, read at Core's place temperature (Weather.placeTemperature), a powered fridge at 4 C, a powered
-- freezer not at all. The item carries its own clock in modData (spec.modDataKey) = { base = its age when the clock
-- started, record = a FluidAgeing record on the keeper's ledger }, so one left in a basement for a month catches up
-- when it is next seen: its age is base plus the record's hours. Vanilla ages it between looks at its own rate; each
-- look puts that right. A mod makes one keeper, records the weather into its ledger and looks at its items.
local Weather = require "TraditionalPreservationCore/Weather"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"

local PlaceKeeping = {}

-- spec: { kind = the ledger's kind name, curve = { { celsius, days of age a day } ... }, ledgerKey = the global modData
-- key of its ledger, modDataKey = the item's clock, enabled = a function (nil: always on), days = optional
-- { [fullType] = { fresh, rotten } } set on each item it keeps (an item whose script never spoils, like vanilla's
-- Butter) }. Returns the keeper.
function PlaceKeeping.new(spec)
    local keeper = { spec = spec }

    -- Days of age a day counts as at celsius.
    function keeper.ageRate(celsius)
        return Weather.curve(spec.curve, celsius)
    end
    keeper.kinds = { [spec.kind] = keeper.ageRate }
    -- The item's ageing (a FluidAgeing record's spec), on top of the place: vanilla's Food Spoilage setting.
    keeper.ageing = { kind = spec.kind, rate = keeper.ageRate, speed = FluidAgeing.foodRotSpeed }

    function keeper.enabled()
        return spec.enabled == nil or spec.enabled()
    end

    function keeper.newLedger(now)
        return Weather.newLedger(now, keeper.kinds)
    end

    function keeper.ledger()
        return Weather.getLedger(spec.ledgerKey, keeper.newLedger)
    end

    -- Adds a stretch of weather to the ledger (every ten minutes, from a Weather.record).
    function keeper.record(now, temperature)
        Weather.advance(keeper.ledger(), now, temperature, keeper.kinds)
    end

    -- How fast an item keeps at a place now: FluidAgeing's place names (Fridge, Freezer, or a Weather place).
    function keeper.rate(place, ledger)
        if place == FluidAgeing.FREEZER then return 0 end
        if place == FluidAgeing.FRIDGE then return keeper.ageRate(FluidAgeing.FRIDGE_C) end
        return keeper.ageRate(Weather.placeTemperature(ledger or keeper.ledger(), place or Weather.DEFAULT_PLACE))
    end

    -- Brings an item's age up to now at the place it was seen in last, and counts from where it is now (place, or
    -- where the item is). The first look starts its clock. Returns its clock, or nil with the keeper off.
    function keeper.keep(item, now, place, ledger)
        if not keeper.enabled() then return nil end
        now = now or getGameTime():getWorldAgeHours()
        ledger = ledger or keeper.ledger()
        local days = spec.days and spec.days[item:getFullType()]
        if days and item:getOffAge() ~= days[1] then
            item:setOffAge(days[1])
            item:setOffAgeMax(days[2])
        end
        local data = item:getModData()
        local clock = data[spec.modDataKey]
        place = place or FluidAgeing.placeOfItem(item) or (clock and clock.record.place) or Weather.DEFAULT_PLACE
        if not clock then
            clock = { base = item:getAge(), record = FluidAgeing.newRecord(keeper.ageing, ledger, now, place) }
            data[spec.modDataKey] = clock
            return clock
        end
        FluidAgeing.advance(clock.record, keeper.ageing, ledger, now, place)
        item:setAge(clock.base + clock.record.age / 24)
        return clock
    end

    -- Ages a kept item by days at its place now (the console's test helper). Returns its clock, or nil.
    function keeper.age(item, days)
        local clock = keeper.keep(item)
        if not clock then return nil end
        clock.record.age = clock.record.age + days * 24 * keeper.rate(clock.record.place) * keeper.ageing.speed()
        item:setAge(clock.base + clock.record.age / 24)
        return clock
    end

    -- One line on a kept item for the console: its place, rate, age and the days to stale and rotten there.
    function keeper.describe(item)
        keeper.keep(item)
        local clock = item:getModData()[spec.modDataKey]
        local place = clock and clock.record.place or "?"
        local rate = keeper.rate(clock and place or nil) * keeper.ageing.speed()
        local age = item:getAge()
        local function left(limit)
            if age >= limit then return "past" end
            return rate > 0 and string.format("%.0f d", (limit - age) / rate) or "never"
        end
        return string.format("%s in %s: x%.2f (%.0f days fresh here), age %.1f d, stale in %s, rotten in %s",
            item:getDisplayName(), place, rate, rate > 0 and item:getOffAge() / rate or 0, age,
            left(item:getOffAge()), left(item:getOffAgeMax()))
    end

    return keeper
end

return PlaceKeeping
