-- Checks InfoWindow:buttonRow outside the game: the buttons share the width, are made once, follow their list, and
-- a click runs the entry's onClick. Run from this folder: luajit tests/test_button_row.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installGetText({})

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end
ISCollapsableWindow = H.class("ISCollapsableWindow")
local made = 0
ISButton = {}
function ISButton:new(x, y, width, height, title, target, onclick)
    made = made + 1
    return setmetatable({ x = x, y = y, width = width, height = height, title = title, target = target, onclick = onclick },
        { __index = ISButton })
end
function ISButton:initialise() end
function ISButton:instantiate() end
function ISButton:setX(x) self.x = x end
function ISButton:setY(y) self.y = y end
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
check("two buttons side by side, sharing the width inside the padding", made == 2 and done.x == 10 and done.width == 167
    and all.x == 10 + 167 + 6 and done.y == 100 and all.y == 100)
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

H.done()
