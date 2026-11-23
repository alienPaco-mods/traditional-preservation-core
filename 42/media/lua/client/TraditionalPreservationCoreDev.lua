-- Traditional Preservation (Core): commands for the debug Lua console, loaded only in debug mode. They work on the
-- core's shared stations (the Stone Hearth, the Smokehouse), whichever TP mods are on. Type TPC.help() in the console for the list.
if not isDebugEnabled() then return end

local Fire = require "TraditionalPreservationCore/Fire"
local StoneHearth = require "TraditionalPreservationCore/StoneHearth"
local Cauldron = require "TraditionalPreservationCore/Cauldron"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
local FireConnect = require "TraditionalPreservationCore/FireConnect"
local Doors = require "TraditionalPreservationCore/Doors"
local Weather = require "TraditionalPreservationCore/Weather"
local Windows = require "TraditionalPreservationCore/Windows"
local Smokehouse = require "TraditionalPreservationCore/Smokehouse"

local DryingCloth = require "TraditionalPreservationCore/DryingCloth"
TPC = {}

local HOT_TEST_C = 90   -- TPC.hot's steam: above CauldronFluid.HOT_C, so it shows Hot at once
local CLOTH_RADIUS = 3
local DAY_KCAL = 2500   -- TPC.food and TPC.crops: a day's food, the long save's ledger figure
local FOOD_RADIUS = 1

local function say(text) print("[TPC] " .. text) end

function TPC.help()
    say("TPC.weather()        the series' weather: temperature now, the season's mean, and each place's temperature")
    say("TPC.here()           which place you're standing in, and its temperature")
    say(string.format("TPC.windows()        walk from where you stand to the open air, now: aired or shut (open air within %d steps, through open doors and gaps), squares read, engine calls, milliseconds", Windows.AIR_STEPS))
    say("TPC.setWeather(c, season, ground) pretend the weather: the day's temperature (the engine's override), the season's mean and the rooms' (default c) and the ground's (default: left alone). The mods read it at the next ten game minutes. TPC.setWeather() ends it")
    say("TPC.speed(x)         game speed: the clock x times as fast (vanilla's buttons are 1, 5, 20, 40 and set it back); no x shows it")
    say("TPC.kit(kind)        what a station takes to build: \"stoneCauldron\" (the default: the Stone Hearth and Fit Cauldron's kit), \"stone\" (the Stone Hearth, Masonry 2), \"cauldron\" (Fit Cauldron: the Forged Cauldron, 2 metal pipes, a heavy chain, a large hook and pliers), \"forge\" (Forge the cauldron at a forge, Blacksmith 4, and the magazine that teaches it), \"smokehouse\" (Woodwork 5, 2 large hooks), \"flue\" (both flue kits and their tools) or \"hole\" (a stove food, an oven food and a pot to fill, for the hole's looks). TPC.kit(\"?\") lists them")
    say(string.format("TPC.cauldronInfo()   the nearest Stone Hearth with the Cauldron within %d tiles: fire (lit, banked or out), fuel, the cauldron, when it steams", Fire.FIRE_RADIUS))
    say(string.format("TPC.cauldron(l, c, f) fill its cauldron: l litres (0 empties it) of fluid f at c degrees (default 10 L CowMilk at 20 C; it holds %g; f TaintedWater to boil)", CauldronFluid.CAULDRON_ML / 1000))
    say("TPC.fuel(minutes)    set the nearest Stone Hearth's fuel, fitted or not (default 600, ten hours; banked, what the embers have left); vanilla's menu still lights it")
    say(string.format("TPC.hot(minutes)     bring its cauldron to the steam (%d C) now, counted as steaming that long (60; 0 to watch a hold)", HOT_TEST_C))
    say("TPC.warmth()         air C and light 1-6 tiles east of the Stone Hearth (Cauldron) and on your square, the Stone Hearth's heat, each food's cooking")
    say(string.format("TPC.stone()          the nearest Stone Hearth within %d tiles, fitted or not: fire, fuel, what is fitted, what is joined (its kit and side), hole look and the squares on its back and flanks", Fire.FIRE_RADIUS))
    say("TPC.fit()            fit the Cauldron on the nearest Stone Hearth now, no items (TPC.fit(false) takes off what is fitted, nothing back)")
    say("TPC.flue(kitName, side) show its flue: kitName Pipe or Stones, side Back, Left or Right; no kitName caps it (art check only)")
    say("TPC.smokehouse()     each Smokehouse tile within 3 tiles: facing, part, the Stone Hearths beside it and why each can't join")
    say("TPC.doors()          the tile you stand on: may a door facing S or E open there, and does a door open onto it")
    say(string.format("TPC.cloth()          each Drying Cloth within %d tiles: place, and each lot's kind, count, state, progress and hours left", CLOTH_RADIUS))
    say(string.format("TPC.dryCloth(hours)  every wet lot on the Drying Cloths within %d tiles dries this many hours at full speed (default 24)", CLOTH_RADIUS))
    say(string.format("TPC.food(r)          food on you and in containers within r tiles (default %d), summed by name and state: count, weight, kcal, hunger; totals, days at %d kcal, salt uses. Remembers each container for TPC.foodTotal()", FOOD_RADIUS, DAY_KCAL))
    say("TPC.foodTotal()      everything TPC.food() has read so far (each container as last seen) plus what is on you, summed; TPC.foodReset() forgets them")
    say("TPC.crops(r)         living crops within r tiles (default 60) by kind: plants, stages, ready dates, expected yield and its kcal, hunger and weight at Farming now")
    say("TPC.pieceList(n)     a sample info window with n made-up pieces (default 14) in Core's scrolling list, on the floor you stand on: scroll, sort switch, tabs, warnings, hover popups")
end

-- What building each of the core's stations takes ("stoneCauldron" is stone and cauldron together, below).
local KITS = {
    cauldron = { about = "Fit Cauldron's kit: the Forged Cauldron, 2 metal pipes, a heavy chain, a large hook and pliers",
        [Cauldron.ITEM] = 1, ["Base.MetalPipe"] = 2, ["Base.HeavyChain"] = 1, ["Base.LargeHook"] = 1, ["Base.Pliers"] = 1 },
    forge = { about = "2 sheet metal, 3 charcoal, wire, a ball-peen hammer, tongs and a metalworking chisel to forge the "
        .. "cauldron (Blacksmith 4, at a forge), and the magazine that teaches it (Smithing Magazine Vol. 2)",
        ["Base.SheetMetal"] = 2, ["Base.Charcoal"] = 3, ["Base.Wire"] = 1, ["Base.BallPeenHammer"] = 1, ["Base.Tongs"] = 1,
        ["Base.MetalworkingChisel"] = 1, ["Base.SmithingMag2"] = 1 },
    stone = { about = "a mason's trowel, 12 stone blocks and 12 clay, to build a Stone Hearth (Masonry 2)",
        ["Base.MasonsTrowel_Wood"] = 1, ["Base.StoneBlock"] = 12, ["Base.Clay"] = 12 },
    hole = { about = "a Pot of Stew (stove food), an uncooked pie (oven food) and an empty Cooking Pot to fill with water",
        ["Base.PotOfStew"] = 1, ["Base.PieWholeRaw"] = 1, ["Base.Pot"] = 1 },
    smokehouse = { about = "a hammer, 14 planks, 20 nails and 2 large hooks, to build a Smokehouse (Woodwork 5)",
        ["Base.Hammer"] = 1, ["Base.Plank"] = 14, ["Base.Nails"] = 20, ["Base.LargeHook"] = 2 },
    cloth = { about = "a Sheet and 2 Stones, to make a Drying Cloth (Build menu, Furniture)",
        ["Base.Sheet"] = 1, ["Base.Stone2"] = 2 },
    flue = { about = "both flue kits (2 Clay Pipe Segments, 3 Flat Stones, 3 Clay), a Mason's Trowel and a Shovel",
        ["Base.ClayPipeSegment"] = 2, ["Base.FlatStone"] = 3, ["Base.Clay"] = 3, ["Base.MasonsTrowel"] = 1, ["Base.Shovel"] = 1 },
}

-- Kits put together: the items of each part, counts added, and their abouts joined.
local function joinKits(about, parts)
    local kit = { about = about }
    for _, part in ipairs(parts) do
        for fullType, count in pairs(KITS[part]) do
            if fullType ~= "about" then kit[fullType] = (kit[fullType] or 0) + count end
        end
    end
    return kit
end

KITS.stoneCauldron = joinKits(KITS.stone.about .. ", and " .. KITS.cauldron.about, { "stone", "cauldron" })

local KIT_NAMES = {}
for name in pairs(KITS) do table.insert(KIT_NAMES, name) end
table.sort(KIT_NAMES)

function TPC.kit(kind)
    local kit = KITS[kind or "stoneCauldron"]
    if not kit then
        for _, name in ipairs(KIT_NAMES) do say("TPC.kit(\"" .. name .. "\"): " .. KITS[name].about) end
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
    local weatherModData = Weather.weatherModData()
    say(string.format("Temperature now %.1f C, season (10-day average) %.1f C, ground (the season a month behind) %.1f C, season humidity %.0f%%.",
        weatherModData.temperature or 0, weatherModData.seasonTemperature or 0, weatherModData.groundTemperature or weatherModData.seasonTemperature or 0,
        (weatherModData.seasonHumidity or 0) * 100))
    for _, place in ipairs(Weather.PLACES) do
        say(string.format("%-9s %.1f C", place, Weather.placeTemperature(weatherModData, place)))
    end
    say(string.format("By a fire indoors %d C, by banked embers %d C (within %d tiles; the mods that ask for it).",
        Fire.FIRE_C, Fire.EMBERS_C, Fire.FIRE_RADIUS))
    for _, placeWithoutFire in ipairs({ "Covered", "Open" }) do
        say(string.format("By a fire, %s: %.1f C, by banked embers %.1f C.", placeWithoutFire,
            Weather.placeTemperature(weatherModData, Fire.PLACE .. placeWithoutFire), Weather.placeTemperature(weatherModData, Fire.EMBERS .. placeWithoutFire)))
    end
end

-- Where the player stands, as a station there would read it.
function TPC.here()
    local player = getPlayer()
    local place = Fire.placeOf(player)
    say(string.format("You're in: %s (%.1f C); with roofs told from rooms: %s.", tostring(place),
        Weather.placeTemperature(Weather.weatherModData(), place), tostring(Weather.placeOf(player))))
end

-- One fresh walk from where the player stands out to the open air, timed: what a station's look costs there once a
-- reading.
function TPC.windows()
    local square = getPlayer():getSquare()
    local start = getTimestampMs()
    local measured = square and Windows.measure(square)
    local took = getTimestampMs() - start
    if not measured then return say("Not in a room: nothing to walk.") end
    say(string.format("Here: %s. Walked %d indoor squares (open air within %d steps), about %d engine calls, in %d ms.",
        measured.aired and "aired (open air within reach)" or "shut", measured.squares, Windows.AIR_STEPS,
        measured.calls, took))
end

-- Pretends the weather for a test that wants a cold month or a warm day. The day's temperature goes through the
-- engine's own override (the debug menu's Climate debugger sets the same one), so every mod's next reading and the
-- player feel it; the season's mean and the ground's are the series' own and are set outright. The season then
-- drifts towards the day again, as it would. Not saved by the engine: set it again after a load.
function TPC.setWeather(celsius, season, ground)
    local temperature = getClimateManager():getClimateFloat(ClimateManager.FLOAT_TEMPERATURE)
    if not celsius then
        temperature:setEnableAdmin(false)
        return say("Weather override off: the day's temperature is the game's again; the rooms follow it over one to three days, the season's mean over about ten.")
    end
    temperature:setEnableAdmin(true)
    temperature:setAdminValue(celsius)
    local weatherModData = Weather.weatherModData()
    weatherModData.seasonTemperature = season or celsius
    -- A shut room's and an aired room's means start there too, as if the weather had held.
    weatherModData.threeDayTemperature, weatherModData.dayTemperature = season or celsius, season or celsius
    if ground then weatherModData.groundTemperature = ground end
    say(string.format("Weather set: %.1f C now, season and rooms %.1f C, ground %.1f C. The mods read it at the next ten game minutes (run the clock); TPC.weather() shows it then.",
        celsius, weatherModData.seasonTemperature, weatherModData.groundTemperature or weatherModData.seasonTemperature))
end

-- Game speed, past vanilla's 40 at the fastest button: getGameTime():setMultiplier(x). Clicking a speed button
-- sets vanilla's own again.
function TPC.speed(x)
    local time = getGameTime()
    if x then time:setMultiplier(x) end
    say(string.format("Game speed x%g.", time:getTrueMultiplier()))
end

-- The nearest Stone Hearth within FIRE_RADIUS, tracked by the World; with fitted (Cauldron.ID), only one with that
-- fitted, named in the message by label.
local function nearestFire(fitted, label)
    local square = getPlayer():getSquare()
    local fire = (fitted and Fire.fittedNear(square, fitted) or Fire.near(square, StoneHearth.isStoneHearth))[1]
    if not fire then
        say(string.format("No Stone Hearth%s within %d tiles.", label and (" with " .. label) or "", Fire.FIRE_RADIUS))
        return nil
    end
    Fire.World.track(fire)
    return fire
end

-- The Stone Hearth with the Cauldron fitted

local function nearestCauldron() return nearestFire(Cauldron.ID, "the Cauldron") end

function TPC.cauldronInfo()
    local fire = nearestCauldron()
    if not fire then return end
    local cauldron = Cauldron.of(fire)
    local fireModData = Fire.fireModData(fire:getModData())
    local hotIn = CauldronFluid.hoursToHot(cauldron, fireModData.banked)
    say(string.format("%d,%d,%d %s, fuel %d min, sprite %s; cauldron %.1f L %s at %.1f C (%s), steaming %s, fire until %s, at the boil %.0f min",
        fire:getX(), fire:getY(), fire:getZ(),
        Fire.isBanked(fire) and string.format("banked (%.1f min reckoned)", fireModData.fuel or 0)
            or fire:isLit() and "lit" or "out", fire:getFuelAmount(),
        fire:getSprite():getName(), (cauldron.ml or 0) / 1000, tostring(cauldron.fluid), cauldron.tempC or 0, CauldronFluid.look(cauldron),
        hotIn and string.format("in %.1f h", hotIn) or "never", fireModData.fireUntil and string.format("%.2f", fireModData.fireUntil) or "-",
        (cauldron.boiled or 0) * 60))
end

function TPC.cauldron(litres, celsius, fluid)
    -- A name the game has no fluid for went in as is and was never milk to Dairy (user, session 69: "Milk").
    if (litres ~= nil and type(litres) ~= "number") or (celsius ~= nil and type(celsius) ~= "number") then
        return say("TPC.cauldron(litres, celsius, fluid): numbers first, e.g. TPC.cauldron(20, 85, \"CowMilk\")")
    end
    if fluid and not Fluid.Get(fluid) then
        return say(string.format("No fluid named %s. Milk is CowMilk, SheepMilk or AnimalMilk; water Water or TaintedWater", tostring(fluid)))
    end
    local fire = nearestCauldron()
    if not fire then return end
    local cauldron = Cauldron.of(fire)
    CauldronFluid.take(cauldron)
    litres = litres or 10
    if litres > 0 then CauldronFluid.pourInto(cauldron, fluid or "CowMilk", math.floor(litres * 1000), celsius or 20, getGameTime():getWorldAgeHours()) end
    Fire.World.refresh(fire)
    TPC.cauldronInfo()
end

-- The nearest Stone Hearth: TPC.fuel works fitted or not.
function TPC.fuel(minutes)
    local fire = nearestFire()
    if not fire then return end
    minutes = minutes or 600
    fire:setFuelAmount(minutes)
    local fireModData = Fire.fireModDataNow(fire)
    if fireModData.banked then Fire.setBanked(fireModData, true, minutes, getGameTime():getWorldAgeHours()) end
    if Fire.isBare(fire) then TPC.stone() else TPC.cauldronInfo() end
end

-- minutes: how long it counts as having steamed already (an hour if left out; 0 to watch a hold such as Dairy's
-- 20-minute scald count up).
function TPC.hot(minutes)
    local fire = nearestCauldron()
    if not fire then return end
    local cauldron = Cauldron.of(fire)
    if (cauldron.ml or 0) <= 0 then return say("The cauldron is empty: TPC.cauldron() first.") end
    cauldron.tempC = HOT_TEST_C
    cauldron.held = (minutes or 60) / 60
    Fire.World.refresh(fire)
    TPC.cauldronInfo()
end

local function squareLine(label, square, playerNum)
    if not square then return end
    say(string.format("  %-14s air %.1f C, light %.2f", label,
        getClimateManager():getAirTemperatureForSquare(square), square:getLightLevel(playerNum)))
end

-- What a lit or banked Stone Hearth (Cauldron) warms and lights round it, and how its firebox cooks.
function TPC.warmth()
    local fire = nearestCauldron()
    if not fire then return end
    local player = getPlayer()
    local playerNum = player:getPlayerNum()
    local cell = getCell()
    local x, y, z = fire:getX(), fire:getY(), fire:getZ()
    say(string.format("Hearth %s, vanilla fire %s, vanilla fuel %d min, firebox %.2f (custom %.2f)",
        Fire.isBanked(fire) and "banked" or fire:isLit() and "lit" or "out", fire:isLit() and "lit" or "out",
        fire:getFuelAmount(), fire:getContainer():getTemperature(), fire:getContainer():getCustomTemperature()))
    for distance = 1, 6 do
        squareLine(distance .. " tile(s) east", cell:getGridSquare(x + distance, y, z), playerNum)
    end
    squareLine("your square", player:getSquare(), playerNum)
    say(string.format("  you: core %.2f C", player:getBodyDamage():getThermoregulator():getCoreTemperature()))
    local items = fire:getContainer():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if instanceof(item, "Food") and item:isCookable() then
            say(string.format("  %s: heat %.2f, cooking %.1f / %.0f min, cooked %s, burnt %s", item:getDisplayName(),
                item:getHeat(), item:getCookingTime(), item:getMinutesToCook(), tostring(item:isCooked()), tostring(item:isBurnt())))
        end
    end
end

-- Stone Hearth

-- Any Stone Hearth, fitted or not (nearestFire()): its flue is its own.

function TPC.stone()
    local stoneHearth = nearestFire()
    if not stoneHearth then return end
    local fireModData = Fire.fireModDataNow(stoneHearth)
    local sides = {}
    for _, side in ipairs(FireConnect.SIDES) do
        local square = Fire.flueSquare(stoneHearth, side)
        table.insert(sides, string.format("%s %s", side, square and (square:getX() .. "," .. square:getY()) or "-"))
    end
    local container = stoneHearth:getContainer()
    say(string.format("%d,%d,%d %s, fuel %d min, sprite %s, fitted %s, joined %s %s, hole %s; sides: %s", stoneHearth:getX(), stoneHearth:getY(),
        stoneHearth:getZ(), Fire.isBanked(stoneHearth) and "banked" or stoneHearth:isLit() and "lit" or "out", stoneHearth:getFuelAmount(),
        stoneHearth:getSprite():getName(), tostring(Fire.attachedTo(stoneHearth)), tostring(Fire.connectedTo(fireModData)),
        table.concat({ Fire.joinOf(fireModData) }, " "),
        StoneHearth.holeLook(container and container:getItems()), table.concat(sides, ", ")))
end

-- Fits the Cauldron on the nearest Stone Hearth at once, or with false takes off what is fitted.
function TPC.fit(on)
    local fire = nearestFire()
    if not fire then return end
    if on == false then Fire.unfit(fire) else Fire.fit(fire, Cauldron.ID) end
    Fire.World.refresh(fire)
    TPC.stone()
end

function TPC.flue(kitName, side)
    local stoneHearth = nearestFire()
    if not stoneHearth then return end
    local fireModData = Fire.fireModDataNow(stoneHearth)
    if kitName then Fire.join(fireModData, Smokehouse.ID, kitName, side or "Back") else Fire.unjoin(fireModData) end
    Fire.World.refresh(stoneHearth)
    TPC.stone()
end

function TPC.doors()
    local square = getPlayer():getSquare()
    for _, facing in ipairs({ StoneHearth.FACE_NAMES[0], StoneHearth.FACE_NAMES[1] }) do
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
local COLUMNS = { [0] = "hidden side", [1] = "side in view" }

function TPC.smokehouse()
    local player, seen = getPlayer(), 0
    local cell, x, y, z = getCell(), math.floor(player:getX()), math.floor(player:getY()), player:getZ()
    for dx = -3, 3 do
        for dy = -3, 3 do
            local tile, face, part, col = Smokehouse.chamberOn(cell:getGridSquare(x + dx, y + dy, z))
            if tile then
                seen = seen + 1
                local lines = {}
                for _, found in ipairs(Smokehouse.stoneHearthsBy(tile)) do
                    if found.tile == tile then
                        local flue, side = Smokehouse.flueOf(found.stoneHearth)
                        table.insert(lines, string.format("Stone Hearth at %d,%d: flue %s %s, %s", found.stoneHearth:getX(), found.stoneHearth:getY(),
                            tostring(flue), tostring(side), Smokehouse.joinedChamber(found.stoneHearth) == tile and "joined here"
                            or (Smokehouse.connectRefusalFor(found) or "may join")))
                    end
                end
                say(string.format("%d,%d facing %s, %s row, %s, entry art %s, smoke %s; %s", tile:getX(), tile:getY(),
                    StoneHearth.FACE_NAMES[face], PARTS[part], COLUMNS[col], tostring(Smokehouse.chamberEntry(tile)),
                    tostring(Smokehouse.smokeLook(tile)), #lines > 0 and table.concat(lines, "; ") or "no Stone Hearth beside it"))
            end
        end
    end
    if seen == 0 then say("No Smokehouse within 3 tiles on this floor.") end
end

-- The Drying Cloths within CLOTH_RADIUS on this floor.
local function clothsNear()
    local player, cloths = getPlayer(), {}
    local cell, x, y, z = getCell(), math.floor(player:getX()), math.floor(player:getY()), player:getZ()
    for dx = -CLOTH_RADIUS, CLOTH_RADIUS do
        for dy = -CLOTH_RADIUS, CLOTH_RADIUS do
            local square = cell:getGridSquare(x + dx, y + dy, z)
            local objects = square and square:getObjects()
            for i = 0, objects and objects:size() - 1 or -1 do
                if DryingCloth.isCloth(objects:get(i)) then table.insert(cloths, objects:get(i)) end
            end
        end
    end
    return cloths
end

function TPC.cloth()
    local cloths = clothsNear()
    if #cloths == 0 then return say(string.format("No Drying Cloth within %d tiles on this floor.", CLOTH_RADIUS)) end
    for _, cloth in ipairs(cloths) do
        local record, place = DryingCloth.update(cloth)
        local placeC = Weather.placeTemperature(DryingCloth.getLedger(), place)
        say(string.format("Drying Cloth at %d,%d: %s, %.1f C, room %d of %d used", cloth:getX(), cloth:getY(), tostring(place), placeC,
            DryingCloth.roomUsed(record), DryingCloth.ROOM))
        for _, lot in ipairs(record.lots) do
            local status = DryingCloth.status(lot, placeC, place)
            say(string.format("  lot %d: %s x %d, %s, %.0f%%, %s", lot.id, lot.kind, lot.count, status.state, status.progress * 100,
                status.hoursLeft and string.format("%.1f h left", status.hoursLeft) or (status.waits or "done")))
        end
    end
end

function TPC.dryCloth(hours)
    hours = hours or 24
    local cloths, dried = clothsNear(), 0
    for _, cloth in ipairs(cloths) do
        local record = DryingCloth.update(cloth)
        for _, lot in ipairs(record.lots) do
            if DryingCloth.state(lot) == "wet" then
                lot.dry.age = lot.dry.age + hours
                dried = dried + 1
            end
        end
        if TraditionalPreservationCoreDryingCloth then TraditionalPreservationCoreDryingCloth.updateCloth(cloth) end
    end
    say(string.format("Dried %d lot(s) on %d cloth(s) by %.1f hours. TPC.cloth() to see them.", dried, #cloths, hours))
end

-- A sample window for Core's scrolling list (PieceList), before any station uses it. The pieces are made up: a
-- name, a share, a tab (its process) and a popup each; every third has a line under its bar, every fifth is done. The window's class is
-- made on the first call (the info window code is the client's, loaded after this file).
local SAMPLE_PIECES = { { "Bluegill", "Base.Bluegill", "Salt Dried" }, { "Yellow Perch", "Base.YellowPerch", "Salt Dried" },
    { "Beef (Salted)", "Base.Steak", "Charque" }, { "Pork (Salted)", "Base.PorkChop", "Cold Smoked" },
    { "Blood Sausage", "Base.Sausage", "Cold Smoked" }, { "Chicken (Corned)", "Base.Chicken", "Hot Smoked" },
    { "Salmon, a long name to cut", "Base.Salmon", "Salt Dried" } }
local SAMPLE_DONE, SAMPLE_SLOW = { 0.35, 0.7, 0.35 }, { 0.8, 0.6, 0.25 }
local SAMPLE_COUNT = 14
local SampleWindow

local function sampleRows(UI, count)
    local rows = {}
    for i = 1, count do
        local piece = SAMPLE_PIECES[(i - 1) % #SAMPLE_PIECES + 1]
        local script = getScriptManager():FindItem(piece[2])
        local share = i % 5 == 0 and 1 or ((i * 37) % 97) / 100
        local text = share >= 1 and "Done"
            or UI.say("IGUI_TraditionalPreservationCore_ClothLeft", UI.percent(share), UI.durationText((1 - share) * 120))
        rows[i] = { icon = script and script:getNormalTexture(), name = piece[1], share = share, text = text, tab = piece[3],
            colour = share >= 1 and SAMPLE_DONE or (i % 4 == 0 and SAMPLE_SLOW or nil),
            note = i % 3 == 0 and string.format("Cold smoke %.1f of 72 h", share * 72) or nil,
            warning = i % 4 == 2 and "Wet: rain" or (i % 7 == 0 and "Stale in 3.5 d" or nil),
            popup = function(tooltip)
                UI.drawTooltip(tooltip, function(layout)
                    UI.addLine(layout, "IGUI_TraditionalPreservationCore_ClothInfoPlace", "Sample")
                    UI.addLine(layout, "EC_CraftLogic_Progress", UI.percent(share))
                    UI.addLine(layout, "IGUI_TraditionalPreservationCore_ClothInfoLots", "piece " .. i)
                end)
            end }
    end
    return rows
end

local function sampleWindow()
    if SampleWindow then return SampleWindow end
    local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
    local UI = require "TraditionalPreservationCore/UI"
    SampleWindow = InfoWindow:derive("TraditionalPreservationCoreSampleListWindow")
    function SampleWindow:new(playerObj, station)
        local o = InfoWindow.new(self, playerObj, station)
        o.title = "Piece List (sample)"
        return o
    end
    -- The first refresh makes the rows, once.
    function SampleWindow:refresh()
        if not self.rows then self.rows = sampleRows(UI, SampleWindow.count) end
    end
    function SampleWindow:render()
        ISCollapsableWindow.render(self)
        if self.isCollapsed or not self.rows then return end
        local y = self:top()
        y = self:row(y, "IGUI_TraditionalPreservationCore_ClothInfoPlace", "Sample")
        y = self:pieceList(y, "IGUI_TraditionalPreservationCore_ClothInfoLots", self.rows)
        self:drawNotes(y, { string.format("%d made-up pieces. Hover a row for its popup; the switch sorts.", #self.rows) })
    end
    return SampleWindow
end

function TPC.pieceList(count)
    local player = getPlayer()
    local square = player:getCurrentSquare()
    local floor = square and square:getFloor()
    if not floor then return say("No floor under you to hang the sample window on.") end
    local window = sampleWindow()
    window.count = count or SAMPLE_COUNT
    require("TraditionalPreservationCore/InfoWindow").open(window, player, floor)
    say(string.format("Sample list opened with %d pieces. Walk off or close it.", window.count))
end

-- Food and crops, for the long save's larder sums (user, 2026-11-23): TPC.food() what is on you and in reach,
-- remembered by container for TPC.foodTotal(); TPC.crops() the living crops near you by kind. Printed as columns to
-- screenshot. Hunger is in the tooltip's points (an item's getHungChange x 100, a fluid's per-litre value x litres),
-- calories as the game counts them; a day's food is reckoned at DAY_KCAL, the long save's ledger figure.
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local MONTH_DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local function fit(text, width)
    text = tostring(text)
    if #text > width then return text:sub(1, width - 1) .. "~" end
    return text .. string.rep(" ", width - #text)
end
local function num(x, width, decimals)
    local text = string.format("%." .. (decimals or 0) .. "f", x)
    return string.rep(" ", math.max(width - #text, 0)) .. text
end

-- The game's date now, and the date days from now ("Sep 30").
local function dateIn(days)
    local time = getGameTime()
    local month, day = time:getMonth() + 1, time:getDay() + 1 + math.floor(days + 0.5)
    while day > MONTH_DAYS[month] do
        day = day - MONTH_DAYS[month]
        month = month % 12 + 1
    end
    return MONTHS[month] .. " " .. day
end
local function nowText()
    local time = getGameTime()
    return string.format("%s %d, %02d:%02d, day %d", MONTHS[time:getMonth() + 1], time:getDay() + 1, time:getHour(),
        time:getMinutes(), math.floor(time:getWorldAgeHours() / 24) + 1)
end

-- A food's state: rotten, stale, fresh, or keeps (never goes off).
local function stateOf(item)
    if item:getOffAgeMax() >= 1000000 then return "keeps" end
    if item:isRotten() then return "rotten" end
    if item:isFresh() then return "fresh" end
    return "stale"
end

local function hasFood(item)
    if instanceof(item, "Food") then return true end
    local fluid = item:getFluidContainer()
    return fluid ~= nil and not fluid:isEmpty()
end

-- One item's row: { key, name, state, weight, kcal, hunger, salt (uses) }, or nil for a fluid with no food in it.
local function rowOf(item)
    if instanceof(item, "Food") then
        if item:hasTag(ItemTag.SALT) then
            return { salt = item:getCurrentUses(), name = item:getDisplayName(), weight = item:getUnequippedWeight() }
        end
        -- Food to the game but no food to eat (feathers): left out.
        if item:getCalories() == 0 and item:getHungChange() == 0 then return nil end
        local state = stateOf(item)
        return { key = item:getDisplayName() .. "|" .. state, name = item:getDisplayName(), state = state,
            weight = item:getUnequippedWeight(), kcal = item:getCalories(), hunger = item:getHungChange() * 100 }
    end
    local fluid = item:getFluidContainer()
    local props, litres = fluid:getProperties(), fluid:getAmount()
    local kcal, hunger = props:getCalories() * litres, props:getHungerChange() * litres
    if kcal == 0 and hunger == 0 then return nil end
    local name = string.format("%s (%.2g L)", item:getDisplayName(), litres)
    return { key = item:getDisplayName() .. "|fluid", name = name, state = "fluid", weight = item:getUnequippedWeight(),
        kcal = kcal, hunger = hunger }
end

-- What is on the player and in every container within radius on their floor (furniture, bags and floor items, and
-- the bags inside them), each container as { key, label, items }.
local function foodPlaces(player, radius)
    local places = {}
    local function add(key, label, list)
        local items = {}
        for i = 0, list:size() - 1 do table.insert(items, list:get(i)) end
        if #items > 0 then table.insert(places, { key = key, label = label, items = items }) end
    end
    add("inventory", "on you", player:getInventory():getAllEvalRecurse(hasFood))
    local cell, px, py, z = getCell(), math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    for dx = -radius, radius do
        for dy = -radius, radius do
            local square = cell:getGridSquare(px + dx, py + dy, z)
            if square then
                local where = string.format("%d,%d,%d", px + dx, py + dy, z)
                local objects = square:getObjects()
                for i = 0, objects:size() - 1 do
                    local isoObject = objects:get(i)
                    for c = 0, isoObject:getContainerCount() - 1 do
                        local container = isoObject:getContainerByIndex(c)
                        add(where .. "|" .. tostring(container:getType()) .. "|" .. c, container:getType(), container:getAllEvalRecurse(hasFood))
                    end
                end
                local floor = ArrayList.new()
                local worldObjects = square:getWorldObjects()
                for i = 0, worldObjects:size() - 1 do
                    local item = worldObjects:get(i):getItem()
                    if item then
                        if hasFood(item) then floor:add(item) end
                        if item:IsInventoryContainer() then floor:addAll(item:getInventory():getAllEvalRecurse(hasFood)) end
                    end
                end
                add(where .. "|floor", "floor", floor)
            end
        end
    end
    return places
end

-- Rows summed by name and state, and the totals: { rows, kcal, hunger, weight, salt, saltWeight }.
local function sumRows(itemLists)
    local byKey, rows = {}, {}
    local sums = { kcal = 0, hunger = 0, weight = 0, salt = 0, saltWeight = 0, count = 0 }
    for _, items in ipairs(itemLists) do
        for _, item in ipairs(items) do
            local row = rowOf(item)
            if row and row.salt then
                sums.salt, sums.saltWeight = sums.salt + row.salt, sums.saltWeight + row.weight
            elseif row then
                local sum = byKey[row.key]
                if not sum then
                    sum = { name = row.name, state = row.state, count = 0, weight = 0, kcal = 0, hunger = 0 }
                    byKey[row.key] = sum
                    table.insert(rows, sum)
                end
                sum.count, sum.weight = sum.count + 1, sum.weight + row.weight
                sum.kcal, sum.hunger = sum.kcal + row.kcal, sum.hunger + row.hunger
                sums.kcal, sums.hunger, sums.weight, sums.count = sums.kcal + row.kcal, sums.hunger + row.hunger, sums.weight + row.weight, sums.count + 1
            end
        end
    end
    table.sort(rows, function(a, b) return a.kcal > b.kcal end)
    sums.rows = rows
    return sums
end

local function printFood(title, sums)
    say(title)
    say(fit("count", 6) .. fit("food", 48) .. fit("state", 7) .. "  weight     kcal   hunger")
    for _, row in ipairs(sums.rows) do
        say(num(row.count, 4) .. "  " .. fit(row.name, 48) .. fit(row.state, 7) .. num(row.weight, 8, 1) .. num(row.kcal, 9) .. num(row.hunger, 9))
    end
    say(string.format("TOTAL %d items, %.1f weight, %.0f kcal, %.0f hunger: %.1f days at %d kcal", sums.count, sums.weight,
        sums.kcal, sums.hunger, sums.kcal / DAY_KCAL, DAY_KCAL))
    say(string.format("SALT %d uses = %.1f E (5 uses each), %.1f weight", sums.salt, sums.salt / 5, sums.saltWeight))
end

-- Every container TPC.food() has read, by its place: what it held the last time (the inventory as it is now).
local seen = {}

function TPC.food(radius)
    radius = radius or FOOD_RADIUS
    local player = getPlayer()
    local lists = {}
    for _, place in ipairs(foodPlaces(player, radius)) do
        table.insert(lists, place.items)
        if place.key ~= "inventory" then seen[place.key] = { label = place.label, items = place.items } end
    end
    printFood(string.format("FOOD on you and within %d tile%s, %s", radius, radius == 1 and "" or "s", nowText()), sumRows(lists))
    local count = 0
    for _ in pairs(seen) do count = count + 1 end
    say(string.format("(%d containers remembered for TPC.foodTotal(); TPC.foodReset() forgets them)", count))
end

function TPC.foodTotal()
    local carried, lists, count = getPlayer():getInventory():getAllEvalRecurse(hasFood), { {} }, 0
    for i = 0, carried:size() - 1 do table.insert(lists[1], carried:get(i)) end
    for _, place in pairs(seen) do
        table.insert(lists, place.items)
        count = count + 1
    end
    printFood(string.format("FOOD TOTAL: on you plus %d containers read with TPC.food(), %s", count, nowText()), sumRows(lists))
end

function TPC.foodReset()
    seen = {}
    say("Forgot the containers read so far.")
end

-- The yield vanilla's harvest rolls for a plant (farming_vegetableconf getVegetablesNumber, 42.22), as the expected
-- number and its range, at its health now. The sandbox's yield multiplier is worked out there but never used.
local function expectedYield(plant, props, skill)
    local health = math.floor((plant.health - 50) / 10)
    local bonus = (plant.bonusYield and not plant.cursed) and 1 or 0
    local minV = math.min(props.minVeg + health, props.minVegAutorized + bonus)
    local maxV = math.min(props.maxVeg + health, props.maxVegAutorized + bonus)
    if maxV < minV then maxV = minV end
    local n = maxV - minV + 1
    local mean = (minV + maxV) / 2
    if bonus == 1 then
        mean = 0
        for i = 0, n - 1 do mean = mean + (minV + i) * ((i + 1) ^ 2 - i ^ 2) / n ^ 2 end
    end
    local pests = math.floor((plant.aphidLvl or 0) / 10) + math.floor((plant.slugsLvl or 0) / 10)
    local skillAdd = skill * math.min(skill, 10) / 10
    return math.max(1, mean - pests + skillAdd), math.max(1, minV - pests), math.max(1, maxV - pests + skill)
end

function TPC.crops(radius)
    radius = radius or 60
    local system = SFarmingSystem and SFarmingSystem.instance
    if not system then return say("No farming system here (the server's side of it isn't loaded).") end
    local player = getPlayer()
    local px, py = player:getX(), player:getY()
    local skill = player:getPerkLevel(Perks.Farming)
    local factor = calcNextTimeFactor and calcNextTimeFactor() or 1
    local kinds, order, dead = {}, {}, 0
    for i = 0, system.system:getObjectCount() - 1 do
        local globalObject = system.system:getObjectByIndex(i)
        local plant = globalObject:getModData()
        if math.abs(globalObject:getX() - px) <= radius and math.abs(globalObject:getY() - py) <= radius then
            local props = farming_vegetableconf.props[plant.typeOfSeed]
            if plant.state == "seeded" and props then
                local kind = kinds[plant.typeOfSeed]
                if not kind then
                    local veg = props.vegetableName and instanceItem(props.vegetableName)
                    kind = { name = plant.typeOfSeed, count = 0, stages = {}, yield = 0, low = 0, high = 0, ready = {},
                        kcal = veg and instanceof(veg, "Food") and veg:getCalories() or 0,
                        hunger = veg and instanceof(veg, "Food") and veg:getHungChange() * 100 or 0,
                        weight = veg and veg:getActualWeight() or 0 }
                    kinds[plant.typeOfSeed] = kind
                    table.insert(order, kind)
                end
                kind.count = kind.count + 1
                kind.stages[plant.nbOfGrow] = (kind.stages[plant.nbOfGrow] or 0) + 1
                local mean, low, high = expectedYield(plant, props, skill)
                kind.yield, kind.low, kind.high = kind.yield + mean, kind.low + low, kind.high + high
                local hours = 0
                if plant.nbOfGrow < props.harvestLevel then
                    hours = math.max(plant.nextGrowing - system.hoursElapsed, 0)
                        + (props.harvestLevel - plant.nbOfGrow - 1) * props.timeToGrow * factor
                end
                table.insert(kind.ready, hours / 24)
            elseif plant.state == "dead" or plant.state == "rotten" then
                dead = dead + 1
            end
        end
    end
    say(string.format("CROPS within %d tiles, %s (Farming %d; yields at each plant's health now)", radius, nowText(), skill))
    say(fit("crop", 13) .. "plants  " .. fit("stages", 16) .. fit("ready", 15) .. "  yield (range)      kcal   hunger  weight")
    local total = { kcal = 0, hunger = 0, weight = 0 }
    table.sort(order, function(a, b) return a.name < b.name end)
    for _, kind in ipairs(order) do
        local stages = {}
        for stage = 0, 10 do
            if kind.stages[stage] then table.insert(stages, stage .. ":" .. kind.stages[stage]) end
        end
        table.sort(kind.ready)
        local first, last = kind.ready[1], kind.ready[#kind.ready]
        local ready = first <= 0 and "now" or dateIn(first)
        if last > 0 and math.floor(last + 0.5) ~= math.floor(first + 0.5) then ready = ready .. "-" .. dateIn(last) end
        local kcal, hunger, weight = kind.yield * kind.kcal, kind.yield * kind.hunger, kind.yield * kind.weight
        total.kcal, total.hunger, total.weight = total.kcal + kcal, total.hunger + hunger, total.weight + weight
        say(fit(kind.name, 13) .. num(kind.count, 6) .. "  " .. fit(table.concat(stages, " "), 16) .. fit(ready, 15)
            .. num(kind.yield, 7) .. fit(string.format(" (%d-%d)", kind.low, kind.high), 11)
            .. num(kcal, 8) .. num(hunger, 9) .. num(weight, 8, 1))
    end
    say(string.format("TOTAL expected harvest %.0f kcal, %.0f hunger, %.1f weight: %.1f days at %d kcal", total.kcal,
        total.hunger, total.weight, total.kcal / DAY_KCAL, DAY_KCAL))
    if dead > 0 then say(string.format("(%d dead or rotten plants left out)", dead)) end
end

say("Debug commands loaded. Type TPC.help() in the Lua console.")
