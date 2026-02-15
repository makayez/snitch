-- Modules/SwapBlaster.lua - SwapBlaster toy detection module

Snitch = Snitch or {}

-- ============================================================================
-- Localize Globals (Performance)
-- ============================================================================

local _G = _G
local pairs = pairs
local string_format = string.format
local GetTime = GetTime
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitBuff = UnitBuff
local IsInRaid = IsInRaid
local GetNumGroupMembers = GetNumGroupMembers
local GetNumSubgroupMembers = GetNumSubgroupMembers
local GetSpellInfo = GetSpellInfo or function(spellId) return C_Spell.GetSpellInfo(spellId) end
local C_Spell = C_Spell
local C_UnitAuras = C_UnitAuras
local AuraUtil = AuraUtil

-- ============================================================================
-- Module Configuration
-- ============================================================================

local MODULE_ID = "swapblaster"
local MODULE_NAME = "SwapBlaster Detector"
local MODULE_DESCRIPTION = "Alerts when someone uses the SwapBlaster toy"

-- SwapBlaster spell/toy identification
-- Note: To find the correct spell ID, use the toy and check your combat log,
-- or use: /dump C_ToyBox.GetToyInfo(232410)
-- The spell ID may vary by expansion. Update this list as needed.
local SWAPBLASTER_SPELL_IDS = {
    470116,  -- The Midnight expansion spell ID (example - verify in-game)
    -- Add additional spell IDs here if the toy has multiple versions
}

-- Neurosilencer aura (blocks mind control effects like SwapBlaster)
-- This is the buff that prevents SwapBlaster from working
local NEUROSILENCER_SPELL_IDS = {
    470344,  -- Neurosilencer spell ID (verify in-game)
    -- Add alternative IDs if needed
}

-- Create a lookup table for faster checking
local swapBlasterSpells = {}
for _, spellId in ipairs(SWAPBLASTER_SPELL_IDS) do
    swapBlasterSpells[spellId] = true
end

local neurosilencerSpells = {}
for _, spellId in ipairs(NEUROSILENCER_SPELL_IDS) do
    neurosilencerSpells[spellId] = true
end

-- ============================================================================
-- State Tracking
-- ============================================================================

-- Track who is currently casting (to match START with SUCCESS/FAIL)
local activeCasts = {}

-- ============================================================================
-- Helper Functions
-- ============================================================================

local function IsSwapBlasterSpell(spellId)
    return swapBlasterSpells[spellId] == true
end

-- Cache for name formatting (avoid repeated string operations)
local nameCache = {}

local function GetPlayerName(fullName)
    -- Remove server name from "PlayerName-ServerName"
    if not fullName then return nil end

    -- Check cache first
    local cached = nameCache[fullName]
    if cached then return cached end

    -- Parse and cache
    local name = fullName:match("^([^-]+)") or fullName
    nameCache[fullName] = name
    return name
end

local function GetTargetName(guid)
    -- Try to resolve GUID to name
    if not guid then return "unknown target" end

    -- Check if it's a player's current target
    if UnitExists("target") and UnitGUID("target") == guid then
        return GetPlayerName(UnitName("target"))
    end

    -- Check raid/party members
    local isRaid = IsInRaid()
    local prefix = isRaid and "raid" or "party"
    local numMembers = isRaid and GetNumGroupMembers() or GetNumSubgroupMembers()

    for i = 1, numMembers do
        local unit = prefix .. i
        if UnitExists(unit) and UnitGUID(unit) == guid then
            return GetPlayerName(UnitName(unit))
        end
    end

    return "unknown target"
end

local function CheckNeurosilencer(guid)
    -- Check if a unit (by GUID) has Neurosilencer aura
    if not guid then return false end

    local unit = nil

    -- Check if it's the current target
    if UnitExists("target") and UnitGUID("target") == guid then
        unit = "target"
    end

    -- Check raid/party members if not found
    if not unit then
        local isRaid = IsInRaid()
        local prefix = isRaid and "raid" or "party"
        local numMembers = isRaid and GetNumGroupMembers() or GetNumSubgroupMembers()

        for i = 1, numMembers do
            local testUnit = prefix .. i
            if UnitExists(testUnit) and UnitGUID(testUnit) == guid then
                unit = testUnit
                break
            end
        end
    end

    -- If we found the unit, check for Neurosilencer aura
    if unit then
        -- Use AuraUtil for efficient aura checking (WoW 10.0+)
        if AuraUtil and AuraUtil.FindAura then
            -- Check for any of our known Neurosilencer spell IDs
            for spellId in pairs(neurosilencerSpells) do
                local aura = C_UnitAuras.GetAuraDataBySpellName(unit, GetSpellInfo(spellId), "HELPFUL")
                if aura then
                    return true
                end
            end
        else
            -- Fallback for older API
            for i = 1, 40 do
                local name, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, i)
                if not name then break end
                if neurosilencerSpells[spellId] then
                    return true
                end
            end
        end
    end

    return false
end

-- ============================================================================
-- Combat Log Event Handler
-- ============================================================================

local function OnCombatLogEvent(subevent, sourceGUID, sourceName, sourceFlags,
                                 destGUID, destName, destFlags, spellId, spellName, ...)

    -- Early return: Filter for SwapBlaster spell events only
    if not IsSwapBlasterSpell(spellId) then
        return
    end

    -- Get clean source name
    local cleanSourceName = GetPlayerName(sourceName)
    if not cleanSourceName then return end

    if subevent == "SPELL_CAST_START" then
        -- Check if target has Neurosilencer
        local hasNeurosilencer = false
        if destGUID then
            hasNeurosilencer = CheckNeurosilencer(destGUID)
        end

        -- Track the cast
        activeCasts[sourceGUID] = {
            name = cleanSourceName,
            startTime = GetTime(),
            targetGUID = destGUID,
            targetName = destName,
            hadNeurosilencer = hasNeurosilencer  -- Track for later
        }

        -- Format target information and Neurosilencer warning
        local targetInfo = ""
        local neurosilencerWarning = ""

        if destName then
            local cleanDestName = GetPlayerName(destName)
            if cleanDestName then
                targetInfo = string_format(" on %s", cleanDestName)

                if hasNeurosilencer then
                    neurosilencerWarning = " (but the target has a Neurosilencer!)"
                end
            end
        end

        local message = string_format("%s is casting SwapBlaster%s%s",
                                     cleanSourceName, targetInfo, neurosilencerWarning)
        Snitch.SendAlert(message, MODULE_ID)

        Snitch.DebugPrint("SwapBlaster cast started:", cleanSourceName, "->", destName or "no target",
                         hasNeurosilencer and "(Neurosilencer detected)" or "")

    elseif subevent == "SPELL_CAST_SUCCESS" then
        local castInfo = activeCasts[sourceGUID]
        if castInfo then
            -- Format target information
            local targetInfo = ""
            local targetName = castInfo.targetName or destName
            if targetName then
                local cleanTargetName = GetPlayerName(targetName)
                if cleanTargetName then
                    targetInfo = string_format(" on %s", cleanTargetName)
                end
            end

            -- Check if Neurosilencer was present at cast start
            local neurosilencerNote = ""
            if castInfo.hadNeurosilencer then
                -- Neurosilencer was active but cast succeeded - it may have worn off or failed to block
                -- Check current state
                local targetGUID = castInfo.targetGUID or destGUID
                local stillHasNeurosilencer = targetGUID and CheckNeurosilencer(targetGUID)

                if stillHasNeurosilencer then
                    neurosilencerNote = " (but was blocked by Neurosilencer!)"
                else
                    neurosilencerNote = " (Neurosilencer wore off)"
                end
            end

            local message = string_format("%s successfully cast SwapBlaster%s%s",
                                         cleanSourceName, targetInfo, neurosilencerNote)
            Snitch.SendAlert(message, MODULE_ID)

            Snitch.DebugPrint("SwapBlaster cast succeeded:", cleanSourceName,
                            castInfo.hadNeurosilencer and "(had Neurosilencer)" or "")

            -- Clean up
            activeCasts[sourceGUID] = nil
        end

    elseif subevent == "SPELL_CAST_FAILED" or subevent == "SPELL_CAST_INTERRUPTED" then
        local castInfo = activeCasts[sourceGUID]
        if castInfo then
            local reason = (subevent == "SPELL_CAST_INTERRUPTED") and "interrupted" or "cancelled"
            local message = string_format("%s %s their SwapBlaster cast.", cleanSourceName, reason)
            Snitch.SendAlert(message, MODULE_ID)

            Snitch.DebugPrint("SwapBlaster cast", reason .. ":", cleanSourceName)

            -- Clean up
            activeCasts[sourceGUID] = nil
        end
    end
end

-- ============================================================================
-- Module Initialization
-- ============================================================================

local function Initialize()
    Snitch.DebugPrint("SwapBlaster module initialized")

    -- Verify SwapBlaster spell IDs (helpful for debugging)
    Snitch.DebugPrint("SwapBlaster spells:")
    for _, spellId in ipairs(SWAPBLASTER_SPELL_IDS) do
        local spellInfo = C_Spell.GetSpellInfo(spellId)
        if spellInfo then
            Snitch.DebugPrint("  Watching spell:", spellInfo.name, "(" .. spellId .. ")")
        else
            Snitch.DebugPrint("  Warning: Spell ID", spellId, "not found. May need updating.")
        end
    end

    -- Verify Neurosilencer spell IDs
    Snitch.DebugPrint("Neurosilencer detection:")
    for _, spellId in ipairs(NEUROSILENCER_SPELL_IDS) do
        local spellInfo = C_Spell.GetSpellInfo(spellId)
        if spellInfo then
            Snitch.DebugPrint("  Checking for:", spellInfo.name, "(" .. spellId .. ")")
        else
            Snitch.DebugPrint("  Warning: Spell ID", spellId, "not found. May need updating.")
        end
    end
end

-- ============================================================================
-- Module Registration
-- ============================================================================

Snitch:RegisterModule(MODULE_ID, {
    name = MODULE_NAME,
    description = MODULE_DESCRIPTION,
    onCombatLogEvent = OnCombatLogEvent,
    initialize = Initialize
})
