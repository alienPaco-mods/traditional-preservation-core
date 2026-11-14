-- Traditional Preservation (Core): commands for the debug Lua console, loaded only in debug mode. They work on the
-- core's shared stations (the Stone Hearth, the Smokehouse), whichever TP mods are on. Type TPC.help() in the console for the list.
if not isDebugEnabled() then return end

local Hearth = require "TraditionalPreservationCore/Hearth"
require "TraditionalPreservationCore/Cauldron"
local Weather = require "TraditionalPreservationCore/Weather"
local Smokehouse = require "TraditionalPreservationCore/Smokehouse"
TPC = {}

local function say(text) print("[TPC] " .. text) end

function TPC.help()
    say("TPC.weather()        the series' weather: temperature now, the season's mean, and each place's temperature")
    say("TPC.here()           which place you're standing in, and its temperature")
    say("TPC.setWeather(c, season, ground) pretend the weather: the day's temperature (the engine's override), the season's mean (default c) and the ground's (default: left alone). The mods read it at the next ten game minutes. TPC.setWeather() ends it")
    say("TPC.speed(x)         game speed: the clock x times as fast (vanilla's buttons are 1, 5, 20, 40 and set it back); no x shows it")
    say("TPC.kit(kind)        what a station takes to build: \"hearth\" (the default: the Stone Hearth and Fit Cauldron's kit), \"firebox\" (the Stone Hearth, Masonry 2), \"cauldron\" (Fit Cauldron: the Forged Cauldron, 2 metal pipes, a heavy chain, a large hook and pliers), \"forge\" (Forge the cauldron at a forge, Blacksmith 4, and the magazine that teaches it), \"smokehouse\" (Woodwork 3), \"flue\" (both flue kits and their tools) or \"hole\" (a stove food, an oven food and a pot to fill, for the hole's looks). TPC.kit(\"?\") lists them")
    say("TPC.cauldronInfo()   the nearest Stone Hearth with the Cauldron within 2 tiles: fire (lit, banked or out), fuel, the cauldron, when it steams")
    say("TPC.cauldron(l, c, f) fill its cauldron: l litres (0 empties it) of fluid f at c degrees (default 10 L CowMilk at 20 C; it holds 60; f TaintedWater to boil)")
    say("TPC.fuel(minutes)    set the nearest Stone Hearth's fuel, fitted or not (default 600, ten hours; banked, what the embers have left); vanilla's menu still lights it")
    say("TPC.hot(minutes)     bring its cauldron to the steam (90 C) now, counted as steaming that long (60; 0 to watch a hold)")
    say("TPC.warmth()         air C and light 1-6 tiles east of the Stone Hearth (Cauldron) and on your square, firebox heat, each food's cooking")
    say("TPC.stone()          the nearest Stone Hearth within 2 tiles, fitted or not: fire, fuel, what is fitted, what is joined (its kit and side), hole look and the squares on its back and flanks")
    say("TPC.fit()            fit the Cauldron on the nearest Stone Hearth now, no items (TPC.fit(false) takes off what is fitted, nothing back)")
    say("TPC.flue(kind, side) show its flue: kind Pipe or Stones, side Back, Left or Right; no kind caps it (art check only)")
    say("TPC.smokehouse()     each Smokehouse tile within 3 tiles: facing, part, the Stone Hearths beside it and why each can't join")
    say("TPC.doors()          the tile you stand on: may a door facing S or E open there, and does a door open onto it")
end

-- What building each of the core's stations takes.
local KITS = {
    hearth = { about = "a mason's trowel, 8 clay bricks and 2 clay, to build a Stone Hearth (Masonry 2), and Fit "
        .. "Cauldron's kit: the Forged Cauldron, 2 metal pipes, a heavy chain, a large hook and pliers",
        ["Base.MasonsTrowel_Wood"] = 1, ["Base.ClayBrick"] = 8, ["Base.Clay"] = 2, [Hearth.CAULDRON_ITEM] = 1,
        ["Base.MetalPipe"] = 2, ["Base.HeavyChain"] = 1, ["Base.LargeHook"] = 1, ["Base.Pliers"] = 1 },
    cauldron = { about = "Fit Cauldron's kit: the Forged Cauldron, 2 metal pipes, a heavy chain, a large hook and pliers",
        [Hearth.CAULDRON_ITEM] = 1, ["Base.MetalPipe"] = 2, ["Base.HeavyChain"] = 1, ["Base.LargeHook"] = 1, ["Base.Pliers"] = 1 },
    forge = { about = "2 sheet metal, 3 charcoal, wire, a ball-peen hammer, tongs and a metalworking chisel to forge the "
        .. "cauldron (Blacksmith 4, at a forge), and the magazine that teaches it (Smithing Magazine Vol. 2)",
        ["Base.SheetMetal"] = 2, ["Base.Charcoal"] = 3, ["Base.Wire"] = 1, ["Base.BallPeenHammer"] = 1, ["Base.Tongs"] = 1,
        ["Base.MetalworkingChisel"] = 1, ["Base.SmithingMag2"] = 1 },
    firebox = { about = "a mason's trowel, 8 clay bricks and 2 clay, to build a Stone Hearth (Masonry 2)",
        ["Base.MasonsTrowel_Wood"] = 1, ["Base.ClayBrick"] = 8, ["Base.Clay"] = 2 },
    hole = { about = "a Pot of Stew (stove food), an uncooked pie (oven food) and an empty Cooking Pot to fill with water",
        ["Base.PotOfStew"] = 1, ["Base.PieWholeRaw"] = 1, ["Base.Pot"] = 1 },
    smokehouse = { about = "a hammer, 14 planks and 20 nails, to build a Smokehouse (Woodwork 3)",
        ["Base.Hammer"] = 1, ["Base.Plank"] = 14, ["Base.Nails"] = 20 },
    flue = { about = "both flue kits (2 Clay Pipe Segments, 3 Flat Stones, 3 Clay), a Mason's Trowel and a Shovel",
        ["Base.ClayPipeSegment"] = 2, ["Base.FlatStone"] = 3, ["Base.Clay"] = 3, ["Base.MasonsTrowel"] = 1, ["Base.Shovel"] = 1 },
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
    say(string.format("By a fire indoors %d C, by banked embers %d C (within %d tiles; the mods that ask for it).",
        Hearth.FIRE_C, Hearth.EMBERS_C, Hearth.FIRE_RADIUS))
    for _, under in ipairs({ "Covered", "Open" }) do
        say(string.format("By a fire, %s: %.1f C, by banked embers %.1f C.", under,
            Weather.placeTemperature(state, Hearth.PLACE .. under), Weather.placeTemperature(state, Hearth.EMBERS .. under)))
    end
end

-- Where the player stands, as a station there would read it.
function TPC.here()
    local player = getPlayer()
    local place = Hearth.placeOf(player)
    say(string.format("You're in: %s (%.1f C); with roofs told from rooms: %s.", tostring(place),
        Weather.placeTemperature(Weather.shared(), place), tostring(Weather.placeOf(player))))
end

-- Pretends the weather for a test that wants a cold month or a warm day. The day's temperature goes through the
-- engine's own override (the debug menu's Climate debugger sets the same one), so every mod's next reading and the
-- player feel it; the season's mean and the ground's are the series' own and are set outright. The season then
-- drifts towards the day again, as it would. Not saved by the engine: set it again after a load.
function TPC.setWeather(celsius, season, ground)
    local temperature = getClimateManager():getClimateFloat(ClimateManager.FLOAT_TEMPERATURE)
    if not celsius then
        temperature:setEnableAdmin(false)
        return say("Weather override off: the day's temperature is the game's again, and the season's mean follows it over about ten days.")
    end
    temperature:setEnableAdmin(true)
    temperature:setAdminValue(celsius)
    local state = Weather.shared()
    state.seasonTemperature = season or celsius
    if ground then state.groundTemperature = ground end
    say(string.format("Weather set: %.1f C now, season %.1f C, ground %.1f C. The mods read it at the next ten game minutes (run the clock); TPC.weather() shows it then.",
        celsius, state.seasonTemperature, state.groundTemperature or state.seasonTemperature))
end

-- Game speed, past vanilla's 40 at the fastest button: getGameTime():setMultiplier(x). Clicking a speed button
-- sets vanilla's own again.
function TPC.speed(x)
    local time = getGameTime()
    if x then time:setMultiplier(x) end
    say(string.format("Game speed x%g.", time:getTrueMultiplier()))
end

-- The Stone Hearth with the Cauldron fitted

local function nearestHearth()
    local hearth = Hearth.fittedNear(getPlayer():getSquare(), Hearth.CAULDRON)[1]
    if not hearth then say("No Stone Hearth with the Cauldron within 2 tiles.") end
    if hearth and Hearth.World then Hearth.World.track(hearth) end
    return hearth
end

function TPC.cauldronInfo()
    local hearth = nearestHearth()
    if not hearth then return end
    local cauldron = Hearth.cauldronOf(hearth)
    local state = Hearth.stateOf(hearth:getModData())
    local hotIn = Hearth.hoursToHot(cauldron, state.banked)
    say(string.format("%d,%d,%d %s, fuel %d min, sprite %s; cauldron %.1f L %s at %.1f C (%s), steaming %s, fire until %s, at the boil %.0f min",
        hearth:getX(), hearth:getY(), hearth:getZ(),
        Hearth.isBanked(hearth) and string.format("banked (%.1f min reckoned)", state.fuel or 0)
            or hearth:isLit() and "lit" or "out", hearth:getFuelAmount(),
        hearth:getSprite():getName(), (cauldron.ml or 0) / 1000, tostring(cauldron.fluid), cauldron.tempC or 0, Hearth.look(cauldron),
        hotIn and string.format("in %.1f h", hotIn) or "never", state.fireUntil and string.format("%.2f", state.fireUntil) or "-",
        (cauldron.boiled or 0) * 60))
end

function TPC.cauldron(litres, celsius, fluid)
    local hearth = nearestHearth()
    if not hearth then return end
    local cauldron = Hearth.cauldronOf(hearth)
    Hearth.take(cauldron)
    litres = litres or 10
    if litres > 0 then Hearth.pourInto(cauldron, fluid or "CowMilk", math.floor(litres * 1000), celsius or 20, getGameTime():getWorldAgeHours()) end
    Hearth.World.refresh(hearth)
    TPC.cauldronInfo()
end

-- The nearest Stone Hearth: TPC.fuel works fitted or not.
function TPC.fuel(minutes)
    local fire = Hearth.near(getPlayer():getSquare(), Hearth.isFire)[1]
    if not fire then return say("No Stone Hearth within 2 tiles.") end
    if Hearth.World then Hearth.World.track(fire) end
    minutes = minutes or 600
    fire:setFuelAmount(minutes)
    local state = Hearth.fireStateOf(fire)
    if state.banked then Hearth.setBanked(state, true, minutes, getGameTime():getWorldAgeHours()) end
    if Hearth.isFirebox(fire) then TPC.stone() else TPC.cauldronInfo() end
end

-- minutes: how long it counts as having steamed already (an hour if left out; 0 to watch a hold such as Dairy's
-- 20-minute scald count up).
function TPC.hot(minutes)
    local hearth = nearestHearth()
    if not hearth then return end
    local cauldron = Hearth.cauldronOf(hearth)
    if (cauldron.ml or 0) <= 0 then return say("The cauldron is empty: TPC.cauldron() first.") end
    cauldron.tempC = 90
    cauldron.held = (minutes or 60) / 60
    Hearth.World.refresh(hearth)
    TPC.cauldronInfo()
end

local function squareLine(label, square, playerNum)
    if not square then return end
    say(string.format("  %-14s air %.1f C, light %.2f", label,
        getClimateManager():getAirTemperatureForSquare(square), square:getLightLevel(playerNum)))
end

-- What a lit or banked Stone Hearth (Cauldron) warms and lights round it, and how its firebox cooks.
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

-- Any Stone Hearth, fitted or not: its flue is its own.
local function nearestFirebox()
    local firebox = Hearth.near(getPlayer():getSquare(), Hearth.isFire)[1]
    if not firebox then say("No Stone Hearth within 2 tiles.") end
    if firebox and Hearth.World then Hearth.World.track(firebox) end
    return firebox
end

function TPC.stone()
    local firebox = nearestFirebox()
    if not firebox then return end
    local state = Hearth.fireStateOf(firebox)
    local sides = {}
    for _, side in ipairs({ "Back", "Left", "Right" }) do
        local square = Hearth.flueSquare(firebox, side)
        table.insert(sides, string.format("%s %s", side, square and (square:getX() .. "," .. square:getY()) or "-"))
    end
    local container = firebox:getContainer()
    say(string.format("%d,%d,%d %s, fuel %d min, sprite %s, fitted %s, joined %s %s, hole %s; sides: %s", firebox:getX(), firebox:getY(),
        firebox:getZ(), Hearth.isBanked(firebox) and "banked" or firebox:isLit() and "lit" or "out", firebox:getFuelAmount(),
        firebox:getSprite():getName(), tostring(Hearth.attachedTo(firebox)), tostring(Hearth.connectedTo(state)),
        table.concat({ Hearth.joinOf(state) }, " "),
        Hearth.holeLook(container and container:getItems()), table.concat(sides, ", ")))
end

-- Fits the Cauldron on the nearest Stone Hearth at once, or with false takes off what is fitted.
function TPC.fit(on)
    local fire = nearestFirebox()
    if not fire then return end
    if on == false then Hearth.unfit(fire) else Hearth.fit(fire, Hearth.CAULDRON) end
    Hearth.World.refresh(fire)
    TPC.stone()
end

function TPC.flue(kind, side)
    local firebox = nearestFirebox()
    if not firebox then return end
    local state = Hearth.fireStateOf(firebox)
    if kind then Hearth.join(state, Smokehouse.ID, kind, side or "Back") else Hearth.unjoin(state) end
    Hearth.World.refresh(firebox)
    TPC.stone()
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

local PARTS = { [0] = "back", [1] = "door" }

function TPC.smokehouse()
    local player, seen = getPlayer(), 0
    local cell, x, y, z = getCell(), math.floor(player:getX()), math.floor(player:getY()), player:getZ()
    for dx = -3, 3 do
        for dy = -3, 3 do
            local tile, face, part = Smokehouse.chamberOn(cell:getGridSquare(x + dx, y + dy, z))
            if tile then
                seen = seen + 1
                local lines = {}
                for _, found in ipairs(Smokehouse.fireboxesBy(tile)) do
                    if found.tile == tile then
                        local flue, side = Smokehouse.flueOf(found.firebox)
                        table.insert(lines, string.format("Stone Hearth at %d,%d: flue %s %s, %s", found.firebox:getX(), found.firebox:getY(),
                            tostring(flue), tostring(side), Smokehouse.joinedChamber(found.firebox) == tile and "joined here"
                            or (Smokehouse.connectRefusalFor(found) or "may join")))
                    end
                end
                say(string.format("%d,%d facing %s, %s tile, entry art %s; %s", tile:getX(), tile:getY(), face == 0 and "S" or "E",
                    PARTS[part], tostring(Smokehouse.chamberEntry(tile)), #lines > 0 and table.concat(lines, "; ") or "no Stone Hearth beside it"))
            end
        end
    end
    if seen == 0 then say("No Smokehouse within 3 tiles on this floor.") end
end

say("Debug commands loaded. Type TPC.help() in the Lua console.")
