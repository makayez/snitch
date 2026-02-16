-- Modules/LifeGrip.lua

Snitch = Snitch or {}

local string_format = string.format
local UnitAffectingCombat = UnitAffectingCombat
local C_Spell = C_Spell

local MODULE_ID          = "lifegrip"
local MODULE_NAME        = "Life Grip Detector"
local MODULE_DESCRIPTION = "Alerts when a Priest uses Life Grip out of combat in a raid"

local LIFEGRIP_SPELL_IDS = {
    73325,  -- Leap of Faith / Life Grip
}

-- Resolved at Initialize() time. OnEvent compares names, never spellID directly.
local lifeGripNames = {}

-- activeCasts keyed on unitToken (plain string, always safe)
local activeCasts = {}

-- ============================================================================
-- Helper
-- ============================================================================

local function IsWatchedSpell(spellID, nameSet)
    local info = C_Spell.GetSpellInfo(spellID)
    if not info or not info.name then return false end
    return nameSet[info.name] == true
end

-- ============================================================================
-- Event Handler
-- ============================================================================

local function OnEvent(event, unitToken, castGUID, spellID)
    if not IsWatchedSpell(spellID, lifeGripNames) then return end
    if not Snitch.IsRaidMemberToken(unitToken) then return end

    local sourceName = Snitch.GetUnitShortName(unitToken)
    if not sourceName then return end

    if event == "UNIT_SPELLCAST_START" then
        if UnitAffectingCombat(unitToken) then
            Snitch.DebugPrint("Life Grip (in combat, ignoring):", sourceName)
            return
        end

        activeCasts[unitToken] = true
        Snitch.SendAlert(string_format("%s is casting Life Grip (out of combat)!", sourceName), MODULE_ID)
        Snitch.DebugPrint("Life Grip START OOC:", sourceName)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not activeCasts[unitToken] then return end
        Snitch.SendAlert(string_format("%s used Life Grip (out of combat)!", sourceName), MODULE_ID)
        Snitch.DebugPrint("Life Grip SUCCESS OOC:", sourceName)
        activeCasts[unitToken] = nil

    elseif event == "UNIT_SPELLCAST_FAILED" then
        if not activeCasts[unitToken] then return end
        Snitch.SendAlert(string_format("%s's Life Grip failed.", sourceName), MODULE_ID)
        Snitch.DebugPrint("Life Grip FAILED OOC:", sourceName)
        activeCasts[unitToken] = nil

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if not activeCasts[unitToken] then return end
        Snitch.SendAlert(string_format("%s's Life Grip was interrupted.", sourceName), MODULE_ID)
        Snitch.DebugPrint("Life Grip INTERRUPTED OOC:", sourceName)
        activeCasts[unitToken] = nil
    end
end

-- ============================================================================
-- Init & Registration
-- ============================================================================

local function Initialize()
    Snitch.DebugPrint("Life Grip module initialized")
    for _, id in ipairs(LIFEGRIP_SPELL_IDS) do
        local info = C_Spell.GetSpellInfo(id)
        if info and info.name then
            lifeGripNames[info.name] = true
            Snitch.DebugPrint("  Watching:", info.name, "(" .. id .. ")")
        else
            Snitch.DebugPrint("  WARNING: spell ID", id, "not found — may need updating")
        end
    end
end

Snitch:RegisterModule(MODULE_ID, {
    name        = MODULE_NAME,
    description = MODULE_DESCRIPTION,
    initialize  = Initialize,
    onEvent     = OnEvent,
    events      = {
        "UNIT_SPELLCAST_START",
        "UNIT_SPELLCAST_SUCCEEDED",
        "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED",
    },
})
