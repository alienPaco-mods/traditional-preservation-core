-- Traditional Preservation core: a craft recipe's bar and clock. Weather-timed runs (startRun, showProgress) count the
-- work the ledger says was done; clock-timed ones (startClock, showClock) the hours since they began; batchStatus is
-- a running batch's popup numbers; setRecipeHours sets a recipe's time from the sandbox. Weather passes every function
-- here on (Weather.startRun, ...), so callers name Weather only.
local Weather = require "TraditionalPreservationCore/Weather"

local CraftClock = {}

local SECONDS_PER_HOUR = 3600

-- The engine pools recipe data without clearing its ModData, so a mod's start hook clears its own fields too.
function CraftClock.startRun(modData, ledger, kind)
    modData.done = 0
    modData.last = Weather.mark({}, ledger, kind)
    modData.place, modData.fireUntil, modData.under = nil, nil, nil
end

-- Craft timers tick at a fixed speed whatever Day Length says, so this replaces their count with the work
-- done. Weather is only recorded every ten minutes, so the bar carries on at the last rate between
-- records. That part is only shown, and the next record replaces it. rateAt gives the rate by a fire
-- (Weather.FIRE_PLACES), which the ledger keeps none for.
function CraftClock.showProgress(craftRecipeData, ledger, kind, place, speed, now, rateAt)
    local modData = craftRecipeData:getModData()
    local byFire = Weather.FIRE_PLACES[place] and rateAt
    local rate = byFire and rateAt(Weather.placeTemperature(ledger, place)) or ledger[kind .. place .. "Rate"] or 0
    local sinceRecord = math.max(now - ledger.lastHour, 0)
    local elapsed = (modData.done + sinceRecord * rate) * speed * SECONDS_PER_HOUR
    craftRecipeData:setElapsedTime(math.min(elapsed, craftRecipeData:getRecipe():getTime()))
end

-- Sets a craft recipe's time from the sandbox, so the bar's full length matches the hours of work it stands for.
-- tag names the mod in the log when the recipe is missing (a renamed or removed script).
function CraftClock.setRecipeHours(fullName, hours, tag)
    local recipe = ScriptManager.instance:getCraftRecipe(fullName)
    if not recipe then
        print("[" .. tag .. "] Could not find " .. fullName)
        return
    end
    recipe:Load(fullName, "{ time = " .. tostring(math.floor(hours * SECONDS_PER_HOUR)) .. ", }")
end

-- Work that goes by the clock alone (Fish's press, Salt's leaching) needs no ledger, only the hour it began.
-- The engine pools recipe data without clearing its ModData, so every run's OnStart must call startClock.
function CraftClock.startClock(craftRecipeData, key, now)
    craftRecipeData:getModData()[key] = now
end

-- A run with no start hour is left alone. The start hour saves with the recipe. speed (default 1) runs the
-- bar faster, for a run shorter than its recipe's time.
function CraftClock.showClock(craftRecipeData, key, now, speed)
    local startHour = craftRecipeData:getModData()[key]
    if not startHour then return end

    local elapsed = (now - startHour) * (speed or 1) * SECONDS_PER_HOUR
    craftRecipeData:setElapsedTime(math.min(elapsed, craftRecipeData:getRecipe():getTime()))
end

-- How a running batch is doing, for its popup. hoursLeft assumes the temperature holds; nil when the batch is
-- paused there (frozen).
function CraftClock.batchStatus(done, recipeHours, ledger, place, rateAt)
    local temperature = Weather.placeTemperature(ledger, place)
    local rate = rateAt(temperature)
    return {
        progress = math.min(done / recipeHours, 1),
        hoursLeft = rate > 0 and math.max(recipeHours - done, 0) / rate or nil,
        temperature = temperature,
        place = place,
        rate = rate,
    }
end

return CraftClock
