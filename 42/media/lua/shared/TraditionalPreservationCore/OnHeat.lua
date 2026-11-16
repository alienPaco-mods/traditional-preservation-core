-- Traditional Preservation core: food kept hot for a while, after it was made. Vanilla tells a food when it first
-- cooks (OnCooked), never again, so a boiled sausage fried afterwards can't know it. A mod watches a full type with
-- OnHeat.watch(fullType, minutes, fn): every minute, items of that type at HEAT_C or hotter in a hot container near
-- a player count the minutes they stay so, and once they reach minutes fn(item) runs, once for that item (Fish &
-- Meat: Blood Sausage (Boiled) fried becomes Blood Sausage (Boiled, Fried)). Counted under KEY in the item's modData.
-- The look is Station's minute look at the heat near players (Station.onHeatNear, Station.HEAT_NEAR).
local Station = require "TraditionalPreservationCore/Station"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"

local OnHeat = {}

-- Save key: never rename it once the mod is out. Inside: minutes, at (the hour last seen hot), finished.
OnHeat.KEY = "tpOnHeat"
OnHeat.HEAT_C = 100
OnHeat.MAX_GAP_MINUTES = 2
-- HEAT_C as vanilla's item heat, worked out once (it is also the container heat looked for).
OnHeat.HEAT = CauldronFluid.itemHeat(OnHeat.HEAT_C)

local watched = {}
local looking = false

-- One look at an item: counts the time since it was last seen hot, and calls fn once it has been hot long enough.
-- hot says whether it is hot now. Returns true once fn has run.
function OnHeat.note(item, watch, now, hot)
    local modData = item:getModData()
    local onHeat = modData[OnHeat.KEY]
    if onHeat and onHeat.finished then return true end
    if not hot then
        if onHeat then onHeat.at = nil end
        return false
    end
    onHeat = onHeat or { minutes = 0 }
    -- Only a gap of a look or two counts: an item taken off the heat isn't seen again until it is back on.
    local gap = onHeat.at and (now - onHeat.at) * 60
    if gap and gap > 0 and gap <= OnHeat.MAX_GAP_MINUTES then onHeat.minutes = onHeat.minutes + gap end
    onHeat.at = now
    modData[OnHeat.KEY] = onHeat
    if onHeat.minutes >= watch.minutes then
        onHeat.finished = true
        watch.fn(item)
        return true
    end
    return false
end

local function lookIn(container, now)
    for fullType, watch in pairs(watched) do
        local items = container:getAllTypeRecurse(fullType)
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            OnHeat.note(item, watch, now, item:getItemHeat() >= OnHeat.HEAT)
        end
    end
end

-- fullType: the food watched; minutes: how long it must stay hot; fn(item): what then happens to it. Watching a type
-- again replaces it (a Lua reload runs the mod's file again).
function OnHeat.watch(fullType, minutes, fn)
    assert(type(fullType) == "string", "OnHeat.watch: fullType must be a full type")
    assert(type(minutes) == "number" and minutes > 0, "OnHeat.watch: " .. fullType .. " needs minutes")
    assert(type(fn) == "function", "OnHeat.watch: " .. fullType .. " needs fn")
    watched[fullType] = { minutes = minutes, fn = fn }
    if looking then return end
    looking = true
    Station.onHeatNear(OnHeat.HEAT, lookIn)
end

return OnHeat
