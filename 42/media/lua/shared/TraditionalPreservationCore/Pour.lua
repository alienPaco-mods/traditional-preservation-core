-- Traditional Preservation core: the one wrap of vanilla's ISFluidTransferAction (a pour between two fluid
-- containers: start, stop and complete). What rides along with a fluid (its age: the core's FluidAgeing; its heat:
-- Dairy's milk) is read as the pour starts and written as it ends, so every mod adds a handler here instead of
-- wrapping the action again: one place to compare with vanilla after a game update.
--   Pour.before(name, fn)  fn(action) before vanilla's start, stop or complete (name)
--   Pour.after(name, fn)   fn(action) after it
-- Handlers run as nested wraps would: of the befores the last added runs first, of the afters the first added.
-- Pour.owner(fluidObject) is the item or world object a pour's source or target belongs to.
-- Wrapped through Wrap (late, guarded).
require "Fluids/ISFluidTransferAction"
local Wrap = require "TraditionalPreservationCore/Wrap"

local Pour = {}

local NAMES = { "start", "stop", "complete" }
local befores, afters = { start = {}, stop = {}, complete = {} }, { start = {}, stop = {}, complete = {} }
local installed = false

local function wrap(name)
    Wrap.method("ISFluidTransferAction", name, function(vanilla, self, ...)
        local first = befores[name]
        for index = #first, 1, -1 do first[index](self) end
        local result = vanilla(self, ...)
        for _, fn in ipairs(afters[name]) do fn(self) end
        return result
    end)
end

local function install()
    if installed then return end
    installed = true
    for _, name in ipairs(NAMES) do wrap(name) end
end

-- A handler for an action name Pour doesn't wrap is a mistake: say which.
local function checkName(name)
    assert(befores[name], "Pour: no action called " .. tostring(name) .. " (start, stop or complete)")
end

function Pour.before(name, fn)
    checkName(name)
    install()
    table.insert(befores[name], fn)
end

function Pour.after(name, fn)
    checkName(name)
    install()
    table.insert(afters[name], fn)
end

-- The item or world object that owns one end of a pour (action.source, action.target), or nil.
function Pour.owner(fluidObject)
    local owner = fluidObject and fluidObject:getOwner()
    if instanceof(owner, "InventoryItem") or instanceof(owner, "IsoObject") then return owner end
end

return Pour
