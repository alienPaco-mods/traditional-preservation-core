-- Traditional Preservation core: food that keeps by place (Fish & Meat's Crock of Potted Meat, Dairy's butter). The
-- item's script days are what it keeps in a 15 C cellar; a keeper's curve says how many days of age a day counts as at
-- a temperature, read at Core's place temperature (Weather.placeTemperature; by a fire or banked embers too, as the
-- stations), a powered fridge at 4 C, a powered freezer not at all. The item carries its own clock in modData (keepingRules.modDataKey) = { base = its age when the clock
-- started, fluidAge = a FluidAgeing age on the keeper's ledger }, so one left in a basement for a month catches up
-- when it is next seen: its age is base plus the fluidAge's hours. Vanilla ages it between looks at its own rate; each
-- look puts that right. A mod makes one keeper, records the weather into its ledger and looks at its items.
-- A keeper with staleShare runs an item's stale stretch (its fresh days to its rotten) on a clock of its own, clock.stale,
-- where only that share of the place's slowing holds (0: none, a day a day wherever it is, frozen still stopping it;
-- user, session 78, for Fruits and Vegetables: cold storage buys the fresh days, a stale vegetable goes off in weeks
-- wherever it is). Without it the whole clock runs at the place's rate, as before.
local Weather = require "TraditionalPreservationCore/Weather"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"

local PlaceKeeping = {}

-- keepingRules: { process = the ledger's process name, curve = { { celsius, days of age a day } ... }, ledgerKey = the global modData
-- key of its ledger, modDataKey = the item's clock, enabled = a function (nil: always on), days = optional
-- { [fullType] = { fresh, rotten } } set on each item it keeps (an item whose script never spoils, like vanilla's
-- Butter, or a stale stretch of the keeper's own), staleShare = optional (see above) }. Returns the keeper.
function PlaceKeeping.new(keepingRules)
    local keeper = { keepingRules = keepingRules }

    -- Days of age a day counts as at celsius.
    function keeper.ageRate(celsius)
        return Weather.curve(keepingRules.curve, celsius)
    end
    keeper.processes = { [keepingRules.process] = keeper.ageRate }
    -- The item's ageing (a FluidAgeing fluid kind), on top of the place: vanilla's Food Spoilage setting.
    keeper.ageing = { process = keepingRules.process, rate = keeper.ageRate, speed = FluidAgeing.foodRotSpeed }

    -- The stale stretch's rate from the fresh one: only staleShare of the slowing holds (a day counting 0.2 slows it
    -- five times; at half, two and a half times: 0.4). Faster than a day (warmer than the curve's base) the same way.
    local staleShare = keepingRules.staleShare
    function keeper.staleRateOf(rate)
        if not staleShare then return rate end
        if rate <= 0 then return 0 end
        return 1 / (1 + (1 / rate - 1) * staleShare)
    end
    if staleShare then
        keeper.staleProcess = keepingRules.process .. "Stale"
        local function staleAgeRate(celsius) return keeper.staleRateOf(keeper.ageRate(celsius)) end
        keeper.processes[keeper.staleProcess] = staleAgeRate
        keeper.staleAgeing = { process = keeper.staleProcess, rate = staleAgeRate, speed = FluidAgeing.foodRotSpeed }
    end

    function keeper.enabled()
        return keepingRules.enabled == nil or keepingRules.enabled()
    end

    function keeper.newLedger(now)
        return Weather.newLedger(now, keeper.processes)
    end

    -- The ledger, with totals for every process (a save from before one was added starts it at 0; once a game).
    local filledLedger
    function keeper.ledger()
        local ledger = Weather.getLedger(keepingRules.ledgerKey, keeper.newLedger)
        if ledger ~= filledLedger then
            Weather.fillLedger(ledger, keeper.processes)
            filledLedger = ledger
        end
        return ledger
    end

    -- A second ageing on the keeper's ledger (a mod's own curve for its items somewhere else, as Yeast's cakes on the
    -- Drying Cloth), made at load. Returns the ageing, a FluidAgeing fluid kind with the keeper's speed.
    function keeper.addAgeing(process, curve)
        local function rate(celsius) return Weather.curve(curve, celsius) end
        keeper.processes[process] = rate
        filledLedger = nil
        return { process = process, rate = rate, speed = keeper.ageing.speed }
    end

    -- Adds a stretch of weather to the ledger (every ten minutes, from a Weather.onReading).
    function keeper.recordWeather(now, temperature)
        Weather.advance(keeper.ledger(), now, temperature, keeper.processes)
    end

    -- How fast an item keeps at a place now: FluidAgeing's place names (Fridge, Freezer, or a Weather place).
    function keeper.rate(place, ledger)
        if place == FluidAgeing.FREEZER then return 0 end
        if place == FluidAgeing.FRIDGE then return keeper.ageRate(FluidAgeing.FRIDGE_C) end
        return keeper.ageRate(Weather.placeTemperature(ledger or keeper.ledger(), place or Weather.DEFAULT_PLACE))
    end

    -- How fast an item's stale stretch goes at a place now (the fresh rate without staleShare).
    function keeper.staleRate(place, ledger)
        return keeper.staleRateOf(keeper.rate(place, ledger))
    end

    -- The clock an item is on now: its stale stretch's once it has one, else its fresh one.
    function keeper.active(clock)
        return clock.stale or clock.fluidAge
    end

    -- Sets the item's age from its clock: its base plus the fresh clock, or once stale its fresh days plus the stale
    -- clock. Crossing into stale (now, or at a look that comes later), the part past stale counts again at the stale
    -- rate of the place it was in (an estimate for that one stretch), and the stale clock starts there.
    function keeper.settle(item, clock, ledger, now)
        local offAge = item:getOffAge()
        if clock.stale then
            item:setAge(offAge + clock.stale.age / 24)
            return
        end
        local age = clock.base + clock.fluidAge.age / 24
        if keeper.staleAgeing and age > offAge then
            local place = clock.fluidAge.place
            local fresh, stale = keeper.rate(place, ledger), keeper.staleRate(place, ledger)
            local over = (age - offAge) * (fresh > 0 and stale / fresh or 1)
            clock.stale = FluidAgeing.newFluidAge(keeper.staleAgeing, ledger or keeper.ledger(), now or clock.fluidAge.hour, place)
            clock.stale.age = over * 24
            age = offAge + over
        end
        item:setAge(age)
    end

    -- Brings an item's age up to now at the place it was seen in last, and counts from where it is now (place, or
    -- where the item is). The first look starts its clock. Returns its clock, or nil with the keeper off.
    function keeper.keep(item, now, place, ledger)
        if not keeper.enabled() then return nil end
        now = now or getGameTime():getWorldAgeHours()
        ledger = ledger or keeper.ledger()
        local days = keepingRules.days and keepingRules.days[item:getFullType()]
        if days and (item:getOffAge() ~= days[1] or item:getOffAgeMax() ~= days[2]) then
            item:setOffAge(days[1])
            item:setOffAgeMax(days[2])
        end
        local itemModData = item:getModData()
        local clock = itemModData[keepingRules.modDataKey]
        local fire, holder
        if not place then place, fire, holder = FluidAgeing.placeOfItem(item) end
        place = place or (clock and clock.fluidAge.place) or Weather.DEFAULT_PLACE
        if not clock then
            clock = { base = item:getAge(), fluidAge = FluidAgeing.newFluidAge(keeper.ageing, ledger, now, place) }
            itemModData[keepingRules.modDataKey] = clock
            -- Stale already (loot, or a keeper it changed to): its stale clock starts from its age.
            if keeper.staleAgeing and clock.base > item:getOffAge() then
                clock.stale = FluidAgeing.newFluidAge(keeper.staleAgeing, ledger, now, place)
                clock.stale.age = (clock.base - item:getOffAge()) * 24
            end
        elseif clock.stale then
            FluidAgeing.advance(clock.stale, keeper.staleAgeing, ledger, now, place)
            keeper.settle(item, clock, ledger, now)
        else
            FluidAgeing.advance(clock.fluidAge, keeper.ageing, ledger, now, place)
            keeper.settle(item, clock, ledger, now)
        end
        if holder then
            FluidAgeing.noteFire(clock.fluidAge, fire, holder, now)
            if clock.stale then FluidAgeing.noteFire(clock.stale, fire, holder, now) end
        end
        return clock
    end

    -- Ages a kept item by days at its place now (the console's test helper). Returns its clock, or nil.
    function keeper.age(item, days)
        local clock = keeper.keep(item)
        if not clock then return nil end
        local active = keeper.active(clock)
        local rate = clock.stale and keeper.staleRate(active.place) or keeper.rate(active.place)
        active.age = active.age + days * 24 * rate * keeper.ageing.speed()
        keeper.settle(item, clock)
        return clock
    end

    -- What a kept item faces where it is now, read-only (its tooltip's; the age is as at its last look): { place,
    -- celsius (nil in a freezer), rate (days of age a day now, the stale stretch's once stale; Food Spoilage in, times
    -- factor: a storage's), stale and rotten (days left at the rates there; nil once past, math.huge while it doesn't
    -- age) }. place: where the item is when nil.
    function keeper.forecast(item, place, factor)
        if not place then place = FluidAgeing.placeOfItem(item) end
        place = place or Weather.DEFAULT_PLACE
        local celsius
        if place == FluidAgeing.FRIDGE then
            celsius = FluidAgeing.FRIDGE_C
        elseif place ~= FluidAgeing.FREEZER then
            celsius = Weather.placeTemperature(keeper.ledger(), place)
        end
        local speed = keeper.ageing.speed() * (factor or 1)
        local rate = keeper.rate(place) * speed
        local staleRate = keeper.staleRate(place) * speed
        local age, offAge, offAgeMax = item:getAge(), item:getOffAge(), item:getOffAgeMax()
        local function days(ageDays, at)
            return at > 0 and ageDays / at or math.huge
        end
        local stale, rotten
        if age < offAge then
            stale = days(offAge - age, rate)
            rotten = stale + days(offAgeMax - offAge, staleRate)
        elseif age < offAgeMax then
            rotten = days(offAgeMax - age, staleRate)
        end
        return { place = place, celsius = celsius, rate = age < offAge and rate or staleRate, stale = stale, rotten = rotten }
    end

    -- One line on a kept item for the console: its place, rate, age and the days to stale and rotten there.
    function keeper.describe(item)
        keeper.keep(item)
        local clock = item:getModData()[keepingRules.modDataKey]
        local place = clock and keeper.active(clock).place or "?"
        local rate = keeper.rate(clock and place or nil) * keeper.ageing.speed()
        local seen = keeper.forecast(item, clock and place or nil)
        local function left(days)
            if not days then return "past" end
            return days < math.huge and string.format("%.0f d", days) or "never"
        end
        local fresh = rate > 0 and string.format("%.0f days fresh here", item:getOffAge() / rate) or "keeps forever here"
        return string.format("%s in %s: x%.2f (%s), age %.1f d, stale in %s, rotten in %s",
            item:getDisplayName(), place, rate, fresh, item:getAge(), left(seen.stale), left(seen.rotten))
    end

    return keeper
end

return PlaceKeeping
