# 技能系统技术文档

本文档详细介绍PolyLash技能系统的技术实现、架构设计和使用方法。

---

## 目录

- [系统概述](#系统概述)
- [架构设计](#架构设计)
- [核心类详解](#核心类详解)
- [技能生命周期](#技能生命周期)
- [配置系统](#配置系统)
- [开发指南](#开发指南)

---

## 系统概述

### 设计目标

技能系统旨在提供：
1. **灵活性**: 易于添加新技能
2. **可配置性**: 技能参数通过CSV配置
3. **可扩展性**: 支持各种技能类型
4. **易维护性**: 清晰的代码结构

### 核心特性

- **槽位管理**: 支持Q/E/LMB/RMB四个技能槽位
- **CSV配置**: 技能参数和绑定通过CSV配置
- **基类继承**: 所有技能继承自SkillBase
- **能量系统**: 技能消耗能量，能量自动恢复
- **冷却系统**: 技能有冷却时间，冷却期间无法使用

---

## 架构设计

### 系统架构图

```
PlayerBase (玩家)
    ↓ 拥有
SkillManager (技能管理器)
    ↓ 管理
skill_slots: Dictionary
    ├── "q": SkillBase (Q技能实例)
    ├── "e": SkillBase (E技能实例)
    ├── "lmb": SkillBase (左键技能实例)
    └── "rmb": SkillBase (右键技能实例)
    ↓ 继承
具体技能类
    ├── SkillDash (冲刺)
    ├── SkillHerderLoop (牧者路径)
    ├── SkillFirePath (火焰路径)
    └── ... (其他技能)
```

### 类关系图

```
SkillBase (抽象基类)
    ├── 通用属性
    │   ├── skill_owner: Node2D
    │   ├── skill_id: String
    │   ├── energy_cost: float
    │   └── cooldown_time: float
    ├── 虚函数接口
    │   ├── execute()
    │   ├── charge(delta)
    │   └── release()
    └── 通用功能
        ├── can_execute()
        ├── consume_energy()
        └── start_cooldown()
        ↓ 继承
具体技能类 (如SkillDash)
    ├── 技能特定属性
    │   ├── dash_speed: float
    │   ├── dash_distance: float
    │   └── dash_damage: float
    └── 实现虚函数
        ├── execute() - 执行冲刺
        ├── charge(delta) - 无需实现
        └── release() - 无需实现
```

---

## 核心类详解

### SkillBase - 技能基类

**位置**: `scenes/skills/skill_base.gd`

#### 职责
- 定义技能的通用接口
- 管理技能状态（就绪/冷却/执行中）
- 处理能量消耗和冷却时间
- 提供虚函数供子类实现

#### 核心属性

```gdscript
# 技能所有者和配置
var skill_owner: Node2D          # 技能所有者（玩家或敌人）
var skill_id: String = ""        # 技能唯一标识符
var energy_cost: float = 0.0     # 能量消耗
var cooldown_time: float = 0.0   # 冷却时间（秒）

# 运行时状态
var is_on_cooldown: bool = false # 是否处于冷却中
var cooldown_timer: float = 0.0  # 冷却计时器
var is_charging: bool = false    # 是否正在蓄力
var is_executing: bool = false   # 是否正在执行
```

#### 虚函数接口

```gdscript
# 执行技能（瞬发技能）
# 用于E键、左键等瞬发技能
func execute() -> void:
    push_warning("[SkillBase] execute() 未实现: %s" % skill_id)

# 蓄力技能（持续按住）
# 用于Q键等需要蓄力的技能
func charge(delta: float) -> void:
    pass  # 默认实现为空，子类可选择性实现

# 释放技能（松开按键）
# 用于Q键等需要释放的技能
func release() -> void:
    pass  # 默认实现为空，子类可选择性实现
```

#### 通用功能

```gdscript
# 检查技能是否可以执行
func can_execute() -> bool:
    if is_on_cooldown:
        return false
    if skill_owner and skill_owner.has_method("consume_energy"):
        return skill_owner.energy >= energy_cost
    return true

# 消耗能量
func consume_energy() -> bool:
    if skill_owner and skill_owner.has_method("consume_energy"):
        return skill_owner.consume_energy(energy_cost)
    return true

# 开始冷却
func start_cooldown() -> void:
    if cooldown_time > 0:
        is_on_cooldown = true
        cooldown_timer = cooldown_time

# 获取冷却剩余时间
func get_cooldown_remaining() -> float:
    return cooldown_timer if is_on_cooldown else 0.0

# 获取冷却进度（0-1）
func get_cooldown_progress() -> float:
    if not is_on_cooldown or cooldown_time <= 0:
        return 0.0
    return cooldown_timer / cooldown_time
```

#### 生命周期

```gdscript
func _ready() -> void:
    # 确保skill_owner已设置
    if not skill_owner:
        push_error("[SkillBase] 错误: skill_owner未设置 for skill %s" % skill_id)

func _process(delta: float) -> void:
    # 更新冷却计时器
    if is_on_cooldown:
        cooldown_timer -= delta
        if cooldown_timer <= 0:
            is_on_cooldown = false
            cooldown_timer = 0.0
            _on_cooldown_complete()

# 冷却完成回调（子类可重写）
func _on_cooldown_complete() -> void:
    pass
```

---

### SkillManager - 技能管理器

**位置**: `scenes/skills/skill_manager.gd`

#### 职责
- 管理四个技能槽位（Q/E/LMB/RMB）
- 从CSV配置加载技能
- 分发技能调用（execute/charge/release）
- 处理技能生命周期

#### 核心属性

```gdscript
# 技能槽位字典
# 键: "q", "e", "lmb", "rmb"
# 值: SkillBase实例或null
var skill_slots: Dictionary = {
    "q": null,
    "e": null,
    "lmb": null,
    "rmb": null
}

# 技能所有者（玩家或敌人）
var skill_owner: Node2D

# 调试模式
var debug_mode: bool = false
```

#### 初始化

```gdscript
func _init(_owner: Node2D = null):
    if _owner:
        skill_owner = _owner

func _ready() -> void:
    if not skill_owner:
        push_error("[SkillManager] 错误: skill_owner未设置")
```

#### 技能加载

```gdscript
# 从配置加载技能
func load_skills_from_config(player_id: String) -> bool:
    if player_id.is_empty():
        push_error("[SkillManager] 错误: player_id为空")
        return false
    
    # 从ConfigManager获取技能绑定
    var bindings = ConfigManager.get_player_skill_bindings(player_id)
    if bindings.is_empty():
        push_warning("[SkillManager] 警告: 未找到技能绑定配置 for %s" % player_id)
        return false
    
    # 加载每个槽位的技能
    var success_count = 0
    for slot in ["q", "e", "lmb", "rmb"]:
        var skill_id = bindings.get("slot_%s" % slot, "")
        if not skill_id.is_empty():
            if _load_skill_to_slot(slot, skill_id):
                success_count += 1
    
    return success_count > 0
```

```gdscript
# 加载技能到指定槽位
func _load_skill_to_slot(slot: String, skill_id: String) -> bool:
    # 构建技能脚本路径
    var skill_script_path = "res://scenes/skills/players/%s.gd" % skill_id
    
    # 加载技能脚本
    var skill_script = load(skill_script_path)
    if not skill_script:
        push_error("[SkillManager] 错误: 无法加载技能脚本 %s" % skill_script_path)
        return false
    
    # 创建技能实例
    var skill: SkillBase = skill_script.new()
    if not skill is SkillBase:
        push_error("[SkillManager] 错误: 技能 %s 不是SkillBase的子类" % skill_id)
        skill.free()
        return false
    
    # 设置技能基础属性
    skill.skill_owner = skill_owner
    skill.skill_id = skill_id
    skill.name = "%s_Skill" % slot.to_upper()
    
    # 从CSV加载技能参数
    _load_skill_params(skill, skill_id)
    
    # 添加到场景树
    add_child(skill)
    
    # 保存到槽位
    skill_slots[slot] = skill
    
    return true
```

```gdscript
# 从CSV加载技能参数
func _load_skill_params(skill: SkillBase, skill_id: String) -> void:
    # 从skill_params.csv加载技能参数
    var params = ConfigManager.get_skill_params(skill_id)
    
    if params.is_empty():
        if debug_mode:
            print("[SkillManager] 警告: 未找到技能参数配置 for %s" % skill_id)
        return
    
    # 设置通用参数
    if "energy_cost" in params:
        skill.energy_cost = params["energy_cost"]
    if "cooldown" in params:
        skill.cooldown_time = params["cooldown"]
    
    # 设置技能特定参数（通过反射）
    for key in params.keys():
        if key in ["skill_id", "energy_cost", "cooldown"]:
            continue  # 跳过已处理的通用参数
        
        if key in skill:
            skill.set(key, params[key])
            if debug_mode:
                print("[SkillManager]   设置参数: %s = %s" % [key, params[key]])
```

#### 技能执行

```gdscript
# 执行技能（瞬发）
func execute_skill(slot: String) -> void:
    var skill = skill_slots.get(slot)
    if not skill or not is_instance_valid(skill):
        return
    
    if skill.can_execute():
        if debug_mode:
            print("[SkillManager] 执行技能: %s (%s)" % [slot.to_upper(), skill.skill_id])
        skill.execute()
    else:
        if debug_mode:
            if skill.is_on_cooldown:
                print("[SkillManager] 技能冷却中: %s (剩余: %.1fs)" % [
                    slot.to_upper(), 
                    skill.get_cooldown_remaining()
                ])
            else:
                print("[SkillManager] 能量不足: %s (需要: %.0f)" % [
                    slot.to_upper(), 
                    skill.energy_cost
                ])

# 蓄力技能（持续按住）
func charge_skill(slot: String, delta: float) -> void:
    var skill = skill_slots.get(slot)
    if not skill or not is_instance_valid(skill):
        return
    
    if not skill.is_charging:
        if debug_mode:
            print("[SkillManager] 开始蓄力: %s (%s)" % [slot.to_upper(), skill.skill_id])
        skill.is_charging = true
    
    skill.charge(delta)

# 释放技能（松开按键）
func release_skill(slot: String) -> void:
    var skill = skill_slots.get(slot)
    if not skill or not is_instance_valid(skill):
        return
    
    if skill.is_charging:
        if debug_mode:
            print("[SkillManager] 释放技能: %s (%s)" % [slot.to_upper(), skill.skill_id])
        skill.is_charging = false
        skill.release()
```

#### 技能查询

```gdscript
# 获取指定槽位的技能
func get_skill(slot: String) -> SkillBase:
    return skill_slots.get(slot)

# 检查槽位是否有技能
func has_skill(slot: String) -> bool:
    var skill = skill_slots.get(slot)
    return skill != null and is_instance_valid(skill)

# 获取所有技能
func get_all_skills() -> Array[SkillBase]:
    var skills: Array[SkillBase] = []
    for slot in skill_slots.keys():
        var skill = skill_slots[slot]
        if skill and is_instance_valid(skill):
            skills.append(skill)
    return skills
```

---

## 技能生命周期

### 完整流程

```
1. 游戏启动
    ↓
2. ConfigManager加载配置
    ├── player_skill_bindings.csv
    └── skill_params.csv
    ↓
3. 玩家场景创建
    ↓
4. PlayerBase._ready()
    ├── 创建SkillManager
    ├── skill_manager = SkillManager.new(self)
    ├── add_child(skill_manager)
    └── skill_manager.load_skills_from_config(player_id)
    ↓
5. SkillManager加载技能
    ├── 获取技能绑定
    ├── 加载技能脚本
    ├── 创建技能实例
    ├── 设置技能参数
    └── 添加到槽位
    ↓
6. 玩家按键
    ↓
7. PlayerBase._handle_input()
    ├── 检测按键
    └── 调用SkillManager
    ↓
8. SkillManager分发调用
    ├── execute_skill(slot)
    ├── charge_skill(slot, delta)
    └── release_skill(slot)
    ↓
9. 技能执行
    ├── 检查can_execute()
    ├── 消耗能量
    ├── 执行技能逻辑
    └── 启动冷却
    ↓
10. 技能更新
    ├── SkillBase._process(delta)
    └── 更新冷却计时器
    ↓
11. 冷却完成
    └── _on_cooldown_complete()
```

### 状态转换

```
[就绪] ──execute()──> [执行中] ──完成──> [冷却中] ──时间到──> [就绪]
   ↑                                                           │
   └───────────────────────────────────────────────────────────┘
```

---

## 配置系统

### 技能绑定配置

**文件**: `config/player/player_skill_bindings.csv`

**格式**:
```csv
player_id,slot_q,slot_e,slot_lmb,slot_rmb
-1,玩家ID,Q技能,E技能,左键技能,右键技能
player_herder,skill_herder_loop,skill_herder_explosion,skill_dash,
player_butcher,skill_saw_path,skill_meat_stake,skill_dash,
```

**说明**:
- 每个玩家可以绑定4个技能
- 空值表示该槽位无技能
- skill_id必须对应实际的技能脚本

### 技能参数配置

**文件**: `config/player/skill_params.csv`

**格式**:
```csv
skill_id,energy_cost,cooldown,damage,dash_speed,dash_distance
-1,技能ID,能量消耗,冷却时间,伤害,冲刺速度,冲刺距离
skill_dash,10,0,14,1700,340
skill_herder_loop,20,0,0,2000,0
```

**说明**:
- 每个技能可以有不同的参数列
- 通用参数：energy_cost, cooldown
- 技能特定参数：根据技能而定
- ConfigManager会自动将参数设置到技能实例

### 参数加载机制

```gdscript
# SkillManager._load_skill_params()
func _load_skill_params(skill: SkillBase, skill_id: String) -> void:
    var params = ConfigManager.get_skill_params(skill_id)
    
    # 设置通用参数
    if "energy_cost" in params:
        skill.energy_cost = params["energy_cost"]
    if "cooldown" in params:
        skill.cooldown_time = params["cooldown"]
    
    # 设置技能特定参数（通过反射）
    for key in params.keys():
        if key in ["skill_id", "energy_cost", "cooldown"]:
            continue
        
        if key in skill:
            skill.set(key, params[key])  # 反射设置
```

**关键点**:
- 使用`skill.set(key, value)`反射设置参数
- 技能类中必须定义对应的变量
- 参数名必须与CSV列名一致

---

## 开发指南

### 添加新技能

#### 1. 创建技能脚本

**位置**: `scenes/skills/players/skill_new_skill.gd`

```gdscript
extends SkillBase
class_name SkillNewSkill

## ==============================================================================
## 新技能 - 技能描述
## ==============================================================================

# ==============================================================================
# 技能特定参数
# ==============================================================================

## 技能特定参数1
var special_param1: float = 0.0

## 技能特定参数2
var special_param2: int = 0

# ==============================================================================
# 虚函数实现
# ==============================================================================

## 执行技能（瞬发）
func execute() -> void:
    # 检查是否可以执行
    if not can_execute():
        return
    
    # 消耗能量
    if not consume_energy():
        return
    
    # 技能逻辑
    print("[SkillNewSkill] 执行技能")
    # TODO: 实现技能效果
    
    # 启动冷却
    start_cooldown()

## 蓄力技能（可选）
func charge(delta: float) -> void:
    # TODO: 实现蓄力逻辑
    pass

## 释放技能（可选）
func release() -> void:
    # TODO: 实现释放逻辑
    pass
```

#### 2. 添加技能参数配置

**文件**: `config/player/skill_params.csv`

```csv
skill_id,energy_cost,cooldown,special_param1,special_param2
skill_new_skill,30,5.0,100.0,10
```

#### 3. 绑定技能到角色

**文件**: `config/player/player_skill_bindings.csv`

```csv
player_id,slot_q,slot_e,slot_lmb,slot_rmb
player_herder,skill_new_skill,skill_herder_explosion,skill_dash,
```

#### 4. 测试技能

1. 启动游戏
2. 选择对应角色
3. 按Q键测试技能
4. 检查控制台日志
5. 验证技能效果

### 技能类型示例

#### 瞬发技能（E键）

```gdscript
func execute() -> void:
    if not can_execute():
        return
    
    consume_energy()
    
    # 立即生效的技能
    var explosion = explosion_scene.instantiate()
    explosion.global_position = skill_owner.global_position
    get_tree().root.add_child(explosion)
    
    start_cooldown()
```

#### 蓄力技能（Q键）

```gdscript
var charge_time: float = 0.0
var max_charge_time: float = 2.0

func charge(delta: float) -> void:
    charge_time += delta
    charge_time = min(charge_time, max_charge_time)
    
    # 显示蓄力效果
    update_charge_visual()

func release() -> void:
    if charge_time < 0.5:
        # 蓄力时间太短，取消
        charge_time = 0.0
        return
    
    if not can_execute():
        charge_time = 0.0
        return
    
    consume_energy()
    
    # 根据蓄力时间计算效果
    var power = charge_time / max_charge_time
    execute_charged_skill(power)
    
    charge_time = 0.0
    start_cooldown()
```

#### 路径技能（Q键）

```gdscript
var path_points: Array[Vector2] = []
var is_planning: bool = false

func charge(delta: float) -> void:
    if not is_planning:
        is_planning = true
        path_points.clear()
        # 进入子弹时间
        Engine.time_scale = 0.1
    
    # 等待玩家点击规划路径
    # 在PlayerBase中处理点击事件

func add_path_point(point: Vector2) -> void:
    path_points.append(point)
    # 显示路径预览

func release() -> void:
    if path_points.is_empty():
        is_planning = false
        Engine.time_scale = 1.0
        return
    
    if not can_execute():
        path_points.clear()
        is_planning = false
        Engine.time_scale = 1.0
        return
    
    consume_energy()
    
    # 执行路径
    execute_path(path_points)
    
    path_points.clear()
    is_planning = false
    Engine.time_scale = 1.0
    start_cooldown()
```

### 调试技巧

#### 启用调试模式

```gdscript
# 在PlayerBase._ready()中
skill_manager.debug_mode = true
```

#### 打印技能信息

```gdscript
# 在技能类中
func execute() -> void:
    print("[%s] 执行技能" % skill_id)
    print("  能量消耗: %.0f" % energy_cost)
    print("  冷却时间: %.1fs" % cooldown_time)
    print("  特殊参数: %.1f" % special_param1)
```

#### 检查技能加载

```gdscript
# 在PlayerBase._ready()中
skill_manager.print_skills_info()
```

输出示例：
```
[SkillManager] 技能槽位信息:
  Q: skill_herder_loop (能量: 20, 冷却: 0.0s, 状态: 就绪)
  E: skill_herder_explosion (能量: 20, 冷却: 0.0s, 状态: 就绪)
  LMB: skill_dash (能量: 10, 冷却: 0.0s, 状态: 就绪)
  RMB: (空)
```

---

## 常见问题

### Q: 技能不执行？
**A**: 检查：
1. 技能是否正确加载到槽位
2. 能量是否足够
3. 是否在冷却中
4. can_execute()返回值

### Q: 技能参数不生效？
**A**: 检查：
1. skill_params.csv中是否有对应配置
2. 参数名是否与技能类中的变量名一致
3. ConfigManager是否正确加载配置
4. 技能类中是否定义了对应变量

### Q: 技能冷却不工作？
**A**: 检查：
1. 是否调用了start_cooldown()
2. cooldown_time是否大于0
3. SkillBase._process()是否正常运行

### Q: 如何实现技能升级？
**A**: 
1. 在skill_params.csv中添加等级相关参数
2. 在技能类中添加level变量
3. 根据level调整技能效果
4. 或者创建多个技能ID（skill_dash_1, skill_dash_2）

---

## 总结

PolyLash的技能系统具有以下特点：

1. **基于继承**: 所有技能继承自SkillBase
2. **CSV配置**: 技能参数和绑定通过CSV配置
3. **槽位管理**: SkillManager管理四个技能槽位
4. **反射机制**: 自动将CSV参数设置到技能实例
5. **易于扩展**: 添加新技能只需继承基类和添加配置

通过合理使用技能系统，可以快速实现各种技能效果，无需修改核心代码。
