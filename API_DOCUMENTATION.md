# API 文档

本文档提供 PolyLash 项目中所有重要类和函数的中文说明。

## 目录

1. [全局单例 (Autoloads)](#全局单例-autoloads)
2. [管理器类 (Managers)](#管理器类-managers)
3. [玩家系统 (Player System)](#玩家系统-player-system)
4. [敌人系统 (Enemy System)](#敌人系统-enemy-system)
5. [物品系统 (Item System)](#物品系统-item-system)
6. [UI系统 (UI System)](#ui系统-ui-system)
7. [工具函数 (Utilities)](#工具函数-utilities)

---

## 全局单例 (Autoloads)

### ConfigManager

**文件**: `autoloads/config_manager.gd`

**描述**: 统一管理所有 CSV 配置文件的加载和访问。

#### 主要属性

```gdscript
var player_configs: Dictionary          # 玩家配置缓存
var enemy_configs: Dictionary           # 敌人配置缓存
var weapon_configs: Dictionary          # 武器配置缓存
var upgrade_attributes: Dictionary      # 升级属性配置
var chest_configs: Dictionary           # 宝箱配置
var wave_chest_configs: Array[Dictionary]  # 波次宝箱配置
var sound_configs: Dictionary           # 音效配置
```

#### 主要方法

##### load_all_configs()
```gdscript
func load_all_configs() -> void
```
**功能**: 加载所有配置文件  
**调用时机**: 游戏启动时自动调用  
**返回值**: 无

##### get_player_config(player_id: String)
```gdscript
func get_player_config(player_id: String) -> Dictionary
```
**功能**: 获取指定玩家的配置  
**参数**:
- `player_id`: 玩家ID，如 `"player_herder"`
**返回值**: 包含玩家所有属性的字典  
**示例**:
```gdscript
var config = ConfigManager.get_player_config("player_herder")
var health = config.get("base_health", 100)
```

##### get_weapon_config(weapon_id: String)
```gdscript
func get_weapon_config(weapon_id: String) -> Dictionary
```
**功能**: 获取指定武器的配置  
**参数**:
- `weapon_id`: 武器ID
**返回值**: 包含武器所有属性的字典

##### get_chest_config(tier: int)
```gdscript
func get_chest_config(tier: int) -> Dictionary
```
**功能**: 获取指定等级宝箱的配置  
**参数**:
- `tier`: 宝箱等级（1-4）
**返回值**: 宝箱配置字典

##### get_wave_chest_config(wave_index: int)
```gdscript
func get_wave_chest_config(wave_index: int) -> Dictionary
```
**功能**: 根据波次获取宝箱生成配置  
**参数**:
- `wave_index`: 当前波次
**返回值**: 包含宝箱生成规则的字典

##### get_sound_config(sound_id: String)
```gdscript
func get_sound_config(sound_id: String) -> Dictionary
```
**功能**: 获取音效配置  
**参数**:
- `sound_id`: 音效ID
**返回值**: 音效配置字典

---

### UpgradeManager

**文件**: `autoloads/upgrade_manager.gd`

**描述**: 管理玩家属性升级系统。

#### 主要属性

```gdscript
var attribute_levels: Dictionary        # 属性当前等级
var attribute_bonuses: Dictionary       # 属性加成值
```

#### 主要方法

##### apply_upgrade(attribute_id: String, chest_tier: int)
```gdscript
func apply_upgrade(attribute_id: String, chest_tier: int) -> Dictionary
```
**功能**: 应用属性升级到玩家  
**参数**:
- `attribute_id`: 属性ID，如 `"max_health"`
- `chest_tier`: 宝箱等级（1-4）
**返回值**: 包含升级信息的字典  
**示例**:
```gdscript
var result = UpgradeManager.apply_upgrade("max_health", 2)
print("升级后等级: ", result["new_level"])
```

##### generate_random_attributes(count: int, chest_tier: int)
```gdscript
func generate_random_attributes(count: int, chest_tier: int) -> Array[Dictionary]
```
**功能**: 生成随机属性选项（用于宝箱）  
**参数**:
- `count`: 生成数量
- `chest_tier`: 宝箱等级
**返回值**: 属性选项数组  
**示例**:
```gdscript
var options = UpgradeManager.generate_random_attributes(3, 2)
for option in options:
    print(option["display_name"], ": +", option["upgrade_value"])
```

##### get_attribute_bonus(attribute_id: String)
```gdscript
func get_attribute_bonus(attribute_id: String) -> float
```
**功能**: 获取属性的累计加成值  
**参数**:
- `attribute_id`: 属性ID
**返回值**: 加成值（浮点数）

##### get_attribute_level(attribute_id: String)
```gdscript
func get_attribute_level(attribute_id: String) -> int
```
**功能**: 获取属性的当前等级  
**参数**:
- `attribute_id`: 属性ID
**返回值**: 等级（整数）

##### reset_all_attributes()
```gdscript
func reset_all_attributes() -> void
```
**功能**: 重置所有属性（用于重新开始游戏）  
**参数**: 无  
**返回值**: 无

---

### SoundManager

**文件**: `autoloads/sound_manager.gd`

**描述**: 通过CSV配置管理所有游戏音效，使用对象池优化性能。

#### 主要属性

```gdscript
const POOL_SIZE = 32                    # 音效对象池大小
var pool: Array[AudioStreamPlayer]      # 音效播放器池
var sound_cache: Dictionary             # 音效缓存
```

#### 主要方法

##### play_sound(sound_id: String)
```gdscript
func play_sound(sound_id: String) -> void
```
**功能**: 播放指定音效  
**参数**:
- `sound_id`: 音效ID（在 sound_config.csv 中定义）
**返回值**: 无  
**特性**: 音效文件不存在时不会崩溃  
**示例**:
```gdscript
SoundManager.play_sound("player_attack")
```

##### 便捷方法

```gdscript
func play_player_attack() -> void      # 播放玩家攻击音效
func play_player_hit() -> void         # 播放玩家受击音效
func play_player_dash() -> void        # 播放玩家冲刺音效
func play_player_skill_q() -> void     # 播放Q技能音效
func play_player_skill_e() -> void     # 播放E技能音效
func play_player_death() -> void       # 播放玩家死亡音效
func play_enemy_attack() -> void       # 播放敌人攻击音效
func play_enemy_death() -> void        # 播放敌人死亡音效
func play_enemy_hit() -> void          # 播放敌人受击音效
```

---

### Global

**文件**: `autoloads/global.gd`

**描述**: 全局变量和工具函数。

#### 主要属性

```gdscript
var player: Node2D                      # 当前玩家引用
var game_paused: bool = false           # 游戏暂停状态
```

#### 主要方法

##### spawn_floating_text(position: Vector2, text: String, color: Color)
```gdscript
func spawn_floating_text(position: Vector2, text: String, color: Color) -> void
```
**功能**: 在指定位置生成浮动文本  
**参数**:
- `position`: 世界坐标位置
- `text`: 显示文本
- `color`: 文本颜色
**返回值**: 无

---

## 管理器类 (Managers)

### ChestManager

**文件**: `scenes/arena/chest_manager.gd`

**描述**: 管理宝箱的生成、加载和持久化。

#### 信号

```gdscript
signal chest_opened(chest: ChestSimple)  # 宝箱打开信号
```

#### 主要属性

```gdscript
var chest_positions: Array[Dictionary]   # 预生成的宝箱位置
var active_chests: Dictionary            # 已实例化的宝箱
var opened_chest_ids: Array[int]         # 已打开的宝箱ID
var current_wave: int                    # 当前波次
```

#### 主要方法

##### get_nearby_chests(player_pos: Vector2, max_count: int)
```gdscript
func get_nearby_chests(player_pos: Vector2, max_count: int = 3) -> Array[Dictionary]
```
**功能**: 获取玩家附近的宝箱  
**参数**:
- `player_pos`: 玩家位置
- `max_count`: 最大返回数量
**返回值**: 宝箱信息数组，按距离排序  
**示例**:
```gdscript
var nearby = chest_manager.get_nearby_chests(player.global_position, 3)
for chest_data in nearby:
    print("宝箱等级: ", chest_data["tier"])
    print("距离: ", chest_data["distance"])
```

---

### Spawner

**文件**: `scenes/arena/spawner.gd`

**描述**: 管理敌人波次生成系统。

#### 主要属性

```gdscript
var wave_index: int                      # 当前波次
var current_wave_data: WaveData          # 当前波次数据
var spawned_enemies: Array[Enemy]        # 已生成的敌人
var max_waves: int = 5                   # 最大波次数
```

#### 主要方法

##### start_wave()
```gdscript
func start_wave() -> void
```
**功能**: 开始新的波次  
**参数**: 无  
**返回值**: 无

##### spawn_enemy()
```gdscript
func spawn_enemy() -> void
```
**功能**: 生成一个敌人  
**参数**: 无  
**返回值**: 无

##### clear_enemies()
```gdscript
func clear_enemies() -> void
```
**功能**: 清除所有敌人  
**参数**: 无  
**返回值**: 无

##### get_wave_text()
```gdscript
func get_wave_text() -> String
```
**功能**: 获取波次显示文本  
**参数**: 无  
**返回值**: 格式化的波次文本，如 `"Wave 3"`

##### get_wave_timer_text()
```gdscript
func get_wave_timer_text() -> String
```
**功能**: 获取波次倒计时文本  
**参数**: 无  
**返回值**: 剩余秒数字符串

---

## 玩家系统 (Player System)

### PlayerBase

**文件**: `scenes/unit/players/player_base.gd`

**描述**: 所有玩家角色的基类，继承自 `Unit`。

#### 主要属性

```gdscript
var player_id: String                    # 玩家ID
var base_speed: float                    # 基础移动速度
var energy: float                        # 当前能量
var max_energy: float                    # 最大能量
var energy_regen: float                  # 能量恢复速度
var dash_distance: float                 # 冲刺距离
var dash_damage: int                     # 冲刺伤害
var dash_cost: float                     # 冲刺消耗
var skill_q_cost: float                  # Q技能消耗
var skill_e_cost: float                  # E技能消耗
```

#### 主要方法

##### _ready()
```gdscript
func _ready() -> void
```
**功能**: 初始化玩家  
**说明**: 加载配置、设置属性、初始化组件

##### _process(delta: float)
```gdscript
func _process(delta: float) -> void
```
**功能**: 每帧更新  
**参数**:
- `delta`: 帧间隔时间
**说明**: 处理移动、能量恢复、输入检测

##### perform_dash()
```gdscript
func perform_dash() -> void
```
**功能**: 执行冲刺  
**参数**: 无  
**返回值**: 无  
**说明**: 消耗能量，向鼠标方向冲刺

##### charge_skill_q()
```gdscript
func charge_skill_q() -> void
```
**功能**: 蓄力Q技能  
**参数**: 无  
**返回值**: 无  
**说明**: 子类需要重写此方法实现具体技能

##### release_skill_q()
```gdscript
func release_skill_q() -> void
```
**功能**: 释放Q技能  
**参数**: 无  
**返回值**: 无  
**说明**: 子类需要重写此方法实现具体技能

##### use_skill_e()
```gdscript
func use_skill_e() -> void
```
**功能**: 使用E技能  
**参数**: 无  
**返回值**: 无  
**说明**: 子类需要重写此方法实现具体技能

---

### 具体角色类

#### PlayerHerder (牧者)

**文件**: `scenes/unit/players/player_herder.gd`

**特殊技能**:
- **Q技能**: 冲刺留下裂痕，持续造成伤害
- **E技能**: 回拉裂痕中的敌人

#### PlayerButcher (屠夫)

**文件**: `scenes/unit/players/player_butcher.gd`

**特殊技能**:
- **Q技能**: 电锯冲刺，持续造成伤害
- **E技能**: 创建死亡角斗场，范围伤害

#### PlayerWeaver (织网者)

**文件**: `scenes/unit/players/player_weaver.gd`

**特殊技能**:
- **Q技能**: 放置蛛网陷阱
- **E技能**: 范围减速

---

## 敌人系统 (Enemy System)

### Enemy

**文件**: `scenes/unit/enemies/enemy.gd`

**描述**: 敌人基类，继承自 `Unit`。

#### 主要属性

```gdscript
var enemy_id: String                     # 敌人ID
var target: Node2D                       # 追击目标（玩家）
var attack_range: float                  # 攻击范围
var attack_cooldown: float               # 攻击冷却
var gold_drop: int                       # 掉落金币
var xp_drop: int                         # 掉落经验
```

#### 主要方法

##### _process(delta: float)
```gdscript
func _process(delta: float) -> void
```
**功能**: 每帧更新  
**说明**: AI逻辑、追击玩家、攻击判定

##### attack_target()
```gdscript
func attack_target() -> void
```
**功能**: 攻击目标  
**参数**: 无  
**返回值**: 无

##### destroy_enemy()
```gdscript
func destroy_enemy() -> void
```
**功能**: 销毁敌人  
**参数**: 无  
**返回值**: 无  
**说明**: 播放死亡效果、掉落奖励

---

## 物品系统 (Item System)

### ChestSimple

**文件**: `scenes/items/chest_simple.gd`

**描述**: 宝箱类，使用 AnimatedSprite2D 播放动画。

#### 信号

```gdscript
signal chest_opened(chest: ChestSimple)  # 宝箱打开信号
```

#### 主要属性

```gdscript
var chest_tier: int                      # 宝箱等级（1-4）
var is_opened: bool                      # 是否已打开
var player_nearby: bool                  # 玩家是否在附近
```

#### 主要方法

##### open_chest()
```gdscript
func open_chest() -> void
```
**功能**: 打开宝箱  
**参数**: 无  
**返回值**: 无  
**说明**: 播放动画、暂停游戏、发送信号

##### hide_chest()
```gdscript
func hide_chest() -> void
```
**功能**: 隐藏宝箱（选择完属性后）  
**参数**: 无  
**返回值**: 无  
**说明**: 淡出动画后销毁

##### get_tier()
```gdscript
func get_tier() -> int
```
**功能**: 获取宝箱等级  
**参数**: 无  
**返回值**: 宝箱等级（1-4）

---

## UI系统 (UI System)

### UpgradeSelectionUI

**文件**: `scenes/ui/upgrade_selection_ui.gd`

**描述**: 升级选择界面。

#### 信号

```gdscript
signal upgrade_selected(attribute_id: String)  # 选择升级信号
```

#### 主要方法

##### show_upgrades(chest: ChestSimple)
```gdscript
func show_upgrades(chest: ChestSimple) -> void
```
**功能**: 显示升级选项  
**参数**:
- `chest`: 宝箱对象
**返回值**: 无  
**说明**: 生成随机属性选项并显示

##### hide_upgrades()
```gdscript
func hide_upgrades() -> void
```
**功能**: 隐藏升级界面  
**参数**: 无  
**返回值**: 无

---

### ChestIndicator

**文件**: `scenes/ui/chest_indicator.gd`

**描述**: 宝箱方向指示器，显示屏幕边缘的箭头。

#### 主要属性

```gdscript
var tier_colors: Dictionary              # 宝箱等级颜色映射
var view_range: float = 800.0            # 视野范围
```

#### 主要方法

##### set_chest_manager(manager: ChestManager)
```gdscript
func set_chest_manager(manager: ChestManager) -> void
```
**功能**: 设置宝箱管理器引用  
**参数**:
- `manager`: ChestManager 实例
**返回值**: 无

---

## 工具函数 (Utilities)

### HealthComponent

**文件**: `scenes/components/health_component.gd`

**描述**: 生命值组件，可附加到任何单位。

#### 信号

```gdscript
signal health_changed(current: int, max: int)  # 生命值变化
signal died()                                   # 死亡
```

#### 主要属性

```gdscript
var max_health: int                      # 最大生命值
var current_health: int                  # 当前生命值
```

#### 主要方法

##### take_damage(amount: int)
```gdscript
func take_damage(amount: int) -> void
```
**功能**: 受到伤害  
**参数**:
- `amount`: 伤害值
**返回值**: 无

##### heal(amount: int)
```gdscript
func heal(amount: int) -> void
```
**功能**: 恢复生命值  
**参数**:
- `amount`: 恢复量
**返回值**: 无

##### is_alive()
```gdscript
func is_alive() -> bool
```
**功能**: 检查是否存活  
**参数**: 无  
**返回值**: 是否存活（布尔值）

---

## 使用示例

### 示例1: 加载玩家配置并创建角色

```gdscript
# 获取玩家配置
var config = ConfigManager.get_player_config("player_herder")

# 创建玩家实例
var player = preload("res://scenes/unit/players/player_herder.tscn").instantiate()
player.player_id = "player_herder"
add_child(player)

# 访问玩家属性
print("玩家生命值: ", player.health_component.max_health)
print("玩家速度: ", player.base_speed)
```

### 示例2: 应用属性升级

```gdscript
# 生成随机属性选项
var options = UpgradeManager.generate_random_attributes(3, 2)

# 显示选项给玩家
for i in range(options.size()):
    var option = options[i]
    print("%d. %s: +%s" % [i+1, option["display_name"], str(option["upgrade_value"])])

# 玩家选择第一个选项
var selected = options[0]
UpgradeManager.apply_upgrade(selected["attribute_id"], 2)
```

### 示例3: 播放音效

```gdscript
# 方式1: 使用便捷方法
SoundManager.play_player_attack()

# 方式2: 使用通用方法
SoundManager.play_sound("player_attack")

# 自定义音效
# 1. 在 sound_config.csv 添加配置
# 2. 调用 play_sound
SoundManager.play_sound("custom_sound")
```

### 示例4: 生成宝箱

```gdscript
# 在 ChestManager 中自动处理
# 手动生成示例:
var chest = preload("res://scenes/items/chest_simple.tscn").instantiate()
chest.chest_tier = 2  # 青铜宝箱
chest.global_position = Vector2(100, 100)
add_child(chest)

# 连接信号
chest.chest_opened.connect(_on_chest_opened)

func _on_chest_opened(chest: ChestSimple):
    print("宝箱已打开，等级: ", chest.get_tier())
```

### 示例5: 获取波次信息

```gdscript
# 在 Spawner 中
var wave_text = spawner.get_wave_text()  # "Wave 3"
var timer_text = spawner.get_wave_timer_text()  # "45"

# 获取当前波次的宝箱配置
var wave_config = ConfigManager.get_wave_chest_config(spawner.wave_index)
var min_tier = wave_config.get("min_tier", 1)
var max_tier = wave_config.get("max_tier", 2)
print("当前波次宝箱等级范围: %d-%d" % [min_tier, max_tier])
```

---

## 扩展指南

### 添加新角色

1. **创建角色脚本**
```gdscript
extends PlayerBase
class_name PlayerCustom

func charge_skill_q() -> void:
    # 实现Q技能蓄力逻辑
    pass

func release_skill_q() -> void:
    # 实现Q技能释放逻辑
    pass

func use_skill_e() -> void:
    # 实现E技能逻辑
    pass
```

2. **添加配置**
在 `player_config.csv` 中添加角色数据。

3. **创建场景**
创建 `.tscn` 文件，设置 `player_id` 属性。

### 添加新属性

1. **添加配置**
在 `upgrade_attributes.csv` 中添加新属性。

2. **实现应用逻辑**
在 `UpgradeManager._apply_to_player()` 中添加处理代码：

```gdscript
match attribute_id:
    "new_attribute":
        if "new_attribute" in player:
            player.new_attribute += value
```

### 添加新音效

1. **添加音效文件**
将文件放入 `assets/audio/` 目录。

2. **添加配置**
在 `sound_config.csv` 中添加配置行。

3. **使用音效**
```gdscript
SoundManager.play_sound("new_sound_id")
```

---

## 调试技巧

### 1. 查看配置加载
```gdscript
# 在控制台查看加载的配置
print(ConfigManager.player_configs)
print(ConfigManager.weapon_configs)
```

### 2. 调试属性升级
```gdscript
# UpgradeManager 会自动打印详细日志
# 查看控制台输出
```

### 3. 检查碰撞层
```gdscript
# 打印碰撞信息
print("Layer: ", collision_layer)
print("Mask: ", collision_mask)
```

### 4. 监控性能
```gdscript
# 查看对象数量
print("敌人数量: ", spawner.spawned_enemies.size())
print("宝箱数量: ", chest_manager.active_chests.size())
```

---

**最后更新**: 2024年12月28日
**版本**: 1.0.0
