-- Traditional Preservation core: fluid that changes in an item (ItemFluid), on the player's side. A loot window
-- brings the items in the containers it shows up to date, and an item is looked at as it is moved, while it is still
-- where it was (taken off a stove, its heat is still the stove's). ItemFluidUI.addPieces puts a mod's Put Pieces in
-- a Pot on the pieces' right-click menu: a row per vessel, One or All (PiecesUI). A vessel sealed by what stays in it
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

-- The vessels in reach that are empty or hold only the fluid.
local function vesselsFor(playerObj, spec)
    return UI.findItems(playerObj, function(item)
        if not spec.vessels[item:getFullType()] then return false end
        local container = item:getFluidContainer()
        return container ~= nil and (container:isEmpty() or ItemFluid.oneFluid(container) == spec.fluid)
    end)
end

-- spec = {
--   title      the menu option's text          icon     its texture
--   items      { full type = true }: the pieces (any of them goes in as the same fluid)
--   fluid      what a piece becomes            pieceMl  the ml of one piece
--   hoursLeft  function(item): the hours until a piece would go off
--   vessels    { full type = true }: what they go into
--   label      function(vessel, count): a vessel's row, count the pieces that fit in it now
--   help       a row's hover                   noRoom   the hover of a vessel with no room
--   noVessel   the option's hover with no vessel in reach
--   refusal    optional function(playerObj): why the player can't, or nil
-- }
-- Every text is finished text.
function ItemFluidUI.addPieces(spec)
    Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
        if not UI.firstSelected(items, function(item) return spec.items[item:getFullType()] end) then return end
        local playerObj = getSpecificPlayer(playerNum)
        local pieces = UI.findItems(playerObj, function(item) return spec.items[item:getFullType()] and not item:isRotten() end)
        if #pieces == 0 then return end
        local option = context:addOption(spec.title)
        option.iconTexture = getTexture(spec.icon)
        local vessels = vesselsFor(playerObj, spec)
        if #vessels == 0 then return UI.disable(option, spec.noVessel) end
        local sub = context:getNew(context)
        context:addSubMenu(option, sub)
        local refusal = spec.refusal and spec.refusal(playerObj)
        local put = { fluid = spec.fluid, pieceMl = spec.pieceMl, hoursLeft = spec.hoursLeft }
        PiecesUI.oldestFirst(pieces, spec.hoursLeft)
        for _, pot in ipairs(vessels) do
            local room = ItemFluid.roomFor(pot, spec.fluid, spec.pieceMl)
            local row = PiecesUI.row(sub, { label = spec.label(pot, math.min(room, #pieces)), room = room, pieces = pieces,
                refusal = refusal, help = spec.help, noRoom = spec.noRoom }, function(chosen)
                ISInventoryPaneContextMenu.transferIfNeeded(playerObj, pot)
                PiecesUI.queue(playerObj, ItemFluid.piecesInto(pot), put, chosen)
            end)
            row.itemForTexture = pot
        end
    end)
end

return ItemFluidUI
