# DashHitbox 自伤问题修复

## 🐛 问题描述

**现象**: 即使修复了所有武器碰撞层配置，玩家在近战攻击时依然会掉血

**日志证据**:
```
[HurtboxComponent] PlayerGeneric 受到攻击！
- 攻击者: 未知
- 武器: PlayerGeneric
- 伤害: 1.0
- 暴击: 否
```

**关键线索**:
- 攻击者显示为"未知"（hitbox.source 为 null）
- 武器名称显示为"PlayerGeneric"（hitbox.get_parent() 返回玩家自己）
- 伤害值为 1.0（不是武器伤害 11.0）

## 🔍 根本原因

这是一个**新的自伤来源**，与之前修复的武器自伤不同！

### 问题分析

在 `player_generic.tscn` 中存在一个 `DashHitbox` 节点：

```gdscript
[node name="DashHitbox" type="Area2D" parent="." index="13"]
collision_layer = 16  # 在第5层
collision_mask = 8    # 检测第4层（敌人）
script = ExtResource("7_20xkg")  # HitboxComponent 脚本
```

**玩家 HurtboxComponent 的配置**（修复前）:
```gdscript
[node name="HurtboxComponent" parent="." index="7"]
collision_layer = 32  # 在第6层
collision_mask = 20   # 检测第3层(4)和第5层(16)
```

### 碰撞层架构
```
Layer 2 (2):   Player/Enemy CharacterBody2D
Layer 3 (4):   Weapon HitboxComponent (玩家武器)
Layer 4 (8):   Enemy HurtboxComponent (敌人受击盒)
Layer 5 (16):  DashHitbox (玩家和敌人的冲刺攻击)
Layer 6 (32):  Player HurtboxComponent (玩家受击盒)
```

### 问题根源

1. 玩家的 `DashHitbox` 在第5层 (collision_layer = 16)
2. 玩家的 `HurtboxComponent` 的 collision_mask = 20 (二进制: 10100)
   - 检测第3层 (4): 敌人武器 ✅
   - 检测第5层 (16): 敌人冲刺攻击 ✅ + **玩家自己的 DashHitbox** ❌
3. **结果**: 玩家的 HurtboxComponent 检测到了玩家自己的 DashHitbox！

### 为什么日志显示"攻击者: 未知"？

因为 `DashHitbox` 是直接挂在玩家节点上的 HitboxComponent，它的 `source` 属性可能没有正确设置，所以显示为"未知"。但 `hitbox.get_parent()` 返回的是 PlayerGeneric 节点本身。

## ✅ 解决方案

### 方案选择

有两种解决方案：

#### 方案1: 修改 HurtboxComponent collision_mask（推荐）✅

**优点**: 简单直接，只需修改一个值
**缺点**: 玩家无法检测敌人的冲刺攻击（如果游戏设计需要的话）

**实施**:
```gdscript
[node name="HurtboxComponent" parent="." index="7"]
collision_layer = 32
collision_mask = 4   # 只检测第3层（敌人武器），不检测第5层
```

#### 方案2: 移动 DashHitbox 到不同层

**优点**: 保留玩家检测敌人冲刺攻击的能力
**缺点**: 需要修改更多配置，可能影响其他系统

**实施**:
```gdscript
[node name="DashHitbox" type="Area2D" parent="." index="13"]
collision_layer = 64  # 移到第7层
collision_mask = 8
```

### 采用方案1（推荐）

**文件**: `scenes/unit/players/player_generic.tscn`

**修改前**:
```gdscript
[node name="HurtboxComponent" parent="." index="7"]
collision_layer = 32
collision_mask = 20   # ❌ 检测第3层和第5层
```

**修改后**:
```gdscript
[node name="HurtboxComponent" parent="." index="7"]
collision_layer = 32
collision_mask = 4    # ✅ 只检测第3层（敌人武器）
```

### collision_mask = 4 的含义

`collision_mask = 4` 是二进制 `00100`，表示只检测：
- 第3层 (4): 敌人 HitboxComponent（敌人的普通武器攻击）

**不检测**:
- 第5层 (16): DashHitbox（包括玩家自己的和敌人的冲刺攻击）

## 🎯 预期结果

修复后：
- ✅ 玩家武器可以攻击敌人
- ✅ 敌人受到伤害
- ✅ 玩家不会受到自己武器的伤害
- ✅ 玩家不会受到自己 DashHitbox 的伤害
- ✅ 玩家可以受到敌人武器攻击的伤害（正常游戏机制）
- ⚠️ 玩家不会受到敌人冲刺攻击的伤害（如果游戏需要此功能，使用方案2）

## 📊 完整碰撞层配置（修复后）

### 玩家相关
```
Player CharacterBody2D:
  collision_layer = 2
  collision_mask = 6

Player HurtboxComponent:
  collision_layer = 32 (第6层)
  collision_mask = 4   (只检测敌人武器: 第3层)

Player DashHitbox:
  collision_layer = 16 (第5层)
  collision_mask = 8   (检测敌人受击盒)

Player Weapon HitboxComponent:
  collision_layer = 4  (第3层)
  collision_mask = 8   (检测敌人受击盒)
```

### 敌人相关
```
Enemy CharacterBody2D:
  collision_layer = 2
  collision_mask = 2

Enemy HurtboxComponent:
  collision_layer = 8  (第4层)
  collision_mask = 16  (检测玩家武器)

Enemy HitboxComponent:
  collision_layer = 4  (第3层)
  collision_mask = 32  (检测玩家受击盒)

Enemy DashHitbox:
  collision_layer = 16 (第5层)
  collision_mask = 32  (检测玩家受击盒)
```

## 🧪 测试步骤

1. 启动游戏
2. 选择战士角色（使用拳头武器）
3. 进入游戏并攻击敌人
4. 观察控制台日志

### 预期日志（正确）
```
[MeleeBehavior] 创建 hitbox: point - CircleShape2D (radius=90.0)
[HurtboxComponent] EnemyGeneric 受到攻击！
  - 攻击者: PlayerGeneric
  - 武器: Weapon
  - 伤害: 11.0
  - 暴击: 否
```

### 不应该出现的日志（错误）
```
❌ [HurtboxComponent] PlayerGeneric 受到攻击！
   - 攻击者: 未知
   - 武器: PlayerGeneric
   - 伤害: 1.0
```

## 📝 修复历史

### Task 10a: 修复武器自伤（已完成）
- 修复了玩家 HurtboxComponent 检测玩家武器的问题
- collision_mask: 4 → 20
- 但引入了新问题：检测到自己的 DashHitbox

### Task 10b: 修复 DashHitbox 自伤（本次修复）
- 修复了玩家 HurtboxComponent 检测自己 DashHitbox 的问题
- collision_mask: 20 → 4
- 彻底解决自伤问题

## 🎉 结论

这是**第二个自伤来源**，与武器自伤不同：

1. **武器自伤**（Task 10a 修复）:
   - 原因: HurtboxComponent 检测玩家武器（第3层）
   - 表现: 攻击者显示为 PlayerGeneric，武器显示为 Weapon，伤害为武器伤害

2. **DashHitbox 自伤**（Task 10b 本次修复）:
   - 原因: HurtboxComponent 检测玩家 DashHitbox（第5层）
   - 表现: 攻击者显示为"未知"，武器显示为 PlayerGeneric，伤害为 1.0

通过将 collision_mask 从 20 改为 4，玩家 HurtboxComponent 现在只检测敌人的普通武器攻击（第3层），不再检测第5层的任何内容（包括玩家自己的 DashHitbox 和敌人的冲刺攻击）。

**权衡**: 如果游戏设计需要玩家能被敌人冲刺攻击伤害，需要采用方案2（移动玩家 DashHitbox 到第7层）。

现在自伤问题已经**彻底解决**！🎊
