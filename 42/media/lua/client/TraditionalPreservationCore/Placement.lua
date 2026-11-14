-- Traditional Preservation core: where a station may be put down, and when it may be picked up. Reached through UI
-- (UI.keepInPlace, UI.outdoorOnly, UI.notInRooms, UI.keepDoorsFree, UI.offAppliances). Wraps
-- ISMoveableSpriteProps.canPickUpMoveable, getInfoPanelFlagsPerTile and canPlaceMoveable, once each for every mod:
-- compare them with vanilla after a game update.
require "Moveables/ISMoveableSpriteProps"

local Placement = {}

-- Picking a station up can break it, and one that holds something would lose it. mustStay(object) names the
-- vanilla pick-up line for a station that has to stay where it is (a test returns true for hasItems, vanilla's line
-- for a full container, or an InfoPanelFlags name: "tooHot" for a fire); nil when it may go.
local stayTests = {}

local function mustStay(object)
    if not object then return nil end
    for _, test in ipairs(stayTests) do
        local why = test(object)
        if why then return why == true and "hasItems" or why end
    end
    return nil
end

local function wrapPickUp()
    local vanillaCanPickUp = ISMoveableSpriteProps.canPickUpMoveable
    local vanillaInfoFlags = ISMoveableSpriteProps.getInfoPanelFlagsPerTile

    function ISMoveableSpriteProps:canPickUpMoveable(character, square, object)
        if mustStay(object) then return false end
        return vanillaCanPickUp(self, character, square, object)
    end

    function ISMoveableSpriteProps:getInfoPanelFlagsPerTile(square, object, player, mode)
        vanillaInfoFlags(self, square, object, player, mode)
        local why = mode == "pickup" and mustStay(object)
        if why then InfoPanelFlags[why] = true end
    end
end

function Placement.keepInPlace(test)
    if #stayTests == 0 then wrapPickUp() end
    table.insert(stayTests, test)
end

-- Putting down: each rule is fits(spriteName, square), false to refuse. Every rule must pass, so their order never
-- decides; vanilla's own check runs after them.
local placeRules = {}

local function placeRule(fits)
    if #placeRules == 0 then
        local vanillaCanPlace = ISMoveableSpriteProps.canPlaceMoveable
        function ISMoveableSpriteProps:canPlaceMoveable(character, square, item)
            for _, ruleFits in ipairs(placeRules) do
                if not ruleFits(self.spriteName, square) then return false end
            end
            return vanillaCanPlace(self, character, square, item)
        end
    end
    table.insert(placeRules, fits)
end

-- Refuses these sprites on a square that fails fits(square).
local function placeOnly(sprites, fits)
    placeRule(function(spriteName, square)
        return not (sprites[spriteName] and square) or fits(square)
    end)
end

-- Stations built for the open refuse an indoor square, and this stops one being picked up and carried in,
-- as placing a moveable doesn't run that check. sprites is a set of sprite names.
function Placement.outdoorOnly(sprites)
    placeOnly(sprites, function(square) return square:isOutside() end)
end

-- The same for stations that may stand under a roof (a porch, an open shed) but not in a room.
function Placement.notInRooms(sprites)
    placeOnly(sprites, function(square) return not square:isInARoom() end)
end

-- Putting down any station whose door is registered with Doors (the Hearth, the Firebox, a mod's): its own door's
-- front tile must be free, and it can't stand in front of another one's door. sprites (a set of names, optional)
-- adds stations without a door that are kept out of a door's front too. One rule, for every mod.
local doorKept
function Placement.keepDoorsFree(sprites)
    if not doorKept then
        doorKept = {}
        local Doors = require "TraditionalPreservationCore/Doors"
        placeRule(function(spriteName, square)
            return not (doorKept[spriteName] or Doors.facingOf(spriteName)) or Doors.fits(square, spriteName)
        end)
    end
    for name in pairs(sprites or {}) do doorKept[name] = true end
end

local APPLIANCES = { "IsoStove", "IsoClothingWasher", "IsoClothingDryer", "IsoCombinationWasherDryer" }
local COLD_CONTAINERS = { fridge = true, freezer = true }

-- A stove, a fridge or freezer, or a washer or dryer: something that heats, chills or shakes what stands on it.
local function isAppliance(object)
    for _, class in ipairs(APPLIANCES) do
        if instanceof(object, class) then return true end
    end
    for index = 0, (object.getContainerCount and object:getContainerCount() or 0) - 1 do
        local container = object:getContainerByIndex(index)
        if container and COLD_CONTAINERS[container:getType()] then return true end
    end
    return false
end

-- Table-top stations refuse a square holding an appliance. Vanilla only asks for IsTable, which electric stoves
-- and chest freezers carry, and the build ghost of an IsStackable tile asks canPlaceMoveable too, so this covers
-- building and putting down. sprites is a set of sprite names.
function Placement.offAppliances(sprites)
    placeOnly(sprites, function(square)
        local objects = square:getObjects()
        for index = 0, objects:size() - 1 do
            if isAppliance(objects:get(index)) then return false end
        end
        return true
    end)
end

return Placement
