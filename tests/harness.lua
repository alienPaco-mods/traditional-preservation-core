-- Shared test harness for the Traditional Preservation mods. Tests run from the mod folder and load it with
--   local H = dofile((os.getenv("TPCORE") or "../_tpcore") .. "/tests/harness.lua")
-- Everything here is opt-in: a test keeps any stub of its own that behaves differently on purpose.
local H = {}

-- Prints one line per check and stops at the first failure, as every test always has.
function H.check(name, condition)
    print((condition and "ok   " or "FAIL ") .. name)
    if not condition then os.exit(1) end
end

function H.near(a, b, tolerance)
    return math.abs(a - b) < (tolerance or 1e-6)
end

-- A Java-style list: size() and get(i) from 0.
function H.list(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end, items = items }
end

function H.done()
    print("all passed")
end

-- A game clock the test moves with H.setHours.
H.hours = 0
function H.installClock(hours)
    H.hours = hours or 0
    getGameTime = function() return { getWorldAgeHours = function() return H.hours end } end
end

function H.setHours(hours)
    H.hours = hours
end

-- ModData.getOrCreate with one table per key, kept in H.modData.
function H.installModData()
    H.modData = {}
    ModData = {
        getOrCreate = function(key)
            H.modData[key] = H.modData[key] or {}
            return H.modData[key]
        end,
    }
end

-- Events.<Name>.Add for any name. Handlers are kept so a test can fire them with H.fire.
function H.installEvents()
    H.handlers = {}
    Events = setmetatable({}, {
        __index = function(events, name)
            local event = {
                Add = function(handler)
                    H.handlers[name] = H.handlers[name] or {}
                    table.insert(H.handlers[name], handler)
                end,
                Remove = function() end,
            }
            rawset(events, name, event)
            return event
        end,
    })
end

function H.fire(name, ...)
    for _, handler in ipairs(H.handlers and H.handlers[name] or {}) do handler(...) end
end

-- Reads one JSON string starting just after its opening quote. Returns the text and where it ended.
local ESCAPES = { n = "\n", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
local function readString(json, at)
    local parts = {}
    while at <= #json do
        local c = json:sub(at, at)
        if c == '"' then return table.concat(parts), at end
        if c == "\\" then
            at = at + 1
            local e = json:sub(at, at)
            table.insert(parts, ESCAPES[e] or e)
        else
            table.insert(parts, c)
        end
        at = at + 1
    end
end

-- Every "key": "value" pair of a flat JSON object, as the translation files are.
function H.jsonStrings(json)
    local pairsFound, at = {}, 1
    while true do
        local open = json:find('"', at, true)
        if not open then break end
        local key, keyEnd = readString(json, open + 1)
        local valueOpen = key and json:find('^%s*:%s*"', keyEnd + 1)
        if not valueOpen then break end
        local quote = json:find('"', keyEnd + 1, true)
        local value, valueEnd = readString(json, quote + 1)
        if not value then break end
        table.insert(pairsFound, { key, value })
        at = valueEnd + 1
    end
    local index = 0
    return function()
        index = index + 1
        local pair = pairsFound[index]
        if pair then return pair[1], pair[2] end
    end
end

-- The mod's real EN translations, from every JSON file in Translate/EN.
function H.loadTranslations(folder)
    folder = folder or "42/media/lua/shared/Translate/EN"
    local texts = {}
    local pipe = io.popen('ls "' .. folder .. '"/*.json 2>/dev/null')
    for path in pipe:lines() do
        local file = io.open(path, "r")
        local json = file:read("*a")
        file:close()
        for key, value in H.jsonStrings(json) do texts[key] = value end
    end
    pipe:close()
    return texts
end

-- getText as the game does it, filling %1, %2 ... It also notes, in H.textWarnings, the three things the game's
-- Java formatter throws a warning on (see ENGINE_NOTES, "Translations and getText"), so a test can check for none.
function H.installGetText(texts)
    H.texts = texts or H.loadTranslations()
    H.textWarnings = {}
    getText = function(key, ...)
        local text = H.texts[key]
        if not text then return key end
        local values = { ... }
        local stripped = text:gsub("%%%d", "")
        if stripped:find("%%") then table.insert(H.textWarnings, key .. ": a literal % in the text") end
        for _, value in ipairs(values) do
            if tostring(value):find("%%%a") then table.insert(H.textWarnings, key .. ": a value with % and a letter") end
        end
        if #values == 0 and text:find("%%%d") then
            table.insert(H.textWarnings, key .. ": %1 with no values")
            return (text:gsub("%%(%d)", "%%%1$s"))
        end
        return (text:gsub("%%(%d)", function(index) return tostring(values[tonumber(index)]) end))
    end
end

return H
