-- Checks Uses (salt, vinegar by the use from what a character carries) and Recipes.cookOutputs outside the game.
-- Run from TraditionalPreservationCore: luajit tests/test_uses.lua
local H = dofile("tests/harness.lua")
local check = H.check
H.useModPaths()

ItemTag = { SALT = "base:salt", VINEGAR = "base:vinegar" }
instanceof = function(o, class) return type(o) == "table" and o.class == class end
ArrayList = { new = function()
    local list = { items = {} }
    function list:add(item) table.insert(self.items, item) end
    function list:size() return #self.items end
    function list:get(i) return self.items[i + 1] end
    return list
end }

local Uses = require "TraditionalPreservationCore/Uses"
local Recipes = require "TraditionalPreservationCore/Recipes"

local function thing(tag, uses)
    local o = { tag = tag, uses = uses }
    function o:getCurrentUses() return self.uses end
    function o:setCurrentUses(n) self.uses = n end
    function o:getContainer() return { DoRemoveItem = function() o.removed = true end } end
    return o
end
local function carrying(items)
    return { getInventory = function()
        return { getAllTagRecurse = function(_, tag, list)
            for _, item in ipairs(items) do if item.tag == tag then list:add(item) end end
            return list
        end }
    end }
end

local full, part, empty = thing("base:salt", 10), thing("base:salt", 2), thing("base:salt", 0)
local vinegar = thing("base:vinegar", 10)
local who = carrying({ full, part, empty, vinegar })
check("count adds the tag's uses, empty ones none", Uses.count(who, "base:salt") == 12 and Uses.count(who, "base:vinegar") == 10)
Uses.take(who, "base:salt", 3)
check("take empties the part-used one first", part.uses == 0 and part.removed and full.uses == 9 and not full.removed)
local returned
TraditionalPreservationSalt = { returnEmpties = function(_, list) returned = list:size() end }
local shaker = thing("base:salt", 1)
Uses.take(carrying({ shaker }), "base:salt", 1)
check("an emptied salt goes back to the Salt mod", returned == 1)
returned = nil
Uses.take(carrying({ thing("base:vinegar", 1) }), "base:vinegar", 1)
check("other emptied things don't", returned == nil)
Uses.take(nil, "base:salt", 1)
check("no character, nothing taken", true)

local made = {}
for i = 1, 2 do
    made[i] = { class = "Food", cookable = i == 1 }
    made[i].isCookable = function(self) return self.cookable end
    made[i].setCooked = function(self, on) self.cooked = on end
end
Recipes.cookOutputs({ getAllCreatedItems = function() return H.list(made) end })
check("cookOutputs: cookable food comes out cooked, the rest left alone", made[1].cooked and not made[2].cooked)
check("scripts reach it as TraditionalPreservationCore.OnCreateCooked", TraditionalPreservationCore.OnCreateCooked == Recipes.cookOutputs)

-- OnHeat: minutes counted only while seen hot from one look to the next; fn once.
local OnHeat = require "TraditionalPreservationCore/OnHeat"
local link = { md = {} }
function link:getModData() return self.md end
local fired = 0
local watch = { minutes = 5, fn = function() fired = fired + 1 end }
for minute = 0, 3 do OnHeat.note(link, watch, minute / 60, true) end
check("3 minutes hot: not yet", fired == 0 and math.abs(link.md.tpOnHeat.minutes - 3) < 1e-6)
OnHeat.note(link, watch, 30 / 60, true)
check("back on the heat after a long gap: the gap doesn't count", fired == 0 and math.abs(link.md.tpOnHeat.minutes - 3) < 1e-6)
for minute = 31, 32 do OnHeat.note(link, watch, minute / 60, true) end
check("5 minutes in all: fn runs", fired == 1 and link.md.tpOnHeat.done)
OnHeat.note(link, watch, 33 / 60, true)
check("and only once", fired == 1)
local cooled = { md = {} }
function cooled:getModData() return self.md end
OnHeat.note(cooled, watch, 0, true)
OnHeat.note(cooled, watch, 1 / 60, false)
OnHeat.note(cooled, watch, 2 / 60, true)
check("a look off the heat stops the count", cooled.md.tpOnHeat.minutes == 0)

-- Charge: one line, a different amount of each kind.
local Charge = require "TraditionalPreservationCore/Charge"
local function food(fullType, uses)
    local o = { fullType = fullType, uses = uses }
    function o:getFullType() return self.fullType end
    function o:getCurrentUses() return self.uses end
    function o:setCurrentUses(n) self.uses = n end
    function o:getContainer() return { DoRemoveItem = function() o.removed = true end } end
    return o
end
local function pantry(items)
    local function ofType(fullType)
        local list = ArrayList.new()
        for _, item in ipairs(items) do if item.fullType == fullType and not item.removed then list:add(item) end end
        return list
    end
    return { getInventory = function() return { getAllTypeRecurse = function(_, t) return ofType(t) end } end }
end
local filler = Charge.line({ ["Base.OatsRaw"] = { uses = 12 }, ["Base.BarleySeed"] = { count = 12 } })
local oats = food("Base.OatsRaw", 10)
local grains = {}
for i = 1, 13 do grains[i] = food("Base.BarleySeed", 5) end
local cook = pantry({ oats, unpack(grains) })
check("10 uses of oats are not enough", not filler.onTest(oats, cook))
check("13 grains are", filler.onTest(grains[1], cook) and filler.has(cook, "Base.BarleySeed") == 13)
check("other items pass", filler.onTest(food("Base.Lard", 24), cook))
filler.take({ getAllKeepInputItems = function() return H.list({ grains[1] }) end }, cook)
check("take: 12 grains go, one stays", filler.has(cook, "Base.BarleySeed") == 1)
local more = food("Base.OatsRaw", 5)
local cook2 = pantry({ oats, more })
filler.take({ getAllKeepInputItems = function() return H.list({ oats }) end }, cook2)
check("take: 12 uses of oats, the part-used bag first", more.removed and oats.uses == 3)
check("the line is found by its item list", Charge.forScriptLine("item 1 [Base.BarleySeed;Base.OatsRaw] mode:keep") == filler
    and filler.need("Base.OatsRaw") == 12 and Charge.forScriptLine("item 1 [Base.OatsRaw] mode:keep") == nil)

-- Station.onHeatNear: one look a minute near each player, each watcher told of the containers at its heat or hotter.
local Station = require "TraditionalPreservationCore/Station"
H.installEvents()
H.installClock(10)
isServer = function() return false end
isClient = function() return false end
local function hotContainer(temperature, items)
    return { getTemperature = function() return temperature end,
        getAllTypeRecurse = function(_, fullType) return H.list(items and items[fullType] or {}) end }
end
local hotLink = { md = {} }
function hotLink:getModData() return self.md end
function hotLink:getItemHeat() return OnHeat.HEAT end
local stove = hotContainer(math.max(OnHeat.HEAT, 2), { ["T.Link"] = { hotLink } })
local warm = hotContainer(1.5)
local cold = hotContainer(1.0)
local objects = {}
for _, container in ipairs({ stove, warm, cold }) do
    table.insert(objects, { getContainerCount = function() return 1 end, getContainerByIndex = function() return container end })
end
local stoveSquare = { getObjects = function() return H.list(objects) end }
getCell = function()
    return { getGridSquare = function(_, x, y) return (x == 2 and y == 0) and stoveSquare or nil end }
end
local cook = H.player()
getNumActivePlayers = function() return 1 end
getSpecificPlayer = function() return cook end
local everyone = {}
Station.eachPlayer(function(player) table.insert(everyone, player) end)
check("eachPlayer: the local players", #everyone == 1 and everyone[1] == cook)
local seen, scaldHeat = {}, nil
Station.onHeatNear(1.4, function(container, now) table.insert(seen, { low = container, now = now }) end)
Station.onHeatNear(function() return scaldHeat end, function(container) table.insert(seen, { high = container }) end)
check("one minute look, however many watch", #H.handlers.EveryOneMinute == 1)
H.fire("EveryOneMinute")
check("a watcher with no heat this minute is skipped; the other sees what is hot enough, with the hour",
    #seen == 2 and seen[1].low == stove and seen[1].now == 10 and seen[2].low == warm)
seen, scaldHeat = {}, 1.8
H.fire("EveryOneMinute")
local highs = 0
for _, entry in ipairs(seen) do if entry.high then highs = highs + 1 end end
check("each watcher by its own heat", #seen == 3 and highs == 1)
OnHeat.watch("T.Link", 2, function(item) item.fried = true end)
check("OnHeat looks through the same minute", #H.handlers.EveryOneMinute == 1)
for minute = 1, 4 do
    H.setHours(10 + minute / 60)
    H.fire("EveryOneMinute")
end
check("a link kept hot near the player is done", hotLink.fried and hotLink.md.tpOnHeat.done)
check("watch checks what it is given", not pcall(OnHeat.watch, "T.Other", 0, function() end))

-- Recipes.researchable: says so when the item isn't there.
local doParams = {}
ScriptManager = { instance = { getItem = function(_, fullType)
    if fullType == "T.Pot" then return { DoParam = function(_, line) table.insert(doParams, line) end } end
end } }
local printed = {}
local realPrint = print
print = function(line) table.insert(printed, line) end
local found, missing = Recipes.researchable("T.Pot", "T.MakePot", "T"), Recipes.researchable("T.None", "T.MakePot", "T")
print = realPrint
check("researchable: a found item takes the recipe", found and doParams[1] == "ResearchableRecipes = T.MakePot")
check("a missing one is reported", missing == false and printed[1] == "[T] Could not find T.None")

-- Season.register: checks what it is given, and finds a seasoning's kind by one lookup.
local Season = require "TraditionalPreservationCore/Season"
local herbs = { name = "herbs", types = { "T.Thyme", "T.Sage" } }
local spec = { kinds = { herbs, { name = "pepper", types = { "T.Pepper" }, uses = 2 } }, unhappy = -2 }
Season.register({ "T.Link" }, spec)
check("Season: a seasoning's kind", Season.kindOf(spec, "T.Sage") == herbs and Season.kindOf(spec, "T.Salt") == nil)
check("a food registered again keeps working", pcall(Season.register, { "T.Link" }, spec))
local ok, err = pcall(Season.register, { "T.Other" }, { kinds = { herbs, { name = "more", types = { "T.Sage" } } }, unhappy = -2 })
check("a seasoning in two kinds is refused, by name", not ok and err:find("T.Sage is in kinds herbs and more", 1, true))
check("no unhappy, or no kinds: refused", not pcall(Season.register, { "T.Other" }, { kinds = { herbs } })
    and not pcall(Season.register, { "T.Other" }, { kinds = {}, unhappy = -2 }))

H.done()
