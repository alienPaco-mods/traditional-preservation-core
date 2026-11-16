-- Traditional Preservation core: things used by the use from what is in a character's reach, as a craft sees it
-- (inventory, bags, and the containers and floor round them): salt, vinegar,
-- anything tagged whose uses are hunger points (food: Food.getCurrentUses is |HungChange| x 100) or a drainable's.
-- A recipe line takes its own uses; a mod that charges more than that (Fish & Meat's salt by the fish's weight, a
-- cure by the litre) counts and takes the rest here.
local Action = require "TraditionalPreservationCore/Action"
local Uses = {}

-- Everything in reach, as a craft has it: the player's inventory and bags and the containers and floor round them
-- (vanilla's ISInventoryPaneContextMenu.getContainers, which lists each bag once). Outside the game's UI (a server,
-- tests) only the player's inventory, bags included. Returns a list of { container, recurse }.
local function reach(character)
    local menu = ISInventoryPaneContextMenu
    local list = menu and menu.getContainers and character.getPlayerNum and menu.getContainers(character)
    if not list then return { { character:getInventory(), true } } end
    local found = {}
    for i = 0, list:size() - 1 do table.insert(found, { list:get(i), false }) end
    return found
end

-- Takes an item away wherever it is: an item lying on the floor goes from its square too.
local function remove(item)
    local world = item:getWorldItem()
    if world and world:getSquare() then
        -- As vanilla's transfer takes an item off the floor.
        world:getSquare():transmitRemoveItemFromSquare(world)
        world:getSquare():removeWorldObject(world)
        item:setWorldItem(nil)
    end
    Action.removeItem(item)
end
Uses.remove = remove

-- Every item with the tag (or, byType, of the full type) in reach.
local function inReach(character, tag, byType)
    local all = {}
    for _, reachable in ipairs(reach(character)) do
        local container, recurse = reachable[1], reachable[2]
        local found
        if byType then
            found = recurse and container:getAllTypeRecurse(tag) or container:getAllType(tag)
        else
            found = recurse and container:getAllTagRecurse(tag, ArrayList.new()) or container:getAllTag(tag, ArrayList.new())
        end
        for i = 0, found:size() - 1 do table.insert(all, found:get(i)) end
    end
    return all
end

-- The items with the tag (or, byType, of the full type) in reach that have uses left.
function Uses.carried(character, tag, byType)
    local items = {}
    for _, item in ipairs(inReach(character, tag, byType)) do
        if item:getCurrentUses() > 0 then table.insert(items, item) end
    end
    return items
end

-- The uses of the tag (or the full type) in reach in all.
function Uses.count(character, tag, byType)
    local uses = 0
    for _, item in ipairs(Uses.carried(character, tag, byType)) do uses = uses + item:getCurrentUses() end
    return uses
end

-- What runs when Uses.take empties items of a tag: fn(character, emptied), emptied a Java list. A mod that gives
-- something back for an emptied item registers here (Salt: an empty shaker or paper bag, as for what a recipe
-- empties). Only for a take by tag, not by full type.
local onEmptied = {}

function Uses.onEmptied(tag, fn)
    assert(tag ~= nil, "Uses.onEmptied: no tag")
    assert(type(fn) == "function", "Uses.onEmptied " .. tostring(tag) .. ": fn must be a function")
    onEmptied[tag] = onEmptied[tag] or {}
    table.insert(onEmptied[tag], fn)
end

-- Takes owed uses of the tag, part-used items first; an item emptied goes, and the tag's onEmptied handlers get it.
function Uses.take(character, tag, owed, byType)
    if owed <= 0 or not character then return end
    local items = Uses.carried(character, tag, byType)
    table.sort(items, function(a, b) return a:getCurrentUses() < b:getCurrentUses() end)
    local emptied = ArrayList.new()
    for _, item in ipairs(items) do
        if owed <= 0 then break end
        local uses = item:getCurrentUses()
        local taken = math.min(uses, owed)
        owed = owed - taken
        item:setCurrentUses(uses - taken)
        if taken == uses then
            remove(item)
            emptied:add(item)
        end
    end
    local handlers = not byType and emptied:size() > 0 and onEmptied[tag]
    for _, fn in ipairs(handlers or {}) do fn(character, emptied) end
end

-- How many items of a full type are in reach.
function Uses.items(character, fullType)
    return #inReach(character, fullType, true)
end

-- Takes count items of a full type from what is in reach.
function Uses.takeItems(character, fullType, count)
    if count <= 0 or not character then return end
    local found = inReach(character, fullType, true)
    for i = 1, math.min(count, #found) do
        remove(found[i])
    end
end

return Uses
