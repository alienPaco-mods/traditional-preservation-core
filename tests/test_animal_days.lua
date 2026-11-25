-- Checks AnimalDays outside the game: an animal coming and going in part-days keeps ageing and its pregnancy moves on
-- by the calendar, one vanilla ran ahead is set back, a whole-day catch-up of vanilla's isn't counted twice, a new pregnancy starts its own count, wild
-- animals and the sandbox off are left alone, old records are dropped. Run from this folder: luajit tests/test_animal_days.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installModData()

local AnimalDays = require "TraditionalPreservationCore/AnimalDays"

-- An animal as the engine has it: vanilla's own day rule is not run here, only what AnimalDays calls.
local nextId = 0
local function animal(o)
    nextId = nextId + 1
    local id = nextId
    local data = { age = o.age or 500, pregnant = o.pregnancy ~= nil, pregnancy = o.pregnancy or 0, grown = 0 }
    function data:getAge() return self.age end
    function data:setAge(age) self.age = age end
    function data:growUp()
        self.grown = self.grown + 1
        if self.pregnant then self.pregnancy = self.pregnancy + 1 end
    end
    function data:isPregnant() return self.pregnant end
    function data:getPregnancyTime() return self.pregnancy end
    function data:setPregnancyTime(days) self.pregnancy = days end
    local self = { data = data, hours = o.hours or data.age * 24, wild = o.wild or false }
    function self:getAnimalID() return id end
    function self:getData() return data end
    function self:isWild() return self.wild end
    function self:getHoursSurvived() return self.hours end
    function self:setHoursSurvived(hours) self.hours = hours end
    return self
end

local function jlist(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end }
end

-- Vanilla's catch-up on coming back: the time away in whole days only, the hour count back to whole days.
local function vanillaCatchUp(a, hoursAway)
    local days = math.floor(hoursAway / 24)
    a.data.age = a.data.age + days
    a.hours = a.data.age * 24
end

local bull = animal({ age = 502 })
AnimalDays.keep(bull, 1000)
-- Four days of coming and going: 20 hours away, back, 4 hours loaded (vanilla's live count gets no day), each day.
local now = 1000
for _ = 1, 4 do
    now = now + 20
    vanillaCatchUp(bull, 20)
    AnimalDays.keep(bull, now)
    now = now + 4
    bull.hours = bull.hours + 4
    AnimalDays.keep(bull, now)
end
check("four days of part-day trips: four days older, grown four times", bull.data.age == 506 and bull.data.grown == 4)
check("the hour count follows (vanilla's day rule sees nothing to add)", bull.hours == 506 * 24)
check("the record says how many days it kept", AnimalDays.recordOf(bull).kept == 4)

local cow = animal({ age = 640, pregnancy = 2 })
AnimalDays.keep(cow, 2000)
local t = 2000
for _ = 1, 3 do
    t = t + 20
    vanillaCatchUp(cow, 20)
    AnimalDays.keep(cow, t)
    t = t + 4
    cow.hours = cow.hours + 4
    AnimalDays.keep(cow, t)
end
check("the pregnancy moves on a day a day, not twice for the growUp", cow.data.pregnancy == 5 and cow.data.age == 643)
check("the record counts the pregnancy days it kept", AnimalDays.recordOf(cow).keptPregnancy == 3)

-- Vanilla's catch-up counting a midnight twice: the pregnancy is set back to its day from the conception.
local angus = animal({ age = 640, pregnancy = 2 })
AnimalDays.keep(angus, 7000)
angus.data.pregnancy = 5
local _, moved = AnimalDays.keep(angus, 7030)
check("a pregnancy vanilla ran ahead is set back to the calendar", angus.data.pregnancy == 3 and moved == -2)
check("the record counts the days taken back", AnimalDays.recordOf(angus).trimmedPregnancy == 2)
AnimalDays.keep(angus, 7030 + 24)
check("and it goes on from there a day a day", angus.data.pregnancy == 4)

-- A two-day trip: vanilla's catch-up counts the two whole days itself, and nothing is added twice.
local ewe = animal({ age = 458 })
AnimalDays.keep(ewe, 3000)
vanillaCatchUp(ewe, 48)
AnimalDays.keep(ewe, 3048)
check("a trip of whole days: vanilla's two days, none added", ewe.data.age == 460 and ewe.data.grown == 0)
vanillaCatchUp(ewe, 30)
AnimalDays.keep(ewe, 3078)
check("30 hours more: vanilla's one day, and the 6 hours over it kept for the next day",
    ewe.data.age == 461 and ewe.data.grown == 0 and AnimalDays.recordOf(ewe).hours == 461 * 24 + 6)

-- A birth and a new mating while away: the pregnancy count went down, so it counts from the new one.
local doe = animal({ age = 220, pregnancy = 40 })
AnimalDays.keep(doe, 4000)
doe.data.pregnancy = 1
AnimalDays.keep(doe, 4010)
check("a new pregnancy isn't pushed to the old one's day", doe.data.pregnancy == 1)
AnimalDays.keep(doe, 4010 + 48)
check("and counts on from its own conception", doe.data.pregnancy == 3)
doe.data.pregnant = false
AnimalDays.keep(doe, 4070)
check("no longer pregnant: the count is forgotten", AnimalDays.recordOf(doe).conceivedAt == nil)

local hare = animal({ age = 100, wild = true })
check("a wild animal is left alone", select(1, AnimalDays.keep(hare, 5000)) == 0 and AnimalDays.recordOf(hare) == nil)

local sheep = animal({ age = 300 })
SandboxVars = { TraditionalPreservationCore = { AnimalsKeepTheirDays = false } }
AnimalDays.keepAll(jlist({ sheep }), 6000)
check("the sandbox off: nothing is kept", AnimalDays.recordOf(sheep) == nil)
SandboxVars = nil
AnimalDays.keepAll(jlist({ sheep }), 6000)
check("on: every animal in the list gets its record", AnimalDays.recordOf(sheep) ~= nil)
AnimalDays.keepAll(jlist({}), 6000 + AnimalDays.FORGET_HOURS + 1)
check("a record not seen for 60 days is dropped", AnimalDays.recordOf(sheep) == nil)

H.done()
