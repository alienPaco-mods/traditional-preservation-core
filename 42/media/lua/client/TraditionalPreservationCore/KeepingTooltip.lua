-- Traditional Preservation core: how long a food kept by place keeps where it is, in its inventory and loot
-- tooltip (ItemTooltip.lua): "Fresh for about 12 days here, rotten in about 20" and "13°C (Basement), ages 0.45 days
-- a day", with a mod's own lines after (a storage's factor, a cure's progress). Read-only: the age is as at the item's
-- last look (PlaceKeepingUI looks at a container as the inventory windows show it). Sandbox "Keeping in item
-- tooltips" (TP Core, on) hides it for a harder game. A mod adds the types it keeps and the lines for one:
--     KeepingTooltip.add(M.BUTTER_DAYS, function(item) return KeepingTooltip.keeperLines(M.BUTTER_KEEPER, item) end)
-- lines(item) returns a list of finished lines, or nil for none.
local ItemTooltip = require "TraditionalPreservationCore/ItemTooltip"
local UI = require "TraditionalPreservationCore/UI"

local KeepingTooltip = {}

KeepingTooltip.CACHE_MS = 500   -- a hovered item's lines are worked out again at most this often (real time)

local say = UI.say
local byType = {}

function KeepingTooltip.add(types, lines)
    for fullType in pairs(types) do byType[fullType] = lines end
end

function KeepingTooltip.shown()
    local options = SandboxVars and SandboxVars.TraditionalPreservationCore
    return not options or options.KeepingTooltips ~= false
end

-- Days as the windows say them: whole hours up to two days, then about N days.
function KeepingTooltip.days(days)
    return UI.durationText(days * 24)
end

-- Where an item is and how fast it ages there: "13°C (Basement), ages 0.45 days a day"; a freezer has no reading.
function KeepingTooltip.whereLine(forecast)
    local where = forecast.celsius and UI.placeText(forecast.place, forecast.celsius) or UI.placeName(forecast.place)
    return say("IGUI_TraditionalPreservationCore_KeepAt", where, string.format("%.2f", forecast.rate))
end

-- The two lines of a PlaceKeeping keeper's forecast (keeper.forecast): how long it keeps here, and where it is.
-- factor scales the rate (a storage's). Nil with the keeper off or for an item already rotten.
function KeepingTooltip.keeperLines(keeper, item, factor, place)
    if not keeper.enabled() then return nil end
    local forecast = keeper.forecast(item, place, factor)
    return KeepingTooltip.forecastLines(forecast)
end

-- The lines of a forecast ({ place, celsius, rate, stale, rotten }), for a mod that works out its own.
function KeepingTooltip.forecastLines(forecast)
    if not forecast.rotten then return nil end
    local keeps
    if forecast.rotten == math.huge then
        keeps = getText("IGUI_TraditionalPreservationCore_KeepStill")
    elseif forecast.stale then
        keeps = say("IGUI_TraditionalPreservationCore_KeepFresh", KeepingTooltip.days(forecast.stale), KeepingTooltip.days(forecast.rotten))
    else
        keeps = say("IGUI_TraditionalPreservationCore_KeepStale", KeepingTooltip.days(forecast.rotten))
    end
    return { keeps, KeepingTooltip.whereLine(forecast) }
end

local cache = setmetatable({}, { __mode = "k" })

local function textOf(item)
    local lines = byType[item:getFullType()]
    if not lines or not KeepingTooltip.shown() then return nil end
    local now = getTimestampMs()
    local kept = cache[item]
    if kept and now - kept.at < KeepingTooltip.CACHE_MS then return kept.text end
    local list = lines(item)
    local text = list and #list > 0 and table.concat(list, "\n") or nil
    cache[item] = { at = now, text = text }
    return text
end

ItemTooltip.add(textOf)

return KeepingTooltip
