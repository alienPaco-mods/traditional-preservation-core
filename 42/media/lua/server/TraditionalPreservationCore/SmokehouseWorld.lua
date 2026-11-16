-- Traditional Preservation core: keeps track of every Smokehouse chamber tile and draws its look. The chamber is
-- closed: nothing hangs in sight. Each tile shows where a joined Stone Hearth's flue enters it, master or not (the other
-- tile has no slots), and the door's tile a ham (Smokehouse.readySprite) while finished stacks wait. What hangs inside is stepped by the mod
-- that owns each stack (Smokehouse.startCounters).
if isClient() then return end

local Smokehouse = require "TraditionalPreservationCore/Smokehouse"
local Station = require "TraditionalPreservationCore/Station"
local Tiles = require "TraditionalPreservationCore/Tiles"

local World = {}
Smokehouse.World = World

-- Whether either tile of the shed holds finished stacks not yet taken out (the slots are on one of them).
local function hasFinished(station)
    for _, found in ipairs(Smokehouse.chamberTiles(station)) do
        local resources = found[1]:getComponent(ComponentType.Resources)
        local logic = found[1]:getComponent(ComponentType.DryingCraftLogic)
        if resources and logic and Station.countItems(resources, logic:getOutputsGroupName(), ResourceIO.Output) > 0 then
            return true
        end
    end
    return false
end

local function refresh(station, sessionState)
    local face, part = Smokehouse.tileOf(station)
    local sprites = {}
    local flue = Smokehouse.chamberEntry(station)
    local ready = Smokehouse.readySprite(face, part, part == 1 and hasFinished(station))
    if flue then table.insert(sprites, Smokehouse.spriteName(flue)) end
    if ready then table.insert(sprites, Smokehouse.spriteName(ready)) end
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
