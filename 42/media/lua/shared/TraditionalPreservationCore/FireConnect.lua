-- Traditional Preservation core: connections, what is built onto a fire in its second slot (the Smokehouse's
-- flue is the first), one at a time, on its back or either flank, never the door's side. The fire's state names it
-- (connected), and its own state is kept under its id there: kitName (the kit it was built with) and side (Back, Left or
-- Right). Connect and Disconnect are Core's (connectRefusal, join, unjoin; TPFireConnect), by the connection's
-- kits, never while the fire burns. A connection draws itself on its own object (the Smokehouse's entry overlay draws
-- the flue, Smokehouse.entrySprite); the stone only puts its lid on when the connection takes the smoke (connection.smoke).
-- Fire passes every function here on (Fire.connect, Fire.join, ...), so callers name Fire only.
local Fire = require "TraditionalPreservationCore/Fire"
local Action = require "TraditionalPreservationCore/Action"

local FireConnect = {}

-- The sides a connection may go to, by facing (0 S, 1 E), as world steps (+x east, +y south): the same table as FLUE_SIDES
-- in tools/build_tileset.py. The door's side is never one.
FireConnect.FLUE_SIDES = {
    [0] = { Back = { 0, -1 }, Left = { -1, 0 }, Right = { 1, 0 } },
    [1] = { Back = { -1, 0 }, Left = { 0, -1 }, Right = { 0, 1 } },
}
-- FLUE_SIDES' sides in the order a search goes through them.
FireConnect.SIDES = { "Back", "Left", "Right" }

-- connect(connection) registers one by connection.id, or adds the fields given to one already registered (Fire.registry), so
-- its rules can be given in shared Lua and its notes in client Lua. kitNames and kits come together, a kit for every
-- kit name. A connection (fields after id are optional unless said):
--   id                                    its save key under tpFire: never rename it once out
--   kitNames, kits                        the ways to build it, in menu order (both needed), each kit { tool (an
--                                         ItemTag's name, kept), items = { {full type, count} }, back (the full type
--                                         Disconnect gives back, as many as went in; the rest is lost), ticks,
--                                         removeTicks, xp = { perk, amount }, anim (a CharacterActionAnims name),
--                                         text, help, name (text keys: its menu row, hover and Info word),
--                                         toolText (the tool's text key) }
--   blocks                                "connection" (the default: its own slot) or "both" (no Fit while joined,
--                                         no Connect while something is fitted)
--   finds(fire) -> target                 the object beside the fire it could join, or nil
--   joined(fire, part) -> target          what a joined fire goes into, or nil (it is gone)
--   refusal(fire, target)                 why not this target, as a text key, or nil
--   onChange(fire, target)                after it is built or taken up, the fire redrawn (target may be nil)
--   connectText, disconnectText, disconnectHelp, icon   client: its menu rows, Disconnect's hover (%1 what comes
--                                         back, %2 the tool), their icon path
--   notes(fireView, notes, part)          client: its Info notes
--   smoke                                 true when it takes the fire's smoke: the hole is lidded, the glow goes up
--                                         it (the Smokehouse's flue)
local CONNECTIONS = Fire.registry("Fire.connect")

function FireConnect.connect(connection)
    local known = CONNECTIONS.add(connection)
    if connection.kitNames or connection.kits then
        assert(known.kitNames and known.kits, "Fire.connect " .. known.id .. ": kitNames and kits come together")
        for _, kitName in ipairs(known.kitNames) do
            assert(known.kits[kitName], "Fire.connect " .. known.id .. ": no kit for " .. tostring(kitName))
        end
    end
    return known
end

FireConnect.connection = CONNECTIONS.get

-- Every connection, in the order registered.
FireConnect.connections = CONNECTIONS.list

-- The id of what is joined to a fire's state, or nil.
function FireConnect.connectedTo(fireModData)
    return fireModData and fireModData.connected or nil
end

-- The kit name and side of what is joined (Pipe, Back), or nil.
function FireConnect.joinOf(fireModData)
    local id = FireConnect.connectedTo(fireModData)
    local part = id and fireModData[id]
    if not part then return nil end
    return part.kitName, part.side
end

-- Whether what is joined takes the fire's smoke (connection.smoke).
function FireConnect.takesSmoke(fireModData)
    local connection = CONNECTIONS.get(FireConnect.connectedTo(fireModData))
    return connection and connection.smoke and FireConnect.joinOf(fireModData) ~= nil or false
end

-- What is joined to a fire: its connection and state, or nil.
function FireConnect.connectionOf(fire)
    local id = FireConnect.connectedTo(fire:getModData()[Fire.KEY])
    local connection = CONNECTIONS.get(id)
    if not connection then return nil end
    return connection, Fire.partModData(fire:getModData(), id)
end

-- Joins connection id to a fire's state by a kit name on a side (Back, Left or Right). Anything else (an unknown
-- id or kit name, the door's side) leaves nothing joined.
function FireConnect.join(fireModData, id, kitName, side)
    FireConnect.unjoin(fireModData)
    local connection = CONNECTIONS.get(id)
    if connection and connection.kits[kitName] and FireConnect.FLUE_SIDES[0][side] then
        fireModData.connected = id
        fireModData[id] = { kitName = kitName, side = side }
    end
end

-- Takes what is joined off a fire's state. Returns its id and state.
function FireConnect.unjoin(fireModData)
    local id = FireConnect.connectedTo(fireModData)
    local part = id and fireModData[id]
    if id then fireModData[id] = nil end
    fireModData.connected = nil
    return id, part
end

-- Why Connect can't be done, as translation keys, besides the kind's own (FireConnect.connectRefusalOf).
FireConnect.REFUSALS = {
    fireBurning = "IGUI_TraditionalPreservationCore_FireBurning",
    connectFitted = "IGUI_TraditionalPreservationCore_ConnectFitted",
}

-- Why Connect can't be done, the first that applies, as a text key, or nil. c = { joined (something is), own (the
-- connection's refusal), side (the target's side of the fire: nil on the door's), burning, fitted (something is fitted
-- and the connection blocks both slots), refusals (the fire's kind's words for joined and door) }.
function FireConnect.connectRefusalOf(c)
    if c.joined then return c.refusals.joined end
    if c.own then return c.own end
    if not c.side then return c.refusals.door end
    if c.burning then return FireConnect.REFUSALS.fireBurning end
    if c.fitted then return FireConnect.REFUSALS.connectFitted end
    return nil
end

function FireConnect.connectRefusal(fire, connection, target)
    return FireConnect.connectRefusalOf({
        joined = FireConnect.connectedTo(fire:getModData()[Fire.KEY]) ~= nil,
        own = connection.refusal and connection.refusal(fire, target),
        side = Fire.flueSideTo(fire, target:getSquare()),
        burning = Fire.isBurning(fire),
        fitted = connection.blocks == "both" and Fire.attachedTo(fire) ~= nil,
        refusals = Fire.kindOf(fire).refusals,
    })
end

-- What a kit lacks from counts (full type -> how many) and whether its tool is there: { {type, missing} }, noTool.
function FireConnect.kitMissing(kit, counts, hasTool)
    local missing = {}
    for _, need in ipairs(kit.items) do
        local have = 0
        for _, fullType in ipairs(Action.needTypes(need)) do have = have + (counts[fullType] or 0) end
        local short = need[2] - have
        if short > 0 then table.insert(missing, { need[1], short }) end
    end
    return missing, not hasTool
end

-- What Disconnect gives back of a kit: { {full type, count} }.
function FireConnect.kitBack(kit)
    local back = {}
    for _, need in ipairs(kit.items) do
        if need[1] == kit.back then table.insert(back, need) end
    end
    return back
end

-- A fire's facing and square, or nil.
local function standing(fire)
    local face = Fire.faceOf(fire)
    return face, face and fire:getSquare()
end

-- The side of a fire that square is on (Back, Left or Right): nil for its door's side, a square not beside it, or
-- anything but a fire.
function FireConnect.flueSideTo(fire, square)
    local face, here = standing(fire)
    if not here or not square or square:getZ() ~= here:getZ() then return nil end
    local dx, dy = square:getX() - here:getX(), square:getY() - here:getY()
    for side, step in pairs(FireConnect.FLUE_SIDES[face]) do
        if step[1] == dx and step[2] == dy then return side end
    end
end

-- The square on that side of a fire, or nil.
function FireConnect.flueSquare(fire, side)
    local face, here = standing(fire)
    local step = here and FireConnect.FLUE_SIDES[face][side]
    if not step then return nil end
    return getCell():getGridSquare(here:getX() + step[1], here:getY() + step[2], here:getZ())
end

return FireConnect
