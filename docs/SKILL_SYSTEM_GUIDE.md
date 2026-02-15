# 技能系统完整指南 - Q键画线与E键瞬发技能

> 本文档面向AI和开发者，详细说明技能系统的实现原理和添加新技能的流程。

## 目录

1. [系统架构概述](#1-系统架构概述)
2. [Q键画线技能详解](#2-q键画线技能详解)
3. [E键瞬发技能详解](#3-e键瞬发技能详解)
4. [关键函数速查表](#4-关键函数速查表)
5. [添加新技能的完整流程](#5-添加新技能的完整流程)
6. [配置文件说明](#6-配置文件说明)
7. [常见问题与注意事项](#7-常见问题与注意事项)

---

## 1. 系统架构概述

### 1.1 核心类继承关系

```
SkillBase (技能基类)
├── SkillDrawingBase (画线技能基类) - Q键技能继承此类
│   ├── skill_fire_path.gd (火焰路径)
│   ├── skill_saw_path.gd (限制移动范围)
│   ├── skill_wind_path.gd (风墙路径)
│   ├── skill_mine_path.gd (地雷路径)
│   ├── skill_web_weave.gd (蛛网编织)
│   └── skill_herder_loop.gd (范围斩杀)
│
└── 直接继承SkillBase - E键/瞬发技能
    ├── skill_dash.gd (冲刺)
    ├── skill_fire_nova.gd (火焰新星)
    ├── skill_stun_bomb.gd (眩晕炸弹)
    ├── skill_storm_eye.gd (暴风眼)
    └── skill_totem.gd (图腾替身)
```

### 1.2 技能管理流程

```
玩家输入 → PlayerBase._handle_input() → SkillManager → 具体技能类
```

### 1.3 关键文件位置

| 文件 | 路径 | 用途 |
|------|------|------|
| 技能基类 | `scenes/skills/skill_base.gd` | 所有技能的抽象基类 |
| 画线技能基类 | `scenes/skills/skill_drawing_base.gd` | Q键画线技能的中间基类 |
| 技能管理器 | `scenes/skills/skill_manager.gd` | 管理角色的所有技能槽位 |
| 玩家基类 | `scenes/unit/players/player_base.gd` | 处理输入和技能调用 |
| 技能效果管理器 | `autoloads/skill_effect_manager.gd` | 统一管理技能效果生命周期 |
| 多边形工具类 | `autoloads/polygon_utils.gd` | 闭合检测和遮罩显示 |
| 技能绑定配置 | `config/player/player_skill_bindings.csv` | 角色-技能槽位映射 |
| 技能参数配置 | `config/player/skill_params.csv` | 技能数值参数 |

---

## 2. Q键画线技能详解

### 2.1 画线技能的核心流程

```
按住Q键 → 进入规划模式(子弹时间) → 按住左键划线 → 松开Q键 → 执行技能效果
```

### 2.2 规划模式状态机

```
[空闲] → 按住Q → [规划模式] → 按住左键 → [划线中]
                      ↓                      ↓
                  松开Q键              松开左键/能量不足
                      ↓                      ↓
              [执行技能效果]          [停止划线]
                      ↓
                  [空闲]
```

### 2.3 闭合检测机制

画线技能支持两种闭合检测方式：

1. **线段交叉检测**: 检测新画的线段是否与之前的线段相交
2. **距离闭合检测**: 检测当前点是否接近起点或路径中的其他点

```gdscript
# 闭合检测核心逻辑 (SkillDrawingBase._check_intersection_and_closure)
func _check_intersection_and_closure() -> void:
    # 1. 检查线段交叉
    var latest_seg = path_segments[path_segments.size() - 1]
    for i in range(path_segments.size() - 2):
        if _segments_intersect(latest_seg, path_segments[i]):
            has_closure = true
            return
    
    # 2. 检查距离闭合
    var tolerance = _get_closure_tolerance()  # 支持羁绊加成
    if path_points.size() >= 20:
        if current_point.distance_to(path_points[0]) < tolerance:
            has_closure = true
```

### 2.4 能量消耗机制

画线技能采用**动态递增能量消耗**：

```gdscript
# 能量消耗计算 (SkillDrawingBase._calculate_current_energy_cost)
func _calculate_current_energy_cost() -> float:
    if total_distance_drawn <= energy_threshold_distance:
        # 基础阶段：固定消耗
        return energy_per_10px  # 默认1.0能量/10像素
    else:
        # 递增阶段：超过阈值后消耗递增
        var excess_distance = total_distance_drawn - energy_threshold_distance
        var multiplier = 1.0 + excess_distance * energy_scale_multiplier
        return energy_per_10px * multiplier
```

**参数说明**:
- `energy_per_10px`: 每10像素消耗的基础能量 (默认1.0)
- `energy_threshold_distance`: 能量递增阈值距离 (默认1800像素)
- `energy_scale_multiplier`: 能量递增系数 (默认0.0005-0.001)

### 2.5 SkillDrawingBase 关键函数

| 函数名 | 用途 | 调用时机 |
|--------|------|----------|
| `charge(delta)` | 蓄力/规划模式处理 | 按住Q键时每帧调用 |
| `release()` | 释放技能 | 松开Q键时调用 |
| `_enter_planning_mode()` | 进入规划模式 | 首次按下Q键 |
| `_exit_planning_mode_and_execute()` | 退出规划并执行 | 松开Q键 |
| `_start_drawing()` | 开始划线 | 按下左键 |
| `_continue_drawing()` | 继续划线 | 按住左键移动鼠标 |
| `_check_intersection_and_closure()` | 实时闭合检测 | 每添加一个点时 |
| `_perform_final_closure_check()` | 最终闭合检测 | 松开Q键时 |
| `_execute_closed_path()` | 执行闭合路径效果 | 检测到闭合时 |
| `_execute_open_path()` | 执行开放路径效果 | 未闭合时 |
| `_spawn_line_effect(start, end)` | **虚函数** - 生成线段效果 | 子类必须实现 |
| `_spawn_area_effect(polygon)` | **虚函数** - 生成区域效果 | 子类必须实现 |
| `_get_line_color()` | 获取规划线颜色 | 子类可重写 |
| `_get_closure_color()` | 获取闭合提示颜色 | 子类可重写 |
| `_update_visuals()` | 更新视觉效果 | 每帧调用 |
| `_clear_all_points()` | 清除路径并返还能量 | 右键或重置时 |

### 2.6 羁绊系统集成

SkillDrawingBase 内置了多个羁绊机制的支持：

| 羁绊机制 | 函数 | 效果 |
|----------|------|------|
| P0-1 爆破师 | `_calculate_closed_shape_damage()` | 闭合图形伤害加成 |
| P0-2 筑墙者 | `_get_line_duration()` | 线条持续时间延长 |
| P0-3 几何学家 | `_get_closure_tolerance()` | 闭合容错距离增加 |
| P1-3 风行者 | `_apply_speed_damage_bonus()` | 速度转伤害加成 |
| P1-4 炼金术士 | `_check_and_spawn_gold_trail()` | 画线时生成金币 |
| P2-2 筑墙者Lv2 | `_add_thorns_wall_effect()` | 线段反伤效果 |
| P2-4 咒术师Lv2 | `_add_curse_stacking_effect()` | 区域诅咒叠加 |
| P3-1 爆破师Lv3 | `_trigger_chain_reaction()` | 连锁爆炸 |
| P3-2 筑墙者Lv3 | `_apply_permanent_cage()` | 永久牢笼 |
| P3-3 几何学家Lv2 | `_apply_small_shape_crit()` | 小图形暴击 |
| P4-2 突击型Lv2 | `_apply_ink_inherit_bonus()` | 图形继承加成 |

---

## 3. E键瞬发技能详解

### 3.1 瞬发技能的核心流程

```
按下E键 → 检查能量/冷却 → 消耗能量 → 执行效果 → 开始冷却
```

### 3.2 SkillBase 关键函数

| 函数名 | 用途 | 说明 |
|--------|------|------|
| `execute()` | **虚函数** - 执行技能 | 瞬发技能必须实现 |
| `charge(delta)` | 蓄力处理 | 画线技能使用 |
| `release()` | 释放技能 | 画线技能使用 |
| `can_execute()` | 检查是否可执行 | 检查冷却和能量 |
| `consume_energy()` | 消耗能量 | 返回是否成功 |
| `start_cooldown()` | 开始冷却 | 技能执行后调用 |
| `reset_cooldown()` | 重置冷却 | 特殊情况使用 |
| `get_cooldown_remaining()` | 获取冷却剩余时间 | UI显示用 |
| `get_cooldown_progress()` | 获取冷却进度(0-1) | UI显示用 |

### 3.3 瞬发技能示例 (skill_fire_nova.gd)

```gdscript
extends SkillBase
class_name SkillFireNova

# 技能参数（从CSV加载）
var fire_nova_radius: float = 140.0
var fire_nova_damage: int = 35
var fire_nova_duration: float = 3.0

func execute() -> void:
    # 1. 消耗能量
    if not consume_energy():
        Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
        return
    
    # 2. 相机震动
    Global.on_camera_shake.emit(8.0, 0.2)
    
    # 3. 生成效果
    call_deferred("_spawn_fire_nova", skill_owner.global_position)
    
    # 4. 开始冷却
    start_cooldown()
```

---

## 4. 关键函数速查表

### 4.1 输入处理 (PlayerBase._handle_input)

```gdscript
func _handle_input(delta: float) -> void:
    # E技能（瞬发）
    if Input.is_action_just_pressed("skill_e"):
        skill_manager.execute_skill("e")
        return
    
    # Q技能（蓄力）
    if Input.is_action_pressed("skill_q"):
        skill_manager.charge_skill("q", delta)
        return
    elif Input.is_action_just_released("skill_q"):
        skill_manager.release_skill("q")
        return
    
    # 左键技能
    if Input.is_action_just_pressed("click_left"):
        skill_manager.execute_skill("lmb")
        return
```

### 4.2 技能管理器 (SkillManager)

| 函数名 | 用途 |
|--------|------|
| `load_skills_from_config(player_id)` | 从CSV加载技能配置 |
| `execute_skill(slot)` | 执行指定槽位的技能 |
| `charge_skill(slot, delta)` | 蓄力指定槽位的技能 |
| `release_skill(slot)` | 释放指定槽位的技能 |
| `get_skill(slot)` | 获取指定槽位的技能实例 |
| `has_skill(slot)` | 检查槽位是否有技能 |
| `get_all_skills()` | 获取所有技能 |
| `cleanup()` | 清理所有技能 |

### 4.3 技能效果管理器 (SkillEffectManager)

| 函数名 | 用途 | 返回值 |
|--------|------|--------|
| `create_area_effect(config)` | 创建多边形区域效果 | effect_id |
| `create_line_effect(config)` | 创建线段效果 | effect_id |
| `remove_effect(effect_id)` | 移除指定效果 | void |
| `clear_all_effects()` | 清理所有效果 | void |

**create_area_effect 配置参数**:
```gdscript
{
    "polygon": PackedVector2Array,  # 必需
    "damage": int,                  # 可选，默认0
    "damage_interval": float,       # 可选，默认0.5
    "duration": float,              # 可选，默认5.0
    "color": Color,                 # 可选，默认白色
    "pull_to_center": bool,         # 可选，默认false
    "pull_force": float,            # 可选，默认0
    "z_index": int,                 # 可选，默认10
    "fade_in_duration": float,      # 可选，默认0.2
    "fade_out_duration": float      # 可选，默认0.3
}
```

**create_line_effect 配置参数**:
```gdscript
{
    "start": Vector2,               # 必需
    "end": Vector2,                 # 必需
    "width": float,                 # 可选，默认24
    "damage": int,                  # 可选，默认0
    "damage_interval": float,       # 可选，默认0.5
    "duration": float,              # 可选，默认5.0
    "color": Color,                 # 可选，默认白色
    "pull_to_line": bool,           # 可选，默认false
    "pull_force": float             # 可选，默认0
}
```

### 4.4 多边形工具类 (PolygonUtils)

| 函数名 | 用途 |
|--------|------|
| `find_all_closing_polygons(points, threshold)` | 查找所有闭合多边形 |
| `show_closure_masks(polygons, color, tree, duration)` | 显示闭合遮罩动画 |
| `ensure_ccw_winding(points)` | 确保多边形逆时针方向 |
| `simplify_polygon(points, min_distance)` | 简化多边形 |

---

## 5. 添加新技能的完整流程

### 5.1 添加新的Q键画线技能

#### 步骤1: 创建技能脚本

在 `scenes/skills/players/` 目录下创建新文件，例如 `skill_ice_path.gd`:

```gdscript
extends SkillDrawingBase
class_name SkillIcePath

## ==============================================================================
## 冰霜路径 - Q键画线技能
## ==============================================================================

# 技能参数（从CSV加载）
var ice_line_damage: int = 15
var ice_line_duration: float = 4.0
var ice_line_width: float = 20.0
var ice_area_damage: int = 30
var ice_area_duration: float = 3.0
var freeze_duration: float = 2.0

func _ready() -> void:
    super._ready()
    # 可以在这里添加额外的初始化逻辑

# 必须实现：生成线段效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
    var final_duration = _get_line_duration()  # 应用羁绊加成
    
    SkillEffectManager.create_line_effect({
        "start": start,
        "end": end,
        "width": ice_line_width,
        "damage": ice_line_damage,
        "damage_interval": 0.5,
        "duration": final_duration,
        "color": Color(0.5, 0.8, 1.0, 0.8)  # 冰蓝色
    })

# 必须实现：生成区域效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
    # 应用闭合图形伤害加成
    var final_damage = int(_calculate_closed_shape_damage(float(ice_area_damage)))
    
    # 应用小图形暴击
    final_damage = int(_apply_small_shape_crit(polygon, float(final_damage)))
    
    var area = SkillEffectManager.create_area_effect({
        "polygon": polygon,
        "damage": final_damage,
        "damage_interval": 0.3,
        "duration": ice_area_duration,
        "color": Color(0.3, 0.6, 1.0, 0.5),
        "z_index": 10
    })
    
    # 可选：添加冰冻效果
    if is_instance_valid(area):
        _apply_freeze_effect(area, polygon)

# 可选：自定义线条颜色
func _get_line_color() -> Color:
    return Color(0.5, 0.8, 1.0, 1.0)  # 冰蓝色

# 可选：自定义闭合提示颜色
func _get_closure_color() -> Color:
    return Color(0.2, 0.4, 1.0, 1.0)  # 深蓝色

# 自定义效果：冰冻
func _apply_freeze_effect(area: Area2D, polygon: PackedVector2Array) -> void:
    # 实现冰冻逻辑...
    pass
```

#### 步骤2: 添加技能参数配置

在 `config/player/skill_params.csv` 中添加新行:

```csv
skill_ice_path,0,0,0,1200,0,300,0,0,0,0,0,0,0,0,0,0,0,0,0,15,4,20,30,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0.4,1800,0.0006,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
```

**重要字段说明**:
- 第1列: `skill_id` = "skill_ice_path"
- 第2列: `energy_cost` = 0 (画线技能通常为0，因为按距离消耗)
- 第38列: `energy_per_10px` = 0.4
- 第39列: `energy_threshold_distance` = 1800
- 第40列: `energy_scale_multiplier` = 0.0006

#### 步骤3: 绑定技能到角色

在 `config/player/player_skill_bindings.csv` 中添加或修改:

```csv
ice_mage,skill_ice_path,skill_ice_nova,skill_dash,
```

#### 步骤4: 创建UID文件

在 `scenes/skills/players/` 目录下创建 `skill_ice_path.gd.uid` 文件（Godot会自动生成）。

---

### 5.2 添加新的E键瞬发技能

#### 步骤1: 创建技能脚本

在 `scenes/skills/players/` 目录下创建新文件，例如 `skill_ice_nova.gd`:

```gdscript
extends SkillBase
class_name SkillIceNova

## ==============================================================================
## 冰霜新星 - E键瞬发技能
## ==============================================================================

# 技能参数（从CSV加载）
var ice_nova_radius: float = 120.0
var ice_nova_damage: int = 25
var ice_nova_duration: float = 2.0
var freeze_chance: float = 0.3

func _ready() -> void:
    super._ready()

func execute() -> void:
    # 1. 检查并消耗能量
    if not consume_energy():
        if skill_owner:
            Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
        return
    
    if not skill_owner:
        return
    
    # 2. 相机震动
    Global.on_camera_shake.emit(6.0, 0.15)
    
    # 3. 生成冰霜新星效果
    _spawn_ice_nova(skill_owner.global_position)
    
    # 4. 开始冷却
    start_cooldown()

func _spawn_ice_nova(center_pos: Vector2) -> void:
    # 创建圆形区域
    var area = Area2D.new()
    area.global_position = center_pos
    area.collision_mask = 2
    area.monitorable = false
    area.monitoring = true
    
    # 碰撞形状
    var col = CollisionShape2D.new()
    var shape = CircleShape2D.new()
    shape.radius = ice_nova_radius
    col.shape = shape
    area.add_child(col)
    
    # 视觉效果
    var vis = Polygon2D.new()
    var points = PackedVector2Array()
    var steps = 32
    for i in range(steps):
        var angle = i * TAU / steps
        points.append(Vector2(cos(angle), sin(angle)) * ice_nova_radius)
    vis.polygon = points
    vis.color = Color(0.5, 0.8, 1.0, 0.6)
    vis.z_index = 5
    area.add_child(vis)
    
    get_tree().current_scene.add_child(area)
    Global.spawn_floating_text(center_pos, "FREEZE!", Color.CYAN)
    
    # 缩放动画
    vis.scale = Vector2.ZERO
    var tween = area.create_tween()
    tween.tween_property(vis, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
    
    # 伤害和冰冻逻辑
    _apply_damage_and_freeze(area)
    
    # 生命周期
    var life = get_tree().create_timer(ice_nova_duration)
    life.timeout.connect(func():
        if is_instance_valid(area):
            var fade_tween = area.create_tween()
            fade_tween.tween_property(vis, "modulate:a", 0.0, 0.3)
            fade_tween.tween_callback(func():
                if is_instance_valid(area):
                    area.queue_free()
            )
    )

func _apply_damage_and_freeze(area: Area2D) -> void:
    # 立即造成伤害
    var targets = area.get_overlapping_bodies() + area.get_overlapping_areas()
    for t in targets:
        var enemy = null
        if t.is_in_group("enemies"):
            enemy = t
        elif t.owner and t.owner.is_in_group("enemies"):
            enemy = t.owner
        
        if enemy and enemy.has_node("HealthComponent"):
            enemy.health_component.take_damage(ice_nova_damage)
            
            # 冰冻几率
            if randf() < freeze_chance and enemy.has_method("apply_status"):
                enemy.apply_status("freeze", 2.0, 0, 1, 0)
```

#### 步骤2: 添加技能参数配置

在 `config/player/skill_params.csv` 中添加新行:

```csv
skill_ice_nova,8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,120,25,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
```

**重要字段说明**:
- 第1列: `skill_id` = "skill_ice_nova"
- 第2列: `energy_cost` = 8
- 第3列: `cooldown` = 0 (或设置冷却时间)

#### 步骤3: 绑定技能到角色

在 `config/player/player_skill_bindings.csv` 中添加或修改:

```csv
ice_mage,skill_ice_path,skill_ice_nova,skill_dash,
```

---

## 6. 配置文件说明

### 6.1 player_skill_bindings.csv 格式

```csv
player_id,slot_q,slot_e,slot_lmb,slot_rmb
butcher,skill_saw_path,skill_meat_stake,skill_dash,
```

| 列名 | 说明 |
|------|------|
| player_id | 角色ID |
| slot_q | Q键技能ID |
| slot_e | E键技能ID |
| slot_lmb | 左键技能ID |
| slot_rmb | 右键技能ID (可选) |

### 6.2 skill_params.csv 常用字段

| 字段名 | 说明 | 适用技能类型 |
|--------|------|--------------|
| skill_id | 技能唯一标识 | 所有 |
| energy_cost | 能量消耗 | 瞬发技能 |
| cooldown | 冷却时间(秒) | 所有 |
| energy_per_10px | 每10像素能量消耗 | 画线技能 |
| energy_threshold_distance | 能量递增阈值 | 画线技能 |
| energy_scale_multiplier | 能量递增系数 | 画线技能 |
| dash_distance | 冲刺距离 | 冲刺技能 |
| dash_speed | 冲刺速度 | 冲刺技能 |
| dash_damage | 冲刺伤害 | 冲刺技能 |
| fire_line_damage | 火线伤害 | 火焰路径 |
| fire_line_duration | 火线持续时间 | 火焰路径 |
| fire_sea_damage | 火海伤害 | 火焰路径 |
| wind_wall_pull_force | 风墙吸力 | 风墙路径 |
| mine_damage | 地雷伤害 | 地雷路径 |

---

## 7. 常见问题与注意事项

### 7.1 技能不生效的排查步骤

1. **检查技能绑定**: 确认 `player_skill_bindings.csv` 中有正确的映射
2. **检查技能脚本路径**: 脚本必须在 `scenes/skills/players/` 目录下
3. **检查类名**: 脚本的 `class_name` 必须唯一
4. **检查继承关系**: Q键技能继承 `SkillDrawingBase`，E键技能继承 `SkillBase`
5. **检查虚函数实现**: 画线技能必须实现 `_spawn_line_effect()` 和 `_spawn_area_effect()`

### 7.2 画线技能的注意事项

1. **子弹时间**: 规划模式会将 `Engine.time_scale` 设为 0.1
2. **能量返还**: 右键清除路径时会返还已消耗的能量
3. **Line2D节点**: 必须设置 `top_level = true` 才能正确显示
4. **闭合检测**: 至少需要3条线段才能形成闭合

### 7.3 效果生命周期管理

1. **使用SkillEffectManager**: 推荐使用统一的效果管理器，而不是手动管理
2. **角色切换**: 技能效果不应该随角色切换而消失
3. **cleanup()函数**: 不要在cleanup中清理已生成的效果节点

### 7.4 性能优化建议

1. **限制路径点数量**: 过长的路径会影响性能
2. **简化多边形**: 使用 `PolygonUtils.simplify_polygon()` 减少点数
3. **限制同时存在的效果数量**: 避免生成过多的Area2D节点

---

## 附录: 现有技能一览

| 技能ID | 类型 | 描述 |
|--------|------|------|
| skill_dash | 瞬发 | 向鼠标方向冲刺 |
| skill_saw_path | 画线 | 锯条路径，闭合时捕获敌人 |
| skill_fire_path | 画线 | 火焰路径，闭合时生成火海 |
| skill_wind_path | 画线 | 风墙路径，吸附敌人 |
| skill_mine_path | 画线 | 地雷路径，沿线布雷 |
| skill_web_weave | 画线 | 蛛网编织，收网处决 |
| skill_herder_loop | 画线 | 牧羊人套索，闭合时爆炸 |
| skill_fire_nova | 瞬发 | 火焰新星，范围伤害 |
| skill_stun_bomb | 瞬发 | 眩晕炸弹，范围眩晕 |
| skill_storm_eye | 瞬发 | 暴风眼，吸附并伤害 |
| skill_totem | 瞬发 | 图腾，持续效果 |
| skill_meat_stake | 瞬发 | 肉桩投掷 |
| skill_herder_explosion | 瞬发 | 牧羊人爆炸 |
