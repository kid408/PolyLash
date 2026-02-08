# Character Weapon Assignment System - Design

## Executive Summary

The weapon assignment system is **ALREADY CORRECTLY IMPLEMENTED** in the code. The issue is that `player_weapons.csv` and `player_available_weapons.csv` are **OUT OF SYNC**.

### Current State
- ✅ Selection screen correctly saves weapons to `Global.selected_player_weapons`
- ✅ Player loading correctly reads from `Global.selected_player_weapons`
- ❌ `player_weapons.csv` contains outdated data (all characters have punch)
- ❌ `player_available_weapons.csv` has correct weapon assignments but missing 2 characters

### Root Cause
The `assign_character_weapons.gd` tool was run and updated `player_available_weapons.csv`, but `player_weapons.csv` was never updated to match.

## System Architecture

### Data Flow (Current - CORRECT)

```
┌─────────────────────────────────────────────────────────────┐
│                    Character Selection                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ├─ Read: player_available_weapons.csv
                              │  (defines selectable weapon types)
                              │
                              ├─ User selects weapon
                              │
                              ├─ Save: user://player_weapon_cache.json
                              │  (local persistence)
                              │
                              └─ Save: Global.selected_player_weapons
                                 (runtime state)
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────┐
│                      Game Loading                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ├─ Read: Global.selected_player_weapons ✅
                              │  (NOT player_weapons.csv)
                              │
                              └─ Load weapon scene
```

### File Roles

| File | Purpose | Status |
|------|---------|--------|
| `player_available_weapons.csv` | Defines which weapon TYPES each character can SELECT | ✅ Correct (26/28 characters) |
| `player_weapons.csv` | **OBSOLETE** - Originally defined equipped weapons | ❌ Outdated (all have punch) |
| `user://player_weapon_cache.json` | Local cache of user's weapon selections | ✅ Working |
| `Global.selected_player_weapons` | Runtime state of selected weapons | ✅ Working |

## Problem Analysis

### Issue 1: Missing Characters in player_available_weapons.csv
**Characters missing:**
- `tempest`
- `sapper`

**Impact:** These characters cannot be selected properly

**Solution:** Add these 2 characters to `player_available_weapons.csv`

### Issue 2: player_weapons.csv is Outdated
**Current state:** All characters have `punch_1, punch_2`

**Expected state:** Should match default weapons from `player_available_weapons.csv`

**Impact:** None (file is not used by game code)

**Solution:** Update for consistency, or mark as deprecated

## Design Decisions

### Decision 1: Keep player_weapons.csv for Backward Compatibility
**Rationale:**
- Some tools may still reference it
- Low cost to maintain
- Provides fallback if needed

**Implementation:**
- Update `player_weapons.csv` to match `player_available_weapons.csv`
- Add comment header indicating it's deprecated
- Update `assign_character_weapons.gd` to output to both files

### Decision 2: Complete Missing Character Assignments
**Rationale:**
- User requested 28 characters with weapon assignments
- Currently only 26 characters are configured
- Need to assign weapons to `tempest` and `sapper`

**Implementation:**
- Assign unique default weapons to missing characters
- Ensure no weapon type conflicts with existing characters
- Follow same pattern as other characters (3 weapons each)

### Decision 3: Validate Weapon Assignments
**Rationale:**
- Prevent future sync issues
- Ensure all weapons exist in weapon_config_optimized.csv
- Verify no duplicate default weapons

**Implementation:**
- Add validation function to `assign_character_weapons.gd`
- Check weapon existence
- Check default weapon uniqueness
- Report any issues

## Technical Design

### Component 1: Update assign_character_weapons.gd

**Purpose:** Generate consistent weapon assignments for all 28 characters

**Changes:**
1. Add missing characters (`tempest`, `sapper`)
2. Output to both CSV files
3. Add validation logic
4. Add deprecation notice for `player_weapons.csv`

**Validation Rules:**
- All 28 characters must have assignments
- Default weapons (weapon_type_1) must be unique
- All weapon types must exist in `weapon_config_optimized.csv`
- Each character must have at least 3 weapons

### Component 2: Weapon Assignment Strategy

**Character Categories:**
- **重装 (Colossus)** - 7 characters - Heavy melee weapons
- **魔导 (Inkborn)** - 7 characters - Magic/energy weapons
- **游侠 (Nomad)** - 7 characters - Ranged physical weapons
- **后勤 (Alchemist)** - 7 characters - Support/heal weapons

**Available Weapons (30 total):**

**Melee (Heavy):**
- hammer_smash, mace, axe, swing_heavy, sword, chainsaw, scimitar, spear, thrust_charged, swing_cleave

**Magic:**
- wand, laser, magic_chain, magic_meteor, heal_bolt, magic_heal_aoe

**Ranged:**
- pistol, revolver, smg, shotgun, bow_arrow, single_sniper

**Special:**
- punch, dagger_flurry, circular_vortex, circular_dual, whip_lash, spread_fan, heal_bolt

**Assignment Rules:**
1. Default weapon must match character archetype
2. Additional weapons can be shared
3. Prioritize thematic fit

### Component 3: Missing Character Assignments

**tempest (游侠 - Nomad):**
- Default: `bow_arrow` (unique ranged weapon)
- Alt 1: `smg` (shared)
- Alt 2: `single_sniper` (shared)

**sapper (后勤 - Alchemist):**
- Default: `spread_fan` (unique support weapon)
- Alt 1: `magic_heal_aoe` (shared)
- Alt 2: `heal_bolt` (shared)

## Data Structures

### player_available_weapons.csv Format
```csv
player_id,weapon_type_1,weapon_type_2,weapon_type_3,weapon_type_4
-1,武器类型1,武器类型2,武器类型3,武器类型4
butcher,hammer_smash,shotgun,single_sniper,
...
```

### player_weapons.csv Format (Deprecated)
```csv
player_id,weapon_slot_1,weapon_slot_2,weapon_slot_3,weapon_slot_4,weapon_slot_5,weapon_slot_6
-1,武器槽1,武器槽2,武器槽3,武器槽4,武器槽5,武器槽6
butcher,hammer_smash_1,shotgun_1,,,,
...
```

**Note:** weapon_slot values should be `{weapon_type}_1` (level 1 instance)

## Implementation Plan

### Phase 1: Update Tool
1. Modify `assign_character_weapons.gd`
2. Add missing character assignments
3. Add validation logic
4. Add dual-output (both CSV files)

### Phase 2: Generate Files
1. Run updated tool
2. Verify output
3. Commit updated CSV files

### Phase 3: Validation
1. Test character selection screen
2. Verify weapons load correctly in-game
3. Test all 28 characters
4. Verify weapon cache persistence

### Phase 4: Documentation
1. Update `CHARACTER_WEAPON_ASSIGNMENT_GUIDE.md`
2. Add deprecation notice to `player_weapons.csv`
3. Update Chinese documentation

## Testing Strategy

### Test Cases

**TC-1: Weapon Selection Persistence**
- Select character in selection screen
- Select weapon
- Start game
- Verify character has selected weapon

**TC-2: Default Weapon Loading**
- Select character without changing weapon
- Start game
- Verify character has default weapon (weapon_type_1)

**TC-3: Weapon Cache Persistence**
- Select character and weapon
- Close game
- Reopen game
- Verify weapon selection is remembered

**TC-4: All Characters Have Weapons**
- For each of 28 characters:
  - Verify character appears in selection screen
  - Verify character has at least 3 selectable weapons
  - Verify default weapon is unique

**TC-5: Weapon Validation**
- Verify all weapon types in CSV exist in weapon_config_optimized.csv
- Verify no duplicate default weapons
- Verify no missing characters

## Edge Cases

### EC-1: Invalid Weapon Type
**Scenario:** Selected weapon type doesn't exist in weapon_config_optimized.csv

**Handling:** 
- Log error
- Fall back to first available weapon
- Don't crash

### EC-2: Missing Character in CSV
**Scenario:** Character exists in player_config.csv but not in player_available_weapons.csv

**Handling:**
- Log warning
- Use punch as default weapon
- Character still playable

### EC-3: Empty Weapon Selection
**Scenario:** Global.selected_player_weapons is empty for a character

**Handling:**
- Use weapon_type_1 from player_available_weapons.csv
- Log info message

## Performance Considerations

- CSV loading happens once at startup (acceptable)
- Weapon cache JSON is small (<1KB)
- No performance impact expected

## Security Considerations

- Local cache file is user-writable (acceptable for single-player game)
- No network transmission of weapon data
- No security concerns

## Maintenance Considerations

### Adding New Characters
1. Add to `player_config.csv`
2. Add to `player_visual.csv`
3. Run `assign_character_weapons.gd` to generate weapon assignments
4. Verify in-game

### Adding New Weapons
1. Add to `weapon_config_optimized.csv`
2. Optionally assign to characters in `player_available_weapons.csv`
3. No code changes needed

### Deprecating player_weapons.csv
**Future consideration:** Remove file entirely once confirmed unused

**Steps:**
1. Add deprecation notice (this design)
2. Monitor for 1-2 releases
3. Remove file and references
4. Remove from ConfigManager

## Success Criteria

- ✅ All 28 characters have weapon assignments
- ✅ All default weapons are unique
- ✅ Weapon selection persists across game sessions
- ✅ Weapon in selection screen matches weapon in-game
- ✅ No console errors related to weapons
- ✅ Tool generates valid CSV files
- ✅ Validation passes for all characters

## References

- `tools/assign_character_weapons.gd` - Weapon assignment tool
- `config/player/player_available_weapons.csv` - Selectable weapons
- `config/player/player_weapons.csv` - Deprecated equipped weapons
- `scenes/ui/selection_panel/selection_panel.gd` - Selection screen
- `scenes/unit/players/player_base.gd` - Weapon loading
- `autoloads/global.gd` - Global state
