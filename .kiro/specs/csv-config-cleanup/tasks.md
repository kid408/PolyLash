# Implementation Plan: CSV配置清理与优化

## Overview

本实施计划将代码中的硬编码变量迁移到CSV配置文件，并增强enemy_visual.csv以支持快速添加敌人的工作流。所有迁移以代码中的值为准，确保游戏行为完全一致。

## Tasks

- [x] 1. 增强 ConfigManager 支持新配置项
  - [x] 1.1 添加 enemy_visual.csv 的完整加载支持
    - 添加 `get_enemy_visual(enemy_id)` 方法
    - 支持新增列：offset_x, offset_y, collision_radius, hitbox_width, hitbox_height, animation_speed, flash_color_r/g/b
    - _Requirements: 6.1_
  - [x] 1.2 扩展 skill_params.csv 加载支持
    - 添加新列支持：stake_duration, saw_rotation_speed, saw_push_force, dismember_damage, saw_max_distance, dash_base_damage, explosion_damage, wind_wall_duration, wind_wall_width, wind_wall_effect_radius, storm_zone_pull_force, storm_zone_duration, storm_eye_pull_force, storm_eye_duration, mine_density_distance, mine_area_density, dash_knockback
    - _Requirements: 6.1_
  - [x] 1.3 扩展 enemy_config.csv 加载支持
    - 添加新列支持：flock_push, stop_distance, charge_prep_time, charge_duration, charge_speed_mult, charge_cooldown, break_radius, can_charge
    - _Requirements: 6.1_
  - [x] 1.4 扩展 player_config.csv 加载支持
    - 添加新列支持：external_force_decay, knockback_scale
    - _Requirements: 6.1_
  - [x] 1.5 扩展 game_config.csv 和 map_config.csv 加载支持
    - game_config: max_waves, enemy_health_per_wave, enemy_damage_per_wave, armor_reduction_per_level
    - map_config: spawn_area_width, spawn_area_height, camera_view_range, min_distance_between_chests
    - _Requirements: 6.1_

- [x] 2. 更新 CSV 配置文件
  - [x] 2.1 更新 enemy_visual.csv
    - 添加新列并填入当前场景中的值
    - 从现有敌人场景提取：collision_radius, hitbox_width, hitbox_height 等
    - _Requirements: 4.1, 4.2_
  - [x] 2.2 更新 skill_params.csv
    - 添加新列并填入代码中的硬编码值
    - 同步 dash_damage: 0 → 20
    - 同步 fixed_segment_length (herder): 300 → 600
    - _Requirements: 3.1, 3.2, 3.3_
  - [x] 2.3 更新 enemy_config.csv
    - 添加敌人行为参数列
    - 填入 enemy.gd 中的硬编码值
    - _Requirements: 4.1_
  - [x] 2.4 更新 player_config.csv
    - 添加 external_force_decay, knockback_scale 列
    - 填入 player_base.gd 中的硬编码值
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_
  - [x] 2.5 更新 game_config.csv 和 map_config.csv
    - 添加波次系统和地图相关参数
    - 填入 spawner.gd 和 chest_manager.gd 中的硬编码值
    - _Requirements: 5.1, 5.2_

- [x] 3. Checkpoint - 验证 CSV 文件格式正确
  - 确保所有 CSV 文件格式正确，可被 ConfigManager 加载
  - 如有问题请告知

- [x] 4. 实现 enemy_visual.csv 驱动的敌人视觉配置
  - [x] 4.1 在 enemy.gd 中添加 _apply_visual_from_config() 方法
    - 从 CSV 加载并应用精灵、缩放、碰撞体等配置
    - 在 _ready() 中调用
    - _Requirements: 4.1, 4.2, 6.2_
  - [x] 4.2 更新现有敌人场景以支持 CSV 配置
    - 确保场景中的默认值与 CSV 一致
    - 测试敌人视觉效果正确
    - _Requirements: 6.2_

- [x] 5. 迁移玩家角色硬编码变量
  - [x] 5.1 迁移 PlayerButcher 硬编码变量
    - 从 skill_params.csv 加载：stake_duration, saw_rotation_speed, saw_push_force, dismember_damage, saw_max_distance
    - _Requirements: 2.1_
  - [x] 5.2 迁移 PlayerHerder 硬编码变量
    - 从 skill_params.csv 加载：dash_base_damage, explosion_damage
    - _Requirements: 2.2_
  - [x] 5.3 迁移 PlayerWind 硬编码变量
    - 从 skill_params.csv 加载：wind_wall_duration, wind_wall_width, wind_wall_effect_radius, storm_zone_pull_force, storm_zone_duration, storm_eye_pull_force, storm_eye_duration
    - _Requirements: 2.5_
  - [x] 5.4 迁移 PlayerSapper 硬编码变量
    - 从 skill_params.csv 加载：mine_density_distance, mine_area_density
    - _Requirements: 2.6_
  - [x] 5.5 迁移 PlayerBase 硬编码变量
    - 从 player_config.csv 加载：external_force_decay, knockback_scale
    - 从 game_config.csv 加载：reduction_per_armor
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [x] 6. 迁移技能硬编码变量
  - [x] 6.1 迁移 SkillDash 硬编码变量
    - 从 skill_params.csv 加载：dash_knockback
    - _Requirements: 3.1_
  - [x] 6.2 迁移 SkillHerderLoop 硬编码变量
    - 从 skill_params.csv 加载：dash_base_damage, dash_knockback
    - _Requirements: 3.2_

- [x] 7. 迁移敌人硬编码变量
  - [x] 7.1 迁移 Enemy 类硬编码变量
    - 从 enemy_config.csv 加载：flock_push, stop_distance, charge_prep_time, charge_duration, charge_speed_mult, charge_cooldown, break_radius
    - _Requirements: 4.1_

- [x] 8. 迁移系统级硬编码变量
  - [x] 8.1 迁移 Spawner 硬编码变量
    - 从 map_config.csv 加载：spawn_area_width, spawn_area_height
    - 从 game_config.csv 加载：max_waves, enemy_health_per_wave, enemy_damage_per_wave
    - _Requirements: 5.1_
  - [x] 8.2 迁移 ChestManager 硬编码变量
    - 从 map_config.csv 加载：camera_view_range, min_distance_between_chests
    - _Requirements: 5.2_

- [ ] 9. Checkpoint - 验证游戏行为一致性
  - 运行游戏，验证所有角色、技能、敌人行为与迁移前完全一致
  - 如有问题请告知

- [x] 10. 添加配置加载失败的默认值处理
  - [x] 10.1 在 ConfigManager 中添加默认值回退机制
    - 当 CSV 中缺少某列时，使用代码中的原硬编码值作为默认值
    - 输出警告日志
    - _Requirements: 6.3_

## Notes

- 所有迁移以代码中的硬编码值为准，确保游戏手感不变
- 不删除任何现有 CSV 列
- enemy_visual.csv 增强后支持"复制场景 + 修改CSV = 完成新敌人"的快速工作流
- 每个 Checkpoint 后请确认游戏行为正确再继续
