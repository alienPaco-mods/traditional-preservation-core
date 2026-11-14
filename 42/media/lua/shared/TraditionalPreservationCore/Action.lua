-- Traditional Preservation core: what every mod's timed actions share. How long a pour takes, the debug cheat that
-- makes timed actions instant (an action only honours it if its getDuration asks), and a kit's items, tool and xp
-- (Fit and Connect at the Stone Hearth). A kit's items are { { full type, count } }, its xp { perk name, amount }.
local Action = {}

Action.POUR_BASE = 40
Action.POUR_PER_LITRE = 12

-- ticks, or 1 with the instant-actions cheat on.
function Action.duration(character, ticks)
    if character:isTimedActionInstant() then return 1 end
    return ticks
end

-- Moving litres of a fluid by hand or hose. Past mostLitres it takes no longer.
function Action.pourDuration(character, litres, mostLitres)
    return Action.duration(character, Action.POUR_BASE + math.floor(math.min(litres, mostLitres) * Action.POUR_PER_LITRE))
end

-- Whether the character carries a tool with the ItemTag of that name, in a bag or not.
function Action.hasTool(character, tag)
    return character:getInventory():containsTagRecurse(ItemTag[tag])
end

-- The items a kit needs, all from the main inventory (a menu brings them there first), or nil if any are missing.
function Action.kitItems(character, needs)
    local inventory = character:getInventory()
    local items = {}
    for _, need in ipairs(needs) do
        local found = inventory:getSomeType(need[1], need[2], ArrayList.new())
        if found:size() < need[2] then return nil end
        for i = 0, need[2] - 1 do table.insert(items, found:get(i)) end
    end
    return items
end

function Action.takeItems(character, items)
    local inventory = character:getInventory()
    for _, item in ipairs(items) do inventory:Remove(item) end
end

function Action.giveItems(character, needs)
    local inventory = character:getInventory()
    for _, need in ipairs(needs) do
        for _ = 1, need[2] do inventory:AddItem(need[1]) end
    end
end

-- Takes an item out of whatever holds it (the inventory or a bag in it); nothing if it is held by nothing.
function Action.removeItem(item)
    local container = item:getContainer()
    if container then container:DoRemoveItem(item) end
end

-- xp is { perk name, amount }, or nil for none.
function Action.addXp(character, xp)
    if xp and Perks[xp[1]] then character:getXp():AddXP(Perks[xp[1]], xp[2]) end
end

return Action
