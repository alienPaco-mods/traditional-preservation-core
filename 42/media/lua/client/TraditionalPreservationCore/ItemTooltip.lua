-- Traditional Preservation core: lines of TP's own in an item's inventory and loot tooltip, the one wrap of
-- ISToolTipInv.render (Salt's brine strength, the keeping lines of KeepingTooltip.lua). A mod adds a function that
-- gives an item's text, or nil:
--     ItemTooltip.add(function(item) return ... end)
--     ItemTooltip.add(strengthLine, { sameLine = true })   -- before the item's own text on its line (Salt's brine)
-- The engine draws an item's Tooltip text through Translator.getText, a label that takes "\n" for more lines, so
-- the lines go in as that text for the one draw (each "%" doubled: the engine formats it) and come out again
-- (setTooltip keeps it in modData, which would otherwise be saved; ENGINE_NOTES "Item tooltip text"). Compare with
-- vanilla's ISToolTipInv.render after a game update.
require "ISUI/ISToolTipInv"
local Wrap = require "TraditionalPreservationCore/Wrap"

local ItemTooltip = {}

local adders = {}

function ItemTooltip.add(fn, options)
    table.insert(adders, { fn = fn, sameLine = options and options.sameLine or false })
end

-- The item's TP text, with its own text after: on the same line, after a space, when every line given asked for
-- that, else under them. Nil when no adder gave anything.
function ItemTooltip.text(item, own)
    local lines, sameLine = {}, true
    for _, adder in ipairs(adders) do
        local text = adder.fn(item)
        if text and text ~= "" then
            table.insert(lines, text)
            sameLine = sameLine and adder.sameLine
        end
    end
    if #lines == 0 then return nil end
    local text = table.concat(lines, "\n")
    if own then text = text .. (sameLine and " " or "\n") .. getText(own) end
    -- The engine formats the text it draws (Translator.getText runs String.formatted, ENGINE_NOTES): a lone "%" ("40%,")
    -- is a bad format, which throws in debug mode and leaves the tooltip empty. Doubled, it draws as one.
    return (text:gsub("%%", "%%%%"))
end

-- ISToolTipInv.item isn't always an InventoryItem (the pour window's tooltip holds something else).
Wrap.method("ISToolTipInv", "render", function(vanillaRender, self)
    local item = self.item
    if not item or not instanceof(item, "InventoryItem") then return vanillaRender(self) end
    local own = item:getTooltip()
    local text = ItemTooltip.text(item, own)
    if not text then return vanillaRender(self) end
    item:setTooltip(text)
    -- Protected so the item's own tooltip is put back even if vanilla's draw fails; the error is raised again after.
    local ok, err = pcall(vanillaRender, self)
    item:setTooltip(own)
    item:getModData().Tooltip = nil
    if not ok then error(err) end
end)

return ItemTooltip
