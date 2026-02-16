-- EventListener.lua
-- Must be FIRST in the TOC. No logic. Just RegisterEvent.

Snitch = Snitch or {}

Snitch.eventFrame = CreateFrame("Frame")
Snitch.eventFrame:RegisterEvent("ADDON_LOADED")
Snitch.eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
Snitch.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
Snitch.eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
Snitch.eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
