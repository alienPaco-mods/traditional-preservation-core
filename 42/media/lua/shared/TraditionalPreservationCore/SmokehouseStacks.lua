-- Traditional Preservation core: a Smokehouse stack's fire counters (moved out of Smokehouse.lua 2026-11-14, refactor
-- b3). What hangs inside is each mod's: a stack records its owner when it starts (startCounters), and a mod steps
-- only its own stacks. The core counts the joined fire for them: hot, the hours of the stoked session now running
-- (Hearth.logFire), and cold, banked hours and the hours of stoked sessions that broke off (fireStep). Plain modData
-- in, plain modData out; Smokehouse passes every function on, so callers name Smokehouse only.
local Hearth = require "TraditionalPreservationCore/Hearth"

local SmokehouseStacks = {}

-- Starts a new stack's fire counters: owner is the mod whose recipe hung it (its id), hotNeed the stoked hours in
-- a row its cook takes (nil for a stack that never cooks).
function SmokehouseStacks.startCounters(modData, owner, hotNeed)
    modData.smokeOwner = owner
    modData.hotNeed = hotNeed
    modData.hot, modData.hotCool, modData.cold = 0, 0, 0
    modData.smokeFrom, modData.smokeSession, modData.lastStoked, modData.lastBanked = nil, nil, nil, nil
end

-- Whether a stack is this mod's to step.
function SmokehouseStacks.owns(modData, owner)
    return modData.smokeOwner == owner
end

local function hotToCold(modData)
    modData.cold = (modData.cold or 0) + (modData.hotCool or modData.hot or 0)
    modData.hot, modData.hotCool = 0, 0
end

-- Brings a stack's counters up to the fire's record (a Firebox's Hearth state), or none (not joined). A new or
-- rebuilt Firebox starts from what it has now; whatever hot the stack had becomes cold, as it does when the session
-- it counted in ends. Of the stoked hours since the last look, those in a session that has since begun are hot.
-- coolShare (default 1) is the share of the hours since the last look that were cool enough for cold smoke: fire
-- hours count as cold only then, stoked or banked, so hot keeps its cool part (hotCool) for when its session breaks
-- off. A stack marked noHot takes no cook: its stoked hours are smoke at once.
-- Returns the stoked and banked hours since the last look for the mod's own use (its drying by the fire's warmth),
-- or nil when the stack starts counting from this fire (none, or another).
function SmokehouseStacks.fireStep(modData, fire, coolShare)
    coolShare = coolShare or 1
    modData.burning = fire and fire.fireMode or nil
    local stokedHours = fire and fire.stokedHours or 0
    if not fire or fire.fireId ~= modData.smokeFrom or stokedHours < (modData.lastStoked or 0) then
        hotToCold(modData)
        if fire and fire.fireId then
            modData.smokeFrom, modData.smokeSession = fire.fireId, fire.session
            modData.lastStoked, modData.lastBanked = stokedHours, fire.bankedHours or 0
        else
            modData.smokeFrom, modData.smokeSession = nil, nil
        end
        return nil
    end
    local stoked = stokedHours - modData.lastStoked
    local banked = math.max((fire.bankedHours or 0) - (modData.lastBanked or 0), 0)
    -- No session running now: whatever was stoked since belonged to one that has ended (even one that began and
    -- ended between two looks, while away).
    if not fire.session or fire.session ~= modData.smokeSession then
        local inNew = math.min(stoked, Hearth.sessionHours(fire))
        hotToCold(modData)
        modData.cold = modData.cold + (stoked - inNew) * coolShare
        modData.hot, modData.hotCool = inNew, inNew * coolShare
        modData.smokeSession = fire.session
    else
        modData.hotCool = (modData.hotCool or modData.hot) + stoked * coolShare
        modData.hot = modData.hot + stoked
    end
    modData.cold = modData.cold + banked * coolShare
    modData.lastStoked, modData.lastBanked = stokedHours, fire.bankedHours or 0
    if modData.noHot then hotToCold(modData) end
    return stoked, banked
end

-- Whether a stack's hot counter has done its cook.
function SmokehouseStacks.hotDone(modData)
    return modData.hotNeed ~= nil and not modData.noHot and (modData.hot or 0) >= modData.hotNeed
end

return SmokehouseStacks
