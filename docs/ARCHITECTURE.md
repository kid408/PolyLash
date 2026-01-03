# 系统架构文档

本文档详细介绍PolyLash的技术架构、设计模式和系统组织。

---

## 目录

- [架构概述](#架构概述)
- [分层架构](#分层架构)
- [核心系统](#核心系统)
- [设计模式](#设计模式)
- [数据流](#数据流)
- [扩展性设计](#扩展性设计)

---

## 架构概述

### 设计理念

PolyLash采用**数据驱动**和**模块化**的架构设计：

1. **数据驱动**: 所有游戏数据通过CSV配置，代码与数据分离
2. **模块化**: 系统高度解耦，每个模块职责单一
3. **组件化**: 使用组件模式实现可复用逻辑
4. **继承体系**: 合理使用继承减少代码重复

### 架构优势

- **易于调整**: 修改CSV即可调整游戏平衡，无需改代码
- **易于扩展**: 添加新内容只需继承基类和添加配置
- **易于维护**: 模块独立，修改影响范围小
- **易于测试**: 系统解耦，便于单元测试

---

## 分层架构

### 四层架构模型

```
┌─────────────────────────────────────────────────────────┐
│                    游戏场景层 (Scenes)                   │
│  - Arena (竞技场)                                        │
│  - UI (用户界面)                                         │
│  - Players (玩家角色)                                    │
│  - Enemies (敌人)                                        │
│  - Weapons (武器)                                        │
│  - Skills (技能)                                         │
│  - Projectiles (投射物)                                  │
└────────────────────┬────────────────────────────────────┘
                     │ 使用
┌────────────────────▼────────────────────────────────────┐
│                  系统管理层 (Managers)                   │
│  - SkillManager (技能管理)                               │
│  - UpgradeManager (升级管理)                             │
│  - Spawner (生成管理)                                    │
│  - WaveManager (波次管理)                                │
└────────────────────┬────────────────────────────────────┘
                     │ 依赖
┌────────────────────▼────────────────────────────────────┐
│                 全局单例层 (Autoloads)                   │
│  - ConfigManager (配置管理) [核心]                       │
│  - Global (全局状态)                                     │
│  - SoundManager (音效管理)                               │
└────────────────────┬────────────────────────────────────┘
                     │ 加载
┌────────────────────▼────────────────────────────────────┐
│                  配置数据层 (CSV Files)                  │
│  - system/ (系统配置)                                    │
│  - player/ (玩家配置)                                    │
│  - enemy/ (敌人配置)                                     │
│  - weapon/ (武器配置)                                    │
│  - wave/ (波次配置)                                      │
│  - item/ (物品配置)                                      │
└─────────────────────────────────────────────────────────┘
```

### 层次职责

#### 1. 配置数据层
- **职责**: 存储所有游戏数据
- **格式**: CSV文件
- **特点**: 纯数据，无逻辑

#### 2. 全局单例层
- **职责**: 提供全局访问的服务
- **生命周期**: 游戏启动时创建，全局唯一
- **特点**: 无状态或全局状态

#### 3. 系统管理层
- **职责**: 管理特定领域的逻辑
- **生命周期**: 随场景创建和销毁
- **特点**: 有状态，管理子对象

#### 4. 游戏场景层
- **职责**: 实现具体的游戏对象
- **生命周期**: 动态创建和销毁
- **特点**: 有状态，响应事件

---

## 核心系统

### 1. 配置管理系统 (ConfigManager)

#### 职责
- 启动时加载所有CSV配置
- 将配置数据缓存到内存
- 提供便捷的访问接口

#### 架构
```
ConfigManager (Autoload)
├── 配置缓存 (Dictionary)
│   ├── player_configs
│   ├── enemy_configs
│   ├── weapon_configs
│   ├── skill_params
│   └── ...
├── 加载方法
│   ├── load_csv_as_dict()
│   ├── load_csv_as_single()
│   └── load_csv_as_array()
└── 访问方法
    ├── get_player_config()
    ├── get_skill_params()
    └── ...
```

#### 关键特性
- **一次加载**: 启动时加载，避免运行时IO
- **内存缓存**: 所有配置存储在内存，快速访问
- **类型转换**: 自动将字符串转换为数值类型
- **容错处理**: 配置不存在时返回空字典

#### 使用示例
```gdscript
# 获取玩家配置
var config = ConfigManager.get_player_config("player_herder")
var health = config.get("health", 100)

# 获取技能参数
var params = ConfigManager.get_skill_params("skill_dash")
var damage = params.get("damage", 0)
```

---

### 2. 技能系统 (SkillManager + SkillBase)

#### 架构
```
SkillManager (管理器)
├── skill_slots: Dictionary
│   ├── "q": SkillBase
│   ├── "e": SkillBase
│   ├── "lmb": SkillBase
│   └── "rmb": SkillBase
├── load_skills_from_config()
├── execute_skill()
├── charge_skill()
└── release_skill()

SkillBase (基类)
├── 通用属性
│   ├── skill_owner
│   ├── skill_id
│   ├── energy_cost
│   └── cooldown_time
├── 虚函数接口
│   ├── execute()
│   ├── charge()
│   └── release()
└── 通用功能
    ├── can_execute()
    ├── consume_energy()
    └── start_cooldown()
```

#### 工作流程
1. **加载阶段**:
   - SkillManager从ConfigManager获取技能绑定
   - 根据skill_id加载技能脚本
   - 创建技能实例并设置参数
   - 添加到对应槽位

2. **执行阶段**:
   - 玩家按键触发
   - SkillManager调用对应槽位的技能
   - 技能检查can_execute()
   - 执行技能逻辑
   - 启动冷却

3. **更新阶段**:
   - 技能基类更新冷却计时器
   - 冷却结束时触发回调

#### 扩展性
- **添加新技能**: 继承SkillBase，实现虚函数
- **修改参数**: 修改skill_params.csv
- **更换技能**: 修改player_skill_bindings.csv

---

### 3. 组件系统 (Components)

#### 设计理念
使用**组合优于继承**的原则，将通用逻辑封装为组件。

#### 核心组件

##### HealthComponent (生命值组件)
```gdscript
HealthComponent
├── max_health: float
├── current_health: float
├── take_damage(amount: float)
├── heal(amount: float)
└── signals
    ├── health_changed
    ├── died
    └── damage_taken
```

##### HitboxComponent (攻击判定组件)
```gdscript
HitboxComponent
├── damage: float
├── knockback: float
├── owner_type: String
└── _on_area_entered(area: Area2D)
```

##### HurtboxComponent (受击判定组件)
```gdscript
HurtboxComponent
├── health_component: HealthComponent
├── owner_type: String
└── take_damage(amount: float, knockback: Vector2)
```

#### 使用示例
```gdscript
# 在玩家场景中
@onready var health_component = $HealthComponent
@onready var hurtbox = $HurtboxComponent

func _ready():
    hurtbox.health_component = health_component
    health_component.health_changed.connect(_on_health_changed)
```

---

### 4. 升级系统 (UpgradeManager)

#### 职责
- 管理玩家属性升级
- 应用升级效果到玩家
- 支持flat和percent两种数值类型

#### 架构
```
UpgradeManager (Autoload)
├── player_upgrades: Dictionary
├── apply_upgrade(attribute_id, tier)
├── get_upgrade_value(attribute_id, tier)
└── _apply_to_player(attribute_id, value, value_type)
```

#### 数值类型
- **flat**: 固定数值增加（如 +10 生命值）
- **percent**: 百分比增加（如 +5% 武器伤害）

#### 应用逻辑
```gdscript
func _apply_to_player(attribute_id: String, value: float, value_type: String):
    match attribute_id:
        "max_health":
            if value_type == "flat":
                player.max_health += value
            else:
                player.max_health *= (1 + value)
        "weapon_damage":
            if value_type == "percent":
                player.weapon_damage_multiplier += value
```

---

## 设计模式

### 1. 单例模式 (Singleton)

**应用**: ConfigManager, Global, UpgradeManager

**实现**: Godot的Autoload机制

**优点**:
- 全局唯一实例
- 全局访问点
- 延迟初始化

**示例**:
```gdscript
# 在project.godot中配置
[autoload]
ConfigManager="*res://autoloads/config_manager.gd"

# 在任何脚本中访问
var config = ConfigManager.get_player_config("player_herder")
```

---

### 2. 工厂模式 (Factory)

**应用**: 技能创建、敌人生成

**实现**: SkillManager, Spawner

**优点**:
- 封装创建逻辑
- 统一创建接口
- 易于扩展

**示例**:
```gdscript
# SkillManager作为技能工厂
func _load_skill_to_slot(slot: String, skill_id: String) -> bool:
    var skill_script_path = "res://scenes/skills/players/%s.gd" % skill_id
    var skill_script = load(skill_script_path)
    var skill: SkillBase = skill_script.new()
    # 配置技能...
    return true
```

---

### 3. 观察者模式 (Observer)

**应用**: 事件系统、信号机制

**实现**: Godot的Signal系统

**优点**:
- 解耦发送者和接收者
- 支持一对多通知
- 动态订阅

**示例**:
```gdscript
# 定义信号
signal health_changed(new_health: float, max_health: float)

# 发送信号
health_changed.emit(current_health, max_health)

# 订阅信号
health_component.health_changed.connect(_on_health_changed)
```

---

### 4. 组件模式 (Component)

**应用**: HealthComponent, HitboxComponent, HurtboxComponent

**实现**: 独立的Node组件

**优点**:
- 组合优于继承
- 可复用逻辑
- 灵活组合

**示例**:
```gdscript
# 玩家场景结构
Player (CharacterBody2D)
├── Sprite2D
├── CollisionShape2D
├── HealthComponent
├── HurtboxComponent (Area2D)
└── HitboxComponent (Area2D)
```

---

### 5. 策略模式 (Strategy)

**应用**: 敌人AI、技能行为

**实现**: 虚函数接口

**优点**:
- 算法可替换
- 易于扩展
- 符合开闭原则

**示例**:
```gdscript
# SkillBase定义接口
func execute() -> void:
    pass  # 子类实现

# 不同技能实现不同策略
class SkillDash extends SkillBase:
    func execute() -> void:
        # 冲刺逻辑
        pass

class SkillFireball extends SkillBase:
    func execute() -> void:
        # 火球逻辑
        pass
```

---

## 数据流

### 配置加载流程

```
游戏启动
    ↓
ConfigManager._ready()
    ↓
load_all_configs()
    ↓
┌─────────────────────────────────┐
│ 加载各类CSV配置                  │
│ - player_configs                │
│ - enemy_configs                 │
│ - weapon_configs                │
│ - skill_params                  │
│ - ...                           │
└─────────────────────────────────┘
    ↓
配置缓存到内存 (Dictionary)
    ↓
游戏场景可以访问配置
```

### 技能执行流程

```
玩家按键 (Q/E/LMB/RMB)
    ↓
PlayerBase._handle_input()
    ↓
SkillManager.execute_skill(slot)
    ↓
获取槽位技能: skill_slots[slot]
    ↓
检查: skill.can_execute()
    ├─ 检查冷却
    └─ 检查能量
    ↓
执行: skill.execute()
    ├─ 消耗能量
    ├─ 执行技能逻辑
    └─ 启动冷却
    ↓
SkillBase._process(delta)
    └─ 更新冷却计时器
```

### 伤害计算流程

```
攻击者发起攻击
    ↓
HitboxComponent检测碰撞
    ↓
_on_area_entered(hurtbox)
    ↓
检查owner_type (避免友伤)
    ↓
hurtbox.take_damage(damage, knockback)
    ↓
HealthComponent.take_damage(amount)
    ↓
current_health -= amount
    ↓
发送信号: health_changed.emit()
    ↓
UI更新 / 死亡处理
```

---

## 扩展性设计

### 添加新角色

1. **创建配置**:
   - 在`player_config.csv`添加角色属性
   - 在`player_visual.csv`添加视觉配置
   - 在`player_skill_bindings.csv`绑定技能

2. **创建脚本**:
   ```gdscript
   extends PlayerBase
   class_name PlayerNewCharacter
   
   # 无需重写，技能由SkillManager管理
   ```

3. **创建场景**:
   - 继承PlayerBase场景
   - 设置player_id
   - 配置精灵和碰撞

### 添加新技能

1. **创建配置**:
   - 在`skill_params.csv`添加技能参数

2. **创建脚本**:
   ```gdscript
   extends SkillBase
   class_name SkillNewSkill
   
   # 技能特定参数
   var special_param: float = 0.0
   
   func execute() -> void:
       if not can_execute():
           return
       
       consume_energy()
       # 技能逻辑
       start_cooldown()
   ```

3. **绑定技能**:
   - 在`player_skill_bindings.csv`绑定到角色

### 添加新敌人

1. **创建配置**:
   - 在`enemy_config.csv`添加敌人属性
   - 在`wave_units_config.csv`添加到波次

2. **创建脚本**:
   ```gdscript
   extends Enemy
   class_name EnemyNewType
   
   # 特殊逻辑
   func _process(delta):
       super._process(delta)
       # 自定义行为
   ```

3. **创建场景**:
   - 继承Enemy场景
   - 设置enemy_id
   - 配置精灵和碰撞

---

## 性能优化

### 对象池

**应用**: 子弹、粒子效果、音效

**实现**:
```gdscript
var projectile_pool: Array[Projectile] = []

func get_projectile() -> Projectile:
    if projectile_pool.is_empty():
        return projectile_scene.instantiate()
    return projectile_pool.pop_back()

func return_projectile(projectile: Projectile):
    projectile_pool.append(projectile)
```

### 空间分区

**应用**: 敌人检测、碰撞检测

**实现**: 使用Godot的Area2D和CollisionShape2D

### 延迟加载

**应用**: 场景资源、音效资源

**实现**:
```gdscript
var scene_cache: Dictionary = {}

func get_scene(path: String) -> PackedScene:
    if not scene_cache.has(path):
        scene_cache[path] = load(path)
    return scene_cache[path]
```

---

## 总结

PolyLash的架构设计遵循以下原则：

1. **数据驱动**: CSV配置驱动，代码与数据分离
2. **模块化**: 系统解耦，职责单一
3. **可扩展**: 易于添加新内容
4. **可维护**: 清晰的代码结构
5. **高性能**: 对象池、缓存等优化

这种架构使得游戏易于开发、调试和扩展，同时保持良好的性能。
