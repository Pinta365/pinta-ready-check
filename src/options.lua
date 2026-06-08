-- Options panel for PintaReadyCheck

local addonName, PRC = ...

local INDENT      = 16
local SECTION_GAP = 14
local AFTER_HEADER = 8
local ROW_CHECK   = 28
local ROW_SLIDER  = 46

local function sectionHeader(parent, label, yOffset)
    local fs = parent:CreateFontString(nil, "overlay", "GameFontNormal")
    fs:SetPoint("TOPLEFT", INDENT, yOffset)
    fs:SetText(label)
    local line = parent:CreateTexture(nil, "BACKGROUND")
    line:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    line:SetHeight(1)
    line:SetPoint("LEFT", fs, "RIGHT", 6, 0)
    line:SetPoint("RIGHT", parent, "RIGHT", -INDENT, 0)
    return yOffset - AFTER_HEADER
end

local function checkbox(parent, label, yOffset)
    local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", INDENT, yOffset)
    cb.Text:SetText(label)
    cb.Text:SetFontObject("GameFontHighlightSmall")
    return cb, yOffset - ROW_CHECK
end

local function initOptionsPanel()
    local parent = (Settings and Settings.RegisterCanvasLayoutCategory) and UIParent or nil
    local panel = CreateFrame("Frame", "PintaReadyCheckOptionsPanel", parent)
    panel.name = "Pinta Ready Check"

    local header = panel:CreateFontString(nil, "overlay", "GameFontHighlightLarge")
    header:SetPoint("TOPLEFT", INDENT, -INDENT)
    header:SetText("|cff45D388Pinta Ready Check|r")

    local y = -46
    y = sectionHeader(panel, "Display", y - SECTION_GAP)

    local slackersCb
    slackersCb, y = checkbox(panel, "Only show players with missing buffs", y)
    slackersCb:SetScript("OnClick", function(self)
        PintaReadyCheckDB.onlyShowSlackers = self:GetChecked()
    end)
    panel.slackersCheckbox = slackersCb

    -- Fade delay slider
    local sliderLabel = panel:CreateFontString(nil, "overlay", "GameFontHighlightSmall")
    sliderLabel:SetPoint("TOPLEFT", INDENT, y)
    sliderLabel:SetText("Hide delay after ready check ends (seconds)")
    y = y - 26

    local slider = CreateFrame("Slider", "PintaReadyCheckFadeSlider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", INDENT, y)
    slider:SetWidth(200)
    slider:SetMinMaxValues(0, 30)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    _G[slider:GetName() .. "Low"]:SetText("0")
    _G[slider:GetName() .. "High"]:SetText("30")
    slider:SetScript("OnValueChanged", function(self, val)
        PintaReadyCheckDB.fadeDelay = math.floor(val)
        _G[self:GetName() .. "Text"]:SetText(math.floor(val) .. "s")
    end)
    panel.fadeSlider = slider
    y = y - ROW_SLIDER

    y = sectionHeader(panel, "General", y - SECTION_GAP)

    local debugCb
    debugCb, y = checkbox(panel, "Show debug messages", y)
    debugCb:SetScript("OnClick", function(self)
        PintaReadyCheckDB.debug = self:GetChecked()
    end)
    panel.debugCheckbox = debugCb

    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 22)
    resetBtn:SetPoint("TOPLEFT", INDENT, y)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("PINTAREADYCHECK_RESET_CONFIRM")
    end)

    local function RefreshOptions()
        slackersCb:SetChecked(PintaReadyCheckDB.onlyShowSlackers == true)
        debugCb:SetChecked(PintaReadyCheckDB.debug == true)
        slider:SetValue(PintaReadyCheckDB.fadeDelay or 2)
    end

    panel:SetScript("OnShow", RefreshOptions)
    RefreshOptions()

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        PRC.settingsCategory = category
    else
        InterfaceOptions_AddCategory(panel)
        PRC.optionsPanel = panel
    end
end

PRC.initOptionsPanel = initOptionsPanel
