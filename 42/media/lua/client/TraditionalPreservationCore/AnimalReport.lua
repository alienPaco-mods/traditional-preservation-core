-- Traditional Preservation core: the animal report, a text file written on each save beside the station report, of
-- every animal loaded at the save: those walking about, those in a hutch and those in a trailer. Each by its pen (the
-- animal zone, with its troughs' feed and water, and the corners of each zone it is joined from), then its name, sex, age and where it stands, its health, hunger,
-- thirst, stress and acceptance of the player, then its milk, pregnancy, wool and young where it has them. Vanilla's
-- own numbers as its Info window reads them. Only animals loaded at the save are in it (the squares round the player),
-- so a pen far off is missing, not empty. For the long save's log: _pzdev/longsave_snapshot.py copies it into the
-- log's repo as animals.txt.
local AnimalReport = {}

AnimalReport.FILE = "TraditionalPreservationAnimals_%s.txt"   -- in ~/Zomboid/Lua, by the save's folder name
AnimalReport.INDENT = "  "
AnimalReport.NO_ZONE = "No pen"

local function percent(value)
    return string.format("%d%%", math.floor((value or 0) * 100 + 0.5))
end

local function list(javaList)
    local out = {}
    if not javaList then return out end
    for i = 0, javaList:size() - 1 do table.insert(out, javaList:get(i)) end
    return out
end

-- A Java collection without get (a HashMap's values, a Set) as a Lua list.
local function collection(javaCollection)
    if not javaCollection then return {} end
    local copy = ArrayList.new()
    copy:addAll(javaCollection)
    return list(copy)
end

-- The pen's line: its size, troughs, the feed and water in them, food on the ground and hutches, as the zone window
-- counts them (connected zones together). Vanilla counts a pen's troughs, food and hutches only while all of it is
-- loaded, so a pen partly out of reach says so instead of a count of none.
local function zoneLine(zone)
    for _, connected in ipairs(list(DesignationZoneAnimal.getAllDZones(nil, zone, nil))) do
        if not connected:isFullyStreamed() then
            return string.format("%d tiles, not all loaded at the save: troughs, feed and water not counted",
                zone:getFullZoneSize())
        end
    end
    local feed, water = 0, 0
    local troughs = zone:getTroughsConnected()
    for _, trough in ipairs(list(troughs)) do
        feed = feed + trough:getCurrentFeedAmount()
        water = water + trough:getWater()
    end
    return string.format("%d tiles, %d troughs (feed %.1f, water %.1f L), %d food on the ground, %d hutches",
        zone:getFullZoneSize(), troughs:size(), feed, water, zone:getFoodOnGroundConnected():size(),
        zone:getHutchsConnected():size())
end

-- Each zone the pen is joined from: its corners, size and whether all of it was loaded at the save. Vanilla catches
-- a zone's animals up for the hours away only when both its corners load at once (DesignationZone.checkStreamed), so
-- a zone that never does stands still while the player is away.
local function zoneParts(zone)
    local parts = {}
    for _, part in ipairs(list(DesignationZoneAnimal.getAllDZones(nil, zone, nil))) do
        local x, y, w, h = part:getX(), part:getY(), part:getW(), part:getH()
        table.insert(parts, { x = x, y = y, text = string.format("zone %d, %d to %d, %d (%d x %d), %s%s", x, y, x + w - 1,
            y + h - 1, w, h, part:getName(), part:isFullyStreamed() and "" or ": not all loaded") })
    end
    table.sort(parts, function(a, b) if a.x ~= b.x then return a.x < b.x end return a.y < b.y end)
    local lines = {}
    for _, part in ipairs(parts) do table.insert(lines, part.text) end
    return lines
end

-- One animal's lines.
local function animalLines(animal, playerObj)
    local data = animal:getData()
    local square = animal:getCurrentSquare()
    local where = square and string.format("%d, %d, %d", square:getX(), square:getY(), square:getZ()) or "?"
    local lines = {
        string.format("%s: %s, %d days%s, at %s", animal:getFullName(), animal:isFemale() and "female" or "male",
            data:getDaysSurvived(), animal:isBaby() and " (young)" or "", where),
        string.format("health %s, hunger %s, thirst %s, stress %d, acceptance %d", percent(animal:getHealth()),
            percent(animal:getHunger()), percent(animal:getThirst()), math.floor(animal:getStress() + 0.5),
            math.floor(animal:getPlayerAcceptance(playerObj) + 0.5)),
    }
    local more = {}
    if animal:hasUdder() and animal:isFemale() and not animal:isBaby() then
        table.insert(more, string.format("milk %.1f / %.1f L (%s, up to %.1f)", data:getMilkQuantity(),
            data:getMaxMilkActual(), data:canHaveMilk() and "in milk" or "dry", data:getMaxMilk()))
    end
    if data:isPregnant() then
        table.insert(more, string.format("pregnant, day %d of %d", data:getPregnancyTime(), data:getPregnantPeriod()))
    end
    if animal:canBeSheared() then
        table.insert(more, string.format("wool %.1f / %.1f", data:getWoolQuantity(), data:getMaxWool()))
    end
    local babies = animal:getBabies()
    if babies and babies:size() > 0 then table.insert(more, string.format("%d young", babies:size())) end
    if animal:haveMatingSeason() and animal:isInMatingSeason() then table.insert(more, "in its mating season") end
    if animal:getGeneticDisorder() and animal:getGeneticDisorder():size() > 0 then
        local disorders = {}
        for _, name in ipairs(list(animal:getGeneticDisorder())) do table.insert(disorders, tostring(name)) end
        table.insert(more, "disorder: " .. table.concat(disorders, ", "))
    end
    if #more > 0 then table.insert(lines, table.concat(more, ", ")) end
    return lines
end

-- A pen is every zone joined to a zone: the one most north-west of them stands for it, so the animals of one pen are
-- reported together whichever of its zones they stand in.
local function penOf(zone)
    local first
    for _, part in ipairs(list(DesignationZoneAnimal.getAllDZones(nil, zone, nil))) do
        if not first or part:getX() < first:getX() or part:getX() == first:getX() and part:getY() < first:getY() then
            first = part
        end
    end
    return first or zone
end

-- Every loaded animal once, with the place it is reported under: { animal, place, zone }.
local function found()
    local entries, seen = {}, {}
    local function add(animal, zone, place)
        local id = animal:getAnimalID()
        if seen[id] then return end
        seen[id] = true
        local pen = zone and penOf(zone)
        table.insert(entries, { animal = animal, place = place or pen and pen:getName() or AnimalReport.NO_ZONE, zone = pen })
    end
    for _, animal in ipairs(list(getCell():getAnimals())) do
        -- An animal looks up its pen only now and then (one just brought, or one at the edge of the loaded squares,
        -- hasn't): the pen where it stands, as its own lookup finds it.
        add(animal, animal:getDZone() or DesignationZoneAnimal.getZoneF(animal:getX(), animal:getY(), animal:getZ()))
    end
    for _, zone in ipairs(list(DesignationZoneAnimal.getAllZones())) do
        for _, hutch in ipairs(list(zone:getHutchsConnected())) do
            for _, animal in ipairs(collection(hutch:getAnimalInside():values())) do add(animal, zone) end
        end
    end
    for _, vehicle in ipairs(collection(getCell():getVehicles())) do
        local square = vehicle:getSquare()
        local place = string.format("In a %s at %d, %d", vehicle:getScript():getName(), square and square:getX() or 0,
            square and square:getY() or 0)
        for _, animal in ipairs(list(vehicle:getAnimals())) do add(animal, nil, place) end
    end
    return entries
end

function AnimalReport.text(playerObj)
    local gameTime = getGameTime()
    local hours = gameTime:getWorldAgeHours()
    local places, order = {}, {}
    local entries = found()
    for _, entry in ipairs(entries) do
        local place = places[entry.place]
        if not place then
            place = { name = entry.place, zone = entry.zone, animals = {} }
            places[entry.place] = place
            table.insert(order, place)
        end
        table.insert(place.animals, entry.animal)
    end
    table.sort(order, function(a, b) return a.name < b.name end)
    local out = {
        "Traditional Preservation animals, save " .. tostring(getWorld():getWorld()),
        string.format("In game: %04d-%02d-%02d %02d:%02d, day %d (hours=%.2f)", gameTime:getYear(), gameTime:getMonth() + 1,
            gameTime:getDay() + 1, gameTime:getHour(), gameTime:getMinutes(), math.floor(hours / 24) + 1, hours),
        string.format("Player at %d, %d, %d", math.floor(playerObj:getX()), math.floor(playerObj:getY()), math.floor(playerObj:getZ())),
        string.format("Animals loaded: %d (an animal far from the player isn't loaded and isn't listed)", #entries),
    }
    for _, place in ipairs(order) do
        table.insert(out, "")
        table.insert(out, string.format("== %s: %d animals", place.name, #place.animals))
        if place.zone then
            table.insert(out, AnimalReport.INDENT .. zoneLine(place.zone))
            for _, line in ipairs(zoneParts(place.zone)) do table.insert(out, AnimalReport.INDENT .. line) end
        end
        table.sort(place.animals, function(a, b) return a:getFullName() < b:getFullName() end)
        for _, animal in ipairs(place.animals) do
            local lines = animalLines(animal, playerObj)
            table.insert(out, AnimalReport.INDENT .. "- " .. lines[1])
            for i = 2, #lines do table.insert(out, AnimalReport.INDENT .. "    " .. lines[i]) end
        end
    end
    return table.concat(out, "\n") .. "\n"
end

function AnimalReport.write()
    local playerObj = getPlayer()
    if not playerObj then return end
    local ok, text = pcall(AnimalReport.text, playerObj)
    if not ok then text = "Traditional Preservation animals: the report failed: " .. tostring(text) .. "\n" end
    local writer = getFileWriter(string.format(AnimalReport.FILE, tostring(getWorld():getWorld())), true, false)
    writer:write(text)
    writer:close()
end

Events.OnSave.Add(AnimalReport.write)

return AnimalReport
