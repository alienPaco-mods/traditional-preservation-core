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

H.done()
