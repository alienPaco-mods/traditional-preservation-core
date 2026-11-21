-- Traditional Preservation core: the station report, a text file written on each save, of what every station's info
-- window would show now: its band, the Station block, what it holds and its list. Read-only: each station is brought
-- up to now as opening its window does, and nothing else changes. Only stations loaded at the save are in it (the
-- squares round the player), so a station far off is missing, not empty. For the long save's log:
-- _pzdev/longsave_snapshot.py copies it into the log's repo.
-- A window takes part with one line beside its class, the function giving the station it opens on for an object a
-- tracker holds (or nil), so a station of several tiles is reported once:
--     StationReport.add(ClothWindow, function(isoObject) return DryingCloth.isCloth(isoObject) and isoObject or nil end)
-- The window is made but never shown: its refresh runs, then its render with the blocks recording their text instead
-- of drawing (band, stationBlock, holds, pieceListBlock, bar, row); buttons, notes and the lore are left out.
local Station = require "TraditionalPreservationCore/Station"
local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local UI = require "TraditionalPreservationCore/UI"

local StationReport = {}

StationReport.FILE = "TraditionalPreservationStations_%s.txt"   -- in ~/Zomboid/Lua, by the save's folder name
StationReport.INDENT = "  "

local windows = {}

function StationReport.add(class, stationOf)
    table.insert(windows, { class = class, stationOf = stationOf })
end

-- Text the windows mark up for the game's rich text, plain.
local function plain(text)
    text = tostring(text or "")
    return (text:gsub("%s*<LINE>%s*", " / "):gsub("%s*<[%u_]+[^>]*>%s*", " "))
end

local function joined(parts)
    local kept = {}
    for _, part in ipairs(parts) do
        if part ~= nil and part ~= "" then table.insert(kept, plain(part)) end
    end
    return table.concat(kept, ", ")
end

-- A holding as one line: its name, amount, state, the line under it, heat, counts, and the rate on its arrow. A
-- starter's slot has no label in the window, its name is what it says ("Add Mother", "used"): "Slot: " and that,
-- its count in brackets.
local function holdingLine(holding)
    local parts = { holding.amount, holding.state, holding.under }
    local celsius = holding.kind == "heat" and holding.celsius or holding.heat and holding.heat.celsius
    if celsius then table.insert(parts, getText("IGUI_TraditionalPreservationCore_HeatDegrees", tostring(math.floor(celsius + 0.5)))) end
    for _, count in ipairs(holding.counts or {}) do table.insert(parts, "x" .. tostring(count.count)) end
    local line
    if holding.kind == "slot" then
        line = "Slot: " .. plain(holding.name)
        if holding.count then line = line .. " (" .. plain(holding.count) .. ")" end
        if #parts > 0 then line = line .. ", " .. joined(parts) end
    else
        local rest = joined(parts)
        line = plain(holding.name) .. (rest ~= "" and ": " .. rest or "")
    end
    if holding.arrow and holding.arrow ~= "" then line = line .. " -> " .. plain(holding.arrow) end
    return line
end

local function pieceLines(lines, labelText, rows)
    table.insert(lines, plain(labelText))
    for _, row in ipairs(rows or {}) do
        local line = "- " .. plain(row.name) .. ": " .. plain(row.text)
        if row.warning then line = line .. " [" .. plain(row.warning) .. "]" end
        if row.note then line = line .. " (" .. plain(row.note) .. ")" end
        table.insert(lines, StationReport.INDENT .. line)
    end
end

local function noop() end
-- The drawing an ISUIElement does through its Java object, which a window never shown hasn't got.
local DRAWING = { "drawText", "drawTextCentre", "drawTextRight", "drawTextZoomed", "drawRect", "drawRectBorder",
    "drawTexture", "drawTextureScaled", "drawTextureScaledAspect", "setHeight", "setWidth", "addChild" }

-- A window of class on station that records what its render shows into lines.
local function recorder(class, playerObj, station, lines)
    local window = class:new(playerObj, station)
    for _, name in ipairs(DRAWING) do window[name] = noop end
    local function add(text) table.insert(lines, text) end
    window.top = function() return 0 end
    window.band = function(_, word, text) add(string.upper(plain(word)) .. ": " .. plain(text)) return 0 end
    window.section = function(_, y, label)
        if label ~= "IGUI_TraditionalPreservationCore_SectionStation" then add(plain(getText(label)) .. ":") end
        return y
    end
    window.stationBlock = function(self, y, _, place, celsius, rows)
        local Weather = require "TraditionalPreservationCore/Weather"
        for _, row in ipairs(InfoWindow.stationRows(place, celsius, rows, Weather.weatherModData().seasonTemperature)) do
            add(plain(row.label) .. ": " .. plain(row.value))
        end
        return y
    end
    window.holds = function(_, y, holdings)
        for _, holding in ipairs(holdings or {}) do add(StationReport.INDENT .. holdingLine(holding)) end
        return y
    end
    window.row = function(_, y, label, text) add(plain(getText(label)) .. ": " .. plain(text)) return y end
    window.placeRow = function(_, y, label, place, celsius)
        add(plain(getText(label)) .. ": " .. plain(UI.placeText(place, celsius)))
        return y
    end
    local function bar(labelText, share, text)
        add(plain(labelText) .. ": " .. (text and plain(text) or UI.percent(share or 0)))
    end
    window.bar = function(_, y, label, share, _, text) bar(getText(label), share, text) return y end
    window.barNamed = function(_, y, labelText, share, _, text) bar(labelText, share, text) return y end
    window.pieceListBlock = function(_, y, sectionLabel, labelText, rows)
        add(plain(getText(sectionLabel)) .. ":")
        pieceLines(lines, labelText, rows)
        return y
    end
    window.pieceList = function(_, y, label, rows) pieceLines(lines, getText(label), rows) return y end
    window.pieceListNamed = function(_, y, labelText, rows) pieceLines(lines, labelText, rows) return y end
    window.buttonRow = function(_, y) return y end
    window.dropZone = function(_, y) return y end
    window.drawNotes = noop
    return window
end

-- What class's window on station shows, as lines, and the window; one line saying why if it couldn't be read.
function StationReport.linesOf(class, playerObj, station)
    local lines = {}
    local frame = ISCollapsableWindow.render
    ISCollapsableWindow.render = noop   -- the title bar and frame: drawing only
    local ok, result = pcall(function()
        local window = recorder(class, playerObj, station, lines)
        window:refresh()
        class.render(window)
        return window
    end)
    ISCollapsableWindow.render = frame
    if not ok then return { "(couldn't be read: " .. tostring(result) .. ")" }, nil end
    return lines, result
end

-- Each loaded station once, with the window it opens: { station, class }, by the window's title then west to
-- east, north to south, level.
local function found()
    local stations, seen = {}, {}
    Station.eachLoaded(function(isoObject)
        for _, entry in ipairs(windows) do
            local station = entry.stationOf(isoObject)
            if station and not seen[station] then
                seen[station] = true
                table.insert(stations, { station = station, class = entry.class })
                break
            end
        end
    end)
    return stations
end

local function where(station)
    local square = station:getSquare()
    return square:getX(), square:getY(), square:getZ()
end

-- The report's text: a header, then a block a station.
function StationReport.text(playerObj)
    local gameTime = getGameTime()
    local hours = gameTime:getWorldAgeHours()
    local blocks = {}
    for _, entry in ipairs(found()) do
        local lines, window = StationReport.linesOf(entry.class, playerObj, entry.station)
        local x, y, z = where(entry.station)
        local title = plain(window and window.title or entry.class.Type or "?")
        table.insert(blocks, { title = title, x = x, y = y, z = z, lines = lines })
    end
    table.sort(blocks, function(a, b)
        if a.title ~= b.title then return a.title < b.title end
        if a.x ~= b.x then return a.x < b.x end
        if a.y ~= b.y then return a.y < b.y end
        return a.z < b.z
    end)
    local out = {
        "Traditional Preservation stations, save " .. tostring(getWorld():getWorld()),
        string.format("In game: %04d-%02d-%02d %02d:%02d, day %d (hours=%.2f)", gameTime:getYear(), gameTime:getMonth() + 1,
            gameTime:getDay() + 1, gameTime:getHour(), gameTime:getMinutes(), math.floor(hours / 24) + 1, hours),
        string.format("Player at %d, %d, %d", math.floor(playerObj:getX()), math.floor(playerObj:getY()), math.floor(playerObj:getZ())),
        string.format("Stations loaded: %d (a station far from the player isn't loaded and isn't listed)", #blocks),
    }
    for _, block in ipairs(blocks) do
        table.insert(out, "")
        table.insert(out, string.format("== %s (%d, %d, %d)", block.title, block.x, block.y, block.z))
        for _, line in ipairs(block.lines) do table.insert(out, StationReport.INDENT .. line) end
    end
    return table.concat(out, "\n") .. "\n"
end

function StationReport.write()
    local playerObj = getPlayer()
    if not playerObj then return end
    local ok, text = pcall(StationReport.text, playerObj)
    if not ok then text = "Traditional Preservation stations: the report failed: " .. tostring(text) .. "\n" end
    local writer = getFileWriter(string.format(StationReport.FILE, tostring(getWorld():getWorld())), true, false)
    writer:write(text)
    writer:close()
end

Events.OnSave.Add(StationReport.write)

return StationReport
