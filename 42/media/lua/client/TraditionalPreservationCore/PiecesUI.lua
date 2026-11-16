-- Traditional Preservation core: menu rows that put pieces into something as a fluid (TPPutPieces): the cauldron's
-- (CauldronUI.addPieces: Put Fat, Put Butter in the Cauldron) and a pot's or saucepan's (ItemFluidUI.addPieces: Put
-- Butter in a Pot). A row is one destination: with more than one piece fitting it opens One (the piece nearest to
-- going off) and All (n); with one, or refused, the row itself is the choice.
require "TimedActions/TPPutPieces"
local UI = require "TraditionalPreservationCore/UI"

local PiecesUI = {}

-- Pieces in the order to put them: the nearest to going off first (hoursLeft(item), as a pieces spec's).
function PiecesUI.oldestFirst(pieces, hoursLeft)
    local left = {}
    for _, item in ipairs(pieces) do left[item] = hoursLeft(item) end
    table.sort(pieces, function(a, b) return left[a] < left[b] end)
    return pieces
end

-- Brings the chosen pieces to hand and queues them into into (Cauldron.piecesInto, ItemFluid.piecesInto).
function PiecesUI.queue(playerObj, into, spec, chosen)
    for _, item in ipairs(chosen) do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item) end
    ISTimedActionQueue.add(TPPutPieces:new(playerObj, into, spec, chosen))
end

-- row = { label, room (how many fit there now), pieces (oldest first), refusal (finished text or nil), help, noRoom }.
-- choose(chosen) is called with the pieces picked. Returns the menu row.
function PiecesUI.row(menu, row, choose)
    local count = row.refusal and 0 or math.min(row.room, #row.pieces)
    local option
    if count <= 1 then
        option = menu:addOption(row.label, { row.pieces[1] }, choose)
    else
        option = menu:addOption(row.label)
        local sub = menu:getNew(menu)
        menu:addSubMenu(option, sub)
        sub:addOption(getText("ContextMenu_TraditionalPreservationCore_PiecesOne"), { row.pieces[1] }, choose)
        sub:addOption(UI.say("ContextMenu_TraditionalPreservationCore_PiecesAll", tostring(count)), row.pieces, choose)
    end
    if row.refusal then
        UI.refuse(option, row.refusal)
    elseif row.room > 0 then
        UI.tooltip(option, row.help)
    else
        UI.refuse(option, row.noRoom)
    end
    return option
end

return PiecesUI
