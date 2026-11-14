-- Traditional Preservation core: the Stone Hearth, a low stone firebox with a lined hole in its top, shared by every TP
-- mod; with the cauldron fitted (Stone Hearth (Cauldron), "the Hearth" in the code) the Forged Cauldron hangs over the hole.
-- The built tile is swapped for a vanilla fireplace, as the Barrel Oven's is (BuildRecipeCode.barrelOven.OnCreate),
-- so vanilla gives it fuel, lighting, burn time, room heat and a firebox to cook in. Its state is a plain table in the
-- fireplace's modData under KEY.
--
-- Hearth is the one name callers use; four files hold its parts, and it passes their functions on:
--   CauldronFluid.lua   what the cauldron holds: heating, boiling, blends, the pour hooks (Hearth.pourInto, .advance,
--                       .hook, ...), and its numbers (Hearth.MAX_C, ...)
--   HearthConnect.lua   connections, the second slot (Hearth.connect, .join, ...)
--   HearthPlace.lua     "by a fire" as a place, and the work done there (Hearth.placeOf, .catchUp, .notePlace, ...);
--                       its numbers (PLACE, FIRE_C, EMBERS, the lifts) are here, registered with Weather at load
--   Cauldron.lua        the cauldron as an attachment (Fit, Remove, its look and heats)
--
-- What sits on the fire is an attachment (Hearth.attach, ATTACHMENTS below): the cauldron is the first, written in
-- Cauldron.lua, CauldronUI.lua and HearthWorld against that registry alone, so a mod can add its own (Salt's salt pan).
-- Two slots (user, 2026-11-13): one attachment fitted on the fire (the Cauldron, later Salt's pan) and one connection
-- built onto it (Hearth.connect: the Smokehouse's flue), each free of the other unless the connection blocks both.
-- The fire's state names the attachment (attached: false once one has come off), and the attachment's own state is
-- kept under its id there. Fit and Remove are Core's (Hearth.canFit, Hearth.fit, Hearth.unfit; TPHearthFit), by the
-- attachment's fit.
--
-- A lit Hearth can be banked: the fire raked down under its ash. It burns BANKED_BURN of the wood a lit fire does,
-- the cauldron settles at BANKED_C, and beside it is a place of its own (EMBERS, at EMBERS_C). Vanilla's fireplace has
-- one speed and heats and lights 8 tiles whatever its fuel (ENGINE_NOTES), so a banked Hearth's vanilla fire is out:
-- the mod counts its fuel from the clock (Hearth.reckonFuel) and sets vanilla's to the count, gives it its own small
-- heat and faint light, and keeps the firebox hot (HearthWorld). Hearth.isBurning is a fire lit or banked.
--
-- A Stone Hearth with nothing fitted is "the Firebox" in the code (Hearth.isFirebox): a cooking source through the
-- hole, banked and stoked the same way. Its state is the same table (no attachment). What shows in the hole is its
-- look (Hearth.holeLook): open, a forged pot when a stove food or a fluid is inside (Hearth.cooksOn), a lid when only
-- oven food is. Any Stone Hearth, fitted or not, may have something joined to its back or either flank, never the
-- door's side (HearthConnect): its tile is picked by facing and hole alone, the hole lidded under a connection that
-- takes the smoke. Hearth.isFire is any Stone Hearth, fitted or not.
local Weather = require "TraditionalPreservationCore/Weather"
local Station = require "TraditionalPreservationCore/Station"
local Tiles = require "TraditionalPreservationCore/Tiles"
local Doors = require "TraditionalPreservationCore/Doors"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"

local Hearth = {}

-- What the cauldron holds: its rules and numbers, all reached here (Hearth.pourInto, Hearth.MAX_C, ...).
for name, value in pairs(CauldronFluid) do Hearth[name] = value end

-- Save key: never rename it once the mod is out (DEVGUIDE, "Rules that keep saves and the game happy").
-- Inside: fireUntil; banked, fuel, fuelAt, fuelSet; attached (the id of what is fitted); connected (the id of what is
-- joined, its kind and side under that id);
-- the fire's record (Hearth.logFire):
-- fireId, fireAt, fireMode, fireEnds, stokedHours, bankedHours, session, sessionBase, stokedLast; and each attachment's
-- state under its id: the cauldron's (CAULDRON) ml, fluid, parts, tempC, last, boiled, hot, held, offAt.
Hearth.KEY = "tpHearth"
Hearth.CAULDRON = "cauldron"

-- By a fire. A fireplace, an antique stove or a campfire, never an electric or gas stove.
Hearth.PLACE = "Hearth"
Hearth.FIRE_C = 28
Hearth.FIRE_RADIUS = 2
Hearth.DEFAULT_UNDER = Weather.DEFAULT_PLACE   -- the place under a fire when none was noted: a room

-- Banked
Hearth.BANKED_BURN = 1 / 3         -- of the wood a lit fire burns: a banked fire lasts three times as long
Hearth.EMBERS = "Embers"           -- the place by a banked Hearth
Hearth.EMBERS_C = 24
Hearth.BANKED_HEAT_RADIUS = 2      -- tiles of room heat around banked embers (a lit fire: 8)
Hearth.BANKED_HEAT_C = 25          -- that heat (a lit fire: 35 C)
Hearth.BANKED_LIGHT_RADIUS = 1
Hearth.BANKED_LIGHT = { 0.6, 0.25, 0.1 }
Hearth.BANKED_FIREBOX = 1.8        -- the firebox's heat (vanilla's container temperature): it cooks, a third as fast
Hearth.MINUTES_PER_HOUR = 60       -- vanilla's fuel is minutes

-- What a fire adds to the air under an open roof (the season's) and in the open (the day's), lit and banked.
Hearth.FIRE_LIFT = { Covered = 15, Open = 10 }
Hearth.EMBERS_LIFT = { Covered = 10, Open = 5 }

-- Save values: a station's noted place. Never rename them.
for _, fire in ipairs({ { Hearth.PLACE, Hearth.FIRE_C, Hearth.FIRE_LIFT }, { Hearth.EMBERS, Hearth.EMBERS_C, Hearth.EMBERS_LIFT } }) do
    local place, celsius, lifts = fire[1], fire[2], fire[3]
    Weather.FIRE_PLACES[place] = { celsius = celsius }
    for under, lift in pairs(lifts) do
        Weather.FIRE_PLACES[place .. under] = { celsius = celsius, under = under, lift = lift }
    end
end

-- The fire's record, for whatever hangs over it (Fish & Meat's Smokehouse). Hours of stoked (lit) and banked fire,
-- and the stoked session now running: unbroken stoking, a gap of up to SESSION_GRACE hours (more wood, a dip) kept.
Hearth.SESSION_GRACE = 1
Hearth.STOKED = "stoked"
Hearth.BANKED = "banked"

-- Adds the time since the last look to the record, as the fire was then (mode, burning until ends), and notes the
-- fire as it is now. Hours count only up to when the fire was due to go out: vanilla burns a lit fire's time away
-- in one go when its chunk loads again (ENGINE_NOTES), so its fuel afterwards can't say when it went out. A session
-- ends once the fire hasn't been stoked for more than SESSION_GRACE hours; stoking again starts a new one (session =
-- when it began, sessionBase = the stoked hours before it). fireId tells one fire's record from a rebuilt one's.
function Hearth.logFire(state, now, mode, ends)
    state.fireId = state.fireId or now
    local at = state.fireAt
    if at and now > at and state.fireMode then
        local stop = math.max(math.min(now, state.fireEnds or now), at)
        local hours = stop - at
        if state.fireMode == Hearth.STOKED then
            state.stokedHours = (state.stokedHours or 0) + hours
            state.stokedLast = stop
        else
            state.bankedHours = (state.bankedHours or 0) + hours
        end
    end
    if state.session and now - (state.stokedLast or now) > Hearth.SESSION_GRACE then
        state.session, state.sessionBase = nil, nil
    end
    if mode == Hearth.STOKED and not state.session then
        state.session, state.sessionBase, state.stokedLast = now, state.stokedHours or 0, now
    end
    state.fireAt, state.fireMode, state.fireEnds = now, mode, ends
end

-- The stoked hours of the session now running, or 0.
function Hearth.sessionHours(state)
    if not state.session then return 0 end
    return (state.stokedHours or 0) - (state.sessionBase or 0)
end

function Hearth.stateOf(modData)
    modData[Hearth.KEY] = modData[Hearth.KEY] or {}
    return modData[Hearth.KEY]
end

-- An attachment's own state, under its id in the fire's.
function Hearth.partState(modData, id)
    local state = Hearth.stateOf(modData)
    state[id] = state[id] or {}
    return state[id]
end

function Hearth.cauldronState(modData)
    return Hearth.partState(modData, Hearth.CAULDRON)
end

-- A registry of specs by id (attachments here, HearthConnect's connections). add(spec) registers one by spec.id, or
-- adds the fields given to one already registered, so its rules can be given in shared Lua and its menu in client
-- Lua; a field already given may not be given again as something else. get(id) is one, list() every one in the order
-- registered. kind names the registering function in its errors.
function Hearth.registry(kind)
    local specs, order = {}, {}
    local registry = {}
    function registry.add(spec)
        assert(type(spec.id) == "string", kind .. ": a spec needs an id")
        local known = specs[spec.id]
        if not known then
            known = {}
            specs[spec.id] = known
            table.insert(order, spec.id)
        end
        for key, value in pairs(spec) do
            assert(known[key] == nil or known[key] == value, kind .. " " .. spec.id .. ": " .. key .. " is already given")
            known[key] = value
        end
        return known
    end
    function registry.get(id)
        return specs[id]
    end
    function registry.list()
        local list = {}
        for _, id in ipairs(order) do table.insert(list, specs[id]) end
        return list
    end
    return registry
end

-- Attachments: what is fitted on a fire, one at a time, registered with Hearth.attach (Hearth.registry). Each
-- function gets the attachment's own state (part) and the fireplace; fireState is the fire's.
--   name                                  its text key
--   fit                                   what Fit takes: { items = { {full type, count} }, tool (an ItemTag's
--                                         name, kept), ticks, removeTicks, xp = { perk, amount }, lost = { full type
--                                         = true } }; Remove gives the items back, all but lost ones
--   fitHelp, fitIcon                      client: Fit's tooltip line (a text key) and Fit / Remove's icon path
--   canRemove(part, fire)                 true, or false and a reason; never asked while the fire burns
--   look(part, fire)                      the look its tile shows (the cauldron's: Empty, Full, Hot)
--   sprite(look, face, burning, banked)   its tile by look, facing and fire, the fire's glow drawn in it (the
--                                         cauldron's Hearth.sprite if left out)
--   overlay(part, face, burning, banked)  its overlay sprite and, to tint it, { r, g, b } (0-1), or nil (the
--                                         cauldron's Hearth.liquidOverlay if left out: what it holds, coloured)
--   heats(part, fire, now, fireState, airC)  brings what it holds up to now, by the fire and the place's air
--   onFire(part, fire, now, fireState)    after each refresh, the look and glow set
--   display                               client: how the fitted Stone Hearth shows, { icon, title (a text key: its
--                                         submenu and Info window), info (the Info row's text key), fire = { bank,
--                                         stoke } (Bank / Stoke's icons) }; the cauldron's if left out
--   status(part)                          client: the menu's first row, text and icon
--   menu(menu, playerObj, fire, part)     client: its rows, after Bank / Stoke
--   rows(window, y, info) -> y            client: its rows in the Info window; info.part is the part
--   notes(info, notes)                    client: its Info notes (HearthUI.notes has info)
local ATTACHMENTS = Hearth.registry("Hearth.attach")

function Hearth.attach(spec)
    local known = ATTACHMENTS.add(spec)
    assert(not spec.fit or type(spec.fit.items) == "table", "Hearth.attach " .. known.id .. ": fit needs items")
    return known
end

Hearth.attachment = ATTACHMENTS.get

-- Every attachment, in the order registered.
Hearth.attachments = ATTACHMENTS.list

-- Banks the fire (banked true) or stokes it up again, with fuel minutes in vanilla's fireplace now.
function Hearth.setBanked(state, banked, fuel, now)
    state.banked = banked or nil
    if banked then
        state.fuel, state.fuelAt, state.fuelSet = fuel, now, fuel
    else
        state.fuel, state.fuelAt, state.fuelSet = nil, nil, nil
    end
end

-- The fuel a banked fire has left now, from vanilla's fuel (minutes) and whether vanilla's fire is lit (it is out
-- while banked). Returns the fuel to give vanilla's fireplace, nil to leave it alone. The count runs on the clock,
-- away time included; wood added since the last reckoning counts in full. Burnt down, the fire is out and no longer
-- banked. Lit by anything but stoking, it is a lit fire again.
function Hearth.reckonFuel(state, fuel, lit, now)
    if not state.banked then return nil end
    if lit then
        Hearth.setBanked(state, false)
        return nil
    end
    if not state.fuel then
        Hearth.setBanked(state, true, fuel, now)
        return nil
    end
    local left = state.fuel - (now - state.fuelAt) * Hearth.MINUTES_PER_HOUR * Hearth.BANKED_BURN + math.max(fuel - state.fuelSet, 0)
    if left < 1 then
        Hearth.setBanked(state, false)
        return 0
    end
    state.fuel, state.fuelAt, state.fuelSet = left, now, math.ceil(left)
    return state.fuelSet
end

-- A banked firebox cooks as slowly as it burns: vanilla adds cooking time at full speed, so of the minutes cooked
-- since before, only BANKED_BURN count. Returns the cooking time the food should have.
function Hearth.bankedCooking(before, now)
    if now <= before then return now end
    return before + (now - before) * Hearth.BANKED_BURN
end

-- Tiles: one per fire (out, lit, banked), still or steaming, and facing, all of them fireplaces. The fire's glow is
-- drawn in them, so the overlay is free for the liquid: the one thing the game tints per object (ENGINE_NOTES).
Hearth.LOOKS = Tiles.HEARTH_LOOKS or {}
Hearth.SPRITES = Tiles.HEARTHS or {}
Hearth.FACE_COUNT = Tiles.FACE_COUNT or 2

-- The hearth's own sprite is swapped among its looks, so each look is a "kind" of tile here.
local _, HEARTH_TILES = Station.kinds(Tiles.PREFIX, Hearth.FACE_COUNT, Hearth.LOOKS)

-- The facing (0 S, 1 E) of a cauldron tile, whatever the cauldron shows; nil for any other tile.
function Hearth.face(spriteName)
    return spriteName and HEARTH_TILES.face[spriteName]
end

-- The tile for the cauldron's look (Empty, Full, Hot: Hot steams) and the fire, lit or banked; out if neither is given.
function Hearth.sprite(look, face, burning, banked)
    local tile = (burning and (banked and "Banked" or "Lit") or "") .. (look == "Hot" and "Steam" or "")
    return Tiles.PREFIX .. (Hearth.LOOKS[tile ~= "" and tile or "Cold"] + face)
end

-- What the cauldron holds, as the overlay: a pale surface in the kettle's mouth, tinted the colour of its fluids (each
-- vanilla fluid's own, mixed by their shares). Nil when it is empty.
Hearth.LIQUID = Tiles.LIQUID

function Hearth.liquidOverlay(cauldron, face)
    if not Hearth.LIQUID or (cauldron.ml or 0) <= 0 then return nil end
    return Tiles.PREFIX .. (Hearth.LIQUID + face), Hearth.liquidColour(cauldron)
end

-- The Stone Hearth with nothing fitted: one tile per hole look and facing (FIREBOX_LOOKS: Open, Lid, Pot), its glow by
-- fire, smoke and hole. Connections draw their own sprites, so the stone has no flue tiles (dropped 2026-11-14).
Hearth.FIREBOX_LOOKS = Tiles.FIREBOX_LOOKS or {}
Hearth.FIREBOX_SPRITES = Tiles.FIREBOXES or {}
Hearth.FIREBOX_GLOWS = Tiles.FIREBOX_GLOWS or {}
Hearth.OPEN, Hearth.LID, Hearth.POT = "Open", "Lid", "Pot"
local _, FIREBOX_TILES = Station.kinds(Tiles.PREFIX, Hearth.FACE_COUNT, Hearth.FIREBOX_LOOKS)

function Hearth.fireboxFace(spriteName)
    return spriteName and FIREBOX_TILES.face[spriteName]
end

-- The facing of any Stone Hearth tile, fitted or not.
function Hearth.fireFace(spriteName)
    return Hearth.fireboxFace(spriteName) or Hearth.face(spriteName)
end

-- With a connection that takes the smoke (smoke true) the hole is never open: the smoke must go up the flue.
function Hearth.fireboxSprite(smoke, hole, face)
    local look = hole or Hearth.OPEN
    if smoke and look == Hearth.OPEN then look = Hearth.LID end
    return Tiles.PREFIX .. ((Hearth.FIREBOX_LOOKS[look] or Hearth.FIREBOX_LOOKS[Hearth.OPEN]) + face)
end

function Hearth.fireboxGlow(lit, banked, smoke, hole, face)
    if not lit then return nil end
    local kind = smoke and "Flue" or (hole == Hearth.OPEN or hole == Hearth.POT) and hole or ""
    local base = Hearth.FIREBOX_GLOWS[(banked and "Banked" or "Lit") .. kind]
    return base and Tiles.PREFIX .. (base + face) or nil
end

-- Every Stone Hearth tile, fitted or not.
Hearth.FIRE_SPRITES = {}
local FIRE_TILES = {}
for _, list in ipairs({ Hearth.SPRITES, Hearth.FIREBOX_SPRITES }) do
    for _, name in ipairs(list) do
        table.insert(Hearth.FIRE_SPRITES, name)
        FIRE_TILES[name] = true
    end
end

-- Any Stone Hearth: a fire this mod banks, stokes and counts the fuel of.
function Hearth.isFire(object)
    local sprite = object and object:getSprite()
    return sprite ~= nil and FIRE_TILES[sprite:getName()] == true and instanceof(object, "IsoFireplace")
end

-- The id of what is fitted on a fire, or nil. A cauldron tile with nothing noted (a Hearth picked up and put down: its
-- modData doesn't go with it) is the cauldron fitted; attached false is nothing, whatever the tile shows until redrawn.
function Hearth.attachedTo(fire)
    local state = fire:getModData()[Hearth.KEY]
    local id = state and state.attached
    if id ~= nil then return id or nil end
    if Hearth.face(fire:getSprite():getName()) then return Hearth.CAULDRON end
end

-- A Stone Hearth with the attachment id fitted (Hearth.CAULDRON: "the Hearth"), or with anything fitted when id is nil.
function Hearth.isFitted(object, id)
    if not Hearth.isFire(object) then return false end
    local fitted = Hearth.attachedTo(object)
    if id == nil then return fitted ~= nil end
    return fitted == id
end

-- A Stone Hearth with nothing fitted ("the Firebox").
function Hearth.isFirebox(object)
    return Hearth.isFire(object) and Hearth.attachedTo(object) == nil
end

-- What is fitted on a fire: its spec and state, or nil.
function Hearth.attachmentOf(fire)
    local id = Hearth.isFire(fire) and Hearth.attachedTo(fire)
    local spec = id and ATTACHMENTS.get(id)
    if not spec then return nil end
    return spec, Hearth.partState(fire:getModData(), id)
end

-- Whether what is fitted may come off (or the fire be picked up): never while the fire burns; else the
-- attachment's say. A fire with nothing fitted may.
function Hearth.canRemove(fire)
    if Hearth.isBurning(fire) then return false, "Burning" end
    local spec, part = Hearth.attachmentOf(fire)
    if not (spec and spec.canRemove) then return true end
    return spec.canRemove(part, fire)
end

-- Why spec can't be fitted on this fire now, as a reason (Burning, Fitted, NoFit, Blocked), or nil. A connection
-- blocks the attachment slot only when it says so (blocks "both"; the Smokehouse's flue doesn't: the Cauldron fits on
-- a Hearth joined to it).
function Hearth.fitRefusal(fire, spec)
    if not (spec and spec.fit) then return "NoFit" end
    if Hearth.attachedTo(fire) then return "Fitted" end
    if Hearth.isBurning(fire) then return "Burning" end
    local joined = Hearth.connectionOf(fire)
    if joined and joined.blocks == "both" then return "Blocked" end
    return nil
end

-- Fits the attachment id on a fire: its state starts empty.
function Hearth.fit(fire, id)
    local state = Hearth.stateOf(fire:getModData())
    state[id] = {}
    state.attached = id
end

-- Takes what is fitted off a fire, its state with it. Returns its id.
function Hearth.unfit(fire)
    local id = Hearth.attachedTo(fire)
    local state = Hearth.stateOf(fire:getModData())
    if id then state[id] = nil end
    state.attached = false
    return id
end

-- What Remove gives back of an attachment's fit: { {full type, count} }, lost items left out.
function Hearth.fitBack(spec)
    local back, lost = {}, spec.fit.lost or {}
    for _, need in ipairs(spec.fit.items) do
        if not lost[need[1]] then table.insert(back, need) end
    end
    return back
end

-- The Hearth's open mouth and the Firebox's door need their front tile free (Doors), every look of each.
local FACE_NAMES = { [0] = "S", [1] = "E" }
local doorFacings = {}
for _, name in ipairs(Hearth.FIRE_SPRITES) do doorFacings[name] = FACE_NAMES[Hearth.fireFace(name)] end
Doors.register(doorFacings)

-- Stove or oven: where a food is cooked, which picks what shows in the hole. A stove food (a pot on the hob: stews,
-- soups) or a fluid sets the forged pot in it; anything else is oven food (clay pots, roasting pans), under the lid.
-- Every food is oven food unless a mod says otherwise: Hearth.cooksOn("stove", "Base.PotOfStew", ...).
Hearth.STOVE, Hearth.OVEN = "stove", "oven"
local COOKS_ON = {}

function Hearth.cooksOn(where, ...)
    assert(where == Hearth.STOVE or where == Hearth.OVEN, "Hearth.cooksOn: where is stove or oven, not " .. tostring(where))
    for _, fullType in ipairs({ ... }) do COOKS_ON[fullType] = where end
end

function Hearth.cookedOn(item)
    return COOKS_ON[item:getFullType()] or Hearth.OVEN
end

-- Vanilla's stews, soups, stir-fries, omelettes, pasta and rice go on the hob.
Hearth.cooksOn(Hearth.STOVE, "Base.PotOfStew", "Base.PotForgedStew", "Base.BucketOfStew", "Base.PotOfSoup",
    "Base.PotOfSoupRecipe", "Base.PotForgedSoupRecipe", "Base.BucketOfSoup", "Base.PanFriedVegetables",
    "Base.PanFriedVegetables2", "Base.PanFriedVegetablesForged", "Base.GriddlePanFriedVegetables", "Base.OmeletteRecipe",
    "Base.OmeletteRecipeForged", "Base.EggOmelette", "Base.PastaPot", "Base.PastaPotForged", "Base.RicePot",
    "Base.RicePotForged", "Base.WaterPotPasta", "Base.WaterPotForgedPasta", "Base.WaterPotRice",
    "Base.WaterPotForgedRice", "Base.PastaPan", "Base.PastaPanCopper", "Base.RicePan", "Base.RicePanCopper",
    "Base.WaterSaucepanPasta", "Base.WaterSaucepanPastaCopper", "Base.WaterSaucepanRice", "Base.WaterSaucepanRiceCopper")

-- What shows in the hole, by what is in the fire's container (a Java list of items): the pot for any stove food or
-- container with fluid in it, the lid for anything else, open when it is empty.
function Hearth.holeLook(items)
    local look = Hearth.OPEN
    for i = 0, items and items:size() - 1 or -1 do
        local item = items:get(i)
        local fluid = item:getFluidContainer()
        if (fluid and not fluid:isEmpty()) or Hearth.cookedOn(item) == Hearth.STOVE then return Hearth.POT end
        look = Hearth.LID
    end
    return look
end

-- The look of an attachment that gives none: the empty cauldron's.
local NO_LOOK = "Empty"

-- The sprite and glow a Stone Hearth shows now: its attachment's look, or its hole (Hearth.holeLook; lidded under a
-- connection that takes the smoke), and its fire. nil for anything else.
function Hearth.showing(fire, state, burning, banked)
    local face = Hearth.fireFace(fire:getSprite():getName())
    if not face then return nil end
    local spec, part = Hearth.attachmentOf(fire)
    if spec then
        local look = spec.look and spec.look(part, fire) or NO_LOOK
        local overlay, colour = (spec.overlay or Hearth.liquidOverlay)(part, face, burning, banked)
        return (spec.sprite or Hearth.sprite)(look, face, burning, banked), overlay, colour
    end
    local container = fire:getContainer()
    local hole = Hearth.holeLook(container and container:getItems())
    local smoke = Hearth.takesSmoke(state)
    return Hearth.fireboxSprite(smoke, hole, face),
        Hearth.fireboxGlow(burning, banked, smoke, smoke and Hearth.LID or hole, face)
end

-- The fire's state, brought up to now where the World runs (a server or single player).
function Hearth.fireStateOf(fire)
    if Hearth.World then return Hearth.World.update(fire, getGameTime():getWorldAgeHours()) end
    return Hearth.stateOf(fire:getModData())
end

-- The cauldron's state, brought up to now the same way.
function Hearth.cauldronOf(fire)
    Hearth.fireStateOf(fire)
    return Hearth.cauldronState(fire:getModData())
end

-- Fires

-- A Hearth or Firebox whose fire is banked (vanilla's fire is out meanwhile).
function Hearth.isBanked(object)
    return Hearth.isFire(object) and Hearth.stateOf(object:getModData()).banked == true
end

-- A fireplace whose fire burns, lit or banked.
function Hearth.isBurning(object)
    return object:isLit() or Hearth.isBanked(object)
end

-- Hours of fuel the fire has left; nil if it can't be read (it is then taken to burn on).
function Hearth.fuelHours(fire)
    if Hearth.isBanked(fire) then return fire:getFuelAmount() / Hearth.MINUTES_PER_HOUR / Hearth.BANKED_BURN end
    if instanceof(fire, "IsoFireplace") then return fire:getFuelAmount() / Hearth.MINUTES_PER_HOUR end
    local minutes = fire:getModData().fuelAmt
    return minutes and minutes / Hearth.MINUTES_PER_HOUR or nil
end

-- Functions moved to their own files, still reached here so no caller changes (DEVGUIDE refactoring rule 5). Each
-- file requires Hearth, so it is required the first time one of its functions is called.
local function passOn(file, names)
    local module
    for _, name in ipairs(names) do
        Hearth[name] = function(...)
            module = module or require("TraditionalPreservationCore/" .. file)
            return module[name](...)
        end
    end
end

passOn("HearthConnect", { "connect", "connection", "connections", "connectedTo", "joinOf", "takesSmoke", "connectionOf",
    "join", "unjoin", "connectRefusalOf", "connectRefusal", "kitMissing", "kitBack", "flueSideTo", "flueSquare" })
passOn("HearthPlace", { "fireC", "isFirePlace", "firePlace", "near", "fittedNear", "placeOf", "catchUp", "catchUpRun",
    "updateRun", "notePlace", "noteFire" })

-- Building: the entity script's OnCreate, so a global.
TraditionalPreservationCore = TraditionalPreservationCore or {}

local function toFireplace(params, faceOf)
    local thumpable = params.thumpable
    local sprite = thumpable and thumpable:getSprite()
    local name = sprite and sprite:getName()
    if not faceOf(name) then return nil end
    local square = thumpable:getSquare()
    local fire = IsoFireplace.new(getCell(), square, getSprite(name))
    square:AddTileObject(fire)
    if thumpable:getSquare() ~= nil then
        thumpable:removeFromWorld()
        thumpable:removeFromSquare()
        thumpable:setSquare(nil)
    end
    return { replaceObject = true, object = fire }
end

function TraditionalPreservationCore.OnCreateFirebox(params)
    return toFireplace(params, Hearth.fireboxFace)
end

return Hearth
