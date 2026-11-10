-- Checks the shared harness, and every mod's EN translations for text the game's formatter chokes on.
-- Run from ~/MODS/TraditionalPreservationCore: luajit tests/test_harness.lua
local H = dofile("tests/harness.lua")
local check = H.check

H.installGetText({ Plain = "Hello", One = "%1 L", Two = "%1 of %2", Bad = "95% done" })
check("an unknown key comes back as itself", getText("Missing") == "Missing")
check("values fill %1 and %2", getText("Two", "3", "4") == "3 of 4" and #H.textWarnings == 0)
check("a literal % is noted", getText("Bad") == "95% done" and H.textWarnings[1]:find("literal", 1, true))
H.installGetText({ One = "%1 L" })
check("%1 with no values comes back as %1$s and is noted", getText("One") == "%1$s L" and #H.textWarnings == 1)
H.installGetText({ One = "%1 L" })
getText("One", "40%s")
check("a value with % and a letter is noted", #H.textWarnings == 1)

H.installClock(5)
check("the clock starts where it's told", getGameTime():getWorldAgeHours() == 5)
H.setHours(9)
check("and moves when set", getGameTime():getWorldAgeHours() == 9)

H.installModData()
ModData.getOrCreate("A").x = 1
check("ModData keeps one table per key", ModData.getOrCreate("A").x == 1 and ModData.getOrCreate("B").x == nil)

H.installEvents()
local fired = 0
Events.EveryTenMinutes.Add(function(n) fired = fired + n end)
H.fire("EveryTenMinutes", 2)
check("any event can be added to and fired", fired == 2)

local items = H.list({ "a", "b" })
check("a list counts from 0 like Java's", items:size() == 2 and items:get(0) == "a")

local parsed = {}
for key, value in H.jsonStrings('{\n  "A": "x \\"y\\"",\n  "B": ""\n}') do parsed[key] = value end
check("the JSON reader handles escapes and empty values", parsed.A == 'x "y"' and parsed.B == "")

-- Every mod's real translation files, one by one (some keys are in two files): a literal % breaks the
-- game's formatter. The count of keys read must match the count of lines with a key, so nothing is skipped.
local pipe = io.popen('ls ../*/42/media/lua/shared/Translate/EN/*.json 2>/dev/null')
local byMod = {}
for path in pipe:lines() do
    local mod = path:match("^%.%./([^/]+)/")
    if not mod:find("%-old$") then
        local file = io.open(path, "r")
        local json = file:read("*a")
        file:close()
        local entry = byMod[mod] or { bad = {}, read = 0, lines = 0 }
        byMod[mod] = entry
        for key, text in H.jsonStrings(json) do
            entry.read = entry.read + 1
            if text:gsub("%%%d", ""):find("%%") then table.insert(entry.bad, key) end
        end
        for _ in json:gmatch('\n%s*"[^"]+"%s*:') do entry.lines = entry.lines + 1 end
    end
end
pipe:close()
local mods = {}
for mod in pairs(byMod) do table.insert(mods, mod) end
table.sort(mods)
for _, mod in ipairs(mods) do
    local entry = byMod[mod]
    table.sort(entry.bad)
    check(mod .. ": all " .. entry.lines .. " translations read", entry.read == entry.lines and entry.read > 0)
    check(mod .. " has no literal % in its translations" .. (#entry.bad > 0 and (": " .. table.concat(entry.bad, ", ")) or ""), #entry.bad == 0)
end

H.done()
