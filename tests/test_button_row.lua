-- Checks InfoWindow:buttonRow outside the game: each button is as wide as its text (and icon), a row too wide goes
-- onto a new line, they are made once, follow their list, and a click runs the entry's onClick. Run from this folder: luajit tests/test_button_row.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installGetText({})

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end
-- Engine stand-ins: every character is 6 wide and a line 10 high.
UIFont = { Small = "small" }
function getTextManager()
    return { getFontHeight = function() return 10 end, MeasureStringX = function(_, _, text) return #text * 6 end }
end
function getTexture(name) return { name = name } end
ISCollapsableWindow = H.class("ISCollapsableWindow")
local made = 0
ISButton = {}
function ISButton:new(x, y, width, height, title, target, onclick)
    made = made + 1
    return setmetatable({ x = x, y = y, width = width, height = height, title = title, target = target, onclick = onclick,
        textureColor = { r = 1, g = 1, b = 1, a = 1 } }, { __index = ISButton })
end
-- As vanilla's: the icon drawn at full alpha, enabled or not; the stand-in logs the alpha it is drawn at.
local drawnAlpha
ISUIElement = {}
function ISUIElement.drawTextureScaled(_, _, _, _, _, _, alpha) drawnAlpha = alpha end
function ISButton:drawTextureScaled(...) return ISUIElement.drawTextureScaled(self, ...) end
function ISButton:render() self:drawTextureScaled(self.iconTexture, 5, 4, 16, 16, 1, 1, 1, 1) end
function ISButton:initialise() end
function ISButton:instantiate() end
function ISButton:setX(x) self.x = x end
function ISButton:setY(y) self.y = y end
function ISButton:setWidth(width) self.width = width end
function ISButton:setTitle(title) self.title = title end
function ISButton:setEnable(enabled) self.enable = enabled end
function ISButton:setTooltip(tooltip) self.tooltip = tooltip end
function ISButton:click() self.onclick(self.target, self) end

local InfoWindow = require "TraditionalPreservationCore/InfoWindow"
local window = setmetatable({ width = 360, children = {} }, { __index = InfoWindow })
function window:addChild(child) table.insert(self.children, child) end

local clicked
local nextY = window:buttonRow(100, {
    { title = "Take Done (0)", enabled = false, tooltip = "Nothing hangs on it.", onClick = function() clicked = "done" end },
    { title = "Take All (0)", enabled = true, onClick = function() clicked = "all" end },
})
local done, all = window.buttonsUI[1], window.buttonsUI[2]
-- "Take Done (0)": 13 characters, 78 + 12 each side; "Take All (0)": 72 + 24.
check("two buttons side by side, each as wide as its text, from the padding", made == 2 and done.x == 12 and done.width == 102
    and all.x == 12 + 102 + 8 and all.width == 96 and done.y == 100 and all.y == 100)
check("the next y is under them", nextY == 100 + InfoWindow.BUTTON_HEIGHT + InfoWindow.BAR_GAP)
check("titles, enabled and tooltips from the list", done.title == "Take Done (0)" and done.enable == false
    and done.tooltip == "Nothing hangs on it." and all.enable == true and all.tooltip == nil)
all:click()
check("a click runs its entry's onClick", clicked == "all")
window:buttonRow(140, {
    { title = "Take Done (2)", enabled = true, onClick = function() clicked = "done" end },
    { title = "Take All (5)", enabled = true, onClick = function() clicked = "all" end },
})
check("drawn again they are the same buttons, moved and set anew", made == 2 and done.y == 140 and done.title == "Take Done (2)"
    and done.enable == true and done.tooltip == nil)
done:click()
check("and click as the new list says", clicked == "done")

-- 336 inside the padding: three of 30 characters (204 each) don't fit side by side.
local long = string.rep("x", 30)
nextY = window:buttonRow(200, {
    { title = long, enabled = true }, { title = long, enabled = true, icon = "media/textures/Item_TPCauldron.png" },
    { title = long, enabled = true },
})
local first, second, third = window.buttonsUI[1], window.buttonsUI[2], window.buttonsUI[3]
check("a row too wide goes onto new lines", first.y == 200 and second.x == 12
    and second.y == 200 + InfoWindow.BUTTON_HEIGHT + InfoWindow.BUTTON_GAP and third.y == 200 + 2 * (InfoWindow.BUTTON_HEIGHT + InfoWindow.BUTTON_GAP))
check("an icon widens its button and is set on it", second.width == first.width + InfoWindow.BUTTON_ICON + 5
    and second.iconTexture and second.iconTexture.name == "media/textures/Item_TPCauldron.png" and first.iconTexture == nil)
check("the next y is under the last line", nextY == 200 + 3 * InfoWindow.BUTTON_HEIGHT + 2 * InfoWindow.BUTTON_GAP + InfoWindow.BAR_GAP)

-- A disabled button's icon is greyed (drawn at DISABLED_ICON_ALPHA), an enabled one's at full; its image too.
local window2 = setmetatable({ width = 400, children = {} }, { __index = InfoWindow })
function window2:addChild(child) table.insert(self.children, child) end
window2:buttonRow(10, { { title = "Take Done (0)", enabled = false, icon = "Icon_Crafted" },
    { title = "Take All (3)", enabled = true, icon = "Icon_Returned" } })
local off, on = window2.buttonsUI[1], window2.buttonsUI[2]
off:render()
local offAlpha = drawnAlpha
on:render()
check("a disabled button's icon is greyed, an enabled one's whole", offAlpha == InfoWindow.DISABLED_ICON_ALPHA and drawnAlpha == 1
    and off.textureColor.a == InfoWindow.DISABLED_ICON_ALPHA and on.textureColor.a == 1)
check("and the button draws as vanilla again after", rawget(off, "drawTextureScaled") == nil)

-- A shorter row hides the buttons left over, and the window's update keeps them hidden (no flashing); none hides all.
for _, button in ipairs(window2.buttonsUI) do
    button.visible = true
    function button:getIsVisible() return self.visible end
    function button:setVisible(shown) self.visible = shown end
end
window2:buttonRow(10, { { title = "Take One", enabled = true } })
window2:showButtons()
window2:showButtons()
check("one button after two: the second stays hidden", window2.buttonsUI[1].visible and not window2.buttonsUI[2].visible)
window2:buttonRow(10, {})
window2:showButtons()
check("no buttons: all hidden", not window2.buttonsUI[1].visible and not window2.buttonsUI[2].visible)
window2:buttonRow(10, { { title = "Take One", enabled = true }, { title = "Take All (2)", enabled = true } })
window2:showButtons()
check("back to two: both show", window2.buttonsUI[1].visible and window2.buttonsUI[2].visible)
window2.isCollapsed = true
window2:showButtons()
check("collapsed: none show", not window2.buttonsUI[1].visible)

-- A menu button (user, session 72): wider by vanilla's combo box arrow, drawn at its right; a click opens its rows as a
-- context menu under it instead of running onClick, a disabled row refused with its reason.
local arrowWidth = 11
function getTexture(name) return { name = name, getWidthOrig = function() return arrowWidth end, getHeight = function() return 6 end } end
local arrowDrawn
function ISButton:drawTexture(texture, x) arrowDrawn = { name = texture.name, x = x } end
function ISButton:getAbsoluteX() return 50 + self.x end
function ISButton:getAbsoluteY() return 300 + self.y end
function ISButton:getHeight() return self.height end
local opened
ISContextMenu = { get = function(playerNum, x, y)
    opened = { playerNum = playerNum, x = x, y = y, options = {} }
    function opened:addOption(title, target, onSelect)
        local option = { title = title, target = target, onSelect = onSelect }
        table.insert(self.options, option)
        return option
    end
    function opened:setVisible() end
    return opened
end }
ISWorldObjectContextMenu = { addToolTip = function() return {} end }
local window3 = setmetatable({ width = 400, children = {}, playerObj = { getPlayerNum = function() return 2 end } }, { __index = InfoWindow })
function window3:addChild(child) child.parent = self table.insert(self.children, child) end
local took
window3:buttonRow(10, {
    { title = "Take Sauerkraut (22)", enabled = true, icon = "Item_Sauerkraut", menu = {
        { title = "One", icon = "Item_Sauerkraut", enabled = true, onClick = function() took = "one" end },
        { title = "All (22)", icon = "Item_Sauerkraut", enabled = false, tooltip = "Too far." },
    } },
    { title = "Take Sauerkraut (22)", enabled = true, icon = "Item_Sauerkraut" },
})
local menuButton, plain = window3.buttonsUI[1], window3.buttonsUI[2]
check("a menu button is wider by the arrow and 3", menuButton.width == plain.width + arrowWidth + 3)
arrowDrawn = nil
menuButton:render()
check("its arrow drawn at its right", arrowDrawn and arrowDrawn.name == "media/ui/ArrowDown.png"
    and arrowDrawn.x == menuButton.width - arrowWidth - 3)
arrowDrawn = nil
plain:render()
check("a plain button draws no arrow", arrowDrawn == nil)
menuButton:click()
check("a click opens its rows under it, for the window's player", opened and opened.playerNum == 2
    and opened.x == 50 + menuButton.x and opened.y == 300 + menuButton.y + menuButton.height and #opened.options == 2
    and opened.options[1].title == "One" and opened.options[2].title == "All (22)")
check("a disabled row is refused with its reason", opened.options[2].notAvailable == true
    and opened.options[2].toolTip.description == "Too far." and not opened.options[1].notAvailable)
opened.options[1].onSelect(opened.options[1].target)
check("choosing a row runs its onClick", took == "one")

H.done()
