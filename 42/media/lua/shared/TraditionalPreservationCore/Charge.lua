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

-- amounts = { [full type] = { uses = n } or { count = n } }: one of the two, a positive number, per kind. No two
-- lines may list the same kinds (the craft window finds a line by them).
function Charge.line(amounts)
    assert(type(amounts) == "table", "Charge.line: amounts must be a table")
    local line = { amounts = amounts }
    local types = {}
    for fullType, amount in pairs(amounts) do
        local n = amount.uses or amount.count
        assert(not (amount.uses and amount.count), "Charge.line " .. fullType .. ": uses or count, not both")
        assert(type(n) == "number" and n > 0, "Charge.line " .. fullType .. ": needs a positive uses or count")
        table.insert(types, fullType)
    end
    assert(#types > 0, "Charge.line: no kinds")
    local key = Charge.key(types)
    assert(not lines[key], "Charge.line: a line for " .. key .. " is registered already")
    lines[key] = line

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
        local fullType = item:getFullType()
        local need = line.need(fullType)
        if not need or not character then return true end
        return line.has(character, fullType) >= need
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

-- The line registered for a script line's items ("item 1 [A;B] mode:keep"), or nil. The craft window asks every
-- frame, so each script line's key is worked out once.
local keyOfText = {}

function Charge.forScriptLine(text)
    if not text then return nil end
    local key = keyOfText[text]
    if key == nil then
        local list = text:match("%[([^%]]*)%]")
        local types = {}
        for fullType in (list or ""):gmatch("[^;]+") do table.insert(types, fullType) end
        key = list and Charge.key(types) or false
        keyOfText[text] = key
    end
    return key and lines[key] or nil
end

return Charge
