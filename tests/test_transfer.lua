-- Checks Transfer (the one wrap of vanilla's transferItem) on a stand-in for the engine. Run from
-- TraditionalPreservationCore: luajit tests/test_transfer.lua
local H = dofile("tests/harness.lua")
local check = H.check
package.path = "42/media/lua/client/?.lua;" .. package.path
package.preload["TimedActions/ISInventoryTransferAction"] = function() return true end

local seen = {}
ISInventoryTransferAction = {}
function ISInventoryTransferAction:transferItem(item)
    table.insert(seen, "vanilla " .. tostring(item))
    return "moved"
end

local Transfer = require "TraditionalPreservationCore/Transfer"
Transfer.before(function(action, item) table.insert(seen, "first before " .. item .. " from " .. action.srcContainer) end)
Transfer.before(function(_, item) table.insert(seen, "second before " .. item) end)
Transfer.after(function(_, item) table.insert(seen, "after " .. item) end)

local action = setmetatable({ srcContainer = "stove" }, { __index = ISInventoryTransferAction })
check("vanilla's result is passed back", action:transferItem("pot") == "moved")
check("befores in order, then vanilla, then afters", table.concat(seen, "|")
    == "first before pot from stove|second before pot|vanilla pot|after pot")

seen = {}
action:transferItem(nil)
check("no item, no handlers", table.concat(seen, "|") == "vanilla nil")

Transfer.after(function() end)
seen = {}
action:transferItem("jar")
check("adding a handler later doesn't wrap twice", #seen == 4)
H.done()
