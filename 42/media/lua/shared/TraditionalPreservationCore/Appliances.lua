-- Traditional Preservation core: stoves, fridges and washers, which table-top stations keep off. Used by the build
-- menu (TraditionalPreservationCore.offAppliances) and by putting a moveable down (UI.offAppliances).
require "TraditionalPreservationCore/Doors"

local Appliances = {}

local CLASSES = { "IsoStove", "IsoClothingWasher", "IsoClothingDryer", "IsoCombinationWasherDryer" }
local COLD_CONTAINERS = { fridge = true, freezer = true }

-- A stove, a fridge or freezer, or a washer or dryer: something that heats, chills or shakes what stands on it.
function Appliances.is(object)
    for _, class in ipairs(CLASSES) do
        if instanceof(object, class) then return true end
    end
    for index = 0, (object.getContainerCount and object:getContainerCount() or 0) - 1 do
        local container = object:getContainerByIndex(index)
        if container and COLD_CONTAINERS[container:getType()] then return true end
    end
    return false
end

-- Whether anything on the square is an appliance.
function Appliances.onSquare(square)
    local objects = square:getObjects()
    for index = 0, objects:size() - 1 do
        if Appliances.is(objects:get(index)) then return true end
    end
    return false
end

TraditionalPreservationCore = TraditionalPreservationCore or {}

-- A table-top station's SpriteConfig OnIsValid: vanilla's build ghost asks canPlaceMoveable only on a solid square
-- (ISBuildIsoEntity.isValidPerSquare), so a stove or fridge would take it. Kept out of a door's front too.
function TraditionalPreservationCore.offAppliances(params)
    return not Appliances.onSquare(params.square) and TraditionalPreservationCore.doorFits(params)
end

return Appliances
