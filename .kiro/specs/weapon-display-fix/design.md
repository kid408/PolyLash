# Weapon Display Fix - Design

## Design Overview
Fix weapon visual display by adjusting sprite scale and z-index in the weapon initialization code and scene files.

## Architecture

### Component Responsibilities

#### 1. Weapon Script (`weapon.gd`)
**Responsibility**: Initialize weapon sprite with correct scale and z-index

**Changes**:
- Set default sprite scale to `Vector2(0.5, 0.5)` instead of `Vector2.ONE`
- Set sprite z_index to 2 (higher than player's z_index of 1)
- Maintain existing rotation and positioning logic

#### 2. Weapon Scene Files
**Responsibility**: Provide default visual settings for weapon sprites

**Changes**:
- Set Sprite2D z_index to 2 in scene files
- Optionally set default scale in scene (can be overridden by code)

#### 3. Weapon Configuration (Future Enhancement)
**Responsibility**: Allow per-weapon scale customization

**Changes** (Optional):
- Add `sprite_scale` parameter to CSV if needed
- Parse and apply sprite_scale in `setup_weapon()`

## Detailed Design

### Solution 1: Code-Based Scale and Z-Index (Recommended)

**File**: `scenes/weapons/weapon.gd`

**Location**: `_ready()` function

**Current Code**:
```gdscript
func _ready() -> void:
	atk_start_pos = sprite.position
	
	# 确保 Sprite2D 可见并设置初始缩放
	sprite.visible = true
	if sprite.scale == Vector2.ZERO:
		sprite.scale = Vector2.ONE
```

**New Code**:
```gdscript
func _ready() -> void:
	atk_start_pos = sprite.position
	
	# 确保 Sprite2D 可见并设置初始缩放和渲染层级
	sprite.visible = true
	sprite.z_index = 2  # 在玩家前面渲染 (玩家是 z_index=1)
	
	# 设置默认缩放为 0.5 (50%)，使武器大小合适
	if sprite.scale == Vector2.ZERO:
		sprite.scale = Vector2(0.5, 0.5)
```

**Rationale**:
- Sets z_index to 2 to render above player (z_index=1)
- Sets default scale to 0.5 to make weapons appropriately sized
- Only sets scale if it's ZERO, allowing scene files to override if needed
- Minimal code change, easy to test and verify

### Solution 2: Scene-Based Defaults (Alternative)

**File**: `scenes/weapons/melee/weapon_melee_point.tscn`

**Changes**:
```
[node name="Sprite2D" type="Sprite2D" parent="."]
unique_name_in_owner = true
z_index = 2
scale = Vector2(0.5, 0.5)
```

**Rationale**:
- Sets defaults in scene file
- Code can still override if needed
- More explicit visual settings

**Recommendation**: Use Solution 1 (code-based) as primary fix, optionally add Solution 2 for explicit scene defaults.

### Solution 3: Configuration-Based Scale (Future Enhancement)

**File**: `config/weapon/weapon_config_optimized.csv`

**New Column**: `sprite_scale` (format: "x|y", e.g., "0.5|0.5")

**File**: `autoloads/weapon_stats.gd`

**New Field**:
```gdscript
var sprite_scale: String = "1.0|1.0"  # 主贴图缩放 (x|y)

func get_sprite_scale() -> Vector2:
	var parts = sprite_scale.split("|")
	if parts.size() == 2:
		return Vector2(float(parts[0]), float(parts[1]))
	return Vector2.ONE
```

**File**: `scenes/weapons/weapon.gd` in `setup_weapon()`

**New Code**:
```gdscript
# 应用贴图缩放
var sprite_scale_vec = data.stats.get_sprite_scale()
if sprite_scale_vec != Vector2.ONE:
	sprite.scale = sprite_scale_vec
	print("[Weapon] 贴图缩放: ", sprite_scale_vec)
```

**Rationale**:
- Allows per-weapon scale customization
- Follows existing pattern for hitbox_scale and hitbox_offset
- More flexible but requires CSV updates

**Recommendation**: Implement this only if different weapons need different scales.

## Implementation Plan

### Phase 1: Quick Fix (Immediate)
1. Modify `weapon.gd` `_ready()` to set z_index=2 and scale=0.5
2. Test with punch weapon (melee)
3. Test with laser weapon (range)
4. Verify visual appearance with user

### Phase 2: Scene Defaults (Optional)
1. Update `weapon_melee_point.tscn` with z_index=2
2. Update `weapon_range_beam.tscn` with z_index=2
3. Update other weapon scene files as needed

### Phase 3: Configuration Support (Future)
1. Add `sprite_scale` column to CSV
2. Add `get_sprite_scale()` to WeaponStats
3. Apply sprite_scale in `setup_weapon()`
4. Update CSV with per-weapon scales if needed

## Testing Strategy

### Unit Tests
- Verify sprite.z_index is set to 2 after _ready()
- Verify sprite.scale is set to Vector2(0.5, 0.5) after _ready()
- Verify existing weapon functionality still works

### Visual Tests
1. **Melee Weapon Test** (Punch):
   - Weapon should be visible in front of player
   - Weapon should be approximately 50% of current size
   - Weapon should rotate correctly around player
   - Weapon should not obscure player character

2. **Range Weapon Test** (Laser):
   - Weapon should be visible in front of player
   - Weapon should be appropriately sized
   - Weapon should aim correctly at enemies
   - Projectiles should spawn from correct position

3. **Multiple Weapons Test**:
   - All weapons should render in front of player
   - Weapons should not overlap incorrectly
   - All weapons should be visible simultaneously

### User Acceptance Test
- User confirms weapons are now the correct size
- User confirms weapons render in front of character
- User confirms weapons are positioned correctly

## Correctness Properties

### Property 1: Weapon Visibility
**Statement**: All weapon sprites must render in front of the player character.

**Validation**: 
- weapon.sprite.z_index > player.sprite.z_index
- weapon.sprite.z_index == 2
- player.sprite.z_index == 1

**Test Strategy**: Visual inspection and z_index value check

### Property 2: Weapon Scale
**Statement**: All weapon sprites must have a reasonable scale that doesn't obscure the player.

**Validation**:
- weapon.sprite.scale.x > 0 and weapon.sprite.scale.x <= 1.0
- weapon.sprite.scale.y > 0 and weapon.sprite.scale.y <= 1.0
- Default scale is Vector2(0.5, 0.5)

**Test Strategy**: Scale value check and visual inspection

### Property 3: Weapon Positioning
**Statement**: Weapons must maintain correct position relative to player during movement and rotation.

**Validation**:
- weapon.global_position is within expected range of player.global_position
- weapon.rotation updates correctly based on target direction
- weapon.position is set by WeaponContainer Marker2D

**Test Strategy**: Position tracking during gameplay

## Edge Cases

### Edge Case 1: Weapon Scale Override
**Scenario**: Scene file has non-zero scale set

**Handling**: Code checks `if sprite.scale == Vector2.ZERO` before setting scale, so scene defaults are preserved

### Edge Case 2: Missing Sprite Node
**Scenario**: Weapon scene doesn't have Sprite2D node

**Handling**: Code already has `@onready var sprite: Sprite2D = $Sprite2D` which will error if missing (expected behavior)

### Edge Case 3: Weapon Rotation Flipping
**Scenario**: Weapon flips when rotating past 90 degrees

**Handling**: Existing `update_visuals()` handles Y-axis flipping, scale change should not affect this

### Edge Case 4: Multiple Weapons
**Scenario**: Player has 6 weapons equipped

**Handling**: Each weapon instance sets its own z_index and scale independently

## Rollback Plan

If the fix causes issues:
1. Revert `weapon.gd` changes to restore original scale and z_index behavior
2. Test with original code to verify rollback
3. Investigate alternative solutions (scene-based or config-based)

## Performance Considerations

- Setting z_index and scale in `_ready()` is a one-time operation
- No performance impact on gameplay
- No additional memory usage
- No impact on weapon behavior or collision detection

## Future Enhancements

1. **Per-Weapon Scale Configuration**: Add sprite_scale to CSV for fine-tuned control
2. **Weapon Layering**: Support multiple z_index layers for weapon effects
3. **Dynamic Scale**: Scale weapons based on player size or zoom level
4. **Weapon Offset**: Add sprite_offset parameter for precise positioning
