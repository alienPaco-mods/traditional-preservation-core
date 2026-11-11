-- Traditional Preservation (Core): commands for the debug Lua console, loaded only in debug mode. They work on the
-- core's shared stations (the Hearth), whichever TP mods are on. Type TPC.help() in the console for the list.
if not isDebugEnabled() then return end

local Hearth = require "TraditionalPreservationCore/Hearth"
TPC = {}

local function say(text) print("[TPC] " .. text) end

function TPC.help()
    say("TPC.kit()            a mason's trowel, 12 clay bricks, 4 clay and a copper sheet, to build a Hearth (Masonry 2)")
    say("TPC.hearth()         the nearest Hearth within 2 tiles: fire (lit, banked or out), fuel, copper, when it steams")
    say("TPC.copper(l, c, f)  fill its copper: l litres (0 empties it) of fluid f at c degrees (default 10 L CowMilk at 20 C; it holds 60; f TaintedWater to boil)")
    say("TPC.fuel(minutes)    set the nearest Hearth's or Firebox's fuel (default 600, ten hours; banked, what the embers have left); vanilla's menu still lights it")
    say("TPC.hot()            bring its copper to the steam (90 C) now")
    say("TPC.warmth()         air C and light 1-6 tiles east of the Hearth and on your square, firebox heat, each food's cooking")
    say("TPC.fireboxKit()     a mason's trowel, 8 clay bricks and 2 clay, to build a Firebox (Masonry 2)")
    say("TPC.firebox()        the nearest Firebox within 2 tiles: fire, fuel, flue and the squares on its flue's sides")
    say("TPC.flue(kind, side) show its flue: kind Pipe or Stones, side Back, Left or Right; no kind caps it (art check only)")
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

function TPC.fireboxKit()
    local inventory = getPlayer():getInventory()
    inventory:AddItem("Base.MasonsTrowel_Wood")
    for _ = 1, 8 do inventory:AddItem("Base.ClayBrick") end
    for _ = 1, 2 do inventory:AddItem("Base.Clay") end
    say("Gave a mason's trowel, 8 clay bricks and 2 clay, to build a Firebox (Masonry 2).")
end

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

say("Debug commands loaded. Type TPC.help() in the Lua console.")
