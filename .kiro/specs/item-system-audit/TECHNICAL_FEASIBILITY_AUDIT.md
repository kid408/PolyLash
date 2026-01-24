# 三层道具系统技术可行性审计报告

## 执行摘要

本报告对现有代码库进行了全面审计，评估实现三层道具系统的技术可行性：
1. **属性道具**（早期）：HP、伤害、速度修改器
2. **魔法道具**（中期）：技能特定增强
3. **圣物道具**（后期）：动态羁绊标签添加

**结论**：系统架构支持实现，但需要关键扩展。

---

## 1. 属性道具系统分析

### 1.1 当前属性系统架构

**核心类：`UnitStats` (resouce/unit/unit_stats.gd)**
```gdscript
extends Resource
class_name UnitStats

@export var health: float = 100.0
@export var damage: float = 10.0
@export var speed: float = 200.0
@export var block_chance: float = 0.0
```

**玩家属性加载：`PlayerBase._load_config_from_csv()`**
```gdscript
# 从CSV设置生命值和速度
var csv_health = config.get("health", 5000.0)
var csv_speed = config.get("base_speed", 300.0)

stats.health = csv_health
stats.speed = csv_speed
```

### 1.2 可行性评估

✅ **高度可行** - 属性系统已经存在且结构清晰

**实现路径**：
1. 扩展 `UnitStats` 添加修改器字典
2. 在 `PlayerBase` 添加 `apply_item_modifiers()` 函数
3. 通过 `EquipmentManager` 读取装备道具并应用加成


**风险**：
- ⚠️ 当前 `UnitStats` 只有4个属性，需要扩展支持更多属性类型
- ⚠️ 缺少属性修改器系统（加法 vs 乘法）

**推荐架构调整**：
```gdscript
# 扩展 UnitStats
class_name UnitStats

# 基础属性
@export var health: float = 100.0
@export var damage: float = 10.0
@export var speed: float = 200.0

# 新增属性
@export var crit_chance: float = 0.0
@export var crit_damage: float = 1.5
@export var cooldown_reduction: float = 0.0
@export var energy_regen: float = 0.5

# 修改器系统
var flat_modifiers: Dictionary = {}  # 加法修改器
var mult_modifiers: Dictionary = {}  # 乘法修改器

func get_modified_value(base_value: float, stat_name: String) -> float:
    var flat = flat_modifiers.get(stat_name, 0.0)
    var mult = mult_modifiers.get(stat_name, 1.0)
    return (base_value + flat) * mult
```

---

## 2. 魔法道具系统分析（技能增强）

### 2.1 当前技能系统架构

**技能基类：`SkillBase` (scenes/skills/skill_base.gd)**
```gdscript
class_name SkillBase

var skill_owner: Node2D
var skill_id: String = ""
var energy_cost: float = 0.0
var cooldown_time: float = 0.0
```

**技能参数示例：`PlayerButcher`**
```gdscript
@export var stake_duration: float = 6.0
@export var chain_radius: float = 250.0
@export var saw_damage_tick: int = 3
@export var saw_rotation_speed: float = 25.0
```


**技能效果管理：`SkillEffectManager` (autoloads/skill_effect_manager.gd)**
```gdscript
func create_area_effect(config: Dictionary) -> int:
    # 支持配置：
    # - damage, damage_interval, duration
    # - pull_to_center, pull_force
    # - color, z_index, fade_in_duration
```

### 2.2 可行性评估

⚠️ **中等可行** - 技能系统存在但参数分散

**当前问题**：
1. **参数分散**：技能参数在角色类中（`@export`），不在技能类中
2. **无统一接口**：每个技能有不同的参数名称
3. **硬编码值**：许多技能直接使用硬编码数值

**实现路径**：
1. 在 `SkillBase` 添加 `skill_modifiers: Dictionary`
2. 创建 `SkillParameterRegistry` 统一管理技能参数
3. 道具通过 `skill_id + param_name` 修改技能参数

**示例实现**：
```gdscript
# 在 SkillBase 中
var skill_modifiers: Dictionary = {}

func get_modified_param(param_name: String, base_value: float) -> float:
    var modifier = skill_modifiers.get(param_name, 1.0)
    return base_value * modifier

# 在具体技能中
var actual_damage = get_modified_param("damage", base_damage)
var actual_duration = get_modified_param("duration", base_duration)
```


**风险**：
- 🔴 **高风险**：需要重构所有技能类以支持参数修改器
- 🔴 **高风险**：技能参数命名不统一（如 `saw_damage_tick` vs `fire_line_damage`）
- ⚠️ 技能效果已经通过 `SkillEffectManager` 独立管理，修改参数需要在创建时传入

**推荐架构调整**：
```gdscript
# 创建技能参数注册表
class_name SkillParameterRegistry

const PARAM_DEFINITIONS = {
    "butcher_q": {
        "damage": 3,
        "rotation_speed": 25.0,
        "duration": 5.0
    },
    "pyro_q": {
        "damage": 20,
        "line_width": 24.0,
        "duration": 5.0
    }
}

static func get_modified_value(skill_id: String, param: String, modifiers: Dictionary) -> float:
    var base = PARAM_DEFINITIONS[skill_id][param]
    var mod = modifiers.get(param, 1.0)
    return base * mod
```

---

## 3. 伤害类型系统分析

### 3.1 当前伤害系统架构

**伤害计算：`HealthComponent.take_damage()`**
```gdscript
func take_damage(value: float) -> void:
    if current_health <= 0: return 
    current_health -= value
    # ... 触发信号和死亡逻辑
```

**玩家护甲系统：`PlayerBase.take_damage()`**
```gdscript
func take_damage(raw_amount: float) -> void:
    var damage_multiplier = 1.0 - (clamp(armor, 0, max_armor) * reduction_per_armor)
    var final_damage = max(1, raw_amount * damage_multiplier)
    health_component.take_damage(final_damage)
```


### 3.2 可行性评估

⚠️ **中等可行** - 伤害系统简单但缺少类型支持

**当前问题**：
1. **无伤害类型**：所有伤害都是单一数值，没有类型区分
2. **无元素系统**：没有火焰、冰霜、物理等伤害类型
3. **简单计算**：只有护甲减伤，没有抗性系统

**实现路径**：
1. 创建 `DamageInfo` 类封装伤害数据
2. 扩展 `take_damage()` 接受 `DamageInfo` 参数
3. 在 `UnitStats` 添加抗性属性

**示例实现**：
```gdscript
# 新建 DamageInfo 类
class_name DamageInfo

enum DamageType { PHYSICAL, FIRE, ICE, LIGHTNING, POISON }

var amount: float
var type: DamageType
var source: Node2D
var can_crit: bool = true

# 修改 HealthComponent
func take_damage_typed(damage_info: DamageInfo) -> void:
    var resistance = owner.stats.get_resistance(damage_info.type)
    var final_damage = damage_info.amount * (1.0 - resistance)
    take_damage(final_damage)
```

**风险**：
- 🔴 **高风险**：需要修改所有伤害调用点（搜索结果显示有30+处）
- ⚠️ 向后兼容性：需要保留 `take_damage(float)` 接口

---

## 4. 圣物道具系统分析（动态羁绊标签）

### 4.1 当前羁绊系统架构

**羁绊管理器：`BondManager` (autoloads/bond_manager.gd)**
```gdscript
func recalculate_active_bonds(team_player_ids: Array) -> void:
    var tag_counts = {}
    
    # 统计标签
    for player_id in team_player_ids:
        var player_data = ConfigManager.get_player_config(player_id)
        var origin = player_data.get("origin_tag", "")
        var mastery = player_data.get("mastery_tag", "")
        var tactic = player_data.get("tactic_tag", "")
        
        _increment_tag_count(tag_counts, origin)
        _increment_tag_count(tag_counts, mastery)
        _increment_tag_count(tag_counts, tactic)
```


**羁绊配置：`bond_config.csv`**
```csv
bond_id,type,level,required_count,effect_type,effect_param,effect_value
martial,origin,1,2,stat_mod,crit_chance,10
martial,origin,2,3,stat_mod,crit_damage,0.5
```

### 4.2 可行性评估

✅ **高度可行** - 羁绊系统已经完整实现

**当前架构优势**：
1. ✅ 标签统计系统已存在
2. ✅ 支持多层级羁绊（level 1, 2, 3...）
3. ✅ 已有 `is_overdrive_mode` 支持特殊激活逻辑

**实现路径**：
1. 在 `recalculate_active_bonds()` 添加 `extra_tags` 参数
2. 从 `EquipmentManager` 读取圣物道具提供的额外标签
3. 将额外标签加入 `tag_counts` 统计

**示例实现**：
```gdscript
# 修改 BondManager
func recalculate_active_bonds(team_player_ids: Array, extra_tags: Dictionary = {}) -> void:
    var tag_counts = {}
    
    # 统计角色标签
    for player_id in team_player_ids:
        # ... 原有逻辑
    
    # 添加圣物提供的额外标签
    for tag in extra_tags:
        var count = extra_tags[tag]
        if tag_counts.has(tag):
            tag_counts[tag] += count
        else:
            tag_counts[tag] = count
    
    # ... 继续激活逻辑
```

**风险**：
- ⚠️ UI 需要区分显示"角色标签"和"圣物标签"
- ⚠️ 需要防止圣物标签过度堆叠导致平衡性问题


---

## 5. 现有道具系统集成分析

### 5.1 仓库系统（Warehouse）

**当前实现：`WarehouseManager` (autoloads/warehouse_manager.gd)**
- ✅ 48槽位存储系统
- ✅ 自动压缩（无空隙）
- ✅ 持久化到 `user://warehouse_data.json`

**装备系统：`EquipmentManager` (autoloads/equipment_manager.gd)**
- ✅ 角色装备槽位管理
- ✅ 从仓库装备/卸下道具
- ✅ 持久化到 `user://equipment_data.json`

### 5.2 道具配置系统

**当前配置：`item_config.csv`**
```csv
itemType,description,resourcePath
1,神秘的红色药水 - 恢复生命值,res://assets/sprites/Item/Attribute/Icon1.png
2,蓝色魔法水晶 - 增加能量上限,res://assets/sprites/Item/Attribute/Icon2.png
```

**问题**：
- 🔴 **严重问题**：配置表只有 `itemType, description, resourcePath`
- 🔴 **缺少字段**：没有效果类型、数值、目标属性等关键数据
- 🔴 **无分类**：没有区分属性道具、魔法道具、圣物道具

### 5.3 推荐配置表重构

**新建：`item_effect_config.csv`**
```csv
item_id,item_name,item_tier,effect_type,effect_target,effect_param,effect_value,icon_path,description
attr_hp_1,生命药水,1,stat_mod,player,health,50,Icon1.png,增加50点生命值
attr_dmg_1,锋利匕首,1,stat_mod,player,damage,10,Icon4.png,增加10点攻击力
magic_fire_1,火焰之心,2,skill_mod,pyro_q,damage,0.3,Icon8.png,火焰技能伤害+30%
relic_martial_1,武道圣物,3,bond_tag,origin,martial,1,Icon10.png,提供1个武道标签
```


**字段说明**：
- `item_tier`: 1=属性道具, 2=魔法道具, 3=圣物道具
- `effect_type`: `stat_mod`（属性修改）, `skill_mod`（技能修改）, `bond_tag`（羁绊标签）
- `effect_target`: `player`（玩家属性）, `skill_id`（特定技能）, `bond_type`（羁绊类型）
- `effect_param`: 具体参数名（如 `health`, `damage`, `martial`）
- `effect_value`: 数值（加法或乘法系数）

---

## 6. 关键风险与挑战

### 6.1 高风险项

| 风险项 | 严重程度 | 影响范围 | 缓解方案 |
|--------|----------|----------|----------|
| 技能参数分散 | 🔴 高 | 所有技能类 | 创建统一参数注册表 |
| 伤害系统重构 | 🔴 高 | 30+伤害调用点 | 保留向后兼容接口 |
| 配置表缺失字段 | 🔴 高 | 道具系统核心 | 重新设计配置表结构 |

### 6.2 中风险项

| 风险项 | 严重程度 | 影响范围 | 缓解方案 |
|--------|----------|----------|----------|
| 属性修改器系统 | ⚠️ 中 | UnitStats | 扩展现有类 |
| UI 显示复杂度 | ⚠️ 中 | 仓库/装备界面 | 分阶段实现 |
| 平衡性测试 | ⚠️ 中 | 游戏体验 | 建立测试框架 |

### 6.3 低风险项

| 风险项 | 严重程度 | 影响范围 | 缓解方案 |
|--------|----------|----------|----------|
| 圣物标签系统 | ✅ 低 | BondManager | 直接扩展现有函数 |
| 仓库集成 | ✅ 低 | WarehouseManager | 已有完整实现 |

---

## 7. 推荐实施路线图

### 阶段 1：基础架构（2-3天）
1. ✅ 重构 `item_effect_config.csv` 配置表
2. ✅ 扩展 `UnitStats` 添加修改器系统
3. ✅ 创建 `ItemEffectManager` 统一管理道具效果

### 阶段 2：属性道具（1-2天）
1. ✅ 实现属性修改器应用逻辑
2. ✅ 集成 `EquipmentManager` 自动应用装备效果
3. ✅ UI 显示属性加成


### 阶段 3：魔法道具（3-4天）
1. ⚠️ 创建 `SkillParameterRegistry` 统一技能参数
2. ⚠️ 重构技能类支持参数修改器
3. ⚠️ 实现技能增强效果应用

### 阶段 4：圣物道具（1-2天）
1. ✅ 扩展 `BondManager.recalculate_active_bonds()` 支持额外标签
2. ✅ 实现圣物标签应用逻辑
3. ✅ UI 区分显示角色标签和圣物标签

### 阶段 5：伤害类型（可选，3-4天）
1. 🔴 创建 `DamageInfo` 类
2. 🔴 重构所有伤害调用点
3. 🔴 实现元素抗性系统

---

## 8. 代码示例：完整实现方案

### 8.1 道具效果管理器

```gdscript
# autoloads/item_effect_manager.gd
extends Node

# 道具效果配置 {item_id: effect_data}
var item_effects: Dictionary = {}

func _ready() -> void:
    _load_item_effects()

func _load_item_effects() -> void:
    var file = FileAccess.open("res://config/item/item_effect_config.csv", FileAccess.READ)
    if not file:
        return
    
    file.get_line()  # 跳过表头
    
    while not file.eof_reached():
        var line = file.get_csv_line()
        if line.size() < 9:
            continue
        
        var item_id = line[0]
        item_effects[item_id] = {
            "name": line[1],
            "tier": int(line[2]),
            "effect_type": line[3],
            "effect_target": line[4],
            "effect_param": line[5],
            "effect_value": float(line[6]),
            "icon_path": line[7],
            "description": line[8]
        }

func get_item_effect(item_id: String) -> Dictionary:
    return item_effects.get(item_id, {})

func apply_item_effects_to_player(player: PlayerBase, equipped_items: Array) -> void:
    # 重置修改器
    player.stats.flat_modifiers.clear()
    player.stats.mult_modifiers.clear()
    
    # 应用所有装备效果
    for item_id in equipped_items:
        var effect = get_item_effect(item_id)
        if effect.is_empty():
            continue
        
        match effect["effect_type"]:
            "stat_mod":
                _apply_stat_modifier(player, effect)
            "skill_mod":
                _apply_skill_modifier(player, effect)
            "bond_tag":
                # 圣物标签在 BondManager 中处理
                pass

func _apply_stat_modifier(player: PlayerBase, effect: Dictionary) -> void:
    var param = effect["effect_param"]
    var value = effect["effect_value"]
    
    # 判断是加法还是乘法（根据数值大小）
    if value > 10:
        # 大数值视为加法（如 +50 HP）
        player.stats.flat_modifiers[param] = player.stats.flat_modifiers.get(param, 0.0) + value
    else:
        # 小数值视为乘法（如 +30% = 0.3）
        player.stats.mult_modifiers[param] = player.stats.mult_modifiers.get(param, 1.0) * (1.0 + value)
```


### 8.2 扩展 UnitStats

```gdscript
# resouce/unit/unit_stats.gd
extends Resource
class_name UnitStats

# 基础属性
@export var health: float = 100.0
@export var damage: float = 10.0
@export var speed: float = 200.0
@export var block_chance: float = 0.0

# 新增属性
@export var crit_chance: float = 0.0
@export var crit_damage: float = 1.5
@export var cooldown_reduction: float = 0.0
@export var energy_regen: float = 0.5

# 修改器系统
var flat_modifiers: Dictionary = {}  # {stat_name: flat_value}
var mult_modifiers: Dictionary = {}  # {stat_name: multiplier}

# 获取修改后的属性值
func get_modified_health() -> float:
    return _apply_modifiers(health, "health")

func get_modified_damage() -> float:
    return _apply_modifiers(damage, "damage")

func get_modified_speed() -> float:
    return _apply_modifiers(speed, "speed")

func _apply_modifiers(base_value: float, stat_name: String) -> float:
    var flat = flat_modifiers.get(stat_name, 0.0)
    var mult = mult_modifiers.get(stat_name, 1.0)
    return (base_value + flat) * mult
```

### 8.3 集成到 PlayerBase

```gdscript
# scenes/unit/players/player_base.gd

func _ready() -> void:
    _load_config_from_csv()
    _load_sprite_from_csv()
    super._ready()
    
    # 应用装备道具效果
    _apply_equipped_items()
    
    _load_weapons_from_config()
    # ... 其他初始化

func _apply_equipped_items() -> void:
    if not EquipmentManager:
        return
    
    var equipped_items = EquipmentManager.get_equipped_items(player_id)
    ItemEffectManager.apply_item_effects_to_player(self, equipped_items)
    
    # 更新实际属性值
    stats.health = stats.get_modified_health()
    stats.speed = stats.get_modified_speed()
    # ... 更新其他属性
```


### 8.4 圣物标签集成

```gdscript
# autoloads/bond_manager.gd

# 修改现有函数
func recalculate_active_bonds(team_player_ids: Array, extra_tags: Dictionary = {}) -> void:
    var tag_counts = {}
    
    # 统计角色标签
    for player_id in team_player_ids:
        var player_data = ConfigManager.get_player_config(player_id)
        var origin = player_data.get("origin_tag", "")
        var mastery = player_data.get("mastery_tag", "")
        var tactic = player_data.get("tactic_tag", "")
        
        _increment_tag_count(tag_counts, origin)
        _increment_tag_count(tag_counts, mastery)
        _increment_tag_count(tag_counts, tactic)
    
    # 添加圣物提供的额外标签
    for tag in extra_tags:
        var count = extra_tags[tag]
        if tag_counts.has(tag):
            tag_counts[tag] += count
        else:
            tag_counts[tag] = count
    
    # 继续原有激活逻辑
    _activate_bonds_from_counts(tag_counts)

# 新增辅助函数
func get_relic_tags_from_equipment(team_player_ids: Array) -> Dictionary:
    var relic_tags = {}
    
    for player_id in team_player_ids:
        var equipped_items = EquipmentManager.get_equipped_items(player_id)
        
        for item_id in equipped_items:
            var effect = ItemEffectManager.get_item_effect(item_id)
            
            if effect.get("effect_type") == "bond_tag":
                var tag = effect["effect_param"]
                var count = int(effect["effect_value"])
                
                if relic_tags.has(tag):
                    relic_tags[tag] += count
                else:
                    relic_tags[tag] = count
    
    return relic_tags
```

---

## 9. 测试策略

### 9.1 单元测试

```gdscript
# tests/test_item_effects.gd

func test_stat_modifier_application():
    var player = PlayerBase.new()
    player.stats = UnitStats.new()
    player.stats.health = 100.0
    
    # 应用 +50 HP 道具
    var items = ["attr_hp_1"]
    ItemEffectManager.apply_item_effects_to_player(player, items)
    
    assert(player.stats.get_modified_health() == 150.0, "HP 应该增加到 150")

func test_skill_modifier_application():
    var pyro = PlayerPyro.new()
    var items = ["magic_fire_1"]  # 火焰伤害 +30%
    
    ItemEffectManager.apply_item_effects_to_player(pyro, items)
    
    var q_skill = pyro.skill_manager.get_skill("q")
    var base_damage = 20
    var modified = q_skill.get_modified_param("damage", base_damage)
    
    assert(modified == 26, "火焰伤害应该从 20 增加到 26")

func test_relic_tag_application():
    var team = ["butcher", "pyro"]
    var relic_tags = {"martial": 1}  # 圣物提供 1 个武道标签
    
    BondManager.recalculate_active_bonds(team, relic_tags)
    
    # 屠夫有 martial 标签，加上圣物的 1 个，总共 2 个
    # 应该激活 martial 的 1 级羁绊（需要 2 个）
    assert(BondManager.is_bond_active("martial", 1), "武道 1 级应该激活")
```


### 9.2 集成测试

**测试场景 1：属性道具叠加**
- 装备 3 个 +HP 道具
- 验证生命值正确累加
- 验证 UI 显示正确

**测试场景 2：技能增强**
- 装备火焰增强道具
- 使用火焰技能
- 验证伤害数值正确提升

**测试场景 3：圣物激活羁绊**
- 2 人队伍（1 个武道标签）
- 装备武道圣物（+1 标签）
- 验证武道 1 级羁绊激活

---

## 10. 性能考虑

### 10.1 潜在性能瓶颈

| 操作 | 频率 | 性能影响 | 优化方案 |
|------|------|----------|----------|
| 属性修改器计算 | 每帧 | 低 | 缓存计算结果 |
| 技能参数查询 | 技能释放时 | 低 | 预计算修改器 |
| 羁绊重新计算 | 装备变更时 | 中 | 增量更新 |
| 配置表加载 | 游戏启动时 | 低 | 一次性加载 |

### 10.2 优化建议

```gdscript
# 缓存修改后的属性值
class_name UnitStats

var _cached_health: float = -1.0
var _cache_dirty: bool = true

func get_modified_health() -> float:
    if _cache_dirty:
        _cached_health = _apply_modifiers(health, "health")
        _cache_dirty = false
    return _cached_health

func invalidate_cache() -> void:
    _cache_dirty = true
```

---

## 11. 最终结论与建议

### 11.1 总体可行性评估

| 道具类型 | 可行性 | 实施难度 | 推荐优先级 |
|----------|--------|----------|------------|
| 属性道具 | ✅ 高 | 低 | P0（立即实施） |
| 圣物道具 | ✅ 高 | 低 | P0（立即实施） |
| 魔法道具 | ⚠️ 中 | 高 | P1（第二阶段） |
| 伤害类型 | ⚠️ 中 | 高 | P2（可选） |

### 11.2 关键建议

1. **先实现属性道具和圣物道具**
   - 这两个系统风险低、收益高
   - 可以快速验证道具系统的核心玩法

2. **延后实现魔法道具**
   - 需要大规模重构技能系统
   - 建议先建立技能参数注册表
   - 逐步迁移技能类

3. **伤害类型系统作为可选扩展**
   - 需要修改 30+ 处代码
   - 对核心玩法影响较小
   - 可以在后续版本中添加

4. **重构配置表是首要任务**
   - 当前 `item_config.csv` 缺少关键字段
   - 必须先设计完整的配置表结构
   - 建议使用 `item_effect_config.csv` 新表

### 11.3 下一步行动

1. ✅ 创建 `item_effect_config.csv` 配置表
2. ✅ 实现 `ItemEffectManager` 自动加载
3. ✅ 扩展 `UnitStats` 添加修改器系统
4. ✅ 集成 `EquipmentManager` 自动应用效果
5. ⚠️ 建立测试框架验证功能

---

## 附录 A：配置表完整示例

```csv
item_id,item_name,item_tier,effect_type,effect_target,effect_param,effect_value,icon_path,description
attr_hp_1,小型生命药水,1,stat_mod,player,health,50,Icon1.png,增加50点生命值
attr_hp_2,中型生命药水,1,stat_mod,player,health,100,Icon1.png,增加100点生命值
attr_dmg_1,锋利匕首,1,stat_mod,player,damage,10,Icon4.png,增加10点攻击力
attr_speed_1,疾风靴,1,stat_mod,player,speed,50,Icon7.png,增加50点移动速度
magic_fire_dmg,火焰之心,2,skill_mod,pyro_q,damage,0.3,Icon8.png,火焰技能伤害+30%
magic_fire_dur,永恒火焰,2,skill_mod,pyro_q,duration,0.5,Icon8.png,火焰持续时间+50%
magic_saw_speed,锯齿加速器,2,skill_mod,butcher_q,rotation_speed,0.4,Icon10.png,锯条旋转速度+40%
relic_martial,武道圣物,3,bond_tag,origin,martial,1,Icon20.png,提供1个武道标签
relic_arcane,秘术圣物,3,bond_tag,origin,arcane,1,Icon21.png,提供1个秘术标签
relic_destruction,毁灭圣物,3,bond_tag,mastery,destruction,1,Icon30.png,提供1个毁灭标签
```

---

**报告生成时间**：2026-01-24  
**审计范围**：完整代码库（玩家系统、技能系统、羁绊系统、道具系统）  
**审计结论**：系统架构支持三层道具实现，建议分阶段实施，优先实现属性道具和圣物道具。
