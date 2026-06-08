-- Shared utilities for PintaReadyCheck

local addonName, PRC = ...

--- Print debug message if debug mode is enabled.
--- @param ... any Message parts
function PRC.Debug(...)
    if PintaReadyCheckDB and PintaReadyCheckDB.debug then
        print("|cff888888[PRC Debug]|r", ...)
    end
end
