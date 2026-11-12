-- Traditional Preservation (Core): commands for the debug Lua console, loaded only in debug mode. They work on the
-- core's shared stations (the Hearth), whichever TP mods are on. Type TPC.help() in the console for the list.
if not isDebugEnabled() then return end

local Hearth = require "TraditionalPreservationCore/Hearth"
local Weather = require "TraditionalPreservationCore/Weather"
TPC = {}

local function say(text) print("[TPC] " .. text) end

function TPC.help()
    say("TPC.weather()        the series' weather: temperature now, the season's mean, and each place's temperature")
    say("TPC.here()           which place you're standing in, and its temperature")
    say("TPC.speed(x)         game speed: the clock x times as fast (vanilla's buttons are 1, 5, 20, 40 and set it back); no x shows it")
    say("TPC.kit(kind)        what a station takes to build: \"hearth\" (the default) or \"firebox\" (Masonry 2). TPC.kit(\"?\") lists them")
    say("TPC.hearth()         the nearest Hearth within 2 tiles: fire (lit, banked or out), fuel, copper, when it steams")
    say("TPC.copper(l, c, f)  fill its copper: l litres (0 empties it) of fluid f at c degrees (default 10 L CowMilk at 20 C; it holds 60; f TaintedWater to boil)")
    say("TPC.fuel(minutes)    set the nearest Hearth's or Firebox's fuel (default 600, ten hours; banked, what the embers have left); vanilla's menu still lights it")
    say("TPC.hot()            bring its copper to the steam (90 C) now")
    say("TPC.warmth()         air C and light 1-6 tiles east of the Hearth and on your square, firebox heat, each food's cooking")
    say("TPC.firebox()        the nearest Firebox within 2 tiles: fire, fuel, flue and the squares on its flue's sides")
    say("TPC.flue(kind, side) show its flue: kind Pipe or Stones, side Back, Left or Right; no kind caps it (art check only)")
    say("TPC.doors()          the tile you stand on: may a door facing S or E open there, and does a door open onto it")
end

-- What building each of the core's stations takes.
local KITS = {
    hearth = { about = "a mason's trowel, 12 clay bricks, 4 clay and a copper sheet, to build a Hearth (Masonry 2)",
        ["Base.MasonsTrowel_Wood"] = 1, ["Base.ClayBrick"] = 12, ["Base.Clay"] = 4, ["Base.CopperSheet"] = 1 },
    firebox = { about = "a mason's trowel, 8 clay bricks and 2 clay, to build a Firebox (Masonry 2)",
        ["Base.MasonsTrowel_Wood"] = 1, ["Base.ClayBrick"] = 8, ["Base.Clay"] = 2 },
}

function TPC.kit(kind)
    local kit = KITS[kind or "hearth"]
    if not kit then
        for name, entry in pairs(KITS) do say("TPC.kit(\"" .. name .. "\"): " .. entry.about) end
        return
    end
    local inventory = getPlayer():getInventory()
    for fullType, count in pairs(kit) do
        if fullType ~= "about" then
            for _ = 1, count do inventory:AddItem(fullType) end
        end
    end
    say("Gave " .. kit.about .. ".")
end

-- The series' weather, as every TP mod reads it: the temperature now, the season's mean, and each place's.
function TPC.weather()
    local state = Weather.shared()
    say(string.format("Temperature now %.1f C, season (10-day average) %.1f C, ground (the season a month behind) %.1f C, season humidity %.0f%%.",
        state.temperature or 0, state.seasonTemperature or 0, state.groundTemperature or state.seasonTemperature or 0,
        (state.seasonHumidity or 0) * 100))
    for _, place in ipairs(Weather.PLACES) do
        say(string.format("%-9s %.1f C", place, Weather.placeTemperature(state, place)))
    end
    say(string.format("By a fire %d C, by banked embers %d C (within %d tiles; the mods that ask for it).", Hearth.FIRE_C,
        Hearth.EMBERS_C, Hearth.FIRE_RADIUS))
end

-- Where the player stands, as a station there would read it.
function TPC.here()
    local player = getPlayer()
    local place = Hearth.placeOf(player)
    say(string.format("You're in: %s (%.1f C); with roofs told from rooms: %s.", tostring(place),
        Hearth.placeTemperature(Weather.shared(), place), tostring(Weather.placeOf(player))))
end

-- Game speed, past vanilla's 40 at the fastest button: getGameTime():setMultiplier(x). Clicking a speed button
-- sets vanilla's own again.
function TPC.speed(x)
    local time = getGameTime()
    if x then time:setMultiplier(x) end
    say(string.format("Game speed x%g.", time:getTrueMultiplier()))
end

-- Hearth

local function nearestHearth()
    local hearth = Hearth.hearthsNear(getPlayer():getSquare())[1]
    if not hearth then say("No Hearth within 2 tiles.") end
    if hearth and Hearth.World then Hearth.World.track(hearth) end
    return hearth
end

function TPC.hearth()
    local hearth = nearestHearth()
    if not hearth then return end
    local copper = Hearth.copperOf(hearth)
    local hotIn = Hearth.hoursToHot(copper)
    say(string.format("%d,%d,%d %s, fuel %d min, sprite %s; copper %.1f L %s at %.1f C (%s), steaming %s, fire until %s, at the boil %.0f min",
        hearth:getX(), hearth:getY(), hearth:getZ(),
        Hearth.isBanked(hearth) and string.format("banked (%.1f min reckoned)", copper.fuel or 0)
            or hearth:isLit() and "lit" or "out", hearth:getFuelAmount(),
        hearth:getSprite():getName(), (copper.ml or 0) / 1000, tostring(copper.fluid), copper.tempC or 0, Hearth.look(copper),
        hotIn and string.format("in %.1f h", hotIn) or "never", copper.fireUntil and string.format("%.2f", copper.fireUntil) or "-",
        (copper.boiled or 0) * 60))
end

function TPC.copper(litres, celsius, fluid)
    local hearth = nearestHearth()
    if not hearth then return end
    local copper = Hearth.copperOf(hearth)
    Hearth.take(copper)
    litres = litres or 10
    if litres > 0 then Hearth.pourInto(copper, fluid or "CowMilk", math.floor(litres * 1000), celsius or 20, getGameTime():getWorldAgeHours()) end
    Hearth.World.refresh(hearth)
    TPC.hearth()
end

-- The nearest Hearth or Firebox: TPC.fuel works on either.
function TPC.fuel(minutes)
    local fire = Hearth.near(getPlayer():getSquare(), Hearth.isFire)[1]
    if not fire then return say("No Hearth or Firebox within 2 tiles.") end
    if Hearth.World then Hearth.World.track(fire) end
    minutes = minutes or 600
    fire:setFuelAmount(minutes)
    local state = Hearth.copperOf(fire)
    if state.banked then Hearth.setBanked(state, true, minutes, getGameTime():getWorldAgeHours()) end
    if Hearth.isFirebox(fire) then TPC.firebox() else TPC.hearth() end
end

function TPC.hot()
    local hearth = nearestHearth()
    if not hearth then return end
    local copper = Hearth.copperOf(hearth)
    if (copper.ml or 0) <= 0 then return say("The copper is empty: TPC.copper() first.") end
    copper.tempC = 90
    Hearth.World.refresh(hearth)
    TPC.hearth()
end

local function squareLine(label, square, playerNum)
    if not square then return end
    say(string.format("  %-14s air %.1f C, light %.2f", label,
        getClimateManager():getAirTemperatureForSquare(square), square:getLightLevel(playerNum)))
end

-- What a lit or banked Hearth warms and lights round it, and how its firebox cooks.
function TPC.warmth()
    local hearth = nearestHearth()
    if not hearth then return end
    local player = getPlayer()
    local playerNum = player:getPlayerNum()
    local cell = getCell()
    local x, y, z = hearth:getX(), hearth:getY(), hearth:getZ()
    say(string.format("Hearth %s, vanilla fire %s, vanilla fuel %d min, firebox %.2f (custom %.2f)",
        Hearth.isBanked(hearth) and "banked" or hearth:isLit() and "lit" or "out", hearth:isLit() and "lit" or "out",
        hearth:getFuelAmount(), hearth:getContainer():getTemperature(), hearth:getContainer():getCustomTemperature()))
    for distance = 1, 6 do
        squareLine(distance .. " tile(s) east", cell:getGridSquare(x + distance, y, z), playerNum)
    end
    squareLine("your square", player:getSquare(), playerNum)
    say(string.format("  you: core %.2f C", player:getBodyDamage():getThermoregulator():getCoreTemperature()))
    local items = hearth:getContainer():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if instanceof(item, "Food") and item:isCookable() then
            say(string.format("  %s: heat %.2f, cooking %.1f / %.0f min, cooked %s, burnt %s", item:getDisplayName(),
                item:getHeat(), item:getCookingTime(), item:getMinutesToCook(), tostring(item:isCooked()), tostring(item:isBurnt())))
        end
    end
end

-- Firebox

local function nearestFirebox()
    local firebox = Hearth.near(getPlayer():getSquare(), Hearth.isFirebox)[1]
    if not firebox then say("No Firebox within 2 tiles.") end
    if firebox and Hearth.World then Hearth.World.track(firebox) end
    return firebox
end

function TPC.firebox()
    local firebox = nearestFirebox()
    if not firebox then return end
    local state = Hearth.copperOf(firebox)
    local sides = {}
    for _, side in ipairs({ "Back", "Left", "Right" }) do
        local square = Hearth.flueSquare(firebox, side)
        table.insert(sides, string.format("%s %s", side, square and (square:getX() .. "," .. square:getY()) or "-"))
    end
    say(string.format("%d,%d,%d %s, fuel %d min, sprite %s, flue %s %s; sides: %s", firebox:getX(), firebox:getY(),
        firebox:getZ(), Hearth.isBanked(firebox) and "banked" or firebox:isLit() and "lit" or "out", firebox:getFuelAmount(),
        firebox:getSprite():getName(), tostring(state.flue), tostring(state.flueSide), table.concat(sides, ", ")))
end

function TPC.flue(kind, side)
    local firebox = nearestFirebox()
    if not firebox then return end
    Hearth.setFlue(Hearth.copperOf(firebox), kind, side or "Back")
    Hearth.World.refresh(firebox)
    TPC.firebox()
end

function TPC.doors()
    local Doors = require "TraditionalPreservationCore/Doors"
    local square = getPlayer():getSquare()
    for _, facing in ipairs({ "S", "E" }) do
        local step = Doors.FRONT[facing]
        local front = getCell():getGridSquare(square:getX() + step[1], square:getY() + step[2], square:getZ())
        local blocker = front and Doors.blocker(front, facing)
        say(string.format("door facing %s: front %s %s", facing, front and (front:getX() .. "," .. front:getY()) or "none",
            blocker and ("blocked by " .. blocker) or "free"))
    end
    local door = Doors.doorOnto(square)
    say(door and ("a door opens onto this tile: " .. door) or "no registered door opens onto this tile")
end

say("Debug commands loaded. Type TPC.help() in the Lua console.")
