-- Traditional Preservation core: seasoning a food after it is made, as vanilla adds a spice to a stew (Fish & Meat's
-- sausage links). A mod registers its item types with the groups of seasoning they take; each group
-- goes in once, taking the group's uses (group.uses, default USES: what vanilla takes for a stew) of whatever item of
-- the group is in reach, with no cap on how many groups. Each group makes
-- the whole item `unhappy` and `boredom` nicer to eat (a part-eaten one, its share): vanilla's spice in a stew is -2
-- of each at most cooking levels (EvolvedRecipe.useSpice: a use, times 200). What went in is the food's own spice list
-- (Food.spices, saved by the game; full types), and the total bonus is kept in ModData so what the item becomes
-- (cooked, smoked, sliced) can be handed it with Season.carry.
local Uses = require "TraditionalPreservationCore/Uses"

local Season = {}

-- Save keys: never rename them once the mod is out. The whole item's unhappy bonus, and its boredom bonus.
Season.KEY = "tpSeasoning"
Season.BOREDOM_KEY = "tpSeasoningBoredom"
Season.USES = 1

-- fullType -> seasoning
local seasonings = {}

-- Seasoning for the foods in fullTypes. seasoning:
--   groups    { { name = key, types = { fullType, ... }, uses = n (optional) }, ... }: an item type in one group only
--   unhappy  what each group adds to the whole item's unhappiness; boredom (optional) the same for boredom
-- Adds seasoning.groupByType (a seasoning's full type -> its group). Registering a food again replaces its seasoning.
function Season.register(fullTypes, seasoning)
    assert(type(fullTypes) == "table" and #fullTypes > 0, "Season.register: fullTypes must be a list of full types")
    local what = "Season.register " .. tostring(fullTypes[1])
    assert(type(seasoning) == "table" and type(seasoning.groups) == "table" and #seasoning.groups > 0, what .. ": seasoning needs groups")
    assert(type(seasoning.unhappy) == "number", what .. ": seasoning needs unhappy")
    assert(seasoning.boredom == nil or type(seasoning.boredom) == "number", what .. ": boredom must be a number")
    if not seasoning.groupByType then
        local groupByType = {}
        for _, group in ipairs(seasoning.groups) do
            assert(type(group.name) == "string", what .. ": a group needs a name")
            assert(type(group.types) == "table" and #group.types > 0, what .. ": group " .. group.name .. " needs types")
            assert(group.uses == nil or (type(group.uses) == "number" and group.uses > 0),
                what .. ": group " .. group.name .. "'s uses must be above 0")
            for _, fullType in ipairs(group.types) do
                if groupByType[fullType] then
                    error(what .. ": " .. fullType .. " is in groups " .. groupByType[fullType].name .. " and " .. group.name)
                end
                groupByType[fullType] = group
            end
        end
        seasoning.groupByType = groupByType
    end
    for _, fullType in ipairs(fullTypes) do seasonings[fullType] = seasoning end
end

function Season.seasoningFor(item)
    return item and seasonings[item:getFullType()]
end

-- The group (its entry in seasoning.groups) a seasoning item's full type belongs to, or nil.
function Season.groupOf(seasoning, fullType)
    return seasoning.groupByType[fullType]
end

-- The uses one seasoning of a group takes.
function Season.usesOf(group)
    return group.uses or Season.USES
end

-- The groups already in an item, by name.
function Season.added(item)
    local found, seasoning = {}, Season.seasoningFor(item)
    if not seasoning then return found end
    local spices = item:getSpices()
    if not spices then return found end
    for i = 0, spices:size() - 1 do
        local group = Season.groupOf(seasoning, spices:get(i))
        if group then found[group.name] = true end
    end
    return found
end

-- The share of a food not yet eaten: HungChange against BaseHunger.
local function shareLeft(item)
    local base = item:getBaseHunger()
    if not base or base == 0 then return 1 end
    return math.max(0, math.min(item:getHungChange() / base, 1))
end

-- A whole item's bonus (nil for none), and its boredom bonus.
function Season.bonus(item)
    return item:getModData()[Season.KEY]
end

function Season.boredom(item)
    return item:getModData()[Season.BOREDOM_KEY]
end

-- A food's spice list (a Java list, or none) as a Lua list, and back.
local function luaList(list)
    local found = {}
    for i = 0, (list and list:size() or 0) - 1 do table.insert(found, list:get(i)) end
    return found
end

local function javaList(fullTypes)
    local list = ArrayList.new()
    for _, fullType in ipairs(fullTypes) do list:add(fullType) end
    return list
end

-- A new Java list of the same full types. Food.setSpices clears the food's own list before copying the one it is
-- given, so it must never be given that same list back.
local function copyOf(list)
    return javaList(luaList(list))
end

local function setBonus(item, bonus, boredom, spices, share)
    if not bonus or bonus == 0 then return end
    share = share or shareLeft(item)
    item:getModData()[Season.KEY] = bonus
    item:setUnhappyChange(bonus * share)
    if boredom and boredom ~= 0 then
        item:getModData()[Season.BOREDOM_KEY] = boredom
        item:setBoredomChange(boredom * share)
    end
    if spices and spices:size() > 0 then item:setSpices(copyOf(spices)) end
end

-- What the character can put in an item now: for each group not yet in it, the first group's item type in reach with a
-- use to spare, and how many uses of it there are. A list of { group, fullType, uses }.
function Season.available(character, item)
    local seasoning, list = Season.seasoningFor(item), {}
    if not seasoning then return list end
    local added = Season.added(item)
    for _, group in ipairs(seasoning.groups) do
        if not added[group.name] then
            for _, fullType in ipairs(group.types) do
                local uses = Uses.count(character, fullType, true)
                if uses >= Season.usesOf(group) then
                    table.insert(list, { group = group, fullType = fullType, uses = uses })
                    break
                end
            end
        end
    end
    return list
end

-- Why a seasoning can't go in, as translation keys (Season.refusal).
Season.REFUSALS = {
    seasonNot = "IGUI_TraditionalPreservationCore_SeasonNot",
    seasonAlready = "IGUI_TraditionalPreservationCore_SeasonAlready",
    seasonNone = "IGUI_TraditionalPreservationCore_SeasonNone",
}

-- Why fullType can't go into item now (a translation key), or nil.
function Season.refusal(item, fullType, character)
    local seasoning = Season.seasoningFor(item)
    local group = seasoning and Season.groupOf(seasoning, fullType)
    if not group then return Season.REFUSALS.seasonNot end
    if Season.added(item)[group.name] then return Season.REFUSALS.seasonAlready end
    if character and Uses.count(character, fullType, true) < Season.usesOf(group) then return Season.REFUSALS.seasonNone end
    return nil
end

-- Puts a seasoning into an item (no use taken: Season.season does both).
function Season.add(item, fullType)
    local seasoning = Season.seasoningFor(item)
    if not seasoning or not Season.groupOf(seasoning, fullType) then return false end
    local spices = copyOf(item:getSpices())
    spices:add(fullType)
    setBonus(item, (Season.bonus(item) or 0) + seasoning.unhappy, (Season.boredom(item) or 0) + (seasoning.boredom or 0), spices)
    return true
end

-- Takes the group's uses of fullType from what is in reach and puts it into item.
function Season.season(character, item, fullType)
    if Season.refusal(item, fullType, character) then return false end
    Uses.take(character, fullType, Season.usesOf(Season.groupOf(Season.seasoningFor(item), fullType)), true)
    return Season.add(item, fullType)
end

-- Hands an item's seasoning on to what it became: its spices and its bonus, times share (a slice is a part of the
-- link: share 0.25), on what is left of the old one.
function Season.carry(from, to, share)
    local bonus = Season.bonus(from)
    if not bonus then return end
    share = share or 1
    local boredom = Season.boredom(from)
    setBonus(to, bonus * share, boredom and boredom * share, from:getSpices(), shareLeft(from))
end

-- What a seasoned item carries, to hand it on later (a pot holding six links): { bonus, spices = { fullType, ... } }
-- or nil.
function Season.carried(item)
    local bonus = Season.bonus(item)
    if not bonus then return nil end
    return { bonus = bonus, boredom = Season.boredom(item), spices = luaList(item:getSpices()) }
end

function Season.carryOver(item, carried)
    if not carried then return end
    setBonus(item, carried.bonus, carried.boredom, javaList(carried.spices or {}))
end

return Season
