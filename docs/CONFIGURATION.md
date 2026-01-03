# 配置系统详解

本文档详细介绍PolyLash的CSV配置系统，包括文件格式、配置项说明和使用方法。

---

## 目录

- [配置系统概述](#配置系统概述)
- [CSV文件格式](#csv文件格式)
- [配置文件详解](#配置文件详解)
- [ConfigManager使用](#configmanager使用)
- [配置最佳实践](#配置最佳实践)

---

## 配置系统概述

### 设计理念

PolyLash使用**CSV文件驱动**的配置系统，实现**数据与代码分离**：

- **数据驱动**: 所有游戏数据存储在CSV文件中
- **热修改**: 修改CSV后重启游戏即可生效，无需重新编译
- **易于调整**: 策划和设计师可以直接修改数值
- **版本控制友好**: CSV文件易于diff和merge

### 配置目录结构

```
config/
├── system/                    # 系统配置
│   ├── game_config.csv        # 游戏全局设置
│   ├── map_config.csv         # 地图设置
│   ├── camera_config.csv      # 摄像机设置
│   ├── input_config.csv       # 输入映射
│   └── sound_config.csv       # 音效配置
│
├── player/                    # 玩家配置
│   ├── player_config.csv      # 玩家基础属性
│   ├── player_visual.csv      # 玩家视觉配置
│   ├── player_weapons.csv     # 玩家武器配置
│   ├── player_skill_bindings.csv  # 技能绑定
│   └── skill_params.csv       # 技能参数
│
├── enemy/                     # 敌人配置
│   ├── enemy_config.csv       # 敌人基础属性
│   ├── enemy_visual.csv       # 敌人视觉配置
│   └── enemy_weapons.csv      # 敌人武器配置
│
├── weapon/                    # 武器配置
│   ├── weapon_config.csv      # 武器基础配置
│   └── weapon_stats_config.csv # 武器详细属性
│
├── wave/                      # 波次配置
│   ├── wave_config.csv        # 波次配置
│   ├── wave_units_config.csv  # 波次单位配置
│   └── wave_chest_config.csv  # 波次宝箱配置
│
└── item/                      # 物品配置
    ├── chest_config.csv       # 宝箱配置
    └── upgrade_attributes.csv # 升级属性配置
```

---

## CSV文件格式

### 标准格式

所有CSV文件遵循统一的三行格式：

```csv
column1,column2,column3,column4
-1,列1说明,列2说明,列3说明,列4说明
value1,value2,value3,value4
value1,value2,value3,value4
```

### 格式说明

#### 第一行：列名（Header）
- **用途**: 作为代码中访问数据的key
- **格式**: 英文，snake_case命名
- **示例**: `player_id`, `max_health`, `move_speed`

#### 第二行：注释行（Comment）
- **标识**: 第一列必须为 `-1`
- **用途**: 中文说明，帮助理解列的含义
- **格式**: 中文描述
- **示例**: `玩家ID`, `最大生命值`, `移动速度`

#### 第三行及以后：数据行（Data）
- **用途**: 实际的配置数据
- **格式**: 根据列类型填写
- **类型**: 自动识别（字符串、整数、浮点数）

### 数据类型识别

ConfigManager会自动识别数据类型：

```gdscript
if value.is_valid_float():
    row_data[header] = float(value)  # 浮点数
elif value.is_valid_int():
    row_data[header] = int(value)    # 整数
else:
    row_data[header] = value         # 字符串
```

**示例**:
- `"100"` → `100` (int)
- `"3.14"` → `3.14` (float)
- `"player_herder"` → `"player_herder"` (String)

### 编码要求

**必须使用UTF-8编码**，否则中文会乱码。

**检查方法**:
- 使用文本编辑器打开CSV
- 查看编码设置
- 确保为UTF-8

**转换方法**:
- 使用Notepad++: 编码 → 转为UTF-8
- 使用VS Code: 右下角点击编码 → 选择UTF-8

---

## 配置文件详解

### 系统配置 (system/)

#### game_config.csv - 游戏全局设置

**格式**: 单行配置（key-value对）

```csv
setting,value
-1,设置名,值
max_enemies,100
difficulty,1.0
```

**配置项**:
| 设置名 | 说明 | 默认值 |
|--------|------|--------|
| max_enemies | 最大敌人数量 | 100 |
| difficulty | 难度系数 | 1.0 |

**访问方法**:
```gdscript
var max_enemies = ConfigManager.get_game_setting("max_enemies", 100)
```

---

#### map_config.csv - 地图设置

**格式**: 单行配置

```csv
setting,value
-1,设置名,值
map_width,2000
map_height,2000
arena_radius,800
```

**配置项**:
| 设置名 | 说明 | 默认值 |
|--------|------|--------|
| map_width | 地图宽度（像素） | 2000 |
| map_height | 地图高度（像素） | 2000 |
| arena_radius | 竞技场半径 | 800 |
| boundary_damage | 边界伤害 | 10 |
| spawn_safe_radius | 生成安全半径 | 200 |

---

#### sound_config.csv - 音效配置

**格式**: 多行配置（以sound_id为key）

```csv
sound_id,sound_path,volume_db,min_pitch,max_pitch,description
-1,音效ID,音效路径,音量,最小音调,最大音调,描述
player_attack,res://assets/audio/player_attack.wav,0.0,0.9,1.1,玩家攻击
enemy_death,res://assets/audio/enemy_death.wav,-5.0,0.8,1.2,敌人死亡
```

**配置项**:
| 列名 | 说明 | 类型 |
|------|------|------|
| sound_id | 音效唯一ID | String |
| sound_path | 音效文件路径 | String |
| volume_db | 音量（分贝） | float |
| min_pitch | 最小音调 | float |
| max_pitch | 最大音调 | float |
| description | 描述 | String |

**访问方法**:
```gdscript
var config = ConfigManager.get_sound_config("player_attack")
var volume = config.get("volume_db", 0.0)
```

---

### 玩家配置 (player/)

#### player_config.csv - 玩家基础属性

**格式**: 多行配置（以player_id为key）

```csv
player_id,display_name,health,max_energy,energy_regen,base_speed,max_armor
-1,玩家ID,显示名称,生命值,最大能量,能量恢复,基础速度,最大护甲
player_herder,牧者,5000,999,0.5,500,3
player_butcher,屠夫,5000,999,0.5,500,3
```

**配置项**:
| 列名 | 说明 | 类型 | 示例 |
|------|------|------|------|
| player_id | 玩家唯一ID | String | player_herder |
| display_name | 显示名称 | String | 牧者 |
| health | 生命值 | float | 5000 |
| max_energy | 最大能量 | float | 999 |
| energy_regen | 能量恢复/秒 | float | 0.5 |
| base_speed | 基础速度 | float | 500 |
| max_armor | 最大护甲 | int | 3 |

---

#### player_skill_bindings.csv - 技能绑定

**格式**: 多行配置（以player_id为key）

```csv
player_id,slot_q,slot_e,slot_lmb,slot_rmb
-1,玩家ID,Q技能,E技能,左键技能,右键技能
player_herder,skill_herder_loop,skill_herder_explosion,skill_dash,
player_butcher,skill_saw_path,skill_meat_stake,skill_dash,
```

**配置项**:
| 列名 | 说明 | 类型 |
|------|------|------|
| player_id | 玩家ID | String |
| slot_q | Q键技能ID | String |
| slot_e | E键技能ID | String |
| slot_lmb | 左键技能ID | String |
| slot_rmb | 右键技能ID | String |

**注意**: 空值表示该槽位无技能

---

#### skill_params.csv - 技能参数

**格式**: 多行配置（以skill_id为key）

```csv
skill_id,energy_cost,cooldown,damage,dash_speed,dash_distance
-1,技能ID,能量消耗,冷却时间,伤害,冲刺速度,冲刺距离
skill_dash,10,0,14,1700,340
skill_herder_loop,20,0,0,2000,0
```

**配置项**:
| 列名 | 说明 | 类型 |
|------|------|------|
| skill_id | 技能唯一ID | String |
| energy_cost | 能量消耗 | float |
| cooldown | 冷却时间（秒） | float |
| ... | 技能特定参数 | 根据技能而定 |

**特点**:
- 每个技能可以有不同的参数列
- ConfigManager会自动将参数设置到技能实例
- 使用反射机制：`skill.set(key, value)`

---

### 敌人配置 (enemy/)

#### enemy_config.csv - 敌人基础属性

**格式**: 多行配置（以enemy_id为key）

```csv
enemy_id,display_name,health,speed,damage,attack_range,attack_cooldown,xp_value,gold_value
-1,敌人ID,显示名称,生命值,速度,攻击力,攻击范围,攻击冷却,经验值,金币值
enemy_chaser_slow,慢速追击者,100,150,10,50,1.0,10,5
enemy_chaser_mid,中速追击者,80,200,8,45,0.8,12,6
```

**配置项**:
| 列名 | 说明 | 类型 |
|------|------|------|
| enemy_id | 敌人唯一ID | String |
| display_name | 显示名称 | String |
| health | 生命值 | float |
| speed | 移动速度 | float |
| damage | 攻击力 | float |
| attack_range | 攻击范围 | float |
| attack_cooldown | 攻击冷却 | float |
| xp_value | 经验值 | int |
| gold_value | 金币值 | int |

---

### 武器配置 (weapon/)

#### weapon_stats_config.csv - 武器详细属性

**格式**: 多行配置（以weapon_id为key）

```csv
weapon_id,display_name,damage,accuracy,cooldown,crit_chance,max_range,projectile_speed,upgrade_to
-1,武器ID,显示名称,伤害,精度,冷却,暴击率,最大范围,子弹速度,升级到
punch_1,拳头1级,20.0,1.0,1.5,0.05,180.0,0.0,punch_2
laser_1,激光1级,15.0,0.95,0.8,0.05,300.0,2000.0,laser_2
```

**配置项**:
| 列名 | 说明 | 类型 |
|------|------|------|
| weapon_id | 武器唯一ID | String |
| display_name | 显示名称 | String |
| damage | 伤害 | float |
| accuracy | 精度（0-1） | float |
| cooldown | 冷却时间 | float |
| crit_chance | 暴击率（0-1） | float |
| max_range | 最大范围 | float |
| projectile_speed | 子弹速度 | float |
| upgrade_to | 升级到的武器ID | String |

---

### 波次配置 (wave/)

#### wave_config.csv - 波次配置

**格式**: 多行配置（以wave_id为key）

```csv
wave_id,from_wave,to_wave,wave_time,spawn_type,min_spawn_time,max_spawn_time
-1,波次ID,起始波次,结束波次,波次时长,生成类型,最小生成间隔,最大生成间隔
wave_1_to_5,1,5,20.0,RANDOM,0.8,1.5
wave_6_to_10,6,10,25.0,RANDOM,0.6,1.2
```

**配置项**:
| 列名 | 说明 | 类型 |
|------|------|------|
| wave_id | 波次配置ID | String |
| from_wave | 起始波次 | int |
| to_wave | 结束波次 | int |
| wave_time | 波次时长（秒） | float |
| spawn_type | 生成类型 | String |
| min_spawn_time | 最小生成间隔 | float |
| max_spawn_time | 最大生成间隔 | float |

---

#### wave_units_config.csv - 波次单位配置

**格式**: 多行配置（按wave_id分组）

```csv
wave_id,enemy_scene,weight
-1,波次ID,敌人场景路径,生成权重
wave_1_to_5,res://scenes/unit/enemy/enemy_chaser_slow.tscn,3.0
wave_1_to_5,res://scenes/unit/enemy/enemy_chaser_mid.tscn,2.0
```

**配置项**:
| 列名 | 说明 | 类型 |
|------|------|------|
| wave_id | 波次配置ID | String |
| enemy_scene | 敌人场景路径 | String |
| weight | 生成权重 | float |

**权重说明**:
- 权重越高，生成概率越大
- 概率 = 权重 / 总权重
- 示例：权重3.0和2.0，概率为60%和40%

---

### 物品配置 (item/)

#### upgrade_attributes.csv - 升级属性配置

**格式**: 多行配置（以attribute_id为key）

```csv
attribute_id,display_name,description,value_type,tier1_value,tier2_value,tier3_value,tier4_value
-1,属性ID,显示名称,描述,数值类型,1级数值,2级数值,3级数值,4级数值
max_health,最大生命值,增加生命上限,flat,100,250,600,1500
weapon_damage,武器伤害,增加所有武器伤害,percent,0.05,0.125,0.3,0.75
```

**配置项**:
| 列名 | 说明 | 类型 |
|------|------|------|
| attribute_id | 属性唯一ID | String |
| display_name | 显示名称 | String |
| description | 描述 | String |
| value_type | 数值类型 | String |
| tier1_value | 1级数值 | float |
| tier2_value | 2级数值 | float |
| tier3_value | 3级数值 | float |
| tier4_value | 4级数值 | float |

**数值类型**:
- `flat`: 固定数值增加（如 +100 生命值）
- `percent`: 百分比增加（如 +5% 武器伤害）

---

## ConfigManager使用

### 加载流程

```gdscript
# ConfigManager在游戏启动时自动加载
func _ready() -> void:
    print("=== 配置管理器初始化 ===")
    load_all_configs()
    print("=== 配置加载完成 ===")

func load_all_configs() -> void:
    # 玩家配置
    player_configs = load_csv_as_dict(PLAYER_CONFIG, "player_id")
    skill_params = load_csv_as_dict(SKILL_PARAMS, "skill_id")
    
    # 敌人配置
    enemy_configs = load_csv_as_dict(ENEMY_CONFIG, "enemy_id")
    
    # 武器配置
    weapon_configs = load_csv_as_dict(WEAPON_CONFIG, "weapon_id")
    
    # 波次配置
    wave_configs = load_csv_as_dict(WAVE_CONFIG, "wave_id")
    wave_units_configs = load_wave_units_grouped(WAVE_UNITS_CONFIG)
    
    # ... 其他配置
```

### 访问方法

#### 获取单个配置
```gdscript
# 获取玩家配置
var config = ConfigManager.get_player_config("player_herder")
var health = config.get("health", 100)  # 默认值100

# 获取技能参数
var params = ConfigManager.get_skill_params("skill_dash")
var damage = params.get("damage", 0)

# 获取武器配置
var weapon = ConfigManager.get_weapon_config("weapon_sword")
var weapon_damage = weapon.get("damage", 10)
```

#### 获取所有配置
```gdscript
# 获取所有升级属性
var all_attributes = ConfigManager.get_all_upgrade_attributes()
for attribute_id in all_attributes.keys():
    var attribute = all_attributes[attribute_id]
    print(attribute.get("display_name"))
```

#### 获取分组配置
```gdscript
# 获取波次的所有单位
var units = ConfigManager.get_wave_units("wave_1_to_5")
for unit in units:
    var scene_path = unit.get("enemy_scene")
    var weight = unit.get("weight")
```

### 加载方法

ConfigManager提供三种加载方法：

#### 1. load_csv_as_dict() - 字典加载
**用途**: 多行数据，以某列为key

```gdscript
var configs = load_csv_as_dict("path/to/file.csv", "id_column")
# 返回: {"id1": {data}, "id2": {data}, ...}
```

#### 2. load_csv_as_single() - 单行加载
**用途**: 只有一行数据的配置

```gdscript
var config = load_csv_as_single("path/to/file.csv")
# 返回: {column1: value1, column2: value2, ...}
```

#### 3. load_csv_as_array() - 数组加载
**用途**: 多行数据，保持顺序

```gdscript
var configs = load_csv_as_array("path/to/file.csv")
# 返回: [{data1}, {data2}, ...]
```

---

## 配置最佳实践

### 1. 命名规范

**文件命名**:
- 使用snake_case
- 描述性名称
- 示例：`player_config.csv`, `skill_params.csv`

**列名命名**:
- 使用snake_case
- 英文，简洁明了
- 示例：`player_id`, `max_health`, `move_speed`

**ID命名**:
- 使用前缀区分类型
- 示例：`player_herder`, `enemy_chaser`, `skill_dash`

### 2. 数值设计

**平衡性**:
- 使用相对数值而非绝对数值
- 考虑数值增长曲线
- 测试不同组合

**可读性**:
- 使用整数或简单小数
- 避免过长的小数
- 示例：使用`1.5`而非`1.523456`

**扩展性**:
- 预留扩展列
- 使用版本号
- 保持向后兼容

### 3. 注释规范

**注释行**:
- 第二行必须为注释行
- 第一列必须为`-1`
- 使用中文说明

**描述列**:
- 添加description列
- 详细说明配置用途
- 示例：`"增加玩家的最大生命值"`

### 4. 版本控制

**Git管理**:
- CSV文件纳入版本控制
- 使用有意义的commit message
- 示例：`"调整玩家生命值平衡"`

**变更记录**:
- 在注释中记录变更
- 使用版本号
- 示例：`# v1.1: 增加冲刺速度参数`

### 5. 测试验证

**数据验证**:
- 检查必填字段
- 验证数值范围
- 测试边界情况

**加载测试**:
- 启动游戏检查日志
- 确认配置加载成功
- 验证数值正确应用

### 6. 文档维护

**配置文档**:
- 为每个配置文件编写说明
- 说明每列的含义和范围
- 提供示例值

**变更日志**:
- 记录重要变更
- 说明变更原因
- 标注影响范围

---

## 常见问题

### Q: 修改CSV后不生效？
**A**: 需要重启游戏。ConfigManager在启动时加载配置，运行时不会重新加载。

### Q: 中文显示乱码？
**A**: 确保CSV文件使用UTF-8编码保存。

### Q: 配置加载失败？
**A**: 检查：
1. 文件路径是否正确
2. CSV格式是否正确（三行格式）
3. 第二行第一列是否为`-1`
4. 查看控制台错误信息

### Q: 如何添加新配置项？
**A**: 
1. 在CSV中添加新列
2. 在第二行添加中文说明
3. 填写数据
4. 在代码中通过`config.get("new_column")`访问

### Q: 如何删除配置项？
**A**:
1. 删除CSV中的列
2. 检查代码中是否有引用
3. 测试确保无影响

---

## 总结

PolyLash的配置系统具有以下特点：

1. **统一格式**: 所有CSV文件遵循三行格式
2. **自动加载**: 启动时自动加载所有配置
3. **类型识别**: 自动识别数值类型
4. **便捷访问**: 提供丰富的访问方法
5. **易于扩展**: 添加新配置只需修改CSV

通过合理使用配置系统，可以快速调整游戏平衡，无需修改代码。
