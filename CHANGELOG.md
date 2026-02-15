# Changelog

All notable changes to Snitch will be documented in this file.

## [0.1.0] - 2026-02-15

### Added
- Initial release
- Core addon framework with modular architecture

- **Per-Module Alert Configuration**:
  - Each module has independent alert settings
  - Global master switch to enable/disable entire addon
  - Configure console, chat, audio, and screen alerts separately for each module
  - Example: SwapBlaster can use audio + screen, Life Grip can use console only

- **SwapBlaster Detection Module**:
  - Alerts when someone starts casting SwapBlaster
  - Alerts on successful cast
  - Alerts on cancelled or interrupted cast
  - Identifies cast target
  - **Detects Neurosilencer buff on target** (warns if swap will be blocked)
  - Reports block status on successful cast completion

- **Life Grip Detection Module**:
  - Alerts when a priest uses Life Grip (Leap of Faith) while out of combat
  - Identifies who is being gripped
  - Only triggers for out-of-combat usage
  - Reports cast start, success, and cancellation

- **Alert System**:
  - Console output
  - Chat messages (/say, /party, /raid) - configurable per module
  - Audio alerts with 5 customizable sounds - configurable per module
  - **Fully customizable screen warnings**:
    - Adjustable font (4 font options)
    - Adjustable font size (16-72)
    - Custom positioning via drag-and-drop
    - Configurable display duration (1-10 seconds)
    - Optional background
    - Screen appearance is global, per-module on/off control
    - Settings saved per character
- Configuration UI
  - Enable/disable addon globally
  - Enable/disable individual modules
  - Configure alert preferences
  - Test audio alerts
- Slash commands:
  - `/snitch` - Open configuration
  - `/snitch version` - Show version
  - `/snitch on/off` - Enable/disable
  - `/snitch debug` - Toggle debug mode
  - `/snitch status` - Show detailed status
- Performance optimizations:
  - Localized globals
  - Efficient combat log filtering
  - Protected calls for error handling
  - Name caching to reduce string operations
- Only active when in a party or raid group
- Debug mode for troubleshooting

### Technical
- Modular architecture for easy addition of new detection modules
- Single source of truth for version (reads from .toc)
- Best practices for WoW addon development
- Clean separation of core logic, config UI, and modules
