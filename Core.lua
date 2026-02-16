-- Core.lua - Main addon logic
-- EventListener.lua MUST be listed before this in the TOC.

local ADDON_NAME = ...
Snitch = Snitch or {}

Snitch.VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "Unknown"

-- ============================================================================
-- Localize Globals
-- ============================================================================

local pairs = pairs
local ipairs = ipairs
local print = print
local string_format = string.format

local IsInRaid = IsInRaid
local UnitInRaid = UnitInRaid
local UnitName = UnitName
local SendChatMessage = SendChatMessage
local PlaySound = PlaySound
local C_Timer = C_Timer

-- ============================================================================
-- Module Registry
-- ============================================================================

Snitch.modules = {}
Snitch._pendingModules = Snitch._pendingModules or {}

function Snitch:RegisterModule(moduleId, config)
    if self._modulesReady then
        self:_RegisterModuleNow(moduleId, config)
    else
        table.insert(self._pendingModules, { id = moduleId, config = config })
    end
end

function Snitch:_RegisterModuleNow(moduleId, config)
    if self.modules[moduleId] then
        print(string_format("Snitch: Module %s already registered", moduleId))
        return
    end
    self.modules[moduleId] = {
        id          = moduleId,
        name        = config.name,
        description = config.description,
        onEvent     = config.onEvent,
        initialize  = config.initialize,
        events      = config.events or {},
    }
end

-- ============================================================================
-- Saved Variables & Settings
-- ============================================================================

SnitchDB = SnitchDB or {}

local function InitializeSettings()
    if SnitchDB.enabled == nil then SnitchDB.enabled = true end
    if SnitchDB.debug   == nil then SnitchDB.debug   = false end
    SnitchDB.modules = SnitchDB.modules or {}
end

local function InitializeModuleSettings(moduleId)
    if not SnitchDB.modules[moduleId] then
        SnitchDB.modules[moduleId] = {
            enabled = true,
            alerts  = {
                console   = true,
                chat      = false,
                audioFile = SOUNDKIT.RAID_WARNING or 8959,
                audio     = false,
                screen    = false,
            }
        }
    elseif not SnitchDB.modules[moduleId].alerts then
        SnitchDB.modules[moduleId].alerts = {
            console   = true,
            chat      = false,
            audioFile = SOUNDKIT.RAID_WARNING or 8959,
            audio     = false,
            screen    = false,
        }
    end
end

-- ============================================================================
-- Utility
-- ============================================================================

local function DebugPrint(...)
    if SnitchDB and SnitchDB.debug then
        print("|cff00ff00[Snitch Debug]|r", ...)
    end
end
Snitch.DebugPrint = DebugPrint

-- Raid-only guard. Returns false if not in a raid.
local function IsInRaidGroup()
    return IsInRaid()
end
Snitch.IsInRaidGroup = IsInRaidGroup

-- Returns short name (no realm) for a unit token.
local function GetUnitShortName(unitToken)
    if not unitToken then return nil end
    local fullName = UnitName(unitToken)
    if not fullName then return nil end
    return fullName:match("^([^-]+)") or fullName
end
Snitch.GetUnitShortName = GetUnitShortName

-- Returns true if the unit token is a raid member.
local function IsRaidMemberToken(unitToken)
    if not unitToken then return false end
    return UnitInRaid(unitToken) and true or false
end
Snitch.IsRaidMemberToken = IsRaidMemberToken

-- ============================================================================
-- Alert System
-- ============================================================================

local function SendAlert(message, moduleId)
    if not SnitchDB or not SnitchDB.enabled then return end
    if not IsInRaidGroup() then return end

    local moduleSettings = SnitchDB.modules[moduleId]
    if not moduleSettings or not moduleSettings.enabled then return end

    local alerts = moduleSettings.alerts
    if not alerts then return end

    DebugPrint("Alert:", message)

    if alerts.console then
        print(string_format("|cffff6600[Snitch]|r %s", message))
    end

    if alerts.chat then
        C_Timer.After(0.1, function()
            local ok, err = pcall(SendChatMessage, message, "RAID")
            if not ok then DebugPrint("Chat send failed:", err) end
        end)
    end

    if alerts.audio and alerts.audioFile then
        local ok, err = pcall(PlaySound, alerts.audioFile)
        if not ok then DebugPrint("Sound failed:", err) end
    end

    if alerts.screen and Snitch.ScreenAlert then
        local ok, err = pcall(Snitch.ScreenAlert.Show, Snitch.ScreenAlert, message)
        if not ok then DebugPrint("Screen alert failed:", err) end
    end
end
Snitch.SendAlert = SendAlert

-- ============================================================================
-- OnEvent
-- ============================================================================

local moduleEvents = {}
local addonReady   = false

Snitch.eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName ~= ADDON_NAME then return end

        InitializeSettings()

        Snitch._modulesReady = true
        for _, entry in ipairs(Snitch._pendingModules) do
            Snitch:_RegisterModuleNow(entry.id, entry.config)
        end
        Snitch._pendingModules = {}

        for moduleId, module in pairs(Snitch.modules) do
            InitializeModuleSettings(moduleId)
            for _, ev in ipairs(module.events) do
                moduleEvents[ev] = moduleEvents[ev] or {}
                table.insert(moduleEvents[ev], moduleId)
            end
            if module.initialize then module.initialize() end
        end

        if Snitch.ScreenAlert then Snitch.ScreenAlert:Initialize() end
        if Snitch.Config      then Snitch.Config:RegisterInterfaceOptions() end

        addonReady = true
        print("Snitch v" .. Snitch.VERSION .. " loaded. Type /snitch to configure.")
        return
    end

    if not addonReady then return end
    if not SnitchDB or not SnitchDB.enabled then return end
    if not IsInRaid() then return end  -- raid only, bail early

    local listeners = moduleEvents[event]
    if not listeners then return end

    local moduleSettings = SnitchDB.modules
    for _, moduleId in ipairs(listeners) do
        local module = Snitch.modules[moduleId]
        if module and module.onEvent then
            local settings = moduleSettings[moduleId]
            if settings and settings.enabled then
                local ok, err = pcall(module.onEvent, event, ...)
                if not ok then
                    DebugPrint(string_format("Error in module %s: %s", moduleId, err))
                end
            end
        end
    end
end)

-- ============================================================================
-- Slash Commands
-- ============================================================================

SLASH_SNITCH1 = "/snitch"

SlashCmdList["SNITCH"] = function(msg)
    msg = (msg or ""):lower():trim()

    if msg == "" then
        if Snitch.Config then Snitch.Config:Toggle() end

    elseif msg == "version" then
        print("Snitch version " .. Snitch.VERSION)

    elseif msg == "on" then
        SnitchDB.enabled = true
        print("Snitch enabled.")

    elseif msg == "off" then
        SnitchDB.enabled = false
        print("Snitch disabled.")

    elseif msg == "debug" then
        SnitchDB.debug = not SnitchDB.debug
        print("Snitch debug " .. (SnitchDB.debug and "ON" or "OFF"))

    elseif msg == "status" then
        print("Snitch v" .. Snitch.VERSION)
        print("  Enabled:", SnitchDB.enabled and "ON" or "OFF")
        print("  In raid:", IsInRaid() and "YES" or "NO")
        print("  Debug:",   SnitchDB.debug and "ON" or "OFF")
        print("Modules:")
        for moduleId, module in pairs(Snitch.modules) do
            local s = SnitchDB.modules[moduleId]
            if s then
                print("  [" .. module.name .. "]", s.enabled and "ON" or "OFF")
            end
        end

    else
        print("Snitch: /snitch [version|on|off|debug|status]")
    end
end
