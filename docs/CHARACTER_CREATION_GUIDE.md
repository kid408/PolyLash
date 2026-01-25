# 角色创建完整指南

## 核心问题：单纯配表能否完成新角色添加？

**答案：可以，但有限制条件**

---

## 一、纯CSV配置可行性分析

### ✅ 理论上可行的情况

如果满足以下条件，**纯CSV配置即可创建新角色**：

1. **使用现有技能**：新角色的Q/E/LMB技能都是已存在的技能类
2. **无特殊逻辑**：不需要角色特定的行为（如屠夫的切线逻辑）
3. **标准输入处理**：使用PlayerBase的默认输入处理即可
4. **无自定义参数**：技能参数都能从CSV加载，不需要@export变量

### ❌ 必须写代码的情况

以下情况**必须创建角色脚本**：

1. **新技能**：需要创建新的技能类（继承SkillBase）
2. **特殊交互**：角色间的特殊交互（如屠夫被LineBreaker切线）
3. **自定义参数**：技能需要从角色脚本读取@export参数
4. **特殊输入**：非标准的输入处理逻辑
5. **状态管理**：需要维护角色特定的状态变量

---

## 二、角色创建流程详解

### 方案A：纯CSV配置（最简单）

**适用场景**：组合现有技能创建新角色

#### 步骤1：配置基础属性
**文件**：`config/player/player_config.csv`

```csv
player_id,name,max_hp,max_energy,speed,energy_regen,enabled
new_hero,新英雄,100,100,300,10,true
```

#### 步骤2：配置视觉效果
**文件**：`config/player/player_visual.csv`

```csv
player_id,sprite_path,sprite_scale,color_modulate
new_hero,res://assets/sprites/Player_1.png,1.0,#ffffff
```

#### 步骤3：绑定技能
**文件**：`config/player/player_skill_bindings.csv`

```csv
player_id,slot_q,slot_e,slot_lmb,slot_rmb
new_hero,skill_fire_path,skill_fire_nova,skill_dash,
```

#### 步骤4：配置技能参数
**文件**：`config/player/skill_params.csv`

```csv
skill_id,player_id,energy_cost,cooldown,damage,duration,...
skill_fire_path,new_hero,50,5,20,5,...
skill_fire_nova,new_hero,30,3,35,3,...
skill_dash,new_hero,10,1,0,0,...
```

#### 步骤5：配置武器
**文件**：`config/player/player_weapons.csv`

```csv
player_id,weapon_id,unlock_level
new_hero,weapon_pistol,1
new_hero,weapon_shotgun,5
```

**文件**：`config/player/player_available_weapons.csv`

```csv
player_id,weapon_pistol,weapon_shotgun,weapon_smg,...
new_hero,true,true,false,...
```

#### 测试

```gdscript
# 在游戏中创建角色
var player = PlayerFactory.create_player("new_hero")
get_tree().root.add_child(player)
```

**结果**：
- ✅ 角色会使用 `PlayerBase` 作为脚本
- ✅ 技能系统会自动加载配置的技能
- ✅ 所有CSV参数会正确应用
- ⚠️ 工厂会打印警告：`"未找到角色脚本 player_new_hero.gd，使用默认 PlayerBase"`

---

### 方案B：CSV + 自定义脚本（推荐）

**适用场景**：需要特殊逻辑或新技能

#### 步骤1-5：同方案A

#### 步骤6：创建角色脚本
**文件**：`scenes/unit/players/player_new_hero.gd`

```gdscript
extends PlayerBase
class_name PlayerNewHero

## ==============================================================================
## 新英雄 - 使用技能系统
## ==============================================================================

# ==============================================================================
# 配置参数（供技能类读取）
# ==============================================================================

@export_group("New Hero Settings")
@export var special_param: float = 100.0
@export var custom_duration: float = 5.0

# ==============================================================================
# 技能管理器
# ==============================================================================
var skill_manager: SkillManager

# ==============================================================================
# 生命周期
# ==============================================================================

func _ready() -> void:
	super._ready()
	
	# 初始化技能管理器
	skill_manager = SkillManager.new(self)
	skill_manager.debug_mode = false
	add_child(skill_manager)
	skill_manager.load_skills_from_config("new_hero")

# ==============================================================================
# 输入处理
# ==============================================================================
func _handle_input(delta: float) -> void:
	# 1. 移动逻辑
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if can_move():
		var current_speed = speed
		position += move_dir * current_speed * delta
	
	# 2. 技能按键分发
	if not skill_manager:
		return
	
	# F键 - 大招
	if Input.is_action_just_pressed("skill_f"):
		if ultimate_skill:
			ultimate_skill.try_activate()
		else:
			Global.spawn_floating_text(global_position, "大招未实现", Color.GRAY)
		return
	
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
	
	# 左键冲刺
	if Input.is_action_just_pressed("click_left"):
		skill_manager.execute_skill("lmb")

# ==============================================================================
# 自定义逻辑（可选）
# ==============================================================================

## 示例：特殊交互
func on_special_event() -> void:
	print("[PlayerNewHero] 触发特殊事件")
	# 自定义逻辑...
```

#### 步骤7：创建新技能（如果需要）
**文件**：`scenes/skills/players/skill_new_ability.gd`

```gdscript
extends SkillBase
class_name SkillNewAbility

## ==============================================================================
## 新技能 - 示例
## ==============================================================================

# 从CSV加载的参数
var damage: int = 50
var radius: float = 200.0
var duration: float = 3.0

func execute() -> void:
	if not can_execute():
		return
	
	# 消耗能量
	consume_energy()
	
	# 技能逻辑
	print("[SkillNewAbility] 执行技能")
	
	# 启动冷却
	start_cooldown()
```

---

## 三、关键代码流程分析

### PlayerFactory.create_player() 流程

```gdscript
func create_player(player_id: String) -> PlayerBase:
	# 1. 加载通用场景 player_generic.tscn
	var scene = load(PLAYER_GENERIC_SCENE)
	
	# 2. 实例化（此时使用PlayerBase脚本）
	var player = scene.instantiate() as PlayerBase
	
	# 3. 设置player_id
	player.player_id = player_id
	
	# 4. 尝试加载角色特定脚本
	var script_path = "res://scenes/unit/players/player_%s.gd" % player_id
	var script = load(script_path)
	
	if script:
		player.set_script(script)  # 替换为自定义脚本
	else:
		# ⚠️ 打印警告，但继续使用PlayerBase
		print("警告: 未找到角色脚本，使用默认 PlayerBase")
	
	return player
```

### PlayerBase._ready() 流程

```gdscript
func _ready() -> void:
	# 1. 从CSV加载基础属性
	_load_config()
	
	# 2. 初始化组件
	_setup_components()
	
	# 3. 加载视觉效果
	_load_visual_config()
	
	# 4. 加载武器
	_load_weapons()
	
	# 5. 加载大招
	_load_ultimate_skill()
	
	# ⚠️ 注意：PlayerBase不会自动创建SkillManager
	# 需要在子类中手动创建
```

### 子类脚本的作用

```gdscript
# player_pyro.gd
func _ready() -> void:
	super._ready()  # 调用PlayerBase._ready()
	
	# ✅ 创建技能管理器（这是关键！）
	skill_manager = SkillManager.new(self)
	add_child(skill_manager)
	skill_manager.load_skills_from_config("pyro")
```

---

## 四、纯CSV配置的局限性

### 问题1：技能管理器不会自动创建

**现象**：
- 纯CSV配置的角色没有Q/E/LMB技能
- 只有大招（F键）和武器（右键）可用

**原因**：
- `PlayerBase._ready()` 不会创建 `SkillManager`
- 需要在子类脚本中手动创建

**解决方案**：
1. 修改 `PlayerBase._ready()` 自动创建SkillManager（推荐）
2. 或者为每个角色创建最小脚本

### 问题2：无法访问角色特定参数

**现象**：
- 技能无法读取角色的@export参数
- 例如：`skill_owner.stake_duration` 会报错

**原因**：
- PlayerBase没有定义这些参数
- 只有子类脚本才有

**解决方案**：
- 将所有参数移到CSV（推荐）
- 或者创建角色脚本定义参数

### 问题3：无法实现特殊交互

**现象**：
- 无法实现角色间的特殊交互
- 例如：屠夫的`try_break_line()`方法

**原因**：
- PlayerBase没有这些方法
- 需要在子类中实现

**解决方案**：
- 必须创建角色脚本

---

## 五、推荐的改进方案

### 改进1：让PlayerBase自动创建SkillManager

**修改**：`scenes/unit/players/player_base.gd`

```gdscript
func _ready() -> void:
	# ... 现有代码 ...
	
	# ✅ 自动创建技能管理器
	if not has_node("SkillManager"):
		var skill_manager = SkillManager.new(self)
		skill_manager.name = "SkillManager"
		add_child(skill_manager)
		skill_manager.load_skills_from_config(player_id)
		print("[PlayerBase] 自动创建技能管理器: %s" % player_id)
```

**效果**：
- ✅ 纯CSV配置即可创建完整角色
- ✅ 子类脚本仍可覆盖（如果需要）
- ✅ 向后兼容现有角色

### 改进2：创建角色创建工具

**文件**：`tools/create_character.gd`

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var character_id = "new_hero"
	var character_name = "新英雄"
	
	# 1. 创建CSV配置
	_add_to_csv("config/player/player_config.csv", {
		"player_id": character_id,
		"name": character_name,
		"max_hp": 100,
		"max_energy": 100,
		"speed": 300,
		"energy_regen": 10,
		"enabled": true
	})
	
	# 2. 创建角色脚本模板
	_create_script_template(character_id, character_name)
	
	print("✅ 角色创建完成: %s" % character_id)

func _create_script_template(id: String, name: String) -> void:
	var template = """
extends PlayerBase
class_name Player%s

## %s

var skill_manager: SkillManager

func _ready() -> void:
	super._ready()
	skill_manager = SkillManager.new(self)
	add_child(skill_manager)
	skill_manager.load_skills_from_config("%s")

func _handle_input(delta: float) -> void:
	# 移动
	move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if can_move():
		position += move_dir * speed * delta
	
	if not skill_manager:
		return
	
	# 技能
	if Input.is_action_just_pressed("skill_f"):
		if ultimate_skill:
			ultimate_skill.try_activate()
	elif Input.is_action_just_pressed("skill_e"):
		skill_manager.execute_skill("e")
	elif Input.is_action_pressed("skill_q"):
		skill_manager.charge_skill("q", delta)
	elif Input.is_action_just_released("skill_q"):
		skill_manager.release_skill("q")
	elif Input.is_action_just_pressed("click_left"):
		skill_manager.execute_skill("lmb")
"""
	
	var class_name = id.capitalize().replace(" ", "")
	var content = template % [class_name, name, id]
	
	var file = FileAccess.open("res://scenes/unit/players/player_%s.gd" % id, FileAccess.WRITE)
	file.store_string(content)
	file.close()
```

---

## 六、最终答案

### 问题：单纯配表能否完成新角色添加？

**答案：理论上可以，但实际上不推荐**

#### ✅ 可以的部分
- 基础属性（HP、能量、速度）
- 视觉效果（精灵、颜色）
- 武器配置
- 大招（F键）

#### ❌ 不可以的部分（当前实现）
- Q/E/LMB技能（因为PlayerBase不创建SkillManager）
- 角色特定参数（@export变量）
- 特殊交互逻辑

#### 🔧 推荐方案

**短期**：为每个角色创建最小脚本（50行代码）
- 复制现有角色脚本模板
- 修改class_name和player_id
- 5分钟完成

**长期**：改进PlayerBase自动创建SkillManager
- 修改1处代码
- 之后纯CSV即可创建角色
- 向后兼容

---

## 七、对比：当前 vs 改进后

### 当前流程（需要代码）

```
1. 配置5个CSV文件（player_config, visual, bindings, weapons, available_weapons）
2. 配置skill_params.csv（每个技能）
3. ✅ 创建角色脚本（50行模板代码）
4. 测试

总耗时：15-20分钟
```

### 改进后流程（纯CSV）

```
1. 配置5个CSV文件
2. 配置skill_params.csv
3. 测试

总耗时：5-10分钟
```

### 改进后流程（带工具）

```
1. 运行工具脚本：create_character("new_hero", "新英雄")
2. 手动调整CSV参数
3. 测试

总耗时：3-5分钟
```

---

## 八、总结

### 当前状态评分

| 维度 | 评分 | 说明 |
|------|------|------|
| 纯CSV可行性 | 6/10 | 理论可行，但缺少SkillManager自动创建 |
| 代码复杂度 | 8/10 | 模板代码简单，但仍需手动创建 |
| 配置灵活性 | 9/10 | CSV配置非常灵活 |
| 新手友好度 | 6/10 | 需要理解脚本结构 |
| 维护成本 | 7/10 | 模板代码重复，但易于维护 |

### 改进后评分

| 维度 | 评分 | 说明 |
|------|------|------|
| 纯CSV可行性 | 9/10 | 完全支持纯CSV创建 |
| 代码复杂度 | 9/10 | 无需手动代码 |
| 配置灵活性 | 9/10 | 保持不变 |
| 新手友好度 | 9/10 | 策划可独立完成 |
| 维护成本 | 9/10 | 无重复代码 |

### 建议

1. **立即实施**：修改PlayerBase自动创建SkillManager（1小时工作量）
2. **中期实施**：创建角色创建工具（2小时工作量）
3. **长期优化**：考虑可视化编辑器（1周工作量）

---

**文档版本**：1.0  
**创建日期**：2026-01-25  
**作者**：Kiro AI Assistant
