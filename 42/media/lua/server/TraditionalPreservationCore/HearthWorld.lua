-- Traditional Preservation core: keeps track of every Hearth and Firebox and brings a Hearth's copper up to the hour: heated while
-- vanilla's fire burnt (as far as its fuel went), cooled to the room since. Its look is its own sprite swapped among
-- the hearth tiles (vanilla's flames are attached sprites: never clear them). The room's temperature is the series'
-- weather (Weather.shared), so the Hearth works whichever TP mods are on. A banked Hearth's vanilla fire is out: its
-- fuel is set each refresh to the mod's count, it gets a small heat source and a faint light of its own, and its
-- firebox is kept hot (a custom container temperature) with the food's cooking set back to a third. None of these
-- three is saved by the game, so each refresh puts them back.
if isClient() then return end

local Hearth = require "TraditionalPreservationCore/Hearth"
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"
local log = require "TraditionalPreservationCore/Log"
local FluidAgeing = require "TraditionalPreservationCore/FluidAgeing"

local World = {}
Hearth.World = World

-- The weather a Hearth's room goes by.
World.getLedger = Weather.shared

-- The cooking time each food in a banked firebox had at the last look, by fire and item id. Cooking only runs in
-- loaded areas, as the refresh does, so this needn't be saved. Vanilla adds cooking time every tick, so a banked
-- firebox is set back every tick too (slowAll): once a refresh made the cooking bar climb and snap back.
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

local function slowAll()
    local fires = {}
    for fire in pairs(cookSeen) do table.insert(fires, fire) end
    for _, fire in ipairs(fires) do slowCooking(fire) end
end

local function addEmbers(fire, entry)
    local x, y, z = fire:getX(), fire:getY(), fire:getZ()
    entry.heat = IsoHeatSource.new(x, y, z, Hearth.BANKED_HEAT_RADIUS, Hearth.BANKED_HEAT_C)
    getCell():addHeatSource(entry.heat)
    local r, g, b = unpack(Hearth.BANKED_LIGHT)
    entry.light = getCell():addLamppost(x, y, z, r, g, b, Hearth.BANKED_LIGHT_RADIUS)
end

local function removeEmbers(entry)
    if entry.heat then getCell():removeHeatSource(entry.heat) end
    if entry.light then getCell():removeLamppost(entry.light) end
    entry.heat, entry.light = nil, nil
end

-- A banked Hearth's own heat, light and hot firebox, or none of them.
local function showEmbers(fire, banked)
    local entry = World.track(fire)
    if entry and banked and not entry.heat then addEmbers(fire, entry) end
    if entry and not banked then removeEmbers(entry) end
    local container = fire:getContainer()
    if not container then return end
    local want = banked and Hearth.BANKED_FIREBOX or 0
    if math.abs(container:getCustomTemperature() - want) > 0.001 then
        container:setCustomTemperature(want)
        if banked then container:addItemsToProcessItems() end
    end
end

-- Brings the copper up to now, keeps a banked fire's fuel and cooking slow, its embers' heat and light, notes how long the fire will burn on
-- and adds to its record (Hearth.logFire),
-- and shows the copper empty, full or steaming (a Firebox: its flue), and the fire mouth's glow, lit or banked.
function World.update(fire, now)
    local copper = Hearth.stateOf(fire:getModData())
    local hasCopper = Hearth.isHearth(fire)
    local before = Hearth.look(copper)
    if hasCopper then
        Hearth.advance(copper, now, Weather.placeTemperature(World.getLedger(), Weather.placeOf(fire)))
        FluidAgeing.updateCopper(copper, now, Weather.placeOf(fire), Hearth.heldHours(copper))
    end
    local fuel = Hearth.reckonFuel(copper, fire:getFuelAmount(), fire:isLit(), now)
    if fuel then fire:setFuelAmount(fuel) end
    local banked = Hearth.isBanked(fire)
    showEmbers(fire, banked)
    if banked then slowCooking(fire) else cookSeen[fire] = nil end
    copper.fireUntil = Hearth.isBurning(fire) and now + Hearth.fuelHours(fire) or nil
    local mode = banked and Hearth.BANKED or fire:isLit() and Hearth.STOKED or nil
    Hearth.logFire(copper, now, mode, copper.fireUntil)
    local look = Hearth.look(copper)
    local name, glow = Hearth.showing(fire, copper, Hearth.isBurning(fire), banked)
    if name and fire:getSprite():getName() ~= name then fire:setSprite(getSprite(name)) end
    local shown = fire:getOverlaySprite()
    if (shown and shown:getName()) ~= glow then fire:setOverlaySprite(glow) end
    if hasCopper and look ~= before then
        log("TP", "hearth copper %s -> %s: %.1f L %s at %.1f C", before, look, (copper.ml or 0) / 1000,
            tostring(copper.fluid), copper.tempC or 0)
    end
    return copper
end

local function refresh(fire)
    World.update(fire, getGameTime():getWorldAgeHours())
end

local tracker = Station.tracker({
    sprites = Hearth.FIRE_SPRITES,
    entry = function(object) return Hearth.isFire(object) and {} or nil end,
    refresh = refresh,
    dropped = function(fire, entry)
        removeEmbers(entry)
        cookSeen[fire] = nil
    end,
    -- A hearth just built or put down shows its copper (a Firebox its flue) at once.
    scan = true,
})

World.track = tracker.track

-- Banks a lit fire (vanilla's fire put out), stokes a banked one up again (lit), or puts a banked one out. The copper
-- is brought up to now first, so it heated as the fire was until now.
function World.setFire(fire, mode, now)
    local copper = World.update(fire, now)
    if mode == "bank" then
        Hearth.setBanked(copper, true, fire:getFuelAmount(), now)
        -- setLit, not extinguish: extinguish lets it smoulder, burning fuel, for ten minutes.
        fire:setLit(false)
    else
        Hearth.setBanked(copper, false)
        if mode == "stoke" and fire:hasFuel() then fire:turnOn() end
    end
    World.refresh(fire)
end

-- Redraws a tracked hearth now, without waiting for the next tick, e.g. after a pour.
function World.refresh(fire)
    if tracker.track(fire) then refresh(fire) end
end

Weather.start()

Events.OnTick.Add(slowAll)

tracker.start()

return World
