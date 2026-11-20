-- Checks Smokehouse Info's band outside the game (SmokehouseUI.band): the joined Stone Hearth stoked, banked or out
-- in the hearth's colours with its Light / Put Out button, and grey with none joined. Run from
-- TraditionalPreservationCore: luajit tests/test_smokehouse_band.lua
local H = dofile("tests/harness.lua")
local check = H.check
package.path = "42/media/lua/shared/?.lua;42/media/lua/client/?.lua;" .. package.path
H.installClock(100)
H.installModData()
H.installEvents()
H.installGetText()
H.installMenus()

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") or name:find("^TimedActions/TP") then return realRequire(name) end
end

local Fire = require "TraditionalPreservationCore/Fire"
local Smokehouse = require "TraditionalPreservationCore/Smokehouse"
local FireUI = require "TraditionalPreservationCore/FireUI"
local SmokehouseUI = require "TraditionalPreservationCore/SmokehouseUI"

-- A Stone Hearth by its state, and a window that keeps what its band was given.
local hearth = { banked = false, burning = false, fuel = 0 }
local stoneHearth = { getFuelAmount = function() return hearth.fuel end }
Fire.isBanked = function() return hearth.banked end
Fire.isBurning = function() return hearth.burning end
Fire.fuelHours = function() return hearth.fuel / 60 end
local joined = stoneHearth
Smokehouse.joinedStoneHearth = function() return joined end
local window = { playerObj = {} }
function window:band(word, text, colour, dark, entry)
    self.shown = { word = word, text = text, colour = colour, entry = entry }
    return 50
end

local function bandOf(state, fuel, tooWarm)
    hearth.burning, hearth.banked, hearth.fuel = state == "lit" or state == "banked", state == "banked", fuel
    check("the band returns the y under it", SmokehouseUI.band(window, {}, tooWarm) == 50)
    return window.shown
end

local shown = bandOf("lit", 190)
check("stoked: STOKED in the hearth's red, hot smoke and how long it burns, the Extinguisher",
    shown.word == "Stoked" and shown.text == "hot smoke, burns 3 h 10 min" and shown.colour == FireUI.BANDS.lit.colour
    and shown.entry.icon == "Item_Extinguisher", shown.word .. " / " .. shown.text)
shown = bandOf("banked", 120)
check("banked: orange, cold smoke on embers", shown.word == "Banked" and shown.text == "cold smoke, embers 2 h 0 min"
    and shown.colour == FireUI.BANDS.banked.colour and shown.entry.icon == "Item_Extinguisher", shown.text)
shown = bandOf("banked", 120, true)
check("banked on a day the mod says is too warm: says so", shown.text == "too warm for cold smoke, embers 2 h 0 min", shown.text)
shown = bandOf("lit", 190, true)
check("stoked on a warm day: hot smoke all the same", shown.text == "hot smoke, burns 3 h 10 min", shown.text)
shown = bandOf("out", 360)
check("out with wood: grey, no smoke, the wood in it, the Lighter", shown.word == "Out"
    and shown.text == "no smoke, 6 h 0 min of wood in it" and shown.colour == FireUI.BANDS.out.colour
    and shown.entry.icon == "Item_Lighter", shown.text)
shown = bandOf("out", 0)
check("out with no wood", shown.text == "no smoke, no wood in it", shown.text)
joined = nil
shown = bandOf("out", 0)
check("none joined: grey NO FIRE, how to join one, no button", shown.word == "No Fire"
    and shown.text == "join a Stone Hearth beside the shed" and shown.entry == nil, shown.text)

H.done()
