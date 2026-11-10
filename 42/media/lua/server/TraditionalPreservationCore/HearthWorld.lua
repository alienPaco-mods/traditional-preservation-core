-- Traditional Preservation core: keeps track of every Hearth and brings its copper up to the hour: heated while
-- vanilla's fire burnt (as far as its fuel went), cooled to the room since. Its look is its own sprite swapped among
-- the hearth tiles (vanilla's flames are attached sprites: never clear them). The core keeps its own weather ledger
-- for the room's temperature, so the Hearth works whichever TP mods are on.
if isClient() then return end

local Hearth = require "TraditionalPreservationCore/Hearth"
local Station = require "TraditionalPreservationCore/Station"
local Weather = require "TraditionalPreservationCore/Weather"

local World = {}
Hearth.World = World

local LEDGER_KEY = "TraditionalPreservationCore"
local KINDS = {}

local function newLedger(now)
    return Weather.newLedger(now, KINDS)
end

function World.getLedger()
    return Weather.getLedger(LEDGER_KEY, newLedger)
end

-- Brings the copper up to now, notes how long the fire will burn on, and shows the copper empty, full or steaming.
function World.update(fire, now)
    local copper = Hearth.stateOf(fire:getModData())
    local before = Hearth.look(copper)
    Hearth.advance(copper, now, Weather.placeTemperature(World.getLedger(), Weather.placeOf(fire)))
    copper.fireUntil = fire:isLit() and now + fire:getFuelAmount() / 60 or nil
    local look = Hearth.look(copper)
    local face = Hearth.face(fire:getSprite():getName())
    local name = face and Hearth.sprite(look, face)
    if name and fire:getSprite():getName() ~= name then fire:setSprite(getSprite(name)) end
    if look ~= before then
        print(string.format("[TP] hearth copper %s -> %s: %.1f L %s at %.1f C", before, look, (copper.ml or 0) / 1000,
            tostring(copper.fluid), copper.tempC or 0))
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
})

World.track = tracker.track

-- Redraws a tracked hearth now, without waiting for the next tick, e.g. after a pour.
function World.refresh(fire)
    if tracker.track(fire) then refresh(fire) end
end

-- Every tracked hearth that is loaded, for the dev consoles.
function World.hearths()
    local list = {}
    for object in pairs(tracker.tracked) do
        if Station.isLoaded(object) then table.insert(list, object) end
    end
    return list
end

-- A hearth just built or put down isn't known to the map loader: the squares round each player are looked over
-- twice a second, so a new one shows its copper at once.
local NEAR = 3
local SCAN_TICKS = 30
local scanTicks = 0

local function players()
    if isServer() then return getOnlinePlayers() end
    local list = ArrayList.new()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then list:add(player) end
    end
    return list
end

local function scanNear(player)
    local cell, px, py, z = getCell(), math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    for x = px - NEAR, px + NEAR do
        for y = py - NEAR, py + NEAR do
            local square = cell:getGridSquare(x, y, z)
            local objects = square and square:getObjects()
            for i = 0, objects and objects:size() - 1 or -1 do
                local object = objects:get(i)
                if not tracker.entry(object) and Hearth.isHearth(object) then World.refresh(object) end
            end
        end
    end
end

Events.OnTick.Add(function()
    scanTicks = scanTicks + 1
    if scanTicks < SCAN_TICKS then return end
    scanTicks = 0
    local list = players()
    for i = 0, list:size() - 1 do scanNear(list:get(i)) end
end)

Weather.record(function(now, climate)
    Weather.advance(World.getLedger(), now, climate:getTemperature(), KINDS)
end)

tracker.start()

return World
