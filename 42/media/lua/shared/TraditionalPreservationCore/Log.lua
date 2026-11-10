-- Traditional Preservation core: lines for the console that the in-game test steps read. Only in debug mode,
-- so a normal game's log stays clean. Used as
--     local log = require "TraditionalPreservationCore/Log"
--     log("TPV", "bottled 1 L, %.2f L left in the cask", litres)
return function(tag, format, ...)
    if not isDebugEnabled() then return end
    print("[" .. tag .. "] " .. string.format(format, ...))
end
