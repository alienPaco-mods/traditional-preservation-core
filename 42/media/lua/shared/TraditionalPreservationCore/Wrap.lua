-- Traditional Preservation core: every wrap of a vanilla function goes through here, once for all TP mods.
--   Wrap.method(owner, name, handler)  owner is the global's name ("ISToolTipInv"); handler(vanilla, ...) gets the
--                                      call's own arguments (self first for a method) and calls vanilla(...) itself
-- Two things keep TP out of other mods' way:
-- - Late: a wrap goes in once every mod's Lua has loaded (OnGameStart; a dedicated server has no OnGameStart, so
--   OnGameBoot there, which it fires after loading shared, client and server Lua). A mod that replaces the function
--   outright as its file loads is then wrapped too, not wiped out. One that replaces it later still wins.
-- - Guarded, in normal play: if the handler fails, vanilla still runs (or its result is returned, if it already
--   ran), and the error is printed once per wrap. An error inside vanilla (or inside another mod's version of the
--   function) isn't TP's: it is raised again with its own message, which names where it happened.
-- - Not guarded in debug mode: the handler runs bare, so any error, TP's or not, is raised where it happens with its
--   full trace (the in-game test steps see it).
-- One function is wrapped once in the whole series (`tp test` fails on a second Wrap.method for it: add handlers to
-- the module that wraps it instead). Registering it again replaces the handler, as a file reloaded in debug mode
-- does. A function missing in this game (or on this side) is skipped. Tests set TPCoreTesting so a wrap goes in at
-- once.
local Wrap = {}

local entries = {}
local started = false
local reported = {}

local function pack(...)
    return { n = select("#", ...), ... }
end

local function report(where, err)
    if reported[where] then return end
    reported[where] = true
    print("[TP Core] the wrap of " .. where .. " failed, vanilla went on: " .. tostring(err))
end

local function guarded(where, vanilla, entry)
    return function(...)
        local handler = entry.handler
        if isDebugEnabled() then return handler(vanilla, ...) end
        local ran, inVanilla, results = false, false, nil
        local function callVanilla(...)
            ran, inVanilla = true, true
            results = pack(vanilla(...))
            inVanilla = false
            return unpack(results, 1, results.n)
        end
        local out = pack(pcall(handler, callVanilla, ...))
        if out[1] then return unpack(out, 2, out.n) end
        if inVanilla then error(out[2], 0) end
        if not ran then results = pack(vanilla(...)) end
        report(where, out[2])
        return unpack(results, 1, results.n)
    end
end

local function apply(entry)
    if entry.applied then return end
    local owner = _G[entry.owner]
    if type(owner) ~= "table" or type(owner[entry.name]) ~= "function" then return end
    entry.applied = true
    owner[entry.name] = guarded(entry.owner .. "." .. entry.name, owner[entry.name], entry)
end

local function startAll()
    started = true
    for _, entry in ipairs(entries) do apply(entry) end
end

function Wrap.method(owner, name, handler)
    assert(type(owner) == "string" and type(name) == "string" and type(handler) == "function",
        "Wrap.method: owner and name (strings) and handler (function) needed")
    for _, entry in ipairs(entries) do
        if entry.owner == owner and entry.name == name then
            entry.handler = handler
            return
        end
    end
    local entry = { owner = owner, name = name, handler = handler }
    table.insert(entries, entry)
    if started or TPCoreTesting then apply(entry) end
end

-- Whether owner.name has been wrapped (for the tests and the console).
function Wrap.applied(owner, name)
    for _, entry in ipairs(entries) do
        if entry.owner == owner and entry.name == name then return entry.applied == true end
    end
    return false
end

if not TPCoreTesting then
    if isServer() then Events.OnGameBoot.Add(startAll) else Events.OnGameStart.Add(startAll) end
end

return Wrap
