# Testing Guide for Snitch

## Installation for Testing

1. Copy or symlink the `snitch` directory to your WoW AddOns folder:
   ```bash
   # Create symlink (recommended for development)
   ln -s ~/projects/wow/snitch "/Applications/World of Warcraft/_retail_/Interface/AddOns/Snitch"

   # Or copy the directory
   cp -r ~/projects/wow/snitch "/Applications/World of Warcraft/_retail_/Interface/AddOns/Snitch"
   ```

2. Launch WoW and log in to a character

3. Verify the addon loaded:
   ```
   /snitch version
   ```

## Testing Checklist

### Basic Functionality

- [ ] Addon loads without errors
- [ ] `/snitch` opens configuration panel
- [ ] Configuration panel displays correctly
- [ ] All settings can be toggled on/off

### Module Testing

#### SwapBlaster Detection

Before testing, you need to find the correct spell ID:

1. Enable debug mode: `/snitch debug`
2. Use the SwapBlaster toy yourself (out of combat)
3. Check your combat log for the spell ID
4. Update `SWAPBLASTER_SPELL_IDS` in `Modules/SwapBlaster.lua` with the correct ID
5. `/reload` to reload the addon

**Test Cases:**

1. **Solo Testing (should NOT trigger)**
   - [ ] Use SwapBlaster while not in a group
   - [ ] Verify no alerts appear (addon only works in groups)

2. **Group Testing (should trigger)**
   - [ ] Form a party with at least one other player
   - [ ] Have someone use SwapBlaster
   - [ ] Verify alert appears when they start casting
   - [ ] Verify alert appears when cast completes
   - [ ] Try cancelling the cast (move or jump)
   - [ ] Verify alert appears for cancelled cast

3. **Target Detection**
   - [ ] Have someone use SwapBlaster on a specific target
   - [ ] Verify the target name appears in the alert (if possible)

### Alert Testing

Configure different alert methods and verify each works:

1. **Console Output**
   - [ ] Enable console output only
   - [ ] Trigger an event
   - [ ] Verify message appears in chat window

2. **Chat Message**
   - [ ] Enable chat message alert
   - [ ] Set to /party
   - [ ] Trigger an event
   - [ ] Verify message sent to party chat

3. **Audio Alert**
   - [ ] Enable audio alert
   - [ ] Select a sound (e.g., "Raid Warning")
   - [ ] Click "Test" button to verify sound works
   - [ ] Trigger an event
   - [ ] Verify sound plays

4. **Screen Warning**
   - [ ] Enable screen warning
   - [ ] Trigger an event
   - [ ] Verify raid-warning style message appears on screen

### Configuration Testing

- [ ] Disable addon globally, verify no alerts trigger
- [ ] Disable SwapBlaster module, verify no SwapBlaster alerts
- [ ] Test each combination of alert types
- [ ] Close and reopen config panel, verify settings persist
- [ ] `/reload`, verify settings persist across reloads

### Error Handling

- [ ] Test with invalid spell ID (should not crash)
- [ ] Test with nil values (addon should handle gracefully)
- [ ] Check for any Lua errors in the default UI error window

## Debug Mode

Enable debug mode to see detailed information:

```
/snitch debug
```

Debug output shows:
- When events are processed
- Why alerts are blocked (if disabled, not in group, etc.)
- SwapBlaster cast tracking
- Spell ID verification on module load

## Known Limitations

1. **Spell ID**: The SwapBlaster spell ID must be verified in-game and may change between expansions
2. **Group Only**: Alerts only work when in a party or raid group
3. **Target Detection**: Target detection may not always work depending on combat log events
4. **Combat Log Timing**: Out-of-combat toy usage may have limited combat log events in current expansion (designed for Midnight)

## Troubleshooting

### No alerts appearing

1. Check: `/snitch status`
   - Verify addon is enabled
   - Verify SwapBlaster module is enabled
   - Verify you're in a group
   - Verify at least one alert type is enabled

2. Enable debug mode: `/snitch debug`
   - Watch for messages explaining why alerts are blocked

3. Verify spell ID:
   - Use the toy yourself
   - Check combat log for spell ID
   - Update `Modules/SwapBlaster.lua` if needed
   - `/reload`

### Configuration not saving

- Check for Lua errors
- Verify `SnitchDB` is listed in SavedVariables in the .toc
- Try `/reload` to ensure settings are written to disk

### Addon not loading

- Check AddOns list at character select
- Look for Lua errors on login
- Verify all files are in the correct location
- Check .toc file format (no syntax errors)

## Future Module Testing

When adding new modules:

1. Add module file to `Modules/`
2. Update `Snitch.toc` to include the new file
3. Test module independently
4. Verify it integrates with alert system
5. Test enable/disable functionality
6. Document the module's behavior

## Reporting Issues

When reporting issues, include:
- WoW version
- Addon version (`/snitch version`)
- Steps to reproduce
- Expected vs actual behavior
- Debug output if relevant (`/snitch debug`)
- Any Lua errors
