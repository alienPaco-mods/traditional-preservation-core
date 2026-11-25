-- Checks the animal report outside the game: animals walking about, in a hutch and in a trailer, each once, by pen
-- with the pen's line, milk and pregnancy where they apply, and the file written on save. Run from this folder:
-- luajit tests/test_animal_report.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installEvents()

-- A Java list as the engine hands it.
local function jlist(items)
    local self = { items = items or {} }
    function self:size() return #self.items end
    function self:get(i) return self.items[i + 1] end
    function self:addAll(other) for _, v in ipairs(other.items) do table.insert(self.items, v) end end
    return self
end
ArrayList = { new = function() return jlist({}) end }

local function square(x, y, z)
    return { getX = function() return x end, getY = function() return y end, getZ = function() return z end }
end

local nextId = 0
local function animal(o)
    nextId = nextId + 1
    local id = nextId
    local data = {
        getDaysSurvived = function() return o.days or 400 end, getMilkQuantity = function() return o.milk or 0 end,
        getMaxMilkActual = function() return 10 end, getMaxMilk = function() return 33.6 end,
        canHaveMilk = function() return o.inMilk or false end, isPregnant = function() return o.pregnant ~= nil end,
        getPregnancyTime = function() return o.pregnant or 0 end, getPregnantPeriod = function() return 280 end,
        getWoolQuantity = function() return 0 end, getMaxWool = function() return 0 end,
    }
    return {
        getAnimalID = function() return id end, getData = function() return data end,
        getFullName = function() return o.name end, isFemale = function() return o.female or false end,
        isBaby = function() return false end, getCurrentSquare = function() return square(5720, 5740, 0) end,
        getHealth = function() return 1 end, getHunger = function() return 0.12 end, getThirst = function() return 0.05 end,
        getStress = function() return 3.4 end, getPlayerAcceptance = function() return 34 end,
        hasUdder = function() return o.udder or false end, canBeSheared = function() return false end,
        getBabies = function() return jlist({}) end, haveMatingSeason = function() return false end,
        isInMatingSeason = function() return false end, getGeneticDisorder = function() return jlist({}) end,
        getDZone = function() return o.zone end,
    }
end

local zone = {}
local bull = animal({ name = "Angus Bull" })
local cow = animal({ name = "Holstein Cow", female = true, udder = true, milk = 4.25, inMilk = true, pregnant = 12 })
local hen = animal({ name = "Leghorn Hen", female = true })
local lamb = animal({ name = "Rambouillet Ewe", female = true, udder = true })
local hutch = { getAnimalInside = function() return { values = function() return jlist({ hen }) end } end }
function zone.getName() return "Ranch" end
function zone.getTroughsConnected()
    return jlist({ { getCurrentFeedAmount = function() return 2 end, getWater = function() return 30 end } })
end
function zone.getFullZoneSize() return 400 end
function zone.isFullyStreamed() return zone.streamed ~= false end
function zone.getFoodOnGroundConnected() return jlist({}) end
function zone.getHutchsConnected() return jlist({ hutch }) end
local function zoned(a) a.getDZone = function() return zone end; return a end
zoned(bull); zoned(cow)

local trailer = { getSquare = function() return square(5700, 5730, 0) end,
    getScript = function() return { getName = function() return "Trailer_Livestock" end } end,
    getAnimals = function() return jlist({ lamb }) end }
function getCell()
    return { getAnimals = function() return jlist({ bull, cow, bull }) end, getVehicles = function() return jlist({ trailer }) end }
end
DesignationZoneAnimal = { getAllZones = function() return jlist({ zone, zone }) end,
    getAllDZones = function(_, z) return jlist({ z }) end }
function getGameTime()
    return { getWorldAgeHours = function() return 1500.5 end, getYear = function() return 1993 end, getMonth = function() return 8 end,
        getDay = function() return 10 end, getHour = function() return 9 end, getMinutes = function() return 5 end }
end
function getWorld() return { getWorld = function() return "TPLongGame" end } end
local player = { getX = function() return 5720.4 end, getY = function() return 5735.9 end, getZ = function() return 0 end }
function getPlayer() return player end

local AnimalReport = require "TraditionalPreservationCore/AnimalReport"
local text = AnimalReport.text(player)
local function has(s) return text:find(s, 1, true) ~= nil end
check("the header counts each animal once (one listed twice, one in a hutch, one in a trailer)", has("Animals loaded: 4"))
check("a pen with its line", has("== Ranch: 3 animals") and has("400 tiles, 1 troughs (feed 2.0, water 30.0 L), 0 food on the ground, 1 hutches"))
check("an animal's stats", has("- Angus Bull: male, 400 days, at 5720, 5740, 0") and has("health 100%, hunger 12%, thirst 5%, stress 3, acceptance 34"))
check("milk and pregnancy", has("milk 4.2 / 10.0 L (in milk, up to 33.6), pregnant, day 12 of 280"))
zone.streamed = false
check("a pen partly out of reach: no trough count", AnimalReport.text(player):find(
    "400 tiles, not all loaded at the save: troughs, feed and water not counted", 1, true) ~= nil)
zone.streamed = nil
check("a hen in a hutch goes under its pen", has("- Leghorn Hen: female"))
check("a dry ewe in a trailer", has("== In a Trailer_Livestock at 5700, 5730: 1 animals") and has("milk 0.0 / 10.0 L (dry, up to 33.6)"))

local written = {}
function getFileWriter(name, create, append)
    written.name, written.append = name, append
    return { write = function(_, body) written.body = body end, close = function() written.closed = true end }
end
AnimalReport.write()
check("written on save, by the save's name, replacing the last", written.name == "TraditionalPreservationAnimals_TPLongGame.txt"
    and written.append == false and written.closed and written.body == text)
getCell = function() error("no cell") end
AnimalReport.write()
check("a failing report says so in the file", written.body:find("the report failed", 1, true) ~= nil)

H.done()
