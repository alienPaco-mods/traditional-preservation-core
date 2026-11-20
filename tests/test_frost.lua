-- Checks Frost (hours at or below a freezing point, by place) on stand-ins for the engine. Run from
-- TraditionalPreservationCore: luajit tests/test_frost.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near
package.path = "42/media/lua/shared/?.lua;" .. package.path
H.installClock(0)
H.installModData()

local Frost = require "TraditionalPreservationCore/Frost"
local Weather = require "TraditionalPreservationCore/Weather"

Frost.recordWeather(1, -20)
check("no point named: nothing is recorded, no ledger made", H.modData[Frost.LEDGER_KEY] == nil)

local potato = Frost.point(-1)
check("a point's kind: its process named by the point, frozen at or below it",
    potato.process == "frostAt-1" and potato.rate(-1) == 1 and potato.rate(-0.9) == 0 and potato.rate(-12) == 1)
check("the same point twice is one kind", Frost.point(-1) == potato and Frost.point(-2.5).process == "frostAt-2.5")

local ledger = Frost.ledger()
check("its ledger lives under its key, with totals for every point and place",
    H.modData[Frost.LEDGER_KEY].ledger == ledger and ledger["frostAt-1Open"] == 0 and ledger["frostAt-2.5Basement"] == 0)

local leek = Frost.point(-10)
check("a point named after the ledger was made gets its totals on the next look", Frost.ledger()["frostAt-10Open"] == 0)

local open = Frost.newRecord(potato, 0, "Open", ledger)
local cellar = Frost.newRecord(potato, 0, "Basement", ledger)
local fridge = Frost.newRecord(potato, 0, "Fridge", ledger)
local freezer = Frost.newRecord(potato, 0, "Freezer", ledger)
check("a new record has no frozen hours", open.age == 0 and cellar.age == 0)
-- Ten hours at -5 C, then ten at +3 C.
for hour = 1, 10 do Frost.recordWeather(hour, -5) end
for hour = 11, 20 do Frost.recordWeather(hour, 3) end
check("in the open ten hours at -5 C are ten frozen hours", near(Frost.catchUp(open, potato, 20, "Open", nil, ledger), 10, 1e-6))
check("a basement follows the ground, never frozen here", Frost.catchUp(cellar, potato, 20, "Basement", nil, ledger) == 0)
check("a powered fridge never freezes", Frost.catchUp(fridge, potato, 20, "Fridge", nil, ledger) == 0)
check("a powered freezer counts nothing (vanilla's rules)", Frost.catchUp(freezer, potato, 20, "Freezer", nil, ledger) == 0)
check("the record keeps its frozen hours in all and the place it is in now", near(open.age, 10, 1e-6) and open.place == "Open")
for hour = 21, 30 do Frost.recordWeather(hour, -5) end
check("the next look gives only the hours since", near(Frost.catchUp(open, potato, 30, "Sheltered", nil, ledger), 10, 1e-6)
    and near(open.age, 20, 1e-6) and open.place == "Sheltered")
check("each point counts on its own: -5 C is no frost for a leek", ledger["frostAt-10Open"] == 0 and near(ledger["frostAt-1Open"], 20, 1e-6))

-- By a fire: the time counts at the fire's heat while the noted fuel lasted.
local Fire = require "TraditionalPreservationCore/Fire"
local byFire = Frost.newRecord(potato, 30, Fire.PLACE, ledger)
byFire.fireUntil, byFire.placeWithoutFire = 40, "Open"
for hour = 31, 50 do Frost.recordWeather(hour, -5) end
check("by a fire nothing freezes while the fuel lasts, the open air's frost after it ran out",
    near(Frost.catchUp(byFire, potato, 50, "Open", nil, ledger), 10, 1e-6))

check("freezing now: the open at -5 C yes, a fridge never, a freezer always, a basement not",
    Frost.freezingAt(potato, "Open", ledger) and not Frost.freezingAt(potato, "Fridge", ledger)
    and Frost.freezingAt(potato, "Freezer", ledger) and not Frost.freezingAt(potato, "Basement", ledger)
    and not Frost.freezingAt(leek, "Open", ledger))
check("the ledger is Weather's: a place's temperature is Core's", Weather.placeTemperature(ledger, "Open") == -5)

H.done()
