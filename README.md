# Snitch

A World of Warcraft addon that alerts when group members perform certain actions while grouped.

## Features

### Current Modules

- **SwapBlaster Detector**:
  - Alerts when someone uses the SwapBlaster toy
  - Reports cast start, success, and cancellation
  - Identifies the target of the swap
  - Detects if target has Neurosilencer buff (which blocks the swap)

- **Life Grip Detector**:
  - Alerts when a priest uses Life Grip (Leap of Faith) while out of combat
  - Reports cast start, success, and cancellation
  - Identifies who is being gripped
  - Only triggers for out-of-combat usage (legitimate in-combat usage is ignored)

### Planned Modules

- Hunter pet not present or set to passive
- Low durability warnings
- Additional behavior monitoring

## Alert Options

Snitch provides **per-module** alert configuration. Each module can have its own alert preferences:

- **Console Output**: Print messages to your chat window
- **Chat Messages**: Send alerts to /say, /party, or /raid chat (configurable per module)
- **Audio Alerts**: Play customizable sound effects when events occur (5 sounds to choose from)
- **Screen Warnings**: Fully customizable on-screen alerts with:
  - Adjustable font and font size
  - Custom positioning (drag to move)
  - Configurable display duration
  - Optional background
  - Screen appearance is global, but each module controls whether to show screen alerts

**Example**: You can configure SwapBlaster to use screen + audio alerts, while Life Grip only uses console output.

## Usage

### Installation

1. Download or clone this repository
2. Place the `snitch` folder in your `World of Warcraft/_retail_/Interface/AddOns/` directory
3. Restart WoW or reload your UI with `/reload`

### Configuration

Open the configuration panel with:
```
/snitch
```

### Commands

```
/snitch          - Open configuration panel
/snitch version  - Show addon version
/snitch on       - Enable the addon
/snitch off      - Disable the addon
/snitch debug    - Toggle debug mode
/snitch status   - Show current status and settings
```

## Module Architecture

Snitch uses a modular architecture to make adding new detection modules easy. Each module:

- Registers itself with the core addon
- Subscribes to combat log events or other WoW events
- Provides detection logic for specific behaviors
- Sends alerts through the unified alert system

### Creating a New Module

To add a new detection module:

1. Create a new file in `Modules/YourModule.lua`
2. Register the module with `Snitch:RegisterModule()`
3. Implement detection logic in event handlers
4. Add the file to `Snitch.toc`

See `Modules/SwapBlaster.lua` for a complete example.

## Technical Details

### Performance

- Localizes frequently accessed globals for improved performance
- Efficient combat log filtering to process only relevant events
- Early returns to minimize unnecessary processing
- Protected calls (pcall) to prevent module errors from breaking the addon

### Combat Log Processing

The addon only processes combat log events when:
- The addon is enabled
- You are in a party or raid group
- The event source is a member of your group

### Finding Spell IDs

To find spell IDs for new toys or abilities:

1. Use the item/toy and check your combat log
2. Use: `/dump C_ToyBox.GetToyInfo(itemID)`
3. Look up the item on Wowhead
4. Enable debug mode (`/snitch debug`) and watch the console

## Requirements

- World of Warcraft: The War Within (11.x) or later
- Intended for Midnight (12.x) where combat log changes support out-of-combat toy detection

## Development

Built following WoW addon best practices:
- Modular architecture for maintainability
- Localized globals for performance
- Error handling with pcall
- Efficient event filtering
- Clean separation of concerns

## Version

Current version is defined in `Snitch.toc`
