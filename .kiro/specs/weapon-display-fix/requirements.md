# Weapon Display Fix - Requirements

## Overview
Fix weapon visual display issues where weapons appear too large, positioned incorrectly, and render behind the player character.

## Problem Statement
After fixing the self-damage collision layer issue, weapons now have the following display problems:
1. Weapons are too large (scale issue)
2. Weapons render behind the player character (z-index issue)
3. Weapon position may need adjustment

## User Stories

### 1. Weapon Scale
**As a player**, I want weapons to be displayed at an appropriate size relative to my character, so they look visually correct and don't obscure the character.

**Acceptance Criteria**:
- 1.1 Weapon sprites should be scaled to approximately 0.5x (50%) of their original size by default
- 1.2 Melee weapons (like punch) should be visible but not oversized
- 1.3 Range weapons should maintain proper proportions
- 1.4 Weapon scale should be configurable per weapon if needed

### 2. Weapon Z-Index (Render Order)
**As a player**, I want weapons to render in front of my character, so I can see them clearly during combat.

**Acceptance Criteria**:
- 2.1 Weapon sprites should have a z_index higher than the player sprite (player is z_index=1)
- 2.2 Weapons should render in front of the player character
- 2.3 Weapon rendering order should be consistent across all weapon types
- 2.4 Z-index should be set to 2 or higher to ensure visibility

### 3. Weapon Position
**As a player**, I want weapons to be positioned correctly relative to my character, so they appear to be held naturally.

**Acceptance Criteria**:
- 3.1 Weapons should be positioned at the correct offset from the player
- 3.2 Weapon rotation should work correctly around the player
- 3.3 Weapon position should update correctly when the player moves
- 3.4 Multiple weapons should not overlap incorrectly

## Technical Context

### Current Implementation
- **File**: `scenes/weapons/weapon.gd`
  - Sprite scale is set to `Vector2.ONE` (1.0, 1.0) in `_ready()`
  - No z_index is set for the weapon sprite
  - Sprite position is stored in `atk_start_pos`

- **File**: `scenes/weapons/melee/weapon_melee_point.tscn`
  - Sprite2D node has no default z_index
  - No default scale is set in the scene

- **File**: `scenes/unit/players/player_generic.tscn`
  - Player sprite has `z_index = 1`
  - WeaponContainer has Marker2D nodes for weapon positioning

### Configuration Data
- **File**: `config/weapon/weapon_config_optimized.csv`
  - Contains `hitbox_scale` parameter (e.g., "1.2|1.0" for punch)
  - Contains `hitbox_offset` parameter (e.g., "30|0" for punch)
  - No explicit sprite scale parameter currently

## Constraints
- Must not break existing weapon functionality
- Must work for both melee and range weapons
- Must maintain weapon rotation and positioning logic
- Should be configurable per weapon if needed

## Success Metrics
- Weapons display at appropriate size (approximately 50% of current size)
- Weapons render in front of player character
- Weapons are positioned correctly relative to player
- No visual glitches or overlapping issues
- User confirms visual appearance is correct

## References
- Previous fix: Collision layer architecture (Task 10c)
- Related files: `weapon.gd`, `weapon_melee_point.tscn`, `player_generic.tscn`
- Configuration: `weapon_config_optimized.csv`
