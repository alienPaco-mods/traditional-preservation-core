-- Traditional Preservation core: a fire the mods bank and stoke, with something fitted on it and something joined to
-- it. Fires come in kinds (Fire.kind): a kind is a vanilla fireplace by its tiles, so vanilla gives it fuel, lighting,
-- burn time, room heat and a firebox to cook in, and the kind says how it looks. The Stone Hearth (StoneHearth.lua) is
-- the first. A fire's state is a plain table in the fireplace's modData under KEY.
--
-- Fire is the name callers use for the fire; its parts in other files:
--   FireConnect.lua   connections, the second slot (Fire.connect, .join, ...), passed on here
--   Fireside.lua      "by a fire" as a place, and the work done there (Fire.placeOf, .catchUp, .notePlace, ...),
--                     passed on here; its numbers (PLACE, FIRE_C, EMBERS, the lifts) are here, registered with
--                     Weather at load
--   StoneHearth.lua   the Stone Hearth, a kind: its tiles, hole, door and build
--   Cauldron.lua      the cauldron, an attachment (its rules: CauldronFluid.lua)
--
-- What sits on the fire is an attachment (Fire.attach, ATTACHMENTS below): the cauldron is the first, written in
-- Cauldron.lua, CauldronUI.lua and FireWorld against that registry alone, so a mod can add its own (Salt's salt pan).
-- Two slots: one attachment fitted on the fire (the Cauldron, later Salt's pan) and one connection built onto it
-- (Fire.connect: the Smokehouse's flue), each free of the other unless the connection blocks both. The fire's state
-- names the attachment (attached: false once one has come off), and the attachment's own state is kept under its id
-- there. Fit and Remove are Core's (Fire.canFit, Fire.fit, Fire.unfit; TPFireFit), by the attachment's fit. A fire
-- with nothing fitted is "bare" (Fire.isBare).
--
-- A lit fire can be banked: raked down under its ash. It burns BANKED_BURN of the wood a lit fire does, and beside it
-- is a place of its own (EMBERS, at EMBERS_C). Vanilla's fireplace has one speed and heats and lights 8 tiles whatever
-- its fuel (ENGINE_NOTES), so a banked fire's vanilla fire is out: the mod counts its fuel from the clock
-- (Fire.reckonFuel) and sets vanilla's to the count, gives it its own small heat and faint light, and keeps the
-- firebox hot (FireWorld). Fire.isBurning is a fire lit or banked; Fire.isFire is any fire of a registered kind.
local Weather = require "TraditionalPreservationCore/Weather"

local Fire = {}

-- Save key: never rename it once the mod is out (DEVGUIDE, "Rules that keep saves and the game happy").
-- Inside: fireUntil; banked, fuel, fuelAt, fuelSet; attached (the id of what is fitted); connected (the id of what is
-- joined, its kind and side under that id);
-- the fire's record (Fire.logFire):
-- fireId, fireAt, fireMode, fireEnds, stokedHours, bankedHours, session, sessionBase, stokedLast; and each attachment's
-- state under its id (the cauldron's: Cauldron.lua).
Fire.KEY = "tpFire"

-- By a fire. A fireplace, an antique stove or a campfire, never an electric or gas stove.
Fire.PLACE = "Fireside"
Fire.FIRE_C = 28
Fire.FIRE_RADIUS = 2
Fire.DEFAULT_PLACE_WITHOUT_FIRE = Weather.DEFAULT_PLACE   -- the place under a fire when none was noted: a room

-- Banked
Fire.BANKED_BURN = 1 / 3         -- of the wood a lit fire burns: a banked fire lasts three times as long
Fire.EMBERS = "Embers"           -- the place by a banked fire
Fire.EMBERS_C = 24
Fire.BANKED_HEAT_RADIUS = 2      -- tiles of room heat around banked embers (a lit fire: 8)
Fire.BANKED_HEAT_C = 25          -- that heat (a lit fire: 35 C)
Fire.BANKED_LIGHT_RADIUS = 1
Fire.BANKED_LIGHT = { 0.6, 0.25, 0.1 }
Fire.BANKED_FIREBOX = 1.8        -- the firebox's heat (vanilla's container temperature): it cooks, a third as fast
Fire.MINUTES_PER_HOUR = 60       -- vanilla's fuel is minutes

-- What a fire adds to the air under an open roof (the season's) and in the open (the day's), lit and banked.
Fire.FIRE_LIFT = { Covered = 15, Open = 10 }
Fire.EMBERS_LIFT = { Covered = 10, Open = 5 }

-- Save values: a station's noted place. Never rename them.
for _, fire in ipairs({ { Fire.PLACE, Fire.FIRE_C, Fire.FIRE_LIFT }, { Fire.EMBERS, Fire.EMBERS_C, Fire.EMBERS_LIFT } }) do
    local place, celsius, lifts = fire[1], fire[2], fire[3]
    Weather.FIRE_PLACES[place] = { celsius = celsius }
    for placeWithoutFire, lift in pairs(lifts) do
        Weather.FIRE_PLACES[place .. placeWithoutFire] = { celsius = celsius, placeWithoutFire = placeWithoutFire, lift = lift }
    end
end

-- The fire's record, for whatever hangs over it (Fish & Meat's Smokehouse). Hours of stoked (lit) and banked fire,
-- and the stoked session now running: unbroken stoking, a gap of up to SESSION_GRACE hours (more wood, a dip) kept.
Fire.SESSION_GRACE = 1
Fire.STOKED = "stoked"
Fire.BANKED = "banked"

-- Adds the time since the last look to the record, as the fire was then (mode, burning until ends), and notes the
-- fire as it is now. Hours count only up to when the fire was due to go out: vanilla burns a lit fire's time away
-- in one go when its chunk loads again (ENGINE_NOTES), so its fuel afterwards can't say when it went out. A session
-- ends once the fire hasn't been stoked for more than SESSION_GRACE hours; stoking again starts a new one (session =
-- when it began, sessionBase = the stoked hours before it). fireId tells one fire's record from a rebuilt one's.
function Fire.logFire(fireModData, now, mode, ends)
    fireModData.fireId = fireModData.fireId or now
    local at = fireModData.fireAt
    if at and now > at and fireModData.fireMode then
        local stop = math.max(math.min(now, fireModData.fireEnds or now), at)
        local hours = stop - at
        if fireModData.fireMode == Fire.STOKED then
            fireModData.stokedHours = (fireModData.stokedHours or 0) + hours
            fireModData.stokedLast = stop
        else
            fireModData.bankedHours = (fireModData.bankedHours or 0) + hours
        end
    end
    if fireModData.session and now - (fireModData.stokedLast or now) > Fire.SESSION_GRACE then
        fireModData.session, fireModData.sessionBase = nil, nil
    end
    if mode == Fire.STOKED and not fireModData.session then
        fireModData.session, fireModData.sessionBase, fireModData.stokedLast = now, fireModData.stokedHours or 0, now
    end
    fireModData.fireAt, fireModData.fireMode, fireModData.fireEnds = now, mode, ends
end

-- The stoked hours of the session now running, or 0.
function Fire.sessionHours(fireModData)
    if not fireModData.session then return 0 end
    return (fireModData.stokedHours or 0) - (fireModData.sessionBase or 0)
end

function Fire.fireModData(modData)
    modData[Fire.KEY] = modData[Fire.KEY] or {}
    return modData[Fire.KEY]
end

-- An attachment's own state, under its id in the fire's.
function Fire.partModData(modData, id)
    local fireModData = Fire.fireModData(modData)
    fireModData[id] = fireModData[id] or {}
    return fireModData[id]
end

-- A registry by id (attachments here, FireConnect's connections). add(added) registers one by added.id, or
-- adds the fields given to one already registered, so its rules can be given in shared Lua and its menu in client
-- Lua; a field already given may not be given again as something else. get(id) is one, list() every one in the order
-- registered. registrar names the registering function in its errors.
function Fire.registry(registrar)
    local byId, order = {}, {}
    local registry = {}
    function registry.add(added)
        assert(type(added.id) == "string", registrar .. ": an id is needed")
        local known = byId[added.id]
        if not known then
            known = {}
            byId[added.id] = known
            table.insert(order, added.id)
        end
        for field, given in pairs(added) do
            assert(known[field] == nil or known[field] == given, registrar .. " " .. added.id .. ": " .. field .. " is already given")
            known[field] = given
        end
        return known
    end
    function registry.get(id)
        return byId[id]
    end
    function registry.list()
        local list = {}
        for _, id in ipairs(order) do table.insert(list, byId[id]) end
        return list
    end
    return registry
end

-- Attachments: what is fitted on a fire, one at a time, registered with Fire.attach (Fire.registry). Each
-- function gets the attachment's own state (part) and the fireplace; fireModData is the fire's.
--   name                                  its text key
--   fit                                   what Fit takes: { items = { {full type, count} }, tool (an ItemTag's
--                                         name, kept), ticks, removeTicks, xp = { perk, amount }, lost = { full type
--                                         = true } }; Remove gives the items back, all but lost ones
--   fitHelp, fitIcon                      client: Fit's tooltip line (a text key) and Fit / Remove's icon path
--   canRemove(part, fire)                 true, or false and a reason; never asked while the fire burns
--   look(part, fire)                      the look its tile shows (the cauldron's: Empty, Full, Hot)
--   sprite(look, face, burning, banked)   its tile by look, facing and fire, the fire's glow drawn in it (the
--                                         cauldron's StoneHearth.cauldronSprite)
--   overlay(part, face, burning, banked)  optional: its overlay sprite and, to tint it, { r, g, b } (0-1), or nil
--                                         (the cauldron's StoneHearth.liquidOverlay: what it holds, coloured)
--   heats(part, fire, now, fireModData, airC, place)  brings what it holds up to now, by the fire and the air of the
--                                         place the fire stands in (Weather.placeOf)
--   onFire(part, fire, now, fireModData)    after each refresh, the look and glow set
--   display                               how the fitted fire shows, { icon, title (a text key: its submenu and
--                                         Info window), info (the Info row's text key), fire = { bank, stoke }
--                                         (Bank / Stoke's icons) }; the fire's kind's display if left out
--   status(part)                          client: the menu's first row, text and icon
--   menu(menu, playerObj, fire, part)     client: its rows, after Bank / Stoke
--   rows(window, y, info) -> y            client: its rows in the Info window; info.part is the part
--   notes(fireView, notes)                client: its Info notes (FireUI.notes has fireView)
local ATTACHMENTS = Fire.registry("Fire.attach")

function Fire.attach(attachment)
    local known = ATTACHMENTS.add(attachment)
    assert(not attachment.fit or type(attachment.fit.items) == "table", "Fire.attach " .. known.id .. ": fit needs items")
    return known
end

Fire.attachment = ATTACHMENTS.get

-- Every attachment, in the order registered.
Fire.attachments = ATTACHMENTS.list

-- Banks the fire (banked true) or stokes it up again, with fuel minutes in vanilla's fireplace now.
function Fire.setBanked(fireModData, banked, fuel, now)
    fireModData.banked = banked or nil
    if banked then
        fireModData.fuel, fireModData.fuelAt, fireModData.fuelSet = fuel, now, fuel
    else
        fireModData.fuel, fireModData.fuelAt, fireModData.fuelSet = nil, nil, nil
    end
end

-- The fuel a banked fire has left now, from vanilla's fuel (minutes) and whether vanilla's fire is lit (it is out
-- while banked). Returns the fuel to give vanilla's fireplace, nil to leave it alone. The count runs on the clock,
-- away time included; wood added since the last reckoning counts in full. Burnt down, the fire is out and no longer
-- banked. Lit by anything but stoking, it is a lit fire again.
function Fire.reckonFuel(fireModData, fuel, lit, now)
    if not fireModData.banked then return nil end
    if lit then
        Fire.setBanked(fireModData, false)
        return nil
    end
    if not fireModData.fuel then
        Fire.setBanked(fireModData, true, fuel, now)
        return nil
    end
    local left = fireModData.fuel - (now - fireModData.fuelAt) * Fire.MINUTES_PER_HOUR * Fire.BANKED_BURN + math.max(fuel - fireModData.fuelSet, 0)
    if left < 1 then
        Fire.setBanked(fireModData, false)
        return 0
    end
    fireModData.fuel, fireModData.fuelAt, fireModData.fuelSet = left, now, math.ceil(left)
    return fireModData.fuelSet
end

-- A banked firebox cooks as slowly as it burns: vanilla adds cooking time at full speed, so of the minutes cooked
-- since before, only BANKED_BURN count. Returns the cooking time the food should have.
function Fire.bankedCooking(before, now)
    if now <= before then return now end
    return before + (now - before) * Fire.BANKED_BURN
end

-- Kinds: the fires Fire banks, stokes and keeps attachments and connections on, registered with Fire.kind
-- (Fire.registry). The Stone Hearth (StoneHearth.lua) is the first; a mod can add its own fireplace the same way.
--   is(isoObject)                          whether an object is one of this kind (an IsoFireplace)
--   face(spriteName)                       its facing (0 S, 1 E) by tile, nil for a tile not its own
--   sprites                                every tile of the kind, for FireWorld to track
--   showing(fire, fireModData, burning, banked)  the sprite it shows now, and the overlay and its colour (nil for none)
--   fittedByTile(spriteName)               the id of what a tile shows fitted when nothing is noted (a fire picked
--                                          up and put down: its modData doesn't go with it), or nil; optional
--   display                                how it shows with nothing fitted: { icon, title, info, fire = { bank,
--                                          stoke } } (Fire.attach's display), and help = { out, lit, banked }: its
--                                          Info's first note by its fire (text keys)
--   refusals                               why Connect is refused, in its words: { joined (something already
--                                          is), door (the target is on its door's side) } (text keys)
local KINDS = Fire.registry("Fire.kind")

-- Checked before it is kept, so a refused kind is never tracked or asked.
function Fire.kind(fireKind)
    local known = KINDS.get(fireKind.id) or {}
    local function given(field) if fireKind[field] ~= nil then return fireKind[field] end return known[field] end
    local refusedAs = "Fire.kind " .. tostring(fireKind.id) .. ": "
    assert(type(given("is")) == "function", refusedAs .. "is needs a function")
    assert(type(given("face")) == "function", refusedAs .. "face needs a function")
    assert(type(given("showing")) == "function", refusedAs .. "showing needs a function")
    assert(type(given("sprites")) == "table", refusedAs .. "sprites needs a list")
    assert(type(given("display")) == "table", refusedAs .. "display needs a table")
    local refusals = given("refusals")
    assert(type(refusals) == "table" and refusals.joined and refusals.door, refusedAs .. "refusals needs joined and door")
    return KINDS.add(fireKind)
end

-- The kind of fire an object is, or nil.
function Fire.kindOf(isoObject)
    if not isoObject then return nil end
    for _, fireKind in ipairs(KINDS.list()) do
        if fireKind.is(isoObject) then return fireKind end
    end
    return nil
end

-- Any fire of a registered kind: one this mod banks, stokes and counts the fuel of.
function Fire.isFire(isoObject)
    return Fire.kindOf(isoObject) ~= nil
end

-- The facing (0 S, 1 E) of a fire, by its kind's tiles; nil for anything else.
function Fire.faceOf(fire)
    local fireKind = Fire.kindOf(fire)
    return fireKind and fireKind.face(fire:getSprite():getName())
end

-- Every registered kind's tiles.
function Fire.sprites()
    local sprites = {}
    for _, fireKind in ipairs(KINDS.list()) do
        for _, name in ipairs(fireKind.sprites) do table.insert(sprites, name) end
    end
    return sprites
end

-- The id of what is fitted on a fire, or nil. With nothing noted, what its tile shows fitted (its kind's fittedByTile);
-- attached false is nothing, whatever the tile shows until redrawn.
function Fire.attachedTo(fire)
    local fireModData = fire:getModData()[Fire.KEY]
    local id = fireModData and fireModData.attached
    if id ~= nil then return id or nil end
    local fireKind = Fire.kindOf(fire)
    if fireKind and fireKind.fittedByTile then return fireKind.fittedByTile(fire:getSprite():getName()) end
end

-- A fire with the attachment id fitted (Cauldron.ID on a Stone Hearth: the Stone Hearth (Cauldron)), or with anything fitted when id is nil.
function Fire.isFitted(isoObject, id)
    if not Fire.isFire(isoObject) then return false end
    local fitted = Fire.attachedTo(isoObject)
    if id == nil then return fitted ~= nil end
    return fitted == id
end

-- A fire with nothing fitted ("bare").
function Fire.isBare(isoObject)
    return Fire.isFire(isoObject) and Fire.attachedTo(isoObject) == nil
end

-- What is fitted on a fire: its attachment and state, or nil.
function Fire.attachmentOf(fire)
    local id = Fire.isFire(fire) and Fire.attachedTo(fire)
    local attachment = id and ATTACHMENTS.get(id)
    if not attachment then return nil end
    return attachment, Fire.partModData(fire:getModData(), id)
end

-- Whether what is fitted may come off (or the fire be picked up): never while the fire burns; else the
-- attachment's say. A fire with nothing fitted may.
function Fire.canRemove(fire)
    if Fire.isBurning(fire) then return false, "Burning" end
    local attachment, part = Fire.attachmentOf(fire)
    if not (attachment and attachment.canRemove) then return true end
    return attachment.canRemove(part, fire)
end

-- Why attachment can't be fitted on this fire now, as a reason (Burning, Fitted, NoFit, Blocked), or nil. A connection
-- blocks the attachment slot only when it says so (blocks "both"; the Smokehouse's flue doesn't: the Cauldron fits on
-- a Stone Hearth joined to it).
function Fire.fitRefusal(fire, attachment)
    if not (attachment and attachment.fit) then return "NoFit" end
    if Fire.attachedTo(fire) then return "Fitted" end
    if Fire.isBurning(fire) then return "Burning" end
    local joined = Fire.connectionOf(fire)
    if joined and joined.blocks == "both" then return "Blocked" end
    return nil
end

-- Fits the attachment id on a fire: its state starts empty.
function Fire.fit(fire, id)
    local fireModData = Fire.fireModData(fire:getModData())
    fireModData[id] = {}
    fireModData.attached = id
end

-- Takes what is fitted off a fire, its state with it. Returns its id.
function Fire.unfit(fire)
    local id = Fire.attachedTo(fire)
    local fireModData = Fire.fireModData(fire:getModData())
    if id then fireModData[id] = nil end
    fireModData.attached = false
    return id
end

-- What Remove gives back of an attachment's fit: { {full type, count} }, lost items left out.
function Fire.fitBack(attachment)
    local back, lost = {}, attachment.fit.lost or {}
    for _, need in ipairs(attachment.fit.items) do
        if not lost[need[1]] then table.insert(back, need) end
    end
    return back
end

-- The sprite, overlay and overlay colour a fire shows now, by its kind; nil for anything else.
function Fire.showing(fire, fireModData, burning, banked)
    local fireKind = Fire.kindOf(fire)
    if not fireKind then return nil end
    return fireKind.showing(fire, fireModData, burning, banked)
end

-- The fire's state, brought up to now where the World runs (a server or single player).
function Fire.fireModDataNow(fire)
    if Fire.World then return Fire.World.update(fire, getGameTime():getWorldAgeHours()) end
    return Fire.fireModData(fire:getModData())
end

-- Redraws a fire now (FireWorld.refresh) where the World runs, e.g. after a pour or a fit.
function Fire.redraw(fire)
    if Fire.World then Fire.World.refresh(fire) end
end

-- Fires

-- A fire that is banked (vanilla's fire is out meanwhile).
function Fire.isBanked(isoObject)
    return Fire.isFire(isoObject) and Fire.fireModData(isoObject:getModData()).banked == true
end

-- A fireplace whose fire burns, lit or banked.
function Fire.isBurning(fire)
    return fire:isLit() or Fire.isBanked(fire)
end

-- Hours of fuel the fire has left; nil if it can't be read (it is then taken to burn on).
function Fire.fuelHours(fire)
    if Fire.isBanked(fire) then return fire:getFuelAmount() / Fire.MINUTES_PER_HOUR / Fire.BANKED_BURN end
    if instanceof(fire, "IsoFireplace") then return fire:getFuelAmount() / Fire.MINUTES_PER_HOUR end
    local minutes = fire:getModData().fuelAmt
    return minutes and minutes / Fire.MINUTES_PER_HOUR or nil
end

-- Functions moved to their own files, still reached here so no caller changes (DEVGUIDE refactoring rule 5). Each
-- file requires Fire, so it is required the first time one of its functions is called.
local function passOn(file, names)
    local module
    for _, name in ipairs(names) do
        Fire[name] = function(...)
            module = module or require("TraditionalPreservationCore/" .. file)
            return module[name](...)
        end
    end
end

passOn("FireConnect", { "connect", "connection", "connections", "connectedTo", "joinOf", "takesSmoke", "connectionOf",
    "join", "unjoin", "connectRefusalOf", "connectRefusal", "kitMissing", "kitBack", "flueSideTo", "flueSquare" })
passOn("Fireside", { "fireC", "isFirePlace", "firePlace", "near", "fittedNear", "placeOf", "catchUp", "catchUpRun",
    "updateRun", "notePlace", "noteFire" })

return Fire
