# 精英敌人系统重构指南

## 概述

精英敌人系统已重构，移除了所有硬编码的资源引用。现在所有配置都通过 CSV 文件管理，使得添加新的精英敌人变得简单快捷。

## 主要改进

### 1. 移除冗余的 @export 定义

**之前**（不推荐）：
```gdscript
@export var evolution_sprites: Array[Texture2D] = [
    preload("res://assets/sprites/Enemies/Enemy_Glutton_01.png"),
    preload("res://assets/sprites/Enemies/Enemy_Glutton_02.png"),
    # ... 更多精灵
]
@export var evolution_thresholds: Array[int] = [5, 15, 30, 50]
@export var evolution_scales: Array[float] = [2.2, 2.5, 3.0, 3.5, 4.5]
```

**现在**（推荐）：
- 所有精灵路径在 `elite_evolution_config.csv` 中配置
- 所有进化阈值在 `elite_enemies_config.csv` 中配置
- 所有缩放倍数在 `elite_evolution_config.csv` 中配置

### 2. 实现了缺失的阶段能力

#### Stage 2 - 酸液投射物射击
- 自动向玩家射击酸液投射物
- 投射物造成敌人伤害的 50%
- 可配置的射击冷却和范围

#### Stage 3 - AoE 踩踏伤害
- 定期执行 AoE 踩踏攻击
- 对玩家造成伤害
- 可配置的 AoE 范围和伤害

#### Stage 4 - 继续进化
- 不再死亡，继续进化到 Stage 5
- 保持所有能力

### 3. 配置驱动的设计

所有配置现在都在 CSV 文件中，无需修改代码：

```
config/enemy/
  ├── elite_enemies_config.csv      # 基础配置和进化阈值
  └── elite_evolution_config.csv    # 每个阶段的配置

config/wave/
  ├── elite_spawn_config.csv        # 生成配置
  └── elite_wave_config.csv         # 波次配置
```

## 添加新的精英敌人

### 步骤 1: 创建敌人脚本

创建 `scenes/unit/enemy/elites/enemy_[name].gd`：

```gdscript
extends Enemy
class_name Enemy[Name]

# ==============================================================================
# 吞噬机制配置
# ==============================================================================

@export var eat_detection_radius: float = 200.0
@export var eat_cooldown: float = 2.0
@export var eat_heal_percent: float = 0.1
@export var eat_max_hp_increase: float = 1.05
@export var eat_damage_increase: float = 1.03

# ==============================================================================
# 奖励配置
# ==============================================================================

@export var base_xp_value: int = 50
@export var base_gold_value: int = 10
@export var reward_scale_per_stage: float = 2.0

# ==============================================================================
# 阶段能力配置
# ==============================================================================

# 根据需要添加特定阶段的配置
# 例如：
# @export var stage2_shoot_cooldown: float = 2.0
# @export var stage2_shoot_range: float = 300.0

# ==============================================================================
# 移动配置
# ==============================================================================

@export var base_speed: float = 150.0
@export var speed_per_stage: float = 10.0
@export var eating_pause_duration: float = 0.1

# 然后复制 EnemyGlutton 的核心逻辑...
```

### 步骤 2: 添加到 elite_enemies_config.csv

```csv
elite_id,display_name,scene_path,base_health,base_damage,base_armor,base_speed,stage_1_count,stage_2_count,stage_3_count,stage_4_count,stage_5_count
-1,精英敌人ID,场景路径,基础血量,基础伤害,基础护甲,基础速度,Stage1进化数,Stage2进化数,Stage3进化数,Stage4进化数,Stage5进化数
enemy_[name],敌人名称,res://scenes/unit/enemy/elites/enemy_[name].tscn,100,10,0,150,1,2,3,4,999
```

### 步骤 3: 添加进化配置到 elite_evolution_config.csv

```csv
elite_id,stage,health_multiplier,damage_multiplier,armor_multiplier,speed_multiplier,eat_count_per_stage,sprite_path,scale_multiplier,description
-1,阶段,血量倍数,伤害倍数,护甲倍数,速度倍数,每阶段吞噬敌人数,精灵图片路径,体型倍数,描述
enemy_[name],1,1.0,1.0,1.0,1.0,1,res://assets/sprites/Enemies/Enemy_[Name]_01.png,1.0,初始阶段
enemy_[name],2,2.0,1.2,1.0,2.067,2,res://assets/sprites/Enemies/Enemy_[Name]_02.png,1.2,第二阶段
enemy_[name],3,3.4,1.44,1.0,3.133,3,res://assets/sprites/Enemies/Enemy_[Name]_03.png,1.4,第三阶段
enemy_[name],4,4.88,1.728,1.0,4.2,4,res://assets/sprites/Enemies/Enemy_[Name]_04.png,1.6,第四阶段
enemy_[name],5,5.456,2.074,1.0,5.267,999,res://assets/sprites/Enemies/Enemy_[Name]_05.png,1.8,终极形态
```

### 步骤 4: 添加生成配置到 elite_spawn_config.csv

```csv
wave_id,elite_id,spawn_interval_min,spawn_interval_max,max_spawn_count,enabled
-1,波次ID,精英敌人ID,最小生成间隔,最大生成间隔,最大生成数,是否启用
wave_1,enemy_[name],5.0,8.0,3,true
```

### 步骤 5: 添加波次配置到 elite_wave_config.csv

```csv
wave_id,elite_id,spawn_count,spawn_weight,initial_stage,allow_evolution
-1,波次ID,精英敌人ID,生成数量,生成权重,初始阶段,是否允许进化
wave_1,enemy_[name],2,1.0,1,true
```

## 配置文件详解

### elite_enemies_config.csv

| 字段 | 说明 | 示例 |
|------|------|------|
| elite_id | 精英敌人唯一ID | enemy_glutton |
| display_name | 显示名称 | 吞噬者 |
| scene_path | 场景文件路径 | res://scenes/unit/enemy/elites/enemy_glutton.tscn |
| base_health | 基础生命值 | 80 |
| base_damage | 基础伤害 | 8 |
| base_armor | 基础护甲 | 0 |
| base_speed | 基础速度 | 150 |
| stage_1-5_count | 各阶段进化所需吞噬敌人数 | 1,2,3,4,999 |

### elite_evolution_config.csv

| 字段 | 说明 | 示例 |
|------|------|------|
| elite_id | 精英敌人ID | enemy_glutton |
| stage | 进化阶段 | 1-5 |
| health_multiplier | 血量倍数 | 1.0-5.456 |
| damage_multiplier | 伤害倍数 | 1.0-2.074 |
| armor_multiplier | 护甲倍数 | 1.0 |
| speed_multiplier | 速度倍数 | 1.0-5.267 |
| eat_count_per_stage | 该阶段需要吞噬的敌人数 | 1-999 |
| sprite_path | 精灵图片路径 | res://assets/sprites/Enemies/Enemy_Glutton_01.png |
| scale_multiplier | 体型倍数 | 1.0-1.8 |
| description | 阶段描述 | 初始阶段 |

### elite_spawn_config.csv

| 字段 | 说明 | 示例 |
|------|------|------|
| wave_id | 波次ID | wave_1 |
| elite_id | 精英敌人ID | enemy_glutton |
| spawn_interval_min | 最小生成间隔（秒） | 5.0 |
| spawn_interval_max | 最大生成间隔（秒） | 8.0 |
| max_spawn_count | 最大生成数量 | 3 |
| enabled | 是否启用 | true |

## 阶段能力实现

### Stage 2 - 酸液投射物

在 `_update_stage2_behavior()` 中实现：
- 检测玩家距离
- 定期射击投射物
- 投射物造成伤害

### Stage 3 - AoE 踩踏

在 `_update_stage3_behavior()` 中实现：
- 定期执行 AoE 检测
- 对范围内的玩家造成伤害
- 显示浮动文本反馈

### Stage 4 - 继续进化

- 不再触发死亡
- 继续进化到 Stage 5
- 保持所有能力

## 最佳实践

### 1. 不要硬编码资源

❌ **不推荐**：
```gdscript
@export var evolution_sprites: Array[Texture2D] = [preload(...), ...]
```

✅ **推荐**：
```gdscript
# 在 CSV 中配置，通过 EliteConfigManager 加载
var sprite_path = EliteConfigManager.get_sprite_path_for_stage("enemy_id", stage)
```

### 2. 使用配置管理器

❌ **不推荐**：
```gdscript
var threshold = 5  # 硬编码
```

✅ **推荐**：
```gdscript
var threshold = EliteConfigManager.get_evolution_threshold("enemy_id", stage)
```

### 3. 保持脚本简洁

- 只在脚本中实现核心逻辑
- 所有参数都应该可配置
- 使用 @export 仅用于运行时调整

### 4. CSV 编码

- 所有 CSV 文件必须使用 **UTF-8 No BOM** 编码
- 修改 CSV 后需要重启 Godot 编辑器
- 使用 Excel 或 LibreOffice 编辑时注意编码

## 常见问题

### Q: 为什么修改 CSV 后没有生效？

A: Godot 编辑器会缓存配置文件。需要完全重启编辑器。

### Q: 如何添加新的阶段能力？

A: 
1. 在脚本中添加 `_update_stage[N]_behavior()` 方法
2. 在 `_process()` 中调用该方法
3. 在 `_apply_stage_effects()` 中初始化该能力

### Q: 可以有超过 5 个阶段吗？

A: 可以。只需在 CSV 中添加更多行，并在脚本中处理新的阶段逻辑。

### Q: 如何自定义每个敌人的能力？

A: 创建继承自 Enemy 的新脚本，实现自己的 `_update_stage[N]_behavior()` 方法。

## 总结

新的精英敌人系统设计：
- ✅ 配置驱动，无需硬编码
- ✅ 易于扩展，添加新敌人简单
- ✅ 灵活配置，所有参数可调
- ✅ 代码清晰，逻辑分离

---

**最后更新**: 2026-01-17
