-- Traditional Preservation core: food kept hot for a while, after it was made. Vanilla tells a food when it first
-- cooks (OnCooked), never again, so a boiled sausage fried afterwards can't know it. A mod watches a full type with
-- OnHeat.watch(fullType, minutes, fn): every minute, items of that type at HEAT_C or hotter in a hot container near
-- a player count the minutes they stay so, and once they reach minutes fn(item) runs, once for that item (Fish &
-- Meat: Blood Sausage (Boiled) fried becomes Blood Sausage (Boiled, Fried)). Counted under KEY in the item's modData.
local Station = require "TraditionalPreservationCore/Station"
local Hearth = require "TraditionalPreservationCore/Hearth"

local OnHeat = {}

-- Save key: never rename it once the mod is out. Inside: minutes, at (the hour last seen hot), done.
OnHeat.KEY = "tpOnHeat"
OnHeat.HEAT_C = 100
OnHeat.RADIUS = 8
OnHeat.MAX_GAP_MINUTES = 2

local watched = {}
local started = false

-- One look at an item: counts the time since it was last seen hot, and calls fn once it has been hot long enough.
-- hot says whether it is hot now. Returns true once fn has run.
function OnHeat.note(item, watch, now, hot)
    local modData = item:getModData()
    local record = modData[OnHeat.KEY]
    if record and record.done then return true end
    if not hot then
        if record then record.at = nil end
        return false
    end
    record = record or { minutes = 0 }
    -- Only a gap of a look or two counts: an item taken off the heat isn't seen again until it is back on.
    local gap = record.at and (now - record.at) * 60
    if gap and gap > 0 and gap <= OnHeat.MAX_GAP_MINUTES then record.minutes = record.minutes + gap end
    record.at = now
    modData[OnHeat.KEY] = record
    if record.minutes >= watch.minutes then
        record.done = true
        watch.fn(item)
        return true
    end
    return false
end

local function itemHot(item)
    return item:getItemHeat() >= Hearth.itemHeat(OnHeat.HEAT_C)
end

local function lookNear(square, now)
    Station.hotContainers(square, OnHeat.RADIUS, Hearth.itemHeat(OnHeat.HEAT_C), function(container)
        for fullType, watch in pairs(watched) do
            local items = container:getAllTypeRecurse(fullType)
            for i = 0, items:size() - 1 do
                local item = items:get(i)
                OnHeat.note(item, watch, now, itemHot(item))
            end
        end
    end)
end

local function start()
    -- Outside the game (tests) there may be no clock to hang it on.
    if started or not Events or (isClient and isClient()) then return end
    started = true
    Events.EveryOneMinute.Add(function()
        local now, list = getGameTime():getWorldAgeHours(), Station.players()
        for i = 0, list:size() - 1 do lookNear(list:get(i):getSquare(), now) end
    end)
end

function OnHeat.watch(fullType, minutes, fn)
    watched[fullType] = { minutes = minutes, fn = fn }
    start()
end

return OnHeat
