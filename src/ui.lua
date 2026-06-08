-- Minimalist ready-check display for PintaReadyCheck

local addonName, PRC = ...

-- ============================================================
-- Layout constants
-- ============================================================
local ADDON_COLOR  = "|cff45D388"
local FRAME_PAD    = 8
local TITLE_HEIGHT = 16
local ROW_HEIGHT   = 18
local ROW_GAP      = 2
local NAME_WIDTH   = 90
local SQUARE_SIZE  = 12
local COL_WIDTH    = 36

local COLOR_ON      = { r = 0.18, g = 0.88, b = 0.18, a = 1 }   -- green: buffed
local COLOR_OFF     = { r = 0.80, g = 0.12, b = 0.12, a = 1 }   -- red: missing
local COLOR_PENDING = { r = 0.95, g = 0.82, b = 0.20, a = 1 }   -- yellow: inspect not back yet
local MAX_CAT       = PRC.CAT_COUNT or 5

-- Horizontal centre of indicator column `j`, measured from the content's left edge.
local function colCenter(j)
    return NAME_WIDTH + (j - 1) * COL_WIDTH + COL_WIDTH / 2
end

-- ============================================================
-- Frame / row pool
-- ============================================================
local mainFrame
local rows       = {}   -- re-used row frames, indexed 1..N
local fadeTimer

-- Wrap a name in its class colour; falls back to the plain name when unknown.
local function classColorName(name, class)
    local c = class and RAID_CLASS_COLORS[class]
    if c then
        return "|c" .. c.colorStr .. name .. "|r"
    end
    return name
end

-- true -> green, false -> red, nil -> yellow "?" (inspect pending)
local function setSquareState(tex, mark, state)
    local c
    if state == true then
        c = COLOR_ON
        mark:Hide()
    elseif state == false then
        c = COLOR_OFF
        mark:Hide()
    else
        c = COLOR_PENDING
        mark:Show()
    end
    tex:SetColorTexture(c.r, c.g, c.b, c.a)
end

-- ============================================================
-- Position persistence
-- ============================================================
local DEFAULT_POS = { point = "CENTER", relPoint = "CENTER", x = 200, y = 100 }

-- Anchor the frame from the saved position, falling back to the default spot.
local function restorePosition()
    local pos = (PintaReadyCheckDB and PintaReadyCheckDB.framePos) or DEFAULT_POS
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

-- Capture the current anchor into SavedVariables after a drag.
local function savePosition()
    local point, _, relPoint, x, y = mainFrame:GetPoint(1)
    if not point then return end
    PintaReadyCheckDB.framePos = { point = point, relPoint = relPoint, x = x, y = y }
end

-- ============================================================
-- Frame construction
-- ============================================================
local function buildMainFrame()
    mainFrame = CreateFrame("Frame", "PintaReadyCheckDisplay", UIParent, "BackdropTemplate")
    mainFrame:SetHeight(FRAME_PAD * 2 + TITLE_HEIGHT)
    mainFrame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileSize = 16, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    mainFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    mainFrame:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:EnableMouse(true)
    mainFrame:SetMovable(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    -- Right-click anywhere on the frame to dismiss it manually.
    mainFrame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            PRC.HideDisplay()
        end
    end)
    mainFrame:Hide()

    restorePosition()

    -- Title over the name column
    local title = mainFrame:CreateFontString(nil, "overlay", "GameFontHighlightSmall")
    title:SetPoint("LEFT", mainFrame, "TOPLEFT", FRAME_PAD, -(FRAME_PAD + TITLE_HEIGHT / 2))
    title:SetText(ADDON_COLOR .. "PRC|r")

    -- One column header per indicator, centred over its column.
    -- Text/visibility is set per refresh from the active categories.
    mainFrame.colHeaders = {}
    for i = 1, MAX_CAT do
        local h = mainFrame:CreateFontString(nil, "overlay", "GameFontHighlightSmall")
        h:SetPoint("CENTER", mainFrame, "TOPLEFT", FRAME_PAD + colCenter(i), -(FRAME_PAD + TITLE_HEIGHT / 2))
        mainFrame.colHeaders[i] = h
    end
end

local function buildRow(index)
    local row = CreateFrame("Frame", nil, mainFrame)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint(
        "TOPLEFT",
        FRAME_PAD,
        -(FRAME_PAD + TITLE_HEIGHT + (index - 1) * (ROW_HEIGHT + ROW_GAP))
    )
    row:SetWidth(NAME_WIDTH + MAX_CAT * COL_WIDTH)

    row.nameText = row:CreateFontString(nil, "overlay", "GameFontHighlightSmall")
    row.nameText:SetWidth(NAME_WIDTH)
    row.nameText:SetPoint("LEFT", 0, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.squares = {}
    row.marks   = {}
    for i = 1, MAX_CAT do
        local sq = row:CreateTexture(nil, "OVERLAY")
        sq:SetSize(SQUARE_SIZE, SQUARE_SIZE)
        sq:SetPoint("CENTER", row, "LEFT", colCenter(i), 0)
        row.squares[i] = sq

        -- "?" overlay shown while an inspect is still pending
        local mark = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mark:SetDrawLayer("OVERLAY", 7)
        mark:SetPoint("CENTER", sq, "CENTER", 0, 0)
        mark:SetText("?")
        mark:SetTextColor(0.1, 0.1, 0.1)
        row.marks[i] = mark

        setSquareState(sq, mark, nil)
    end

    return row
end

local function getRow(index)
    if not rows[index] then
        rows[index] = buildRow(index)
    end
    return rows[index]
end

local function hideRows()
    for _, row in ipairs(rows) do row:Hide() end
end

-- Set the column header labels from the active categories; hide unused columns.
local function refreshHeaders(activeCats)
    for i = 1, MAX_CAT do
        local h = mainFrame.colHeaders[i]
        local cat = activeCats[i]
        if cat then
            h:SetText(PRC.CAT_LABEL[cat])
            h:Show()
        else
            h:Hide()
        end
    end
end

-- ============================================================
-- Public: refresh the display from a fresh group scan
-- ============================================================
function PRC.RefreshDisplay()
    if InCombatLockdown() then return end
    if not mainFrame then buildMainFrame() end

    local activeCats = PRC.GetActiveCategories()
    local catCount   = #activeCats
    local data       = PRC.ScanGroup()
    local visibleRows = 0

    hideRows()
    refreshHeaders(activeCats)
    mainFrame:SetWidth(NAME_WIDTH + catCount * COL_WIDTH + FRAME_PAD * 2 + 4)

    if mainFrame.allGoodText then mainFrame.allGoodText:Hide() end

    for _, entry in ipairs(data) do
        local s = entry.status
        local allBuffed = true
        for _, cat in ipairs(activeCats) do
            if s[cat] ~= true then
                allBuffed = false
                break
            end
        end

        if not (PintaReadyCheckDB.onlyShowSlackers and allBuffed) then
            visibleRows = visibleRows + 1
            local row = getRow(visibleRows)

            -- Clamp name to fit the column, then apply class colour
            local name = entry.name or "?"
            if #name > 12 then name = name:sub(1, 11) .. "~" end
            row.nameText:SetText(classColorName(name, entry.class))

            -- Colour each active indicator square; hide unused columns
            for i = 1, MAX_CAT do
                local sq   = row.squares[i]
                local mark = row.marks[i]
                local cat  = activeCats[i]
                if cat then
                    setSquareState(sq, mark, s[cat])
                    sq:Show()
                else
                    sq:Hide()
                    mark:Hide()
                end
            end

            row:Show()
        end
    end

    -- Resize frame to fit content
    local contentH = FRAME_PAD * 2 + TITLE_HEIGHT
    if visibleRows == 0 then
        if not mainFrame.allGoodText then
            mainFrame.allGoodText = mainFrame:CreateFontString(nil, "overlay", "GameFontHighlightSmall")
            mainFrame.allGoodText:SetPoint("TOPLEFT", FRAME_PAD, -(FRAME_PAD + TITLE_HEIGHT))
        end
        mainFrame.allGoodText:SetText(ADDON_COLOR .. "All Buffed Up!|r")
        mainFrame.allGoodText:Show()
        contentH = contentH + ROW_HEIGHT
    else
        contentH = contentH + visibleRows * (ROW_HEIGHT + ROW_GAP) - ROW_GAP
    end
    mainFrame:SetHeight(contentH + FRAME_PAD)

    mainFrame:Show()
    PRC.Debug("RefreshDisplay: " .. #data .. " total, " .. visibleRows .. " row(s) shown")
end

-- ============================================================
-- Event callbacks (called from PintaReadyCheck.lua)
-- ============================================================

-- Hide the display immediately (manual close / slash command).
function PRC.HideDisplay()
    if fadeTimer then fadeTimer:Cancel(); fadeTimer = nil end
    if mainFrame then mainFrame:Hide() end
end

function PRC.OnReadyCheck()
    if fadeTimer then fadeTimer:Cancel(); fadeTimer = nil end
    PRC.Debug("READY_CHECK – scanning group")
    PRC.QueuePartyInspects()
    PRC.RefreshDisplay()
end

function PRC.OnReadyCheckConfirm(unit)
    -- Re-scan when someone confirms; they may have just consumed a buff item.
    PRC.Debug("READY_CHECK_CONFIRM: " .. tostring(unit))
    PRC.RefreshDisplay()
end

function PRC.OnReadyCheckFinished()
    PRC.Debug("READY_CHECK_FINISHED – starting fade timer")
    local delay = (PintaReadyCheckDB and PintaReadyCheckDB.fadeDelay) or 2
    if fadeTimer then fadeTimer:Cancel() end
    if delay == 0 then
        if mainFrame then mainFrame:Hide() end
        return
    end
    fadeTimer = C_Timer.NewTimer(delay, function()
        if mainFrame then mainFrame:Hide() end
        fadeTimer = nil
    end)
end

function PRC.OnEnterCombat()
    -- Instantly clear the frame when combat begins
    PRC.Debug("PLAYER_REGEN_DISABLED - hiding display")
    PRC.CancelInspects()
    if fadeTimer then fadeTimer:Cancel(); fadeTimer = nil end
    if mainFrame then mainFrame:Hide() end
end
