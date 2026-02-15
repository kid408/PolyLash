# Weapon Display Fix - Tasks

## Task List

### Phase 1: Quick Fix (Immediate)

- [x] 1. Fix weapon sprite scale and z-index in weapon.gd
  - [x] 1.1 Modify `_ready()` function to set sprite.z_index = 2
  - [x] 1.2 Modify `_ready()` function to set sprite.scale = Vector2(0.5, 0.5)
  - [x] 1.3 Update debug print statements to show z_index and scale
  - [x] 1.4 Verify code compiles without errors
  - [x] 1.5 Fix X-axis scale in `update_visuals()` to 0.5 (was staying at 1.0)
  - [x] 1.6 Add sprite position offset Vector2(27, 0) to avoid obscuring player face

- [ ] 2. Test melee weapon display (punch)
  - [ ] 2.1 Launch game and equip punch weapon
  - [ ] 2.2 Verify weapon renders in front of player
  - [ ] 2.3 Verify weapon size is appropriate (not too large)
  - [ ] 2.4 Verify weapon rotates correctly
  - [ ] 2.5 Verify weapon attacks work correctly

- [ ] 3. Test range weapon display (laser)
  - [ ] 3.1 Launch game and equip laser weapon
  - [ ] 3.2 Verify weapon renders in front of player
  - [ ] 3.3 Verify weapon size is appropriate
  - [ ] 3.4 Verify weapon aims correctly at enemies
  - [ ] 3.5 Verify projectiles spawn from correct position

- [ ] 4. User acceptance testing
  - [ ] 4.1 Get user feedback on weapon size
  - [ ] 4.2 Get user feedback on weapon position
  - [ ] 4.3 Get user feedback on weapon visibility
  - [ ] 4.4 Adjust scale if needed based on feedback

### Phase 2: Scene Defaults (Optional)

- [ ] 5. Update weapon scene files with default z-index
  - [ ] 5.1 Update weapon_melee_point.tscn Sprite2D z_index to 2
  - [ ] 5.2 Update weapon_range_beam.tscn Sprite2D z_index to 2
  - [ ] 5.3 Update weapon_range_physical.tscn Sprite2D z_index to 2
  - [ ] 5.4 Update weapon_range_magic.tscn Sprite2D z_index to 2

- [ ] 6. Update weapon scene files with default scale (optional)
  - [ ] 6.1 Update weapon_melee_point.tscn Sprite2D scale to Vector2(0.5, 0.5)
  - [ ] 6.2 Update weapon_range_beam.tscn Sprite2D scale to Vector2(0.5, 0.5)
  - [ ] 6.3 Update weapon_range_physical.tscn Sprite2D scale to Vector2(0.5, 0.5)
  - [ ] 6.4 Update weapon_range_magic.tscn Sprite2D scale to Vector2(0.5, 0.5)

### Phase 3: Documentation

- [ ] 7. Document the fix
  - [ ] 7.1 Create WEAPON_DISPLAY_FIX.md with details
  - [ ] 7.2 Update SYSTEM_STATUS.md with fix status
  - [ ] 7.3 Document z_index and scale values used
  - [ ] 7.4 Add before/after comparison notes

## Task Dependencies

```
1 (Fix code) → 2 (Test melee) → 4 (User acceptance)
1 (Fix code) → 3 (Test range) → 4 (User acceptance)
4 (User acceptance) → 5 (Update scenes - optional)
5 (Update scenes) → 6 (Add scale - optional)
4 (User acceptance) → 7 (Documentation)
```

## Success Criteria

- [x] All Phase 1 tasks completed
- [ ] User confirms weapons display correctly
- [ ] No regression in weapon functionality
- [ ] Documentation updated

## Notes

- **Priority**: Phase 1 tasks are critical and must be completed first
- **Testing**: Visual testing is essential - screenshots or video from user
- **Flexibility**: Scale value (0.5) may need adjustment based on user feedback
- **Optional**: Phase 2 tasks are optional enhancements, not required for fix
