-- Traditional Preservation (__NAME__): commands for the debug Lua console, loaded only in debug mode.
-- Type __SHORT__.help() in the console for the list. See DEVHELP.md in the mod folder.
if not isDebugEnabled() then return end

local M = __MOD__
local Weather = require "__MOD__/Core/Weather"
__SHORT__ = {}

local RECIPE_NAME = "__MOD__.ProcessBatch"

local function say(text) print("[__SHORT__] " .. text) end

function __SHORT__.help()
    say("__SHORT__.weather()        the temperature by place, and how fast a batch works there")
    say("__SHORT__.here()           which place you're standing in (outdoors, under a roof or a basement)")
    say("__SHORT__.age(hours)       give every station this many hours of perfect weather")
    say("__SHORT__.fast(hours)      test timer: a batch takes this many hours. __SHORT__.fast() goes back to the sandbox time")
    say("__SHORT__.batches(n)       spawn n raw batches")
end

function __SHORT__.weather()
    local ledger = M.getLedger()
    say(string.format("Temperature now %.1f C, season (10-day average) %.1f C. A batch takes %.1f hours at full speed.",
        ledger.temperature or 0, ledger.seasonTemperature or 0, M.PROCESS_HOURS))
    for _, place in ipairs(M.PLACES) do
        local rate = ledger["process" .. place .. "Rate"] or 0
        say(string.format("%-9s %.1f C: %.0f%% speed, about %.1f days a batch", place, M.placeTemperature(ledger, place),
            rate * 100, rate > 0 and M.PROCESS_HOURS / rate / 24 or 0))
    end
end

function __SHORT__.here()
    say("You're in: " .. tostring(M.placeOf(getPlayer():getCurrentSquare())))
end

function __SHORT__.age(hours)
    hours = hours or 24
    local ledger = M.getLedger()
    for _, place in ipairs(M.PLACES) do ledger["process" .. place] = (ledger["process" .. place] or 0) + hours end
    say(string.format("Added %.0f hours of perfect weather. Batches update within a few seconds.", hours))
end

function __SHORT__.fast(hours)
    if not hours then
        M.applyProcessTime()
        return say(string.format("Back to the sandbox time: %.1f hours.", M.PROCESS_HOURS))
    end
    M.PROCESS_HOURS = hours
    Weather.setRecipeHours(RECIPE_NAME, hours, "__MOD__")
    say(string.format("Test timer on: a batch takes %s hours at full speed.", tostring(hours)))
end

function __SHORT__.batches(count)
    local inventory = getPlayer():getInventory()
    for _ = 1, count or 1 do inventory:AddItem("__MOD__.RawBatch") end
    say("Gave " .. (count or 1) .. " raw batch(es).")
end

say("Debug commands loaded. Type __SHORT__.help() in the Lua console.")
