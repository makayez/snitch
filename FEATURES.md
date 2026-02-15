# Snitch - Complete Feature List

## Core Features

### Modular Architecture
- Easy to add new detection modules
- Modules register themselves with the core
- Each module can be enabled/disabled independently
- Clean separation of concerns

### SwapBlaster Detection
The initial detection module includes:

1. **Cast Detection**
   - Alerts when someone starts casting SwapBlaster
   - Reports successful casts
   - Reports cancelled/interrupted casts

2. **Target Identification**
   - Identifies who is being swapped
   - Shows target name in alerts

3. **Neurosilencer Detection** 🆕
   - Automatically checks if target has Neurosilencer buff
   - Warns in alert: "(NEUROSILENCER ACTIVE - will block!)"
   - Helps raid avoid wasted SwapBlaster attempts
   - Uses efficient aura checking

## Alert System

### Multiple Output Methods

1. **Console Output**
   - Prints to your chat window
   - Colored [Snitch] prefix for visibility
   - Toggle on/off

2. **Chat Messages**
   - Send to /say, /party, or /raid
   - Automatically adjusts based on group type
   - Toggle on/off
   - Select chat type in config

3. **Audio Alerts**
   - 5 sound options:
     - Raid Warning
     - Ready Check
     - Alarm Clock
     - Level Up
     - Achievement
   - Test button to preview sounds
   - Toggle on/off

4. **Screen Warnings** 🆕 (Fully Customizable!)
   - **NOT** the basic raid warning frame
   - Custom frame system with full control

### Screen Alert Customization 🆕

Access via: `/snitch` → "Screen warning" → "Configure..." button

**Font Options:**
- Friz Quadrata (WoW default)
- Arial
- Skurri
- Morpheus

**Font Size:**
- Range: 16-72
- Slider with live preview
- Default: 32

**Display Duration:**
- Range: 1-10 seconds
- Adjustable in 0.5s increments
- Default: 3 seconds

**Background:**
- Optional semi-transparent background
- Toggle on/off
- Helps text visibility

**Positioning:**
- Click "Reposition Alert" button
- Drag the preview frame to desired location
- Click "Done Repositioning" to save
- Position saved per character
- Default: Top center of screen

**Test Button:**
- Preview your settings instantly
- Shows sample alert with your configuration
- Safe to use anytime

## Configuration UI

### Main Config Panel
Access via: `/snitch` command

**Global Settings:**
- Enable/Disable entire addon
- Only active when in party or raid (by design)

**Alert Settings:**
- Toggle each alert type independently
- Configure chat type (say/party/raid)
- Select audio sound
- Test audio button
- Screen warning configuration button

**Module Settings:**
- Enable/Disable each detection module
- Module descriptions shown
- Future modules will appear here automatically

### Screen Alert Config Panel 🆕
Separate dedicated panel for screen customization:
- All font and display settings
- Repositioning controls
- Live test button
- Help text for guidance

## Commands

```
/snitch          - Open main config
/snitch version  - Show addon version
/snitch on       - Enable addon
/snitch off      - Disable addon
/snitch debug    - Toggle debug mode
/snitch status   - Show detailed status
```

## Technical Highlights

### Performance Optimizations
- Localized globals for faster access
- Efficient combat log filtering
- Early returns to minimize processing
- Name caching to reduce string operations
- Aura checking uses modern API when available

### Error Handling
- Protected calls (pcall) for all risky operations
- Module errors don't crash the addon
- Graceful degradation
- Debug mode for troubleshooting

### Best Practices
- Single source of truth for version (reads from .toc)
- Settings persistence via SavedVariables
- Clean code organization
- Comprehensive inline documentation
- Consistent naming conventions

## How It Works

### Detection Flow
1. Player in your group uses SwapBlaster
2. Combat log event fires
3. Snitch filters event (is it SwapBlaster? is player in group?)
4. SwapBlaster module processes event
5. Module checks target for Neurosilencer
6. Module formats alert message
7. Core sends alert to all enabled output methods

### Alert Flow
1. Module calls `Snitch.SendAlert(message, moduleId)`
2. Core validates:
   - Is addon enabled?
   - Are you in a group?
   - Is this module enabled?
3. If valid, sends to all enabled alert types:
   - Console: Prints to chat
   - Chat: Delays 0.1s, sends via SendChatMessage
   - Audio: Plays selected sound
   - Screen: Shows in custom alert frame
4. Each output wrapped in pcall for safety

## Setup Requirements

### Finding Spell IDs

**SwapBlaster:**
1. Enable debug: `/snitch debug`
2. Use the toy yourself
3. Check combat log or debug output
4. Update `SWAPBLASTER_SPELL_IDS` in `Modules/SwapBlaster.lua`

**Neurosilencer:**
1. Find someone with the buff
2. `/dump` their buffs or check combat log
3. Update `NEUROSILENCER_SPELL_IDS` in `Modules/SwapBlaster.lua`

The addon includes example IDs but these **must be verified** in your game version.

## Future Module Ideas

The architecture supports easy addition of:
- Hunter pet detection (not present/passive)
- Low durability warnings
- Consumable tracking
- Cooldown monitoring
- Position checking
- Buff/debuff alerts
- Any combat log event

## FAQ

**Q: Why don't I see alerts when solo?**
A: Addon only works in party/raid groups by design.

**Q: Can I move the screen alert?**
A: Yes! Open screen config, click "Reposition Alert", drag it, click "Done".

**Q: Can I change the text color?**
A: Not yet, but the architecture supports it. Easy to add if requested.

**Q: Will this cause lag?**
A: No. Heavily optimized with localized globals, efficient filtering, and minimal processing.

**Q: Can I see Edit Mode integration?**
A: Basic Edit Mode registration is implemented but full integration would require more development.

**Q: How do I add a new module?**
A: See `Modules/SwapBlaster.lua` as template. Create new file, register module, add to .toc, reload.

## File Structure

```
snitch/
├── Snitch.toc           - Addon descriptor & file list
├── Core.lua             - Main framework & alert system
├── ScreenAlert.lua      - Custom screen alert system 🆕
├── Config.lua           - Main configuration UI
├── Modules/
│   └── SwapBlaster.lua  - SwapBlaster detection module
├── README.md            - User documentation
├── CHANGELOG.md         - Version history
├── TESTING.md           - Testing guide
├── FEATURES.md          - This file
├── PROJECT_SUMMARY.md   - Technical overview
└── .gitignore           - Git ignore rules
```

## Summary

Snitch is a production-ready, highly customizable addon for monitoring group member actions. The initial SwapBlaster module demonstrates the system's capabilities:

✅ Accurate detection via combat log
✅ Target identification
✅ Neurosilencer buff detection
✅ Multiple alert methods
✅ Fully customizable screen alerts
✅ Drag-and-drop positioning
✅ Performance optimized
✅ Error handling
✅ Easy to extend
✅ Well documented
✅ User-friendly configuration

The modular architecture makes adding new detection modules straightforward while maintaining code quality and performance.
