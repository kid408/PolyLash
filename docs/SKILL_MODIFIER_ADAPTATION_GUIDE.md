# 技能修改器适配指南

## 概述

本指南展示如何将现有技能脚本适配到**标签驱动修改器系统**，使技能参数能够被道具动态修改。

---

## 适配步骤

### 步骤 1：定义技能标签

在技能脚本顶部定义常量标签数组：

```gdscript
extends SkillBase
class_name SkillFirePath

# ==============================================================================
# 技能标签定义（用于道具修改器匹配）
# ==============================================================================

## Q技能伤害标签
const SKILL_Q_DAMAGE_TAGS = ["damage", "fire", "aoe"]

## Q技能持续时间标签
const SKILL_Q_DURATION_TAGS = ["duration", "fire"]

## Q技能宽度标签
const SKILL_Q_WIDTH_TAGS = ["size", "fire"]
```

### 步骤 2：从 CSV 加载基础参数

在 `_ready()` 函数中从 `skill_registry.csv` 加载基础数值：

```gdscript
func _ready() -> void:
	super._ready()
	
	# 从 CSV 加载基础参数
	_load_skill_params_from_csv()

func _load_skill_params_from_csv() -> void:
	var file = FileAccess.open("res://config/system/skill_registry.csv", FileAccess.READ)
	if not file:
		printerr("[SkillFirePath] 错误: 无法打开 skill_registry.csv")
		return
	
	file.get_line()  # 跳过表头
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() < 5:
			continue
		
		var skill_id = line[0]
		var param_name = line[1]
		var base_value = float(line[2])
		
		# 匹配当前技能的参数
		match skill_id:
			"pyro_q_damage":
				fire_line_damage = int(base_value)
			"pyro_q_duration":
				fire_line_duration = base_value
			"pyro_q_width":
				fire_line_width = base_value
```

### 步骤 3：使用修改器获取最终数值

在技能执行时，调用 `skill_owner.get_skill_param()` 获取经过道具加成的最终数值：

```gdscript
func _execute_dash_sequence() -> void:
	# 获取经过道具加成的伤害值
	var final_damage = skill_owner.get_skill_param(
		float(fire_line_damage),  # 基础伤害
		SKILL_Q_DAMAGE_TAGS       # 标签: ["damage", "fire", "aoe"]
	)
	
	# 获取经过道具加成的持续时间
	var final_duration = skill_owner.get_skill_param(
		fire_line_duration,       # 基础持续时间
		SKILL_Q_DURATION_TAGS     # 标签: ["duration", "fire"]
	)
	
	# 使用最终数值创建技能效果
	var effect_id = SkillEffectManager.create_line_effect({
		"start": start_pos,
		"end": end_pos,
		"width": fire_line_width,
		"damage": int(final_damage),      # 使用修改后的伤害
		"duration": final_duration,       # 使用修改后的持续时间
		"color": Color(1.0, 0.3, 0.0, 0.8)
	})
```

---

## 完整示例：SkillFirePath 适配

### 修改前（硬编码）

```gdscript
extends SkillBase
class_name SkillFirePath

var fire_line_damage: int = 20
var fire_line_duration: float = 5.0

func _execute_dash_sequence() -> void:
	var effect_id = SkillEffectManager.create_line_effect({
		"damage": fire_line_damage,      # 固定值 20
		"duration": fire_line_duration   # 固定值 5.0
	})
```

### 修改后（标签驱动）

```gdscript
extends SkillBase
class_name SkillFirePath

# 技能标签定义
const SKILL_Q_DAMAGE_TAGS = ["damage", "fire", "aoe"]
const SKILL_Q_DURATION_TAGS = ["duration", "fire"]

# 基础参数（从 CSV 加载）
var fire_line_damage: int = 20
var fire_line_duration: float = 5.0

func _ready() -> void:
	super._ready()
	_load_skill_params_from_csv()

func _load_skill_params_from_csv() -> void:
	# 从 skill_registry.csv 读取基础数值
	# （实现代码见步骤 2）
	pass

func _execute_dash_sequence() -> void:
	# 获取经过道具加成的最终数值
	var final_damage = skill_owner.get_skill_param(
		float(fire_line_damage),
		SKILL_Q_DAMAGE_TAGS
	)
	
	var final_duration = skill_owner.get_skill_param(
		fire_line_duration,
		SKILL_Q_DURATION_TAGS
	)
	
	var effect_id = SkillEffectManager.create_line_effect({
		"damage": int(final_damage),      # 动态计算
		"duration": final_duration        # 动态计算
	})
```

---

## 道具效果示例

### 场景：装备"火焰之心"道具

**道具配置**（`item_effect_config.csv`）：
```csv
magic_fire_heart,火焰之心,2,percent_add,modifier,fire,0.20,...
```

**效果**：
- 基础伤害：20
- 道具加成：+20%（因为技能标签包含 "fire"）
- 最终伤害：20 * (1.0 + 0.20) = **24**

### 场景：装备"通用伤害增幅"道具

**道具配置**：
```csv
magic_damage_boost,通用伤害增幅,2,percent_add,modifier,damage,0.15,...
```

**效果**：
- 基础伤害：20
- 道具加成：+15%（因为技能标签包含 "damage"）
- 最终伤害：20 * (1.0 + 0.15) = **23**

### 场景：同时装备多个道具（理论上，当前系统为单槽位）

如果系统支持多槽位：
- 火焰之心：+20%
- 通用伤害增幅：+15%
- 最终伤害：20 * (1.0 + 0.20 + 0.15) = **27**（加法叠加）

---

## 标签设计原则

### 1. 通用标签（跨技能）

- `damage`：所有伤害
- `duration`：所有持续时间
- `size`：所有范围/半径/宽度
- `speed`：所有速度相关

### 2. 元素标签（特定类型）

- `fire`：火焰技能
- `ice`：冰霜技能
- `physical`：物理技能
- `lightning`：雷电技能

### 3. 机制标签（特定玩法）

- `aoe`：范围伤害
- `dash`：冲刺技能
- `nova`：新星爆发
- `saw`：锯条技能
- `stake`：肉桩技能

### 4. 标签组合示例

| 技能 | 标签组合 | 说明 |
|------|----------|------|
| 火焰路径伤害 | `["damage", "fire", "aoe"]` | 火焰 + 范围伤害 |
| 锯条旋转速度 | `["speed", "saw"]` | 锯条 + 速度 |
| 冰霜新星半径 | `["size", "ice", "nova"]` | 冰霜 + 新星 + 范围 |

---

## 调试技巧

### 1. 启用调试日志

在 `ModifierManager` 中，调试日志会自动输出：

```
[ModifierManager] 添加修改器: tags=["fire"], type=percent_add, value=0.2
[ModifierManager] 数值计算: base=20.00, flat=+0.00, percent=+20.00%, final=24.00
```

### 2. 打印所有修改器

```gdscript
if OS.is_debug_build():
	skill_owner.modifier_manager.print_all_modifiers()
```

### 3. 验证标签匹配

```gdscript
var test_tags = ["damage", "fire", "aoe"]
var final_value = skill_owner.get_skill_param(20.0, test_tags)
print("最终伤害: ", final_value)
```

---

## 常见问题

### Q1: 技能参数没有被修改？

**检查清单**：
1. 确认道具已装备（`EquipmentManager.get_equipped_items()`）
2. 确认道具标签与技能标签匹配（子集关系）
3. 确认调用了 `get_skill_param()` 而不是直接使用变量
4. 启用调试日志查看修改器是否添加

### Q2: 如何支持多个参数？

为每个参数定义独立的标签数组：

```gdscript
const DAMAGE_TAGS = ["damage", "fire"]
const DURATION_TAGS = ["duration", "fire"]
const RADIUS_TAGS = ["size", "fire", "aoe"]

var final_damage = skill_owner.get_skill_param(base_damage, DAMAGE_TAGS)
var final_duration = skill_owner.get_skill_param(base_duration, DURATION_TAGS)
var final_radius = skill_owner.get_skill_param(base_radius, RADIUS_TAGS)
```

### Q3: 如何处理整数参数？

`get_skill_param()` 返回 `float`，需要转换：

```gdscript
var final_damage = int(skill_owner.get_skill_param(float(fire_line_damage), DAMAGE_TAGS))
```

---

## 迁移检查清单

- [ ] 定义技能标签常量
- [ ] 从 CSV 加载基础参数
- [ ] 替换所有直接使用参数的地方为 `get_skill_param()`
- [ ] 测试道具装备效果
- [ ] 验证数值计算正确性
- [ ] 添加调试日志（可选）

---

**完成适配后，技能将自动支持所有 Tier 2 道具的动态加成！** 🎉
