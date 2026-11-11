-- Traditional Preservation core: Bank the Fire / Stoke the Fire as a button in the loot window, beside vanilla's
-- Put out Fire, while a Hearth's fire burns. It queues the same action as the Hearth's right-click menu.
require "ISUI/LootWindow/ISLootWindowContainerControls"
local Hearth = require "TraditionalPreservationCore/Hearth"
local HearthUI = require "TraditionalPreservationCore/HearthUI"

ISLootWindowObjectControlHandler_TPHearthFire = ISLootWindowObjectControlHandler:derive("ISLootWindowObjectControlHandler_TPHearthFire")
local Handler = ISLootWindowObjectControlHandler_TPHearthFire

local TITLES = { bank = "ContextMenu_TraditionalPreservationCore_BankFire", stoke = "ContextMenu_TraditionalPreservationCore_StokeFire" }
local HELP = { bank = "IGUI_TraditionalPreservationCore_BankHelp", stoke = "IGUI_TraditionalPreservationCore_StokeHelp" }

-- "bank" for a lit Hearth, "stoke" for a banked one, nil for anything else.
local function modeOf(object)
    if not object or not Hearth.isHearth(object) or not object:isLit() then return nil end
    return Hearth.isBanked(object) and "stoke" or "bank"
end
Handler.modeOf = modeOf

function Handler:shouldBeVisible()
    return modeOf(self.object) ~= nil
end

function Handler:getControl()
    local mode = modeOf(self.object) or "bank"
    self.control = self:getButtonControl(getText(TITLES[mode]))
    self.control:setTooltip(getText(HELP[mode]))
    return self.control
end

function Handler:handleJoypadContextMenu(context)
    local mode = modeOf(self.object)
    if not mode then return end
    local option = self:addJoypadContextMenuOption(context, getText(TITLES[mode]))
    option.iconTexture = getTexture(HearthUI.FIRE_ICONS[mode])
end

function Handler:perform()
    if isGamePaused() then return end
    local mode = modeOf(self.object)
    if mode then HearthUI.fireAction(self.playerObj, self.object, mode) end
end

function Handler:new()
    local o = ISLootWindowObjectControlHandler.new(self)
    o.altColor = true -- it works the fire, not what's in the firebox
    return o
end

-- Right-hand buttons are laid out from the right in list order, so just after Put out Fire puts it beside it.
ISLootWindowContainerControls.AddHandler(Handler, true)
local list = ISLootWindowContainerControls_HandlerList
for index, handler in ipairs(list) do
    if handler == Handler then table.remove(list, index) break end
end
local at = #list + 1
for index, handler in ipairs(list) do
    if handler == ISLootWindowObjectControlHandler_PutOut then at = index + 1 break end
end
table.insert(list, at, Handler)

return Handler
