-- Traditional Preservation core: keeps track of every fire (Fire.kind: the Stone Hearth) and brings what is fitted (the
-- cauldron) up to the hour: heated while
-- vanilla's fire burnt (as far as its fuel went), cooled to the room since. Its look is its own sprite swapped among
-- the fire tiles (vanilla's flames are attached sprites: never clear them). The room's temperature is the series'
-- weather (Weather.weatherModData), so a fire works whichever TP mods are on. A banked fire's vanilla fire is out: its
-- fuel is set each refresh to the mod's count, it gets a small heat source and a faint light of its own, and its
-- firebox is kept hot (a custom container temperature) with the food's cooking set back to a third. None of these
-- three is saved by the game, so each refresh puts them back.
if isClient() then return end

local Fire = require "TraditionalPreservationCore/Fire"
require "TraditionalPreservationCore/StoneHearth"   -- registers its kind before the tracker reads Fire.sprites
local Cauldron = require "TraditionalPreservationCore/Cauldron"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"
local log = require "TraditionalPreservationCore/Log"

local World = {}
Fire.World = World

-- The weather a fire's room goes by.
World.getLedger = Weather.weatherModData

-- The cooking time each food in a banked firebox had at the last look, by fire and item id. Cooking only runs in
-- loaded areas, as the refresh does, so this needn't be saved. Vanilla adds cooking time every tick, so a banked
-- firebox is set back every tick too (slowAll): once a refresh made the cooking bar climb and snap back. Kahlua has
-- no weak tables (ENGINE_NOTES), so a fire's sessionState goes when the tracker drops it.
local cookSeen = {}

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
                time = Fire.bankedCooking(before, time)
                item:setCookingTime(time)
            end
            now[item:getID()] = time
        end
    end
    cookSeen[fire] = now
end

-- Kahlua's pairs goes over the keys as they were when it started, so slowCooking may set a fire's sessionState meanwhile.
local function slowAll()
    for fire in pairs(cookSeen) do slowCooking(fire) end
end

local function addEmbers(fire, sessionState)
    local x, y, z = fire:getX(), fire:getY(), fire:getZ()
    sessionState.heat = IsoHeatSource.new(x, y, z, Fire.BANKED_HEAT_RADIUS, Fire.BANKED_HEAT_C)
    getCell():addHeatSource(sessionState.heat)
    local r, g, b = unpack(Fire.BANKED_LIGHT)
    sessionState.light = getCell():addLamppost(x, y, z, r, g, b, Fire.BANKED_LIGHT_RADIUS)
end

local function removeEmbers(sessionState)
    if sessionState.heat then getCell():removeHeatSource(sessionState.heat) end
    if sessionState.light then getCell():removeLamppost(sessionState.light) end
    sessionState.heat, sessionState.light = nil, nil
end

-- A banked fire's own heat, light and hot firebox, or none of them.
local function showEmbers(fire, banked)
    local sessionState = World.track(fire)
    if sessionState and banked and not sessionState.heat then addEmbers(fire, sessionState) end
    if sessionState and not banked then removeEmbers(sessionState) end
    local container = fire:getContainer()
    if not container then return end
    local want = banked and Fire.BANKED_FIREBOX or 0
    if math.abs(container:getCustomTemperature() - want) > 0.001 then
        container:setCustomTemperature(want)
        if banked then container:addItemsToProcessItems() end
    end
end

-- The cauldron's simmer: a looping TPSimmering on the fire's square while what it holds is at HOT_C or more, one per
-- fire. A free world emitter (the world ticks it); stopped when the cauldron cools, empties, or the fire unloads.
World.SIMMER_SOUND = "TPSimmering"
local simmers = {}

local function simmer(fire, on)
    local playing = simmers[fire]
    if playing and (not on or not playing.emitter:isPlaying(playing.id)) then
        playing.emitter:stopSound(playing.id)
        simmers[fire], playing = nil, nil
    end
    if not on or playing or isServer() then return end
    local square = fire:getSquare()
    local emitter = square and getWorld():getFreeEmitter(square:getX() + 0.5, square:getY() + 0.5, square:getZ())
    if emitter then simmers[fire] = { emitter = emitter, id = emitter:playSoundLooped(World.SIMMER_SOUND) } end
end

Fire.attach({ id = Cauldron.ID, onFire = function(cauldron, fire) simmer(fire, CauldronFluid.isHot(cauldron)) end })

-- The overlay (a bare Stone Hearth's glow, or what the cauldron holds) and its tint. The tint isn't saved, so it is set
-- again the first time a fire is seen after a load (tints starts empty), and whenever it changes. Dropped with the fire.
local tints = {}

local function showOverlay(fire, overlay, colour)
    local shown = fire:getOverlaySprite()
    local key = overlay and colour and string.format("%.3f %.3f %.3f", colour[1], colour[2], colour[3]) or ""
    if (shown and shown:getName()) == overlay and tints[fire] == key then return end
    if overlay and colour then
        fire:setOverlaySprite(overlay, colour[1], colour[2], colour[3], 1)
    else
        fire:setOverlaySprite(overlay)
    end
    tints[fire] = key
end

-- Brings what is fitted up to now (Fire.attach's heats), keeps a banked fire's fuel and cooking slow, its embers'
-- heat and light, notes how long the fire will burn on and adds to its record (Fire.logFire), and shows the
-- attachment's look (a Stone Hearth: its flue and what is in the hole) and the fire mouth's glow, lit or banked. Returns the fire's state.
function World.update(fire, now)
    local fireModData = Fire.fireModData(fire:getModData())
    local attachment, part = Fire.attachmentOf(fire)
    -- Known by its tile only (put down after a pick-up): noted, so the hole's tiles never take its place.
    if attachment then fireModData.attached = attachment.id end
    local before = attachment and attachment.look and attachment.look(part, fire)
    if attachment and attachment.heats then
        local place = Weather.placeOf(fire)
        attachment.heats(part, fire, now, fireModData, Weather.placeTemperature(World.getLedger(), place), place)
    end
    local fuel = Fire.reckonFuel(fireModData, fire:getFuelAmount(), fire:isLit(), now)
    if fuel then fire:setFuelAmount(fuel) end
    local banked = Fire.isBanked(fire)
    showEmbers(fire, banked)
    if banked then slowCooking(fire) else cookSeen[fire] = nil end
    local burning = Fire.isBurning(fire)
    fireModData.fireUntil = burning and now + Fire.fuelHours(fire) or nil
    local mode = banked and Fire.BANKED or fire:isLit() and Fire.STOKED or nil
    Fire.logFire(fireModData, now, mode, fireModData.fireUntil)
    local name, overlay, colour = Fire.showing(fire, fireModData, burning, banked)
    if name and fire:getSprite():getName() ~= name then fire:setSprite(getSprite(name)) end
    showOverlay(fire, overlay, colour)
    if attachment and attachment.onFire then attachment.onFire(part, fire, now, fireModData) end
    local look = attachment and attachment.look and attachment.look(part, fire)
    if look ~= before then log("TP", "fire %s %s -> %s", attachment.id, tostring(before), tostring(look)) end
    return fireModData
end

local function refresh(fire)
    World.update(fire, getGameTime():getWorldAgeHours())
end

local tracker = Station.tracker({
    sprites = Fire.sprites(),
    newSessionState = function(isoObject) return Fire.isFire(isoObject) and {} or nil end,
    refresh = refresh,
    dropped = function(fire, sessionState)
        removeEmbers(sessionState)
        simmer(fire, false)
        cookSeen[fire] = nil
        tints[fire] = nil
    end,
    -- A fire just built or put down shows its cauldron (a Stone Hearth its flue and hole) at once.
    scan = true,
})

World.track = tracker.track

-- Banks a lit fire (vanilla's fire put out), stokes a banked one up again (lit), or puts a banked one out. The cauldron
-- is brought up to now first, so it heated as the fire was until now.
function World.setFire(fire, mode, now)
    local fireModData = World.update(fire, now)
    if mode == "bank" then
        Fire.setBanked(fireModData, true, fire:getFuelAmount(), now)
        -- setLit, not extinguish: extinguish lets it smoulder, burning fuel, for ten minutes.
        fire:setLit(false)
    else
        Fire.setBanked(fireModData, false)
        if mode == "stoke" and fire:hasFuel() then fire:turnOn() end
    end
    World.refresh(fire)
end

-- Redraws a tracked fire now, without waiting for the next tick, e.g. after a pour.
function World.refresh(fire)
    if tracker.track(fire) then refresh(fire) end
end

Weather.start()

Events.OnTick.Add(slowAll)

tracker.start()

return World
