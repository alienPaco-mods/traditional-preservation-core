-- Traditional Preservation (Core): commands for the debug Lua console, loaded only in debug mode. They work on the
-- core's shared stations (the Hearth), whichever TP mods are on. Type TPC.help() in the console for the list.
if not isDebugEnabled() then return end

local Hearth = require "TraditionalPreservationCore/Hearth"
TPC = {}

local function say(text) print("[TPC] " .. text) end

function TPC.help()
    say("TPC.kit()            a mason's trowel, 12 clay bricks, 4 clay and a copper sheet, to build a Hearth (Masonry 2)")
    say("TPC.hearth()         the nearest Hearth within 2 tiles: fire (lit, banked or out), fuel, copper, when it steams")
    say("TPC.copper(l, c, f)  fill its copper: l litres (0 empties it) of fluid f at c degrees (default 10 L CowMilk at 20 C; it holds 20)")
    say("TPC.fuel(minutes)    set its fuel (default 600, ten hours); vanilla's menu still lights it")
    say("TPC.hot()            bring its copper to the steam (90 C) now")
    say("TPC.probe(r, c)      PROBE: put the Hearth's vanilla fire out, add our own heat (r tiles, c C; default 2, 25),")
    say("                     a faint light, and keep its firebox at a lit fire's heat; TPC.unprobe() undoes it")
    say("TPC.probeRead()      PROBE: air C and light by the Hearth and on your square, firebox heat, each food's cooking")
end

function TPC.kit()
    local inventory = getPlayer():getInventory()
    inventory:AddItem("Base.MasonsTrowel_Wood")
    for _ = 1, 12 do inventory:AddItem("Base.ClayBrick") end
    for _ = 1, 4 do inventory:AddItem("Base.Clay") end
    inventory:AddItem("Base.CopperSheet")
    say("Gave a mason's trowel, 12 clay bricks, 4 clay and a copper sheet, to build a Hearth (Masonry 2).")
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
    say(string.format("%d,%d,%d %s, fuel %d min, sprite %s; copper %.1f L %s at %.1f C (%s), steaming %s, fire until %s",
        hearth:getX(), hearth:getY(), hearth:getZ(),
        Hearth.isBanked(hearth) and string.format("banked (%.1f min reckoned)", copper.fuel or 0)
            or hearth:isLit() and "lit" or "out", hearth:getFuelAmount(),
        hearth:getSprite():getName(), (copper.ml or 0) / 1000, tostring(copper.fluid), copper.tempC or 0, Hearth.look(copper),
        hotIn and string.format("in %.1f h", hotIn) or "never", copper.fireUntil and string.format("%.2f", copper.fireUntil) or "-"))
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

function TPC.fuel(minutes)
    local hearth = nearestHearth()
    if not hearth then return end
    hearth:setFuelAmount(minutes or 600)
    TPC.hearth()
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

-- Probe for the banked Hearth (ROADMAP section 4), not a feature: the vanilla fire put out, our own heat source and
-- light in its place, and the firebox kept at a lit fire's heat with a custom temperature. Nothing here is saved.

local probe = {}

function TPC.unprobe()
    local cell = getCell()
    if probe.heat then cell:removeHeatSource(probe.heat) end
    if probe.light then cell:removeLamppost(probe.light) end
    local hearth = probe.hearth
    if hearth then
        hearth:getContainer():setCustomTemperature(0)
        if hearth:hasFuel() then hearth:turnOn() end
        say("Probe undone: the vanilla fire lit again, our heat and light gone, the firebox back to vanilla's heat.")
    end
    probe = {}
end

function TPC.probe(radius, celsius)
    local hearth = nearestHearth()
    if not hearth then return end
    TPC.unprobe()
    radius, celsius = radius or 2, celsius or 25
    local x, y, z = hearth:getX(), hearth:getY(), hearth:getZ()
    local cell = getCell()
    -- setLit, not extinguish: extinguish lets it smoulder (burning fuel) for ten minutes.
    hearth:setLit(false)
    local heat = IsoHeatSource.new(x, y, z, radius, celsius)
    cell:addHeatSource(heat)
    local light = cell:addLamppost(x, y, z, 0.6, 0.25, 0.1, math.max(1, radius - 1))
    local container = hearth:getContainer()
    container:setCustomTemperature(1.8)
    container:addItemsToProcessItems()
    probe = { hearth = hearth, heat = heat, light = light }
    say(string.format("Probe on: vanilla fire out, heat %d tiles at %d C, light %d, firebox custom temperature %.1f.",
        radius, celsius, math.max(1, radius - 1), container:getCustomTemperature()))
    TPC.probeRead()
end

local function squareLine(label, square, playerNum)
    if not square then return end
    say(string.format("  %-14s air %.1f C, light %.2f", label,
        getClimateManager():getAirTemperatureForSquare(square), square:getLightLevel(playerNum)))
end

function TPC.probeRead()
    local hearth = probe.hearth or nearestHearth()
    if not hearth then return end
    local player = getPlayer()
    local playerNum = player:getPlayerNum()
    local cell = getCell()
    local x, y, z = hearth:getX(), hearth:getY(), hearth:getZ()
    say(string.format("Hearth %s, vanilla fuel %d min, firebox %.2f (custom %.2f), probe %s",
        hearth:isLit() and "lit" or "out", hearth:getFuelAmount(), hearth:getContainer():getTemperature(),
        hearth:getContainer():getCustomTemperature(), probe.hearth and "on" or "off"))
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

say("Debug commands loaded. Type TPC.help() in the Lua console.")
