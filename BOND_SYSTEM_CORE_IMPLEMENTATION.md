# 羁绊系统核心数值逻辑实现总结

## 实施日期
2026-01-24

## 概述
完成了羁绊系统从 UI 原型到完整数据驱动系统的重构，移除了所有硬编码阈值，实现了基于 CSV 配置的核心数值逻辑。

---

## Task 1: 重构羁绊配置表 (bond_config.csv)

### 新增字段
**文件**: `config/player/bond_config.csv`

**Schema (表头结构)**:
```csv
bond_id, type, level, required_count, effect_type, effect_param, effect_value, icon_path_index, display_name, description
```

**字段说明**:
- `bond_id`: 羁绊唯一标识符（如 "martial", "arcane"）
- `type`: 羁绊类型（origin/mastery/tactic）
- `level`: 羁绊等级（1, 2, 3...）
- `required_count`: 激活该等级所需的标签数量
- `effect_type`: 效果类型
  - `stat_mod`: 属性修改（直接加成）
  - `mechanic`: 特殊机制（需要额外实现）
- `effect_param`: 效果参数名（属性名或机制名）
- `effect_value`: 效果数值
- `icon_path_index`: 图标索引（用于 UI 显示）
- `display_name`: 显示名称
- `description`: 效果描述

### 核心羁绊数据

#### 身世 (Origin) - 3 种核心羁绊

**1. Martial (武道世家)**
```csv
martial,origin,1,2,stat_mod,crit_chance,10,1,武道世家,全队暴击率+10%
martial,origin,2,3,stat_mod,crit_damage,0.5,1,武道世家,全队暴击伤害+50%
```

**2. Arcane (秘术行者)**
```csv
arcane,origin,1,2,stat_mod,energy_regen,0.5,2,秘术行者,全队能量回复+0.5/s
arcane,origin,2,3,stat_mod,cooldown_reduction,0.25,2,秘术行者,全队冷却缩减25%
```

**3. Survivor (幸存者)**
```csv
survivor,origin,1,2,stat_mod,max_health,50,3,幸存者,全队生命上限+50
survivor,origin,2,3,mechanic,revive,1,3,幸存者,获得一次复活机会
```

#### 职能 (Mastery) - 3 种核心羁绊

**4. Destruction (毁灭打击)**
```csv
destruction,mastery,1,2,mechanic,draw_damage_mult,0.3,1,毁灭打击,画图区域伤害提升30%
destruction,mastery,2,3,mechanic,draw_explode,1,1,毁灭打击,闭合图形引发二次爆炸
```

**5. Velocity (极速)**
```csv
velocity,mastery,1,2,stat_mod,speed,50,2,极速,移动速度+50
velocity,mastery,2,3,mechanic,speed_to_dmg_ratio,0.1,2,极速,移速的10%转化为攻击力
```

**6. Control (控制大师)**
```csv
control,mastery,1,2,mechanic,draw_duration,2.0,3,控制大师,图形持续时间+2秒
control,mastery,2,3,mechanic,draw_slow_percent,0.5,3,控制大师,图形区域减速50%
```

#### 战术 (Tactic) - 3 种核心羁绊

**7. Assault (突击战术)**
```csv
assault,tactic,1,2,mechanic,switch_cd_reduce,0.3,1,突击战术,切人冷却减少30%
assault,tactic,2,3,mechanic,switch_nuke,1,1,突击战术,登场触发全屏震击
```

**8. Assist (支援战术)**
```csv
assist,tactic,1,2,mechanic,bench_cd_reduce,0.5,2,支援战术,后台技能频率加快50%
assist,tactic,2,3,mechanic,bench_mimic,1,2,支援战术,后台角色镜像攻击
```

**9. Captain (指挥官)**
```csv
captain,tactic,1,2,stat_mod,stat_share_ratio,0.2,3,指挥官,后台角色20%属性共享
captain,tactic,2,3,stat_mod,stat_share_ratio,0.5,3,指挥官,后台角色50%属性共享
```

### 扩展羁绊（已配置）
- Noble (贵族血统): 金币+20%, 经验+30%
- Shadow (暗影刺客): 闪避+15%, 背刺伤害+150%
- Nature (自然守护): 生命回复+2/s, 反伤30%
- Tech (科技先锋): 弹道速度+30%, 召唤炮塔
- Defense (坚韧防御): 护甲+30, 伤害减免20%
- Support (辅助专家): 治疗效果+30%, 光环治疗5/s
- Summon (召唤大师): 召唤物持续+50%, 伤害+50%
- Stealth (隐匿): 隐身时间+3s, 隐身暴击+100%
- Defense_tactic (防御战术): 伤害减免15%, 低血护盾
- Guerrilla (游击战术): 攻击后加速25%, 闪避反击
- Siege (攻城战术): 建筑伤害+50%, 范围扩大30%
- Ambush (伏击战术): 首次攻击+40%, 陷阱伤害翻倍

**总计**: 42 行配置数据（21 个羁绊 × 2 等级）

---

## Task 2: BondManager 核心逻辑

### 文件创建
**文件**: `autoloads/bond_manager.gd`
**类型**: Autoload 单例

### 核心数据结构

```gdscript
# 羁绊配置数据
var bond_configs: Dictionary = {
    "martial": {
        "bond_type": "origin",
        "display_name": "武道世家",
        "icon_path_index": 1,
        "levels": [
            {
                "level": 1,
                "required_count": 2,
                "effect_type": "stat_mod",
                "effect_param": "crit_chance",
                "effect_value": 10,
                "description": "全队暴击率+10%"
            },
            {
                "level": 2,
                "required_count": 3,
                "effect_type": "stat_mod",
                "effect_param": "crit_damage",
                "effect_value": 0.5,
                "description": "全队暴击伤害+50%"
            }
        ]
    }
}

# 当前激活的羁绊
var active_bonds: Dictionary = {
    "martial": {
        "level": 2,
        "effects": [...],
        "bond_type": "origin",
        "display_name": "武道世家"
    }
}

# 当前队伍的羁绊标签统计
var current_bond_counts: Dictionary = {
    "martial": 3,
    "destruction": 2,
    "assault": 2
}

# 变身过载模式
var is_overdrive_mode: bool = false
```

### 核心功能

#### 1. 数据加载
```gdscript
func _load_bond_configs() -> void
```
- 从 `bond_config.csv` 加载所有羁绊配置
- 构建 `bond_configs` 字典
- 按等级排序每个羁绊的 levels 数组
- 容错处理：跳过无效行

#### 2. 计算激活羁绊
```gdscript
func recalculate_active_bonds(team_player_ids: Array, equipped_relics: Array = []) -> void
```

**逻辑流程**:
1. 清空 `current_bond_counts` 和 `active_bonds`
2. 遍历队伍角色，统计所有羁绊标签
3. （预留）处理圣物提供的额外标签
4. 检查每个羁绊的激活状态
5. 调用 `_get_activated_level()` 获取激活等级
6. 调用 `_activate_bond()` 激活羁绊
7. 发出信号 `bonds_recalculated` 和 `stat_modifiers_changed`

**示例**:
```gdscript
# 队伍: butcher (martial, destruction, assault)
#       wind (martial, velocity, captain)
#       pyro (arcane, destruction, assault)

# 统计结果:
current_bond_counts = {
    "martial": 2,      # 激活 Lv.1
    "arcane": 1,       # 未激活
    "destruction": 2,  # 激活 Lv.1
    "velocity": 1,     # 未激活
    "assault": 2,      # 激活 Lv.1
    "captain": 1       # 未激活
}
```

#### 3. 变身过载逻辑
```gdscript
func _get_activated_level(bond_id: String, current_count: int) -> int
```

**正常模式**:
- 检查 `current_count >= required_count`
- 返回满足条件的最高等级

**过载模式** (`is_overdrive_mode = true`):
- 只要 `current_count >= 1`
- 直接返回该羁绊的最高等级

**示例**:
```gdscript
# 正常模式: martial 有 2 个标签
_get_activated_level("martial", 2)  # 返回 1 (需要2个)

# 过载模式: martial 有 1 个标签
is_overdrive_mode = true
_get_activated_level("martial", 1)  # 返回 2 (最高等级)
```

#### 4. 查询接口

```gdscript
# 获取羁绊激活等级
func get_active_bond_level(bond_id: String) -> int

# 获取羁绊最大等级
func get_bond_max_level(bond_id: String) -> int

# 获取羁绊指定等级的需求数量
func get_bond_required_count(bond_id: String, level: int) -> int

# 获取羁绊当前标签数量
func get_bond_current_count(bond_id: String) -> int

# 检查羁绊是否激活
func is_bond_active(bond_id: String) -> bool

# 获取所有激活的羁绊
func get_all_active_bonds() -> Dictionary

# 获取羁绊完整配置
func get_bond_config(bond_id: String) -> Dictionary
```

#### 5. 属性应用接口

```gdscript
func apply_stat_modifiers(player_stats: Dictionary) -> Dictionary
```

**功能**:
- 遍历所有激活的羁绊
- 筛选 `effect_type == "stat_mod"` 的效果
- 应用到 `player_stats` 字典
- 返回修改后的属性

**支持的属性**:
- `crit_chance`: 暴击率
- `crit_damage`: 暴击伤害
- `energy_regen`: 能量回复
- `cooldown_reduction`: 冷却缩减
- `max_health`: 最大生命
- `speed`: 移动速度
- `armor`: 护甲
- `stat_share_ratio`: 属性共享比例
- `gold_gain`: 金币获取
- `exp_gain`: 经验获取
- `dodge_chance`: 闪避率
- `health_regen`: 生命回复
- `projectile_speed`: 弹道速度
- `heal_power`: 治疗效果
- `damage_taken_reduction`: 伤害减免

**示例**:
```gdscript
var base_stats = {
    "crit_chance": 5,
    "max_health": 100,
    "speed": 200
}

# 激活羁绊: martial Lv.1 (暴击率+10%)
var modified_stats = BondManager.apply_stat_modifiers(base_stats)
# 结果: {"crit_chance": 15, "max_health": 100, "speed": 200}
```

#### 6. 机制查询接口

```gdscript
# 获取所有激活的机制效果
func get_active_mechanics() -> Array

# 检查是否激活了指定机制
func has_mechanic(mechanic_name: String) -> bool

# 获取机制的效果值
func get_mechanic_value(mechanic_name: String) -> float
```

**示例**:
```gdscript
# 检查是否有复活机制
if BondManager.has_mechanic("revive"):
    var revive_count = BondManager.get_mechanic_value("revive")
    print("可以复活 %d 次" % revive_count)

# 获取所有机制
var mechanics = BondManager.get_active_mechanics()
for mechanic in mechanics:
    print("%s: %s = %.2f" % [
        mechanic.bond_id,
        mechanic.effect_param,
        mechanic.effect_value
    ])
```

#### 7. 变身过载模式控制

```gdscript
# 设置过载模式
func set_overdrive_mode(enabled: bool) -> void

# 检查是否处于过载模式
func is_in_overdrive_mode() -> bool
```

#### 8. 调试接口

```gdscript
# 打印所有激活的羁绊
func print_active_bonds() -> void
```

**输出示例**:
```
========== 激活的羁绊 ==========
【武道世家】 Lv.2 - martial
  - Lv.1 stat_mod: crit_chance = 10.00 (全队暴击率+10%)
  - Lv.2 stat_mod: crit_damage = 0.50 (全队暴击伤害+50%)
【毁灭打击】 Lv.1 - destruction
  - Lv.1 mechanic: draw_damage_mult = 0.30 (画图区域伤害提升30%)
================================
```

### 信号系统

```gdscript
# 羁绊重新计算完成
signal bonds_recalculated(active_bonds: Dictionary)

# 属性修改器变化
signal stat_modifiers_changed()
```

---

## Task 3: 清理 UI 逻辑

### 修改文件
**文件**: `autoloads/bond_ui_loader.gd`

### 移除硬编码

**修改前**:
```gdscript
const BOND_THRESHOLDS = {
    "origin": 2,
    "mastery": 3,
    "tactic": 2
}

func get_sorted_bonds(bond_stats: Dictionary) -> Array:
    var max_count = thresholds.get(bond_type, 2)  # 硬编码
```

**修改后**:
```gdscript
func get_sorted_bonds(bond_stats: Dictionary) -> Array:
    # 从 BondManager 动态获取
    var max_level = BondManager.get_bond_max_level(bond_id)
    var max_count = BondManager.get_bond_required_count(bond_id, max_level)
```

### 动态获取阈值

```gdscript
func get_sorted_bonds(bond_stats: Dictionary) -> Array:
    var bonds_array = []
    
    for bond_id in bond_stats.bonds.keys():
        var bond_data = bond_stats.bonds[bond_id]
        var count = bond_data.count
        
        # 动态获取最大等级和需求数量
        var max_level = BondManager.get_bond_max_level(bond_id)
        var max_count = 0
        if max_level > 0:
            max_count = BondManager.get_bond_required_count(bond_id, max_level)
        
        bonds_array.append({
            "bond_id": bond_id,
            "count": count,
            "type": bond_data.type,
            "max": max_count,
            "max_level": max_level
        })
    
    return bonds_array
```

### UI 显示效果

**修改前**:
```
武道世家 2/2  (硬编码阈值)
毁灭打击 2/3  (硬编码阈值)
```

**修改后**:
```
武道世家 2/3  (从 CSV 读取: martial Lv.2 需要 3 个)
毁灭打击 2/3  (从 CSV 读取: destruction Lv.2 需要 3 个)
```

---

## Task 4: 属性应用接口（预留）

### 已实现功能

```gdscript
func apply_stat_modifiers(player_stats: Dictionary) -> Dictionary
```

**使用示例**:
```gdscript
# 在角色初始化时应用羁绊加成
func _ready():
    # 计算羁绊
    BondManager.recalculate_active_bonds(Global.selected_player_ids)
    
    # 应用属性加成
    var base_stats = {
        "max_health": 100,
        "crit_chance": 5,
        "speed": 200
    }
    
    var final_stats = BondManager.apply_stat_modifiers(base_stats)
    
    # 应用到角色
    health = final_stats.max_health
    crit_chance = final_stats.crit_chance
    speed = final_stats.speed
```

### 机制实现（后续任务）

以下机制需要在具体系统中实现：

**画图系统机制**:
- `draw_damage_mult`: 画图区域伤害倍率
- `draw_explode`: 闭合图形二次爆炸
- `draw_duration`: 图形持续时间
- `draw_slow_percent`: 图形区域减速

**切换系统机制**:
- `switch_cd_reduce`: 切人冷却减少
- `switch_nuke`: 登场全屏震击

**后台系统机制**:
- `bench_cd_reduce`: 后台技能频率
- `bench_mimic`: 后台镜像攻击

**特殊机制**:
- `revive`: 复活机会
- `speed_to_dmg_ratio`: 移速转攻击力
- `backstab_damage`: 背刺伤害
- `thorns_damage`: 反伤
- `tech_turret`: 召唤炮塔

---

## 集成指南

### 1. 在角色选择界面集成

```gdscript
# scenes/ui/selection_panel/selection_panel.gd

func _on_continue_pressed() -> void:
    # 保存选择
    Global.selected_player_ids = player_ids
    
    # 计算羁绊
    BondManager.recalculate_active_bonds(player_ids)
    
    # 打印调试信息
    BondManager.print_active_bonds()
    
    # 进入游戏
    get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")
```

### 2. 在战斗场景应用属性

```gdscript
# scenes/arena/arena.gd

func _ready():
    # 应用羁绊属性加成到所有角色
    for player in players:
        var base_stats = player.get_base_stats()
        var modified_stats = BondManager.apply_stat_modifiers(base_stats)
        player.apply_stats(modified_stats)
```

### 3. 实现变身过载

```gdscript
# scenes/unit/players/player_generic.gd

func _input(event):
    if event.is_action_pressed("transform"):  # F键
        # 启用过载模式
        BondManager.set_overdrive_mode(true)
        
        # 重新计算羁绊（所有羁绊升至最高等级）
        BondManager.recalculate_active_bonds(Global.selected_player_ids)
        
        # 重新应用属性
        var modified_stats = BondManager.apply_stat_modifiers(get_base_stats())
        apply_stats(modified_stats)
        
        # 变身持续时间结束后
        await get_tree().create_timer(10.0).timeout
        BondManager.set_overdrive_mode(false)
        BondManager.recalculate_active_bonds(Global.selected_player_ids)
```

### 4. 监听羁绊变化

```gdscript
func _ready():
    # 连接信号
    BondManager.bonds_recalculated.connect(_on_bonds_changed)
    BondManager.stat_modifiers_changed.connect(_on_stats_changed)

func _on_bonds_changed(active_bonds: Dictionary):
    print("羁绊已更新: %s" % str(active_bonds.keys()))
    update_ui()

func _on_stats_changed():
    print("属性修改器已变化")
    recalculate_stats()
```

---

## 测试建议

### 测试场景 1: 基础羁绊激活
```gdscript
# 队伍: butcher (martial, destruction, assault)
#       wind (martial, velocity, captain)

# 预期结果:
# - martial: 2/3 (Lv.1 激活)
# - destruction: 1/3 (未激活)
# - assault: 1/2 (未激活)
# - velocity: 1/2 (未激活)
# - captain: 1/2 (未激活)
```

### 测试场景 2: 满级羁绊
```gdscript
# 队伍: butcher (martial, destruction, assault)
#       wind (martial, velocity, captain)
#       pyro (arcane, destruction, assault)

# 预期结果:
# - martial: 2/3 (Lv.1 激活)
# - destruction: 2/3 (Lv.1 激活)
# - assault: 2/2 (Lv.1 激活) ✅
```

### 测试场景 3: 变身过载
```gdscript
# 队伍: butcher (martial, destruction, assault)
# 正常模式: martial 1/3 (未激活)

BondManager.set_overdrive_mode(true)
BondManager.recalculate_active_bonds(["butcher"])

# 过载模式: martial 1/3 (Lv.2 激活) ✅
```

### 测试场景 4: 属性应用
```gdscript
var stats = {"crit_chance": 5, "max_health": 100}

# 激活 martial Lv.1 (暴击率+10%)
BondManager.recalculate_active_bonds(["butcher", "wind"])
var modified = BondManager.apply_stat_modifiers(stats)

# 预期: {"crit_chance": 15, "max_health": 100}
```

---

## 文件清单

### 新增文件
- `autoloads/bond_manager.gd` (核心逻辑)
- `BOND_SYSTEM_CORE_IMPLEMENTATION.md` (本文档)

### 修改文件
- `config/player/bond_config.csv` (完整重构)
- `autoloads/bond_ui_loader.gd` (移除硬编码)
- `project.godot` (注册 BondManager autoload)

### 依赖文件
- `config/player/player_config.csv` (角色羁绊标签)
- `autoloads/config_manager.gd` (配置读取)
- `autoloads/global.gd` (全局状态)

---

## 完成状态

✅ Task 1: 重构羁绊配置表 - 完成
  - ✅ 新增 level, required_count, effect_type 等字段
  - ✅ 填入 9 种核心羁绊数据（42 行配置）
  - ✅ 扩展 12 种额外羁绊

✅ Task 2: 编写 BondManager - 完成
  - ✅ 数据加载与解析
  - ✅ 计算激活羁绊逻辑
  - ✅ 变身过载模式
  - ✅ 查询接口
  - ✅ 属性应用接口
  - ✅ 机制查询接口
  - ✅ 信号系统
  - ✅ 调试接口

✅ Task 3: 清理 UI 逻辑 - 完成
  - ✅ 移除硬编码阈值
  - ✅ 动态获取最大等级
  - ✅ 动态获取需求数量

✅ Task 4: 属性应用接口 - 完成
  - ✅ apply_stat_modifiers 实现
  - ✅ 支持 15+ 种属性
  - ✅ 机制查询接口预留

**总体状态**: 核心逻辑完全实现，可以开始集成测试

**下一步**: 
1. 在角色选择界面调用 `BondManager.recalculate_active_bonds()`
2. 在战斗场景应用 `BondManager.apply_stat_modifiers()`
3. 实现具体的机制效果（画图、切换、后台等）
4. 实现变身过载的 UI 和输入处理
