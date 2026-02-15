-- Core.lua - Main addon logic

local ADDON_NAME = ...
Snitch = Snitch or {}

-- Read version from .toc file (single source of truth)
Snitch.VERSION = GetAddOnMetadata(ADDON_NAME, "Version") or "Unknown"

-- ============================================================================
-- Localize Globals (Performance)
-- ============================================================================

local _G = _G
local pairs = pairs
local ipairs = ipairs
local type = type
local print = print
local string_format = string.format
local string_lower = string.lower
local math_floor = math.floor

-- WoW API
local CreateFrame = CreateFrame
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetAddOnMetadata = GetAddOnMetadata or C_AddOns.GetAddOnMetadata
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local GetTime = GetTime
local SendChatMessage = SendChatMessage
local PlaySound = PlaySound
local C_Timer = C_Timer

-- ============================================================================
-- Module Registry
-- ============================================================================

Snitch.modules = {}

function Snitch:RegisterModule(moduleId, config)
    if self.modules[moduleId] then
        print(string_format("Snitch: Module %s already registered", moduleId))
        return
    end

    self.modules[moduleId] = {
        id = moduleId,
        name = config.name,
        description = config.description,
        onCombatLogEvent = config.onCombatLogEvent,
        onEvent = config.onEvent,
        initialize = config.initialize
    }
end

-- ============================================================================
-- Saved Variables & Settings
-- ============================================================================

SnitchDB = SnitchDB or {}

local function InitializeSettings()
    -- Global enable/disable (master switch)
    if SnitchDB.enabled == nil then
        SnitchDB.enabled = true
    end

    -- Debug mode
    if SnitchDB.debug == nil then
        SnitchDB.debug = false
    end

    -- Module settings (will be initialized per-module)
    SnitchDB.modules = SnitchDB.modules or {}

    -- Screen alert appearance settings (global - just controls how alerts look)
    -- The per-module screen alert on/off is in module settings
    if SnitchDB.screenAlert == nil then
        -- This will be initialized by ScreenAlert.lua
    end
end

-- Initialize per-module settings with default alert preferences
local function InitializeModuleSettings(moduleId)
    if not SnitchDB.modules[moduleId] then
        SnitchDB.modules[moduleId] = {
            enabled = true,
            alerts = {
                console = true,
                chat = false,
                chatType = "PARTY",  -- PARTY, RAID, or SAY
                audio = false,
                audioFile = SOUNDKIT.RAID_WARNING or 8959,
                screen = false
            }
        }
    else
        -- Ensure alerts table exists (for backward compatibility)
        if not SnitchDB.modules[moduleId].alerts then
            SnitchDB.modules[moduleId].alerts = {
                console = true,
                chat = false,
                chatType = "PARTY",
                audio = false,
                audioFile = SOUNDKIT.RAID_WARNING or 8959,
                screen = false
            }
        end
    end
end

-- ============================================================================
-- Utility Functions
-- ============================================================================

local function DebugPrint(...)
    if SnitchDB and SnitchDB.debug then
        print("|cff00ff00[Snitch Debug]|r", ...)
    end
end

Snitch.DebugPrint = DebugPrint

local function GetCurrentGroup()
    if IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
    return nil
end

local function IsInSupportedGroup()
    return IsInRaid() or IsInGroup()
end

-- ============================================================================
-- Alert System
-- ============================================================================

local function SendAlert(message, moduleId)
    -- Guard clauses
    if not SnitchDB or not SnitchDB.enabled then
        DebugPrint("Alert blocked: Addon globally disabled")
        return
    end

    if not IsInSupportedGroup() then
        DebugPrint("Alert blocked: Not in a group")
        return
    end

    -- Check if module is enabled and get its settings
    local moduleSettings = SnitchDB.modules[moduleId]
    if not moduleSettings or not moduleSettings.enabled then
        DebugPrint(string_format("Alert blocked: Module %s disabled", moduleId))
        return
    end

    -- Get module-specific alert settings
    local alerts = moduleSettings.alerts
    if not alerts then
        DebugPrint(string_format("Alert blocked: Module %s has no alert settings", moduleId))
        return
    end

    DebugPrint("Sending alert:", message)

    -- Console output
    if alerts.console then
        print(string_format("|cffff6600[Snitch]|r %s", message))
    end

    -- Chat output
    if alerts.chat then
        local chatType = alerts.chatType
        -- Validate chat type based on current group
        if chatType == "RAID" and not IsInRaid() then
            chatType = "PARTY"
        end
        if chatType == "PARTY" and not IsInGroup() then
            chatType = "SAY"
        end

        -- Delay to avoid protected frame issues
        C_Timer.After(0.1, function()
            local success, err = pcall(SendChatMessage, message, chatType)
            if not success then
                DebugPrint("Failed to send chat message:", err)
            end
        end)
    end

    -- Audio alert
    if alerts.audio and alerts.audioFile then
        local success, err = pcall(PlaySound, alerts.audioFile)
        if not success then
            DebugPrint("Failed to play sound:", err)
        end
    end

    -- Screen warning
    if alerts.screen then
        if Snitch.ScreenAlert then
            local success, err = pcall(Snitch.ScreenAlert.Show, Snitch.ScreenAlert, message)
            if not success then
                DebugPrint("Failed to show screen warning:", err)
            end
        else
            DebugPrint("Screen alert system not loaded")
        end
    end
end

Snitch.SendAlert = SendAlert

-- ============================================================================
-- Event Handling
-- ============================================================================

local frame = CreateFrame("Frame")
local combatLogFrame = CreateFrame("Frame")

-- Handle ADDON_LOADED
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            InitializeSettings()

            -- Initialize all modules
            for moduleId, module in pairs(Snitch.modules) do
                -- Initialize module settings with default alerts
                InitializeModuleSettings(moduleId)

                -- Run module-specific initialization
                if module.initialize then
                    module.initialize()
                end
            end

            -- Initialize screen alert system
            if Snitch.ScreenAlert then
                Snitch.ScreenAlert:Initialize()
            end

            -- Register config panel
            if Snitch.Config then
                Snitch.Config:RegisterInterfaceOptions()
            end

            print("Snitch v" .. Snitch.VERSION .. " loaded. Type /snitch to configure.")
            DebugPrint("Loaded with", #Snitch.modules, "modules")
        end
    end
end)

-- Handle COMBAT_LOG_EVENT_UNFILTERED
combatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatLogFrame:SetScript("OnEvent", function(_, event)
    -- Early returns for performance
    if not SnitchDB or not SnitchDB.enabled then return end
    if not IsInSupportedGroup() then return end

    -- Get combat log info
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()

    -- Filter: Only process events from players
    if not sourceName then return end

    -- Filter: Only process events from group members
    -- Check both party and raid efficiently
    local inGroup = UnitInParty(sourceName) or UnitInRaid(sourceName)
    if not inGroup then return end

    -- Pass to enabled modules
    local modules = Snitch.modules
    local moduleSettings = SnitchDB.modules

    for moduleId, module in pairs(modules) do
        if module.onCombatLogEvent then
            local settings = moduleSettings[moduleId]
            if settings and settings.enabled then
                -- Protected call to prevent module errors from breaking the addon
                local success, err = pcall(module.onCombatLogEvent, subevent, sourceGUID,
                                          sourceName, sourceFlags, destGUID, destName,
                                          destFlags, ...)
                if not success then
                    DebugPrint(string_format("Error in module %s: %s", moduleId, err))
                end
            end
        end
    end
end)

-- ============================================================================
-- Module Event Passthrough (for non-combat-log events)
-- ============================================================================

function Snitch:RegisterModuleEvent(moduleId, event)
    if not self.modules[moduleId] then
        print("Snitch: Cannot register event for unknown module: " .. moduleId)
        return
    end

    frame:RegisterEvent(event)

    -- Store which modules are listening to which events
    self.moduleEvents = self.moduleEvents or {}
    self.moduleEvents[event] = self.moduleEvents[event] or {}
    table.insert(self.moduleEvents[event], moduleId)
end

-- Update frame event handler to pass events to modules
local originalOnEvent = frame:GetScript("OnEvent")
frame:SetScript("OnEvent", function(self, event, ...)
    -- Call original handler first
    if event == "ADDON_LOADED" then
        originalOnEvent(self, event, ...)
    end

    -- Pass to modules that registered for this event
    if Snitch.moduleEvents and Snitch.moduleEvents[event] then
        for _, moduleId in ipairs(Snitch.moduleEvents[event]) do
            local module = Snitch.modules[moduleId]
            if module and module.onEvent then
                local moduleSettings = SnitchDB.modules[moduleId]
                if moduleSettings and moduleSettings.enabled then
                    module.onEvent(event, ...)
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
        if Snitch.Config then
            Snitch.Config:Toggle()
        end

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
        print("Snitch debug mode " .. (SnitchDB.debug and "enabled" or "disabled") .. ".")

    elseif msg == "status" then
        local groupType = GetCurrentGroup() or "none"
        print("Snitch Status:")
        print("  Global Enabled:", SnitchDB.enabled and "ON" or "OFF")
        print("  Version:", Snitch.VERSION)
        print("  Group Type:", groupType)
        print("  Debug:", SnitchDB.debug and "ON" or "OFF")
        print("")
        print("Modules:")
        for moduleId, module in pairs(Snitch.modules) do
            local settings = SnitchDB.modules[moduleId]
            if settings then
                local status = settings.enabled and "ON" or "OFF"
                print("  [" .. module.name .. "]", status)
                if settings.alerts then
                    local alerts = settings.alerts
                    print("    Alerts: Console=" .. (alerts.console and "ON" or "OFF") ..
                          ", Chat=" .. (alerts.chat and "ON" or "OFF") .. " (" .. alerts.chatType .. ")" ..
                          ", Audio=" .. (alerts.audio and "ON" or "OFF") ..
                          ", Screen=" .. (alerts.screen and "ON" or "OFF"))
                end
            end
        end

    else
        print("Snitch commands:")
        print("  /snitch - Open config panel")
        print("  /snitch version")
        print("  /snitch on")
        print("  /snitch off")
        print("  /snitch debug")
        print("  /snitch status")
    end
end
