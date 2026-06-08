-- Configuration for PintaReadyCheck

local addonName, PRC = ...

PRC.name = addonName
PRC.title = C_AddOns.GetAddOnMetadata(addonName, "Title")
PRC.version = C_AddOns.GetAddOnMetadata(addonName, "Version")

PRC.defaultSettings = {
    debug           = false,
    onlyShowSlackers = false,
    fadeDelay       = 2,
}

function PRC.initSettings()
    PintaReadyCheckDB = PintaReadyCheckDB or {}

    for key, value in pairs(PRC.defaultSettings) do
        if PintaReadyCheckDB[key] == nil then
            PintaReadyCheckDB[key] = value
        end
    end
end
