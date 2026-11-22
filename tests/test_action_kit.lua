-- Checks Action.playKit, how a kit's work looks (Fit and Connect at the Stone Hearth), with stand-ins for the engine.
-- Run from TraditionalPreservationCore: luajit tests/test_action_kit.lua
local H = dofile("tests/harness.lua")
local check = H.check
package.path = "42/media/lua/shared/?.lua;" .. package.path

CharacterActionAnims = { Build = "Build", DigShovel = "DigShovel" }
ItemTag = { MASONS_TROWEL = "base:masonstrowel", PLIERS = "base:pliers" }
local trowel = { name = "Wooden Trowel" }
getScriptManager = function()
    return { FindItem = function(_, fullType) return fullType == "Base.Clay" and { getStaticModel = function() return "Clay" end } or nil end }
end

local Action = require "TraditionalPreservationCore/Action"

local function action()
    local a = { character = { getInventory = function()
        return { getFirstTagRecurse = function(_, tag) return tag == "base:masonstrowel" and trowel or nil end }
    end } }
    function a:setActionAnim(anim) self.anim = anim end
    function a:setOverrideHandModels(right, left) self.right, self.left = right, left end
    return a
end

local plain = action()
Action.playKit(plain, { tool = "PLIERS" })
check("a kit without anim builds, hands left alone", plain.anim == "Build" and plain.right == nil and plain.left == nil)

local dig = action()
Action.playKit(dig, { tool = "DIG_GRAVE", anim = "DigShovel" })
check("a CharacterActionAnims name plays as it is", dig.anim == "DigShovel")

local brick = action()
Action.playKit(brick, { tool = "MASONS_TROWEL", anim = "MakeWithBrick_Low", prop = "Base.Clay" })
check("vanilla's masonry by its PerformingAction name, the carried trowel and clay in hand",
    brick.anim == "MakeWithBrick_Low" and brick.right == trowel and brick.left == "Clay")

H.done()
