-- Checks the batch timer outside the game. Run from the mod folder: luajit tests/test_process.lua
local H = dofile((os.getenv("TPCORE") or "../TraditionalPreservationCore") .. "/tests/harness.lua")
local check, near = H.check, H.near
H.useModPaths()
H.installClock(10)
H.installModData()
H.installEvents()
H.installGetText()
local loaded = {}
ScriptManager = { instance = { getCraftRecipe = function() return { Load = function(_, name, text) loaded[name] = text end } end } }
dofile("42/media/lua/shared/__MOD__.lua")
local M = __MOD__

local function recipeData(time)
    local craftRecipeData = { modData = {}, elapsed = 0 }
    function craftRecipeData:getModData() return self.modData end
    function craftRecipeData:getElapsedTime() return self.elapsed end
    function craftRecipeData:setElapsedTime(seconds) self.elapsed = seconds end
    function craftRecipeData:getRecipe() return { getTime = function() return time end } end
    return craftRecipeData
end

local function weather(count, temperature)
    for _ = 1, count do
        H.setHours(H.hours + 1)
        M.advance(M.getLedger(), H.hours, temperature)
    end
end

-- Temperature
check("full speed at its best temperature", M.processRate(20) == 1)
check("slower in the cold, never stopped", M.processRate(-20) > 0 and M.processRate(-20) < M.processRate(10))
M.SENSITIVITY = 0
check("sensitivity off runs at full speed in any weather", M.processRate(-20) == 1)
M.SENSITIVITY = 1
check("a basement swings two fifths as far as the ground", M.placeTemperature({ temperature = -15, seasonTemperature = -5, groundTemperature = -10 }, "Basement") == 2)

-- Timer
local TIME = M.PROCESS_HOURS * 3600
local craftRecipeData = recipeData(TIME)
M.onProcessStart(craftRecipeData)
craftRecipeData.modData.place = "Open"
weather(24, 10)
M.onProcessUpdate(craftRecipeData)
local rate = M.processRate(10)
check("a batch counts the work at its place's temperature", near(craftRecipeData.modData.workHours, 24 * rate))
check("the bar shows it in game seconds", near(craftRecipeData.elapsed, 24 * rate * 3600))
local status = M.batchStatus(craftRecipeData.modData, M.PROCESS_HOURS, M.getLedger())
check("the popup's time left assumes the rate holds", near(status.hoursLeft, (M.PROCESS_HOURS - 24 * rate) / rate))
weather(M.PROCESS_HOURS * 2, 22)
M.onProcessUpdate(craftRecipeData)
check("the bar stops at the recipe's time", craftRecipeData.elapsed == TIME)

-- A pooled recipe craftRecipeData starts clean
M.onProcessStart(craftRecipeData)
check("a new run starts from nothing", craftRecipeData.modData.workHours == 0 and craftRecipeData.modData.place == nil)

-- Sandbox
SandboxVars = { __MOD__ = { ProcessDays = 2, TemperatureSensitivity = 1 } }
H.fire("OnInitGlobalModData")
check("the sandbox sets the time", M.PROCESS_HOURS == 48 and loaded["__MOD__.ProcessBatch"] == "{ time = 172800, }")
check("and the sensitivity", M.SENSITIVITY == 0)

-- Translations
check("the popup's texts are translated", getText("IGUI___MOD___Time", 1, 2) == "1d 2h, if the temperature holds"
    and getText("IGUI___MOD___Temperature") == "Temperature")
check("with no formatter errors", #H.textWarnings == 0)
H.done()
