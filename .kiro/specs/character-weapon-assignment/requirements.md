# Character Weapon Assignment System - Requirements

## Overview
Fix the weapon assignment system so that weapons selected in the character selection screen are correctly loaded when entering the game.

## Problem Statement
Currently, there is a mismatch between the weapon shown in the selection screen and the weapon the character has in-game:
- Selection screen shows one weapon (e.g., sword for butcher)
- In-game character has a different weapon (e.g., gun)

## Root Cause
1. `player_available_weapons.csv` defines which weapon TYPES each character can SELECT
2. `player_weapons.csv` defines which weapon INSTANCES each character currently has EQUIPPED
3. Selection screen saves selected weapons to `Global.selected_player_weapons` (runtime only)
4. Game loading code reads from `player_weapons.csv` instead of `Global.selected_player_weapons`

## User Stories

### 1. Weapon Selection Persistence
**As a** player  
**I want** the weapon I select in the character selection screen to be the weapon my character uses in-game  
**So that** my weapon choice is respected

**Acceptance Criteria:**
- 1.1 When I select a weapon for a character in the selection screen, that weapon is saved
- 1.2 When I start the game, my character has the weapon I selected
- 1.3 The weapon shown in selection screen matches the weapon in-game

### 2. Default Weapon Assignment
**As a** developer  
**I want** each character to have a unique default weapon  
**So that** characters have distinct identities

**Acceptance Criteria:**
- 2.1 Each character has a unique default weapon (weapon_type_1 in player_available_weapons.csv)
- 2.2 Default weapons are never shared between characters
- 2.3 Each character has at least 3 selectable weapons total

### 3. Weapon Cache Persistence
**As a** player  
**I want** my weapon selections to be remembered between game sessions  
**So that** I don't have to reselect weapons every time

**Acceptance Criteria:**
- 3.1 Weapon selections are saved to local storage
- 3.2 Weapon selections persist across game restarts
- 3.3 Weapon cache is loaded when selection screen opens

## Current System Analysis

### Files Involved
1. **`config/player/player_available_weapons.csv`** - Defines selectable weapon TYPES
2. **`config/player/player_weapons.csv`** - Defines equipped weapon INSTANCES (OUTDATED)
3. **`scenes/ui/selection_panel/selection_panel.gd`** - Selection screen logic
4. **`autoloads/player_factory.gd`** - Player creation logic
5. **`autoloads/global.gd`** - Global state management
6. **`user://player_weapon_cache.json`** - Local weapon selection cache

### Data Flow (Current - BROKEN)
```
Selection Screen:
  player_available_weapons.csv → Display weapons → User selects → player_weapon_cache.json
                                                                 → Global.selected_player_weapons

Game Loading:
  player_weapons.csv → PlayerFactory → Player instance
  (IGNORES Global.selected_player_weapons!)
```

### Data Flow (Target - FIXED)
```
Selection Screen:
  player_available_weapons.csv → Display weapons → User selects → player_weapon_cache.json
                                                                 → Global.selected_player_weapons

Game Loading:
  Global.selected_player_weapons → PlayerFactory → Player instance
  (player_weapons.csv becomes OBSOLETE)
```

## Technical Requirements

### TR-1: Update player_weapons.csv to match player_available_weapons.csv
- Sync default weapons between the two files
- Ensure all 28 characters have correct default weapons

### TR-2: Fix PlayerFactory to read from Global.selected_player_weapons
- Modify `player_factory.gd` to use `Global.selected_player_weapons` instead of `player_weapons.csv`
- Add fallback to `player_available_weapons.csv` if no selection exists

### TR-3: Verify weapon loading in player scripts
- Check `player_base.gd` to ensure it uses the correct weapon source
- Verify weapon instantiation logic

### TR-4: Update assign_character_weapons.gd tool
- Modify tool to output to BOTH files for backward compatibility
- Add validation to ensure consistency

## Non-Functional Requirements

### Performance
- Weapon loading should not add noticeable delay to game start
- Cache operations should be fast (<100ms)

### Reliability
- System should gracefully handle missing weapon data
- Fallback to default weapon if selected weapon is invalid

### Maintainability
- Clear separation between "available weapons" and "selected weapons"
- Well-documented data flow

## Out of Scope
- Adding new weapons
- Changing weapon balance
- Modifying weapon upgrade system
- Character creation/deletion

## Dependencies
- Godot 4.x
- Existing weapon system
- Existing character system
- ConfigManager autoload
- Global autoload

## Constraints
- Must maintain backward compatibility with existing save files
- Cannot break existing weapon functionality
- Must work with current CSV structure

## Success Metrics
- ✅ Weapon in selection screen matches weapon in-game (100% accuracy)
- ✅ All 28 characters have unique default weapons
- ✅ Weapon selections persist across game restarts
- ✅ No weapon-related errors in console

## References
- Context transfer summary (weapon assignment system section)
- `tools/CHARACTER_WEAPON_ASSIGNMENT_GUIDE.md`
- `角色武器配置说明.md`
