-- Traditional Preservation core: animals keep their days. Vanilla (42.22) ages an animal a day, moves its pregnancy on
-- a day and grows it (AnimalData.growUp) only once its hour count reaches the next whole day while loaded, and a pen's
-- catch-up when the player comes back (IsoAnimal.updateStatsAway) sets that count back to whole days, adding the time
-- away in whole days only. Coming and going in less than a day, an animal loses every part-day: ages, pregnancies and
-- growth stand still (user's long save, 2026-11-25: a bull 502 days old for four days running). Here each animal keeps
-- its own count by the calendar, by its id in the world's mod data. Its age is pushed forward when vanilla's falls
-- behind, a day at a time through vanilla's own growUp (size, weight, the day's eggs), the hour count to match; never
-- back, as vanilla's age catch-up only ever counts whole days that passed (a trip of whole days becomes ours). Its
-- pregnancy day is set to the day from the conception, both ways: vanilla's catch-up replays the hours away from the
-- animal's own last-update clock, often stale, and moves a pregnancy on at each midnight it passes, so the same
-- midnight can count twice (user's long save, 2026-11-26: an Angus cow 3 days ahead in 2). Hourly things (milk,
-- hunger, thirst) are vanilla's catch-up as ever. Wild animals are left alone.
-- Sandbox Animals keep their days (on). Called every ten minutes by AnimalDaysWorld.lua.
local AnimalDays = {}

AnimalDays.KEY = "TraditionalPreservationCoreAnimalDays"
AnimalDays.FORGET_HOURS = 60 * 24   -- a record not seen for this long (butchered, sold off, lost) is dropped

function AnimalDays.on()
    local options = SandboxVars and SandboxVars.TraditionalPreservationCore
    return not options or options.AnimalsKeepTheirDays ~= false
end

function AnimalDays.records()
    return ModData.getOrCreate(AnimalDays.KEY)
end

-- The record of an animal, or nil: { hours, at, pregnancy, conceivedAt, kept, keptPregnancy, trimmedPregnancy,
-- seen }.
function AnimalDays.recordOf(animal)
    return AnimalDays.records()[tostring(animal:getAnimalID())]
end

-- Brings one animal's days up to now (world hours). Returns the days of age it added and the days its pregnancy moved
-- (less than 0 when vanilla's had run ahead).
function AnimalDays.keep(animal, now, records)
    if animal:isWild() then return 0, 0 end
    records = records or AnimalDays.records()
    local id = tostring(animal:getAnimalID())
    local data = animal:getData()
    local record = records[id]
    local hours = animal:getHoursSurvived()
    if not record then
        record = { hours = math.max(hours, data:getAge() * 24), at = now, kept = 0, keptPregnancy = 0 }
        records[id] = record
    end
    -- Our count: what it had, plus the time since. Vanilla's ahead of it (a whole-day catch-up) is taken as it is.
    local ours = math.max(record.hours + math.max(0, now - record.at), hours)
    local addedAge, addedPregnancy = 0, 0

    local pregnant = data:isPregnant()
    local pregnancy = pregnant and data:getPregnancyTime() or 0
    local target = math.floor(ours / 24)
    local age = data:getAge()
    while age < target do
        age = age + 1
        data:setAge(age)
        data:growUp(false)
        addedAge = addedAge + 1
    end
    -- growUp moves the pregnancy on too; the pregnancy is counted on its own from the conception below.
    if pregnant then data:setPregnancyTime(pregnancy) end
    if hours < ours then animal:setHoursSurvived(ours) end

    if pregnant then
        -- A pregnancy count lower than last seen is a new one (a birth and a mating while away): counted from it.
        if not record.conceivedAt or pregnancy < (record.pregnancy or 0) then
            record.conceivedAt = now - pregnancy * 24
        end
        local due = math.floor((now - record.conceivedAt) / 24)
        if pregnancy ~= due then
            addedPregnancy = due - pregnancy
            pregnancy = due
            data:setPregnancyTime(pregnancy)
        end
        record.pregnancy = pregnancy
    else
        record.conceivedAt, record.pregnancy = nil, nil
    end

    record.hours, record.at, record.seen = ours, now, now
    record.kept = (record.kept or 0) + addedAge
    if addedPregnancy > 0 then
        record.keptPregnancy = (record.keptPregnancy or 0) + addedPregnancy
    else
        record.trimmedPregnancy = (record.trimmedPregnancy or 0) - addedPregnancy
    end
    return addedAge, addedPregnancy
end

-- Every loaded animal, then the records of animals not seen for FORGET_HOURS dropped.
function AnimalDays.keepAll(animals, now)
    if not AnimalDays.on() then return end
    local records = AnimalDays.records()
    for i = 0, animals:size() - 1 do
        AnimalDays.keep(animals:get(i), now, records)
    end
    for id, record in pairs(records) do
        if now - (record.seen or record.at or now) > AnimalDays.FORGET_HOURS then records[id] = nil end
    end
end

return AnimalDays
