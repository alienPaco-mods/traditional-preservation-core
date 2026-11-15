-- Traditional Preservation core: putting pieces from the inventory into a Stone Hearth's cauldron as a fluid, as many
-- as fit (Fish & Meat's Put Fat in the Cauldron, Dairy's Put Butter in the Cauldron; CauldronUI.addPieces makes the
-- menu). spec: { fluid, pieceMl, hoursLeft = function(item) the hours until it would go off }.
require "TimedActions/ISBaseTimedAction"

TPCauldronPieces = ISBaseTimedAction:derive("TPCauldronPieces")

local Fire = require "TraditionalPreservationCore/Fire"
local Cauldron = require "TraditionalPreservationCore/Cauldron"
local CauldronFluid = require "TraditionalPreservationCore/CauldronFluid"
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

function TPCauldronPieces:isValid()
    return self.fire:getSquare() ~= nil and #piecesHere(self) > 0
        and CauldronFluid.pieceRoom(Cauldron.state(self.fire:getModData()), self.raw, self.spec.pieceMl) > 0
end

function TPCauldronPieces:waitToStart()
    self.character:faceThisObject(self.fire)
    return self.character:shouldBeTurning()
end

function TPCauldronPieces:start()
    self:setActionAnim("Loot")
end

function TPCauldronPieces:complete()
    -- Brought up to the minute first, so the pieces mix with the cauldron as it is now.
    local cauldron = Cauldron.of(self.fire)
    local now = getGameTime():getWorldAgeHours()
    local pieces, hoursLeft = piecesHere(self), {}
    for index, item in ipairs(pieces) do hoursLeft[index] = self.spec.hoursLeft(item) end
    local count = CauldronFluid.putPieces(cauldron, self.raw, self.spec.pieceMl, hoursLeft, now)
    for index = 1, count do
        Action.removeItem(pieces[index])
    end
    Fire.redraw(self.fire)
    return count > 0
end

function TPCauldronPieces:perform()
    ISBaseTimedAction.perform(self)
end

function TPCauldronPieces:getDuration()
    return Action.duration(self.character, TICKS_A_PIECE * #self.pieces)
end

function TPCauldronPieces:new(character, fire, spec, pieces)
    local o = ISBaseTimedAction.new(self, character)
    o.fire = fire
    o.spec = spec
    o.raw = spec.fluid
    o.pieces = pieces
    o.maxTime = o:getDuration()
    return o
end
