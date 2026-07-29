-- Buff scanner for PintaReadyCheck

local addonName, PRC = ...
local issecretvalue = issecretvalue or function() return false end

local function unitIdentitySecret(unitToken)
    return C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret
        and C_Secrets.ShouldUnitIdentityBeSecret(unitToken)
end

-- Buff category indices
PRC.CAT = {
    FLASK  = 1,
    FOOD   = 2,
    RUNE   = 3,
    ENCHANT = 4,
    GEMS   = 5,
}
PRC.CAT_COUNT = 5

PRC.CAT_LABEL = {
    [PRC.CAT.FLASK]   = "Flask",
    [PRC.CAT.FOOD]    = "Food",
    [PRC.CAT.RUNE]    = "Rune",
    [PRC.CAT.ENCHANT] = "Ench",
    [PRC.CAT.GEMS]    = "Gem",
}

-- Aura-based categories (flask/food/rune) work for any group via C_UnitAuras.
-- Gear categories (enchant/gem) need an inspect, which is only reliable for a
-- 5-man party where everyone is in range, so we restrict them to party/solo.
--- Categories to display for the current group type.
--- Raid: aura categories only. Party/solo: auras + gear.
--- @return table  Array of PRC.CAT indices.
function PRC.GetActiveCategories()
    if IsInRaid() then
        return { PRC.CAT.FLASK, PRC.CAT.FOOD, PRC.CAT.RUNE }
    end
    return { PRC.CAT.FLASK, PRC.CAT.FOOD, PRC.CAT.RUNE, PRC.CAT.ENCHANT, PRC.CAT.GEMS }
end

-- ============================================================
-- Midnight spell data
-- ============================================================

local MIDNIGHT = {
    flask = {
        -- Midnight flasks/phials
        1236763, 1239355, 1235057, 1239755, 1236767,
        1235111, 1235110, 1235108,
    },
    rune = {
        -- Midnight augment runes
        1234969, 1242347, 1264426,
    },
    food = {
        -- Verified from live capture: Hearty Well Fed
        1233724,
    },
}

local function makeSet(list)
    local out = {}
    for i = 1, #list do out[list[i]] = true end
    return out
end

local FLASK_IDS  = makeSet(MIDNIGHT.flask)
local FOOD_IDS   = makeSet(MIDNIGHT.food)
local RUNE_IDS   = makeSet(MIDNIGHT.rune)
local FOOD_ICONS = {
    [136000] = true,
    [134062] = true,
    [132805] = true,
    [133950] = true,
}

-- ============================================================
-- Gear scan helpers (enchant / gem)
-- ============================================================

local function parseItemFields(itemLink)
    if type(itemLink) ~= "string" then
        return nil
    end

    local itemString = itemLink:match("item:([%-:%d]+)")
    if not itemString then
        return nil
    end

    local fields = {strsplit(":", itemString)}
    return fields
end

local function hasEnchantOnSlot(unitToken, slotId)
    local itemLink = GetInventoryItemLink(unitToken, slotId)
    local fields = parseItemFields(itemLink)
    if not fields then
        return false
    end

    local enchantId = tonumber(fields[2]) or 0
    return enchantId > 0
end

local function hasAnyGemOnSlot(unitToken, slotId)
    local itemLink = GetInventoryItemLink(unitToken, slotId)
    local fields = parseItemFields(itemLink)
    if not fields then
        return false
    end

    for index = 3, 6 do
        if (tonumber(fields[index]) or 0) > 0 then
            return true
        end
    end

    return false
end

local function applyGearChecks(unitToken, status)
    -- Midnight enchants: head, shoulder, chest, legs, boots, both rings, weapon.
    local hasArmorAndRingEnchants =
        hasEnchantOnSlot(unitToken, INVSLOT_HEAD) and
        hasEnchantOnSlot(unitToken, INVSLOT_SHOULDER) and
        hasEnchantOnSlot(unitToken, INVSLOT_CHEST) and
        hasEnchantOnSlot(unitToken, INVSLOT_LEGS) and
        hasEnchantOnSlot(unitToken, INVSLOT_FEET) and
        hasEnchantOnSlot(unitToken, INVSLOT_FINGER1) and
        hasEnchantOnSlot(unitToken, INVSLOT_FINGER2)

    local hasWeaponEnchant =
        hasEnchantOnSlot(unitToken, INVSLOT_MAINHAND) or
        hasEnchantOnSlot(unitToken, INVSLOT_OFFHAND)

    status[PRC.CAT.ENCHANT] = hasArmorAndRingEnchants and hasWeaponEnchant

    -- Require at least one gem in neck and both rings.
    status[PRC.CAT.GEMS] =
        hasAnyGemOnSlot(unitToken, INVSLOT_NECK) and
        hasAnyGemOnSlot(unitToken, INVSLOT_FINGER1) and
        hasAnyGemOnSlot(unitToken, INVSLOT_FINGER2)
end

-- ============================================================
-- Inspect queue (party only)
-- ------------------------------------------------------------
-- NotifyInspect is async and rate-limited (one inspection at a time), so we
-- serialize requests through a queue. Results are cached by GUID and surfaced
-- on the next display refresh. Gear stays nil (= "unknown") until it resolves.
-- ============================================================

local INSPECT_TIMEOUT = 1.5      -- fallback if INSPECT_READY never fires (out of range / failed)

local gearByGUID  = {}           -- [guid] = { [ENCHANT] = bool, [GEMS] = bool }
local inspectQueue = {}          -- array of pending unit tokens
local inspectQueued = {}         -- [token] = true, dedupe set
local current = nil              -- { token = ..., guid = ... } in-flight inspection
local inspectTimer = nil

local function clearInspectState()
    wipe(inspectQueue)
    wipe(inspectQueued)
    current = nil
    if inspectTimer then
        inspectTimer:Cancel()
        inspectTimer = nil
    end
end
PRC.CancelInspects = clearInspectState

local function canInspectUnit(unitToken)
    return UnitExists(unitToken)
        and not UnitIsUnit(unitToken, "player")
        and not unitIdentitySecret(unitToken)
        and CanInspect(unitToken, false)
end

local function processQueue()
    if current or InCombatLockdown() then return end

    local token = table.remove(inspectQueue, 1)
    while token do
        inspectQueued[token] = nil
        if canInspectUnit(token) then break end
        token = table.remove(inspectQueue, 1)
    end
    if not token then return end

    current = { token = token, guid = UnitGUID(token) }
    NotifyInspect(token)
    PRC.Debug("NotifyInspect ->", token)

    inspectTimer = C_Timer.NewTimer(INSPECT_TIMEOUT, function()
        inspectTimer = nil
        if current then
            PRC.Debug("inspect timed out:", current.token)
            current = nil
            processQueue()
        end
    end)
end

--- Queue gear inspections for every other party member (M+ groups only).
--- No-op in raids and when solo.
function PRC.QueuePartyInspects()
    clearInspectState()
    if IsInRaid() or not IsInGroup() then return end

    for i = 1, GetNumSubgroupMembers() do
        local token = "party" .. i
        if UnitExists(token) and not inspectQueued[token] then
            inspectQueued[token] = true
            inspectQueue[#inspectQueue + 1] = token
        end
    end
    processQueue()
end

--- INSPECT_READY handler (called from PintaReadyCheck.lua).
--- @param guid string  GUID of the unit whose inspect data is ready.
function PRC.OnInspectReady(guid)
    if not current or guid ~= current.guid then
        return
    end

    local token = current.token
    if UnitExists(token) and not unitIdentitySecret(token) then
        local gear = {}
        applyGearChecks(token, gear)
        gearByGUID[guid] = {
            [PRC.CAT.ENCHANT] = gear[PRC.CAT.ENCHANT],
            [PRC.CAT.GEMS]    = gear[PRC.CAT.GEMS],
        }
        PRC.Debug("inspect ready:", token,
            "ench", tostring(gear[PRC.CAT.ENCHANT]),
            "gem", tostring(gear[PRC.CAT.GEMS]))
    end

    ClearInspectPlayer()
    if inspectTimer then
        inspectTimer:Cancel()
        inspectTimer = nil
    end
    current = nil

    processQueue()
    PRC.RefreshDisplay()
end

-- ============================================================
-- Aura scan
-- ============================================================

--- Walk a unit's buffs, flagging matched consumables into `status`.
--- Separated out so it can be pcall'd without allocating a closure per unit.
--- @param unitToken string
--- @param status table  mutated in place
local function collectBuffs(unitToken, status)
    local i = 1
    while true do
        local aura = C_UnitAuras.GetBuffDataByIndex(unitToken, i)
        if not aura then break end

        local id = aura.spellId
        if issecretvalue(id) then
            -- Skip secret aura data safely; we also avoid running in combat.
        elseif FLASK_IDS[id] then
            status[PRC.CAT.FLASK] = true
        elseif FOOD_IDS[id] or FOOD_ICONS[aura.icon] then
            status[PRC.CAT.FOOD] = true
        elseif RUNE_IDS[id] then
            status[PRC.CAT.RUNE] = true
        end

        i = i + 1
    end
end

--- Scan a single unit's consumable buffs (flask/food/rune).
--- Gear categories are left unset here; ScanGroup fills them in.
--- @param unitToken string  e.g. "player", "party1", "raid3"
--- @return table  status keyed by PRC.CAT values
local function scanUnitBuffs(unitToken)
    local status = {
        [PRC.CAT.FLASK] = false,
        [PRC.CAT.FOOD]  = false,
        [PRC.CAT.RUNE]  = false,
    }
    if not UnitExists(unitToken) then return status end

    local skipAuraScan = C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()
    if skipAuraScan then return status end

    local ok, err = pcall(collectBuffs, unitToken, status)
    if not ok then
        PRC.Debug("aura scan failed for", unitToken, "-", err)
    end

    return status
end

-- ============================================================
-- Group scan
-- ============================================================

--- Build the current group data table.
--- Aura categories are scanned synchronously. Gear categories are filled from
--- the inspect cache for party members (self is read directly), and skipped
--- entirely in raids.
--- @return table  Array of { name, unitToken, status } entries.
function PRC.ScanGroup()
    local results     = {}
    local isRaid      = IsInRaid()
    local gearAllowed = not isRaid

    local function addUnit(name, token)
        local status = scanUnitBuffs(token)

        if gearAllowed then
            if UnitIsUnit(token, "player") then
                applyGearChecks(token, status)
            else
                local guid = UnitGUID(token)
                local cached = guid and gearByGUID[guid]
                if cached then
                    status[PRC.CAT.ENCHANT] = cached[PRC.CAT.ENCHANT]
                    status[PRC.CAT.GEMS]    = cached[PRC.CAT.GEMS]
                end
                -- else leave nil -> shown as "unknown" until inspect resolves
            end
        end

        results[#results + 1] = {
            name        = name,
            unitToken   = token,
            status      = status,
            class       = select(2, UnitClass(token)),
            readyStatus = GetReadyCheckStatus(token),
        }
    end

    addUnit(UnitName("player") or "You", "player")

    if isRaid then
        for i = 1, GetNumGroupMembers() do
            local token = "raid" .. i
            if UnitExists(token) and not UnitIsUnit(token, "player") then
                addUnit(UnitName(token) or token, token)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local token = "party" .. i
            if UnitExists(token) then
                addUnit(UnitName(token) or token, token)
            end
        end
    end

    return results
end
