-- Traditional Preservation (__NAME__) B42: the __STATION__'s window. A station built or placed this session
-- isn't reported by the map loader, so adding items to it starts tracking it.
require "Entity/ISUI/Components/Crafting/ISCraftLogicPanel"
local UI = require "__MOD__/Core/UI"
local Tiles = require "__MOD__/Tiles"

local STATIONS = {}
for _, name in ipairs(Tiles.STATIONS) do STATIONS[name] = true end

local vanillaItemSlotAddItems = ISCraftLogicPanel.ItemSlotAddItems

local function isStation(entity)
    local sprite = entity and entity:getSprite()
    return sprite ~= nil and STATIONS[sprite:getName()] == true
end

-- TEMPLATE: slot limits beyond vanilla go here (Yeast's five cultures, Fish's weight rule).
function ISCraftLogicPanel.ItemSlotAddItems(player, entity, itemSlot, itemList, component)
    if isStation(entity) and __MOD__World then __MOD__World.track(entity) end
    return vanillaItemSlotAddItems(player, entity, itemSlot, itemList, component)
end

local PLACE_TEXT = { Open = "IGUI___MOD___Open", Sheltered = "IGUI___MOD___Roof", Basement = "IGUI___MOD___Basement" }

-- Vanilla's popup on a running batch goes by the recipe's time alone, so it gets the real time left at the
-- station's temperature instead.
local function drawBatchTooltip(slot, tooltip)
    local data = slot.craftRecipeData
    local M = __MOD__
    local status = M.batchStatus(data:getModData(), data:getRecipe():getTime() / 3600, M.getLedger())
    UI.drawTooltip(tooltip, function(layout)
        UI.addLine(layout, "IGUI___MOD___Progress", UI.percent(status.progress))
        UI.addLine(layout, "IGUI___MOD___TimeLeft", UI.timeText(status.hoursLeft, "IGUI___MOD___Time"))
        UI.addLine(layout, "IGUI___MOD___Temperature", UI.say(PLACE_TEXT[status.place], string.format("%.0f", status.temperature)))
        UI.addRateLine(layout, "IGUI___MOD___Rate", status.rate)
    end)
end

UI.progressTooltips({ ProcessBatch = drawBatchTooltip })
