# Requirements Document

## Introduction

本文档定义角色选择面板（SelectionPanel）的功能需求。该面板允许玩家在游戏开始前选择最多3个角色并配置武器，游戏中可通过TAB键在已选角色间切换，每个角色拥有独立的血量和能量状态。

## Glossary

- **SelectionPanel**: 角色选择面板，游戏开始前的角色配置界面
- **PlayerContainer**: 角色列表区，显示所有可选角色
- **WeaponContainer**: 武器选择区，显示当前角色可用武器
- **PlayerInfo**: 角色信息区，显示选中角色的详细信息
- **SelectedList**: 已选角色列表，显示玩家已选择的角色槽位
- **ConfigManager**: 配置管理器，负责加载CSV配置文件
- **player_states**: 角色状态存储，保存每个角色的独立血量和能量

## Requirements

### Requirement 1: CSV配置扩展

**User Story:** As a 开发者, I want to 通过CSV配置角色选择界面的参数, so that 可以灵活调整角色显示和选择规则。

#### Acceptance Criteria

1. WHEN ConfigManager加载player_config.csv THEN THE ConfigManager SHALL 支持新增列display_order、enabled、ties、health_regen
2. WHEN ConfigManager加载game_config.csv THEN THE ConfigManager SHALL 支持新增行selection_players_per_row和max_selected_players
3. WHEN ConfigManager初始化 THEN THE ConfigManager SHALL 加载新建的player_available_weapons.csv文件
4. THE ConfigManager SHALL 提供get_enabled_players()方法返回启用的角色列表（按display_order排序）
5. THE ConfigManager SHALL 提供get_player_available_weapons(player_id)方法返回角色可用武器类型列表

### Requirement 2: 角色列表显示

**User Story:** As a 玩家, I want to 在角色列表中看到所有可选角色, so that 我可以选择想要使用的角色。

#### Acceptance Criteria

1. WHEN SelectionPanel初始化 THEN THE PlayerContainer SHALL 根据player_config.csv动态生成角色按钮
2. WHEN 生成角色按钮 THEN THE SelectionPanel SHALL 只显示enabled=1的角色
3. WHEN 生成角色按钮 THEN THE SelectionPanel SHALL 按display_order升序排列角色
4. WHEN 角色数量超过每行限制 THEN THE PlayerContainer SHALL 自动换行显示
5. THE PlayerContainer SHALL 每行显示的角色数量从game_config.csv的selection_players_per_row读取
6. WHEN 生成角色按钮 THEN THE SelectionPanel SHALL 使用player_visual.csv的sprite_path作为按钮图标

### Requirement 3: 角色信息显示

**User Story:** As a 玩家, I want to 查看角色的详细信息, so that 我可以了解角色的属性和特点。

#### Acceptance Criteria

1. WHEN 玩家点击角色按钮 THEN THE PlayerInfo SHALL 显示该角色的图标（sprite_path）
2. WHEN 玩家点击角色按钮 THEN THE PlayerInfo SHALL 显示该角色的display_name
3. WHEN 玩家点击角色按钮 THEN THE PlayerInfo SHALL 显示该角色的ties（羁绊类型）
4. WHEN 玩家点击角色按钮 THEN THE PlayerInfo SHALL 显示角色属性（格式：属性注释:值）
5. THE PlayerInfo SHALL 显示以下属性：生命值、Q技能消耗、E技能消耗、能量恢复、最大能量、最大护甲、移动速度、说明

### Requirement 4: 武器选择

**User Story:** As a 玩家, I want to 为角色选择武器, so that 我可以自定义角色的战斗方式。

#### Acceptance Criteria

1. WHEN 玩家点击角色按钮 THEN THE WeaponContainer SHALL 动态生成该角色可用的武器按钮
2. THE WeaponContainer SHALL 只显示每种武器类型的1级武器
3. WHEN WeaponContainer初始化 THEN THE SelectionPanel SHALL 默认选中第一把可用武器
4. WHEN 玩家点击武器按钮 THEN THE SelectionPanel SHALL 更新当前角色的武器选择
5. IF 角色已在SelectedList中 THEN THE SelectionPanel SHALL 立即更新该角色的武器配置

### Requirement 5: 角色选择与拖拽

**User Story:** As a 玩家, I want to 通过拖拽选择角色, so that 我可以直观地组建角色队伍。

#### Acceptance Criteria

1. WHEN SelectionPanel初始化 THEN THE SelectedList SHALL 根据max_selected_players动态生成槽位按钮
2. WHEN 玩家拖拽角色到SelectedList THEN THE SelectionPanel SHALL 将角色添加到空槽位
3. IF 拖拽时未选择武器 THEN THE SelectionPanel SHALL 自动选择该角色的第一把可用武器
4. WHEN 已选角色数量达到max_selected_players THEN THE SelectionPanel SHALL 阻止添加更多角色
5. WHEN 玩家点击SelectedList中的角色 THEN THE SelectionPanel SHALL 从列表中移除该角色
6. WHEN 角色被选中 THEN THE PlayerContainer SHALL 显示该角色按钮的"已选中"状态

### Requirement 6: 确认并开始游戏

**User Story:** As a 玩家, I want to 确认选择并开始游戏, so that 我可以使用选择的角色进行游戏。

#### Acceptance Criteria

1. IF 玩家未选择任何角色 THEN THE Continue按钮 SHALL 处于禁用状态
2. WHEN 玩家点击Continue按钮 THEN THE SelectionPanel SHALL 将选择数据保存到Global
3. WHEN 玩家点击Continue按钮 THEN THE SelectionPanel SHALL 切换到游戏场景
4. THE Global SHALL 存储selected_player_ids（已选角色ID列表）
5. THE Global SHALL 存储selected_player_weapons（已选角色武器配置）

### Requirement 7: 游戏中角色切换

**User Story:** As a 玩家, I want to 在游戏中切换角色, so that 我可以根据战况使用不同角色。

#### Acceptance Criteria

1. WHEN 玩家按下TAB键 THEN THE Global SHALL 切换到下一个已选角色
2. WHEN 切换角色 THEN THE Global SHALL 保存当前角色的血量、能量、护甲状态
3. WHEN 切换角色 THEN THE Global SHALL 恢复目标角色之前保存的状态
4. THE Global SHALL 按SelectedList的顺序循环切换角色
5. IF 只选择了1个角色 THEN THE Global SHALL 忽略TAB键切换请求

### Requirement 8: 角色独立状态管理

**User Story:** As a 玩家, I want to 每个角色有独立的血量和能量, so that 我可以策略性地切换角色。

#### Acceptance Criteria

1. THE Global SHALL 为每个已选角色维护独立的player_states
2. THE player_states SHALL 包含health、max_health、energy、max_energy、armor、health_regen、energy_regen
3. WHEN 角色未激活时 THEN THE Global SHALL 持续恢复该角色的能量（使用energy_regen）
4. WHEN 角色未激活且health_regen>0时 THEN THE Global SHALL 持续恢复该角色的血量
5. THE 恢复速率 SHALL 从player_config.csv的energy_regen和health_regen列读取

### Requirement 9: 角色死亡处理

**User Story:** As a 玩家, I want to 在角色死亡时游戏结束, so that 游戏有明确的失败条件。

#### Acceptance Criteria

1. WHEN 任意角色血量归零 THEN THE PlayerBase SHALL 触发游戏结束
2. WHEN 游戏结束 THEN THE Global SHALL 调用game_over()方法
3. THE 游戏结束 SHALL 显示Game Over界面或重新加载场景
