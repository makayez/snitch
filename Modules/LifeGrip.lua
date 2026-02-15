-- Modules/LifeGrip.lua - Priest Life Grip detection module

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
local UnitAffectingCombat = UnitAffectingCombat
local IsInRaid = IsInRaid
local GetNumGroupMembers = GetNumGroupMembers
local GetNumSubgroupMembers = GetNumSubgroupMembers
local C_Spell = C_Spell

-- ============================================================================
-- Module Configuration
-- ============================================================================

local MODULE_ID = "lifegrip"
local MODULE_NAME = "Life Grip Detector"
local MODULE_DESCRIPTION = "Alerts when a priest uses Life Grip (Leap of Faith) while out of combat"

-- Life Grip spell identification
-- Life Grip (Leap of Faith) - Priest ability that pulls a friendly target to the caster
local LIFEGRIP_SPELL_IDS = {
    73325,  -- Life Grip / Leap of Faith
    -- Add additional spell IDs here if needed
}

-- Create a lookup table for faster checking
local lifeGripSpells = {}
for _, spellId in ipairs(LIFEGRIP_SPELL_IDS) do
    lifeGripSpells[spellId] = true
end

-- ============================================================================
-- State Tracking
-- ============================================================================

-- Track who is currently casting (to match START with SUCCESS/FAIL)
local activeCasts = {}

-- ============================================================================
-- Helper Functions
-- ============================================================================

local function IsLifeGripSpell(spellId)
    return lifeGripSpells[spellId] == true
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

local function IsPlayerInCombat(guid)
    -- Check if a player (by GUID) is in combat
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

    -- If we found the unit, check combat status
    if unit then
        return UnitAffectingCombat(unit)
    end

    return false
end

-- ============================================================================
-- Combat Log Event Handler
-- ============================================================================

local function OnCombatLogEvent(subevent, sourceGUID, sourceName, sourceFlags,
                                 destGUID, destName, destFlags, spellId, spellName, ...)

    -- Early return: Filter for Life Grip spell events only
    if not IsLifeGripSpell(spellId) then
        return
    end

    -- Get clean source name
    local cleanSourceName = GetPlayerName(sourceName)
    if not cleanSourceName then return end

    if subevent == "SPELL_CAST_START" then
        -- Check if caster is in combat
        local isInCombat = IsPlayerInCombat(sourceGUID)

        -- Only alert if OUT of combat
        if not isInCombat then
            -- Track the cast
            activeCasts[sourceGUID] = {
                name = cleanSourceName,
                startTime = GetTime(),
                targetGUID = destGUID,
                targetName = destName
            }

            -- Format target information
            local targetInfo = ""
            if destName then
                local cleanDestName = GetPlayerName(destName)
                if cleanDestName then
                    targetInfo = string_format(" on %s", cleanDestName)
                end
            end

            local message = string_format("%s is casting Life Grip%s (OUT OF COMBAT)!",
                                         cleanSourceName, targetInfo)
            Snitch.SendAlert(message, MODULE_ID)

            Snitch.DebugPrint("Life Grip cast started (OOC):", cleanSourceName, "->", destName or "no target")
        else
            Snitch.DebugPrint("Life Grip cast started but in combat, ignoring:", cleanSourceName)
        end

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

            local message = string_format("%s successfully cast Life Grip%s!",
                                         cleanSourceName, targetInfo)
            Snitch.SendAlert(message, MODULE_ID)

            Snitch.DebugPrint("Life Grip cast succeeded (OOC):", cleanSourceName)

            -- Clean up
            activeCasts[sourceGUID] = nil
        end

    elseif subevent == "SPELL_CAST_FAILED" or subevent == "SPELL_CAST_INTERRUPTED" then
        local castInfo = activeCasts[sourceGUID]
        if castInfo then
            local reason = (subevent == "SPELL_CAST_INTERRUPTED") and "interrupted" or "cancelled"
            local message = string_format("%s %s their Life Grip cast.", cleanSourceName, reason)
            Snitch.SendAlert(message, MODULE_ID)

            Snitch.DebugPrint("Life Grip cast", reason .. " (OOC):", cleanSourceName)

            -- Clean up
            activeCasts[sourceGUID] = nil
        end
    end
end

-- ============================================================================
-- Module Initialization
-- ============================================================================

local function Initialize()
    Snitch.DebugPrint("Life Grip module initialized")

    -- Verify spell IDs (helpful for debugging)
    Snitch.DebugPrint("Life Grip spells:")
    for _, spellId in ipairs(LIFEGRIP_SPELL_IDS) do
        local spellInfo = C_Spell.GetSpellInfo(spellId)
        if spellInfo then
            Snitch.DebugPrint("  Watching spell:", spellInfo.name, "(" .. spellId .. ")")
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
