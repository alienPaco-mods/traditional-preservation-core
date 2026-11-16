-- Traditional Preservation core: putting pieces from the inventory into something as a fluid, as many as fit, the
-- oldest first (Fish & Meat's Put Fat in the Cauldron, Dairy's Put Butter in the Cauldron and in a Pot; PiecesUI makes
-- the rows). Where they go is the destination's say, so one action serves every one:
--   into = { here(character): it is still there to put into, room(spec): how many fit now,
--            put(spec, hoursLeft, now): puts that many (hoursLeft per piece), returns how many went in,
--            object: a world object to face, or nil; item: the vessel, for a carried one; after(): optional }
-- Cauldron.piecesInto(fire) and ItemFluid.piecesInto(item) make them.
-- spec: { fluid, pieceMl, hoursLeft = function(item) the hours until it would go off }.
require "TimedActions/ISBaseTimedAction"

TPPutPieces = ISBaseTimedAction:derive("TPPutPieces")

local Action = require "TraditionalPreservationCore/Action"

local TICKS_A_PIECE = 15

-- The pieces still on the player and not rotten.
local function piecesHere(self)
    local inventory, here = self.character:getInventory(), {}
    for _, item in ipairs(self.pieces) do
        if inventory:containsRecursive(item) and not item:isRotten() then table.insert(here, item) end
    end
    return here
end

function TPPutPieces:isValid()
    return self.into.here(self.character) and #piecesHere(self) > 0 and self.into.room(self.spec) > 0
end

function TPPutPieces:waitToStart()
    if not self.into.object then return false end
    self.character:faceThisObject(self.into.object)
    return self.character:shouldBeTurning()
end

function TPPutPieces:start()
    self:setActionAnim("Loot")
end

function TPPutPieces:complete()
    local pieces, hoursLeft = piecesHere(self), {}
    for index, item in ipairs(pieces) do hoursLeft[index] = self.spec.hoursLeft(item) end
    local count = self.into.put(self.spec, hoursLeft, getGameTime():getWorldAgeHours())
    for index = 1, count do Action.removeItem(pieces[index]) end
    if self.into.after then self.into.after() end
    return count > 0
end

function TPPutPieces:perform()
    ISBaseTimedAction.perform(self)
end

function TPPutPieces:getDuration()
    return Action.duration(self.character, TICKS_A_PIECE * #self.pieces)
end

function TPPutPieces:new(character, into, spec, pieces)
    local o = ISBaseTimedAction.new(self, character)
    o.into = into
    o.spec = spec
    o.pieces = pieces
    o.maxTime = o:getDuration()
    return o
end
