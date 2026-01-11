# Requirements Document

## Introduction

本文档描述了对Godot游戏项目中CSV配置文件的清理和优化需求。目标是：
1. 删除CSV表中未被代码使用的无用配置项
2. 将代码中写死的变量迁移到对应的CSV配置表中
3. 确保配置系统的一致性和可维护性

## Glossary

- **ConfigManager**: 配置管理器，负责加载和管理所有CSV配置文件
- **CSV配置表**: 存储游戏配置数据的逗号分隔值文件
- **硬编码变量**: 直接在代码中定义的常量或变量，而非从配置文件加载
- **PlayerBase**: 玩家基类，所有玩家角色继承此类
- **SkillBase**: 技能基类，所有技能继承此类
- **SkillManager**: 技能管理器，负责加载和管理玩家技能

## Requirements

### Requirement 1: 清理无用的CSV配置项

**User Story:** 作为开发者，我希望删除CSV表中未被代码使用的配置项，以保持配置文件的简洁和可维护性。

#### Acceptance Criteria

1. WHEN 分析enemy_config.csv时，THE System SHALL 识别并标记未被代码使用的列
2. WHEN 分析player_config.csv时，THE System SHALL 识别并标记未被代码使用的列
3. WHEN 分析skill_params.csv时，THE System SHALL 识别并标记未被代码使用的参数
4. WHEN 分析weapon_stats_config.csv时，THE System SHALL 识别并标记未被代码使用的属性

### Requirement 2: 迁移玩家角色硬编码变量

**User Story:** 作为开发者，我希望将玩家角色代码中的硬编码变量迁移到CSV配置表中，以便于调整和平衡。

#### Acceptance Criteria

1. WHEN 检测到PlayerButcher中的硬编码变量时，THE System SHALL 将其迁移到player_config.csv或skill_params.csv
2. WHEN 检测到PlayerHerder中的硬编码变量时，THE System SHALL 将其迁移到对应的CSV配置表
3. WHEN 检测到PlayerPyro中的硬编码变量时，THE System SHALL 将其迁移到对应的CSV配置表
4. WHEN 检测到PlayerWeaver中的硬编码变量时，THE System SHALL 将其迁移到对应的CSV配置表
5. WHEN 检测到PlayerWind中的硬编码变量时，THE System SHALL 将其迁移到对应的CSV配置表
6. WHEN 检测到PlayerSapper中的硬编码变量时，THE System SHALL 将其迁移到对应的CSV配置表

### Requirement 3: 迁移技能硬编码变量

**User Story:** 作为开发者，我希望将技能代码中的硬编码变量迁移到skill_params.csv中，以便于技能平衡调整。

#### Acceptance Criteria

1. WHEN 检测到SkillDash中的硬编码变量时，THE System SHALL 将其迁移到skill_params.csv
2. WHEN 检测到SkillHerderLoop中的硬编码变量时，THE System SHALL 将其迁移到skill_params.csv
3. WHEN 检测到其他技能类中的硬编码变量时，THE System SHALL 将其迁移到skill_params.csv

### Requirement 4: 迁移敌人硬编码变量

**User Story:** 作为开发者，我希望将敌人代码中的硬编码变量迁移到enemy_config.csv中，以便于敌人平衡调整。

#### Acceptance Criteria

1. WHEN 检测到Enemy类中的硬编码变量时，THE System SHALL 将其迁移到enemy_config.csv
2. WHEN 检测到特定敌人类型的硬编码变量时，THE System SHALL 将其迁移到对应的CSV配置表

### Requirement 5: 迁移系统级硬编码变量

**User Story:** 作为开发者，我希望将系统级硬编码变量迁移到对应的系统配置CSV中。

#### Acceptance Criteria

1. WHEN 检测到Spawner中的硬编码变量时，THE System SHALL 将其迁移到wave_config.csv或game_config.csv
2. WHEN 检测到ChestManager中的硬编码变量时，THE System SHALL 将其迁移到chest_config.csv或map_config.csv
3. WHEN 检测到Global中的硬编码变量时，THE System SHALL 将其迁移到sound_config.csv或game_config.csv

### Requirement 6: 确保配置加载正确性

**User Story:** 作为开发者，我希望确保所有迁移后的配置能够正确加载和使用。

#### Acceptance Criteria

1. WHEN 配置迁移完成后，THE ConfigManager SHALL 能够正确加载所有新增的配置项
2. WHEN 代码使用迁移后的配置时，THE System SHALL 保持与原有硬编码相同的行为
3. IF 配置加载失败，THEN THE System SHALL 使用合理的默认值并输出警告日志
