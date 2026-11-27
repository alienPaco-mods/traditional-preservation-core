-- Traditional Preservation core: what every mod's timed actions share. How long a pour takes, the debug cheat that
-- makes timed actions instant (an action only honours it if its getDuration asks), and a kit's items, tool and xp
-- (Fit and Connect at the Stone Hearth), and the game clock for actions timed by it. A kit's items are { { full type, count } }, its xp { perk name, amount }.
local Action = {}

Action.POUR_BASE = 40
Action.POUR_PER_LITRE = 12

-- ticks, or 1 with the instant-actions cheat on.
function Action.duration(character, ticks)
    if character:isTimedActionInstant() then return 1 end
    return ticks
end

-- A timed action that runs on the game clock takes the same in-game time at any Day Length (its getDuration is -1).
-- startClock goes in its start, clockProgress in its update: it moves item's job bar and completes the action once
-- the minutes are up, at once with the instant-actions cheat.
function Action.startClock(action)
    action.startHours = getGameTime():getWorldAgeHours()
end

function Action.clockProgress(action, item, minutes)
    local progress = (getGameTime():getWorldAgeHours() - action.startHours) * 60 / minutes
    item:setJobDelta(math.min(progress, 1))
    if progress >= 1 or action.character:isTimedActionInstant() then action:forceComplete() end
end

-- Moving litres of a fluid by hand or hose. Past mostLitres it takes no longer.
function Action.pourDuration(character, litres, mostLitres)
    return Action.duration(character, Action.POUR_BASE + math.floor(math.min(litres, mostLitres) * Action.POUR_PER_LITRE))
end

-- Whether the character carries a tool with the ItemTag of that name, in a bag or not.
function Action.hasTool(character, tag)
    return character:getInventory():containsTagRecurse(ItemTag[tag])
end

-- Plays a kit's work (a fit's or a connection's kit): its anim, a CharacterActionAnims name or a vanilla action's
-- PerformingAction value ("MakeWithBrick_Low", vanilla's masonry), "Build" if none; with prop (a full type), the
-- kit's tool in the right hand (the one carried) and prop's model in the left, as vanilla's Make_With_Brick.
function Action.playKit(action, kit)
    local anim = kit.anim or "Build"
    action:setActionAnim(CharacterActionAnims[anim] or anim)
    if not kit.prop then return end
    local tool = action.character:getInventory():getFirstTagRecurse(ItemTag[kit.tool])
    local script = getScriptManager():FindItem(kit.prop)
    action:setOverrideHandModels(tool, script and script:getStaticModel() or nil)
end

-- A kit need's full types: need[1] is one full type, or a list of any of which will do (the cauldron's crossbars).
function Action.needTypes(need)
    if type(need[1]) == "table" then return need[1] end
    return { need[1] }
end

-- The items a kit needs, all from the main inventory (a menu brings them there first), or nil if any are missing.
-- A need with alternatives takes them in the order listed.
function Action.kitItems(character, needs)
    local inventory = character:getInventory()
    local items = {}
    for _, need in ipairs(needs) do
        local owed = need[2]
        for _, fullType in ipairs(Action.needTypes(need)) do
            if owed <= 0 then break end
            local found = inventory:getSomeType(fullType, owed, ArrayList.new())
            for i = 0, found:size() - 1 do table.insert(items, found:get(i)) end
            owed = owed - found:size()
        end
        if owed > 0 then return nil end
    end
    return items
end

-- What items are as kit needs: { {full type, count} }, one entry per full type (what a fitting gives back).
function Action.asNeeds(items)
    local counts, order = {}, {}
    for _, item in ipairs(items) do
        local fullType = item:getFullType()
        if not counts[fullType] then table.insert(order, fullType) end
        counts[fullType] = (counts[fullType] or 0) + 1
    end
    local needs = {}
    for _, fullType in ipairs(order) do table.insert(needs, { fullType, counts[fullType] }) end
    return needs
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

-- Takes an item out of whatever holds it (the inventory or a bag in it); nothing if it is held by nothing. Vanilla's
-- Remove, not DoRemoveItem: from a character's inventory it takes the item out of the hands too (ENGINE_NOTES).
function Action.removeItem(item)
    local container = item:getContainer()
    if container then container:Remove(item) end
end

-- Puts new where old is, in an item container or on the ground (at the same spot). Returns new, or nil when old is
-- nowhere. (Salt's boiling bucket, Core's burnt vessels.)
function Action.replaceItem(old, new)
    local inventory = old:getContainer()
    local worldItem = old:getWorldItem()
    if worldItem then
        local square = worldItem:getSquare()
        local x, y, z = worldItem:getWorldPosX() - square:getX(), worldItem:getWorldPosY() - square:getY(),
            worldItem:getWorldPosZ() - square:getZ()
        if inventory then Action.removeItem(old) end
        square:transmitRemoveItemFromSquare(worldItem)
        worldItem:removeFromWorld()
        worldItem:removeFromSquare()
        square:AddWorldInventoryItem(new, x, y, z)
        return new
    end
    if not inventory then return nil end
    Action.removeItem(old)
    inventory:AddItem(new)
    return new
end

-- xp is { perk name, amount }, or nil for none.
function Action.addXp(character, xp)
    if xp and Perks[xp[1]] then character:getXp():AddXP(Perks[xp[1]], xp[2]) end
end

return Action
