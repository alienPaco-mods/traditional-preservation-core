-- Checks UI.confirm outside the game: it opens vanilla's yes or no box with the text, runs onYes on Yes only, and moves a
-- controller's focus to the box. Run from this folder: luajit tests/test_confirm.lua
local H = dofile((os.getenv("TPCORE") or ".") .. "/tests/harness.lua")
local check = H.check
H.useModPaths()
H.installGetText({})

local realRequire = require
require = function(name)
    if name:find("^TraditionalPreservationCore/") then return realRequire(name) end
end

local shown = {}
ISModalDialog = {}
function ISModalDialog:new(_, _, _, _, text, yesno, target, onclick)
    local modal = { text = text, yesno = yesno, target = target, onclick = onclick }
    function modal:initialise() end
    function modal:addToUIManager() table.insert(shown, self) end
    return modal
end
local focused
JoypadState = { players = {} }
function setJoypadFocus(player, element) focused = { player, element } end
local function answer(modal, internal) modal.onclick(modal.target, { internal = internal, parent = modal }) end

local UI = require "TraditionalPreservationCore/UI"
local playerObj = { getPlayerNum = function() return 0 end }

local yes = 0
local modal = UI.confirm(playerObj, "Pour it away?", function() yes = yes + 1 end)
check("a yes or no box with the text", #shown == 1 and modal.text == "Pour it away?" and modal.yesno)
answer(modal, "NO")
check("No does nothing", yes == 0)
answer(modal, "YES")
check("Yes runs it", yes == 1)
check("no controller, no focus moved", focused == nil)

JoypadState.players[1] = { focus = "menu" }
modal = UI.confirm(playerObj, "Again?", function() end)
check("with a controller the box takes the focus", focused[1] == 0 and focused[2] == modal and modal.prevFocus == "menu")

H.done()
