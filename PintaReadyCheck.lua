local addonName, PRC = ...

local function onEvent(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        PRC.initSettings()
        PRC.initOptionsPanel()
        PRC.initCommands()
        print("|cff45D388[PintaReadyCheck]|r v" .. PRC.version .. " loaded. Type |cffFFFFFF/prc|r for commands.")
    elseif event == "PLAYER_REGEN_DISABLED" then
        PRC.OnEnterCombat()
    elseif InCombatLockdown() then
        -- Never run any ready-check logic in combat. Unit identity APIs return
        -- secret values in instances (Midnight 12.0.0) and comparisons will error.
        return
    elseif event == "READY_CHECK" then
        PRC.OnReadyCheck(...)
    elseif event == "READY_CHECK_CONFIRM" then
        PRC.OnReadyCheckConfirm(...)
    elseif event == "READY_CHECK_FINISHED" then
        PRC.OnReadyCheckFinished()
    elseif event == "INSPECT_READY" then
        PRC.OnInspectReady(...)
    end
end

local frame = CreateFrame("Frame", "PintaReadyCheckEventFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("READY_CHECK")
frame:RegisterEvent("READY_CHECK_CONFIRM")
frame:RegisterEvent("READY_CHECK_FINISHED")
frame:RegisterEvent("INSPECT_READY")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:SetScript("OnEvent", onEvent)
