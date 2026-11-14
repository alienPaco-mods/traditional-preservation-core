-- Traditional Preservation core: seasoning a food after it is made, as vanilla adds a spice to a stew (Fish & Meat's
-- sausage links; user, 2026-11-13). A mod registers its item types with the kinds of seasoning they take; each kind
-- goes in once, taking the kind's uses (kind.uses, default USES: what vanilla takes for a stew) of whatever item of
-- the kind is in reach, with no cap on how many kinds. Each kind makes
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

-- fullType -> spec
local specs = {}

-- Seasoning for the foods in fullTypes. spec:
--   kinds    { { name = key, types = { fullType, ... }, uses = n (optional) }, ... }: an item type in one kind only
--   unhappy  what each kind adds to the whole item's unhappiness; boredom (optional) the same for boredom
-- Adds spec.kindByType (a seasoning's full type -> its kind). Registering a food again replaces its spec.
function Season.register(fullTypes, spec)
    assert(type(fullTypes) == "table" and #fullTypes > 0, "Season.register: fullTypes must be a list of full types")
    local what = "Season.register " .. tostring(fullTypes[1])
    assert(type(spec) == "table" and type(spec.kinds) == "table" and #spec.kinds > 0, what .. ": spec needs kinds")
    assert(type(spec.unhappy) == "number", what .. ": spec needs unhappy")
    assert(spec.boredom == nil or type(spec.boredom) == "number", what .. ": boredom must be a number")
    if not spec.kindByType then
        local kindByType = {}
        for _, kind in ipairs(spec.kinds) do
            assert(type(kind.name) == "string", what .. ": a kind needs a name")
            assert(type(kind.types) == "table" and #kind.types > 0, what .. ": kind " .. kind.name .. " needs types")
            assert(kind.uses == nil or (type(kind.uses) == "number" and kind.uses > 0),
                what .. ": kind " .. kind.name .. "'s uses must be above 0")
            for _, fullType in ipairs(kind.types) do
                if kindByType[fullType] then
                    error(what .. ": " .. fullType .. " is in kinds " .. kindByType[fullType].name .. " and " .. kind.name)
                end
                kindByType[fullType] = kind
            end
        end
        spec.kindByType = kindByType
    end
    for _, fullType in ipairs(fullTypes) do specs[fullType] = spec end
end

function Season.specFor(item)
    return item and specs[item:getFullType()]
end

-- The kind (its entry in spec.kinds) a seasoning item's full type belongs to, or nil.
function Season.kindOf(spec, fullType)
    return spec.kindByType[fullType]
end

-- The uses one seasoning of a kind takes.
function Season.usesOf(kind)
    return kind.uses or Season.USES
end

-- The kinds already in an item, by name.
function Season.added(item)
    local found, spec = {}, Season.specFor(item)
    if not spec then return found end
    local spices = item:getSpices()
    if not spices then return found end
    for i = 0, spices:size() - 1 do
        local kind = Season.kindOf(spec, spices:get(i))
        if kind then found[kind.name] = true end
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

-- What the character can put in an item now: for each kind not yet in it, the first kind's item type in reach with a
-- use to spare, and how many uses of it there are. A list of { kind, fullType, uses }.
function Season.available(character, item)
    local spec, list = Season.specFor(item), {}
    if not spec then return list end
    local added = Season.added(item)
    for _, kind in ipairs(spec.kinds) do
        if not added[kind.name] then
            for _, fullType in ipairs(kind.types) do
                local uses = Uses.count(character, fullType, true)
                if uses >= Season.usesOf(kind) then
                    table.insert(list, { kind = kind, fullType = fullType, uses = uses })
                    break
                end
            end
        end
    end
    return list
end

-- Why fullType can't go into item now (a translation key), or nil.
function Season.refusal(item, fullType, character)
    local spec = Season.specFor(item)
    local kind = spec and Season.kindOf(spec, fullType)
    if not kind then return "IGUI_TraditionalPreservationCore_SeasonNot" end
    if Season.added(item)[kind.name] then return "IGUI_TraditionalPreservationCore_SeasonAlready" end
    if character and Uses.count(character, fullType, true) < Season.usesOf(kind) then return "IGUI_TraditionalPreservationCore_SeasonNone" end
    return nil
end

-- Puts a seasoning into an item (no use taken: Season.season does both).
function Season.add(item, fullType)
    local spec = Season.specFor(item)
    if not spec or not Season.kindOf(spec, fullType) then return false end
    local spices = copyOf(item:getSpices())
    spices:add(fullType)
    setBonus(item, (Season.bonus(item) or 0) + spec.unhappy, (Season.boredom(item) or 0) + (spec.boredom or 0), spices)
    return true
end

-- Takes the kind's uses of fullType from what is in reach and puts it into item.
function Season.season(character, item, fullType)
    if Season.refusal(item, fullType, character) then return false end
    Uses.take(character, fullType, Season.usesOf(Season.kindOf(Season.specFor(item), fullType)), true)
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
function Season.record(item)
    local bonus = Season.bonus(item)
    if not bonus then return nil end
    return { bonus = bonus, boredom = Season.boredom(item), spices = luaList(item:getSpices()) }
end

function Season.apply(item, record)
    if not record then return end
    setBonus(item, record.bonus, record.boredom, javaList(record.spices or {}))
end

return Season
