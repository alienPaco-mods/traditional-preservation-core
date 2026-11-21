-- Traditional Preservation core: ground that can be dug for something set into the earth (Fruits and Vegetables'
-- clamp): vanilla's own rule for a furrow (ISFarmingMenu.canDigHereSquare: ground level, a free square of bare dirt,
-- no plant or grave), with its grass removed first (vanilla's Remove Grass: the objects flagged canBeRemoved; a
-- furrow digs through them, a clamp doesn't), and outdoors under the sky.
local Ground = {}

-- Whether grass still grows on the square (what vanilla's Remove Grass takes off).
function Ground.hasGrass(square)
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local properties = objects:get(i):getProperties()
        if properties and properties:has(IsoFlagType.canBeRemoved) then return true end
    end
    return false
end

-- Whether a square can be dug for something under the sky. Vanilla's furrow rule is client Lua: none without it.
function Ground.diggable(square)
    if not square or not square:isOutside() then return false end
    local farming = ISFarmingMenu
    if farming == nil or farming.canDigHereSquare == nil or farming.canDigHereSquare(square) ~= true then return false end
    return not Ground.hasGrass(square)
end

return Ground
