-- Checks the shared core in 42/media/lua. Run from TraditionalPreservationCore: luajit tests/test_core.lua
local H = dofile("tests/harness.lua")
local check, near = H.check, H.near

local Weather = dofile("42/media/lua/shared/TraditionalPreservationCore/Weather.lua")
local Station = dofile("42/media/lua/shared/TraditionalPreservationCore/Station.lua")

-- Weather
local points = { { 0, 0.1 }, { 10, 0.5 }, { 20, 1 } }
check("curve: flat below the first point", Weather.curve(points, -5) == 0.1)
check("curve: flat past the last point", Weather.curve(points, 30) == 1)
check("curve: straight between points", near(Weather.curve(points, 5), 0.3) and near(Weather.curve(points, 15), 0.75))
check("scaled: off runs at full speed", Weather.scaled(0.2, 0, 0.02) == 1)
check("scaled: harsh slows more, down to the floor", near(Weather.scaled(0.8, 1.5, 0.02), 0.7) and Weather.scaled(0, 1.5, 0.02) == 0.02)
check("shelter: ten degrees over the season", Weather.shelterTemperature(5) == 15)
check("shelter: thick walls cap it", Weather.shelterTemperature(30) == Weather.SHELTER_MAX)
local ledger = { temperature = 30, seasonTemperature = 12 }
check("place: open goes by the day", Weather.placeTemperature(ledger, "Open") == 30)
check("place: a roof by the season", Weather.placeTemperature(ledger, "Sheltered") == 22)
check("place: a basement holds still", Weather.placeTemperature(ledger, "Basement") == Weather.BASEMENT_TEMPERATURE)

local function object(z, outside)
    return { getSquare = function() return { getZ = function() return z end } end, isOutside = function() return outside end }
end
check("placeOf: below ground", Weather.placeOf(object(-1, false)) == "Basement")
check("placeOf: under a roof", Weather.placeOf(object(0, false)) == "Sheltered")
check("placeOf: outdoors", Weather.placeOf(object(1, true)) == "Open")

local kinds = { [""] = function(celsius) return celsius >= 10 and 1 or 0.5 end }
ledger = Weather.newLedger(0, kinds)
check("ledger: zero totals for every place", ledger.Open == 0 and ledger.Sheltered == 0 and ledger.Basement == 0)
check("advance: nothing when no time has passed", Weather.advance(ledger, 0, 20, kinds) == nil)
check("advance: returns its hours", Weather.advance(ledger, 2, 5, kinds) == 2)
check("advance: open counts the day", ledger.Open == 1 and ledger.OpenRate == 0.5)
check("advance: a roof counts the season, warmer", ledger.Sheltered == 2 and ledger.ShelteredRate == 1)
check("advance: the first record is the season", near(ledger.seasonTemperature, 5))
Weather.advance(ledger, 2 + Weather.SEASON_HOURS * 2, 25, kinds)
check("season: a gap longer than a season replaces it", near(ledger.seasonTemperature, 25))
local filled = Weather.fillLedger({ malting = nil }, { malting = true, acetic = true })
check("fillLedger: adds missing totals", filled.maltingBasement == 0 and filled.aceticOpen == 0)

-- Catching up
ledger = { Open = 10, Sheltered = 20, Basement = 30 }
local marks = Weather.mark({}, ledger, "")
ledger.Open, ledger.Sheltered, ledger.Basement = 14, 25, 36
check("catchUp: the work at the station's place", Weather.catchUp(marks, ledger, "", "Sheltered") == 5)
check("catchUp: moves every mark on", marks.Open == 14 and marks.Sheltered == 25 and marks.Basement == 36)
check("catchUp: a new place with no mark counts nothing", Weather.catchUp({}, ledger, "", "Open") == 0)

-- The plain clock
local recipe = { modData = {}, elapsed = 12 }
function recipe:getModData() return self.modData end
function recipe:setElapsedTime(value) self.elapsed = value end
function recipe:getRecipe() return { getTime = function() return 7200 end } end
Weather.showClock(recipe, "runStartHour", 100)
check("showClock: a run with no start hour is left alone", recipe.elapsed == 12)
Weather.startClock(recipe, "runStartHour", 100)
Weather.showClock(recipe, "runStartHour", 101)
check("showClock: one hour is 3600 seconds", recipe.elapsed == 3600)
Weather.showClock(recipe, "runStartHour", 150)
check("showClock: time away finishes the run, and no further", recipe.elapsed == 7200)

H.installClock(50)
H.installModData()
local made = 0
local function newLedger(now) made = made + 1 return Weather.newLedger(now, kinds) end
local first = Weather.getLedger("Key", newLedger)
check("getLedger: made once, in ModData", Weather.getLedger("Key", newLedger) == first and made == 1 and first.lastHour == 50)
check("getLedger: no climate yet, no reading yet", first.temperature == nil)
local outside, damp = 12, 60
getClimateManager = function()
    return { getTemperature = function() return outside end, getHumidity = function() return damp end }
end
local seeded = Weather.getLedger("Seeded", newLedger)
check("getLedger: a new ledger starts on the weather there is", Weather.placeTemperature(seeded, "Open") == 12
    and Weather.placeTemperature(seeded, "Sheltered") == Weather.shelterTemperature(12))

-- One weather for the series: every mod's ledger copies its season means at each record.
H.installEvents()
local series = Weather.shared()
check("shared: the core's own ModData, read once at the start", H.modData[Weather.SHARED_KEY].ledger == series
    and series.temperature == 12 and series.seasonTemperature == 12 and series.seasonHumidity == 60)
local old = Weather.getLedger("OldMod", newLedger)
local recorded = 0
Weather.record(function(now, climate)
    recorded = recorded + 1
    Weather.advance(old, now, climate:getTemperature(), kinds)
end)
Weather.record(function() recorded = recorded + 1 end)
for hour = 51, 50 + Weather.SEASON_HOURS do
    H.setHours(hour)
    outside = 30
    H.fire("EveryTenMinutes")
end
check("record: every recorder runs at each reading", recorded == 2 * Weather.SEASON_HOURS)
check("shared: the season mean follows the weather", series.temperature == 30 and series.seasonTemperature > 22
    and series.seasonTemperature < 30)
check("a ledger's season mean is the series' own", old.seasonTemperature == series.seasonTemperature)
local late = Weather.getLedger("AddedLater", newLedger)
check("a mod added later agrees with the others from its first day", late.temperature == 30
    and Weather.placeTemperature(late, "Sheltered") == Weather.placeTemperature(old, "Sheltered"))
local own = { lastHour = 0 }
Weather.season(own, "seasonHumidity", 40, 1)
check("season: the series' humidity too", own.seasonHumidity == series.seasonHumidity)
Weather.share(nil)
Weather.season(own, "seasonHumidity", 40, Weather.SEASON_HOURS)
check("season: with no series' weather a ledger grows its own mean", own.seasonHumidity == 40)
getClimateManager = nil

-- Station
local cellSquares = {}
getCell = function()
    return { getGridSquare = function(_, x, y, z) return cellSquares[x .. "," .. y .. "," .. z] end }
end
local function square(x, y, z)
    return { getX = function() return x end, getY = function() return y end, getZ = function() return z end }
end
local function worldObject(sq, index)
    return { square = sq, index = index or 0,
        getSquare = function(self) return self.square end,
        getObjectIndex = function(self) return self.index end }
end
local here = square(1, 2, 0)
cellSquares["1,2,0"] = here
local loaded = worldObject(here)
check("isLoaded: on a square the cell still has", Station.isLoaded(loaded))
local unloaded = worldObject(square(1, 2, 0))
check("isLoaded: not once the cell has let go of its square", not Station.isLoaded(unloaded))
check("isLoaded: not when removed", not Station.isLoaded(worldObject(here, -1)))
check("isLoaded: not without a square", not Station.isLoaded(worldObject(nil)))

H.installEvents()
local loadHandlers = {}
MapObjects = { OnLoadWithSprite = function(name, handler, priority) loadHandlers[name] = { handler, priority } end }
local refreshed = {}
local other = worldObject(square(3, 3, 0))
cellSquares["3,3,0"] = other.square
local tracker
tracker = Station.tracker({
    sprites = { "a_0", "a_1" },
    entry = function() return { made = true } end,
    ticks = 2,
    refresh = function(obj, entry)
        table.insert(refreshed, obj)
        if obj == loaded then tracker.track(other) end
    end,
})
tracker.start()
check("start: registers every sprite with the map loader", loadHandlers.a_0 and loadHandlers.a_1[2] == Station.MAP_PRIORITY)
check("start: hands the loader track", loadHandlers.a_0[1] == tracker.track)
local entry = tracker.track(loaded)
check("track: makes the entry once", entry.made and tracker.track(loaded) == entry and tracker.entry(loaded) == entry)
tracker.track(unloaded)
H.fire("OnTick")
check("onTick: waits its ticks", #refreshed == 0)
H.fire("OnTick")
check("onTick: refreshes the loaded station", #refreshed == 1 and refreshed[1] == loaded)
check("onTick: drops the unloaded one", tracker.entry(unloaded) == nil)
check("onTick: a refresh can track another station", tracker.entry(other) ~= nil)
local refusing = Station.tracker({ sprites = {}, entry = function() return nil end, refresh = function() end })
check("track: an entry of nil leaves the object alone", refusing.track(loaded) == nil and refusing.entry(loaded) == nil)
check("track: the default entry is a table", Station.tracker({ sprites = {}, refresh = function() end }).track(loaded) ~= nil)

local shown = { names = {}, clears = 0 }
local drawn = {
    clearAttachedAnimSprite = function() shown.clears = shown.clears + 1 shown.names = {} end,
    addAttachedAnimSpriteByName = function(_, name) table.insert(shown.names, name) end,
}
local spriteEntry = {}
Station.showSprites(drawn, spriteEntry, "1,2", { "x_1", "x_2" })
check("showSprites: layers in order", shown.names[1] == "x_1" and shown.names[2] == "x_2")
Station.showSprites(drawn, spriteEntry, "1,2", { "x_1", "x_2" })
check("showSprites: leaves an unchanged station alone", shown.clears == 1)
local movable = { modData = {} }
function movable:getModData() return self.modData end
Station.movableData(movable).ml = 5
check("movableData: kept in modData.movableData", movable.modData.movableData.ml == 5)

-- UI
H.installGetText({ T_Time = "%1 d %2 h", T_Soured = "%1 soured", T_None = "plain" })
-- Stand-ins for the requires and the vanilla classes it wraps.
require = function() end
ISWidgetCraftLogicOutputProgress = { updateProgressItems = function(self) self.vanillaRan = true end }
local placed
ISMoveableSpriteProps = { canPlaceMoveable = function() placed = true return true end }
local UI = dofile("42/media/lua/client/TraditionalPreservationCore/UI.lua")
check("say: values go in after the translator", UI.say("T_Soured", UI.percent(0.4)) == "40% soured" and #H.textWarnings == 0)
check("say: a text with no values", UI.say("T_None") == "plain")
check("timeText: rounds up to the hour", UI.timeText(25.2, "T_Time") == "1 d 2 h")
check("timeText: whole days", UI.timeText(48, "T_Time") == "2 d 0 h")

local function slot(name)
    local recipe = name and { getName = function() return "Mod." .. name end }
    return { craftRecipeData = { getRecipe = function() return recipe end } }
end
local seen = {}
UI.onProgressSlot(function(s, name) table.insert(seen, tostring(name)) end)
local drew
UI.progressTooltips({ Ferment = function(s, tooltip, name, entity) drew = { name, entity } end })
local slots = { slot("Ferment"), slot("Other"), slot(nil) }
local widget = { entity = "shelf", progressItems = { getItemSlots = function() return slots end } }
ISWidgetCraftLogicOutputProgress.updateProgressItems(widget)
check("progress hook: runs vanilla first", widget.vanillaRan)
check("progress hook: every slot, by short name", table.concat(seen, ",") == "Ferment,Other,nil")
check("progressTooltips: only the named recipe", slots[1].drawTooltip and not slots[2].drawTooltip and not slots[3].drawTooltip)
slots[1].drawTooltip(slots[1], {})
check("progressTooltips: draws with the name and station", drew[1] == "Ferment" and drew[2] == "shelf")

UI.outdoorOnly({ beam_0 = true })
local inside = { isOutside = function() return false end }
check("outdoorOnly: refuses an indoor square", ISMoveableSpriteProps.canPlaceMoveable({ spriteName = "beam_0" }, nil, inside) == false and not placed)
check("outdoorOnly: other sprites go to vanilla", ISMoveableSpriteProps.canPlaceMoveable({ spriteName = "cask_0" }, nil, inside) and placed)

-- offAppliances: an object is instanceof its .class; containers by type.
instanceof = function(object, class) return object.class == class end
local function thing(class, ...)
    local types = { ... }
    return { class = class, getContainerCount = function() return #types end,
             getContainerByIndex = function(_, i) return { getType = function() return types[i + 1] end } end }
end
local function squareWith(...)
    local list = { ... }
    return { isOutside = function() return true end,
             getObjects = function() return { size = function() return #list end, get = function(_, i) return list[i + 1] end } end }
end
UI.offAppliances({ crock_2 = true })
local crock = { spriteName = "crock_2" }
for _, case in ipairs({
    { "a stove", thing("IsoStove") },
    { "a chest freezer", thing("IsoObject", "freezer") },
    { "a fridge-freezer", thing("IsoObject", "fridge", "freezer") },
    { "a washer", thing("IsoClothingWasher") },
}) do
    placed = false
    check("offAppliances: refuses " .. case[1], ISMoveableSpriteProps.canPlaceMoveable(crock, nil, squareWith(thing("IsoObject"), case[2])) == false and not placed)
end
placed = false
check("offAppliances: a counter with drawers goes to vanilla", ISMoveableSpriteProps.canPlaceMoveable(crock, nil, squareWith(thing("IsoObject", "counter"))) and placed)
placed = false
check("offAppliances: other sprites go to vanilla", ISMoveableSpriteProps.canPlaceMoveable({ spriteName = "cask_0" }, nil, squareWith(thing("IsoStove"))) and placed)

-- slotRules, twice as two mods would: each mod's stations go to its own rules, the rest on to vanilla.
ResourceIO = { Input = "in", Output = "out" }
local vanillaAdds, vanillaUps, halos, queuedActions = 0, 0, {}, {}
ISCraftLogicPanel = { ItemSlotAddItems = function() vanillaAdds = vanillaAdds + 1 end }
ISItemSlot = { defaultVerifyItem = function() return true end, onMouseUp = function() vanillaUps = vanillaUps + 1 end }
HaloTextHelper = { addBadText = function(_, text) table.insert(halos, text) end }
ISEntityUI = { WalkToEntity = function() return true end }
ISItemSlotAddAction = { new = function(_, _, _, item) return { item = item } end }
instanceof = function(object, class) return class == "IsoObject" and not object.isItem end
ISTimedActionQueue = { add = function(action) table.insert(queuedActions, action) end }
ISMouseDrag = {}
ISInventoryPane = { getActualItems = function(dragging) return dragging end }
function getPlayer() return "player" end
local function station(name, free)
    local entity = { name = name, component = { free = free } }
    local resource = { getIO = function() return ResourceIO.Input end, getGameEntity = function() return entity end }
    return { resource = resource }, entity
end
local tracked = {}
local function rulesFor(name, refusalKey)
    UI.slotRules{
        station = function(entity) if entity and entity.name == name then return entity.component, name end end,
        refusal = function(s, item, queued)
            if item == "wrong" then return refusalKey end
            if #queued >= s.component.free then return "T_Full" end
        end,
        added = function(entity) tracked[entity] = true end,
    }
end
rulesFor("cask", "T_NotCask")
rulesFor("shelf", "T_NotShelf")
local caskSlot, cask = station("cask", 2)
ISCraftLogicPanel.ItemSlotAddItems("player", cask, caskSlot, { "a", "b", "c" }, cask.component)
check("slotRules: adds until the refusal, then says why", #queuedActions == 2 and halos[1] == getText("T_Full") and tracked[cask])
check("slotRules: each queued action asks again", queuedActions[1].tpSlot.extra == "cask" and queuedActions[1].canAddItem(queuedActions[1]))
halos, queuedActions = {}, {}
local shelfSlot, shelf = station("shelf", 5)
ISCraftLogicPanel.ItemSlotAddItems("player", shelf, shelfSlot, { "wrong" }, shelf.component)
check("slotRules: the other mod's station gets its own rules", #queuedActions == 0 and halos[1] == getText("T_NotShelf"))
local otherSlot, other = station("barrel", 5)
ISCraftLogicPanel.ItemSlotAddItems("player", other, otherSlot, { "a" }, {})
check("slotRules: anything else goes to vanilla", vanillaAdds == 1)
local itemSlot, craftedItem = station("cask", 2)
craftedItem.isItem = true
ISCraftLogicPanel.ItemSlotAddItems("player", craftedItem, itemSlot, { "a" }, {})
check("slotRules: an item that crafts is never asked for a sprite", vanillaAdds == 2 and #queuedActions == 0)
check("slotRules: green border follows the refusal", ISItemSlot.defaultVerifyItem({}, caskSlot, "a") and not ISItemSlot.defaultVerifyItem({}, caskSlot, "wrong"))
local outSlot = station("cask", 2)
outSlot.resource.getIO = function() return ResourceIO.Output end
check("slotRules: output slots are left alone", ISItemSlot.defaultVerifyItem({}, outSlot, "wrong"))
halos = {}
ISMouseDrag.dragging = { "wrong" }
ISItemSlot.onMouseUp(caskSlot, 0, 0)
check("slotRules: a refused drop says why, and vanilla still runs", halos[1] == getText("T_NotCask") and vanillaUps == 1)
halos = {}
ISMouseDrag.dragging = { "wrong", "a" }
ISItemSlot.onMouseUp(caskSlot, 0, 0)
check("slotRules: a drag that can partly go in says nothing", #halos == 0 and vanillaUps == 2)
ISMouseDrag.dragging = nil

-- Yeast, Fish and Vinegar were checked here against their old code when each moved onto the core (2026-11-09).
-- Their golden outputs and their own tests keep them in step now.

H.done()
