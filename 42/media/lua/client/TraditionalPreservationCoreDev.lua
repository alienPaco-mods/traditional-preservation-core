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

say("Debug commands loaded. Type TPC.help() in the Lua console.")
