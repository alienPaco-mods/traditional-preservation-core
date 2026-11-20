-- Checks the Drying Cloth (DryingCloth: lots in its room, drying by place, the shut room's still air, heat that kills) on
-- stand-ins for the engine. Run from TraditionalPreservationCore: luajit tests/test_drying_cloth.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near
package.path = "42/media/lua/shared/?.lua;" .. package.path
H.installClock(0)
H.installModData()

local DryingCloth = require "TraditionalPreservationCore/DryingCloth"
local Tiles = require "TraditionalPreservationCore/Tiles"

local given = {}
local cakes = DryingCloth.register({
    name = "testCakes", title = "Cakes", types = { ["Test.Cake"] = true }, room = 10, perLot = 1, hours = 168,
    curve = { { 0, 0 }, { 15, 1 }, { 25, 1 } }, killAbove = 35,
    sprite = function(lot, state) return "cake_" .. lot .. "_" .. state end,
    lay = function(items) return { first = items[1]:getFullType() } end,
    give = function(lot, inventory, state) table.insert(given, lot.kind .. ":" .. state .. ":" .. lot.count) end,
})
DryingCloth.register({
    name = "testGrains", title = "Grains", types = { ["Test.Grain"] = true }, room = 1, hours = 48,
    curve = { { 0, 0 }, { 25, 1 } },
    sprite = function(lot, state) return "grain_" .. lot .. "_" .. state end,
    give = function(lot, inventory, state) table.insert(given, lot.kind .. ":" .. state .. ":" .. lot.count) end,
})

local function item(fullType)
    return { getFullType = function() return fullType end }
end

local function cloth(face)
    local self = { modData = {} }
    function self:getModData() return self.modData end
    function self:hasModData() return true end
    function self:getSprite() return { getName = function() return Tiles.CLOTHS[face or 1] end } end
    return self
end

-- A day of steady weather at celsius everywhere (open, shut room and the rest track it alike enough here).
local function weather(hours, celsius)
    for _ = 1, hours do
        H.setHours(H.hours + 1)
        DryingCloth.recordWeather(H.hours, celsius)
    end
end

check("a cloth tile is a cloth, others aren't", DryingCloth.isCloth(cloth()) and DryingCloth.isCloth(cloth(2))
    and not DryingCloth.isCloth({ getSprite = function() return { getName = function() return "x" end } end }))
check("kinds are found by what they take", DryingCloth.kindOf("Test.Cake") == cakes and DryingCloth.kindOf("Base.Apple") == nil)

-- Lots
local open = cloth()
DryingCloth.getLedger()
check("an empty cloth has room for five batches of cakes or fifty grains", DryingCloth.isEmpty(DryingCloth.recordOf(open))
    and DryingCloth.fits(DryingCloth.recordOf(open), cakes) == 5 and DryingCloth.fits(DryingCloth.recordOf(open), DryingCloth.kind("testGrains")) == 50)
check("a lay is one lot, ids in order", DryingCloth.lay(open, { item("Test.Cake") }, H.hours, "Open") == 1
    and DryingCloth.lay(open, { item("Test.Grain"), item("Test.Grain"), item("Test.Grain") }, H.hours, "Open") == 2)
local record = DryingCloth.recordOf(open)
check("a lot keeps its kind, count and data", record.lots[1].kind == "testCakes" and record.lots[1].data.first == "Test.Cake"
    and record.lots[2].count == 3)
check("the room used is each piece's room", DryingCloth.roomUsed(record) == 13 and DryingCloth.fits(record, cakes) == 3)
check("each spot shows the lot covering most of it", table.concat(DryingCloth.lotSprites(record), " ") == "cake_0_wet grain_1_wet")
check("unknown items lay nothing", DryingCloth.lay(open, { item("Base.Apple") }, H.hours, "Open") == nil)

-- Drying: 48 hours at 25 C dries the grains, the cakes (a week at full speed) are on their way.
weather(48, 25)
record = DryingCloth.update(open, H.hours, "Open")
check("grains dry in two days at 25 C", DryingCloth.state(record.lots[2]) == "dry")
check("cakes are two sevenths dried", near(record.lots[1].dry.age, 48) and DryingCloth.state(record.lots[1]) == "wet")
local status = DryingCloth.status(record.lots[1], 25, "Open")
check("the status says how long is left", near(status.hoursLeft, 120) and near(status.progress, 48 / 168))
check("and frost waits", DryingCloth.status(record.lots[1], -3, "Open").waits == "frozen")

-- Taking off: the finished lot only, then everything (the wet cakes come back as they went).
check("take gives what its kind gives", DryingCloth.take(open, 2, {}) == "dry" and given[1] == "testGrains:dry:3")
check("a taken lot's room is free again", DryingCloth.roomUsed(DryingCloth.recordOf(open)) == 10 and DryingCloth.take(open, 2, {}) == nil)
DryingCloth.take(open, 1, {})
check("a wet lot comes off wet", given[2] == "testCakes:wet:1" and DryingCloth.isEmpty(DryingCloth.recordOf(open)))

-- A shut room's still air dries nothing; a window opened, it goes on.
local shut = cloth()
DryingCloth.lay(shut, { item("Test.Grain") }, H.hours, "Sheltered")
weather(24, 25)
record = DryingCloth.update(shut, H.hours, "AiredRoom")
check("a day in a shut room dried nothing", record.lots[1].dry.age == 0)
check("and its status waits for a window", DryingCloth.status(record.lots[1], 25, "Sheltered").waits == "still")
weather(24, 25)
record = DryingCloth.update(shut, H.hours, "AiredRoom")
check("the aired room dries it", record.lots[1].dry.age > 20)

-- Too hot: past killAbove for KILL_HOURS, cakes die; grains have no limit.
local hot = cloth()
DryingCloth.lay(hot, { item("Test.Cake") }, H.hours, "Open")
DryingCloth.lay(hot, { item("Test.Grain") }, H.hours, "Open")
weather(2, 38)
record = DryingCloth.update(hot, H.hours, "Open")
check("two hours at 38 C kill the cakes", DryingCloth.state(record.lots[1]) == "dead" and DryingCloth.lotSprites(record)[1] == "cake_0_dead")
check("but not the grains", DryingCloth.state(record.lots[2]) == "wet")
check("the status warns of the heat first", DryingCloth.status({ kind = "testCakes", dry = { age = 0 } }, 37, "Open").tooHot)
check("the look key follows the states", DryingCloth.lookKey(record) == "testCakesdead,testGrainswet,-,-,-")

-- The room: lays fill it in any mix, a lay too big takes what fits, a full cloth takes nothing.
local full = cloth()
local grains = {}
for _ = 1, 25 do table.insert(grains, item("Test.Grain")) end
DryingCloth.lay(full, { item("Test.Cake") }, H.hours, "Open")
DryingCloth.lay(full, { item("Test.Cake") }, H.hours, "Open")
local id, count = DryingCloth.lay(full, grains, H.hours, "Open")
check("a lay takes as many as fit", id == 3 and count == 25)
id, count = DryingCloth.lay(full, { item("Test.Cake"), item("Test.Cake") }, H.hours, "Open")
record = DryingCloth.recordOf(full)
check("the last batch fills only the room left", id == nil and DryingCloth.fits(record, cakes) == 0
    and DryingCloth.fits(record, DryingCloth.kind("testGrains")) == 5)
DryingCloth.lay(full, { item("Test.Grain"), item("Test.Grain"), item("Test.Grain"), item("Test.Grain"), item("Test.Grain"), item("Test.Grain") }, H.hours, "Open")
check("fifty is full", DryingCloth.roomUsed(record) == 50 and #record.lots == 4 and record.lots[4].count == 5)
check("the spots follow the room in the order laid", table.concat(DryingCloth.lotSprites(record), " ")
    == "cake_0_wet cake_1_wet grain_2_wet grain_3_wet grain_4_wet")
DryingCloth.take(full, 1, {})
check("taken off, the rest move up", table.concat(DryingCloth.lotSprites(record), " ") == "cake_0_wet grain_1_wet grain_2_wet grain_3_wet")
local apart = cloth()
id, count = DryingCloth.lay(apart, { item("Test.Cake"), item("Test.Cake"), item("Test.Cake") }, H.hours, "Open")
check("a kind with perLot 1 lays one piece a lot", id == 1 and count == 1 and DryingCloth.roomUsed(DryingCloth.recordOf(apart)) == 10)
local split = DryingCloth.lotsOf(cakes, { 1, 2, 3 })
local whole = DryingCloth.lotsOf(DryingCloth.kind("testGrains"), { 1, 2, 3 })
check("lotsOf: perLot each, else one lot", #split == 3 and #split[2] == 1 and #whole == 1 and #whole[1] == 3)
local few = cloth()
DryingCloth.lay(few, { item("Test.Grain") }, H.hours, "Open")
check("one grain still shows a spot", table.concat(DryingCloth.lotSprites(DryingCloth.recordOf(few)), " ") == "grain_0_wet")

-- A cloth from before the room: five fixed lots, false when free, packed into the list with ids.
local old = cloth()
old.modData[DryingCloth.KEY] = { lots = { false, { kind = "testGrains", count = 10, dry = { age = 0 } }, false,
    { kind = "testCakes", count = 1, dry = { age = 0 } }, false } }
record = DryingCloth.recordOf(old)
check("an old cloth's lots are packed", #record.lots == 2 and record.lots[1].id == 1 and record.lots[2].kind == "testCakes"
    and record.nextId == 3 and DryingCloth.roomUsed(record) == 20)

-- A kind that goes off: whichever comes first, gone off or dry, wins.
local offAt = {}
DryingCloth.register({
    name = "testCurd", title = "Curd", types = { ["Test.Curd"] = true }, room = 10, hours = 48,
    curve = { { 0, 0 }, { 25, 1 } },
    sprite = function(lot, state) return "curd_" .. lot .. "_" .. state end,
    lay = function(items, now, place) return { laidAt = now, place = place } end,
    goesOff = function(lot, now)
        local limit, from = offAt[lot.data.laidAt], lot.data.seen or lot.data.laidAt
        lot.data.seen = now
        if now < limit then return nil end
        return math.max((limit - from) / (now - from), 0)
    end,
    give = function(lot, inventory, state) table.insert(given, lot.kind .. ":" .. state) end,
})
local curd = cloth()
DryingCloth.lay(curd, { item("Test.Curd") }, H.hours, "Open")
check("lay hands the kind the hour and place", DryingCloth.recordOf(curd).lots[1].data.place == "Open")
offAt[H.hours] = H.hours + 20
weather(24, 25)
record = DryingCloth.update(curd, H.hours, "Open")
check("a lot that goes off before it dries is dead, spoiled", DryingCloth.state(record.lots[1]) == "dead" and record.lots[1].spoiled
    and DryingCloth.status(record.lots[1], 25, "Open").spoiled)
local race = cloth()
DryingCloth.lay(race, { item("Test.Curd") }, H.hours, "Open")
offAt[H.hours] = H.hours + 47
weather(60, 25)
record = DryingCloth.update(race, H.hours, "Open")
check("in one long stretch the earlier wins: dry at 48 h loses to gone off at 47", record.lots[1].spoiled == true)
local quick = cloth()
DryingCloth.lay(quick, { item("Test.Curd") }, H.hours, "Open")
offAt[H.hours] = H.hours + 55
weather(60, 25)
record = DryingCloth.update(quick, H.hours, "Open")
check("dry first: it is dry, and keeps", DryingCloth.state(record.lots[1]) == "dry" and not record.lots[1].spoiled)
weather(24, 25)
record = DryingCloth.update(quick, H.hours, "Open")
check("a dry lot no longer goes off", DryingCloth.state(record.lots[1]) == "dry")

H.done()
