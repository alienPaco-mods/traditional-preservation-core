-- Traditional Preservation (__NAME__) B42: how a batch works on the __STATION__.
-- Made by `tp new` from ~/MODS/_tpcore/template: a working one-station skeleton. Lines marked TEMPLATE are
-- placeholders to replace with the real technique (SERIES.md, "Designing a new mod").
-- Each press of Craft runs its own timer. A batch works by the temperature where the station stands: running
-- totals of the weather in global ModData say how much each one has done, even while its area was unloaded.
__MOD__ = __MOD__ or {}
local M = __MOD__
local Weather = require "__MOD__/Core/Weather"

M.PROCESS_HOURS = 72  -- TEMPLATE: hours at the best temperature
-- Save keys: never rename these once the mod is out (DEVGUIDE, "Rules that keep saves and the game happy").
M.MOD_DATA_KEY = "__MOD__"
local RECIPE_NAME = "__MOD__.ProcessBatch"
-- The ledger's totals are "<kind><place>", e.g. "processOpen".
local KIND = "process"

-- TEMPLATE: { temperature, share of full speed } points, joined by straight lines.
local PROCESS_CURVE = { { -5, 0.05 }, { 0, 0.1 }, { 5, 0.2 }, { 10, 0.4 }, { 18, 1 }, { 30, 1 }, { 35, 0.6 }, { 40, 0.1 } }
-- Off, Forgiving, Normal, Harsh: how much of a temperature's slowdown applies.
M.SENSITIVITY_SCALES = { 0, 0.5, 1, 1.5 }
M.SENSITIVITY = 1
M.MIN_RATE = 0.02

-- Places and their temperatures are shared with the other Traditional Preservation mods; these are the
-- mod's public names for them, used by the Dev console and the tests.
M.PLACES = Weather.PLACES
M.placeTemperature = Weather.placeTemperature
M.placeOf = Weather.placeOf

function M.processRate(celsius)
    return Weather.scaled(Weather.curve(PROCESS_CURVE, celsius), M.SENSITIVITY, M.MIN_RATE)
end

local KINDS = { [KIND] = function(celsius) return M.processRate(celsius) end }

function M.newLedger(now)
    return Weather.newLedger(now, KINDS)
end

-- Adds one stretch of weather to the totals.
function M.advance(ledger, now, temperature)
    Weather.advance(ledger, now, temperature, KINDS)
end

function M.getLedger()
    return Weather.getLedger(M.MOD_DATA_KEY, M.newLedger)
end

local function runPlace(modData)
    return modData.place or "Sheltered"
end

-- The engine pools recipe data without clearing its ModData, so every run must set all of this.
function M.onProcessStart(craftRecipeData)
    Weather.startRun(craftRecipeData:getModData(), M.getLedger(), KIND)
end

-- Craft timers tick at a fixed speed whatever Day Length says, so this replaces their count with the
-- work done at the station's temperature. It goes by where the station stands now.
function M.onProcessUpdate(craftRecipeData)
    local ledger = M.getLedger()
    local modData = craftRecipeData:getModData()
    local place = runPlace(modData)
    modData.done = modData.done + Weather.catchUp(modData.last, ledger, KIND, place)
    Weather.showProgress(craftRecipeData, ledger, KIND, place, 1, getGameTime():getWorldAgeHours())
end

-- How a running batch is doing, for its popup. hoursLeft assumes the temperature holds.
function M.batchStatus(modData, recipeHours, ledger)
    return Weather.batchStatus(modData.done or 0, recipeHours, ledger, runPlace(modData), M.processRate)
end

function M.applySandbox()
    local options = SandboxVars and SandboxVars.__MOD__
    if not options then return end
    if options.ProcessDays then M.PROCESS_HOURS = options.ProcessDays * 24 end
    if options.TemperatureSensitivity then M.SENSITIVITY = M.SENSITIVITY_SCALES[options.TemperatureSensitivity] or 1 end
end

function M.applyProcessTime()
    M.applySandbox()
    Weather.setRecipeHours(RECIPE_NAME, M.PROCESS_HOURS, "__MOD__")
end

Events.OnInitGlobalModData.Add(M.applyProcessTime)
