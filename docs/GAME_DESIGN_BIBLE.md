# 《PolyLash》终极游戏设计圣经 (The Ultimate GDD)

> **文档版本**: v1.0  
> **最后更新**: 2026-01-25  
> **游戏引擎**: Godot 4.5  
> **游戏类型**: Roguelike 生存射击 + 角色切换 + 羁绊系统

---

## 📋 目录

1. [游戏概述](#1-游戏概述)
2. [操控指南](#2-操控指南)
3. [角色系统](#3-角色系统)
4. [战斗核心](#4-战斗核心)
5. [技能系统](#5-技能系统)
6. [敌人系统](#6-敌人系统)
7. [波次系统](#7-波次系统)
8. [商店系统](#8-商店系统)
9. [升级系统](#9-升级系统)
10. [道具系统](#10-道具系统)
11. [羁绊系统](#11-羁绊系统)
12. [系统架构](#12-系统架构)
13. [数据流](#13-数据流)
14. [细节备忘录](#14-细节备忘录)

---

## 1. 游戏概述

### 1.1 核心玩法

**PolyLash** 是一款 Roguelike 生存射击游戏，玩家需要：
- 选择 1-3 个角色组成小队
- 在 10 波敌人攻击中存活
- 通过角色切换（Tab/1-2-3键）应对不同战况
- 利用羁绊系统获得强力加成
- 在波次间商店购买道具强化角色

### 1.2 游戏流程

```
角色选择界面 → 武器选择 → 强化属性 → 进入战斗
  ↓
波次1-10循环：
  - 生成敌人（定时刷新）
  - 击杀敌人获得经验/金币/能量
  - 波次结束 → 商店购买道具
  - 开始下一波
  ↓
完成10波 → 胜利
任意角色死亡 → 失败
```

### 1.3 核心特色

1. **角色切换系统**: 实时切换角色，每个角色技能都不同,保留技能效果（如火海、地雷）,普通攻击是自动攻击(远程,近战)
2. **羁绊系统**: 可以将三个角色带进游戏,队伍角色组合激活强力羁绊效果
3. **三类道具系统**: 
   - Tier 1: 直接加属性
   - Tier 2: 标签修改器（如火焰伤害+20%）
   - Tier 3: 圣物（提供额外羁绊标签）
4. **画线系统**: Q键画线，按线段长短消耗能量，未闭合线段,选段轨迹攻击,闭合线段,变AOE攻击
4. **大招系统**: F键释放，消耗100%能量，变身强化,普通攻击变AOE攻击
5. **波次商店**: 每波结束购买道具，支持刷新

---

## 2. 操控指南

### 2.1 按键映射表

| 代码Action名 | 物理按键 | 触发功能 | 逻辑入口脚本 |
|-------------|---------|---------|-------------|
| `move_left` | A | 向左移动 | `player_base.gd` |
| `move_right` | D | 向右移动 | `player_base.gd` |
| `move_up` | W | 向上移动 | `player_base.gd` |
| `move_down` | S | 向下移动 | `player_base.gd` |
| `click_left` |  冲刺（消耗能量） | 各角色脚本 |
| `skill_q` | Q | Q技能 | 屏幕划线,魔法技能,闭合图形是大招 `SkillManager` |
| `skill_e` | E | E技能 | 以角色为中心的AOE,各角色AOE效果不同 `SkillManager` |
| `skill_f` | F | 变身大招,普通攻击变AOE（消耗100%能量） | `player_base.gd` |
| `switch_player` | Tab | 循环切换角色 | `arena.gd` |
| `switch_player_1` | 1 | 切换到角色1 | `arena.gd` |
| `switch_player_2` | 2 | 切换到角色2 | `arena.gd` |
| `switch_player_3` | 3 | 切换到角色3 | `arena.gd` |
| `ui_cancel` | ESC | 打开退出确认对话框 | `arena.gd` |

### 2.2 交互逻辑

- **鼠标位置**: 决定角色冲撞方向
- **移动限制**: 无限制，可自由移动
- **攻击方向**: 自动攻击最近敌人


---

## 3. 角色系统

### 3.1 角色列表

游戏中所有角色从 `config/player/player_config.csv` 加载，包括：

| 角色ID | 显示名称 | 羁绊标签 | 特点 |
|--------|---------|---------|------|
| `butcher` | 屠夫 | 武道/毁灭/近战 | 限制敌人移动范围，批量击退敌人 |
| `pyro` | 烈焰法师 | 秘术/毁灭/火焰 | 火焰AOE，持续伤害 |
| `sapper` | 爆破手 | 幸存者/控制/陷阱 | 地雷陷阱，区域控制 |
| `herder` | 牧羊人 | 幸存者/控制/召唤 | 线技能，群体控制 |
| `weaver` | 织网者 | 秘术/控制/召唤 | 蛛网陷阱，减速 |
| `tempest` | 风暴使 | 秘术/速度/风暴 | 风墙推进，高机动 |

### 3.2 角色属性

每个角色有以下基础属性（从CSV加载）：

```gdscript
# 基础属性
health: float = 100.0          # 生命值
max_energy: float = 100.0       # 最大能量
energy_regen: float = 0.5       # 能量恢复速度
base_speed: float = 300.0       # 移动速度
max_armor: int = 3              # 最大护甲
damage: float = 10.0            # 基础伤害

# 技能消耗
skill_q_cost: float = 50.0      # Q技能消耗
skill_e_cost: float = 30.0      # E技能消耗
skill_f_cost: float = 60%      # F技能消耗

# 其他
close_threshold: float = 60.0   # 近战判定距离
knockback_scale: float = 0.3    # 击退缩放
```

### 3.3 角色切换机制

#### 3.3.1 切换方式

1. **Tab键**: 循环切换到下一个存活角色
2. **1-2-3键**: 精准切换到指定索引的角色
3. **自我屏蔽**: 如果已经是当前角色，忽略切换

#### 3.3.2 切换流程

```
1. 保存当前角色状态（血量、能量、护甲）
2. 销毁当前角色实例
3. 在原位置生成新角色
4. 恢复新角色的保存状态
5. 重新连接信号
6. 不清理旧角色的技能效果（火海、地雷等保留）
```

#### 3.3.3 状态保存

角色状态存储在 `Global.player_states`:

```gdscript
{
  "player_id": {
    "health": 100.0,
    "max_health": 100.0,
    "energy": 500.0,
    "max_energy": 100.0,
    "armor": 3,
    "health_regen": 0.0,
    "energy_regen": 0.5
  }
}
```

#### 3.3.4 未激活角色恢复

未激活的角色会自动恢复能量和血量（如果配置了 `health_regen`）：

```gdscript
# 在 Global._update_inactive_players_regen() 中
energy += energy_regen * delta
if health_regen > 0:
    health += health_regen * delta
```

### 3.4 角色工厂

角色通过 `PlayerFactory` 动态创建：

```gdscript
# 创建角色
var player = PlayerFactory.create_player("butcher")
player.global_position = spawn_pos
add_child(player)

# 恢复状态
Global.restore_player_state(player)
```


---

## 4. 战斗核心

### 4.1 攻击流程

#### 4.1.1 武器攻击状态机

```
IDLE → ATTACK → RECOIL → BACK → IDLE
  ↓       ↓        ↓       ↓
 等待    前摇     后坐力   回位
```

#### 4.1.2 攻击参数

```gdscript
# 武器属性（从 weapon_stats_config.csv 加载）
damage: float = 10.0              # 基础伤害
accuracy: float = 0.9             # 精准度
cooldown: float = 1.0             # 冷却时间
crit_chance: float = 0.05         # 暴击率
crit_damage: float = 1.5          # 暴击倍率
max_range: float = 150.0          # 最大射程
knockback: float = 0.0            # 击退力
life_steal: float = 0.0           # 生命偷取
recoil: float = 25.0              # 后坐力距离
recoil_duration: float = 0.1      # 后坐力时长
attack_duration: float = 0.2      # 攻击动画时长
back_duration: float = 0.15       # 回位时长
projectile_speed: float = 1600.0  # 子弹速度
```

### 4.2 伤害公式

#### 4.2.1 最终伤害计算

```gdscript
# 1. 基础伤害
base_damage = weapon.damage + player.damage

# 2. 应用道具修改器（Tier 2）
modified_damage = ModifierManager.get_modified_value(
    base_damage, 
    ["damage", "fire", "aoe"]  # 技能标签
)

# 3. 暴击判定
if randf() < crit_chance:
    final_damage = modified_damage * crit_damage
    is_critical = true
else:
    final_damage = modified_damage

# 4. 敌人护甲减伤
damage_multiplier = 1.0 - (enemy.armor * 0.2)
final_damage *= damage_multiplier
```

#### 4.2.2 玩家受伤计算

```gdscript
# 护甲减伤
damage_multiplier = 1.0 - (clamp(armor, 0, max_armor) * 0.2)
final_damage = max(1, raw_damage * damage_multiplier)

# 护甲破碎
if armor > 0:
    armor -= 1
    # 轻微反馈
    Global.frame_freeze(0.03, 0.2)
    Global.on_camera_shake.emit(4.0, 0.1)
else:
    # 强烈反馈
    Global.frame_freeze(0.08, 0.15)
    Global.on_camera_shake.emit(10.0, 0.25)
```

### 4.3 命中反馈

#### 4.3.1 顿帧系统 (Hitstop)

```gdscript
# 根据伤害大小调整顿帧强度
var freeze_duration = clamp(damage / 100.0, 0.02, 0.08)
Global.frame_freeze(freeze_duration, 0.2)

# 实现原理
Engine.time_scale = 0.05  # 接近静止
await get_tree().create_timer(duration * time_scale, true, false, true).timeout
Engine.time_scale = 1.0
```

#### 4.3.2 震屏系统

```gdscript
# 根据伤害大小调整震动强度
Global.on_camera_shake.emit(2.0 + damage / 20.0, 0.08)

# 指向性震动（未实现）
Global.on_directional_shake.emit(direction, strength)
```

#### 4.3.3 飘字系统

```gdscript
# 伤害飘字
Global.spawn_floating_text(position, str(damage), Color.RED)

# 暴击飘字
Global.spawn_floating_text(position, str(damage), Color.YELLOW)

# 闪避飘字
Global.spawn_floating_text(position, "闪!", Color.CYAN)
```

### 4.4 击退系统

```gdscript
# 应用击退
func apply_knockback(knock_dir: Vector2, knock_power: float):
    knockback_dir = knock_dir
    knockback_power = knock_power
    knockback_timer.start()

# 击退衰减（极快）
if external_force.length() > 1.0:
    position += external_force * delta
    external_force = external_force.lerp(Vector2.ZERO, 50.0 * delta)
```

### 4.5 生命偷取

```gdscript
# 武器配置中的 life_steal
if life_steal > 0:
    var heal_amount = damage * life_steal
    player.health_component.heal(heal_amount)
```

### 4.6 能量系统

#### 4.6.1 能量获取

```gdscript
# 击杀敌人获得能量
func gain_energy(amount: float):
    energy = min(energy + amount, max_energy)
    Global.spawn_floating_text(position, "+%d Energy" % amount, Color.CYAN)

# 敌人配置中的 energy_drop
enemy_config.get("energy_drop", 5)
```

#### 4.6.2 能量消耗

```gdscript
# 技能消耗
func consume_energy(amount: float) -> bool:
    if energy >= amount:
        energy -= amount
        return true
    else:
        Global.spawn_floating_text(position, "No Energy!", Color.RED)
        return false
```

#### 4.6.3 能量恢复

```gdscript
# 每帧恢复
if energy < max_energy:
    energy += energy_regen * delta
```


---

## 5. 技能系统

### 5.1 技能架构

每个角色有独立的 `SkillManager`，管理 Q/E/F 技能：

```gdscript
# SkillManager 结构
class_name SkillManager extends Node

var skill_q: Skill = null
var skill_e: Skill = null
var click_left: Skill = null

func _input(event):
    if event.is_action_pressed("skill_q"):
        skill_q.try_activate()
    if event.is_action_pressed("skill_e"):
        skill_e.try_activate()
    if event.is_action_pressed("click_left"):
        click_left.try_activate()
```

### 5.2 技能基类

```gdscript
class_name Skill extends Node

var player: PlayerBase
var cooldown_timer: Timer
var is_on_cooldown: bool = false

# 技能参数（从 skill_params.csv 加载）
var energy_cost: float = 50.0
var cooldown: float = 5.0

func try_activate() -> bool:
    if is_on_cooldown:
        return false
    if not player.consume_energy(energy_cost):
        return false
    
    activate()
    start_cooldown()
    return true

func activate():
    # 子类实现具体逻辑
    pass

func start_cooldown():
    is_on_cooldown = true
    cooldown_timer.start(cooldown)
```

### 5.3 技能示例

#### 5.3.1 烈焰法师 - 火海 (Q键)

```gdscript
# skill_fire_path.gd
class_name SkillFirePath extends Skill

var fire_path_scene = preload("res://scenes/skills/fire_path_area.tscn")

func activate():
    # 在鼠标位置生成火海
    var mouse_pos = get_global_mouse_position()
    var fire_path = fire_path_scene.instantiate()
    fire_path.global_position = mouse_pos
    
    # 应用道具修改器
    var base_damage = 10.0
    var modified_damage = player.get_skill_param(base_damage, ["damage", "fire", "aoe"])
    fire_path.damage = modified_damage
    
    # 添加到场景根节点（不跟随角色）
    get_tree().root.add_child(fire_path)
```

**火海效果**:
- 持续时间: 8秒
- 伤害间隔: 0.5秒
- 基础伤害: 10
- 标签: `["damage", "fire", "aoe"]`
- 特点: 切换角色后火海保留

#### 5.3.2 爆破手 - 地雷 (Q键)

```gdscript
# skill_mine.gd
class_name SkillMine extends Skill

var mine_scene = preload("res://scenes/skills/mine.tscn")

func activate():
    var mouse_pos = get_global_mouse_position()
    var mine = mine_scene.instantiate()
    mine.global_position = mouse_pos
    
    # 设置地雷参数
    mine.damage = player.get_skill_param(50.0, ["damage", "explosion", "aoe"])
    mine.trigger_radius = 80.0
    mine.explosion_radius = 150.0
    
    get_tree().root.add_child(mine)
```

**地雷效果**:
- 触发半径: 80
- 爆炸半径: 150
- 基础伤害: 50
- 标签: `["damage", "explosion", "aoe"]`
- 特点: 敌人靠近触发，切换角色后地雷保留

#### 5.3.3 牧羊人 - 线技能 (Q键)

```gdscript
# skill_line.gd
class_name SkillLine extends Skill

var line_points: Array[Vector2] = []
var line_node: Line2D

func activate():
    # 开始绘制线
    line_points.clear()
    line_points.append(player.global_position)
    is_drawing = true

func _process(delta):
    if is_drawing:
        # 跟随鼠标绘制线
        var mouse_pos = get_global_mouse_position()
        line_points.append(mouse_pos)
        update_line_visual()

func finish_line():
    # 检测线内敌人
    var enemies_in_loop = detect_enemies_in_polygon(line_points)
    for enemy in enemies_in_loop:
        enemy.take_damage(100)
    
    # 清理线
    line_points.clear()
    is_drawing = false
```

**线技能效果**:
- 绘制方式: 按住Q键跟随鼠标
- 闭环判定: 起点和终点距离 < 50
- 伤害: 100（闭环内所有敌人）
- 特点: 可被 LineBreaker 敌人切断

### 5.4 大招系统 (F键)

#### 5.4.1 大招基类

```gdscript
# skill_ultimate_base.gd
class_name SkillUltimate extends Node

var player: PlayerBase
var config: Dictionary  # 从 ult_config.csv 加载

# 大招参数
var duration: float = 10.0
var energy_cost: float = 100.0  # 百分比
var bonus_bond_tag: String = ""  # 临时羁绊标签
var visual_color: Color = Color.RED
var scale_multiplier: float = 1.5

func try_activate() -> bool:
    if player.get_energy_percent() < 100.0:
        Global.spawn_floating_text(player.position, "能量不足!", Color.RED)
        return false
    
    if not player.consume_energy_percent(100.0):
        return false
    
    activate()
    return true

func activate():
    # 1. 变身效果
    apply_visual_effects()
    
    # 2. 添加临时羁绊标签
    if bonus_bond_tag != "":
        BondManager.add_temp_tag(bonus_bond_tag)
    
    # 3. 启用过载模式（所有羁绊激活最高等级）
    BondManager.set_overdrive_mode(true)
    
    # 4. 定时结束
    await get_tree().create_timer(duration).timeout
    deactivate()

func deactivate():
    # 恢复正常
    BondManager.set_overdrive_mode(false)
    if bonus_bond_tag != "":
        BondManager.remove_temp_tag(bonus_bond_tag)
    restore_visual_effects()
```

#### 5.4.2 大招配置

从 `config/player/ult_config.csv` 加载：

| 角色 | 大招名称 | 持续时间 | 临时标签 | 颜色 | 缩放 |
|------|---------|---------|---------|------|------|
| butcher_ult | 血之狂怒 | 10s | martial | 红色 | 1.5x |
| pyro_ult | 炼狱化身 | 12s | destruction | 橙色 | 1.3x |
| wind_ult | 风之升华 | 8s | velocity | 黄色 | 1.2x |
| weaver_ult | 大地泰坦 | 10s | defense | 蓝色 | 1.2x |
| sapper_ult | 爆破专家 | 10s | destruct | 紫色 | 1.2x |
| herder_ult | 自然之怒 | 10s | nature | 绿色 | 1.2x |

#### 5.4.3 大招特殊效果

**屠夫大招** (`skill_ultimate_butcher.gd`):
- 冲刺伤害 +200%
- 冲刺距离 +50%
- 移动速度 +30%
- TODO 以上未实现

**烈焰法师大招** (`skill_ultimate_pyro.gd`):
- 火焰伤害 +100%
- 火海持续时间 +50%
- 自动在周围生成火海
- TODO 以上未实现

**爆破手大招** (`skill_ultimate_sapper.gd`):
- 地雷伤害 +150%
- 地雷触发半径 +50%
- TODO 以上未实现

**织网者大招** (`skill_web_weave.gd`):
- 技能伤害 +100%
- 技能能量 -50%
- TODO 以上未实现

**御风者大招** (`skill_ultimate_pyro.gd`):
- 技能伤害 +100%
- 技能持续时间 +50%
- 自动在周围生成风海
- TODO 以上未实现

**其他基础角色大招** (`skill_ultimate_base.gd`):
- 技能伤害 +100%
- TODO 以上未实现


---

## 6. 敌人系统

### 6.1 敌人类型

从 `config/enemy/enemy_config.csv` 加载：

| 敌人ID | 类型 | 特点 |
|--------|------|------|
| `basic_enemy` | NORMAL | 普通追逐 |
| `breaker_enemy` | LINE_BREAKER | 切断线技能 |
| `shielded_enemy` | SHIELDED | 减伤30%，远程射击 |
| `spiked_enemy` | SPIKED | 冲锋攻击，霸体 |
| `mine_layer_enemy` | MINE_LAYER | 死后留毒池 |

### 6.2 敌人AI状态机

```gdscript
enum AIState {
    CHASE,      # 正常追逐
    PREPARING,  # 预警阶段（红线）
    CHARGING,   # 冲锋阶段
    COOLDOWN    # 休息
}
```

#### 6.2.1 追逐状态 (CHASE)

```gdscript
func _state_chase(delta):
    # 1. 检查距离
    var dist = global_position.distance_to(Global.player.global_position)
    if dist <= stop_distance:
        return  # 停止移动
    
    # 2. 计算移动方向（包含群聚逻辑）
    var move_vec = get_move_direction() + (knockback_dir * knockback_power)
    position += move_vec * speed * delta
    
    # 3. 冲锋判定
    if can_charge and dist < 300.0 and dist > 100.0:
        start_charge_sequence()
```

#### 6.2.2 预警状态 (PREPARING)

```gdscript
func start_charge_sequence():
    current_ai_state = AIState.PREPARING
    ai_timer = charge_prep_time  # 0.8秒
    
    # 锁定冲锋方向
    charge_vector = global_position.direction_to(Global.player.global_position).normalized()
    
    # 绘制红线预警
    var end_pos = global_position + (charge_vector * 500.0)
    warning_line.add_point(global_position)
    warning_line.add_point(end_pos)
    
    # 红线淡入动画
    var tween = create_tween()
    tween.tween_property(warning_line, "default_color", Color(1, 0, 0, 0.3), 0.2)
```

#### 6.2.3 冲锋状态 (CHARGING)

```gdscript
func _state_charging(delta):
    ai_timer -= delta
    
    # 沿锁定方向高速移动
    position += charge_vector * speed * charge_speed_mult * delta
    
    # 霸体：免疫击退
    if ai_timer <= 0:
        current_ai_state = AIState.COOLDOWN
        ai_timer = charge_cooldown  # 3秒
```

### 6.3 特殊敌人能力

#### 6.3.1 硬壳龟 (SHIELDED)

```gdscript
# 减伤30%
if enemy_type == EnemyType.SHIELDED:
    hitbox.damage *= 0.3
    
    # 轻微反伤
    if Global.player.has_method("take_damage"):
        Global.player.take_damage(1)

# 远程射击
class ShootingBehavior:
    var cooldown: float = 3.0
    var projectile_count: int = 3
    var arc_angle: float = 45.0
    
    func shoot():
        for i in range(projectile_count):
            var angle = -arc_angle/2 + (arc_angle / (projectile_count-1)) * i
            spawn_projectile(angle)
```

#### 6.3.2 地雷怪 (MINE_LAYER)

```gdscript
# 死后生成毒池
func _spawn_poison_pool(pos: Vector2):
    var poison = Area2D.new()
    poison.collision_layer = 0
    poison.collision_mask = 1
    
    # 碰撞体
    var shape = CircleShape2D.new()
    shape.radius = pool_radius  # 60
    
    # 伤害计时器
    var dmg_timer = Timer.new()
    dmg_timer.wait_time = pool_damage_interval  # 0.5秒
    dmg_timer.timeout.connect(func():
        for target in poison.get_overlapping_bodies():
            if target.is_in_group("player"):
                target.take_damage(pool_damage)  # 5伤害
    )
    
    # 生命计时器
    var life_timer = Timer.new()
    life_timer.wait_time = pool_lifetime  # 8秒
    life_timer.timeout.connect(func():
        poison.queue_free()
    )
```

#### 6.3.3 剪刀手 (LINE_BREAKER)

```gdscript
# 切断线技能
func _check_line_break():
    if Global.player.has_method("try_break_line"):
        Global.player.try_break_line(global_position, break_radius)

# 在牧羊人中实现
func try_break_line(enemy_pos: Vector2, radius: float):
    for i in range(line_points.size() - 1):
        var p1 = line_points[i]
        var p2 = line_points[i + 1]
        var dist = Geometry2D.get_closest_point_to_segment(enemy_pos, p1, p2).distance_to(enemy_pos)
        if dist < radius:
            # 切断线
            line_points.clear()
            break
```

### 6.4 敌人属性增强

每波敌人属性递增：

```gdscript
# 在 spawner.gd 中
enemy.health += (wave_index - 1) * enemy_health_per_wave  # +10/波
enemy.damage += (wave_index - 1) * enemy_damage_per_wave  # +2/波
```

### 6.5 敌人奖励

击杀敌人获得：

```gdscript
# 从 enemy_config.csv 读取
var energy_drop = enemy_config.get("energy_drop", 5)
var xp_value = int(enemy_config.get("xp_value", 10))
var gold_value = int(enemy_config.get("gold_value", 5))

player.gain_energy(energy_drop)
player.add_xp(xp_value)
player.add_gold(gold_value)
```


---

## 7. 波次系统

### 7.1 波次配置

从 `config/wave/wave_config.csv` 和 `wave_units_config.csv` 加载：

```csv
# wave_config.csv
wave_id,from_wave,to_wave,wave_time,spawn_type,min_spawn_time,max_spawn_time
wave_1_3,1,3,60,RANDOM,0.8,1.5
wave_4_6,4,6,80,RANDOM,0.6,1.2
wave_7_10,7,10,100,FIXED,0.5,0.5

# wave_units_config.csv
wave_id,enemy_id,enemy_scene,weight
wave_1_3,basic_enemy,res://scenes/unit/enemy/enemy.tscn,10
wave_1_3,breaker_enemy,res://scenes/unit/enemy/enemy.tscn,2
wave_4_6,shielded_enemy,res://scenes/unit/enemy/enemy.tscn,5
```

### 7.2 波次流程

```
1. start_wave()
   - 加载波次配置
   - 启动波次计时器（wave_timer）
   - 启动生成计时器（spawn_timer）
   - 初始化精英敌人生成器

2. 定时生成敌人
   - 根据权重随机选择敌人类型
   - 在玩家周围随机位置生成
   - 应用波次增强（血量、伤害）

3. 波次结束
   - 清除所有敌人
   - 发出 wave_completed 信号
   - 显示商店

4. 商店关闭
   - 调用 start_next_wave()
   - wave_index += 1
   - 重复步骤1
```

### 7.3 生成位置计算

```gdscript
func get_random_spawn_position() -> Vector2:
    var center_pos = Global.player.global_position
    
    # 在玩家周围随机生成
    var random_x = randf_range(-spawn_area_size.x / 2.0, spawn_area_size.x / 2.0)
    var random_y = randf_range(0, spawn_area_size.y)
    
    var spawn_pos = center_pos + Vector2(random_x, random_y)
    
    # 限制Y坐标范围
    var min_y = center_pos.y - 200.0
    var max_y = center_pos.y + spawn_area_size.y + 200.0
    spawn_pos.y = clamp(spawn_pos.y, min_y, max_y)
    
    return spawn_pos
```

### 7.4 精英敌人系统

#### 7.4.1 精英配置

从 `config/enemy/elite_config.csv` 加载：

```csv
elite_id,display_name,scene_path,base_health,base_damage
elite_glutton,贪食者,res://scenes/unit/enemy/elite_glutton.tscn,1000,50
```

#### 7.4.2 精英生成器

```gdscript
class EliteSpawner:
    var wave_id: String
    var spawn_config: EliteSpawnConfig
    var spawn_count: int = 0
    var next_spawn_time: float = 0.0
    
    func update(delta: float) -> bool:
        if spawn_count >= max_spawn_count:
            return false
        
        next_spawn_time -= delta
        if next_spawn_time <= 0:
            spawn_count += 1
            next_spawn_time = randf_range(spawn_interval_min, spawn_interval_max)
            return true
        return false
```

#### 7.4.3 精英进化系统

精英敌人有多个阶段，击杀后进化：

```gdscript
# 阶段1 → 阶段2 → 阶段3
var current_stage: int = 1
var max_stage: int = 3

func on_death():
    if current_stage < max_stage and allow_evolution:
        evolve_to_next_stage()
    else:
        destroy_enemy()

func evolve_to_next_stage():
    current_stage += 1
    health = base_health * (1.0 + current_stage * 0.5)
    damage = base_damage * (1.0 + current_stage * 0.3)
    scale *= 1.2
```

### 7.5 暂停机制

```gdscript
func _process(delta):
    # 游戏暂停时，暂停所有Timer
    if Global.game_paused:
        spawn_timer.set_paused(true)
        wave_timer.set_paused(true)
        elite_spawn_timer.set_paused(true)
    else:
        spawn_timer.set_paused(false)
        wave_timer.set_paused(false)
        elite_spawn_timer.set_paused(false)
```

### 7.6 测试功能

按 L 键跳过当前波次：

```gdscript
func _input(event):
    if Input.is_physical_key_pressed(KEY_L):
        if not _l_key_pressed:
            _l_key_pressed = true
            go_to_next_wave()
```


---

## 8. 商店系统

### 8.1 商店触发

每波结束后自动显示商店：

```gdscript
# spawner.gd
func _on_wave_timer_timeout():
    spawn_timer.stop()
    clear_enemies()
    
    # 发出波次完成信号
    wave_completed.emit(wave_index)
    
    # 暂停生成
    pause_spawning()

# arena.gd
func _on_wave_completed(wave_number: int):
    if shop_panel:
        shop_panel.show_shop(wave_number + 1)
```

### 8.2 商店物品配置

从 `config/item/shop_item_config.csv` 加载：

```csv
item_id,item_name,item_type,item_tier,effect_type,effect_target,target_tags,effect_value,icon_path,description,price,shop_weight,is_trade_off
fire_boost,火焰强化,magic,2,percent_add,modifier,fire,0.20,res://...,火焰伤害+20%,100,10,0
hp_potion,生命药水,attribute,1,flat_add,stat,max_health,50,res://...,生命上限+50,50,15,0
speed_curse,速度诅咒,curse,2,flat_add,stat,speed,-30,res://...,移动速度-30（换取其他加成）,30,5,1
```

### 8.3 商店生成逻辑

```gdscript
# shop_manager.gd
func generate_shop_items(count: int = 3):
    current_shop_items.clear()
    purchased_indices.clear()
    
    # 构建权重池
    var weighted_pool: Array = []
    for item_id in shop_item_configs.keys():
        var weight = config.get("shop_weight", 10)
        for i in range(weight):
            weighted_pool.append(item_id)
    
    # 随机抽取（允许重复）
    for i in range(count):
        var random_index = randi() % weighted_pool.size()
        var item_id = weighted_pool[random_index]
        current_shop_items.append(shop_item_configs[item_id])
```

### 8.4 购买流程

```gdscript
func purchase_item(index: int) -> bool:
    # 1. 检查索引有效性
    if index < 0 or index >= current_shop_items.size():
        return false
    
    # 2. 检查是否已购买
    if index in purchased_indices:
        return false
    
    # 3. 检查金币
    var item = current_shop_items[index]
    var price = item.get("price", 0)
    if DataManager.get_total_gold() < price:
        purchase_failed.emit("金币不足")
        return false
    
    # 4. 扣除金币
    DataManager.add_gold(-price)
    
    # 5. 应用物品效果
    _apply_item_effects(item)
    
    # 6. 标记已购买
    purchased_indices.append(index)
    item_purchased.emit(item_id, index)
    return true
```

### 8.5 物品效果应用

```gdscript
func _apply_item_effects(item: Dictionary):
    var effects = item.get("effects", [])
    
    for effect in effects:
        var effect_target = effect.get("effect_target", "")
        
        match effect_target:
            "modifier":
                # Tier 2: 添加修改器
                ModifierManager.add_modifier(
                    target_tags, 
                    effect_type, 
                    effect_value
                )
            
            "stat":
                # Tier 1: 直接修改属性
                _apply_stat_effect(Global.player, target_tags, effect_value)
            
            "bond":
                # Tier 3: 羁绊标签（未来扩展）
                pass
```

### 8.6 刷新功能

```gdscript
const REROLL_COST = 50  # 刷新费用

func reroll_shop() -> bool:
    if DataManager.get_total_gold() < REROLL_COST:
        purchase_failed.emit("金币不足")
        return false
    
    DataManager.add_gold(-REROLL_COST)
    generate_shop_items(current_shop_items.size())
    shop_rerolled.emit()
    return true
```

### 8.7 商店UI

```gdscript
# shop_panel.gd
func show_shop(next_wave: int):
    # 1. 暂停游戏
    Global.game_paused = true
    
    # 2. 生成商店物品
    ShopManager.generate_shop_items(3)
    
    # 3. 显示UI
    visible = true
    
    # 4. 更新金币显示
    update_gold_display()

func _on_next_wave_button_pressed():
    # 1. 隐藏商店
    visible = false
    
    # 2. 恢复游戏
    Global.game_paused = false
    
    # 3. 发出信号
    next_wave_requested.emit()
```


---

## 9. 升级系统

### 9.1 升级触发

打开宝箱时触发升级选择：

```gdscript
# chest_manager.gd
func _on_chest_opened(chest: ChestSimple):
    var tier = chest.get_tier()
    upgrade_ui.show_upgrades(tier)

# upgrade_selection_ui.gd
func show_upgrades(chest_tier: int):
    # 生成3个随机属性选项
    var options = UpgradeManager.generate_random_attributes(3, chest_tier)
    display_options(options)
```

### 9.2 属性配置

从 `config/item/upgrade_attributes.csv` 加载：

```csv
attribute_id,display_name,description,value_type,tier1_value,tier2_value,tier3_value,tier4_value,max_level
max_health,最大生命值,增加生命上限,flat,50,100,150,200,10
base_speed,移动速度,增加移动速度,flat,20,40,60,80,10
crit_chance,暴击率,增加暴击几率,percent,5,10,15,20,10
weapon_damage,武器伤害,增加武器伤害,percent,10,20,30,40,10
```

### 9.3 升级值计算

根据宝箱等级获取对应的升级值：

```gdscript
# Tier 1 宝箱 → tier1_value
# Tier 2 宝箱 → tier2_value
# Tier 3 宝箱 → tier3_value
# Tier 4 宝箱 → tier4_value

var value_key = "tier%d_value" % chest_tier
var upgrade_value = attr_config.get(value_key, 0)
```

### 9.4 属性应用

```gdscript
func apply_upgrade(attribute_id: String, chest_tier: int):
    # 1. 获取升级值
    var upgrade_value = get_upgrade_value(attribute_id, chest_tier)
    
    # 2. 更新等级和累计加成
    attribute_levels[attribute_id] += 1
    attribute_bonuses[attribute_id] += upgrade_value
    
    # 3. 应用到玩家
    _apply_to_player(attribute_id, upgrade_value, value_type)
```

### 9.5 属性类型

#### 9.5.1 直接修改属性

```gdscript
match attribute_id:
    "max_health":
        player.health_component.max_health += int(value)
        player.health_component.current_health += int(value)
    
    "max_energy":
        player.max_energy += int(value)
        player.energy += int(value)
    
    "base_speed":
        player.base_speed += value
        player.speed += value
    
    "dash_distance":
        player.dash_distance += value
    
    "dash_damage":
        player.dash_damage += int(value)
```

#### 9.5.2 存储加成（在战斗中应用）

```gdscript
# 这些属性存储在 attribute_bonuses 中
# 在相应逻辑中使用
match attribute_id:
    "weapon_damage":
        # 在武器攻击时应用
        var bonus = UpgradeManager.get_attribute_bonus("weapon_damage")
        final_damage *= (1.0 + bonus / 100.0)
    
    "crit_chance":
        # 在暴击判定时使用
        var bonus = UpgradeManager.get_attribute_bonus("crit_chance")
        crit_chance += bonus / 100.0
    
    "lifesteal":
        # 在造成伤害时应用
        var bonus = UpgradeManager.get_attribute_bonus("lifesteal")
        heal_amount = damage * (bonus / 100.0)
```

### 9.6 宝箱系统

#### 9.6.1 宝箱配置

从 `config/item/chest_config.csv` 加载：

```csv
chest_tier,display_name,icon_path,description
1,普通宝箱,res://...,提供少量属性提升
2,稀有宝箱,res://...,提供中等属性提升
3,史诗宝箱,res://...,提供大量属性提升
4,传说宝箱,res://...,提供巨额属性提升
```

#### 9.6.2 宝箱生成

从 `config/wave/wave_chest_config.csv` 加载：

```csv
wave_range_start,wave_range_end,chest_tier,spawn_chance
1,3,1,0.3
4,6,2,0.4
7,10,3,0.5
```

```gdscript
# chest_manager.gd
func try_spawn_chest(wave_index: int):
    var config = ConfigManager.get_wave_chest_config(wave_index)
    var chance = config.get("spawn_chance", 0.3)
    
    if randf() < chance:
        var tier = config.get("chest_tier", 1)
        spawn_chest(tier)
```


---

## 10. 道具系统

### 10.1 三层道具架构

#### 10.1.1 Tier 1: 属性道具

**直接修改玩家属性**

```gdscript
# item_effect_config.csv
item_id,item_name,item_tier,effect_type,effect_target,target_tags,effect_value
attr_hp_potion,生命药水,1,flat_add,stat,health,100
attr_speed_boots,疾风靴,1,flat_add,stat,speed,50
attr_damage_dagger,锋利匕首,1,flat_add,stat,damage,20
```

**应用逻辑**:

```gdscript
func _apply_tier1_item(item_data: Dictionary):
    var stat_name = item_data.get("target_tags", "")
    var value = float(item_data.get("effect_value", 0.0))
    
    match stat_name:
        "health":
            player.health += value
        "speed":
            player.speed += value
        "damage":
            player.damage += value
```

#### 10.1.2 Tier 2: 魔法道具（修改器）

**基于标签的数值修改**

```gdscript
# item_effect_config.csv
item_id,item_name,item_tier,effect_type,effect_target,target_tags,effect_value
magic_fire_heart,火焰之心,2,percent_add,modifier,fire,0.20
magic_aoe_amplifier,范围扩增器,2,percent_add,modifier,aoe,0.30
magic_damage_boost,通用伤害增幅,2,percent_add,modifier,damage,0.15
```

**应用逻辑**:

```gdscript
func _apply_tier2_item(item_data: Dictionary):
    var target_tags = item_data.get("target_tags", "").split(";")
    var effect_type = item_data.get("effect_type", "")
    var value = float(item_data.get("effect_value", 0.0))
    
    # 添加到修改器管理器
    ModifierManager.add_modifier(target_tags, effect_type, value)
```

**使用示例**:

```gdscript
# 技能伤害计算
var base_damage = 20.0
var skill_tags = ["damage", "fire", "aoe"]

# 应用修改器
var final_damage = ModifierManager.get_modified_value(base_damage, skill_tags)
# 如果装备了火焰之心（fire +20%）和范围扩增器（aoe +30%）
# final_damage = 20 * (1.0 + 0.20 + 0.30) = 30
```

#### 10.1.3 Tier 3: 圣物（羁绊标签）

**提供额外羁绊标签**

```gdscript
# item_effect_config.csv
item_id,item_name,item_tier,effect_type,effect_target,target_tags,effect_value
relic_martial,武道圣物,3,tag_add,bond,martial,1
relic_arcane,秘术圣物,3,tag_add,bond,arcane,1
relic_survivor,幸存者圣物,3,tag_add,bond,survivor,1
```

**应用逻辑**:

```gdscript
func _apply_tier3_item(item_data: Dictionary):
    # 只存储 item_id，实际标签由 BondManager 读取
    equipped_item_id = item_id

# 获取圣物提供的标签
func get_equipped_relic_tags() -> Dictionary:
    if equipped_item_id.is_empty():
        return {}
    
    var item_data = _load_item_config(equipped_item_id)
    var tag = item_data.get("target_tags", "")
    var count = int(item_data.get("effect_value", 1))
    
    return {tag: count}
```

### 10.2 仓库系统

#### 10.2.1 仓库数据结构

```gdscript
# warehouse_manager.gd
var warehouse_items: Dictionary = {}  # {slot_index: item_type}
var warehouse_capacity: int = 48

# 示例数据
warehouse_items = {
    0: 1,   # 生命药水
    1: 2,   # 疾风靴
    2: 4,   # 火焰之心
    3: 10   # 武道圣物
}
```

#### 10.2.2 仓库操作

```gdscript
# 添加道具
func add_item(item_type: int) -> bool:
    for i in range(warehouse_capacity):
        if not warehouse_items.has(i):
            warehouse_items[i] = item_type
            save_warehouse_data()
            return true
    return false  # 仓库已满

# 移除道具
func remove_item(slot_index: int) -> bool:
    if warehouse_items.has(slot_index):
        warehouse_items.erase(slot_index)
        _compact_warehouse()  # 整理仓库
        save_warehouse_data()
        return true
    return false

# 整理仓库（移除空位）
func _compact_warehouse():
    var items_list = []
    var sorted_slots = warehouse_items.keys()
    sorted_slots.sort()
    
    for slot in sorted_slots:
        items_list.append(warehouse_items[slot])
    
    warehouse_items.clear()
    for i in range(items_list.size()):
        warehouse_items[i] = items_list[i]
```

### 10.3 装备系统

#### 10.3.1 装备数据结构

```gdscript
# equipment_manager.gd
var equipped_items: Dictionary = {}  # {player_id: item_type}

# 示例数据
equipped_items = {
    "butcher": 4,   # 火焰之心
    "pyro": 10,     # 武道圣物
    "sapper": 0     # 未装备
}
```

#### 10.3.2 装备操作

```gdscript
# 装备道具
func equip_item(player_id: String, item_type: int, slot_index: int) -> bool:
    # 1. 卸下旧装备
    if equipped_items.has(player_id) and equipped_items[player_id] > 0:
        unequip_item(player_id)
    
    # 2. 从仓库移除
    if not WarehouseManager.remove_item(slot_index):
        return false
    
    # 3. 装备道具
    equipped_items[player_id] = item_type
    save_equipment_data()
    return true

# 卸下装备
func unequip_item(player_id: String) -> bool:
    if not equipped_items.has(player_id):
        return false
    
    var item_type = equipped_items[player_id]
    
    # 1. 添加回仓库
    if not WarehouseManager.add_item(item_type):
        return false
    
    # 2. 清除装备
    equipped_items[player_id] = 0
    save_equipment_data()
    return true
```

### 10.4 道具加载流程

```gdscript
# player_base.gd
func _ready():
    # 1. 加载配置
    _load_config_from_csv()
    
    # 2. 装备道具
    _load_and_equip_item()
    
    # 3. 加载武器
    _load_weapons_from_config()

func _load_and_equip_item():
    # 从 EquipmentManager 获取装备的道具类型
    var item_type = EquipmentManager.get_equipped_item(player_id)
    if item_type <= 0:
        return
    
    # 转换为 item_id
    var item_id = _get_item_id_from_type(item_type)
    if item_id != "":
        equip_item(item_id)
```


---

## 11. 羁绊系统

### 11.1 羁绊概述

羁绊系统是游戏的核心数值系统，通过队伍组合激活强力被动效果。

#### 11.1.1 羁绊类型

- **起源 (Origin)**: 角色的种族/背景
- **精通 (Mastery)**: 角色的战斗风格
- **战术 (Tactic)**: 角色的战术定位

#### 11.1.2 羁绊标签示例

| 羁绊ID | 类型 | 显示名称 | 效果 |
|--------|------|---------|------|
| `martial` | 精通 | 武道世家 | 暴击率+5%/10%/15% |
| `arcane` | 精通 | 秘术大师 | 技能伤害+10%/20%/30% |
| `survivor` | 起源 | 幸存者 | 生命恢复+1/2/3 |
| `destruction` | 战术 | 毁灭 | 伤害+10%/20%/30% |
| `velocity` | 战术 | 速度 | 移动速度+10%/20%/30% |
| `control` | 战术 | 控制 | 技能冷却-10%/20%/30% |

### 11.2 羁绊配置

从 `config/player/bond_config.csv` 加载：

```csv
bond_id,bond_type,level,required_count,effect_type,effect_param,effect_value,icon_path_index,display_name,description
martial,mastery,1,2,stat_mod,crit_chance,5,1,武道世家,暴击率+5%
martial,mastery,2,4,stat_mod,crit_chance,10,1,武道世家,暴击率+10%
martial,mastery,3,6,stat_mod,crit_chance,15,1,武道世家,暴击率+15%
```

### 11.3 羁绊计算流程

```gdscript
# bond_manager.gd
func recalculate_active_bonds(team_player_ids: Array):
    # 1. 清空当前数据
    current_bond_counts.clear()
    active_bonds.clear()
    
    # 2. 统计所有羁绊标签
    for player_id in team_player_ids:
        var config = ConfigManager.get_player_config(player_id)
        var tags = [
            config.get("origin_tag", ""),
            config.get("mastery_tag", ""),
            config.get("tactic_tag", "")
        ]
        for tag in tags:
            if tag != "":
                current_bond_counts[tag] = current_bond_counts.get(tag, 0) + 1
    
    # 3. 添加临时标签（大招/技能）
    for tag in temp_bonus_tags.keys():
        current_bond_counts[tag] = current_bond_counts.get(tag, 0) + temp_bonus_tags[tag]
    
    # 4. 检查每个羁绊的激活状态
    for bond_id in bond_configs.keys():
        var count = current_bond_counts.get(bond_id, 0)
        if count > 0:
            var activated_level = _get_activated_level(bond_id, count)
            if activated_level > 0:
                _activate_bond(bond_id, activated_level)
    
    # 5. 发出信号
    bonds_recalculated.emit(active_bonds)
```

### 11.4 羁绊激活等级

```gdscript
func _get_activated_level(bond_id: String, current_count: int) -> int:
    var levels = bond_configs[bond_id].levels
    var activated_level = 0
    
    # 变身过载模式：只要有1个标签就激活最高等级
    if is_overdrive_mode and current_count >= 1:
        return levels[levels.size() - 1].level
    
    # 正常模式：检查满足条件的最高等级
    for level_data in levels:
        if current_count >= level_data.required_count:
            activated_level = level_data.level
        else:
            break
    
    return activated_level
```

### 11.5 羁绊效果类型

#### 11.5.1 属性修改 (stat_mod)

```gdscript
# 应用到玩家属性
func apply_stat_modifiers(player_stats: Dictionary) -> Dictionary:
    for bond_id in active_bonds.keys():
        for effect in bond_data.effects:
            if effect.effect_type == "stat_mod":
                _apply_stat_modifier(stats, effect.effect_param, effect.effect_value)
    return stats

# 支持的属性
match param:
    "crit_chance":
        stats["crit_chance"] += value
    "crit_damage":
        stats["crit_damage"] += value
    "energy_regen":
        stats["energy_regen"] += value
    "cooldown_reduction":
        stats["cooldown_reduction"] += value
    "max_health":
        stats["max_health"] += value
    "speed":
        stats["speed"] += value
```

#### 11.5.2 机制效果 (mechanic)

```gdscript
# 特殊机制（需要在代码中实现）
func get_active_mechanics() -> Array:
    var mechanics = []
    for bond_id in active_bonds.keys():
        for effect in bond_data.effects:
            if effect.effect_type == "mechanic":
                mechanics.append({
                    "bond_id": bond_id,
                    "effect_param": effect.effect_param,
                    "effect_value": effect.effect_value
                })
    return mechanics

# 检查机制是否激活
if BondManager.has_mechanic("stat_share"):
    # 实现属性共享逻辑
    pass
```

### 11.6 临时羁绊标签

大招可以临时添加羁绊标签：

```gdscript
# 大招激活时
func activate():
    if bonus_bond_tag != "":
        BondManager.add_temp_tag(bonus_bond_tag)
    
    await get_tree().create_timer(duration).timeout
    
    if bonus_bond_tag != "":
        BondManager.remove_temp_tag(bonus_bond_tag)

# 临时标签管理
func add_temp_tag(tag: String):
    temp_bonus_tags[tag] = temp_bonus_tags.get(tag, 0) + 1
    _recalculate_with_current_team()

func remove_temp_tag(tag: String):
    temp_bonus_tags[tag] -= 1
    if temp_bonus_tags[tag] <= 0:
        temp_bonus_tags.erase(tag)
    _recalculate_with_current_team()
```

### 11.7 变身过载模式

F键大招激活时，所有羁绊升至最高等级：

```gdscript
# 启用过载模式
BondManager.set_overdrive_mode(true)

# 在 _get_activated_level() 中
if is_overdrive_mode and current_count >= 1:
    return levels[levels.size() - 1].level  # 返回最高等级
```

### 11.8 羁绊UI

#### 11.8.1 BondHUD 显示

```gdscript
# bond_hud.gd
func _on_bonds_recalculated(active_bonds: Dictionary):
    # 清空旧图标
    for child in icon_container.get_children():
        child.queue_free()
    
    # 创建新图标
    for bond_id in active_bonds.keys():
        var bond_data = active_bonds[bond_id]
        var icon = bond_icon_scene.instantiate()
        icon.setup(bond_id, bond_data.level, bond_data.display_name)
        icon_container.add_child(icon)
```

#### 11.8.2 悬浮提示

```gdscript
func get_bond_tooltip_text(bond_id: String, current_count: int) -> String:
    var tooltip = "【%s】(当前: %d)\n" % [display_name, current_count]
    
    for level_data in levels:
        var is_active = current_count >= level_data.required_count
        var status = "[√]" if is_active else "[ ]"
        tooltip += "%s (%d) %s\n" % [status, level_data.required_count, level_data.description]
    
    return tooltip
```


---

## 12. 系统架构

### 12.1 核心循环

```
Arena (场景根节点)
  ├─ Player (当前激活角色)
  ├─ Spawner (敌人生成器)
  ├─ ChestManager (宝箱管理器)
  ├─ UpgradeSelectionUI (升级选择UI)
  ├─ ShopPanel (商店面板)
  ├─ GlobalHUD (全局HUD)
  └─ SquadHUD (小队HUD)
```

### 12.2 Autoload 单例

游戏使用多个全局单例管理系统：

| 单例名称 | 职责 |
|---------|------|
| `Global` | 全局状态、玩家引用、音效、角色切换 |
| `ConfigManager` | CSV配置加载和缓存 |
| `DataManager` | 金币、存档、持久化数据 |
| `UpgradeManager` | 属性升级系统 |
| `PlayerFactory` | 角色实例化工厂 |
| `SkillEffectManager` | 技能效果管理（未使用） |
| `WarehouseManager` | 仓库系统 |
| `EquipmentManager` | 装备系统 |
| `BondManager` | 羁绊系统 |
| `ModifierManager` | 修改器系统 |
| `ShopManager` | 商店系统 |
| `EliteConfigManager` | 精英敌人配置 |

### 12.3 对象池

#### 12.3.1 音效对象池

```gdscript
# Global.gd
const POOL_SIZE = 32
var pool: Array[AudioStreamPlayer] = []
var next_idx = 0

func _ready():
    for i in range(POOL_SIZE):
        var player = AudioStreamPlayer.new()
        add_child(player)
        pool.append(player)

func play_sfx(stream: AudioStream, min_pitch: float = 0.8, max_pitch: float = 1.2):
    var player = pool[next_idx]
    next_idx = (next_idx + 1) % POOL_SIZE
    
    player.stream = stream
    player.pitch_scale = randf_range(min_pitch, max_pitch)
    player.play()
```

### 12.4 信号系统

#### 12.4.1 全局信号

```gdscript
# Global.gd
signal on_create_block_text(unit: Node2D)
signal on_create_damage_text(unit: Node2D, hitbox: HitboxComponent)
signal on_camera_shake(intensity: float, duration: float)
signal on_directional_shake(direction: Vector2, strength: float)
signal on_player_switch_requested(player_id: String)
signal on_session_xp_changed(current: int)
signal on_active_character_changed(index: int)
signal on_switch_rejected(index: int, reason: String)
signal on_squad_state_changed(index: int, state: Dictionary)
```

#### 12.4.2 玩家信号

```gdscript
# PlayerBase
signal energy_changed(current, max_val)
signal armor_changed(current)
signal xp_changed(current)
signal gold_changed(current)
```

#### 12.4.3 波次信号

```gdscript
# Spawner
signal wave_completed(wave_number: int)
```

#### 12.4.4 商店信号

```gdscript
# ShopManager
signal shop_items_generated(items: Array)
signal item_purchased(item_id: String, index: int)
signal shop_rerolled()
signal purchase_failed(reason: String)
```

#### 12.4.5 羁绊信号

```gdscript
# BondManager
signal bonds_recalculated(active_bonds: Dictionary)
signal stat_modifiers_changed()
```

### 12.5 组 (Groups)

游戏使用 Godot 的 Group 系统进行对象管理：

```gdscript
# 玩家组
add_to_group("player")

# 敌人组
add_to_group("enemies")

# 投射物组
add_to_group("projectiles")

# 物品组
add_to_group("items")

# 宝箱组
add_to_group("chests")

# 查询示例
var all_enemies = get_tree().get_nodes_in_group("enemies")
for enemy in all_enemies:
    enemy.take_damage(100)
```

### 12.6 碰撞层

从 `project.godot` 配置：

```
Layer 1: Player
Layer 2: Enemy
Layer 3: HitboxEnemy
Layer 4: HurtboxEnemy
Layer 5: HitboxPlayer
Layer 6: HurtboxPlayer
```

### 12.7 场景结构

#### 12.7.1 玩家场景

```
PlayerGeneric (CharacterBody2D)
  ├─ CollisionShape2D
  ├─ Visuals (Node2D)
  │   └─ Sprite2D
  ├─ HealthComponent
  ├─ HurtboxComponent (Area2D)
  ├─ WeaponContainer
  ├─ SkillManager
  └─ AnimationPlayer
```

#### 12.7.2 敌人场景

```
Enemy (CharacterBody2D)
  ├─ CollisionShape2D
  ├─ Visuals (Node2D)
  │   └─ Sprite2D
  ├─ HealthComponent
  ├─ HurtboxComponent (Area2D)
  ├─ Hitbox (Area2D)
  ├─ VisionArea (Area2D)
  ├─ KnockbackTimer
  └─ AnimationPlayer
```

#### 12.7.3 武器场景

```
Weapon (Node2D)
  ├─ Sprite2D
  ├─ FirePos (Marker2D)
  ├─ Hitbox (Area2D)
  │   └─ CollisionShape2D
  └─ AttackTimer
```


---

## 13. 数据流

### 13.1 存档系统

#### 13.1.1 存档文件

```
user://player_save.json        # 金币和升级数据
user://warehouse_data.json     # 仓库数据
user://equipment_data.json     # 装备数据
```

#### 13.1.2 存档结构

```json
// player_save.json
{
  "total_gold": 1000,
  "upgrades": {
    "butcher": {
      "hp_level": 3,
      "max_energy_level": 2,
      "base_speed_level": 1
    }
  }
}

// warehouse_data.json
{
  "0": 1,   // 槽位0: 道具类型1
  "1": 2,   // 槽位1: 道具类型2
  "2": 4    // 槽位2: 道具类型4
}

// equipment_data.json
{
  "equipped_items": {
    "butcher": 4,   // 屠夫装备道具类型4
    "pyro": 10,     // 烈焰法师装备道具类型10
    "sapper": 0     // 爆破手未装备
  }
}
```

### 13.2 配置加载流程

```
游戏启动
  ↓
ConfigManager._ready()
  ↓
加载所有CSV配置
  - player_config.csv
  - player_visual.csv
  - player_weapons.csv
  - player_skill_bindings.csv
  - skill_params.csv
  - enemy_config.csv
  - enemy_visual.csv
  - weapon_config.csv
  - weapon_stats_config.csv
  - wave_config.csv
  - wave_units_config.csv
  - upgrade_attributes.csv
  - chest_config.csv
  - shop_item_config.csv
  - bond_config.csv
  - item_effect_config.csv
  ↓
缓存到内存（Dictionary）
  ↓
提供快速访问接口
```

### 13.3 角色创建流程

```
选择界面
  ↓
Global.selected_player_ids = ["butcher", "pyro", "sapper"]
Global.selected_player_weapons = {"butcher": "punch", "pyro": "laser"}
  ↓
进入Arena
  ↓
Arena._init_player_from_selection()
  ↓
PlayerFactory.create_player("butcher")
  ↓
1. 加载通用场景 (player_generic.tscn)
2. 设置 player_id
3. 加载角色特定脚本 (player_butcher.gd)
4. 实例化场景
  ↓
PlayerBase._ready()
  ↓
1. _load_config_from_csv()
2. _load_sprite_from_csv()
3. _load_and_equip_item()
4. _load_weapons_from_config()
5. _load_ultimate_skill()
  ↓
Global.restore_player_state(player)
  ↓
角色就绪
```

### 13.4 战斗数据流

```
玩家攻击
  ↓
Weapon.attack()
  ↓
生成 Hitbox
  - damage = weapon.damage + player.damage
  - 应用修改器: ModifierManager.get_modified_value(damage, tags)
  - 暴击判定: if randf() < crit_chance
  ↓
Hitbox 碰撞检测
  ↓
Enemy.HurtboxComponent.on_damaged(hitbox)
  ↓
Enemy.take_damage(hitbox.damage)
  - 护甲减伤
  - 应用击退
  - 触发反馈（顿帧、震屏、飘字）
  ↓
Enemy.health_component.take_damage(final_damage)
  ↓
如果 health <= 0
  ↓
Enemy.destroy_enemy()
  - 给玩家奖励（能量、经验、金币）
  - 播放死亡音效
  - 生成死亡特效
  - 从场景移除
```

### 13.5 升级数据流

```
打开宝箱
  ↓
ChestManager.chest_opened.emit(chest)
  ↓
Arena._on_chest_opened(chest)
  ↓
UpgradeSelectionUI.show_upgrades(chest_tier)
  ↓
UpgradeManager.generate_random_attributes(3, chest_tier)
  - 从 upgrade_attributes.csv 读取配置
  - 筛选未达到最大等级的属性
  - 随机选择3个
  - 根据宝箱等级获取升级值
  ↓
玩家选择属性
  ↓
UpgradeManager.apply_upgrade(attribute_id, chest_tier)
  ↓
1. 更新等级: attribute_levels[attribute_id] += 1
2. 更新加成: attribute_bonuses[attribute_id] += upgrade_value
3. 应用到玩家: _apply_to_player(attribute_id, value, type)
  ↓
玩家属性更新
```

### 13.6 商店数据流

```
波次结束
  ↓
Spawner.wave_completed.emit(wave_index)
  ↓
Arena._on_wave_completed(wave_index)
  ↓
ShopPanel.show_shop(wave_index + 1)
  ↓
ShopManager.generate_shop_items(3)
  - 从 shop_item_config.csv 读取配置
  - 根据权重随机抽取3个道具
  - 允许重复
  ↓
玩家购买道具
  ↓
ShopManager.purchase_item(index)
  ↓
1. 检查金币: DataManager.get_total_gold()
2. 扣除金币: DataManager.add_gold(-price)
3. 应用效果: _apply_item_effects(item)
  - Tier 1: 直接修改属性
  - Tier 2: 添加修改器
  - Tier 3: 注册圣物
4. 标记已购买: purchased_indices.append(index)
  ↓
玩家点击"下一波"
  ↓
ShopPanel.next_wave_requested.emit()
  ↓
Arena._on_shop_next_wave_requested()
  ↓
Spawner.resume_spawning()
  ↓
Spawner.start_next_wave()
```

### 13.7 羁绊数据流

```
进入Arena
  ↓
Arena._init_bond_hud()
  ↓
BondManager.recalculate_active_bonds(Global.selected_player_ids)
  ↓
1. 统计羁绊标签
  - 从 player_config.csv 读取 origin_tag, mastery_tag, tactic_tag
  - 累加到 current_bond_counts
2. 添加临时标签（大招/技能）
3. 添加圣物标签（Tier 3道具）
4. 检查每个羁绊的激活状态
  - 从 bond_config.csv 读取配置
  - 根据标签数量判断激活等级
5. 收集激活羁绊的效果
  ↓
BondManager.bonds_recalculated.emit(active_bonds)
  ↓
BondHUD._on_bonds_recalculated(active_bonds)
  - 更新UI显示
  ↓
应用羁绊效果
  - stat_mod: 直接修改玩家属性
  - mechanic: 在代码中实现特殊机制
```


---

## 14. 细节备忘录

### 14.1 Hardcoded Values（硬编码参数）

#### 14.1.1 手感参数

```gdscript
# 击退衰减（极快）
external_force_decay: float = 50.0

# 顿帧参数
freeze_duration: float = 0.02 ~ 0.08  # 根据伤害动态调整
time_scale: float = 0.05              # 接近静止

# 震屏参数
shake_intensity: float = 2.0 ~ 10.0   # 根据伤害动态调整
shake_duration: float = 0.08 ~ 0.25

# 护甲减伤
reduction_per_armor: float = 0.2      # 每层护甲减伤20%

# 玩家击退缩放
knockback_scale: float = 0.3          # 玩家受击退效果减少70%
```

#### 14.1.2 音效参数

```gdscript
# 敌人死亡音效
pitch_range: 0.9 ~ 1.4
volume: -10.0 dB

# 闭环绞杀音效
pitch_range: 0.6 ~ 0.8
volume: 5.0 dB

# 玩家死亡音效
pitch: 1.0 (固定)
volume: 5.0 dB

# 玩家冲刺音效
pitch: 1.0 (固定)
volume: -2.0 dB
```

#### 14.1.3 UI参数

```gdscript
# 飘字随机偏移
random_offset: Vector2(randf_range(-40, 40), randf_range(-40, 40))

# 能量槽位置（已禁用，改用SquadHUD）
# position: Vector2(20, 20)

# 商店刷新费用
REROLL_COST: int = 50
```

### 14.2 特殊Tag/Group

#### 14.2.1 技能标签

```gdscript
# 伤害类型
["damage"]              # 通用伤害
["damage", "fire"]      # 火焰伤害
["damage", "explosion"] # 爆炸伤害
["damage", "physical"]  # 物理伤害

# 效果类型
["aoe"]                 # 范围伤害
["dot"]                 # 持续伤害
["control"]             # 控制效果
["summon"]              # 召唤物

# 组合示例
["damage", "fire", "aoe"]           # 火焰范围伤害
["damage", "explosion", "aoe"]      # 爆炸范围伤害
["damage", "physical", "melee"]     # 物理近战伤害
```

#### 14.2.2 羁绊标签

```gdscript
# 起源标签
"survivor"      # 幸存者
"noble"         # 贵族
"outlaw"        # 亡命徒

# 精通标签
"martial"       # 武道
"arcane"        # 秘术
"tech"          # 科技

# 战术标签
"destruction"   # 毁灭
"velocity"      # 速度
"control"       # 控制
"support"       # 支援
```

### 14.3 性能优化

#### 14.3.1 对象池

```gdscript
# 音效对象池
POOL_SIZE = 32
pool: Array[AudioStreamPlayer]

# 避免频繁创建销毁音频节点
# 使用循环索引复用
```

#### 14.3.2 延迟操作

```gdscript
# 使用 call_deferred 避免物理帧冲突
collision_shape.set_deferred("disabled", true)
get_tree().current_scene.call_deferred("add_child", vfx)

# 使用 await 等待场景树准备
await get_tree().process_frame
```

#### 14.3.3 配置缓存

```gdscript
# ConfigManager 在启动时加载所有CSV
# 缓存到内存中的 Dictionary
# 避免重复读取文件
```

### 14.4 调试工具

#### 14.4.1 调试开关

```gdscript
# 使用 OS.is_debug_build() 控制调试输出
if OS.is_debug_build():
    print("[ModifierManager] 数值计算: base=%.2f, final=%.2f" % [base, final])
```

#### 14.4.2 测试功能

```gdscript
# L键跳过当前波次,测试用
if Input.is_physical_key_pressed(KEY_L):
    go_to_next_wave()

# 初始化默认测试道具
func _init_default_items():
    warehouse_items[0] = 1   # Tier 1
    warehouse_items[3] = 4   # Tier 2
    warehouse_items[9] = 10  # Tier 3
```

### 14.5 已知问题和限制

#### 14.5.1 角色切换

- **技能效果保留**: 切换角色后，旧角色的技能效果（火海、地雷）会保留在场景中
- **状态独立**: 每个角色有独立的血量、能量、护甲
- **未激活角色恢复**: 未激活的角色会自动恢复能量（如果配置了 health_regen 也会恢复血量）

#### 14.5.2 羁绊系统

- **圣物标签**: Tier 3 圣物提供的羁绊标签功能已实现，但需要在 BondManager 中手动读取
- **变身过载**: F键大招激活时，所有羁绊升至最高等级（只要有1个标签）

#### 14.5.3 商店系统

- **物品重复**: 商店可能生成重复的道具（这是设计特性）
- **购买限制**: 每个道具只能购买一次（同一波次）
- **刷新费用**: 固定50金币

#### 14.5.4 波次系统

- **最大波次**: 10波（从 game_config.csv 配置）
- **敌人增强**: 每波敌人血量+10，伤害+2
- **精英敌人**: 支持多阶段进化（最多3阶段）

### 14.6 未实现功能

- **手柄支持**: 未实现
- **副武器攻击**: 鼠标右键未绑定功能
- **多人模式**: 单人游戏
- **成就系统**: 未实现
- **排行榜**: 未实现
- **音量设置**: 未实现
- **画质设置**: 未实现

### 14.7 CSV配置文件列表

```
config/
├── system/
│   ├── game_config.csv          # 游戏全局设置
│   ├── camera_config.csv        # 摄像机设置
│   ├── map_config.csv           # 地图设置
│   ├── input_config.csv         # 输入映射
│   └── sound_config.csv         # 音效配置
├── player/
│   ├── player_config.csv        # 玩家基础属性
│   ├── player_visual.csv        # 玩家视觉配置
│   ├── player_weapons.csv       # 玩家武器配置
│   ├── player_skill_bindings.csv # 技能绑定
│   ├── player_available_weapons.csv # 可用武器类型
│   ├── skill_params.csv         # 技能参数
│   ├── ult_config.csv           # 大招配置
│   ├── bond_config.csv          # 羁绊配置
│   └── attribute_upgrade.csv    # 属性升级配置
├── enemy/
│   ├── enemy_config.csv         # 敌人基础属性
│   ├── enemy_visual.csv         # 敌人视觉配置
│   ├── enemy_weapons.csv        # 敌人武器配置
│   └── elite_config.csv         # 精英敌人配置
├── weapon/
│   ├── weapon_config.csv        # 武器基础配置
│   └── weapon_stats_config.csv  # 武器详细属性
├── wave/
│   ├── wave_config.csv          # 波次配置
│   ├── wave_units_config.csv    # 波次单位配置
│   └── wave_chest_config.csv    # 波次宝箱配置
└── item/
    ├── item_config.csv          # 道具基础配置
    ├── item_effect_config.csv   # 道具效果配置
    ├── shop_item_config.csv     # 商店道具配置
    ├── chest_config.csv         # 宝箱配置
    └── upgrade_attributes.csv   # 升级属性配置
```

---

## 15. 总结

这份文档详细记录了《PolyLash》游戏的所有核心系统和机制。通过阅读这份文档，你应该能够：

1. **理解游戏玩法**: 角色切换、羁绊系统、波次生存
2. **掌握操控方式**: WASD移动、QEF技能、Tab/1-2-3切换角色
3. **了解战斗机制**: 伤害计算、击退、顿帧、震屏
4. **理解技能系统**: Q/E技能、鼠标左键冲刺、F键大招
5. **掌握敌人AI**: 追逐、冲锋、特殊能力
6. **理解波次系统**: 10波生存、敌人增强、精英敌人
7. **掌握商店系统**: 波次间购买道具、刷新功能
8. **理解升级系统**: 宝箱升级、属性提升
9. **掌握道具系统**: 三层道具架构、仓库、装备
10. **理解羁绊系统**: 队伍组合、标签统计、效果激活
11. **掌握系统架构**: Autoload单例、信号系统、数据流
12. **了解实现细节**: 硬编码参数、性能优化、调试工具

**祝你游戏愉快！** 🎮

