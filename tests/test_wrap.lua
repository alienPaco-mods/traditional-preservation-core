-- Checks Wrap: wraps go in late (OnGameStart, OnGameBoot on a dedicated server), a failing handler never stops
-- vanilla, and debug mode raises the error. Run from TraditionalPreservationCore: luajit tests/test_wrap.lua
local H = dofile("tests/harness.lua")
local check = H.check
package.path = "42/media/lua/shared/?.lua;" .. package.path
TPCoreTesting = nil
H.installEvents()
function isServer() return false end
local debug = false
function isDebugEnabled() return debug end
local printed = {}
local realPrint = print
-- Runs fn with print caught in `printed`.
local function quietly(fn, ...)
    print = function(line) table.insert(printed, line) end
    local results = { pcall(fn, ...) }
    print = realPrint
    return unpack(results)
end
local Wrap = require "TraditionalPreservationCore/Wrap"

-- Late
Tool = { name = "vanilla" }
function Tool.use(self, x) return self.name .. " " .. x end
Wrap.method("Tool", "use", function(vanilla, self, x) return "tp(" .. vanilla(self, x) .. ")" end)
check("nothing is wrapped as files load", Tool:use("a") == "vanilla a" and not Wrap.applied("Tool", "use"))
function Tool.use(self, x) return "other mod " .. x end
H.fire("OnGameStart")
check("on game start it wraps what is there then, another mod's replacement too", Tool:use("a") == "tp(other mod a)")
check("and says so", Wrap.applied("Tool", "use"))
Wrap.method("Tool", "count", function(vanilla) return vanilla() end)
check("a function the game hasn't got is skipped", not Wrap.applied("Tool", "count"))
Tool.late = function() return 1 end
Wrap.method("Tool", "late", function(vanilla) return vanilla() + 1 end)
check("a wrap added after the start goes in at once", Tool.late() == 2)
Wrap.method("Tool", "use", function(vanilla, self, x) return "reloaded(" .. vanilla(self, x) .. ")" end)
check("registering it again replaces the handler, as a reloaded file does, without wrapping twice", Tool:use("a") == "reloaded(other mod a)")

-- Guarded
local runs = 0
Bag = {}
function Bag.put(a, b) runs = runs + 1 return a + b, "two" end
local fail = "before"
Wrap.method("Bag", "put", function(vanilla, a, b)
    if fail == "before" then error("tp broke before") end
    local sum, word = vanilla(a, b)
    if fail == "after" then error("tp broke after") end
    return sum * 10, word
end)
local _, sum, word = quietly(Bag.put, 1, 2)
check("a handler failing before vanilla: vanilla still runs, every result passed back", sum == 3 and word == "two" and runs == 1)
check("the error is printed once", #printed == 1 and printed[1]:find("Bag.put", 1, true) and printed[1]:find("tp broke before", 1, true))
quietly(Bag.put, 1, 2)
check("not again", #printed == 1)
fail = "after"
runs = 0
_, sum = quietly(Bag.put, 1, 2)
check("failing after vanilla: vanilla's result, vanilla not run twice", sum == 3 and runs == 1)
fail = nil
check("a handler that works changes the result", Bag.put(1, 2) == 30)

-- Vanilla's own error is vanilla's
Pot = {}
function Pot.boil() error("vanilla broke") end
Wrap.method("Pot", "boil", function(vanilla) return vanilla() end)
local ok, err = pcall(Pot.boil)
check("an error in vanilla is raised as it is, where it happened", not ok and err:find("test_wrap.lua:%d+: vanilla broke$") ~= nil)

-- Debug mode runs bare
debug = true
fail = "before"
runs = 0
ok, err = pcall(Bag.put, 1, 2)
check("in debug mode the error is raised where it happened", not ok and tostring(err):find("test_wrap.lua:%d+: tp broke before"))
check("nothing caught it: vanilla didn't run after it", runs == 0)
fail = nil
check("a working handler is the same in debug mode", Bag.put(1, 2) == 30)
debug = false

-- A dedicated server wraps on OnGameBoot
package.loaded["TraditionalPreservationCore/Wrap"] = nil
H.installEvents()
function isServer() return true end
local ServerWrap = require "TraditionalPreservationCore/Wrap"
Milk = { take = function() return "milk" end }
ServerWrap.method("Milk", "take", function(vanilla) return "tp " .. vanilla() end)
H.fire("OnGameStart")
check("a server has no game start", Milk.take() == "milk")
H.fire("OnGameBoot")
check("it wraps on boot, after all its Lua has loaded", Milk.take() == "tp milk")

H.done()
