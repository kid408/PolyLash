# 近战武器 Hitbox 调试指南

## 当前问题
玩家使用近战武器（punch）攻击时，角色会掉血。日志显示 hitbox 半径为 0.0。

## 已添加的调试日志

### 1. WeaponConfigLoader 调试
在 `autoloads/weapon_config_loader.gd` 中添加了调试日志，会打印：
- punch 武器的所有 row 键值对
- base_max_range 的值
- range_scale 的值
- 计算后的 max_range 值

### 2. MeleeBehavior 调试
在 `scenes/weapons/melee/melee_behavior.gd` 中添加了调试日志，会打印：
- stats 对象是否为 null
- stats.max_range 的值
- stats.shape_type 的值

## 测试步骤

1. **运行游戏**
2. **选择带 punch 武器的角色**（如 warrior, tankman）
3. **进入游戏**
4. **等待武器第一次攻击**
5. **查看控制台日志**

## 预期日志输出

### 正常情况（应该看到）:
```
[WeaponConfigLoader] DEBUG punch row keys:
  - weapon_base_id: punch
  - display_name_template: 拳头%d级
  - type: melee
  - max_level: 4
  - base_damage: 1
  - base_accuracy: 1
  - base_cooldown: 0.8
  - base_crit_chance: 0.05
  - base_crit_damage: 1.5
  - base_max_range: 180
  - ... (其他字段)

[WeaponConfigLoader] DEBUG punch:
  - base_max_range: 180
  - range_scale: 10
  - level: 1
  - max_range: 180
  - row['base_max_range']: 180

[MeleeBehavior] setup_hitbox 调用:
  - stats: <WeaponStats#...>
  - stats.max_range: 180
  - stats.shape_type: point

[MeleeBehavior] 创建 hitbox: point
[MeleeBehavior] 创建 hitbox: point - CircleShape2D (radius=90.0)
```

### 异常情况（如果看到）:
```
[WeaponConfigLoader] DEBUG punch row keys:
  - weapon_base_id: punch
  - ... (缺少 base_max_range 键)

[WeaponConfigLoader] DEBUG punch:
  - base_max_range: 150  (使用了默认值)
  - range_scale: 10
  - level: 1
  - max_range: 150
  - row['base_max_range']: KEY_NOT_FOUND

[MeleeBehavior] setup_hitbox 调用:
  - stats: <WeaponStats#...>
  - stats.max_range: 0  (错误！)
  - stats.shape_type: point

[MeleeBehavior] 创建 hitbox: point
[MeleeBehavior] 创建 hitbox: point - CircleShape2D (radius=0.0)
```

## 可能的问题和解决方案

### 问题 1: CSV 列名不匹配
**症状**: row 字典中没有 "base_max_range" 键

**原因**: CSV 表头可能有拼写错误或额外的空格

**解决方案**: 检查 `config/weapon/weapon_config_optimized.csv` 第一行，确保列名完全匹配

### 问题 2: CSV 数据解析失败
**症状**: base_max_range 的值是空字符串或无法转换为数字

**原因**: CSV 数据格式问题（如额外的引号、空格）

**解决方案**: 检查 CSV 文件编码（应该是 UTF-8），确保数据格式正确

### 问题 3: WeaponStats 对象未正确初始化
**症状**: stats.max_range 是 0，但 WeaponConfigLoader 显示计算正确

**原因**: WeaponStats 对象在传递过程中丢失了数据

**解决方案**: 检查 `weapon.data.stats` 的赋值过程

### 问题 4: 碰撞层设置错误
**症状**: hitbox radius 正确，但玩家仍然掉血

**原因**: 玩家的 HurtboxComponent 和武器的 HitboxComponent 碰撞层设置冲突

**当前设置**:
- 武器 HitboxComponent: collision_layer = 4, collision_mask = 2
- 玩家 HurtboxComponent: collision_layer = 32, collision_mask = 4

**问题**: 武器 mask=2 会检测敌人（layer=2），但不应该检测玩家（layer=32）

**解决方案**: 确保武器 HitboxComponent 的 collision_mask 不包含玩家的 collision_layer

## 下一步行动

1. **运行游戏并收集日志**
2. **将完整的控制台日志发送给我**
3. **根据日志输出确定具体问题**
4. **应用相应的解决方案**

## 临时解决方案

如果问题紧急，可以尝试以下临时修复：

### 方案 A: 硬编码 radius
在 `melee_behavior.gd` 的 `_create_point_shape` 函数中：
```gdscript
func _create_point_shape(stats: WeaponStats) -> void:
    var collision_shape = CollisionShape2D.new()
    var circle = CircleShape2D.new()
    
    # 临时硬编码
    var radius = 90.0  # 强制使用 90.0
    if stats and stats.max_range > 0:
        radius = stats.max_range / 2.0
    if stats and not stats.param1.is_empty():
        radius = float(stats.param1)
    
    circle.radius = radius
    collision_shape.shape = circle
    
    hitbox.add_child(collision_shape)
    current_shape = collision_shape
    
    print("[MeleeBehavior] 创建 hitbox: point - CircleShape2D (radius=", radius, ")")
```

### 方案 B: 修改碰撞层
确保玩家不会被自己的武器击中：
1. 打开 `scenes/weapons/melee/weapon_melee_point.tscn`
2. 找到 HitboxComponent 节点
3. 确认 collision_mask = 2（只检测敌人）
4. 确认 collision_layer = 4（武器攻击层）

## 文件修改记录
- `autoloads/weapon_config_loader.gd` - 添加调试日志
- `scenes/weapons/melee/melee_behavior.gd` - 添加调试日志

## 日期
2026-02-08
