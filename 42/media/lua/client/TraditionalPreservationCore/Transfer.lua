-- Traditional Preservation core: the one wrap of vanilla's ISInventoryTransferAction.transferItem, which moves an
-- item from one container to another (dragging, the loot window, Put in, taking a pot off a stove). Every TP mod
-- adds a handler here instead of wrapping it again, so there is one place to compare with vanilla after a game update.
--   Transfer.before(fn)  fn(action, item) while the item is still where it was (action.srcContainer, .destContainer)
--   Transfer.after(fn)   fn(action, item) once vanilla has moved it
-- Handlers run in the order they were added. Outside the game (tests) there may be no transfer action: then nothing
-- is wrapped.
require "TimedActions/ISInventoryTransferAction"

local Transfer = {}

local befores, afters = {}, {}
local installed = false

local function install()
    if installed or not ISInventoryTransferAction then return end
    installed = true
    local vanillaTransferItem = ISInventoryTransferAction.transferItem
    function ISInventoryTransferAction:transferItem(item)
        if item then
            for _, fn in ipairs(befores) do fn(self, item) end
        end
        local result = vanillaTransferItem(self, item)
        if item then
            for _, fn in ipairs(afters) do fn(self, item) end
        end
        return result
    end
end

function Transfer.before(fn)
    install()
    table.insert(befores, fn)
end

function Transfer.after(fn)
    install()
    table.insert(afters, fn)
end

return Transfer
