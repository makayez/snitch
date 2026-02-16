-- Modules/SwapBlaster.lua

Snitch = Snitch or {}

local string_format = string.format
local C_Spell = C_Spell
local C_UnitAuras = C_UnitAuras
local UnitExists = UnitExists
local GetNumGroupMembers = GetNumGroupMembers

local MODULE_ID          = "swapblaster"
local MODULE_NAME        = "SwapBlaster Detector"
local MODULE_DESCRIPTION = "Alerts when someone uses the SwapBlaster toy in a raid"

local SWAPBLASTER_SPELL_IDS = {
    470116,
}

local NEUROSILENCER_SPELL_IDS = {
    470344,
}

-- In Midnight 12.0+, the spellID argument from UNIT_SPELLCAST_* is a "secret
-- value" inside instances. You cannot index a table with it, and you cannot
-- compare it with ==. The only safe approach is to pass it directly to
-- Blizzard API functions (which accept secret values) and compare the
-- returned plain strings instead.
--
-- Strategy: at Initialize() time, resolve our known IDs (safe plain numbers
-- from our own code) to spell names and cache them. In OnEvent, call
-- C_Spell.GetSpellInfo(spellID) to convert the secret value to a safe name,
-- then compare names.

local swapBlasterNames   = {}  -- populated in Initialize()
local neurosilencerNames = {}  -- populated in Initialize()

-- activeCasts keyed on unitToken (plain string, always safe)
local activeCasts = {}

-- ============================================================================
-- Helpers
-- ============================================================================

local function IsWatchedSpell(spellID, nameSet)
    -- spellID is a secret value — pass it to GetSpellInfo which accepts
    -- secret values and returns a safe plain string name.
    local info = C_Spell.GetSpellInfo(spellID)
    if not info or not info.name then return false end
    return nameSet[info.name] == true
end

local function GetNeurosilencerCarriers()
    local carriers = {}
    local n = GetNumGroupMembers()
    for i = 1, n do
        local unitToken = "raid" .. i
        if UnitExists(unitToken) then
            for spellName in pairs(neurosilencerNames) do
                if C_UnitAuras.GetAuraDataBySpellName(unitToken, spellName, "HELPFUL") then
                    local name = Snitch.GetUnitShortName(unitToken)
                    if name then carriers[#carriers + 1] = name end
                    break
                end
            end
        end
    end
    return carriers
end

local function FormatList(t)
    if #t == 0 then return nil end
    if #t == 1 then return t[1] end
    if #t == 2 then return t[1] .. " and " .. t[2] end
    local parts = {}
    for i = 1, #t - 1 do parts[i] = t[i] end
    return table.concat(parts, ", ") .. " and " .. t[#t]
end

-- ============================================================================
-- Event Handler
-- ============================================================================

local function OnEvent(event, unitToken, castGUID, spellID)
    -- Resolve secret spellID to a safe name via Blizzard API, then check
    -- against our cached name set. Never compare or index with spellID directly.
    if not IsWatchedSpell(spellID, swapBlasterNames) then return end
    if not Snitch.IsRaidMemberToken(unitToken) then return end

    local sourceName = Snitch.GetUnitShortName(unitToken)
    if not sourceName then return end

    if event == "UNIT_SPELLCAST_START" then
        local carriers = GetNeurosilencerCarriers()
        local neuroNote = #carriers > 0
            and string_format(" (Neurosilencer: %s)", FormatList(carriers))
            or ""

        activeCasts[unitToken] = { carriers = carriers }

        Snitch.SendAlert(string_format("%s is casting SwapBlaster%s", sourceName, neuroNote), MODULE_ID)
        Snitch.DebugPrint("SwapBlaster START:", sourceName, neuroNote)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local cast = activeCasts[unitToken]
        if not cast then return end

        local carriersNow = GetNeurosilencerCarriers()
        local neuroNote = ""
        if #cast.carriers > 0 then
            neuroNote = #carriersNow > 0
                and string_format(" (may have been blocked — %s still has Neurosilencer)", FormatList(carriersNow))
                or " (Neurosilencer wore off during cast)"
        end

        Snitch.SendAlert(string_format("%s used SwapBlaster%s", sourceName, neuroNote), MODULE_ID)
        Snitch.DebugPrint("SwapBlaster SUCCESS:", sourceName, neuroNote)
        activeCasts[unitToken] = nil

    elseif event == "UNIT_SPELLCAST_FAILED" then
        local cast = activeCasts[unitToken]
        if not cast then return end

        local neuroNote = #cast.carriers > 0
            and string_format(" (blocked by Neurosilencer on %s?)", FormatList(cast.carriers))
            or ""

        Snitch.SendAlert(string_format("%s's SwapBlaster failed%s", sourceName, neuroNote), MODULE_ID)
        Snitch.DebugPrint("SwapBlaster FAILED:", sourceName, neuroNote)
        activeCasts[unitToken] = nil

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if not activeCasts[unitToken] then return end
        Snitch.SendAlert(string_format("%s's SwapBlaster was interrupted", sourceName), MODULE_ID)
        Snitch.DebugPrint("SwapBlaster INTERRUPTED:", sourceName)
        activeCasts[unitToken] = nil
    end
end

-- ============================================================================
-- Init & Registration
-- ============================================================================

local function Initialize()
    Snitch.DebugPrint("SwapBlaster module initialized")

    -- Resolve spell IDs to names while they are still safe plain numbers.
    -- OnEvent will use these name sets to identify secret-value spellIDs.
    for _, id in ipairs(SWAPBLASTER_SPELL_IDS) do
        local info = C_Spell.GetSpellInfo(id)
        if info and info.name then
            swapBlasterNames[info.name] = true
            Snitch.DebugPrint("  Watching:", info.name, "(" .. id .. ")")
        else
            Snitch.DebugPrint("  WARNING: spell ID", id, "not found — may need updating")
        end
    end

    for _, id in ipairs(NEUROSILENCER_SPELL_IDS) do
        local info = C_Spell.GetSpellInfo(id)
        if info and info.name then
            neurosilencerNames[info.name] = true
            Snitch.DebugPrint("  Neurosilencer:", info.name, "(" .. id .. ")")
        else
            Snitch.DebugPrint("  WARNING: Neurosilencer spell ID", id, "not found")
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
