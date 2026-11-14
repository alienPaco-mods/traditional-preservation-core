-- Checks the Smokehouse outside the game: the chamber's tiles, joining a Firebox to it, and the fire's two counters
-- on a stack. Run from TraditionalPreservationCore: luajit tests/test_smokehouse.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(100)
H.installModData()
H.installEvents()
local Smokehouse = require "TraditionalPreservationCore/Smokehouse"
local Hearth = require "TraditionalPreservationCore/Hearth"
local Doors = require "TraditionalPreservationCore/Doors"
local Tiles = require "TraditionalPreservationCore/Tiles"

local function name(index) return Tiles.PREFIX .. index end

-- Sprite names: facing S back and door tile, then facing E.
local face, part = Smokehouse.tileOfName(name(Tiles.CHAMBER))
check("the first chamber tile is facing S, back", face == 0 and part == 0)
face, part = Smokehouse.tileOfName(name(Tiles.CHAMBER + 3))
check("the fourth is facing E, door", face == 1 and part == 1)
check("anything else isn't a chamber tile", Smokehouse.tileOfName(name(Tiles.CHAMBER + 4)) == nil
    and Smokehouse.tileOfName(name(Tiles.CHAMBER - 1)) == nil and Smokehouse.tileOfName(nil) == nil)
check("an entry overlay isn't a chamber tile", Smokehouse.tileOfName(name(Tiles.CHAMBER_ENTRY)) == nil)
check("nor is another mod's tile", Smokehouse.tileOfName("traditionalpreservationfishmeat_02_448") == nil)
check("the chamber, its entries and the ham fit the core's sheet", Tiles.CHAMBER_HAM + 1 < Tiles.SHEETS[1].tiles)
check("each door tile opens its way, the back tiles have no door", Doors.facingOf(name(Tiles.CHAMBER + 1)) == "S"
    and Doors.facingOf(name(Tiles.CHAMBER + 3)) == "E" and Doors.facingOf(name(Tiles.CHAMBER)) == nil)
check("the shed takes 6 stacks", Smokehouse.STACKS == 6)

-- The other tile: facing S the door's tile is south of the back one.
local dx, dy = Smokehouse.otherStep(0, 0)
check("facing S the door tile is one south of the back tile", dx == 0 and dy == 1)
dx, dy = Smokehouse.otherStep(1, 1)
check("facing E the back tile is one west of the door tile", dx == -1 and dy == 0)

-- Where a Firebox may stand.
check("facing S the back tile's long sides", Smokehouse.sideAllowed(0, 0, 1, 0) and Smokehouse.sideAllowed(0, 0, -1, 0))
check("facing S the back gable", Smokehouse.sideAllowed(0, 0, 0, -1))
check("never on the shed's other tile", not Smokehouse.sideAllowed(0, 0, 0, 1))
check("facing S the door tile's long sides", Smokehouse.sideAllowed(0, 1, 1, 0) and Smokehouse.sideAllowed(0, 1, -1, 0))
check("never at the door's end", not Smokehouse.sideAllowed(0, 1, 0, 1))
check("facing E: back gable west, door end east", Smokehouse.sideAllowed(1, 0, -1, 0) and not Smokehouse.sideAllowed(1, 1, 1, 0))
check("facing E the door tile's long sides", Smokehouse.sideAllowed(1, 1, 0, 1) and Smokehouse.sideAllowed(1, 1, 0, -1))
check("not diagonal or further away", not Smokehouse.sideAllowed(0, 0, 1, 1) and not Smokehouse.sideAllowed(0, 0, 2, 0))

-- The entry art, only on the side the camera sees (S: east, E: south), numbered as the tile builder's.
check("pipe, facing S, back tile", Smokehouse.entrySprite("Pipe", 0, 0, 1, 0) == Tiles.CHAMBER_ENTRY)
check("pipe, facing E, door tile", Smokehouse.entrySprite("Pipe", 1, 1, 0, 1) == Tiles.CHAMBER_ENTRY + 3)
check("trench, facing S, door tile", Smokehouse.entrySprite("Stones", 0, 1, 1, 0) == Tiles.CHAMBER_ENTRY + 5)
check("trench, facing E, back tile", Smokehouse.entrySprite("Stones", 1, 0, 0, 1) == Tiles.CHAMBER_ENTRY + 6)
check("nothing on hidden sides", Smokehouse.entrySprite("Pipe", 0, 0, -1, 0) == nil and Smokehouse.entrySprite("Pipe", 0, 0, 0, -1) == nil)
check("nothing when the flue isn't laid", Smokehouse.entrySprite(nil, 0, 0, 1, 0) == nil)
check("the ham hangs on the door's tile while stacks wait", Smokehouse.hamSprite(0, 1, true) == Tiles.CHAMBER_HAM
    and Smokehouse.hamSprite(1, 1, true) == Tiles.CHAMBER_HAM + 1)
check("never on the back tile, nor with nothing finished", Smokehouse.hamSprite(0, 0, true) == nil and Smokehouse.hamSprite(0, 1, false) == nil)
check("an overlay's name is the core's", Smokehouse.spriteName(Tiles.CHAMBER_HAM) == "traditionalpreservationcore_01_" .. Tiles.CHAMBER_HAM)

-- The shed's own refusals (Hearth.connectRefusal asks them after "already joined").
check("a long side of a free shed joins", Smokehouse.chamberRefusal({ allowed = true }) == nil)
check("door end refused", Smokehouse.chamberRefusal({ allowed = false }) == "IGUI_TraditionalPreservationCore_FlueDoorEnd")
check("one Firebox a shed", Smokehouse.chamberRefusal({ allowed = true, chamberJoined = true }) == "IGUI_TraditionalPreservationCore_FlueChamberJoined")
local flue = Hearth.connection(Smokehouse.ID)
check("the flue is a Hearth connection by its kits, blocking only its own slot", flue ~= nil and flue.kits == Smokehouse.FLUE_KITS
    and flue.kinds == Smokehouse.FLUE_KINDS and flue.blocks == "connection" and flue.finds ~= nil and flue.joined ~= nil)
check("Connect takes 400 ticks, Disconnect 200, 5 Masonry", flue.kits.Pipe.ticks == 400 and flue.kits.Stones.removeTicks == 200
    and flue.kits.Pipe.xp[1] == "Masonry" and flue.kits.Pipe.xp[2] == 5 and flue.kits.Stones.anim == "DigShovel")

-- Kits.
local missing, noTool = Smokehouse.kitMissing("Pipe", { ["Base.ClayPipeSegment"] = 2, ["Base.Clay"] = 1 }, true)
check("a full pipe kit", #missing == 0 and not noTool)
missing, noTool = Smokehouse.kitMissing("Stones", { ["Base.FlatStone"] = 1 }, false)
check("two flat stones, two clay and the shovel short",
    #missing == 2 and missing[1][1] == "Base.FlatStone" and missing[1][2] == 2 and missing[2][2] == 2 and noTool)
for _, kind in ipairs(Smokehouse.FLUE_KINDS) do
    local kit = Smokehouse.FLUE_KITS[kind]
    local gives = false
    for _, need in ipairs(kit.items) do gives = gives or need[1] == kit.back end
    check(kind .. ": what comes back is part of the kit, and a tool, its text and the kit's texts are named", gives and kit.tool ~= nil
        and kit.toolText ~= nil and kit.text ~= nil and kit.help ~= nil and kit.name ~= nil)
end

-- The build menu's check: not in a room, and the door's front free.
local open = { isInARoom = function() return false end }
local room = { isInARoom = function() return true end }
local oldFits = Doors.fits
Doors.fits = function() return true end
check("a shed may be built in the open", TraditionalPreservationCore.notInRoom({ square = open }))
check("never in a room", not TraditionalPreservationCore.notInRoom({ square = room }))
Doors.fits = oldFits

-- The stack's counters against the Firebox's record (Hearth.logFire), and its owner.
local stack = {}
Smokehouse.startCounters(stack, "SomeMod", 8)
check("a new stack starts at nought, with its owner and need", stack.hot == 0 and stack.cold == 0 and stack.hotNeed == 8
    and Smokehouse.owns(stack, "SomeMod") and not Smokehouse.owns(stack, "OtherMod"))
local fire = {}
Hearth.logFire(fire, 100, nil, nil)
check("joining takes the fire's record as it stands", Smokehouse.fireStep(stack, fire) == nil
    and stack.smokeFrom == fire.fireId and stack.lastStoked == 0)
Hearth.logFire(fire, 101, Hearth.STOKED, 120)
Hearth.logFire(fire, 104, Hearth.STOKED, 120)
local stoked, banked = Smokehouse.fireStep(stack, fire)
check("stoked hours in the session are hot, and handed back", near(stack.hot, 3) and not Smokehouse.hotDone(stack)
    and near(stoked, 3) and banked == 0)
Hearth.logFire(fire, 104.5, nil, nil)
Hearth.logFire(fire, 105, Hearth.STOKED, 120)
Hearth.logFire(fire, 110, Hearth.STOKED, 120)
Smokehouse.fireStep(stack, fire)
check("a short gap keeps the cook going", near(stack.hot, 8.5) and Smokehouse.hotDone(stack))

local cool = {}
Smokehouse.startCounters(cool, "SomeMod", 4)
Smokehouse.fireStep(cool, fire)
Hearth.logFire(fire, 111, Hearth.BANKED, 160)
Hearth.logFire(fire, 115, Hearth.BANKED, 160)
stoked, banked = Smokehouse.fireStep(cool, fire, 0.5)
-- The stoked hour before banking ended its session: smoke too, at the same share.
check("banked hours are smoke by the share of cool hours", near(banked, 4) and near(stoked, 1) and near(cool.cold, 2.5) and cool.hot == 0)

local noCook = { noHot = true }
Smokehouse.startCounters(noCook, "SomeMod", 4)
Smokehouse.fireStep(noCook, fire)
Hearth.logFire(fire, 116, Hearth.STOKED, 160)
Hearth.logFire(fire, 119, Hearth.STOKED, 160)
Smokehouse.fireStep(noCook, fire)
-- An hour banked before the stoking, then three stoked.
check("a stack that never cooks takes stoked hours as smoke at once", noCook.hot == 0 and near(noCook.cold, 4)
    and not Smokehouse.hotDone(noCook))

local moved = { hotNeed = 4, hot = 2, cold = 1, smokeFrom = fire.fireId, lastStoked = fire.stokedHours, lastBanked = fire.bankedHours }
check("disconnected, nothing is handed back", Smokehouse.fireStep(moved, nil) == nil)
check("and the hot hours become smoke", moved.hot == 0 and near(moved.cold, 3) and moved.smokeFrom == nil)

H.done()
