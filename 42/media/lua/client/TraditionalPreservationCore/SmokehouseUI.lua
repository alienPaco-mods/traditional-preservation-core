-- Traditional Preservation core: Connect the Firebox and Disconnect the Firebox, in the Firebox's own menu
-- (HearthUI.addFireboxMenu) and on the Smokehouse chamber's right-click. Neither picks up while joined, and
-- Firebox Info says where its flue goes.
require "TimedActions/TPFlue"
local UI = require "TraditionalPreservationCore/UI"
local HearthUI = require "TraditionalPreservationCore/HearthUI"
local Hearth = require "TraditionalPreservationCore/Hearth"
local Smokehouse = require "TraditionalPreservationCore/Smokehouse"
local Tiles = require "TraditionalPreservationCore/Tiles"

local FIREBOX_ICON = "media/textures/Item_TPFirebox.png"
local TOOL_NAMES = { MASONS_TROWEL = "IGUI_TraditionalPreservationCore_ToolTrowel", DIG_GRAVE = "IGUI_TraditionalPreservationCore_ToolShovel" }
local KIND_NAMES = { Pipe = "IGUI_TraditionalPreservationCore_FluePipe", Stones = "IGUI_TraditionalPreservationCore_FlueStones" }

local function countsOf(playerObj, kind)
    local counts = {}
    for _, need in ipairs(Smokehouse.FLUE_KITS[kind].items) do
        counts[need[1]] = #UI.findItems(playerObj, function(item) return item:getFullType() == need[1] end)
    end
    return counts
end

local function toolOf(playerObj, kind)
    local tag = ItemTag[Smokehouse.FLUE_KITS[kind].tool]
    return UI.findItems(playerObj, function(item) return item:hasTag(tag) and not item:isBroken() end)[1]
end

local function itemList(items)
    local names = {}
    for _, need in ipairs(items) do table.insert(names, need[2] .. " " .. getItemNameFromFullType(need[1])) end
    return table.concat(names, ", ")
end

local function walkTo(playerObj, found)
    return luautils.walkAdj(playerObj, found.firebox:getSquare(), true)
end

local function onConnect(playerObj, found, kind)
    local kit = Smokehouse.FLUE_KITS[kind]
    for _, need in ipairs(kit.items) do
        local items = UI.findItems(playerObj, function(item) return item:getFullType() == need[1] end)
        for i = 1, need[2] do ISInventoryPaneContextMenu.transferIfNeeded(playerObj, items[i]) end
    end
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, toolOf(playerObj, kind))
    if not walkTo(playerObj, found) then return end
    ISTimedActionQueue.add(TPFlue:new(playerObj, found.firebox, found.tile, kind, kit.tool))
end

local function onDisconnect(playerObj, found, kind)
    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, toolOf(playerObj, kind))
    if not walkTo(playerObj, found) then return end
    ISTimedActionQueue.add(TPFlue:new(playerObj, found.firebox, found.tile, nil, Smokehouse.FLUE_KITS[kind].tool))
end

local function addConnect(menu, playerObj, found)
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_ConnectFirebox"))
    option.iconTexture = getTexture(FIREBOX_ICON)
    local refusal = Smokehouse.connectRefusalFor(found)
    if refusal then return UI.disable(option, getText(refusal)) end
    local sub = menu:getNew(menu)
    menu:addSubMenu(option, sub)
    for _, kind in ipairs(Smokehouse.FLUE_KINDS) do
        local kit = Smokehouse.FLUE_KITS[kind]
        local choice = sub:addOption(getText("ContextMenu_TraditionalPreservationCore_Connect" .. kind), playerObj, onConnect, found, kind)
        local missing, noTool = Smokehouse.kitMissing(kind, countsOf(playerObj, kind), toolOf(playerObj, kind) ~= nil)
        local lines = { getText("IGUI_TraditionalPreservationCore_Flue" .. kind .. "Help"),
            UI.say("IGUI_TraditionalPreservationCore_FlueNeeds", itemList(kit.items)),
            UI.say("IGUI_TraditionalPreservationCore_FlueTool", getText(TOOL_NAMES[kit.tool])) }
        if #missing > 0 or noTool then
            local short = itemList(missing)
            if noTool then short = short ~= "" and (short .. ", " .. getText(TOOL_NAMES[kit.tool])) or getText(TOOL_NAMES[kit.tool]) end
            table.insert(lines, UI.say("IGUI_TraditionalPreservationCore_FlueMissing", short))
            UI.disable(choice, table.concat(lines, " <LINE> "))
        else
            UI.tooltip(choice, table.concat(lines, " <LINE> "))
        end
    end
end

local function addDisconnect(menu, playerObj, found)
    local kind = Smokehouse.flueOf(found.firebox)
    local kit = Smokehouse.FLUE_KITS[kind]
    local option = menu:addOption(getText("ContextMenu_TraditionalPreservationCore_DisconnectFirebox"), playerObj, onDisconnect, found, kind)
    option.iconTexture = getTexture(FIREBOX_ICON)
    local back
    for _, need in ipairs(kit.items) do
        if need[1] == kit.back then back = need[2] .. " " .. getItemNameFromFullType(need[1]) end
    end
    local help = UI.say("IGUI_TraditionalPreservationCore_DisconnectHelp", back, getText(TOOL_NAMES[kit.tool]))
    if Hearth.isBurning(found.firebox) then
        UI.disable(option, getText("IGUI_TraditionalPreservationCore_FlueBurning"))
    elseif not toolOf(playerObj, kind) then
        UI.disable(option, help .. " <LINE> " .. UI.say("IGUI_TraditionalPreservationCore_FlueMissing", getText(TOOL_NAMES[kit.tool])))
    else
        UI.tooltip(option, help)
    end
end

-- The Firebox's menu: Disconnect if its flue is laid, else Connect when a chamber tile is on its back or a flank.
HearthUI.addFireboxMenu(function(menu, playerObj, firebox)
    if Smokehouse.flueOf(firebox) then
        local tile = Smokehouse.joinedChamber(firebox)
        return addDisconnect(menu, playerObj, { firebox = firebox, tile = tile or firebox })
    end
    local found = Smokehouse.chamberBy(firebox)
    if found then addConnect(menu, playerObj, found) end
end)

-- The chamber's right-click: the joined Firebox's Disconnect, or Connect for the first Firebox beside it.
local function onFillChamberMenu(playerNum, context, worldobjects, test)
    for _, object in ipairs(worldobjects) do
        if Smokehouse.isChamber(object) then
            if test then return end
            if Smokehouse.World then Smokehouse.World.track(object) end
            local playerObj = getSpecificPlayer(playerNum)
            local firebox, joined = Smokehouse.joinedFirebox(object)
            if firebox then return addDisconnect(context, playerObj, joined) end
            local candidates = Smokehouse.fireboxesBy(object)
            -- One that may join first, so a refusal shows only when none fits.
            table.sort(candidates, function(a, b) return (Smokehouse.connectRefusalFor(a) == nil) and (Smokehouse.connectRefusalFor(b) ~= nil) end)
            if candidates[1] then addConnect(context, playerObj, candidates[1]) end
            return
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillChamberMenu)

-- Neither the Firebox nor the shed picks up while the flue joins them.
UI.keepInPlace(function(object)
    if Smokehouse.isChamber(object) then return Smokehouse.joinedFirebox(object) ~= nil end
    return Hearth.isFire(object) and Smokehouse.flueOf(object) ~= nil
end)

HearthUI.addFireboxNotes(function(info, notes)
    local flue = info.state and info.state.flue
    if not flue then return end
    table.insert(notes, UI.say("IGUI_TraditionalPreservationCore_FlueJoined", getText(KIND_NAMES[flue])))
end)

-- The shed stands in the open or under an open roof, never in a room, and keeps its door's front free.
local chambers = {}
for _, name in ipairs(Tiles.CHAMBERS) do chambers[name] = true end
UI.notInRooms(chambers)
UI.keepDoorsFree(chambers)
