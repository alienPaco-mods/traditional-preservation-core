-- Traditional Preservation core: keeps track of every Hearth and brings its copper up to the hour: heated while
-- vanilla's fire burnt (as far as its fuel went), cooled to the room since. Its look is its own sprite swapped among
-- the hearth tiles (vanilla's flames are attached sprites: never clear them). The room's temperature is the series'
-- weather (Weather.shared), so the Hearth works whichever TP mods are on. A banked Hearth's fuel and the food
-- cooking in its firebox are set back each refresh to what a fire burning at BANKED_BURN would have done.
if isClient() then return end

local Hearth = require "TraditionalPreservationCore/Hearth"
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"
local log = require "TraditionalPreservationCore/Log"

local World = {}
Hearth.World = World

-- The weather a Hearth's room goes by.
World.getLedger = Weather.shared

-- The cooking time each food in a banked firebox had at the last refresh, by fire and item id. Cooking only runs in
-- loaded areas, as the refresh does, so this needn't be saved.
local cookSeen = setmetatable({}, { __mode = "k" })

local function slowCooking(fire)
    local seen = cookSeen[fire] or {}
    local now = {}
    local container = fire:getContainer()
    local items = container and container:getItems()
    for i = 0, items and items:size() - 1 or -1 do
        local item = items:get(i)
        if instanceof(item, "Food") and item:isCookable() then
            local time = item:getCookingTime()
            local before = seen[item:getID()]
            if before and time > before then
                time = Hearth.bankedCooking(before, time)
                item:setCookingTime(time)
            end
            now[item:getID()] = time
        end
    end
    cookSeen[fire] = now
end

-- Brings the copper up to now, keeps a banked fire's fuel and cooking slow, notes how long the fire will burn on,
-- and shows the copper empty, full or steaming.
function World.update(fire, now)
    local copper = Hearth.stateOf(fire:getModData())
    local before = Hearth.look(copper)
    Hearth.advance(copper, now, Weather.placeTemperature(World.getLedger(), Weather.placeOf(fire)))
    local fuel, relight = Hearth.reckonFuel(copper, fire:getFuelAmount(), fire:isLit(), now)
    if fuel then fire:setFuelAmount(fuel) end
    if relight then fire:turnOn() end
    if Hearth.isBanked(fire) then slowCooking(fire) else cookSeen[fire] = nil end
    copper.fireUntil = fire:isLit() and now + Hearth.fuelHours(fire) or nil
    local look = Hearth.look(copper)
    local face = Hearth.face(fire:getSprite():getName())
    local name = face and Hearth.sprite(look, face)
    if name and fire:getSprite():getName() ~= name then fire:setSprite(getSprite(name)) end
    if look ~= before then
        log("TP", "hearth copper %s -> %s: %.1f L %s at %.1f C", before, look, (copper.ml or 0) / 1000,
            tostring(copper.fluid), copper.tempC or 0)
    end
    return copper
end

local function refresh(fire)
    World.update(fire, getGameTime():getWorldAgeHours())
end

local tracker = Station.tracker({
    sprites = Hearth.SPRITES,
    entry = function(object) return Hearth.isHearth(object) and {} or nil end,
    refresh = refresh,
    -- A hearth just built or put down shows its copper at once.
    scan = true,
})

World.track = tracker.track

-- Redraws a tracked hearth now, without waiting for the next tick, e.g. after a pour.
function World.refresh(fire)
    if tracker.track(fire) then refresh(fire) end
end

Weather.start()

tracker.start()

return World
