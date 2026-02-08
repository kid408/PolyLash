# 武器场景节点类型修复报告

**日期**: 2026-02-08  
**问题**: WeaponBehavior 节点类型不匹配  
**状态**: ✅ 已完成

---

## 问题描述

### 错误信息
```
Script inherits from native type 'Node2D', so it can't be assigned to an object of type: 'Node'
```

### 根本原因

1. **脚本继承**: `weapon_behavior.gd` 继承自 `Node2D`
2. **场景节点类型**: 工具生成的场景文件中 `WeaponBehavior` 节点类型为 `Node`
3. **类型不匹配**: Godot 不允许将 Node2D 脚本附加到 Node 类型节点

---

## 修复内容

### 1. 修复 weapon.gd 中的 CollisionShape2D 引用

**文件**: `scenes/weapons/weapon.gd`  
**行号**: 5

**修复前**:
```gdscript
@onready var collision: CollisionShape2D = %CollisionShape2D
```

**修复后**:
```gdscript
@onready var collision: CollisionShape2D = $HitboxComponent/CollisionShape2D
```

**原因**: CollisionShape2D 是 HitboxComponent 的子节点，不是 Weapon 的直接唯一子节点

---

### 2. 修复所有场景文件中的 WeaponBehavior 节点类型

修复了 7 个场景文件，将 `WeaponBehavior` 节点从 `type="Node"` 改为 `type="Node2D"`：

#### 近战武器场景 (4个)

1. **scenes/weapons/melee/weapon_melee_point.tscn**
   - 修复行: 23
   - 变更: `type="Node"` → `type="Node2D"`

2. **scenes/weapons/melee/weapon_melee_thrust.tscn**
   - 修复行: 23
   - 变更: `type="Node"` → `type="Node2D"`

3. **scenes/weapons/melee/weapon_melee_sector.tscn**
   - 修复行: 23
   - 变更: `type="Node"` → `type="Node2D"`

4. **scenes/weapons/melee/weapon_melee_circle.tscn**
   - 修复行: 23
   - 变更: `type="Node"` → `type="Node2D"`

#### 远程武器场景 (3个)

5. **scenes/weapons/range/weapon_range_physical.tscn**
   - 修复行: 23
   - 变更: `type="Node"` → `type="Node2D"`

6. **scenes/weapons/range/weapon_range_beam.tscn**
   - 修复行: 23
   - 变更: `type="Node"` → `type="Node2D"`
   - 注: 此文件在之前已手动修复

7. **scenes/weapons/range/weapon_range_magic.tscn**
   - 修复行: 23
   - 变更: `type="Node"` → `type="Node2D"`

---

## 修复前后对比

### 修复前的场景结构
```
[node name="WeaponBehavior" type="Node" parent="."]  ❌ 错误
unique_name_in_owner = true
script = ExtResource("3_h84gd")
```

### 修复后的场景结构
```
[node name="WeaponBehavior" type="Node2D" parent="."]  ✅ 正确
unique_name_in_owner = true
script = ExtResource("3_h84gd")
```

---

## 验证步骤

1. ✅ 所有 7 个场景文件已修复
2. ✅ weapon.gd 中的 CollisionShape2D 引用已修复
3. ✅ 场景文件可在 Godot 编辑器中正常打开
4. ⏳ 待测试: 游戏运行时武器加载和攻击功能

---

## 下一步

请在 Godot 中运行游戏，验证：

1. **武器加载**: 游戏启动时武器正常加载，无错误
2. **武器攻击**: 近战和远程武器攻击功能正常
3. **碰撞检测**: HitboxComponent 和 CollisionShape2D 正常工作
4. **控制台日志**: 查看是否有新的错误信息

如果仍有错误，请提供完整的错误信息和堆栈跟踪。

---

## 相关文件

- `scenes/weapons/weapon.gd` (修复 CollisionShape2D 引用)
- `scenes/weapons/weapon_behavior.gd` (基类，继承 Node2D)
- `scenes/weapons/melee/melee_behavior.gd` (继承 WeaponBehavior)
- `scenes/weapons/range/range_behavior.gd` (继承 WeaponBehavior)
- `tools/create_weapon_scenes_tool.gd` (工具已在之前更新)
- 所有 7 个武器场景文件 (已全部修复)

---

**修复完成时间**: 2026-02-08  
**修复人员**: Kiro AI Assistant


---

## 补充修复: CollisionShape2D Shape 初始化

**日期**: 2026-02-08  
**问题**: `collision.shape` 为 null

### 错误信息
```
Invalid assignment of property or key 'radius' with value of type 'float' on a base object of type 'null instance'.
weapon.gd:50 @ setup_weapon()
```

### 根本原因

场景文件中的 CollisionShape2D 节点没有初始化 shape 属性，导致 `collision.shape` 为 `null`。

### 修复方案

在 `weapon.gd` 的 `setup_weapon()` 函数中，在设置 radius 之前先检查并创建 shape：

**修复前** (第 50 行):
```gdscript
collision.shape.radius = data.stats.max_range
```

**修复后** (第 50-58 行):
```gdscript
# 确保 CollisionShape2D 有一个 shape（用于检测范围）
if not collision.shape:
	collision.shape = CircleShape2D.new()

# 设置检测范围
if collision.shape is CircleShape2D:
	collision.shape.radius = data.stats.max_range
elif collision.shape is RectangleShape2D:
	collision.shape.extents = Vector2(data.stats.max_range, data.stats.max_range)
```

### 为什么这样修复

1. **动态创建 shape**: 如果场景文件中没有预设 shape，就动态创建一个 CircleShape2D
2. **类型检查**: 支持不同类型的 shape（CircleShape2D 和 RectangleShape2D）
3. **安全性**: 避免访问 null 对象的属性

### 验证

修复后，游戏应该能够正常启动并加载武器，不再出现 "null instance" 错误。

---

**修复完成时间**: 2026-02-08  
**状态**: ✅ 已完成
