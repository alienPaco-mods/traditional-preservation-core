-- Traditional Preservation core: fluid that changes in an item (ItemFluid), on the player's side. A loot window
-- brings the items in the containers it shows up to date, and an item is looked at as it is moved, while it is still
-- where it was (taken off a stove, its heat is still the stove's). ItemFluidUI.addPieces puts a mod's Put Pieces in
-- a Pot on the pieces' right-click menu: a row per vessel, One or All (PiecesUI); with vesselTitle, the vessel's own
-- menu gets a row too, its pieces going into it. A vessel sealed by what stays in it
-- (ItemFluid.staysIn) can't be poured from, but can always be emptied: Empty goes in vanilla's Fluid menu, which is
-- otherwise left bare for it.
require "TimedActions/TPEmptyFluid"
local ItemFluid = require "TraditionalPreservationCore/ItemFluid"
local PiecesUI = require "TraditionalPreservationCore/PiecesUI"
local Transfer = require "TraditionalPreservationCore/Transfer"
local UI = require "TraditionalPreservationCore/UI"

local ItemFluidUI = {}

local function onEmpty(playerObj, item)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
    ISTimedActionQueue.add(TPEmptyFluid:new(playerObj, item))
end

Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    local item = UI.firstSelected(items, function(selected)
        return not ItemFluid.canEmpty(ItemFluid.oneFluid(selected:getFluidContainer()))
    end)
    if not item then return end
    local fluidMenu = context:getOptionFromName(getText("ContextMenu_Fluid"))
    local menu = fluidMenu and fluidMenu.subOption and context:getSubMenu(fluidMenu.subOption) or context
    menu:addOption(getText("Fluid_Empty"), getSpecificPlayer(playerNum), onEmpty, item)
end)

Events.OnRefreshInventoryWindowContainers.Add(function(page, reason)
    if reason ~= "end" or page.onCharacter then return end
    local now = getGameTime():getWorldAgeHours()
    for _, button in ipairs(page.backpacks or {}) do ItemFluid.lookIn(button.inventory, now) end
end)

Transfer.before(function(_, item)
    if item:getFluidContainer() then ItemFluid.look(item, getGameTime():getWorldAgeHours()) end
end)

-- A vessel the pieces can go into: one of piecesMenu's, empty or holding only the fluid.
local function takesPieces(item, piecesMenu)
    if not piecesMenu.vessels[item:getFullType()] then return false end
    local container = item:getFluidContainer()
    return container ~= nil and (container:isEmpty() or ItemFluid.oneFluid(container) == piecesMenu.fluid)
end

-- The vessels in reach that take the pieces.
local function vesselsFor(playerObj, piecesMenu)
    return UI.findItems(playerObj, function(item) return takesPieces(item, piecesMenu) end)
end

-- The pieces in reach, not rotten, oldest first.
local function piecesFor(playerObj, piecesMenu)
    local pieces = UI.findItems(playerObj, function(item) return piecesMenu.items[item:getFullType()] and not item:isRotten() end)
    PiecesUI.oldestFirst(pieces, piecesMenu.hoursLeft)
    return pieces
end

-- A vessel's row in menu: One or All of the pieces into it.
local function vesselRow(menu, playerObj, piecesMenu, pot, pieces, label)
    local asFluid = { fluid = piecesMenu.fluid, pieceMl = piecesMenu.pieceMl, hoursLeft = piecesMenu.hoursLeft }
    local room = ItemFluid.roomFor(pot, piecesMenu.fluid, piecesMenu.pieceMl)
    return PiecesUI.row(menu, { label = label(math.min(room, #pieces)), room = room, pieces = pieces,
        refusal = piecesMenu.refusal and piecesMenu.refusal(playerObj), help = piecesMenu.help, noRoom = piecesMenu.noRoom },
        function(chosen)
            ISInventoryPaneContextMenu.transferIfNeeded(playerObj, pot)
            PiecesUI.queue(playerObj, ItemFluid.piecesInto(pot), asFluid, chosen)
        end)
end

-- piecesMenu = {
--   title      the menu option's text          icon     its texture
--   items      { full type = true }: the pieces (any of them goes in as the same fluid)
--   fluid      what a piece becomes            pieceMl  the ml of one piece
--   hoursLeft  function(item): the hours until a piece would go off
--   vessels    { full type = true }: what they go into
--   label      function(vessel, count): a vessel's row, count the pieces that fit in it now
--   help       a row's hover                   noRoom   the hover of a vessel with no room
--   noVessel   the option's hover with no vessel in reach
--   refusal    optional function(playerObj): why the player can't, or nil
--   vesselTitle  optional function(count): the row on a vessel's own menu, count the pieces that fit in it now
--   vesselIcon   optional: that row's texture (the first piece's icon if not given)
-- }
-- Every text is finished text.
function ItemFluidUI.addPieces(piecesMenu)
    Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
        if not UI.firstSelected(items, function(item) return piecesMenu.items[item:getFullType()] end) then return end
        local playerObj = getSpecificPlayer(playerNum)
        local pieces = piecesFor(playerObj, piecesMenu)
        if #pieces == 0 then return end
        local option = context:addOption(piecesMenu.title)
        option.iconTexture = getTexture(piecesMenu.icon)
        local vessels = vesselsFor(playerObj, piecesMenu)
        if #vessels == 0 then return UI.disable(option, piecesMenu.noVessel) end
        local sub = context:getNew(context)
        context:addSubMenu(option, sub)
        for _, pot in ipairs(vessels) do
            local row = vesselRow(sub, playerObj, piecesMenu, pot, pieces, function(count) return piecesMenu.label(pot, count) end)
            row.itemForTexture = pot
        end
    end)
    if not piecesMenu.vesselTitle then return end
    Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
        local pot = UI.firstSelected(items, function(item) return takesPieces(item, piecesMenu) end)
        if not pot then return end
        local playerObj = getSpecificPlayer(playerNum)
        local pieces = piecesFor(playerObj, piecesMenu)
        if #pieces == 0 then return end
        local row = vesselRow(context, playerObj, piecesMenu, pot, pieces, piecesMenu.vesselTitle)
        if piecesMenu.vesselIcon then row.iconTexture = getTexture(piecesMenu.vesselIcon) else row.itemForTexture = pieces[1] end
    end)
end

return ItemFluidUI
