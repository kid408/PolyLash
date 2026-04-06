# Character Weapon Assignment System - Tasks

## Overview
Fix weapon assignment system by completing missing character assignments and synchronizing CSV files.

## Task List

### 1. Analysis and Validation
- [ ] 1.1 Verify current weapon assignments in player_available_weapons.csv
- [ ] 1.2 Identify missing characters (tempest, diva)
- [ ] 1.3 List all available weapon types from weapon_config_optimized.csv
- [ ] 1.4 Verify no duplicate default weapons exist

### 2. Update Weapon Assignment Tool
- [ ] 2.1 Modify `tools/assign_character_weapons.gd` to add missing characters
  - Add tempest with unique default weapon
  - Add diva with unique default weapon
  - Ensure 3 weapons per character
- [ ] 2.2 Add validation function to check weapon assignments
  - Verify all weapon types exist in weapon_config_optimized.csv
  - Verify all default weapons are unique
  - Verify all 28 characters have assignments
- [ ] 2.3 Add dual-output functionality
  - Output to player_available_weapons.csv (weapon types)
  - Output to player_weapons.csv (weapon instances with _1 suffix)
  - Add deprecation notice to player_weapons.csv header

### 3. Generate Updated CSV Files
- [ ] 3.1 Run updated assign_character_weapons.gd tool
- [ ] 3.2 Review generated player_available_weapons.csv
  - Verify all 28 characters present
  - Verify all default weapons unique
  - Verify all weapon types valid
- [ ] 3.3 Review generated player_weapons.csv
  - Verify format matches (weapon_type_1 format)
  - Verify deprecation notice present
  - Verify consistency with player_available_weapons.csv

### 4. Testing
- [ ] 4.1 Test character selection screen
  - Verify all 28 characters appear
  - Verify each character shows correct weapons
  - Verify weapon selection works
- [ ] 4.2 Test weapon loading in-game
  - Select character with default weapon
  - Verify correct weapon loads
  - Test with multiple characters
- [ ] 4.3 Test weapon selection persistence
  - Select character and weapon
  - Start game
  - Verify selected weapon loads (not default)
- [ ] 4.4 Test weapon cache persistence
  - Select weapon
  - Close game
  - Reopen game
  - Verify weapon selection remembered
- [ ] 4.5 Test missing characters (tempest, diva)
  - Verify they appear in selection screen
  - Verify they have 3 selectable weapons
  - Verify they load correctly in-game

### 5. Documentation
- [ ] 5.1 Update `tools/CHARACTER_WEAPON_ASSIGNMENT_GUIDE.md`
  - Document new tool features
  - Document validation rules
  - Add troubleshooting section
- [ ] 5.2 Update `角色武器配置说明.md` (Chinese documentation)
  - Translate new features
  - Add examples
- [ ] 5.3 Add deprecation notice to player_weapons.csv
  - Add comment header explaining file is deprecated
  - Explain that Global.selected_player_weapons is used instead
- [ ] 5.4 Create completion summary document
  - List all changes made
  - Document test results
  - Provide usage instructions

## Task Dependencies

```
1.1 → 1.2 → 1.3 → 1.4
         ↓
2.1 → 2.2 → 2.3
         ↓
3.1 → 3.2 → 3.3
         ↓
4.1 → 4.2 → 4.3 → 4.4 → 4.5
         ↓
5.1 → 5.2 → 5.3 → 5.4
```

## Detailed Task Descriptions

### Task 1.1: Verify Current Weapon Assignments
**Goal:** Understand current state of weapon assignments

**Steps:**
1. Read `config/player/player_available_weapons.csv`
2. Count number of characters (should be 26, missing 2)
3. List all default weapons (weapon_type_1)
4. Check for duplicates

**Expected Output:**
- List of 26 characters with their default weapons
- Identification of 2 missing characters

### Task 1.2: Identify Missing Characters
**Goal:** Determine which characters need weapon assignments

**Steps:**
1. Read `config/player/player_config.csv` to get all 28 characters
2. Compare with `player_available_weapons.csv`
3. Identify missing characters

**Expected Output:**
- List of missing characters: `tempest`, `diva`

### Task 1.3: List Available Weapon Types
**Goal:** Know which weapons can be assigned

**Steps:**
1. Read `config/weapon/weapon_config_optimized.csv`
2. Extract unique weapon_base_id values
3. Categorize by type (melee, magic, ranged, support)

**Expected Output:**
- List of 30+ weapon types
- Categorization by weapon class

### Task 1.4: Verify No Duplicate Default Weapons
**Goal:** Ensure each character has unique default weapon

**Steps:**
1. Extract weapon_type_1 from all characters
2. Check for duplicates
3. Report any conflicts

**Expected Output:**
- Confirmation that all default weapons are unique
- OR list of duplicate weapons to fix

### Task 2.1: Add Missing Characters to Tool
**Goal:** Update tool to assign weapons to tempest and diva

**Steps:**
1. Open `tools/assign_character_weapons.gd`
2. Find weapon assignment logic
3. Add tempest assignment:
   - Default: bow_arrow (unique ranged)
   - Alt 1: smg
   - Alt 2: single_sniper
4. Add diva assignment:
   - Default: spread_fan (unique support)
   - Alt 1: magic_heal_aoe
   - Alt 2: heal_bolt

**Expected Output:**
- Updated tool with 28 character assignments

### Task 2.2: Add Validation Function
**Goal:** Prevent invalid weapon assignments

**Steps:**
1. Create `validate_assignments()` function
2. Check all weapon types exist in weapon_config_optimized.csv
3. Check all default weapons are unique
4. Check all 28 characters have assignments
5. Print validation report

**Expected Output:**
- Validation function that reports any issues

### Task 2.3: Add Dual-Output Functionality
**Goal:** Generate both CSV files from single tool run

**Steps:**
1. Create `generate_player_weapons_csv()` function
2. Convert weapon types to weapon instances (add _1 suffix)
3. Format as player_weapons.csv
4. Add deprecation notice header
5. Write to file

**Expected Output:**
- Tool generates both CSV files
- player_weapons.csv has deprecation notice

### Task 3.1: Run Updated Tool
**Goal:** Generate new CSV files

**Steps:**
1. Open Godot editor
2. Attach `assign_character_weapons.gd` to a node
3. Run scene
4. Check console output for validation results
5. Verify files generated

**Expected Output:**
- Updated `player_available_weapons.csv`
- Updated `player_weapons.csv`
- Validation report in console

### Task 3.2: Review player_available_weapons.csv
**Goal:** Verify generated file is correct

**Steps:**
1. Open `config/player/player_available_weapons.csv`
2. Count rows (should be 28 + 2 header rows = 30)
3. Verify tempest and diva present
4. Verify all weapon types valid
5. Verify no duplicate default weapons

**Expected Output:**
- Confirmation that file is correct

### Task 3.3: Review player_weapons.csv
**Goal:** Verify deprecated file is consistent

**Steps:**
1. Open `config/player/player_weapons.csv`
2. Verify deprecation notice in header
3. Verify weapon format (weapon_type_1 not weapon_type)
4. Verify consistency with player_available_weapons.csv

**Expected Output:**
- Confirmation that file is correct and consistent

### Task 4.1: Test Character Selection Screen
**Goal:** Verify UI shows all characters and weapons

**Steps:**
1. Run game
2. Open character selection screen
3. Scroll through all characters
4. Verify 28 characters visible
5. Click each character
6. Verify weapons display correctly
7. Verify tempest and diva present

**Expected Output:**
- All 28 characters visible
- All weapons display correctly
- No console errors

### Task 4.2: Test Weapon Loading In-Game
**Goal:** Verify weapons load correctly

**Steps:**
1. Select butcher (default: hammer_smash)
2. Don't change weapon
3. Start game
4. Verify butcher has hammer_smash weapon
5. Repeat for 2-3 other characters

**Expected Output:**
- Characters have correct default weapons
- No console errors

### Task 4.3: Test Weapon Selection Persistence
**Goal:** Verify selected weapon loads (not default)

**Steps:**
1. Select butcher
2. Change weapon to shotgun
3. Start game
4. Verify butcher has shotgun (not hammer_smash)

**Expected Output:**
- Selected weapon loads correctly
- Console shows: "Global.selected_player_weapons = {butcher: shotgun}"

### Task 4.4: Test Weapon Cache Persistence
**Goal:** Verify weapon selection persists across sessions

**Steps:**
1. Select butcher
2. Change weapon to shotgun
3. Close game
4. Reopen game
5. Open selection screen
6. Click butcher
7. Verify shotgun is highlighted

**Expected Output:**
- Weapon selection remembered
- Console shows: "从缓存获取武器: shotgun"

### Task 4.5: Test Missing Characters
**Goal:** Verify tempest and diva work correctly

**Steps:**
1. Select tempest
2. Verify 3 weapons available
3. Verify default is bow_arrow
4. Start game with default weapon
5. Verify tempest has bow_arrow
6. Repeat for diva (default: spread_fan)

**Expected Output:**
- Both characters work correctly
- Correct weapons load

### Task 5.1: Update English Documentation
**Goal:** Document new tool features

**Steps:**
1. Open `tools/CHARACTER_WEAPON_ASSIGNMENT_GUIDE.md`
2. Add section on validation
3. Add section on dual-output
4. Add troubleshooting section
5. Add examples

**Expected Output:**
- Updated documentation

### Task 5.2: Update Chinese Documentation
**Goal:** Translate documentation for Chinese users

**Steps:**
1. Open `角色武器配置说明.md`
2. Translate new sections
3. Add examples
4. Verify formatting

**Expected Output:**
- Updated Chinese documentation

### Task 5.3: Add Deprecation Notice
**Goal:** Mark player_weapons.csv as deprecated

**Steps:**
1. Open `config/player/player_weapons.csv`
2. Add comment header:
   ```
   # DEPRECATED: This file is no longer used by the game
   # Weapon selection is handled by Global.selected_player_weapons
   # This file is maintained for backward compatibility only
   ```
3. Save file

**Expected Output:**
- Deprecation notice added

### Task 5.4: Create Completion Summary
**Goal:** Document all changes and results

**Steps:**
1. Create `角色武器配置完成总结.md`
2. List all changes made
3. Document test results
4. Provide usage instructions
5. Add before/after comparison

**Expected Output:**
- Comprehensive summary document

## Acceptance Criteria

### Must Have
- ✅ All 28 characters have weapon assignments
- ✅ All default weapons are unique
- ✅ Tool validates weapon assignments
- ✅ Both CSV files generated
- ✅ Weapon selection works in-game
- ✅ Weapon cache persists across sessions

### Should Have
- ✅ Deprecation notice on player_weapons.csv
- ✅ Updated documentation (English + Chinese)
- ✅ Validation report in console
- ✅ Completion summary document

### Nice to Have
- ⭕ Automated tests for weapon loading
- ⭕ Tool GUI for easier weapon assignment
- ⭕ Weapon preview in selection screen

## Notes

- Focus on completing missing character assignments first
- Validation is critical to prevent future issues
- Test thoroughly before marking complete
- Document everything for future maintenance
