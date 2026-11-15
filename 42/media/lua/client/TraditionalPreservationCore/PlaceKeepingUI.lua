-- Traditional Preservation core: looks at the items a PlaceKeeping keeper keeps, so they catch up on their keeping:
-- the player's own things every hour, any container as soon as the inventory windows show it, and an item as it is
-- moved, while it is still where it was, so its time there counts at that place.
--   PlaceKeepingUI.watch(keeper, types)   types: { [fullType] = true }
-- A mod whose own look already goes through its containers (Fish & Meat's, for its fish) keeps its items there.
local Transfer = require "TraditionalPreservationCore/Transfer"

local PlaceKeepingUI = {}

local watched = {}

local function keeperOf(item)
    local fullType = item:getFullType()
    for _, entry in ipairs(watched) do
        if entry.types[fullType] then return entry.keeper end
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

function PlaceKeepingUI.watch(keeper, types)
    install()
    table.insert(watched, { keeper = keeper, types = types })
end

return PlaceKeepingUI
