-- Traditional Preservation core: keeps track of every Smokehouse chamber tile and draws its look. The chamber is
-- closed: nothing hangs in sight. Each tile shows where a joined Stone Hearth's flue enters it, master or not (the other
-- tiles have no slots); the front row what hangs by the door while finished stacks wait (Smokehouse.pieceSprites) and
-- the vent's smoke while the joined fire burns (Smokehouse.smokeSprite). What hangs inside is stepped by the mod that
-- owns each stack (Smokehouse.startCounters).
if isClient() then return end

local Smokehouse = require "TraditionalPreservationCore/Smokehouse"
local Station = require "TraditionalPreservationCore/Station"
local Tiles = require "TraditionalPreservationCore/Tiles"

local World = {}
Smokehouse.World = World

-- How many finished stacks wait in the shed's outputs (the slots are on one of its tiles): the pieces of a stack share
-- its stackId (the owning mod's), so each different one is a stack; pieces with none count as one.
local function finishedStacks(station)
    local seen, stacks = {}, 0
    for _, found in ipairs(Smokehouse.chamberTiles(station)) do
        local resources = found[1]:getComponent(ComponentType.Resources)
        local logic = found[1]:getComponent(ComponentType.DryingCraftLogic)
        if resources and logic then
            local slots = Station.itemSlots(resources, logic:getOutputsGroupName(), ResourceIO.Output)
            for i = 0, slots:size() - 1 do
                local stored = slots:get(i):getStoredItems()
                for j = 0, stored:size() - 1 do
                    local stackId = tostring(stored:get(j):getModData().stackId)
                    if not seen[stackId] then seen[stackId], stacks = true, stacks + 1 end
                end
            end
        end
    end
    return stacks
end

local function refresh(station, sessionState)
    local face, part, col = Smokehouse.tileOf(station)
    local sprites = {}
    local flue = Smokehouse.chamberEntry(station)
    if flue then table.insert(sprites, Smokehouse.spriteName(flue)) end
    if part == 1 then
        for _, piece in ipairs(Smokehouse.pieceSprites(face, part, col, finishedStacks(station))) do
            table.insert(sprites, Smokehouse.spriteName(piece))
        end
        local smoke = Smokehouse.smokeSprite(face, part, col, Smokehouse.smokeLook(station))
        if smoke then table.insert(sprites, Smokehouse.spriteName(smoke)) end
    end
    Station.showSprites(station, sessionState, table.concat(sprites, ","), sprites)
end

-- A shed keeps the recipe tag it was built with in the save, so one built before the tag gets it when first seen.
local function newSessionState(station)
    if not Smokehouse.isChamber(station) then return nil end
    local logic = station:getComponent(ComponentType.DryingCraftLogic)
    if logic and logic:getRecipeTagQuery() ~= Smokehouse.RECIPES then logic:setRecipeTagQuery(Smokehouse.RECIPES) end
    return {}
end

local tracker = Station.tracker({ sprites = Tiles.CHAMBERS, newSessionState = newSessionState, refresh = refresh, scan = true })

World.track = tracker.track

-- Redraws a chamber tile now, without waiting for the next tick, e.g. after the flue is laid.
function World.refresh(station)
    local sessionState = tracker.track(station)
    if sessionState then refresh(station, sessionState) end
end

tracker.start()

return World
