# Weapon Config CSV Loading Fix

## Issue Summary
**Problem**: Melee weapons (punch) were causing player to take damage during attacks because hitbox radius was 0.0.

**Root Cause**: `ConfigManager` was loading 0 records from `weapon_config_optimized.csv` because the Chinese comment line (line 2) didn't start with "-1", causing it to be processed as a data row instead of being skipped.

## Log Evidence
```
[ConfigManager] 加载配置: res://config/weapon/weapon_config_optimized.csv - 0 条记录
[MeleeBehavior] 创建 hitbox: point - CircleShape2D (radius=0.0)
```

## Technical Details

### CSV Structure Issue
**Before Fix:**
```csv
weapon_base_id,display_name_template,type,...
武器基础ID,显示名模板(%d=等级),类型,...    ← Line 2 doesn't start with -1
punch,拳头%d级,melee,...
```

**After Fix:**
```csv
weapon_base_id,display_name_template,type,...
-1,显示名模板(%d=等级),类型,...    ← Line 2 now starts with -1
punch,拳头%d级,melee,...
```

### Why This Matters
The `ConfigManager.load_csv_as_dict()` function has this logic:
```gdscript
# 第二行：如果第一列是 -1，跳过（注释行）
if line_num == 2 and line[0].strip_edges() == "-1":
    continue
```

Without "-1" in the first column, line 2 was being processed as a data row with key "武器基础ID", which is not a valid weapon ID. This caused the entire CSV to fail loading properly.

### Impact Chain
1. `ConfigManager` loads 0 weapon records
2. `WeaponConfigLoader.get_weapon_stats("punch_1")` can't find base data
3. Returns `null` or creates stats with default/zero values
4. `MeleeBehavior._create_point_shape()` calculates radius from `stats.max_range / 2.0`
5. If `max_range` is 0, radius becomes 0.0
6. Zero-radius hitbox causes collision issues (player hits themselves)

## Solution
Changed line 2 of `config/weapon/weapon_config_optimized.csv` to start with "-1" instead of "武器基础ID".

## Expected Result
After this fix:
- `ConfigManager` should load 36 weapon records (one per weapon base)
- `WeaponConfigLoader` can successfully create weapon stats with correct values
- Punch weapon (level 1) should have:
  - `base_max_range`: 180
  - `max_range`: 180 (for level 1)
  - Hitbox radius: 90.0 (180 / 2.0)
- Player should no longer take damage from their own melee attacks

## Files Modified
- `config/weapon/weapon_config_optimized.csv` - Fixed line 2 to start with "-1"

## Testing Instructions
1. Run the game
2. Check console log for: `[ConfigManager] 加载配置: res://config/weapon/weapon_config_optimized.csv - 36 条记录`
3. Select a character with punch weapon
4. Enter game and attack enemies
5. Verify:
   - Log shows: `[MeleeBehavior] 创建 hitbox: point - CircleShape2D (radius=90.0)` (not 0.0)
   - Player doesn't take damage when attacking
   - Melee attacks successfully hit enemies

## Related Issues
- Task 6.4: Fixed ConfigManager CSV loading (column name mismatch)
- Task 7: Fix melee weapon hitbox radius issue (this fix)

## Date
2026-02-08
