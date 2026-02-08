# 角色武器分配工具使用指南

## 功能说明

这个工具会自动为每个角色分配武器，遵循以下规则：

1. **每个角色至少3个武器**
2. **默认武器（第1个）必须唯一**：每个角色的默认武器不能和其他角色重复
3. **其他武器（第2、3个）可以重复**：可以和其他角色共享

## 当前配置

- **角色数量**：26个
- **武器数量**：35个（足够分配）
- **分配策略**：根据角色类型和角色自动匹配合适的武器

## 使用方法

### 方法1：在Godot编辑器中运行

1. 打开Godot编辑器
2. 在文件系统中找到 `tools/assign_character_weapons.gd`
3. 右键点击文件
4. 选择 "Run" 或 "运行"
5. 查看输出面板，会显示每个角色分配的武器
6. 配置文件会自动生成到 `config/player/character_weapons.csv`

### 方法2：使用命令行

```bash
# 在项目根目录运行
godot --headless --script tools/assign_character_weapons.gd
```

## 分配策略

### 默认武器分配（唯一）

根据角色类型优先分配：

- **重装**：优先分配重型近战武器
  - hammer_smash（锤击）
  - mace（钉锤）
  - axe（斧头）
  - swing_heavy（重挥击）
  - sword（剑）
  - spear（长矛）

- **魔导**：优先分配魔法武器
  - wand（魔杖）
  - magic_chain（连锁魔法）
  - magic_meteor（流星魔法）
  - laser（激光）
  - heal_bolt（治疗弹）

- **游侠**：优先分配远程或快速武器
  - pistol（手枪）
  - revolver（左轮手枪）
  - smg（冲锋枪）
  - dagger_flurry（匕首连击）
  - scimitar（弯刀）
  - bow_arrow（弓箭）

- **后勤**：优先分配支援或远程武器
  - heal_bolt（治疗弹）
  - magic_heal_aoe（治疗光环）
  - pistol（手枪）
  - shotgun（霰弹枪）
  - wand（魔杖）

### 第2个武器分配（可重复）

根据角色类型选择互补的武器：

- **重装**：添加远程武器（shotgun, pistol, revolver, laser）
- **魔导**：添加另一个魔法武器（laser, magic_chain, wand, magic_meteor）
- **游侠**：添加另一个远程武器（smg, bow_arrow, single_arc, pistol）
- **后勤**：添加支援武器（magic_heal_aoe, heal_bolt, pistol, wand）

### 第3个武器分配（可重复）

根据角色角色选择：

- **突击型**：高伤害武器（single_sniper, swing_heavy, hammer_smash, axe, shotgun）
- **支援型**：支援或控制武器（heal_bolt, magic_heal_aoe, wand, pistol）
- **指挥型**：范围或控制武器（spread_fan, magic_chain, circular_vortex, scythe_reap）

## 输出格式

生成的 `character_weapons.csv` 文件格式：

```csv
# 角色武器配置
# 格式: 角色ID,默认武器,武器2,武器3

butcher,hammer_smash,shotgun,swing_heavy
technology_hurricane,mace,pistol,axe
warrior,sword,revolver,single_sniper
pyro,wand,magic_chain,spread_fan
...
```

## 如何使用生成的配置

生成配置文件后，你需要在角色配置系统中读取这个文件：

### 选项1：修改 player_config.csv

在 `config/player/player_config.csv` 中添加武器列：

```csv
player_id,...,default_weapon,weapon_2,weapon_3
butcher,...,hammer_smash,shotgun,swing_heavy
technology_hurricane,...,mace,pistol,axe
```

### 选项2：创建独立的武器配置加载器

在 `autoloads/` 中创建一个新的管理器来加载武器配置：

```gdscript
# autoloads/character_weapon_manager.gd
extends Node

var character_weapons = {}

func _ready():
	load_weapon_config()

func load_weapon_config():
	var file = FileAccess.open("res://config/player/character_weapons.csv", FileAccess.READ)
	if not file:
		return
	
	while not file.eof_reached():
		var line = file.get_csv_line()
		if line.size() >= 4 and not line[0].begins_with("#"):
			var char_id = line[0]
			character_weapons[char_id] = {
				"default": line[1],
				"weapon_2": line[2],
				"weapon_3": line[3]
			}
	
	file.close()

func get_character_weapons(char_id: String) -> Array:
	if char_id in character_weapons:
		var weapons = character_weapons[char_id]
		return [weapons["default"], weapons["weapon_2"], weapons["weapon_3"]]
	return []
```

## 自定义分配

如果你想自定义分配策略，可以修改 `assign_character_weapons.gd` 中的以下函数：

- `_assign_default_weapon()` - 修改默认武器分配逻辑
- `_assign_secondary_weapon()` - 修改第2个武器分配逻辑
- `_assign_tertiary_weapon()` - 修改第3个武器分配逻辑

## 验证分配结果

运行工具后，检查输出：

1. **唯一性检查**：确保每个角色的默认武器都不同
2. **数量检查**：确保每个角色都有3个武器
3. **合理性检查**：确保武器类型与角色类型匹配

## 示例输出

```
========== 开始分配角色武器 ==========
屠夫 (重装 - 突击): hammer_smash, shotgun, swing_heavy
科技飓风 (重装 - 突击): mace, pistol, axe
坦克手 (重装 - 支援): axe, revolver, heal_bolt
...
========== 分配完成 ==========
总角色数: 26
总武器数: 35
已使用的唯一默认武器: 26

配置文件已生成: res://config/player/character_weapons.csv
```

## 注意事项

1. **备份原配置**：运行工具前备份现有配置
2. **检查输出**：仔细检查生成的配置是否符合预期
3. **测试游戏**：在游戏中测试每个角色的武器是否正常工作
4. **调整策略**：如果不满意，可以修改分配策略后重新运行

## 故障排除

### 问题：工具无法运行

**解决方案**：
- 确保文件路径正确
- 检查Godot版本是否支持 `@tool` 脚本
- 查看输出面板的错误信息

### 问题：生成的配置不合理

**解决方案**：
- 修改 `_assign_*_weapon()` 函数中的优先级列表
- 调整角色类型和武器类型的匹配规则
- 手动编辑生成的 CSV 文件

### 问题：某些角色没有合适的武器

**解决方案**：
- 增加武器数量（目前35个武器足够26个角色）
- 调整分配策略，允许更多武器重复
- 为特定角色手动指定武器

---

**创建时间**：2026-02-08
**工具文件**：`tools/assign_character_weapons.gd`
**输出文件**：`config/player/character_weapons.csv`
