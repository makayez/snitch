# Recent Updates

## Major Changes

### Per-Module Alert Configuration 🎉

**Before**: All modules shared the same alert settings (global console, chat, audio, screen settings)

**Now**: Each module has its own independent alert configuration!

**Benefits**:
- SwapBlaster can use screen + audio alerts
- Life Grip can use console output only
- Each module fully customizable

**How It Works**:
1. Global master switch (`/snitch` → "Enable Snitch") - turns entire addon on/off
2. Per-module enable/disable (module checkbox)
3. Per-module alert settings (click "Configure..." button)

### New Life Grip Module 🆕

Detects when a priest uses Life Grip (Leap of Faith) **while out of combat**.

**Features**:
- Alerts on cast start with target identification
- Reports successful grips
- Reports cancelled/interrupted casts
- **Only triggers out of combat** (legitimate in-combat usage is ignored)

**Spell ID**: 73325 (verify in-game, may need adjustment)

## Configuration UI Changes

### Main Config Panel
```
/snitch
├── Global Enable/Disable (master switch)
└── Modules:
    ├── [✓] SwapBlaster Detector [Configure...]
    └── [✓] Life Grip Detector [Configure...]
```

### Per-Module Config Panel
Click "Configure..." next to any module:
```
Module Name - Alert Configuration
├── [ ] Console output
├── [ ] Chat message
│   └── Chat type: [Party ▼]
├── [ ] Audio alert
│   ├── Sound: [Raid Warning ▼]
│   └── [Test] button
└── [ ] Screen warning
    └── [Appearance...] button (global screen settings)
```

### Screen Alert Appearance Panel
Accessed from any module's config:
- Font selection (4 fonts)
- Font size (16-72)
- Display duration (1-10 seconds)
- Background on/off
- [Reposition Alert] button
- [Test Alert] button

**Note**: Screen appearance (font, size, position) is **global** - affects all modules. Each module controls whether to **show** screen alerts.

## Data Structure Changes

### SavedVariables Format

**Before**:
```lua
SnitchDB = {
  enabled = true,
  alerts = {  -- Global alerts
    console = true,
    chat = false,
    ...
  },
  modules = {
    swapblaster = {
      enabled = true
    }
  }
}
```

**After**:
```lua
SnitchDB = {
  enabled = true,  -- Global master switch
  modules = {
    swapblaster = {
      enabled = true,
      alerts = {  -- Per-module alerts!
        console = true,
        chat = false,
        chatType = "PARTY",
        audio = false,
        audioFile = 8959,
        screen = false
      }
    },
    lifegrip = {
      enabled = true,
      alerts = {
        console = true,
        chat = false,
        ...
      }
    }
  },
  screenAlert = {  -- Global screen appearance
    fontSize = 32,
    font = 1,
    ...
  }
}
```

## Command Changes

### `/snitch status` Output

**Before**:
```
Snitch Status:
  Enabled: ON
  Version: 0.1.0
  ...
Modules:
  [SwapBlaster Detector] ON
Alerts:
  Console: ON
  Chat: OFF
  ...
```

**After**:
```
Snitch Status:
  Global Enabled: ON
  Version: 0.1.0
  ...
Modules:
  [SwapBlaster Detector] ON
    Alerts: Console=ON, Chat=OFF (PARTY), Audio=OFF, Screen=ON
  [Life Grip Detector] ON
    Alerts: Console=ON, Chat=OFF (PARTY), Audio=OFF, Screen=OFF
```

## Migration / Compatibility

**Good News**: If you have existing settings, the addon will:
1. Initialize per-module alert settings with defaults
2. Keep your existing module enable/disable states
3. Not break or lose any existing configuration

**First Time Opening Config**:
- Each module will have default alerts (console=ON, others=OFF)
- You can customize each module independently
- Settings save automatically

## Testing Checklist

1. **Existing Settings**:
   - [ ] Load addon with existing SnitchDB
   - [ ] Verify modules still enabled/disabled correctly
   - [ ] Open config, verify per-module settings initialized

2. **SwapBlaster Module**:
   - [ ] Open SwapBlaster config
   - [ ] Enable screen + audio
   - [ ] Trigger SwapBlaster alert
   - [ ] Verify both screen and audio work

3. **Life Grip Module**:
   - [ ] Open Life Grip config
   - [ ] Enable console only
   - [ ] Have a priest use Life Grip out of combat
   - [ ] Verify console alert appears
   - [ ] Verify no screen/audio (if disabled)

4. **Global Master Switch**:
   - [ ] Disable addon globally
   - [ ] Try to trigger any module
   - [ ] Verify no alerts appear
   - [ ] Re-enable, verify alerts work again

5. **Screen Appearance**:
   - [ ] Open screen config (from any module)
   - [ ] Change font size
   - [ ] Reposition alert
   - [ ] Test alert
   - [ ] Verify changes apply to all modules

## File Changes

### Modified:
- `Core.lua` - Updated to support per-module alerts
- `Config.lua` - Complete UI redesign for per-module config
- `Snitch.toc` - Added Life Grip module

### Added:
- `Modules/LifeGrip.lua` - New Life Grip detection module
- `UPDATES.md` - This file

### Unchanged:
- `ScreenAlert.lua` - No changes needed
- `Modules/SwapBlaster.lua` - No changes needed (works with new system)

## Spell IDs to Verify

Before testing, verify these spell IDs in-game:

**Life Grip**: 73325
- Have a priest check their spellbook
- Use `/dump C_Spell.GetSpellInfo(73325)`
- Update `LIFEGRIP_SPELL_IDS` in `Modules/LifeGrip.lua` if needed

**SwapBlaster**: 470116 (already in code)
- Use toy and check combat log
- Update `SWAPBLASTER_SPELL_IDS` in `Modules/SwapBlaster.lua` if needed

**Neurosilencer**: 470344 (already in code)
- Find someone with buff active
- Update `NEUROSILENCER_SPELL_IDS` in `Modules/SwapBlaster.lua` if needed

## Summary

✅ Per-module alert configuration implemented
✅ Life Grip detection module added
✅ Configuration UI redesigned
✅ Data structure updated
✅ `/snitch status` enhanced
✅ Backward compatible
✅ Documentation updated

**Ready for testing!**
