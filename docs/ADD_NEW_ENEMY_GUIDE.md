# 添加新敌人完整流程指南

**目标**: 从零开始添加一个新的敌人类型  
**时间**: 15-30 分钟  
**难度**: ⭐⭐ 中等

---

## 📋 概述

添加新敌人需要以下步骤：

1. **准备资源** - 敌人精灵图片
2. **修改配置表** - 添加敌人参数
3. **测试验证** - 确保敌人正常工作

**无需创建新文件或修改代码！** 所有敌人都使用 `enemy_generic.tscn` 模板。

---

## 🎯 完整流程

### 第1步：准备敌人精灵（5分钟）

#### 1.1 获取精灵图片

你需要一张敌人的精灵图片，格式要求：
- **格式**: PNG 或其他 Godot 支持的格式
- **大小**: 建议 64x64 或 128x128 像素
- **背景**: 透明背景

#### 1.2 导入精灵到项目

1. 将精灵图片放到 `assets/sprites/Enemies/` 目录
2. 例如: `assets/sprites/Enemies/Enemy_Archer.png`

**目录结构**:
```
assets/sprites/Enemies/
├── Enemy_1.png (基础敌人)
├── Enemy_2.png (快速敌人)
├── Enemy_3.png (剪刀手)
├── Enemy_4.png (硬壳龟)
├── Enemy_5.png (刺猬)
├── Enemy_Glutton_01.png (吞噬者)
└── Enemy_Archer.png (新敌人 - 弓箭手)
```

---

### 第2步：修改配置表（10-15分钟）

#### 2.1 打开 enemy_config.csv

位置: `config/enemy/enemy_config.csv`

**当前内容示例**:
```csv
enemy_id,display_name,health,speed,damage,attack_range,attack_cooldown,xp_value,gold_value,knockback_resistance,energy_drop,color_r,color_g,color_b,flock_push,stop_distance,charge_prep_time,charge_duration,charge_speed_mult,charge_cooldown,break_radius,can_charge,shoot_cooldown,projectile_count,projectile_arc_angle,projectile_speed,pool_radius,pool_damage,pool_damage_interval,pool_lifetime
slow_enemy,缓速敌人,120,120,8,50,1,12,6,0.4,4,0.5,1,0.5,20.0,60.0,0.8,0.6,3.5,3.0,40.0,0,3.0,3,45.0,1800.0,60.0,5.0,0.5,8.0
```

#### 2.2 添加新敌人配置

在最后一行添加新敌人的配置。以添加"弓箭手"为例：

```csv
archer_enemy,弓箭手,90,180,12,80,1.2,22,11,0.5,5,0.8,0.6,0.2,20.0,60.0,0.8,0.6,3.5,3.0,40.0,0,2.0,5,60.0,2000.0,60.0,5.0,0.5,8.0
```

**参数说明**:

| 参数 | 说明 | 示例 | 范围 |
|------|------|------|------|
| enemy_id | 敌人唯一ID | archer_enemy | 字母+下划线 |
| display_name | 显示名称 | 弓箭手 | 任意文本 |
| health | 生命值 | 90 | 1-1000 |
| speed | 移动速度 | 180 | 50-500 |
| damage | 攻击力 | 12 | 1-100 |
| attack_range | 攻击范围 | 80 | 30-200 |
| attack_cooldown | 攻击冷却 | 1.2 | 0.1-5.0 |
| xp_value | 经验值 | 22 | 1-100 |
| gold_value | 金币值 | 11 | 1-50 |
| knockback_resistance | 击退抗性 | 0.5 | 0.0-1.0 |
| energy_drop | 能量掉落 | 5 | 0-50 |
| color_r | 颜色红 | 0.8 | 0.0-1.0 |
| color_g | 颜色绿 | 0.6 | 0.0-1.0 |
| color_b | 颜色蓝 | 0.2 | 0.0-1.0 |
| flock_push | 群聚推力 | 20.0 | 10.0-50.0 |
| stop_distance | 停止距离 | 60.0 | 30.0-100.0 |
| charge_prep_time | 冲锋预备时间 | 0.8 | 0.1-2.0 |
| charge_duration | 冲锋持续时间 | 0.6 | 0.1-2.0 |
| charge_speed_mult | 冲锋速度倍率 | 3.5 | 1.0-5.0 |
| charge_cooldown | 冲锋冷却 | 3.0 | 1.0-10.0 |
| break_radius | 破线半径 | 40.0 | 20.0-100.0 |
| can_charge | 是否冲锋 | 0 | 0(否) 或 1(是) |
| shoot_cooldown | 射击冷却 | 2.0 | 0.5-5.0 |
| projectile_count | 投射物数量 | 5 | 1-10 |
| projectile_arc_angle | 投射物弧角 | 60.0 | 10.0-180.0 |
| projectile_speed | 投射物速度 | 2000.0 | 500.0-3000.0 |
| pool_radius | 毒池半径 | 60.0 | 20.0-150.0 |
| pool_damage | 毒池伤害 | 5.0 | 1.0-20.0 |
| pool_damage_interval | 毒池伤害间隔 | 0.5 | 0.1-2.0 |
| pool_lifetime | 毒池生命周期 | 8.0 | 1.0-20.0 |

#### 2.3 打开 enemy_visual.csv

位置: `config/enemy/enemy_visual.csv`

**当前内容示例**:
```csv
enemy_id,sprite_path,scale_x,scale_y,color_r,color_g,color_b,color_a,z_index,offset_x,offset_y,collision_radius,hitbox_width,hitbox_height,animation_speed,flash_color_r,flash_color_g,flash_color_b
slow_enemy,res://assets/sprites/Enemies/Enemy_1.png,1,1,1,1,1,1,0,0,0,20,40,40,1,1,1,1
```

#### 2.4 添加新敌人视觉配置

在最后一行添加新敌人的视觉配置：

```csv
archer_enemy,res://assets/sprites/Enemies/Enemy_Archer.png,0.9,0.9,0.8,0.6,0.2,1,0,0,0,18,36,36,1,1,1,1
```

**参数说明**:

| 参数 | 说明 | 示例 | 范围 |
|------|------|------|------|
| enemy_id | 敌人唯一ID | archer_enemy | 字母+下划线 |
| sprite_path | 精灵路径 | res://assets/sprites/Enemies/Enemy_Archer.png | 资源路径 |
| scale_x | X缩放 | 0.9 | 0.1-3.0 |
| scale_y | Y缩放 | 0.9 | 0.1-3.0 |
| color_r | 颜色红 | 0.8 | 0.0-1.0 |
| color_g | 颜色绿 | 0.6 | 0.0-1.0 |
| color_b | 颜色蓝 | 0.2 | 0.0-1.0 |
| color_a | 透明度 | 1 | 0.0-1.0 |
| z_index | Z层级 | 0 | -10 到 10 |
| offset_x | X偏移 | 0 | -50 到 50 |
| offset_y | Y偏移 | 0 | -50 到 50 |
| collision_radius | 碰撞半径 | 18 | 10-50 |
| hitbox_width | 受击框宽 | 36 | 20-100 |
| hitbox_height | 受击框高 | 36 | 20-100 |
| animation_speed | 动画速度 | 1 | 0.1-3.0 |
| flash_color_r | 闪烁红 | 1 | 0.0-1.0 |
| flash_color_g | 闪烁绿 | 1 | 0.0-1.0 |
| flash_color_b | 闪烁蓝 | 1 | 0.0-1.0 |

#### 2.5 打开 wave_units_config.csv

位置: `config/wave/wave_units_config.csv`

**当前内容示例**:
```csv
wave_id,enemy_scene,enemy_id,weight
wave_1_to_5,res://scenes/unit/enemy/enemy_generic.tscn,slow_enemy,4
wave_1_to_5,res://scenes/unit/enemy/enemy_generic.tscn,fast_enemy,5
```

#### 2.6 添加新敌人到波次配置

在适当的波次中添加新敌人。例如，在第6-10波中添加弓箭手：

```csv
wave_6_to_10,res://scenes/unit/enemy/enemy_generic.tscn,archer_enemy,2.0
```

**参数说明**:

| 参数 | 说明 | 示例 |
|------|------|------|
| wave_id | 波次ID | wave_6_to_10 |
| enemy_scene | 敌人场景 | res://scenes/unit/enemy/enemy_generic.tscn |
| enemy_id | 敌人ID | archer_enemy |
| weight | 权重（生成概率） | 2.0 |

**权重说明**:
- 权重越高，敌人生成的概率越高
- 例如: slow_enemy(4) + fast_enemy(5) + archer_enemy(2) = 总权重11
- archer_enemy 的生成概率 = 2/11 ≈ 18%

---

### 第3步：测试验证（5-10分钟）

#### 3.1 刷新项目

1. 在 Godot 编辑器中按 `F5` 刷新项目
2. 检查是否有错误信息

#### 3.2 启动游戏

1. 按 `F5` 启动游戏
2. 进入游戏场景

#### 3.3 验证敌人

1. 等待敌人生成
2. 观察新敌人是否出现
3. 检查敌人的：
   - 精灵是否正确
   - 颜色是否正确
   - 大小是否正确
   - 移动速度是否正确
   - 攻击力是否正确

#### 3.4 检查控制台

打开控制台（`View` → `Output`）

**应该看到**:
```
[Spawner] 生成敌人，enemy_id = archer_enemy 位置: (...)
```

**不应该看到**:
- ❌ 错误信息
- ❌ 警告信息
- ❌ 缺失资源警告

---

## 📝 完整示例：添加弓箭手敌人

### 步骤1：准备精灵

将弓箭手精灵放到: `assets/sprites/Enemies/Enemy_Archer.png`

### 步骤2：修改 enemy_config.csv

在最后添加一行：
```csv
archer_enemy,弓箭手,90,180,12,80,1.2,22,11,0.5,5,0.8,0.6,0.2,20.0,60.0,0.8,0.6,3.5,3.0,40.0,0,2.0,5,60.0,2000.0,60.0,5.0,0.5,8.0
```

### 步骤3：修改 enemy_visual.csv

在最后添加一行：
```csv
archer_enemy,res://assets/sprites/Enemies/Enemy_Archer.png,0.9,0.9,0.8,0.6,0.2,1,0,0,0,18,36,36,1,1,1,1
```

### 步骤4：修改 wave_units_config.csv

在适当的波次中添加：
```csv
wave_6_to_10,res://scenes/unit/enemy/enemy_generic.tscn,archer_enemy,2.0
```

### 步骤5：测试

1. 按 F5 刷新项目
2. 按 F5 启动游戏
3. 验证敌人是否正常工作

---

## 🎯 敌人类型配置指南

### 基础敌人（无特殊能力）

**配置示例**:
```csv
# enemy_config.csv
basic_archer,基础弓箭手,90,180,12,80,1.2,22,11,0.5,5,0.8,0.6,0.2,20.0,60.0,0.8,0.6,3.5,3.0,40.0,0,2.0,5,60.0,2000.0,60.0,5.0,0.5,8.0
```

**关键参数**:
- `can_charge = 0` (不冲锋)
- `shoot_cooldown = 2.0` (不射击，设置为0即可)
- `pool_radius = 60.0` (不留毒池，设置为0即可)

### 冲锋敌人（能冲锋）

**配置示例**:
```csv
charger_enemy,冲锋者,100,150,15,50,1,25,15,0.6,8,1,0.2,0.2,20.0,60.0,0.8,0.6,3.5,3.0,40.0,1,3.0,3,45.0,1800.0,60.0,5.0,0.5,8.0
```

**关键参数**:
- `can_charge = 1` (启用冲锋)
- `charge_prep_time = 0.8` (预备时间)
- `charge_duration = 0.6` (冲锋持续时间)
- `charge_speed_mult = 3.5` (冲锋速度倍率)
- `charge_cooldown = 3.0` (冲锋冷却)

### 射击敌人（能射击）

**配置示例**:
```csv
shooter_enemy,射手,150,100,6,50,1.5,20,12,0.8,6,0.5,0.8,1,20.0,60.0,0.8,0.6,3.5,3.0,40.0,0,2.5,3,45.0,1800.0,60.0,5.0,0.5,8.0
```

**关键参数**:
- `shoot_cooldown = 2.5` (射击冷却)
- `projectile_count = 3` (投射物数量)
- `projectile_arc_angle = 45.0` (投射物弧角)
- `projectile_speed = 1800.0` (投射物速度)

**敌人类型识别**:
```gdscript
# 在 enemy.gd 中，系统会自动识别敌人类型
# 如果 enemy_id 包含 "shielded" 或其他特定关键字，会自动启用射击
```

### 毒池敌人（死后留毒池）

**配置示例**:
```csv
poison_enemy,毒液怪,80,120,8,45,1.2,12,6,0.4,4,0.5,1,0.5,20.0,60.0,0.8,0.6,3.5,3.0,40.0,0,3.0,3,45.0,1800.0,80.0,8.0,0.5,10.0
```

**关键参数**:
- `pool_radius = 80.0` (毒池半径)
- `pool_damage = 8.0` (毒池伤害)
- `pool_damage_interval = 0.5` (伤害间隔)
- `pool_lifetime = 10.0` (毒池生命周期)

**敌人类型识别**:
```gdscript
# 在 enemy.gd 中，系统会自动识别敌人类型
# 如果 enemy_id 包含 "mine_layer" 或其他特定关键字，会自动启用毒池
```

---

## 🔧 高级配置

### 敌人类型识别规则

系统通过 `enemy_id` 自动识别敌人类型：

```gdscript
# scenes/unit/enemy/enemy.gd
func _set_enemy_type_from_id() -> void:
    match enemy_id:
        "breaker_enemy":
            enemy_type = EnemyType.LINE_BREAKER
        "shielded_enemy":
            enemy_type = EnemyType.SHIELDED
        "spiked_enemy":
            enemy_type = EnemyType.SPIKED
        "mine_layer_enemy":
            enemy_type = EnemyType.MINE_LAYER
        _:
            enemy_type = EnemyType.NORMAL
```

**如果你想添加新的敌人类型**（例如射击敌人），需要：

1. 在 `enemy.gd` 中添加新的敌人类型到 `EnemyType` 枚举
2. 在 `_set_enemy_type_from_id()` 中添加识别规则
3. 在 `_setup_special_nodes()` 中添加特殊节点生成逻辑

### 自定义敌人颜色

有两种方式设置敌人颜色：

**方式1：在 enemy_config.csv 中设置**
```csv
archer_enemy,...,0.8,0.6,0.2,...
```

**方式2：在 enemy_visual.csv 中设置**
```csv
archer_enemy,...,0.8,0.6,0.2,1,...
```

优先级：`enemy_visual.csv` > `enemy_config.csv`

### 自定义敌人大小

在 `enemy_visual.csv` 中设置缩放：

```csv
archer_enemy,res://assets/sprites/Enemies/Enemy_Archer.png,0.9,0.9,...
```

- `scale_x = 0.9` (X轴缩放 90%)
- `scale_y = 0.9` (Y轴缩放 90%)

---

## 📊 参数调整建议

### 如果敌人太强

- 减少 `health` (生命值)
- 减少 `damage` (攻击力)
- 增加 `attack_cooldown` (攻击冷却)
- 减少 `xp_value` 和 `gold_value` (奖励)

### 如果敌人太弱

- 增加 `health` (生命值)
- 增加 `damage` (攻击力)
- 减少 `attack_cooldown` (攻击冷却)
- 增加 `xp_value` 和 `gold_value` (奖励)

### 如果敌人太快

- 减少 `speed` (移动速度)
- 增加 `stop_distance` (停止距离)

### 如果敌人太慢

- 增加 `speed` (移动速度)
- 减少 `stop_distance` (停止距离)

---

## ✅ 检查清单

### 添加新敌人前
- [ ] 准备好敌人精灵图片
- [ ] 决定敌人的基本属性（生命值、速度、攻击力等）
- [ ] 决定敌人的特殊能力（冲锋、射击、毒池等）

### 添加新敌人时
- [ ] 将精灵放到 `assets/sprites/Enemies/` 目录
- [ ] 在 `enemy_config.csv` 中添加敌人配置
- [ ] 在 `enemy_visual.csv` 中添加敌人视觉配置
- [ ] 在 `wave_units_config.csv` 中添加敌人到波次

### 添加新敌人后
- [ ] 刷新项目（按 F5）
- [ ] 启动游戏（按 F5）
- [ ] 验证敌人是否正常工作
- [ ] 检查控制台是否有错误信息
- [ ] 测试敌人的所有功能

---

## 🎓 常见问题

### Q1: 敌人无法生成

**A**: 检查以下几点：
1. 敌人ID是否在所有三个配置表中都添加了
2. 精灵路径是否正确
3. 波次ID是否正确
4. 是否刷新了项目

### Q2: 敌人生成但看不到

**A**: 检查以下几点：
1. 精灵路径是否正确
2. 敌人的缩放是否太小
3. 敌人的颜色是否与背景相同
4. Z层级是否正确

### Q3: 敌人的特殊能力不工作

**A**: 检查以下几点：
1. 敌人ID是否包含正确的关键字（例如 "shielded" 用于射击）
2. 特殊能力参数是否正确设置
3. 是否需要在 `enemy.gd` 中添加新的敌人类型识别

### Q4: 如何添加新的敌人类型（例如新的特殊能力）

**A**: 需要修改 `enemy.gd` 脚本：
1. 在 `EnemyType` 枚举中添加新类型
2. 在 `_set_enemy_type_from_id()` 中添加识别规则
3. 在 `_setup_special_nodes()` 中添加特殊节点生成逻辑
4. 在 `_apply_behavior_from_config()` 中添加参数加载逻辑

---

## 📚 相关文件

- `scenes/unit/enemy/enemy_generic.tscn` - 通用敌人模板
- `scenes/unit/enemy/enemy.gd` - 敌人脚本
- `config/enemy/enemy_config.csv` - 敌人参数配置
- `config/enemy/enemy_visual.csv` - 敌人视觉配置
- `config/wave/wave_units_config.csv` - 波次配置

---

## 🎉 总结

添加新敌人只需要：

1. **准备精灵** - 放到 `assets/sprites/Enemies/` 目录
2. **修改三个表** - 添加敌人参数、视觉、波次配置
3. **测试验证** - 刷新项目并启动游戏

**无需创建新文件或修改代码！**

所有敌人都使用同一个通用模板 `enemy_generic.tscn`，通过配置表驱动。

---

**最后更新**: 2026-01-18  
**难度**: ⭐⭐ 中等  
**时间**: 15-30 分钟

