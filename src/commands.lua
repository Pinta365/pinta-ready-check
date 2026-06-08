-- Slash commands for PintaReadyCheck

local addonName, PRC = ...

StaticPopupDialogs["PINTAREADYCHECK_RESET_CONFIRM"] = {
    text = "Reset all Pinta Ready Check settings to defaults and reload the UI?",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function()
        wipe(PintaReadyCheckDB)
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function PRC.initCommands()
    local function printHelp()
        local c = "|cff45D388[PintaReadyCheck]|r"
        print(c, "Commands:")
        print(c, "|cffFFFFFF/prc debug|r - toggle debug output")
        print(c, "|cffFFFFFF/prc slackers|r - toggle \"only show slackers\" mode")
        print(c, "|cffFFFFFF/prc test|r - force a buff scan and show the display")
        print(c, "|cffFFFFFF/prc close|r - hide the display now (or right-click it)")
        print(c, "|cffFFFFFF/prc reset|r - reset settings to defaults")
    end

    SlashCmdList["PINTAREADYCHECK"] = function(msg)
        local cmd = msg:match("^%s*(%S*)%s*$") or ""
        if cmd == "debug" then
            PintaReadyCheckDB.debug = not PintaReadyCheckDB.debug
            print("|cff45D388[PintaReadyCheck]|r Debug", PintaReadyCheckDB.debug and "|cff00FF00ON|r" or "|cffFF4444OFF|r")
        elseif cmd == "slackers" then
            PintaReadyCheckDB.onlyShowSlackers = not PintaReadyCheckDB.onlyShowSlackers
            print("|cff45D388[PintaReadyCheck]|r Only Show Slackers", PintaReadyCheckDB.onlyShowSlackers and "|cff00FF00ON|r" or "|cffFF4444OFF|r")
        elseif cmd == "test" then
            if InCombatLockdown() then
                print("|cff45D388[PintaReadyCheck]|r Cannot scan while in combat.")
            else
                PRC.QueuePartyInspects()
                PRC.RefreshDisplay()
            end
        elseif cmd == "close" or cmd == "hide" then
            PRC.HideDisplay()
        elseif cmd == "reset" then
            StaticPopup_Show("PINTAREADYCHECK_RESET_CONFIRM")
        else
            printHelp()
        end
    end
    SLASH_PINTAREADYCHECK1 = "/prc"
end
