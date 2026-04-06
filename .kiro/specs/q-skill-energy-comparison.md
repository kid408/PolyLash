# Q键技能能量消耗对比

## 概述

**不是所有角色的Q键都基于SkillHerderLoop！** 游戏中有两种不同的Q键技能类型：

1. **画线技能**（动态能量消耗）- 6个角色
2. **固定技能**（固定能量消耗）- 其他角色

## 技能分类

### 类型1：画线技能（动态能量消耗）

这些技能使用**相同的能量消耗算法**（每10像素消耗能量，超过阈值后递增），但**各自独立实现**：

| 角色 | 技能类 | 技能名称 | 基础消耗 | 阈值距离 | 递增系数 | 特点 |
|------|--------|---------|---------|---------|---------|------|
| 牧羊人 | `SkillHerderLoop` | 画圈击杀 | 1.0 | 1800 | 0.0005 | 闭合秒杀 |
| 织网者 | `SkillWebWeave` | 蛛网陷阱 | 1.0 | 1800 | 0.0006 | 减速陷阱 |
| 风行者 | `SkillWindbladePath` | 风墙路径 | 1.0 | 1800 | 0.0006 | 推进敌人 |
| 火焰法师 | `SkillFirePath` | 火线火海 | 1.0 | 1800 | 0.0008 | 持续伤害 |
| 爆破手 | `SkillMinePath` | 布雷路径 | 1.0 | 1800 | 0.001 | 地雷陷阱 |
| 屠夫 | `SkillSawPath` | 锯条路径 | 1.0 | 1800 | 0.001 | 切割伤害 |

**共同特点：**
- ✅ 按住Q进入规划模式（子弹时间）
- ✅ 按住鼠标左键画线
- ✅ 每10像素消耗能量（动态递增）
- ✅ 右键清除路径并返还能量
- ✅ 松开Q执行技能
- ✅ 支持闭合检测

**代码实现：**
```gdscript
# 每个技能都有这些参数
var energy_per_10px: float = 1.0
var energy_threshold_distance: float = 1800.0
var energy_scale_multiplier: float = 0.0005~0.001

# 每个技能都有这个方法
func _calculate_current_energy_cost() -> float:
	if total_distance_drawn <= energy_threshold_distance:
		return energy_per_10px
	else:
		var excess_distance = total_distance_drawn - energy_threshold_distance
		var multiplier = 1.0 + excess_distance * energy_scale_multiplier
		return energy_per_10px * multiplier
```

### 类型2：固定技能（固定能量消耗）

这些技能使用**固定能量消耗**，从`skill_params.csv`的`energy_cost`列读取：

| 角色 | 技能类 | 技能名称 | 能量消耗 | 冷却时间 | 特点 |
|------|--------|---------|---------|---------|------|
| 屠夫 | `SkillMeatStake` | 肉桩投掷 | 8 | 0 | 投掷控制 |
| 牧羊人 | `SkillHerderExplosion` | 爆炸 | 8 | 0 | 范围爆炸 |
| 风行者 | `SkillStormEye` | 暴风眼 | 8 | 0 | 吸附伤害 |
| 织网者 | `SkillStunBomb` | 眩晕炸弹 | 8 | 0 | 定身控制 |
| 火焰法师 | `SkillFireNova` | 烈焰新星 | 8 | 0 | 范围伤害 |
| 爆破手 | `SkillTotem` | 图腾 | 8 | 0 | 召唤物 |

**共同特点：**
- ✅ 按E键释放（不是Q键！）
- ✅ 固定能量消耗
- ✅ 瞬发或短时间释放
- ✅ 无画线机制

**代码实现：**
```gdscript
# 从SkillBase继承
func execute() -> void:
	# 消耗固定能量
	if not consume_energy():
		Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	
	# 执行技能效果
	_spawn_effect()
	
	# 开始冷却
	start_cooldown()
```

## 关键区别

### 画线技能 vs 固定技能

| 特性 | 画线技能 | 固定技能 |
|------|---------|---------|
| **按键** | Q键（蓄力） | E键（瞬发） |
| **能量消耗** | 动态递增 | 固定值 |
| **释放方式** | 按住Q+画线 | 按E释放 |
| **子弹时间** | ✅ 有 | ❌ 无 |
| **能量返还** | ✅ 右键清除返还 | ❌ 无 |
| **闭合检测** | ✅ 有 | ❌ 无 |
| **配置参数** | 3个（基础/阈值/系数） | 1个（固定消耗） |

## 配置文件对比

### skill_params.csv 结构

```csv
skill_id,energy_cost,cooldown,...,energy_per_10px,energy_threshold_distance,energy_scale_multiplier,...
```

### 画线技能配置

```csv
skill_herder_loop,0,0,...,1,1800,0.0005,...
skill_web_weave,10,0,...,1,1800,0.0006,...
skill_windblade_path,0,0,...,1,1800,0.0006,...
skill_fire_path,0,0,...,1,1800,0.0008,...
skill_mine_path,0,0,...,1,1800,0.001,...
skill_saw_path,10,0,...,1,1800,0.001,...
```

**注意：**
- `energy_cost` = 0 或 10（初始消耗，但实际使用动态计算）
- `energy_per_10px` = 1.0（基础消耗）
- `energy_threshold_distance` = 1800（阈值）
- `energy_scale_multiplier` = 0.0005~0.001（递增系数）

### 固定技能配置

```csv
skill_meat_stake,8,0,...,0,0,0,...
skill_herder_explosion,8,0,...,0,0,0,...
skill_fire_nova,8,0,...,0,0,0,...
skill_stun_bomb,8,0,...,0,0,0,...
skill_storm_eye,8,0,...,0,0,0,...
skill_totem,8,0,...,0,0,0,...
```

**注意：**
- `energy_cost` = 8（固定消耗）
- `energy_per_10px` = 0（不使用）
- `energy_threshold_distance` = 0（不使用）
- `energy_scale_multiplier` = 0（不使用）

## 代码架构

### 继承关系

```
SkillBase (基类)
├── SkillHerderLoop (画线技能)
├── SkillWebWeave (画线技能)
├── SkillWindbladePath (画线技能)
├── SkillFirePath (画线技能)
├── SkillMinePath (画线技能)
├── SkillSawPath (画线技能)
├── SkillMeatStake (固定技能)
├── SkillHerderExplosion (固定技能)
├── SkillFireNova (固定技能)
├── SkillStunBomb (固定技能)
├── SkillStormEye (固定技能)
└── SkillTotem (固定技能)
```

### 代码复用

**画线技能的能量消耗算法是复制粘贴的，不是继承的！**

每个画线技能都有**完全相同的代码**：

```gdscript
# 在每个画线技能中都有这段代码
func _calculate_current_energy_cost() -> float:
	if total_distance_drawn <= energy_threshold_distance:
		return energy_per_10px
	else:
		var excess_distance = total_distance_drawn - energy_threshold_distance
		var multiplier = 1.0 + excess_distance * energy_scale_multiplier
		return energy_per_10px * multiplier

func _calculate_total_consumed_energy() -> float:
	var total = 0.0
	var distance = 0.0
	while distance < total_distance_drawn:
		if distance <= energy_threshold_distance:
			total += energy_per_10px
		else:
			var excess = distance - energy_threshold_distance
			var multiplier = 1.0 + excess * energy_scale_multiplier
			total += energy_per_10px * multiplier
		distance += POINT_INTERVAL
	return total
```

**优化建议：** 可以将这些共同代码提取到一个基类（如`SkillDrawingBase`）中。

## 总结

### 回答你的问题

**Q: 所有角色的Q键能量都是基于SkillHerderLoop做的吗？**

**A: 不是！**

1. **画线技能**（6个）：
   - 使用**相同的算法**（动态递增能量消耗）
   - 但是**各自独立实现**（代码复制粘贴）
   - 不是继承自SkillHerderLoop
   - 都继承自SkillBase

2. **固定技能**（6个）：
   - 使用**完全不同的机制**（固定能量消耗）
   - 是E键技能，不是Q键
   - 也继承自SkillBase

### 设计模式

- **画线技能**：代码复制（Copy-Paste）
- **固定技能**：继承基类（Inheritance）

### 改进建议

创建一个中间基类来避免代码重复：

```gdscript
class_name SkillDrawingBase extends SkillBase

var energy_per_10px: float = 1.0
var energy_threshold_distance: float = 1800.0
var energy_scale_multiplier: float = 0.0005
var total_distance_drawn: float = 0.0

func _calculate_current_energy_cost() -> float:
	# 共同的能量计算逻辑
	...

func _calculate_total_consumed_energy() -> float:
	# 共同的总能量计算逻辑
	...
```

然后让所有画线技能继承这个基类：

```gdscript
class_name SkillHerderLoop extends SkillDrawingBase
class_name SkillWebWeave extends SkillDrawingBase
class_name SkillWindbladePath extends SkillDrawingBase
# ...
```

这样可以：
- ✅ 减少代码重复
- ✅ 统一能量消耗逻辑
- ✅ 更容易维护和修改
