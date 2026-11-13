-- Traditional Preservation core: one recipe line that takes a different amount of each item it accepts. A script
-- line has one amount and one way of counting (uses for food and drainables, items with ItemCount), so 12 uses of
-- oats and 12 grains of barley can't share it. Instead the line takes one of them and keeps it,
--     item 1 [Base.OatsRaw;Base.Rice;Base.BarleySeed] mode:keep,
-- and the mod registers the real amounts here:
--     local filler = Charge.line({ ["Base.OatsRaw"] = { uses = 12 }, ["Base.BarleySeed"] = { count = 12 } })
-- Its OnTest (filler.onTest) wants that much of the chosen kind carried, and its OnCreate (filler.take) takes it:
-- uses from the part-used items of the kind first, or that many items. The craft window shows the real amount on the
-- line (ChargeUI), found by the line's item list.
local Uses = require "TraditionalPreservationCore/Uses"

local Charge = {}

local lines = {}

-- The key of a list of full types: sorted, joined.
function Charge.key(fullTypes)
    local sorted = {}
    for _, fullType in ipairs(fullTypes) do table.insert(sorted, fullType) end
    table.sort(sorted)
    return table.concat(sorted, ";")
end

-- How much of a kind the character has, in the line's unit for it.
local function carried(character, fullType, amount)
    if amount.uses then return Uses.count(character, fullType, true) end
    return Uses.items(character, fullType)
end

function Charge.line(amounts)
    local line = { amounts = amounts }
    local types = {}
    for fullType in pairs(amounts) do table.insert(types, fullType) end
    lines[Charge.key(types)] = line

    -- The amount a kind takes (its uses or its count), or nil for an item the line doesn't list.
    function line.need(fullType)
        local amount = amounts[fullType]
        return amount and (amount.uses or amount.count)
    end

    -- How much of the kind the character carries, in the same unit.
    function line.has(character, fullType)
        local amount = amounts[fullType]
        return amount and carried(character, fullType, amount) or 0
    end

    -- OnTest: an item of a listed kind passes only with enough of that kind carried; any other item passes.
    function line.onTest(item, character)
        local amount = amounts[item:getFullType()]
        if not amount or not character then return true end
        return carried(character, item:getFullType(), amount) >= (amount.uses or amount.count)
    end

    -- OnCreate: takes the amount of the kind the recipe kept.
    function line.take(craftRecipeData, character)
        local kept = craftRecipeData:getAllKeepInputItems()
        for i = 0, kept:size() - 1 do
            local fullType = kept:get(i):getFullType()
            local amount = amounts[fullType]
            if amount then
                if amount.uses then Uses.take(character, fullType, amount.uses, true)
                else Uses.takeItems(character, fullType, amount.count) end
                return
            end
        end
    end

    return line
end

-- The line registered for a script line's items ("item 1 [A;B] mode:keep"), or nil.
function Charge.forScriptLine(text)
    local list = text and text:match("%[([^%]]*)%]")
    if not list then return nil end
    local types = {}
    for fullType in list:gmatch("[^;]+") do table.insert(types, fullType) end
    return lines[Charge.key(types)]
end

return Charge
