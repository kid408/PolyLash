# CSV配置清理与优化 - 详细改动文档

## 概述

本文档详细列出了代码与CSV配置之间的差异分析，包括：
1. **无用的CSV配置项**（可以删除）
2. **代码中的硬编码变量**（需要迁移到CSV）
3. **建议的改动方案**

---

## 一、无用的CSV配置项分析

### 1.1 enemy_config.csv

| 列名 | 当前状态 | 分析结果 |
|------|----------|----------|
| enemy_id | ✅ 使用中 | 作为主键，被ConfigManager使用 |
| display_name | ⚠️ 未使用 | 代码中未读取此字段，仅用于注释 |
| health | ✅ 使用中 | 被enemy.gd通过stats使用 |
| speed | ✅ 使用中 | 被enemy.gd通过stats使用 |
| damage | ⚠️ 部分使用 | 在spawner中增强，但敌人本身未直接使用 |
| attack_range | ❌ 未使用 | 代码中未读取此字段 |
| attack_cooldown | ❌ 未使用 | 代码中未读取此字段 |
| xp_value | ❌ 未使用 | 代码中未实现经验系统 |
| gold_value | ❌ 未使用 | 代码中未实现金币系统 |
| knockback_resistance | ❌ 未使用 | 代码中未读取此字段 |
| energy_drop | ✅ 使用中 | 在enemy.gd的destroy_enemy()中使用 |
| color_r/g/b | ✅ 使用中 | 在enemy.gd的_apply_color_from_config()中使用 |

**暂时保留的列,后续会添加对应的功能：**
- `attack_range` - 敌人攻击范围未实现
- `attack_cooldown` - 敌人攻击冷却未实现
- `xp_value` - 经验系统未实现
- `gold_value` - 金币系统未实现
- `knockback_resistance` - 击退抗性未实现

### 1.2 enemy_visual.csv

| 列名 | 当前状态 | 分析结果 |
|------|----------|----------|
| enemy_id | ✅ 使用中 | 作为主键 |
| sprite_path | ❌ 未使用 | 敌人精灵在场景文件中设置，未从CSV加载 |
| scale_x/y | ❌ 未使用 | 敌人缩放在场景文件中设置 |
| color_r/g/b/a | ❌ 未使用 | 颜色在enemy_config.csv中配置 |
| z_index | ❌ 未使用 | Z层级在场景文件中设置 |

**建议：** 将对应的场景属性通过读csv表进行初始化。

### 1.3 player_config.csv

| 列名 | 当前状态 | 分析结果 |
|------|----------|----------|
| player_id | ✅ 使用中 | 作为主键 |
| display_name | ⚠️ 未使用 | 仅用于注释 |
| health | ✅ 使用中 | 在player_base.gd中加载到stats |
| skill_q_cost | ✅ 使用中 | 在player_base.gd中加载 |
| skill_e_cost | ✅ 使用中 | 在player_base.gd中加载 |
| close_threshold | ✅ 使用中 | 在player_base.gd中加载 |
| energy_regen | ✅ 使用中 | 在player_base.gd中加载 |
| max_energy | ✅ 使用中 | 在player_base.gd中加载 |
| initial_energy | ✅ 使用中 | 在player_base.gd中加载 |
| max_armor | ✅ 使用中 | 在player_base.gd中加载 |
| base_speed | ✅ 使用中 | 在player_base.gd中加载 |
| description | ⚠️ 未使用 | 仅用于注释 |

**保留列,方便后续维护管理：**
- `display_name` - 可保留用于UI显示，但当前未使用
- `description` - 可保留用于UI显示，但当前未使用

### 1.4 skill_params.csv

**当前CSV列：**
```
skill_id, energy_cost, cooldown, dash_distance, dash_speed, dash_damage, 
fixed_segment_length, saw_fly_speed, saw_damage_tick, saw_damage_open, 
chain_radius, stake_throw_speed, stake_impact_damage, recall_fly_speed, 
recall_damage, recall_execute_mult, auto_recall_delay, stun_radius, 
stun_duration, explosion_radius, fire_line_damage, fire_line_duration, 
fire_line_width, fire_sea_damage, fire_sea_duration, fire_nova_radius, 
fire_nova_damage, fire_nova_duration, wind_wall_pull_force, wind_wall_damage, 
storm_zone_damage, storm_eye_radius, storm_eye_damage, mine_damage, 
mine_trigger_radius, mine_explosion_radius, totem_duration, totem_max_health, 
energy_per_10px, energy_threshold_distance, energy_scale_multiplier
```

**分析结果：**
- 大部分参数都被对应的技能类使用
- 但有些参数在CSV中定义但技能类中使用了硬编码值

---

## 二、代码中的硬编码变量分析

### 2.1 PlayerButcher (player_butcher.gd)

| 变量名 | 硬编码值 | CSV状态 | 建议 |
|--------|----------|---------|------|
| stake_duration | 6.0 | ❌ 未在CSV | 添加到skill_params.csv |
| chain_radius | 250.0 | ✅ 在CSV | 从CSV加载 |
| stake_throw_speed | 1200.0 | ✅ 在CSV | 从CSV加载 |
| stake_impact_damage | 20 | ✅ 在CSV | 从CSV加载 |
| fixed_segment_length | 400.0 | ✅ 在CSV | 从CSV加载 |
| saw_fly_speed | 1100.0 | ✅ 在CSV | 从CSV加载 |
| saw_rotation_speed | 25.0 | ❌ 未在CSV | 添加到skill_params.csv |
| saw_push_force | 1000.0 | ❌ 未在CSV | 添加到skill_params.csv |
| saw_damage_tick | 3 | ✅ 在CSV | 从CSV加载 |
| saw_damage_open | 1 | ✅ 在CSV | 从CSV加载 |
| dismember_damage | 200 | ❌ 未在CSV | 添加到skill_params.csv |
| saw_max_distance | 900.0 | ❌ 未在CSV | 添加到skill_params.csv |

### 2.2 PlayerHerder (player_herder.gd)

| 变量名 | 硬编码值 | CSV状态 | 建议 |
|--------|----------|---------|------|
| fixed_segment_length | 600.0 | ⚠️ CSV中是300 | 需要同步 |
| dash_base_damage | 10 | ❌ 未在CSV | 添加到skill_params.csv |
| geometry_mask_color | Color(1, 0.0, 0.0, 0.6) | ❌ 未在CSV | 可保留为代码常量 |
| explosion_radius | 200.0 | ✅ 在CSV | 从CSV加载 |
| explosion_damage | 100 | ❌ 未在CSV | 添加到skill_params.csv |

### 2.3 PlayerPyro (player_pyro.gd)

| 变量名 | 硬编码值 | CSV状态 | 建议 |
|--------|----------|---------|------|
| fire_line_damage | 20 | ✅ 在CSV | 从CSV加载 |
| fire_line_duration | 5.0 | ✅ 在CSV | 从CSV加载 |
| fire_line_width | 24.0 | ✅ 在CSV | 从CSV加载 |
| fire_sea_damage | 40 | ✅ 在CSV | 从CSV加载 |
| fire_sea_duration | 5.0 | ✅ 在CSV | 从CSV加载 |
| fire_nova_radius | 140.0 | ✅ 在CSV | 从CSV加载 |
| fire_nova_damage | 35 | ✅ 在CSV | 从CSV加载 |
| fire_nova_duration | 3.0 | ✅ 在CSV | 从CSV加载 |

### 2.4 PlayerWeaver (player_weaver.gd)

| 变量名 | 硬编码值 | CSV状态 | 建议 |
|--------|----------|---------|------|
| fixed_segment_length | 320.0 | ⚠️ CSV中是320 | ✅ 一致 |
| auto_recall_delay | 8.0 | ✅ 在CSV | 从CSV加载 |
| recall_fly_speed | 3.0 | ✅ 在CSV | 从CSV加载 |
| recall_damage | 40 | ✅ 在CSV | 从CSV加载 |
| recall_execute_mult | 3.0 | ✅ 在CSV | 从CSV加载 |
| stun_radius | 300.0 | ✅ 在CSV | 从CSV加载 |
| stun_duration | 2.5 | ✅ 在CSV | 从CSV加载 |
| stun_color | Color(...) | ❌ 未在CSV | 可保留为代码常量 |

### 2.5 PlayerWind (player_wind.gd)

| 变量名 | 硬编码值 | CSV状态 | 建议 |
|--------|----------|---------|------|
| wind_wall_pull_force | 350.0 | ✅ 在CSV | 从CSV加载 |
| wind_wall_damage | 15 | ✅ 在CSV | 从CSV加载 |
| wind_wall_duration | 3.0 | ❌ 未在CSV | 添加到skill_params.csv |
| wind_wall_width | 24.0 | ❌ 未在CSV | 添加到skill_params.csv |
| wind_wall_effect_radius | 120.0 | ❌ 未在CSV | 添加到skill_params.csv |
| storm_zone_damage | 30 | ✅ 在CSV | 从CSV加载 |
| storm_zone_pull_force | 400.0 | ❌ 未在CSV | 添加到skill_params.csv |
| storm_zone_duration | 3.0 | ❌ 未在CSV | 添加到skill_params.csv |
| storm_eye_radius | 140.0 | ✅ 在CSV | 从CSV加载 |
| storm_eye_damage | 35 | ✅ 在CSV | 从CSV加载 |
| storm_eye_pull_force | 500.0 | ❌ 未在CSV | 添加到skill_params.csv |
| storm_eye_duration | 3.0 | ❌ 未在CSV | 添加到skill_params.csv |

### 2.6 PlayerSapper (player_sapper.gd)

| 变量名 | 硬编码值 | CSV状态 | 建议 |
|--------|----------|---------|------|
| mine_damage | 150 | ✅ 在CSV | 从CSV加载 |
| mine_trigger_radius | 20.0 | ✅ 在CSV | 从CSV加载 |
| mine_explosion_radius | 120.0 | ✅ 在CSV | 从CSV加载 |
| mine_density_distance | 50.0 | ❌ 未在CSV | 添加到skill_params.csv |
| mine_area_density | 60.0 | ❌ 未在CSV | 添加到skill_params.csv |
| totem_duration | 8.0 | ✅ 在CSV | 从CSV加载 |
| totem_max_health | 200.0 | ✅ 在CSV | 从CSV加载 |

### 2.7 SkillDash (skill_dash.gd)

| 变量名 | 硬编码值 | CSV状态 | 建议 |
|--------|----------|---------|------|
| dash_distance | 400.0 | ✅ 在CSV | 从CSV加载 |
| dash_speed | 2000.0 | ✅ 在CSV | 从CSV加载 |
| dash_damage | 20 | ⚠️ CSV中是0 | 需要同步 |
| dash_knockback | 2.0 | ❌ 未在CSV | 添加到skill_params.csv |

### 2.8 SkillHerderLoop (skill_herder_loop.gd)

| 变量名 | 硬编码值 | CSV状态 | 建议 |
|--------|----------|---------|------|
| energy_per_10px | 1.0 | ✅ 在CSV | 从CSV加载 |
| energy_threshold_distance | 1800.0 | ✅ 在CSV | 从CSV加载 |
| energy_scale_multiplier | 0.0005 | ✅ 在CSV | 从CSV加载 |
| dash_speed | 2000.0 | ✅ 在CSV | 从CSV加载 |
| dash_base_damage | 10 | ❌ 未在CSV | 添加到skill_params.csv |
| dash_knockback | 2.0 | ❌ 未在CSV | 添加到skill_params.csv |
| close_threshold | 60.0 | ✅ 从owner加载 | 保持现状 |
| POINT_INTERVAL | 10.0 | ❌ 常量 | 可保留为代码常量 |

### 2.9 Enemy (enemy.gd)

| 变量名 | 硬编码值 | CSV状态 | 建议 |
|--------|----------|---------|------|
| flock_push | 20.0 | ❌ 未在CSV | 添加到enemy_config.csv |
| stop_distance | 60.0 | ❌ 未在CSV | 添加到enemy_config.csv |
| charge_prep_time | 0.8 | ❌ 未在CSV | 添加到enemy_config.csv |
| charge_duration | 0.6 | ❌ 未在CSV | 添加到enemy_config.csv |
| charge_speed_mult | 3.5 | ❌ 未在CSV | 添加到enemy_config.csv |
| charge_cooldown | 3.0 | ❌ 未在CSV | 添加到enemy_config.csv |
| break_radius | 40.0 | ❌ 未在CSV | 添加到enemy_config.csv |

### 2.10 Spawner (spawner.gd)

| 变量名 | 硬编码值 | CSV状态 | 建议 |
|--------|----------|---------|------|
| spawn_area_size | Vector2(1000, 500) | ❌ 未在CSV | 添加到map_config.csv |
| max_waves | 10 | ❌ 未在CSV | 添加到game_config.csv |
| enemy_health_per_wave | 10.0 | ❌ 未在CSV | 添加到game_config.csv |
| enemy_damage_per_wave | 2.0 | ❌ 未在CSV | 添加到game_config.csv |

### 2.11 ChestManager (chest_manager.gd)

| 变量名 | 硬编码值 | CSV状态 | 建议 |
|--------|----------|---------|------|
| spawn_density | 3 | ✅ 从map_config加载 | 保持现状 |
| spawn_radius | 2000.0 | ✅ 从map_config加载 | 保持现状 |
| camera_view_range | 1500.0 | ❌ 未在CSV | 添加到map_config.csv |
| generation_interval | 5.0 | ❌ 未在CSV | 使用wave_chest_config |
| MIN_DISTANCE_BETWEEN_CHESTS | 500.0 | ❌ 常量 | 添加到chest_config.csv |

### 2.12 Global (global.gd)

| 变量名 | 硬编码值 | CSV状态 | 建议 |
|--------|----------|---------|------|
| POOL_SIZE | 32 | ❌ 常量 | 可保留为代码常量 |
| 音效文件路径 | 硬编码 | ⚠️ sound_config.csv存在但未使用 | 从CSV加载 |

### 2.13 PlayerBase (player_base.gd)

| 变量名 | 硬编码值 | CSV状态 | 建议 |
|--------|----------|---------|------|
| external_force_decay | 50.0 | ❌ 未在CSV | 添加到player_config.csv |
| reduction_per_armor | 0.2 | ❌ 未在CSV | 添加到game_config.csv |
| knockback_scale | 0.3 | ❌ 未在CSV | 添加到player_config.csv |

---

## 三、建议的改动方案

### 3.1 CSV列处理策略
**原则：暂时不删除任何CSV列**，保留所有现有配置项以便后续功能扩展。

### 3.2 enemy_visual.csv 增强方案（快速添加敌人）

**目标：** 实现"复制场景 + 修改CSV = 完成新敌人"的快速工作流

#### 当前问题
- 敌人的视觉属性（精灵、缩放、碰撞体等）硬编码在场景文件中
- 添加新敌人需要手动编辑场景文件的多个节点

#### 解决方案：CSV驱动的敌人视觉配置

**enemy_visual.csv 增强后的列：**
```csv
enemy_id, sprite_path, scale_x, scale_y, offset_x, offset_y, 
collision_radius, hitbox_width, hitbox_height, z_index,
animation_speed, flash_color_r, flash_color_g, flash_color_b
```

**新增列说明：**
| 列名 | 类型 | 说明 | 默认值 |
|------|------|------|--------|
| offset_x | float | 精灵X偏移 | 0.0 |
| offset_y | float | 精灵Y偏移 | 0.0 |
| collision_radius | float | 碰撞体半径 | 20.0 |
| hitbox_width | float | 受击框宽度 | 40.0 |
| hitbox_height | float | 受击框高度 | 40.0 |
| animation_speed | float | 动画播放速度 | 1.0 |
| flash_color_r/g/b | float | 受击闪烁颜色 | 1.0, 1.0, 1.0 |

**实现方式：**
1. 在 `enemy.gd` 的 `_ready()` 中添加 `_apply_visual_from_config()` 方法
2. 根据 `enemy_id` 从 `enemy_visual.csv` 加载配置
3. 动态设置精灵、缩放、碰撞体等属性

**添加新敌人的工作流：**
```
1. 复制 enemy.tscn → new_enemy.tscn
2. 复制 enemy.gd → new_enemy.gd（如需特殊行为）
3. 在 enemy_config.csv 添加一行（属性配置）
4. 在 enemy_visual.csv 添加一行（视觉配置）
5. 完成！
```

**代码示例：**
```gdscript
# enemy.gd 中添加
func _apply_visual_from_config() -> void:
    var visual_config = ConfigManager.get_enemy_visual(enemy_id)
    if visual_config.is_empty():
        return
    
    # 设置精灵
    if visual_config.has("sprite_path") and visual_config.sprite_path != "":
        var texture = load(visual_config.sprite_path)
        if texture:
            $Sprite2D.texture = texture
    
    # 设置缩放
    if visual_config.has("scale_x") and visual_config.has("scale_y"):
        $Sprite2D.scale = Vector2(visual_config.scale_x, visual_config.scale_y)
    
    # 设置碰撞体
    if visual_config.has("collision_radius"):
        $CollisionShape2D.shape.radius = visual_config.collision_radius
    
    # 设置受击框
    if visual_config.has("hitbox_width") and visual_config.has("hitbox_height"):
        $Hitbox/CollisionShape2D.shape.size = Vector2(
            visual_config.hitbox_width, 
            visual_config.hitbox_height
        )
```

### 3.3 需要添加到CSV的新列

#### skill_params.csv 新增列
```
stake_duration, saw_rotation_speed, saw_push_force, dismember_damage, 
saw_max_distance, dash_base_damage, explosion_damage, wind_wall_duration, 
wind_wall_width, wind_wall_effect_radius, storm_zone_pull_force, 
storm_zone_duration, storm_eye_pull_force, storm_eye_duration, 
mine_density_distance, mine_area_density, dash_knockback
```

#### enemy_config.csv 新增列
```
flock_push, stop_distance, charge_prep_time, charge_duration, 
charge_speed_mult, charge_cooldown, break_radius, can_charge
```

#### map_config.csv 新增列
```
spawn_area_width, spawn_area_height, camera_view_range, 
min_distance_between_chests
```

#### game_config.csv 新增列
```
max_waves, enemy_health_per_wave, enemy_damage_per_wave, 
armor_reduction_per_level
```

#### player_config.csv 新增列
```
external_force_decay, knockback_scale
```

### 3.4 需要同步的值（以代码中的值为准）

**重要原则：** 迁移时以代码中的硬编码值为准，因为当前游戏手感已调整好。

| 位置 | 变量 | 代码值 | CSV值 | 操作 |
|------|------|--------|-------|------|
| skill_dash | dash_damage | 20 | 0 | 更新CSV为20 |
| player_herder | fixed_segment_length | 600.0 | 300.0 | 更新CSV为600.0 |

**迁移后验证：** 游戏行为必须与迁移前完全一致，不能有任何手感变化。

---

## 四、实施优先级

### 高优先级（核心功能）
1. **增强 enemy_visual.csv** - 实现CSV驱动的敌人视觉配置
2. 同步 skill_params.csv 中的值（以代码值为准）
3. 添加敌人行为相关参数到 enemy_config.csv

### 中优先级（代码整洁）
1. 添加技能参数到 skill_params.csv
2. 添加地图参数到 map_config.csv
3. 添加波次系统参数到 game_config.csv

### 低优先级（可选优化）
1. 从 sound_config.csv 加载音效配置
2. 添加视觉效果颜色到配置（如 geometry_mask_color）

---

## 五、风险评估

### 低风险改动
- 添加新的CSV列（有默认值）
- 修改代码以从CSV加载参数（保持默认值与原硬编码一致）

### 中风险改动
- 修改现有CSV值以匹配代码中的硬编码值
- 实现 enemy_visual.csv 驱动的视觉配置

### 注意事项
- **不删除任何CSV列**
- **不删除任何CSV文件**
- **迁移后游戏行为必须与迁移前完全一致**

---

## 六、测试建议

1. **单元测试**：验证ConfigManager能正确加载所有新增配置
2. **集成测试**：验证游戏行为与修改前一致
3. **回归测试**：确保所有角色和技能正常工作
4. **平衡测试**：确认数值调整后游戏平衡性
