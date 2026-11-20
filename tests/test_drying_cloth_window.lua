-- Checks Drying Cloth Info's band outside the game (empty, a lot lost, too hot, waiting, all dry or drying, the worst
-- first) and the Place row's icon by place. Run from this folder: luajit tests/test_drying_cloth_window.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installGetText({})
H.installEvents()

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end

UIFont = { Small = "small" }
function getTexture(name) return { name = name } end
ISCollapsableWindow = H.class("ISCollapsableWindow")
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local DryingClothUI = require "TraditionalPreservationCore/DryingClothUI"

local function lots(...)
    local list = {}
    for _, status in ipairs({ ... }) do table.insert(list, { status = status }) end
    return { lots = list }
end
local wet, dry, dead = { state = "wet", progress = 0.5 }, { state = "dry" }, { state = "dead" }
local hot, still = { state = "wet", tooHot = true }, { state = "wet", waits = "still" }

local function band(view)
    local word, text, look = DryingClothUI.band(view)
    return word:match("ClothBand(%a+)$"), text, look
end

local word, _, look = band(lots())
check("nothing on it: empty, grey", word == "Empty" and look == InfoWindow.BAND_IDLE)
word, _, look = band(lots(wet, dry))
check("some drying: drying, green", word == "Drying" and look == InfoWindow.BAND_WORKING)
word = band(lots(dry, dry))
check("every lot dry: dry", word == "Dry")
word, _, look = band(lots(wet, still))
check("a lot in still air: waiting, amber", word == "Waiting" and look == InfoWindow.BAND_WAITING)
word, _, look = band(lots(still, hot))
check("too hot beats waiting: red", word == "TooHot" and look == InfoWindow.BAND_AT_RISK)
word, _, look = band(lots(hot, dead, dry))
check("a lot lost beats the rest: red", word == "Lost" and look == InfoWindow.BAND_AT_RISK)

local UI = require "TraditionalPreservationCore/UI"
check("a place has its own icon", UI.placeIcon("AiredRoom").name == "media/textures/TPPlace_AiredRoom.png")
check("by a fire, any fire's place shows the fire", UI.placeIcon("FiresideCovered").name == "media/textures/TPPlace_Fireside.png"
    and UI.placeIcon("EmbersOpen").name == "media/textures/TPPlace_Embers.png")
check("a place with no icon has none", UI.placeIcon("Moon") == nil)

local DryingCloth = require "TraditionalPreservationCore/DryingCloth"
local realKind = DryingCloth.kind
DryingCloth.kind = function(name)
    return ({ cakes = { name = "cakes", pattern = "Cakes.png" }, grains = { name = "grains", pattern = "Grains.png" } })[name]
end
local parts = DryingClothUI.parts({ lots = { { lot = { kind = "cakes" } }, { lot = { kind = "grains" } }, { lot = { kind = "cakes" } } } })
check("the lots' cells by kind: 2 cakes, 1 grains", #parts == 2 and parts[1].pattern == "Cakes.png" and parts[1].weight == 2
    and parts[2].weight == 1)
check("an empty cloth: plain cells", DryingClothUI.parts({ lots = {} }) == nil)
DryingCloth.kind = realKind

H.done()
