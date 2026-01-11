# 角色选择面板设计文档

## 概述

本设计文档描述角色选择面板（SelectionPanel）的完整实现方案。该面板允许玩家在游戏开始前选择最多3个角色，并为每个角色配置武器。游戏中玩家可通过TAB键在已选角色间切换。

---

## 一、功能区域划分

### 1. PlayerContainer - 角色列表区
- **位置**: 面板下方
- **功能**: 显示所有可选角色的按钮列表
- **布局规则**:
  - 每行显示N个角色（N从`game_config.csv`的`selection_players_per_row`读取，默认5）
  - 超过N个角色自动换行
  - 按钮按`display_order`列排序显示
  - 只显示`enabled=1`的角色
- **交互**: 
  - 点击角色按钮 → 在PlayerInfo区显示该角色详情
  - 拖拽角色按钮 → 可拖放到SelectedList区

### 2. WeaponContainer - 武器选择区
- **位置**: 角色列表区上方
- **功能**: 显示当前选中角色可使用的武器列表
- **动态生成**: 场景中只保留一个按钮作为模板，其他按钮根据角色可用武器配置动态生成
- **数据来源**: 新建`config/player/player_available_weapons.csv`
- **交互**: 点击武器按钮为当前角色装备该武器
- **武器更新规则**: 
  - 如果角色已在SelectedList中，选择武器后立即更新该角色的武器配置
  - 进入游戏时使用玩家最后选择的武器

### 3. PlayerInfo - 角色信息区
- **位置**: 面板中央
- **子组件**:
  - `PlayerIco`: 显示选中角色的图片（从`player_visual.csv`的`sprite_path`读取）
  - `PlayerName`: 显示角色的`display_name`
  - `PlayerTies`: 显示角色的羁绊类型（新增`ties`列）
  - `PlayerDescription`: 显示角色属性详情（格式：`属性注释: 值`）

### 4. SelectedList - 已选角色列表
- **位置**: 面板左侧
- **功能**: 显示玩家已选择的角色（最多3个）
- **动态生成**: 场景中只保留一个按钮作为模板，其他按钮根据`max_selected_players`配置动态生成
- **交互**:
  - 接受从PlayerContainer拖拽的角色
  - 点击已选角色可移除
  - 顺序决定TAB切换顺序
- **默认武器规则**: 
  - 拖拽角色到SelectedList时，如果玩家未选择武器，自动选择该角色可用武器列表中的第一把武器
  - 如果玩家之后在WeaponContainer中选择了其他武器，使用最新选择的武器

### 5. Continue - 确认按钮
- **位置**: 面板右侧
- **功能**: 确认选择并开始游戏
- **条件**: 至少选择1个角色才能点击

---

## 二、CSV配置修改

### 2.1 修改 `config/player/player_config.csv`

新增列：
| 列名 | 类型 | 说明 | 示例值 |
|------|------|------|--------|
| display_order | int | 显示顺序（升序排列） | 1, 2, 3... |
| enabled | int | 是否启用（1=启用, 0=禁用） | 1 |
| ties | string | 羁绊类型（本次只显示，不实现加成逻辑） | "战士", "法师", "刺客" |
| health_regen | float | 每秒血量恢复 | 0.0, 1.0, 2.0 |

**注意**: 角色图标直接使用`player_visual.csv`中的`sprite_path`，不需要单独的icon_path列。

修改后的CSV结构：
```csv
player_id,display_name,display_order,enabled,ties,health,health_regen,skill_q_cost,skill_e_cost,...
-1,显示名,显示顺序,是否启用,羁绊,生命值,血量恢复,Q技能消耗,E技能消耗,...
butcher,屠夫,1,1,战士,100,0.0,50,30,...
herder,牧者,2,1,召唤师,100,0.5,20,20,...
```

### 2.2 修改 `config/system/game_config.csv`

新增行：
| setting | value | description |
|---------|-------|-------------|
| selection_players_per_row | 5 | 角色选择界面每行显示的角色数量 |
| max_selected_players | 3 | 最多可选择的角色数量 |

### 2.3 新建 `config/player/player_available_weapons.csv`

角色可用武器配置表：
```csv
player_id,weapon_type_1,weapon_type_2,weapon_type_3,weapon_type_4
-1,武器类型1,武器类型2,武器类型3,武器类型4
butcher,punch,laser,,
herder,pistol,laser,punch,
pyro,laser,pistol,,
sapper,pistol,laser,,
tempest,punch,pistol,,
weaver,laser,punch,,
wind,pistol,punch,,
```

说明：
- `weapon_type_N`: 对应`weapon_config.csv`中的武器类型（如punch、laser、pistol）
- 空值表示该槽位无可用武器
- **武器显示规则**: WeaponContainer只显示每种类型的1级武器（如punch_1、laser_1、pistol_1）
- 选择武器类型后，游戏中使用该类型的1级武器

---

## 三、数据流设计

### 3.1 角色数据加载流程

```
游戏启动
    ↓
ConfigManager._ready()
    ↓
加载 player_config.csv → player_configs 字典
    ↓
SelectionPanel._ready()
    ↓
调用 _load_available_players()
    ↓
过滤 enabled=1 的角色
    ↓
按 display_order 排序
    ↓
动态创建角色按钮
```

### 3.2 角色选择数据结构

```gdscript
# 已选择的角色列表
var selected_players: Array[Dictionary] = []
# 每个元素格式:
# {
#   "player_id": "butcher",
#   "weapon_type": "punch",  # 选择的武器类型（默认为可用武器列表第一个）
#   "slot_index": 0          # 在SelectedList中的位置
# }

# 当前预览的角色（用于PlayerInfo显示和武器选择）
var preview_player_id: String = ""

# 当前预览角色选择的武器（临时存储，拖拽时使用）
var preview_weapon_type: String = ""
```

### 3.3 游戏中角色状态管理

每个角色拥有独立的血量和能量状态，切换角色时保留状态，且未激活角色持续恢复。
**重要**: 任意角色血量归零时，游戏直接结束（Game Over）。

```gdscript
# Global.gd 中新增

# 已选角色ID列表（从选择界面传入）
var selected_player_ids: Array[String] = []

# 已选角色武器配置
var selected_player_weapons: Dictionary = {}  # {player_id: weapon_type}

# 当前激活角色索引
var current_player_index: int = 0

# 角色状态存储（独立血量和能量）
var player_states: Dictionary = {}
# 格式: {
#   "butcher": {
#     "health": 100.0,
#     "max_health": 100.0,
#     "energy": 500.0,
#     "max_energy": 999.0,
#     "armor": 3,
#     "health_regen": 0.0,   # 从CSV加载
#     "energy_regen": 0.5    # 从CSV加载
#   },
#   "herder": {...},
#   ...
# }
```

### 3.4 角色切换与状态同步

```gdscript
# Global.gd

# 切换到下一个角色
func switch_to_next_player() -> void:
    if selected_player_ids.size() <= 1:
        return
    
    # 1. 保存当前角色状态
    _save_current_player_state()
    
    # 2. 计算下一个角色索引（循环）
    current_player_index = (current_player_index + 1) % selected_player_ids.size()
    
    # 3. 生成新角色并恢复状态
    var next_player_id = selected_player_ids[current_player_index]
    _spawn_player_with_state(next_player_id)

# 保存当前角色状态
func _save_current_player_state() -> void:
    if not is_instance_valid(player):
        return
    
    var player_id = player.player_id
    player_states[player_id] = {
        "health": player.health_component.current_health,
        "max_health": player.health_component.max_health,
        "energy": player.energy,
        "max_energy": player.max_energy,
        "armor": player.armor
    }

# 生成角色并恢复状态
func _spawn_player_with_state(player_id: String) -> void:
    # 销毁当前角色
    if is_instance_valid(player):
        var old_position = player.global_position
        player.queue_free()
        
        # 生成新角色
        var new_player = _instantiate_player(player_id)
        new_player.global_position = old_position
        
        # 恢复状态
        if player_states.has(player_id):
            var state = player_states[player_id]
            new_player.health_component.current_health = state.health
            new_player.energy = state.energy
            new_player.armor = state.armor
        
        player = new_player
```

### 3.5 未激活角色的持续恢复

未激活的角色在后台持续恢复血量和能量（恢复速率从player_config.csv加载）。

```gdscript
# Global.gd

# 每帧更新未激活角色的恢复
func _process(delta: float) -> void:
    _update_inactive_players_regen(delta)

# 更新未激活角色的恢复
func _update_inactive_players_regen(delta: float) -> void:
    var active_player_id = ""
    if is_instance_valid(player):
        active_player_id = player.player_id
    
    for player_id in selected_player_ids:
        # 跳过当前激活的角色（激活角色由自身处理恢复）
        if player_id == active_player_id:
            continue
        
        # 跳过没有状态记录的角色
        if not player_states.has(player_id):
            continue
        
        var state = player_states[player_id]
        
        # 能量恢复（从state中读取，已从CSV加载）
        var energy_regen = state.get("energy_regen", 0.5)
        state.energy = min(state.energy + energy_regen * delta, state.max_energy)
        
        # 血量恢复（从state中读取，已从CSV加载）
        var health_regen = state.get("health_regen", 0.0)
        if health_regen > 0:
            state.health = min(state.health + health_regen * delta, state.max_health)
        
        player_states[player_id] = state
```

### 3.6 角色死亡处理

任意角色血量归零时，游戏直接结束。

```gdscript
# PlayerBase.gd 中修改 _on_death()

func _on_death() -> void:
    # 游戏结束逻辑
    Global.game_over()
    
    # 原有的死亡效果...
    Global.play_player_death()
    visuals.visible = false
    # ...
```

---

## 四、UI组件详细设计

### 4.1 角色按钮 (PlayerButton)

```
┌─────────────────┐
│   ┌─────────┐   │
│   │  Icon   │   │  128x128 像素
│   │  图标   │   │
│   └─────────┘   │
│    角色名称     │
└─────────────────┘
```

属性：
- `player_id`: 角色ID
- `icon`: 角色图标纹理
- `is_selected`: 是否已被选中（选中后显示勾选标记）

### 4.2 PlayerInfo 显示格式

```
┌────────────────────────────────────┐
│ ┌──────┐  角色名称                 │
│ │ Icon │  [羁绊类型]               │
│ └──────┘                           │
│                                    │
│ 生命值: 100                        │
│ Q技能消耗: 50                      │
│ E技能消耗: 30                      │
│ 能量恢复: 0.5                      │
│ 最大能量: 999                      │
│ 最大护甲: 3                        │
│ 移动速度: 500                      │
│                                    │
│ 说明: 近战型角色，高冲刺伤害       │
└────────────────────────────────────┘
```

### 4.3 SelectedList 布局

```
┌──────────┐
│ 槽位 1   │  ← 第一个选择的角色
│ (空/图标)│
├──────────┤
│ 槽位 2   │  ← 第二个选择的角色
│ (空/图标)│
├──────────┤
│ 槽位 3   │  ← 第三个选择的角色
│ (空/图标)│
└──────────┘
```

---

## 五、交互流程

### 5.1 选择角色流程

```
1. 玩家点击 PlayerContainer 中的角色按钮
   ↓
2. PlayerInfo 区域更新显示该角色信息
   ↓
3. WeaponContainer 动态生成该角色可用武器按钮
   ↓
4. 默认选中第一把武器（高亮显示）
   ↓
5. 玩家可选择其他武器（可选步骤）
   ↓
6. 玩家拖拽角色到 SelectedList 的空槽位
   ↓
7. 角色添加到已选列表，使用当前选择的武器（默认或玩家选择的）
   ↓
8. 按钮显示"已选中"状态
   ↓
9. 如果已选满（根据max_selected_players配置），无法再添加新角色
```

### 5.2 修改已选角色武器流程

```
1. 玩家点击 PlayerContainer 中已经在 SelectedList 里的角色
   ↓
2. PlayerInfo 显示该角色信息
   ↓
3. WeaponContainer 显示该角色可用武器，当前武器高亮
   ↓
4. 玩家点击其他武器
   ↓
5. 立即更新 SelectedList 中该角色的武器配置
   ↓
6. 进入游戏时使用最新选择的武器
```

### 5.2 移除已选角色流程

```
1. 玩家点击 SelectedList 中的已选角色
   ↓
2. 弹出确认提示（可选）
   ↓
3. 从已选列表移除
   ↓
4. PlayerContainer 中对应按钮恢复"未选中"状态
```

### 5.3 确认并开始游戏流程

```
1. 玩家点击 Continue 按钮
   ↓
2. 检查是否至少选择了1个角色
   ↓
3. 将选择数据保存到 Global
   ↓
4. 切换到游戏场景 (arena.tscn)
   ↓
5. 生成第一个选择的角色
```

### 5.4 游戏中切换角色流程

```
1. 玩家按下 TAB 键
   ↓
2. Global.switch_to_next_player() 被调用
   ↓
3. 保存当前角色状态（血量、能量、护甲）到 player_states
   ↓
4. 计算下一个角色索引（循环）
   ↓
5. 销毁当前角色实例，记录位置
   ↓
6. 在相同位置生成新角色
   ↓
7. 从 player_states 恢复新角色的状态
   ↓
8. 更新 Global.player 引用
```

### 5.5 未激活角色后台恢复流程

```
游戏运行中（每帧）
   ↓
Global._process(delta) 调用 _update_inactive_players_regen(delta)
   ↓
遍历 selected_player_ids 中的所有角色
   ↓
跳过当前激活角色（激活角色由自身 _process 处理恢复）
   ↓
对每个未激活角色：
   - 从 player_states 读取当前状态
   - 根据 player_regen_configs 计算恢复量
   - 能量恢复：energy += energy_regen * delta（不超过max_energy）
   - 血量恢复：health += health_regen * delta（如果配置了，不超过max_health）
   - 更新 player_states
```

---

## 六、文件结构

```
config/
├── player/
│   ├── player_config.csv          # 修改：新增 display_order, enabled, ties, icon_path
│   ├── player_visual.csv          # 现有
│   ├── player_weapons.csv         # 现有
│   ├── player_skills.csv          # 现有
│   └── player_available_weapons.csv  # 新建：角色可用武器类型
├── system/
│   └── game_config.csv            # 修改：新增 selection_players_per_row, max_selected_players
└── weapon/
    └── weapon_config.csv          # 现有

scenes/ui/selection_panel/
├── selection_panel.tscn           # 现有：需要重构
├── selection_panel.gd             # 现有：需要实现
└── player_button.tscn             # 新建：角色按钮预制件（可选）

autoloads/
├── global.gd                      # 修改：新增角色切换相关变量和方法
└── config_manager.gd              # 修改：新增加载方法
```

---

## 七、ConfigManager 新增方法

```gdscript
# 获取所有启用的角色配置（按display_order排序）
func get_enabled_players() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for player_id in player_configs.keys():
        var config = player_configs[player_id]
        if config.get("enabled", 0) == 1:
            result.append(config)
    # 按 display_order 排序
    result.sort_custom(func(a, b): return a.get("display_order", 999) < b.get("display_order", 999))
    return result

# 获取角色可用武器类型
func get_player_available_weapons(player_id: String) -> Array[String]:
    var config = player_available_weapons.get(player_id, {})
    var weapons: Array[String] = []
    for i in range(1, 5):
        var weapon_type = config.get("weapon_type_%d" % i, "")
        if weapon_type != "":
            weapons.append(weapon_type)
    return weapons

# 获取指定类型的所有武器
func get_weapons_by_type(weapon_type: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for weapon_id in weapon_configs.keys():
        var config = weapon_configs[weapon_id]
        if config.get("type", "") == weapon_type:
            result.append(config)
    return result
```

---

## 八、属性显示映射表

PlayerDescription 中显示的属性及其注释对应关系：

| CSV列名 | 显示名称 | 是否显示 |
|---------|----------|----------|
| health | 生命值 | ✓ |
| skill_q_cost | Q技能消耗 | ✓ |
| skill_e_cost | E技能消耗 | ✓ |
| energy_regen | 能量恢复 | ✓ |
| max_energy | 最大能量 | ✓ |
| max_armor | 最大护甲 | ✓ |
| base_speed | 移动速度 | ✓ |
| description | 说明 | ✓ (单独显示) |
| close_threshold | - | ✗ (内部参数) |
| initial_energy | - | ✗ (内部参数) |
| external_force_decay | - | ✗ (内部参数) |
| knockback_scale | - | ✗ (内部参数) |

---

## 九、已确认决策

| 问题 | 决策 |
|------|------|
| 角色图标来源 | 直接使用`player_visual.csv`中的`sprite_path` |
| 羁绊系统 | 本次只添加显示，不实现加成逻辑 |
| 武器显示 | WeaponContainer只显示每种类型的1级武器 |
| 血量恢复 | 在`player_config.csv`添加`health_regen`列配置 |
| 角色死亡 | 任意角色血量归零，游戏直接结束（Game Over） |

---

## 十、实现优先级

### Phase 1 - 基础功能
1. 修改CSV配置文件（player_config.csv新增display_order、enabled、ties、health_regen列）
2. 修改game_config.csv（新增selection_players_per_row、max_selected_players）
3. 新建player_available_weapons.csv
4. 更新ConfigManager加载新配置

### Phase 2 - 选择界面
5. 实现角色列表动态生成（根据enabled和display_order，使用sprite_path作为图标）
6. 实现角色信息显示（PlayerInfo，包含羁绊显示）
7. 实现武器列表动态生成（WeaponContainer，只显示1级武器）
8. 实现SelectedList动态生成槽位

### Phase 3 - 选择功能
9. 实现拖拽选择角色功能
10. 实现默认武器选择逻辑（第一把可用武器）
11. 实现武器更新逻辑（已选角色修改武器）
12. 实现Continue按钮和数据传递到Global

### Phase 4 - 角色切换与状态管理
13. 实现Global中的角色状态存储结构
14. 实现TAB键切换角色（保存/恢复状态）
15. 实现未激活角色后台恢复逻辑（血量+能量）
16. 修改PlayerBase死亡逻辑（任意角色死亡=游戏结束）

---

*文档版本: 1.2*
*更新日期: 2026-01-11*
*更新内容: 确认所有待定事项 - 图标使用sprite_path、羁绊只显示、武器显示1级、添加health_regen列、角色死亡游戏结束*
