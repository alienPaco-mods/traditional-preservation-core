-- Shared test harness for the Traditional Preservation mods. Tests run from the mod folder and load it with
--   local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
-- Everything here is opt-in: a test keeps any stub of its own that behaves differently on purpose.
local H = {}

-- The core's Log asks this before it prints: tests run quiet unless one sets it.
isDebugEnabled = isDebugEnabled or function() return false end

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

-- Lets require find the mod's own Lua and TP Core's as the game does, so a mod file can
--   local Weather = require "TraditionalPreservationCore/Weather"
-- (or a mod still carrying its own copy: require "TraditionalPreservationYeast/Core/Weather").
function H.useModPaths()
    local core = (os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/42/media/lua/"
    package.path = "42/media/lua/shared/?.lua;42/media/lua/client/?.lua;42/media/lua/server/?.lua;"
        .. core .. "shared/?.lua;" .. core .. "client/?.lua;" .. package.path
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

-- The mod's real EN translations, from every JSON file in Translate/EN. With no folder, TP Core's come first, as
-- the game has them loaded for every TP mod (the place words, UI.placeText).
function H.loadTranslations(folder)
    if not folder then
        local texts = H.loadTranslations((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/42/media/lua/shared/Translate/EN")
        for key, value in pairs(H.loadTranslations("42/media/lua/shared/Translate/EN")) do texts[key] = value end
        return texts
    end
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

-- A player for a Dev console or a menu: stands at at.x, at.y, at.z (in a room unless at.outside) and keeps the
-- full types it was given in .given.
function H.player(at)
    at = at or {}
    local x, y, z = at.x or 0, at.y or 0, at.z or 0
    local square = { getX = function() return x end, getY = function() return y end, getZ = function() return z end,
        isOutside = function() return at.outside == true end, isInARoom = function() return at.outside ~= true end }
    local player = { given = {} }
    local inventory = { AddItem = function(_, fullType) table.insert(player.given, fullType) return {} end }
    function player:getInventory() return inventory end
    function player:getSquare() return square end
    function player:getCurrentSquare() return square end
    function player:getX() return x + 0.5 end
    function player:getY() return y + 0.5 end
    function player:getZ() return z end
    function player:isOutside() return at.outside == true end
    return player
end

-- A vanilla Lua class a mod derives from (a timed action, a window): derive and new, nothing else.
function H.class(name)
    local base = { Type = name }
    function base:derive(type)
        return setmetatable({ Type = type }, { __index = self })
    end
    function base.new(self, character)
        return setmetatable({ character = character }, { __index = self })
    end
    return base
end

-- A right-click menu: .options in order, each with its submenu in .subOption if it has one. An option keeps what
-- choosing it calls: option.onSelect(option.target, unpack(option.args)).
function H.menu()
    local self = { options = {} }
    function self:addOption(name, target, onSelect, ...)
        local option = { name = name, target = target, onSelect = onSelect, args = { ... } }
        table.insert(self.options, option)
        return option
    end
    function self:getNew() return H.menu() end
    function self:addSubMenu(option, sub) option.subOption = sub end
    function self:getSubMenu(sub) return sub end
    function self:getOptionFromName(name)
        for _, option in ipairs(self.options) do
            if option.name == name then return option end
        end
    end
    return self
end

-- An item with a fluid container: litres of fluid ("Mix" for a mixture, nil for none) in a vessel that holds
-- capacity litres. more adds or replaces methods (getFullType, isFavorite ...).
function H.vessel(name, fluid, litres, capacity, more)
    local container = {
        isEmpty = function() return litres <= 0 end,
        getAmount = function() return litres end,
        getCapacity = function() return capacity end,
        getPrimaryFluid = function() return litres > 0 and { getFluidTypeString = function() return fluid end } or nil end,
        getPrimaryFluidAmount = function() return fluid == "Mix" and litres / 2 or litres end,
    }
    local item = {
        getFluidContainer = function() return container end,
        getDisplayName = function() return name end,
        getTex = function() return name .. ".png" end,
        isFavorite = function() return false end,
        getFullType = function() return "Base." .. name:gsub("%W", "") end,
    }
    local modData = {}
    item.getModData = function() return modData end
    for key, value in pairs(more or {}) do item[key] = value end
    return item
end

-- What a right-click menu file touches in the engine. Returns the record a test reads and sets:
--   .carried  the items in reach (set it)      .queued  the timed actions queued
--   .moved    the items brought to hand        .probes  times a controller's probe was answered
--   .walks    times the player was sent over   .vanillaPickUp  what vanilla says to picking a tile up (set it)
-- An object is instanceof its .class field.
function H.installMenus()
    local ui = { carried = {}, queued = {}, moved = {}, probes = 0, walks = 0, vanillaPickUp = true }
    H.ui = ui
    ISBaseTimedAction, ISCollapsableWindow = H.class("ISBaseTimedAction"), H.class("ISCollapsableWindow")
    function instanceof(object, name) return type(object) == "table" and object.class == name end
    function getTexture(name) return name end
    function getSpecificPlayer() return "player" end
    Fluid = { Get = function() return nil end }
    ISWorldObjectContextMenu = {
        addToolTip = function() return {} end,
        setTest = function() ui.probes = ui.probes + 1 return true end,
    }
    local function walk() ui.walks = ui.walks + 1 return true end
    luautils = { walkAdj = walk }
    ISEntityUI = { WalkToEntity = walk }
    ISTimedActionQueue = { add = function(action) table.insert(ui.queued, action) end }
    ISInventoryPaneContextMenu = {
        getContainers = function() return H.list({ { getItems = function() return H.list(ui.carried) end } }) end,
        transferIfNeeded = function(_, item) table.insert(ui.moved, item) end,
    }
    -- Vanilla's Light Fire submenu, as one option.
    ISCampingMenu = {
        doLightFireOption = function(_, context) return context:addOption("Light Fire") end,
        timeString = function(minutes) return minutes .. " min" end,
    }
    InfoPanelFlags = {}
    ISMoveableSpriteProps = {
        canPickUpMoveable = function() return ui.vanillaPickUp end,
        getInfoPanelFlagsPerTile = function() InfoPanelFlags.hasItems = false end,
    }
    return ui
end

-- Loads a mod's Dev console as the game does and checks what breaks unseen: it stays out of a normal game, it
-- loads in debug mode, and help() lists every command it has and none it hasn't. Returns the console and
--   run("command", ...)  calls it and returns what it printed, as one text
-- so a test can go on to call the commands its stand-ins can carry.
function H.checkConsole(path, name)
    local wasDebug, realPrint = isDebugEnabled, print
    local function quietly(work, ...)
        local lines = {}
        print = function(...)
            local parts = {}
            for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
            table.insert(lines, table.concat(parts, "\t"))
        end
        isDebugEnabled = function() return true end
        local ok, problem = pcall(work, ...)
        print, isDebugEnabled = realPrint, wasDebug
        if not ok then
            realPrint(table.concat(lines, "\n"))
            error(problem, 0)
        end
        return table.concat(lines, "\n")
    end

    isDebugEnabled = function() return false end
    dofile(path)
    isDebugEnabled = wasDebug
    H.check(name .. " stays out of a game without debug mode", _G[name] == nil)
    quietly(dofile, path)
    local console = _G[name]
    H.check(name .. " loads in debug mode", type(console) == "table" and type(console.help) == "function")

    local listed, unknown, unlisted = {}, {}, {}
    for command in quietly(console.help):gmatch(name .. "%.(%w+)%(") do
        listed[command] = true
        if type(console[command]) ~= "function" then table.insert(unknown, command) end
    end
    for command, value in pairs(console) do
        if type(value) == "function" and command ~= "help" and not listed[command] then table.insert(unlisted, command) end
    end
    table.sort(unknown)
    table.sort(unlisted)
    H.check(name .. ".help() lists only commands that exist" .. (unknown[1] and " (not " .. table.concat(unknown, ", ") .. ")" or ""), #unknown == 0)
    H.check(name .. ".help() lists every command" .. (unlisted[1] and " (not " .. table.concat(unlisted, ", ") .. ")" or ""), #unlisted == 0)

    return console, function(command, ...) return quietly(console[command], ...) end
end

-- Checks a mod's generated Tiles.lua against its entity scripts: every sprite a script names is a tile the
-- builder made, and every station sprite has a script. Run from the mod folder.
function H.checkTiles(Tiles)
    local sheets = {}
    for _, sheet in ipairs(Tiles.SHEETS) do sheets[sheet.prefix] = sheet.tiles end
    local function exists(name)
        local prefix, index = string.match(name, "^(.-_%d%d_)(%d+)$")
        return prefix ~= nil and sheets[prefix] ~= nil and tonumber(index) < sheets[prefix]
    end
    local named, bad = {}, {}
    local files = io.popen("find 42/media/scripts -name '*.txt' | sort")
    for path in files:lines() do
        for line in io.lines(path) do
            for prefix in pairs(sheets) do
                for name in string.gmatch(line, prefix:gsub("%p", "%%%0") .. "%d+") do
                    named[name] = true
                    if not exists(name) then table.insert(bad, path .. ": " .. name) end
                end
            end
        end
    end
    files:close()
    H.check("every sprite the scripts name is a tile the builder made" .. (bad[1] and " (" .. table.concat(bad, ", ") .. ")" or ""), #bad == 0)
    local missing = {}
    for _, name in ipairs(Tiles.STATIONS) do
        if not named[name] then table.insert(missing, name) end
    end
    H.check("every station sprite has a script" .. (missing[1] and " (" .. table.concat(missing, ", ") .. ")" or ""), #missing == 0)
    local outdoor = true
    for name in pairs(Tiles.OUTDOOR or {}) do outdoor = outdoor and exists(name) end
    H.check("the outdoor-only sprites are tiles", outdoor)
end

return H
