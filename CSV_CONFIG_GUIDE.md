# CSV 配置文件指南

本文档详细说明了 PolyLash 项目中所有 CSV 配置文件的格式、字段含义和使用方法。

## 目录

1. [配置文件概述](#配置文件概述)
2. [玩家配置](#玩家配置)
3. [敌人配置](#敌人配置)
4. [武器配置](#武器配置)
5. [宝箱配置](#宝箱配置)
6. [升级属性配置](#升级属性配置)
7. [音效配置](#音效配置)
8. [游戏配置](#游戏配置)
9. [输入配置](#输入配置)

---

## 配置文件概述

### 文件位置
所有配置文件位于 `config/` 目录下。

### 文件格式规则
- **第一行**: 列名（字段名）
- **第二行**: 注释行（第一列为 `-1`），用于说明字段含义
- **第三行及以后**: 实际数据行

### 数据类型
- **整数**: 直接写数字，如 `100`
- **浮点数**: 带小数点，如 `1.5`
- **字符串**: 文本内容，如 `player_herder`
- **资源路径**: Godot 资源路径，如 `res://assets/sprites/player.png`

### 注意事项
- 不要删除第一行的列名
- 第二行注释行可以修改，但第一列必须保持 `-1`
- 数据行的列数必须与列名一致
- 空值会被解析为默认值（0 或空字符串）

---

## 玩家配置

### player_config.csv
定义所有可玩角色的基础属性。

#### 字段说明

| 字段名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| player_id | String | 玩家唯一标识符 | `player_herder` |
| display_name | String | 显示名称 | `牧者` |
| base_health | Int | 基础生命值 | `100` |
| base_speed | Float | 基础移动速度 | `300.0` |
| base_energy | Int | 基础能量值 | `100` |
| energy_regen | Float | 能量恢复速度（每秒） | `10.0` |
| dash_distance | Float | 冲刺距离 | `200.0` |
| dash_damage | Int | 冲刺伤害 | `10` |
| dash_cost | Float | 冲刺能量消耗 | `20.0` |
| skill_q_cost | Float | Q技能能量消耗 | `30.0` |
| skill_e_cost | Float | E技能能量消耗 | `40.0` |
| close_attack_damage | Int | 近战攻击伤害 | `15` |
| max_weapons | Int | 最大武器槽位数 | `6` |

#### 使用示例
```csv
player_id,display_name,base_health,base_speed,base_energy,energy_regen,dash_distance,dash_damage,dash_cost,skill_q_cost,skill_e_cost,close_attack_damage,max_weapons
-1,玩家ID,基础生命,基础速度,基础能量,能量恢复,冲刺距离,冲刺伤害,冲刺消耗,Q技能消耗,E技能消耗,近战伤害,最大武器数
player_herder,牧者,100,300.0,100,10.0,200.0,10,20.0,30.0,40.0,15,6
player_butcher,屠夫,120,280.0,100,10.0,180.0,15,20.0,35.0,45.0,20,6
```

### player_visual.csv
定义玩家的视觉表现。

#### 字段说明

| 字段名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| player_id | String | 玩家ID（对应player_config） | `player_herder` |
| sprite | String | 精灵图路径 | `res://assets/sprites/player_herder.png` |
| color | String | 颜色调制（十六进制） | `#FFFFFF` |
| scale | Float | 缩放比例 | `1.0` |
| z_index | Int | 渲染层级 | `10` |

### player_weapons.csv
定义玩家初始装备的武器。

#### 字段说明

| 字段名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| player_id | String | 玩家ID | `player_herder` |
| weapon1-6 | String | 武器槽位1-6的武器ID | `weapon_sword` |

---

## 敌人配置

### enemy_config.csv
定义所有敌人的基础属性。

#### 字段说明

| 字段名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| enemy_id | String | 敌人唯一标识符 | `enemy_basic` |
| display_name | String | 显示名称 | `基础敌人` |
| health | Int | 生命值 | `50` |
| speed | Float | 移动速度 | `150.0` |
| damage | Int | 攻击伤害 | `10` |
| attack_range | Float | 攻击范围 | `50.0` |
| attack_cooldown | Float | 攻击冷却时间（秒） | `1.0` |
| knockback_resistance | Float | 击退抗性（0-1） | `0.0` |
| gold_drop | Int | 掉落金币数 | `10` |
| xp_drop | Int | 掉落经验值 | `5` |
| health_increase_per_wave | Int | 每波生命值增长 | `10` |
| damage_increase_per_wave | Int | 每波伤害增长 | `2` |

### enemy_visual.csv
定义敌人的视觉表现（格式同 player_visual.csv）。

### enemy_weapons.csv
定义敌人装备的武器（格式同 player_weapons.csv）。

---

## 武器配置

### weapon_config.csv
定义所有武器的属性。

#### 字段说明

| 字段名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| weapon_id | String | 武器唯一标识符 | `weapon_sword` |
| display_name | String | 显示名称 | `剑` |
| weapon_type | String | 武器类型 | `melee` / `ranged` / `magic` |
| damage | Int | 基础伤害 | `20` |
| attack_speed | Float | 攻击速度（次/秒） | `1.0` |
| range | Float | 攻击范围 | `100.0` |
| projectile_speed | Float | 弹道速度（远程武器） | `500.0` |
| pierce_count | Int | 穿透数量 | `1` |
| knockback | Float | 击退力度 | `100.0` |
| energy_cost | Float | 能量消耗 | `5.0` |
| cooldown | Float | 冷却时间（秒） | `0.5` |
| projectile_scene | String | 弹道场景路径 | `res://scenes/projectiles/bullet.tscn` |

#### 武器类型说明
- **melee**: 近战武器，直接造成伤害
- **ranged**: 远程武器，发射弹道
- **magic**: 魔法武器，特殊效果

---

## 宝箱配置

### chest_config.csv
定义不同品质宝箱的属性。

#### 字段说明

| 字段名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| chest_tier | Int | 宝箱等级（1-4） | `1` |
| display_name | String | 显示名称 | `木质宝箱` |
| upgrade_count | Int | 提供的升级选项数量 | `3` |
| min_attribute_value | Float | 最小属性值 | `5.0` |
| max_attribute_value | Float | 最大属性值 | `10.0` |

#### 宝箱等级说明
- **1**: 木质宝箱（白色）- 基础属性提升
- **2**: 青铜宝箱（青色）- 中等属性提升
- **3**: 黄金宝箱（黄色）- 高级属性提升
- **4**: 钻石宝箱（彩虹色）- 顶级属性提升

### wave_chest_config.csv
定义不同波次的宝箱生成规则。

#### 字段说明

| 字段名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| wave_range_start | Int | 波次范围起始 | `1` |
| wave_range_end | Int | 波次范围结束 | `2` |
| min_tier | Int | 最小宝箱等级 | `1` |
| max_tier | Int | 最大宝箱等级 | `2` |
| chest_count | Int | 初始宝箱数量 | `3` |
| spawn_interval | Float | 动态生成间隔（秒） | `30.0` |

#### 使用示例
```csv
wave_range_start,wave_range_end,min_tier,max_tier,chest_count,spawn_interval
-1,波次起始,波次结束,最小等级,最大等级,宝箱数量,生成间隔
1,2,1,2,3,30.0
3,4,2,3,4,25.0
5,999,3,4,5,20.0
```

---

## 升级属性配置

### upgrade_attributes.csv
定义所有可升级的属性。

#### 字段说明

| 字段名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| attribute_id | String | 属性唯一标识符 | `max_health` |
| display_name | String | 显示名称 | `最大生命值` |
| description | String | 属性描述 | `增加最大生命值` |
| value_type | String | 数值类型 | `flat` / `percent` |
| max_level | Int | 最大升级等级 | `10` |
| tier1_value | Float | 等级1宝箱提升值 | `10.0` |
| tier2_value | Float | 等级2宝箱提升值 | `20.0` |
| tier3_value | Float | 等级3宝箱提升值 | `30.0` |
| tier4_value | Float | 等级4宝箱提升值 | `50.0` |

#### 数值类型说明
- **flat**: 固定数值，直接加到属性上
- **percent**: 百分比，按比例增加属性

#### 可配置的属性
- `max_health` - 最大生命值
- `max_energy` - 最大能量
- `energy_regen` - 能量恢复速度
- `base_speed` - 移动速度
- `dash_distance` - 冲刺距离
- `dash_damage` - 冲刺伤害
- `dash_cost` - 冲刺消耗（负值表示降低）
- `skill_q_cost` - Q技能消耗（负值表示降低）
- `skill_e_cost` - E技能消耗（负值表示降低）
- `weapon_damage` - 武器伤害
- `crit_chance` - 暴击率
- `crit_damage` - 暴击伤害
- `damage_reduction` - 伤害减免
- `lifesteal` - 生命偷取
- `energy_on_kill` - 击杀回能

---

## 音效配置

### sound_config.csv
定义所有游戏音效。

#### 字段说明

| 字段名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| sound_id | String | 音效唯一标识符 | `player_attack` |
| sound_path | String | 音效文件路径 | `res://assets/audio/attack.wav` |
| volume_db | Float | 音量（分贝） | `0.0` |
| min_pitch | Float | 最小音调 | `0.9` |
| max_pitch | Float | 最大音调 | `1.1` |
| description | String | 音效描述 | `玩家攻击音效` |

#### 音量参考
- `0.0` - 正常音量
- `-10.0` - 较小音量
- `5.0` - 较大音量
- `-80.0` - 静音

#### 音调说明
- 音调范围 `0.5` - `2.0`
- `1.0` 为原始音调
- 随机音调可增加音效变化感

#### 预定义音效ID
- `player_attack` - 玩家普通攻击
- `player_hit` - 玩家受击
- `player_dash` - 玩家冲刺
- `player_skill_q` - 玩家Q技能
- `player_skill_e` - 玩家E技能
- `player_death` - 玩家死亡
- `enemy_attack` - 敌人攻击
- `enemy_death` - 敌人死亡
- `enemy_hit` - 敌人受击

#### 使用示例
```csv
sound_id,sound_path,volume_db,min_pitch,max_pitch,description
-1,音效ID,音效文件路径,音量(dB),最小音调,最大音调,描述
player_attack,res://assets/audio/player_attack.wav,0.0,0.9,1.1,玩家普通攻击
player_hit,res://assets/audio/player_hit.wav,-5.0,0.8,1.2,玩家受击
```

#### 安全机制
- 如果音效文件不存在，游戏不会崩溃
- 只会在控制台输出警告信息
- 音效会被跳过，不影响游戏运行

---

## 游戏配置

### game_config.csv
定义全局游戏设置。

#### 字段说明

| 字段名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| setting | String | 设置名称 | `max_enemies` |
| value | Variant | 设置值 | `100` |

#### 常用设置
- `max_enemies` - 最大敌人数量
- `difficulty_multiplier` - 难度倍率
- `gold_multiplier` - 金币倍率
- `xp_multiplier` - 经验倍率

### camera_config.csv
定义摄像机设置。

#### 字段说明

| 字段名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| setting | String | 设置名称 | `zoom_level` |
| value | Float | 设置值 | `1.0` |

#### 常用设置
- `zoom_level` - 缩放级别
- `smooth_speed` - 平滑跟随速度
- `offset_x` - X轴偏移
- `offset_y` - Y轴偏移

### map_config.csv
定义地图设置。

#### 字段说明

| 字段名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| setting | String | 设置名称 | `tile_size` |
| value | Variant | 设置值 | `1024` |

#### 常用设置
- `tile_size` - 地图瓦片大小
- `chest_spawn_density` - 宝箱生成密度
- `chest_spawn_radius` - 宝箱生成半径

---

## 输入配置

### input_config.csv
定义输入映射（键位绑定）。

#### 字段说明

| 字段名 | 类型 | 说明 | 示例 |
|--------|------|------|------|
| action | String | 动作名称 | `move_up` |
| key | String | 按键 | `W` |
| player | Int | 玩家编号（多人游戏） | `1` |
| description | String | 动作描述 | `向上移动` |

#### 预定义动作
- `move_up` / `move_down` / `move_left` / `move_right` - 移动
- `dash` - 冲刺
- `skill_q` - Q技能
- `skill_e` - E技能
- `switch_weapon_1-6` - 切换武器槽位

---

## 配置加载流程

### 1. 初始化
游戏启动时，`ConfigManager` 自动加载所有配置文件。

### 2. 访问配置
通过 `ConfigManager` 的便捷方法访问配置：

```gdscript
# 获取玩家配置
var player_config = ConfigManager.get_player_config("player_herder")

# 获取武器配置
var weapon_config = ConfigManager.get_weapon_config("weapon_sword")

# 获取宝箱配置
var chest_config = ConfigManager.get_chest_config(1)

# 获取音效配置
var sound_config = ConfigManager.get_sound_config("player_attack")
```

### 3. 热重载
修改 CSV 文件后，需要重新启动游戏才能生效。

---

## 常见问题

### Q: 修改配置后不生效？
A: 确保重新启动游戏，配置在游戏启动时加载。

### Q: 配置文件格式错误怎么办？
A: 检查控制台输出，会显示具体的错误信息。确保：
- 第一行是列名
- 第二行第一列是 `-1`
- 数据行列数与列名一致

### Q: 如何添加新的配置项？
A: 
1. 在 CSV 文件中添加新列
2. 在 `ConfigManager` 中添加对应的加载逻辑
3. 在使用的地方读取配置

### Q: 音效文件不存在会崩溃吗？
A: 不会。系统会安全处理，只在控制台输出警告。

### Q: 如何调试配置加载？
A: 查看控制台输出，`ConfigManager` 会打印加载的配置数量和详细信息。

---

## 最佳实践

### 1. 备份配置
修改配置前，先备份原始文件。

### 2. 使用注释行
第二行注释行可以帮助理解字段含义，建议保留。

### 3. 数值平衡
- 从小数值开始测试
- 逐步调整到理想效果
- 记录每次修改的原因

### 4. 命名规范
- 使用小写字母和下划线
- 名称要有意义，易于理解
- 保持一致的命名风格

### 5. 版本控制
使用 Git 等版本控制工具管理配置文件，方便回滚和对比。

---

**最后更新**: 2024年12月28日
**版本**: 1.0.0
