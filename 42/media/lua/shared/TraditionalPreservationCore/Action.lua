-- Traditional Preservation core: what every mod's timed actions share. How long a pour takes, and the debug
-- cheat that makes timed actions instant, which an action only honours if its getDuration asks.
local Action = {}

Action.POUR_BASE = 40
Action.POUR_PER_LITRE = 12

-- ticks, or 1 with the instant-actions cheat on.
function Action.duration(character, ticks)
    if character:isTimedActionInstant() then return 1 end
    return ticks
end

-- Moving litres of a fluid by hand or hose. Past mostLitres it takes no longer.
function Action.pourDuration(character, litres, mostLitres)
    return Action.duration(character, Action.POUR_BASE + math.floor(math.min(litres, mostLitres) * Action.POUR_PER_LITRE))
end

return Action
