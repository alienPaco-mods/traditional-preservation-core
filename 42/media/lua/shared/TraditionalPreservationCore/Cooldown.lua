-- Traditional Preservation core: cooldowns kept on a player. Vanilla keeps its own (the one food and drink share
-- for easing food sickness) in a field Lua can't reach, so a mod that needs one keeps it here: a name (a key) and
-- the world hour it runs out, in the player's modData. World hours, so it survives saving and runs on game time
-- (sleeping and fast-forwarding move it on). Any mod may use a key of its own ("tpy:...") or share one: kefir's
-- cure shares "foodSickness" with any later TP cure, as vanilla's foods share theirs.
local Cooldown = {}

-- Save key: never rename it once the mod is out. Inside: { key = the world hour it runs out }.
Cooldown.KEY = "tpCooldowns"

local function now()
    return getGameTime():getWorldAgeHours()
end

local function timers(player, create)
    local data = player:getModData()
    if create then data[Cooldown.KEY] = data[Cooldown.KEY] or {} end
    return data[Cooldown.KEY]
end

-- Hours left on a cooldown table's key at hour `at` (0 once run out or never started).
function Cooldown.leftIn(tbl, key, at)
    local endsAt = tbl and tbl[key]
    return endsAt and math.max(endsAt - at, 0) or 0
end

-- Starts (or restarts) the key in a cooldown table: it runs out `hours` after `at`.
function Cooldown.startIn(tbl, key, hours, at)
    tbl[key] = at + hours
end

-- Whether the player's cooldown `key` has run out (true if it was never started).
function Cooldown.ready(player, key)
    return Cooldown.leftIn(timers(player), key, now()) <= 0
end

-- Starts the player's cooldown `key`, running out in `hours` of game time.
function Cooldown.start(player, key, hours)
    Cooldown.startIn(timers(player, true), key, hours, now())
end

-- Game hours left on the player's cooldown `key` (0 once run out).
function Cooldown.left(player, key)
    return Cooldown.leftIn(timers(player), key, now())
end

return Cooldown
