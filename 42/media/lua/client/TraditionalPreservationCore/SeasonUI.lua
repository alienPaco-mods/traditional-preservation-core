-- Traditional Preservation core: the Season menu (Season), in a seasonable food's own submenu (with vanilla's recipes
-- for it): one option a group of seasoning not yet in it and in reach, its label counting the uses there, for every
-- selected item of that type that lacks it. With nothing to add, one greyed line saying what it takes.
local Season = require "TraditionalPreservationCore/Season"
local UI = require "TraditionalPreservationCore/UI"

-- The selected items of the first seasonable type.
local function selected(items)
    local seasonable, found = UI.selectedItems(items, Season.seasoningFor), {}
    local fullType = seasonable[1] and seasonable[1]:getFullType()
    for _, item in ipairs(seasonable) do
        if item:getFullType() == fullType then table.insert(found, item) end
    end
    return found
end

local function onSeason(playerObj, items, fullType)
    for _, item in ipairs(items) do
        if Season.refusal(item, fullType) == nil then
            ISInventoryPaneContextMenu.transferIfNeeded(playerObj, item)
            ISTimedActionQueue.add(TPSeason:new(playerObj, item, fullType))
        end
    end
end

-- The names of a seasoning's groups, by their first item type, for the tooltip.
local function groupNames(seasoning)
    local names = {}
    for _, group in ipairs(seasoning.groups) do table.insert(names, getItemNameFromFullType(group.types[1])) end
    return table.concat(names, ", ")
end

local function fillMenu(playerNum, context, items)
    local foods = selected(items)
    if #foods == 0 then return end
    local playerObj, first = getSpecificPlayer(playerNum), foods[1]
    local seasoning = Season.seasoningFor(first)
    local parent = UI.itemSubMenu(context, first):addOption(getText("ContextMenu_TraditionalPreservationCore_Season"))
    local about = ISWorldObjectContextMenu.addToolTip()
    about.description = getText("Tooltip_TraditionalPreservationCore_Season", groupNames(seasoning))
    parent.toolTip = about
    local available = Season.available(playerObj, first)
    if #available == 0 then
        parent.notAvailable = true
        return
    end
    local subMenu = context:getNew(context)
    context:addSubMenu(parent, subMenu)
    for _, inReach in ipairs(available) do
        local option = subMenu:addOption(getText("ContextMenu_TraditionalPreservationCore_SeasonWith",
            getItemNameFromFullType(inReach.fullType), tostring(math.floor(inReach.uses))), playerObj, onSeason, foods, inReach.fullType)
        local item = getScriptManager():FindItem(inReach.fullType)
        if item then option.iconTexture = item:getNormalTexture() end
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = getText("Tooltip_TraditionalPreservationCore_SeasonTakes", tostring(Season.usesOf(inReach.group)),
            tostring(#foods))
        option.toolTip = tooltip
    end
end

Events.OnFillInventoryObjectContextMenu.Add(fillMenu)
