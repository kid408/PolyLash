# Melee Collision Debug Guide

## Overview

This guide explains how to debug melee weapon collision detection issues in the game.

## Problem History

### Issue 1: CollisionShape2D Accumulation ✅ FIXED
- **Problem**: `queue_free()` caused delayed deletion, CollisionShape2D nodes accumulated
- **Solution**: Use `free()` for immediate deletion in `cleanup_old_shape()`

### Issue 2: HurtboxComponent Mutual Detection ✅ FIXED
- **Problem**: HurtboxComponents detected each other, causing mutual damage
- **Solution**: Filter to only process HitboxComponent in `_on_area_entered()`

### Issue 3: Invisible CollisionShape2D (CURRENT)
- **Problem**: CollisionShape2D not visible in debug view, collision detection fails
- **Root Cause**: Scene file has disabled placeholder CollisionShape2D
- **Solution**: Remove placeholder, make weapon.gd support dynamic CollisionShape2D

## Collision Layer Architecture

```
Layer 3 (4):   Player Weapon HitboxComponent
Layer 4 (8):   Enemy HurtboxComponent  
Layer 6 (32):  Player HurtboxComponent
Layer 7 (64):  Enemy Weapon HitboxComponent
```

## Debug Logging System

### MeleeBehavior Debug Logs

**Location**: `scenes/weapons/melee/melee_behavior.gd`

**Key Functions**:

1. **setup_hitbox()** - Logs shape creation
```gdscript
print("[MeleeBehavior] setup_hitbox 调用:")
print("  - stats.max_range: ", stats.max_range)
print("  - stats.shape_type: ", stats.shape_type)
```

2. **_create_point_shape()** - Logs CircleShape2D creation
```gdscript
print("[MeleeBehavior] 创建 CollisionShape2D:")
print("  - 类型: CircleShape2D")
print("  - 半径: ", radius)
print("  - disabled: ", collision_shape.disabled)
print("  - 在场景树中: ", collision_shape.is_inside_tree())
```

3. **execute_attack()** - Logs attack execution
```gdscript
print("[MeleeBehavior] ========== 开始近战攻击 ==========")
print("[MeleeBehavior] 武器名称: ", weapon.data.item_name)
print("[MeleeBehavior] 武器位置: ", weapon.global_position)
print("[MeleeBehavior] Hitbox 启用:")
print("  - Hitbox 位置: ", hitbox.global_position)
print("  - 伤害: ", damage_value)
```

4. **cleanup_old_shape()** - Logs shape cleanup
```gdscript
print("[MeleeBehavior] 清理旧 CollisionShape2D")
```

### HitboxComponent Debug Logs

**Location**: `scenes/components/hitbox_component.gd`

**Key Functions**:

1. **enable()** - Lists all children
```gdscript
print("[HitboxComponent] Hitbox 启用 - ", get_parent().name)
print("[HitboxComponent] 子节点数量: ", get_child_count())
for child in get_children():
    print("[HitboxComponent]   - 子节点: ", child.name, " (", child.get_class(), ")")
    if child is CollisionShape2D:
        print("[HitboxComponent]     - disabled: ", child.disabled)
        print("[HitboxComponent]     - shape: ", child.shape)
```

2. **disable()** - Logs disable
```gdscript
print("[HitboxComponent] Hitbox 禁用 - ", get_parent().name)
```

3. **_on_area_entered()** - Logs collision detection
```gdscript
print("[HitboxComponent] ========== 检测到碰撞！==========")
print("[HitboxComponent] 攻击方: ", get_parent().name)
print("[HitboxComponent] 受击方: ", area.get_parent().name)
print("[HitboxComponent] 伤害: ", damage)
```

### HurtboxComponent Debug Logs

**Location**: `scenes/components/hurtbox_component.gd`

**Key Functions**:

1. **_on_area_entered()** - Logs damage received
```gdscript
print("[HurtboxComponent] ========== 受到攻击！==========")
print("[HurtboxComponent] 受击者: ", get_parent().name)
print("[HurtboxComponent] 攻击者: ", hitbox.source.name)
print("[HurtboxComponent] 武器: ", hitbox.get_parent().name)
print("[HurtboxComponent] 伤害: ", hitbox.damage)
```

## Debug Workflow

### Step 1: Enable Collision Shape Visibility

In Godot Editor:
1. Go to **Debug** menu
2. Enable **Visible Collision Shapes**
3. Run the game

### Step 2: Check Console Logs

Look for these log patterns:

**Successful Attack Pattern**:
```
[MeleeBehavior] ========== 开始近战攻击 ==========
[MeleeBehavior] 创建 CollisionShape2D:
  - 类型: CircleShape2D
  - 半径: 90.0
  - disabled: false
  - 在场景树中: true
[HitboxComponent] Hitbox 启用 - Weapon
[HitboxComponent] 子节点数量: 1
[HitboxComponent]   - 子节点 0: CollisionShape2D (CollisionShape2D)
[HitboxComponent]     - disabled: false
[HitboxComponent]     - shape: <CircleShape2D#...>
[HitboxComponent] ========== 检测到碰撞！==========
[HurtboxComponent] ========== 受到攻击！==========
```

**Failed Attack Pattern** (before fix):
```
[MeleeBehavior] ========== 开始近战攻击 ==========
[MeleeBehavior] 创建 CollisionShape2D:
[HitboxComponent] Hitbox 启用 - Weapon
[HitboxComponent] 子节点数量: 0  # ← No children!
# No collision detected
```

### Step 3: Verify Scene Structure

In Godot Editor, open `scenes/weapons/melee/weapon_melee_point.tscn`:

**Correct Structure**:
```
Weapon (Node2D)
├── Sprite2D
├── HitboxComponent (Area2D)
│   └── (no static CollisionShape2D)  # ← Should be empty
├── RangeArea2
│   └── CollisionShape2D
├── CooldownTimer
└── WeaponBehavior (MeleeBehavior)
```

**Incorrect Structure** (before fix):
```
Weapon (Node2D)
├── Sprite2D
├── HitboxComponent (Area2D)
│   └── CollisionShape2D (disabled=true)  # ← Should NOT exist
├── RangeArea2
│   └── CollisionShape2D
├── CooldownTimer
└── WeaponBehavior (MeleeBehavior)
```

### Step 4: Check CollisionShape2D Properties

If CollisionShape2D is visible in debug view, verify:
- **disabled**: Should be `false`
- **shape**: Should be CircleShape2D with radius > 0
- **position**: Should match weapon position
- **collision_layer**: Should be 4 (Layer 3)
- **collision_mask**: Should be 8 (Layer 4)

## Common Issues and Solutions

### Issue: CollisionShape2D Not Visible

**Symptoms**:
- No collision shape in debug view
- No collision detection
- Log shows "子节点数量: 0"

**Causes**:
1. Placeholder CollisionShape2D in scene file (disabled)
2. CollisionShape2D not added to scene tree
3. CollisionShape2D immediately deleted

**Solutions**:
1. Remove placeholder from scene file
2. Verify `hitbox.add_child(collision_shape)` is called
3. Use `free()` instead of `queue_free()` in cleanup

### Issue: CollisionShape2D Accumulation

**Symptoms**:
- Multiple CollisionShape2D nodes
- Collision detection at wrong positions
- Log shows "子节点数量: 12" (or other large number)

**Causes**:
- `queue_free()` delays deletion
- Old shapes not cleaned up before creating new ones

**Solutions**:
- Use `free()` for immediate deletion
- Call `cleanup_old_shape()` before creating new shape

### Issue: Mutual Damage

**Symptoms**:
- Enemies damage each other
- Players damage each other (in multiplayer)

**Causes**:
- HurtboxComponent detects other HurtboxComponents

**Solutions**:
- Filter `_on_area_entered()` to only process HitboxComponent:
```gdscript
func _on_area_entered(area: Area2D) -> void:
    if not area is HitboxComponent:
        return
    # ... process damage
```

### Issue: Delayed Collision Detection

**Symptoms**:
- Collision detected after weapon passes through enemy
- Multiple attacks needed to hit

**Causes**:
- Hitbox disabled too early
- Physics engine needs time to process

**Solutions**:
- Add delay before disabling hitbox:
```gdscript
tween.tween_interval(0.1)  # Wait 0.1 seconds
tween.tween_callback(func(): hitbox.disable())
```

## Testing Checklist

- [ ] Collision shapes visible in debug view
- [ ] CollisionShape2D created successfully (check logs)
- [ ] CollisionShape2D added to scene tree (check logs)
- [ ] CollisionShape2D not disabled (check logs)
- [ ] Collision detected on first hit (check logs)
- [ ] No CollisionShape2D accumulation (check child count)
- [ ] No mutual damage between same team
- [ ] Damage applies correctly (check enemy health)

## Related Files

- `scenes/weapons/melee/melee_behavior.gd` - Melee attack logic
- `scenes/weapons/melee/weapon_melee_point.tscn` - Melee weapon scene
- `scenes/weapons/weapon.gd` - Base weapon class
- `scenes/components/hitbox_component.gd` - Attack collision detection
- `scenes/components/hurtbox_component.gd` - Damage reception
- `config/weapon/weapon_config_optimized.csv` - Weapon stats

## Fix History

### 2026-02-08: Invisible CollisionShape2D Fix
- Removed disabled placeholder from scene file
- Updated weapon.gd to support dynamic CollisionShape2D
- Added detailed debug logging

### 2026-02-08: CollisionShape2D Accumulation Fix
- Changed `queue_free()` to `free()` in cleanup
- Added immediate removal from parent before deletion

### 2026-02-08: Mutual Damage Fix
- Added HitboxComponent type check in HurtboxComponent
- Filtered out non-HitboxComponent collisions

### 2026-02-08: Delayed Detection Fix
- Added 0.1s delay before disabling hitbox
- Increased attack_duration from 0.15s to 0.3s
