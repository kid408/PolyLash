# 波次系统详解

## 目录
- [系统概述](#系统概述)
- [波次配置](#波次配置)
- [生成机制](#生成机制)
- [难度曲线](#难度曲线)
- [宝箱系统](#宝箱系统)

---

## 系统概述

### 基本流程

波次系统是游戏的核心进度机制，控制敌人的生成和游戏节奏。

**完整流程**:
1. 开始新波次，加载波次配置
2. 启动波次计时器和生成计时器
3. 定期生成敌人（固定或随机间隔）
4. 敌人在玩家附近随机位置生成
5. 波次时间结束，清除所有敌人
6. 增强敌人属性（生命值+10，伤害+2）
7. 进入下一波或结束游戏

**游戏目标**:
- 共10波敌人
- 完成所有波次即胜利
- 每波难度递增

---

### 暂停机制

波次系统支持游戏暂停，确保宝箱选择时倒计时真正暂停。

**工作原理**:
```gdscript
if Global.game_paused:
    spawn_timer.set_paused(true)
    wave_timer.set_paused(true)
else:
    spawn_timer.set_paused(false)
    wave_timer.set_paused(false)
```

**应用场景**:
- 选择宝箱属性时
- 打开菜单时
- 游戏暂停时

**效果**:
- Timer从暂停位置继续
- 不会跳过时间
- 保证公平性

---

### 测试功能

按L键可以立即跳过当前波次（用于测试）。

**实现**:
```gdscript
if Input.is_physical_key_pressed(KEY_L):
    if not _l_key_pressed:
        _l_key_pressed = true
        go_to_next_wave()
```

**效果**:
- 立即结束当前波次
- 清除所有敌人
- 进入下一波
- 应用属性增强

---

## 波次配置

### 配置文件

波次配置存储在: `config/wave/wave_config.csv`

**配置示例**:
```csv
wave_id,from_wave,to_wave,wave_time,spawn_type,fixed_spawn_time,min_spawn_time,max_spawn_time
wave_1_to_5,1,5,20.0,RANDOM,1.0,0.8,1.5
wave_6_to_10,6,10,25.0,RANDOM,1.0,0.6,1.2
```

---

### 配置字段说明

| 字段 | 说明 | 示例 |
|------|------|------|
| wave_id | 波次配置ID | wave_1_to_5 |
| from_wave | 起始波次 | 1 |
| to_wave | 结束波次 | 5 |
| wave_time | 波次时长（秒） | 20.0 |
| spawn_type | 生成类型 | RANDOM/FIXED |
| fixed_spawn_time | 固定生成间隔 | 1.0 |
| min_spawn_time | 最小生成间隔 | 0.8 |
| max_spawn_time | 最大生成间隔 | 1.5 |

---

### 生成类型

#### FIXED（固定间隔）

每次生成间隔固定，节奏稳定。

**配置**:
- spawn_type = "FIXED"
- 使用fixed_spawn_time字段
- 忽略min/max_spawn_time

**示例**:
```csv
wave_id,spawn_type,fixed_spawn_time
wave_boss,FIXED,2.0
```
每2秒生成一个敌人

**适用场景**:
- Boss波次
- 特殊挑战波次
- 需要精确控制的波次

---

#### RANDOM（随机间隔）

每次生成间隔随机，增加不可预测性。

**配置**:
- spawn_type = "RANDOM"
- 使用min_spawn_time和max_spawn_time
- 忽略fixed_spawn_time

**示例**:
```csv
wave_id,spawn_type,min_spawn_time,max_spawn_time
wave_1_to_5,RANDOM,0.8,1.5
```
每0.8-1.5秒随机生成一个敌人

**适用场景**:
- 常规波次
- 增加游戏变化
- 避免节奏单调

---

### 当前配置分析

#### 波次1-5（前期）
**配置**: `wave_1_to_5`

- 波次时长: 20秒
- 生成类型: RANDOM
- 生成间隔: 0.8-1.5秒
- 预计敌人数: 13-25个

**特点**:
- 时间较短，压力较小
- 生成间隔较长，有喘息空间
- 适合玩家熟悉游戏

---

#### 波次6-10（后期）
**配置**: `wave_6_to_10`

- 波次时长: 25秒
- 生成类型: RANDOM
- 生成间隔: 0.6-1.2秒
- 预计敌人数: 21-42个

**特点**:
- 时间更长，持续压力
- 生成间隔更短，敌人更密集
- 难度显著提升

---

## 生成机制

### 敌人单位配置

敌人单位配置存储在: `config/wave/wave_unit_config.csv`（如果存在）

**配置字段**:
- wave_id: 对应的波次配置ID
- enemy_scene: 敌人场景路径
- weight: 生成权重（越高越容易生成）

**权重系统**:
```gdscript
var rng = RandomNumberGenerator.new()
var index = rng.rand_weighted(weights)
```

**示例**:
```csv
wave_id,enemy_scene,weight
wave_1_to_5,res://scenes/unit/enemy/enemy_basic.tscn,5.0
wave_1_to_5,res://scenes/unit/enemy/enemy_fast.tscn,3.0
wave_1_to_5,res://scenes/unit/enemy/enemy_tank.tscn,1.0
```

**生成概率**:
- 基础敌人: 5/(5+3+1) = 55.6%
- 快速敌人: 3/(5+3+1) = 33.3%
- 坦克敌人: 1/(5+3+1) = 11.1%

---

### 生成位置

敌人在玩家周围随机位置生成。

**生成区域**:
```gdscript
@export var spawn_area_size := Vector2(1000, 500)
```

**计算方式**:
```gdscript
var center_pos = Global.player.global_position
var random_x = randf_range(-spawn_area_size.x, spawn_area_size.x)
var random_y = randf_range(-spawn_area_size.y, spawn_area_size.y)
var spawn_pos = center_pos + Vector2(random_x, random_y)
```

**特点**:
- 以玩家为中心
- X轴范围: ±1000像素
- Y轴范围: ±500像素
- 完全随机，不可预测

**优点**:
- 敌人从四面八方出现
- 增加游戏挑战性
- 避免固定刷怪点

**缺点**:
- 可能在玩家身边生成
- 可能在屏幕外生成
- 需要玩家保持警惕

---

### 生成流程

**详细步骤**:

1. **选择敌人**:
   - 从当前波次配置获取敌人列表
   - 根据权重随机选择敌人场景
   - 加载敌人场景

2. **计算位置**:
   - 获取玩家位置
   - 在生成区域内随机选择位置
   - 确保位置有效

3. **实例化敌人**:
   - 实例化敌人场景
   - 设置敌人位置
   - 应用波次增强

4. **添加到场景**:
   - 添加到场景树
   - 记录到已生成列表
   - 重新设置生成计时器

**代码示例**:
```gdscript
func spawn_enemy() -> void:
    var enemy_scene_path = get_random_enemy_scene()
    var enemy_scene = load(enemy_scene_path) as PackedScene
    var spawn_pos = get_random_spawn_position()
    var enemy_instance = enemy_scene.instantiate() as Enemy
    enemy_instance.global_position = spawn_pos
    
    # 应用波次增强
    if enemy_instance.stats:
        enemy_instance.stats.health += (wave_index - 1) * enemy_health_per_wave
        enemy_instance.stats.damage += (wave_index - 1) * enemy_damage_per_wave
    
    get_parent().add_child(enemy_instance)
    spawned_enemies.append(enemy_instance)
    set_spawn_timer()
```

---

## 难度曲线

### 属性增强

每波结束后，敌人属性都会增强。

**增强公式**:
```gdscript
新生命值 = 基础生命值 + (波次 - 1) × 10
新攻击力 = 基础攻击力 + (波次 - 1) × 2
```

**增强参数**:
```gdscript
var enemy_health_per_wave: float = 10.0
var enemy_damage_per_wave: float = 2.0
```

---

### 各波次属性对比

以基础敌人为例（基础生命100，基础攻击10）：

| 波次 | 生命值 | 攻击力 | 生命增幅 | 攻击增幅 |
|------|--------|--------|----------|----------|
| 1 | 100 | 10 | - | - |
| 2 | 110 | 12 | +10% | +20% |
| 3 | 120 | 14 | +20% | +40% |
| 4 | 130 | 16 | +30% | +60% |
| 5 | 140 | 18 | +40% | +80% |
| 6 | 150 | 20 | +50% | +100% |
| 7 | 160 | 22 | +60% | +120% |
| 8 | 170 | 24 | +70% | +140% |
| 9 | 180 | 26 | +80% | +160% |
| 10 | 190 | 28 | +90% | +180% |

---

### 难度曲线分析

**前期（1-3波）**:
- 属性增幅较小（+0-20%）
- 玩家适应期
- 收集资源和升级

**中期（4-7波）**:
- 属性增幅中等（+30-60%）
- 挑战开始增加
- 需要合理升级

**后期（8-10波）**:
- 属性增幅巨大（+70-90%）
- 极高难度
- 需要满级装备

---

### 综合难度因素

难度不仅来自属性增强，还包括：

**1. 生成速度**:
- 波次6-10生成间隔更短
- 敌人数量更多
- 压力更大

**2. 波次时长**:
- 波次6-10时长更长（25秒 vs 20秒）
- 持续战斗时间更长
- 更容易失误

**3. 敌人类型**:
- 后期可能出现更多坦克敌人
- Boss敌人出现频率增加
- 特殊敌人组合

**4. 玩家状态**:
- 生命值可能不满
- 资源可能不足
- 疲劳度增加

---

## 宝箱系统

### 宝箱配置

宝箱配置存储在: `config/wave/wave_chest_config.csv`

**配置字段**:
- wave: 波次
- max: 最大选项数
- chest: 宝箱类型

**示例**:
```csv
wave,max,chest
1,3,upgrade
2,3,upgrade
3,3,upgrade
```

---

### 宝箱类型

#### upgrade（升级宝箱）

提供属性升级选项。

**可能的升级**:
- 生命值上限
- 移动速度
- 攻击力
- 暴击率
- 暴击伤害
- 生命恢复
- 护甲
- 闪避率

**选择机制**:
- 随机提供3个选项
- 玩家选择1个
- 立即应用效果

---

#### weapon（武器宝箱）

提供武器升级或新武器。

**可能的选项**:
- 升级现有武器
- 获得新武器
- 武器属性强化

---

#### item（物品宝箱）

提供消耗品或特殊物品。

**可能的物品**:
- 生命恢复药水
- 能量恢复
- 临时增益
- 特殊道具

---

### 宝箱触发

**触发时机**:
- 每波结束后
- 清除所有敌人后
- 进入下一波前

**触发流程**:
1. 波次计时器结束
2. 清除所有敌人
3. 暂停游戏（Global.game_paused = true）
4. 显示宝箱UI
5. 玩家选择奖励
6. 应用奖励效果
7. 恢复游戏（Global.game_paused = false）
8. 进入下一波

---

## UI显示

### 波次信息

**显示内容**:
- 当前波次: "Wave 3"
- 剩余时间: "45"

**获取方法**:
```gdscript
func get_wave_text() -> String:
    return "Wave %s" % wave_index

func get_wave_timer_text() -> String:
    return str(max(0, int(wave_timer.time_left)))
```

**更新频率**:
- 每帧更新
- 实时显示

---

### 进度提示

**波次开始**:
- 显示浮动文字: "进入第X波！"
- 颜色: 青色
- 位置: 屏幕中央

**波次结束**:
- 清除敌人
- 显示宝箱UI
- 暂停游戏

**游戏胜利**:
- 显示浮动文字: "胜利！"
- 颜色: 金色
- 位置: 屏幕中央
- 3秒后重新加载场景

---

## 配置建议

### 调整难度

**降低难度**:
- 增加波次时长
- 减少生成频率
- 降低属性增幅
- 减少总波次数

**提高难度**:
- 减少波次时长
- 增加生成频率
- 提高属性增幅
- 增加总波次数

---

### 平衡建议

**前期波次**:
- 时长: 15-20秒
- 生成间隔: 1.0-2.0秒
- 属性增幅: 较小

**中期波次**:
- 时长: 20-25秒
- 生成间隔: 0.8-1.5秒
- 属性增幅: 中等

**后期波次**:
- 时长: 25-30秒
- 生成间隔: 0.5-1.2秒
- 属性增幅: 较大

**Boss波次**:
- 时长: 30-40秒
- 生成类型: FIXED
- 生成间隔: 2.0-3.0秒
- 只生成Boss和精英

---

### 敌人组合

**前期组合**:
- 基础敌人: 60%
- 快速敌人: 30%
- 其他: 10%

**中期组合**:
- 基础敌人: 40%
- 快速敌人: 30%
- 坦克敌人: 20%
- 其他: 10%

**后期组合**:
- 基础敌人: 30%
- 快速敌人: 20%
- 坦克敌人: 30%
- Boss敌人: 10%
- 特殊敌人: 10%

---

## 开发者注意事项

### 性能优化

**敌人管理**:
- 使用对象池复用敌人
- 限制同时存在的敌人数量
- 及时清理死亡敌人

**生成优化**:
- 避免在屏幕外生成过多敌人
- 使用空间分区优化碰撞检测
- 批量生成而不是逐个生成

---

### 调试技巧

**波次调试**:
- 使用L键快速跳波
- 打印波次配置信息
- 监控敌人数量

**生成调试**:
- 打印生成位置
- 可视化生成区域
- 记录生成间隔

**属性调试**:
- 打印敌人属性
- 对比基础属性和增强属性
- 验证增强公式

---

### 常见问题

**敌人不生成**:
- 检查波次配置是否加载
- 确认敌人场景路径正确
- 检查生成计时器是否启动

**波次不结束**:
- 检查波次计时器
- 确认计时器未暂停
- 验证timeout信号连接

**属性增强不生效**:
- 检查增强公式
- 确认stats对象存在
- 验证波次索引正确

**宝箱不显示**:
- 检查宝箱配置
- 确认游戏暂停
- 验证UI显示逻辑

---

## 扩展功能

### 无尽模式

可以添加无尽模式，波次无限循环：

```gdscript
func _on_wave_timer_timeout() -> void:
    spawn_timer.stop()
    clear_enemies()
    update_enemies_new_wave()
    
    # 无尽模式：循环波次
    if endless_mode:
        wave_index += 1
        start_wave()
    # 普通模式：检查最大波次
    elif wave_index >= max_waves:
        _end_game()
    else:
        wave_index += 1
        await get_tree().create_timer(1.0).timeout
        start_wave()
```

---

### 特殊波次

可以添加特殊波次事件：

**Boss波次**:
- 只生成Boss敌人
- 更长的波次时间
- 更高的奖励

**精英波次**:
- 生成精英敌人
- 属性额外增强
- 特殊掉落

**休息波次**:
- 不生成敌人
- 恢复生命值
- 准备下一波

---

### 动态难度

根据玩家表现调整难度：

```gdscript
func adjust_difficulty() -> void:
    var player_health_percent = Global.player.health / Global.player.max_health
    
    if player_health_percent > 0.8:
        # 玩家状态良好，增加难度
        enemy_health_per_wave *= 1.1
        enemy_damage_per_wave *= 1.1
    elif player_health_percent < 0.3:
        # 玩家状态不佳，降低难度
        enemy_health_per_wave *= 0.9
        enemy_damage_per_wave *= 0.9
```

---

## 总结

波次系统是游戏的核心，控制着游戏节奏和难度曲线。通过合理配置波次参数、敌人组合和属性增强，可以创造出富有挑战性和趣味性的游戏体验。

**关键要素**:
- 清晰的难度曲线
- 合理的生成节奏
- 平衡的敌人组合
- 丰富的奖励机制

**设计原则**:
- 前期友好，后期挑战
- 节奏有张有弛
- 奖励及时反馈
- 保持可玩性
