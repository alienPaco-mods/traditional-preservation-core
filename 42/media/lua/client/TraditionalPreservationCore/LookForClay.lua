-- Traditional Preservation core: Look for Clay on the shovel menu (user, 2026-11-27). Vanilla's Take some Clay opens
-- its ground cursor, which paints each tile green where clay can be dug and red where not, but the row only shows
-- once a clay tile has been right-clicked, so finding one meant clicking tile after tile. This row opens the same
-- cursor at once; clicking a green tile digs it as vanilla does. Only tiles within RANGE of the character are judged
-- (user: "limit look for clay to 10 tiles around my character"), green or red; further out they show grey.
require "BuildingObjects/ISUI/ISInventoryBuildMenu"

local RANGE = 10

-- Vanilla's clay cursor, green only within RANGE tiles of the character. Made on first use: vanilla's cursor is in
-- the server Lua, loaded after this file.
local ClayCursor
local function clayCursor()
    if ClayCursor then return ClayCursor end
    ClayCursor = ISShovelGroundCursor:derive("TPClayCursor")
    function ClayCursor:inRange(square)
        local character = self.character
        if not square or square:getZ() ~= math.floor(character:getZ()) then return false end
        local dx, dy = square:getX() - character:getX(), square:getY() - character:getY()
        return dx * dx + dy * dy <= RANGE * RANGE
    end
    function ClayCursor:isValid(square)
        return self:inRange(square) and ISShovelGroundCursor.isValid(self, square)
    end
    -- Out of range grey (user: "tiles further out should be gray not red"); in range vanilla's green or red.
    function ClayCursor:render(x, y, z, square)
        if self:inRange(square) then return ISShovelGroundCursor.render(self, x, y, z, square) end
        self:getFloorCursorSprite():RenderGhostTileColor(x, y, z, 0.5, 0.5, 0.5, 0.6)
    end
    return ClayCursor
end

local function lookForClay(playerObj)
    local cursor = clayCursor():new("floors_exterior_natural_01_13", "floors_exterior_natural_01_13", playerObj, "clay")
    getCell():setDrag(cursor, playerObj:getPlayerNum())
end

local function takesDirt(item)
    return not item:isBroken() and item:hasTag(ItemTag.TAKE_DIRT)
end

Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldobjects, test)
    if test then return end
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or playerObj:getVehicle() then return end
    if not playerObj:getInventory():getFirstEvalRecurse(takesDirt) then return end
    local counts = ISShovelGroundCursor.GetEmptyItemCounts(playerObj)
    if (counts.clay or 0) + (counts.empty or 0) <= 0 then return end
    local menu = context
    local shovel = context:getOptionFromName(getText("ContextMenu_Shovel"))
    if shovel and shovel.subOption then menu = context:getSubMenu(shovel.subOption) end
    if menu:getOptionFromName(getText("ContextMenu_Take_some_clay")) then return end
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_LookForClay"), playerObj,
        lookForClay)
    option.iconTexture = getTexture("Item_Clay")
    option.toolTip = ISWorldObjectContextMenu.addToolTip()
    option.toolTip.description = getText("IGUI_TraditionalPreservationCore_LookForClayHelp")
end)
