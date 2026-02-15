# 近战武器自伤问题修复报告

## 问题描述

玩家使用近战武器（如拳头）攻击时，角色会受到伤害。

## 根本原因

### 1. Hitbox 半径为 0
近战武器的 hitbox 半径被错误地设置为 0.0，导致碰撞体无效或异常。

**日志证据**：
```
[MeleeBehavior] setup_hitbox 调用:
- stats.max_range: 180.0  ✅

[MeleeBehavior] 创建 hitbox: point - CircleShape2D (radius=0.0)  ❌
```

### 2. param1 字段的错误处理
在 `weapon_config_optimized.csv` 中，punch 武器的 `param1` 字段值为 `"0"`（字符串零），而不是空字符串。

**CSV 数据**（第 3 行，punch 武器）：
- Column 10: `base_max_range: 180` ✅
- Column 36: `param1: 0` ⚠️ **问题所在**
- Column 43: `range_scale: 10` ✅

**错误逻辑**（`melee_behavior.gd` 原代码）：
```gdscript
var radius = stats.max_range / 2.0  # 计算为 90.0 ✅

if not stats.param1.is_empty():  # "0" 不是空字符串，条件为 true ❌
    radius = float(stats.param1)  # float("0") = 0.0 ❌
```

结果：正确的 radius (90.0) 被 param1 的 0.0 覆盖。

## 修复方案

### 修复 1: 添加伤害来源日志（用户请求）

**文件**: `scenes/components/hurtbox_component.gd`

**修改内容**：
在 `_on_area_entered()` 函数中添加详细的调试日志，记录：
- 受击者名称
- 攻击者名称
- 武器名称
- 伤害值
- 是否暴击

**代码**：
```gdscript
func _on_area_entered(area: Area2D) -> void:
    if area is HitboxComponent:
        var hitbox = area as HitboxComponent
        var attacker_name = "未知"
        var weapon_name = "未知"
        
        if hitbox.source and is_instance_valid(hitbox.source):
            attacker_name = hitbox.source.name
        
        if hitbox.get_parent():
            weapon_name = hitbox.get_parent().name
        
        print("[HurtboxComponent] %s 受到攻击！" % get_parent().name)
        print("  - 攻击者: %s" % attacker_name)
        print("  - 武器: %s" % weapon_name)
        print("  - 伤害: %.1f" % hitbox.damage)
        print("  - 暴击: %s" % ("是" if hitbox.critical else "否"))
        
        on_damaged.emit(area)
```

### 修复 2: 修正 param1 判断逻辑

**文件**: `scenes/weapons/melee/melee_behavior.gd`

**修改内容**：
在 `_create_point_shape()` 函数中，只有当 `param1` 不为空**且大于 0** 时才使用它：

**修改前**：
```gdscript
if not stats.param1.is_empty():
    radius = float(stats.param1)
```

**修改后**：
```gdscript
if not stats.param1.is_empty() and float(stats.param1) > 0:
    radius = float(stats.param1)
    print("[MeleeBehavior] 使用 param1 作为 radius: ", radius)
```

**逻辑改进**：
- `not stats.param1.is_empty()`: 确保 param1 不是空字符串
- `float(stats.param1) > 0`: 确保 param1 转换为浮点数后大于 0
- 只有两个条件都满足时，才使用 param1 覆盖默认的 `max_range / 2.0`

## 预期结果

修复后，punch 武器的 hitbox 创建流程：

1. **计算默认 radius**：
   ```
   radius = stats.max_range / 2.0
   radius = 180.0 / 2.0 = 90.0
   ```

2. **检查 param1**：
   ```
   stats.param1 = "0"
   not stats.param1.is_empty() = true
   float(stats.param1) > 0 = false  ❌ 条件不满足
   ```

3. **保持默认 radius**：
   ```
   radius = 90.0  ✅
   ```

4. **日志输出**：
   ```
   [MeleeBehavior] 创建 hitbox: point - CircleShape2D (radius=90.0)  ✅
   ```

## 测试验证

### 测试步骤
1. 启动游戏
2. 选择任意角色（带有 punch 武器）
3. 进入游戏场景
4. 使用近战攻击敌人
5. 观察控制台日志

### 预期日志
```
[WeaponConfigLoader] DEBUG punch:
  - base_max_range: 180.0
  - max_range: 180.0

[MeleeBehavior] setup_hitbox 调用:
  - stats.max_range: 180.0

[MeleeBehavior] 创建 hitbox: point - CircleShape2D (radius=90.0)  ✅

[HurtboxComponent] Enemy_1 受到攻击！
  - 攻击者: Player
  - 武器: WeaponMeleePoint
  - 伤害: 5.0
  - 暴击: 否
```

### 验证要点
- ✅ Hitbox radius 不再是 0.0
- ✅ 玩家攻击敌人时，敌人受到伤害
- ✅ 玩家不再受到自己武器的伤害
- ✅ 伤害来源日志清晰显示攻击者和武器信息

## 相关文件

### 修改的文件
1. `scenes/components/hurtbox_component.gd` - 添加伤害来源日志
2. `scenes/weapons/melee/melee_behavior.gd` - 修正 param1 判断逻辑

### 相关配置
- `config/weapon/weapon_config_optimized.csv` - 武器配置数据（未修改）

### 相关文档
- `docs/MELEE_HITBOX_DEBUG_GUIDE.md` - 调试指南
- `docs/WEAPON_CONFIG_CSV_FIX.md` - CSV 修复文档

## 后续建议

### 1. CSV 数据规范化
考虑将所有"不使用"的 param 字段设置为空字符串，而不是 "0"：

**当前**：
```csv
punch,...,param1,param2,param3,...
punch,...,0,0,0,...
```

**建议**：
```csv
punch,...,param1,param2,param3,...
punch,...,,,,...
```

### 2. 添加参数验证
在 `WeaponConfigLoader` 中添加参数验证，确保数值字段的合法性：

```gdscript
func _parse_float_safe(row: Dictionary, key: String, default: float = 0.0) -> float:
    var value = _get_string(row, key)
    if value.is_empty():
        return default
    var result = float(value)
    if result < 0:
        push_warning("[WeaponConfigLoader] 警告: %s 为负数，使用默认值" % key)
        return default
    return result
```

### 3. 碰撞层验证
虽然本次问题不是碰撞层导致的，但建议验证：
- 武器 HitboxComponent: `collision_layer = 4`, `collision_mask = 2`
- 玩家 HurtboxComponent: `collision_layer = 32`, `collision_mask = 4`
- 确保玩家不会与自己的武器碰撞

## 总结

本次修复解决了近战武器 hitbox 半径为 0 导致的异常行为。核心问题是 CSV 中的 `param1="0"` 被错误地用于覆盖正确的半径计算。通过添加 `> 0` 条件检查，确保只有有效的 param1 值才会被使用。

同时，根据用户要求添加了详细的伤害来源日志，方便后续调试和问题排查。

---

**修复日期**: 2026-02-08  
**修复人员**: Kiro AI Assistant  
**问题严重性**: 高（影响游戏核心玩法）  
**修复状态**: ✅ 已完成，等待用户测试验证
