-- Traditional Preservation core: the craft window shows a charged line (Charge) with its real amount. Vanilla shows
-- such a line as one item kept and given back; for the kind showing (or picked) it now reads "12 Uses" or "7/12",
-- with the consumed icon, red when too little is carried. Wraps ISWidgetInput.updateValues, which runs every frame.
local Charge = require "TraditionalPreservationCore/Charge"

local function relabel(widget)
    local primary, script = widget.primary, widget.inputScript
    if not primary or not script or not primary.inputFullName or widget.displayAsOutput then return end
    local line = Charge.forScriptLine(script:getOriginalLine())
    local need = line and line.need(primary.inputFullName)
    if not need then return end
    local player = getSpecificPlayer(widget.player or 0) or getPlayer()
    local has = player and line.has(player, primary.inputFullName) or 0
    local text = line.amounts[primary.inputFullName].uses
        and string.format("%d/%d %s", math.floor(has), need, getText("Attributes_Type_Uses"))
        or string.format("%d/%d", has, need)
    if primary.label.name ~= text then
        primary.label:setName(text)
        widget:calculateLayout(widget.width, widget.height)
    end
    if widget.iconReturned then widget.iconReturned:setVisible(false) end
    if widget.iconConsumed then widget.iconConsumed:setVisible(true) end
    if has < need then
        primary.label.textColor = widget.colBad
        widget.borderColor = widget.colBad
    end
end

local function install()
    if not ISWidgetInput then pcall(require, "Entity/ISUI/CraftRecipe/ISWidgetInput") end
    if not ISWidgetInput or ISWidgetInput.tpChargeWrapped then return end
    ISWidgetInput.tpChargeWrapped = true
    local vanillaUpdateValues = ISWidgetInput.updateValues
    function ISWidgetInput:updateValues()
        vanillaUpdateValues(self)
        relabel(self)
    end
end

install()
