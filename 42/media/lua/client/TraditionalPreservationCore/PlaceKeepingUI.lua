-- Traditional Preservation core: looks at the items a PlaceKeeping keeper keeps, so they catch up on their keeping:
-- the player's own things every hour, any container as soon as the inventory windows show it, and an item as it is
-- moved, while it is still where it was, so its time there counts at that place.
--   PlaceKeepingUI.watch(keeper, types)   types: { [fullType] = true }
--   PlaceKeepingUI.near(types, reach)     the consoles' list: such items carried and in containers within reach
-- A mod whose own look already goes through its containers (Fish & Meat's, for its fish) keeps its items there.
local Transfer = require "TraditionalPreservationCore/Transfer"

local PlaceKeepingUI = {}

local watched = {}

local function keeperOf(item)
    local fullType = item:getFullType()
    for _, watch in ipairs(watched) do
        if watch.types[fullType] then return watch.keeper end
    end
end

local function isKept(item)
    return keeperOf(item) ~= nil
end

function PlaceKeepingUI.lookIn(container)
    if not container or #watched == 0 then return end
    local items = container:getAllEvalRecurse(isKept)
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        keeperOf(item).keep(item)
    end
end

local installed = false

local function install()
    if installed then return end
    installed = true
    Events.EveryHours.Add(function()
        for i = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(i)
            if player then PlaceKeepingUI.lookIn(player:getInventory()) end
        end
    end)
    Events.OnRefreshInventoryWindowContainers.Add(function(page, reason)
        if reason ~= "end" then return end
        for _, button in ipairs(page.backpacks or {}) do PlaceKeepingUI.lookIn(button.inventory) end
    end)
    Transfer.before(function(_, item)
        local keeper = keeperOf(item)
        if keeper then keeper.keep(item) end
    end)
end

-- Items of types (a set keyed by full type, as watch takes) the player carries, then those in containers (a fridge, a crate, a counter)
-- within reach tiles on the player's floor, as a list: what a console describes and ages.
PlaceKeepingUI.REACH = 4
function PlaceKeepingUI.near(types, reach)
    reach = reach or PlaceKeepingUI.REACH
    local player, found = getPlayer(), {}
    local function wanted(item) return types[item:getFullType()] ~= nil end
    local function add(container)
        local items = container and container:getAllEvalRecurse(wanted)
        for i = 0, items and items:size() - 1 or -1 do table.insert(found, items:get(i)) end
    end
    add(player:getInventory())
    local cell, x, y, z = getCell(), player:getX(), player:getY(), player:getZ()
    for dx = -reach, reach do
        for dy = -reach, reach do
            local square = cell:getGridSquare(x + dx, y + dy, z)
            local isoObjects = square and square:getObjects()
            for i = 0, isoObjects and isoObjects:size() - 1 or -1 do
                local isoObject = isoObjects:get(i)
                for c = 0, isoObject:getContainerCount() - 1 do add(isoObject:getContainerByIndex(c)) end
            end
        end
    end
    return found
end

function PlaceKeepingUI.watch(keeper, types)
    install()
    table.insert(watched, { keeper = keeper, types = types })
end

return PlaceKeepingUI
