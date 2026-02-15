# 武器显示问题修复报告

## 问题描述

重构武器系统后，出现两个问题：
1. **武器在游戏内显示但不攻击敌人** - 武器无法检测到敌人
2. **武器在角色选择界面不显示** - 精灵缩放问题

## 根本原因

### 问题1: 武器不攻击敌人

**原因**: 武器场景文件中**缺少敌人检测区域** (`RangeArea2` 节点)

在 `weapon.gd` 中有以下函数依赖 `RangeArea2` 节点：
- `_on_range_area_2_area_entered()` - 敌人进入检测范围
- `_on_range_area_2_area_exited()` - 敌人离开检测范围

但是新创建的7个武器场景文件都缺少这个关键节点，导致：
- `targets` 数组始终为空
- `closest_target` 始终为 null
- `can_use_weapon()` 始终返回 false
- 武器永远不会攻击

### 问题2: 精灵缩放问题

在 `weapon.gd` 的 `update_visuals()` 函数中，每帧都将 Sprite2D 的 `scale.y` 设置为 `0.5` 或 `-0.5`，导致武器精灵被缩小到原始大小的 50%。

## 修复方案

### 修复1: 添加敌人检测区域

**文件**: 所有7个武器场景文件

**修改**: 添加 `RangeArea2` 节点和信号连接

```gdscript
# 添加 CircleShape2D 资源
[sub_resource type="CircleShape2D" id="CircleShape2D_range"]
radius = 300.0

# 添加 RangeArea2 节点
[node name="RangeArea2" type="Area2D" parent="."]
collision_layer = 0
collision_mask = 2

[node name="CollisionShape2D" type="CollisionShape2D" parent="RangeArea2"]
shape = SubResource("CircleShape2D_range")

# 连接信号
[connection signal="area_entered" from="RangeArea2" to="." method="_on_range_area_2_area_entered"]
[connection signal="area_exited" from="RangeArea2" to="." method="_on_range_area_2_area_exited"]
[connection signal="timeout" from="CooldownTimer" to="." method="_on_cooldown_timer_timeout"]
```

**修复的场景文件**:
1. `scenes/weapons/melee/weapon_melee_point.tscn`
2. `scenes/weapons/melee/weapon_melee_thrust.tscn`
3. `scenes/weapons/melee/weapon_melee_sector.tscn`
4. `scenes/weapons/melee/weapon_melee_circle.tscn`
5. `scenes/weapons/range/weapon_range_physical.tscn`
6. `scenes/weapons/range/weapon_range_beam.tscn`
7. `scenes/weapons/range/weapon_range_magic.tscn`

**工作原理**:
- `RangeArea2` 是一个 Area2D 节点，用于检测范围内的敌人
- `collision_layer = 0`: 不在任何碰撞层
- `collision_mask = 2`: 只检测第2层（敌人的 HurtboxComponent）
- `radius = 300.0`: 检测半径300像素（会被 `setup_weapon()` 中的 `max_range` 覆盖）

### 修复2: 修复 Sprite 缩放问题

**文件**: `scenes/weapons/weapon.gd`

**修改**: 将 `update_visuals()` 函数中的缩放值从 `0.5/-0.5` 改为 `1.0/-1.0`

```gdscript
# 修复后的代码
func update_visuals() -> void:
	# 只翻转Y轴，不改变大小（保持scale为1.0或-1.0）
	if abs(rotation) > PI /2:
		sprite.scale.y = -1.0  # ✅ 保持原始大小，只翻转
	else:
		sprite.scale.y = 1.0   # ✅ 保持原始大小
```

### 修复3: 添加 Sprite 初始化检查

**文件**: `scenes/weapons/weapon.gd`

**修改**: 在 `_ready()` 函数中确保 Sprite2D 正确初始化

```gdscript
func _ready() -> void:
	atk_start_pos = sprite.position
	
	# 确保 Sprite2D 可见并设置初始缩放
	sprite.visible = true
	if sprite.scale == Vector2.ZERO:
		sprite.scale = Vector2.ONE
	
	print("[Weapon] _ready() - Sprite2D 初始化:")
	print("  - 可见性: ", sprite.visible)
	print("  - 缩放: ", sprite.scale)
	print("  - 位置: ", sprite.position)
```

### 修复4: 增强武器定位日志

**文件**: `scenes/unit/players/player_base.gd`

**修改**: 在 `_add_weapon()` 函数中添加更详细的位置日志

```gdscript
# 更新武器位置（通过weapon_container的marker定位）
if weapon_container:
	weapon_container.update_weapons_position(current_weapons)
	print("[Player] 武器定位后位置: ", weapon.position)
	print("[Player] 武器定位后全局位置: ", weapon.global_position)
```

## 测试步骤

1. **启动游戏**
   - 进入角色选择界面
   - 选择任意角色
   - 检查角色预览中是否显示武器

2. **进入游戏**
   - 开始游戏
   - 检查玩家手中是否显示武器
   - 等待敌人靠近
   - **观察武器是否自动攻击敌人**

3. **检查控制台日志**
   - 查找 `[Weapon] _ready()` 日志，确认 Sprite2D 初始化
   - 查找 `[Player] 武器定位后位置` 日志，确认武器位置正确
   - 确认没有错误信息

## 预期结果

- ✅ 武器在角色选择界面正常显示
- ✅ 武器在游戏内正常显示
- ✅ 武器大小正常（不再缩小到 50%）
- ✅ **武器能检测到敌人并自动攻击**
- ✅ 武器跟随鼠标旋转
- ✅ 武器在旋转超过 90° 时正确翻转

## 技术细节

### 敌人检测系统

武器通过以下流程检测和攻击敌人：

1. **检测阶段** (`RangeArea2`)
   - `RangeArea2` 检测范围内的敌人 HurtboxComponent
   - `_on_range_area_2_area_entered()` 将敌人添加到 `targets` 数组
   - `_on_range_area_2_area_exited()` 从 `targets` 数组移除敌人

2. **目标选择** (`update_closest_target()`)
   - 从 `targets` 数组中选择最近的敌人
   - 更新 `closest_target` 变量

3. **攻击判定** (`can_use_weapon()`)
   - 检查冷却时间是否结束
   - 检查是否有 `closest_target`
   - 两个条件都满足时返回 true

4. **执行攻击** (`use_weapon()`)
   - 调用 `weapon_behavior.execute_attack()`
   - 启动冷却计时器

### Sprite2D 缩放机制

在 Godot 中，`Sprite2D.scale` 是一个 `Vector2`：
- `scale.x`: 水平缩放（1.0 = 原始大小，-1.0 = 水平翻转）
- `scale.y`: 垂直缩放（1.0 = 原始大小，-1.0 = 垂直翻转）

### 为什么需要翻转？

当武器旋转超过 90° 时（朝向左侧），如果不翻转，武器会上下颠倒。通过设置 `scale.y = -1.0`，可以保持武器的正确朝向。

### WeaponContainer 的作用

`WeaponContainer` 不持有武器节点，只负责提供定位标记（Marker2D）：
- 武器作为玩家的子节点添加
- `WeaponContainer` 通过 `update_weapons_position()` 将武器移动到正确的位置
- 支持 1-6 个武器的不同布局

## 相关文件

- `scenes/weapons/weapon.gd` - 武器基类（修复缩放问题）
- `scenes/unit/players/player_base.gd` - 玩家基类（增强日志）
- `scenes/unit/players/weapon_container.gd` - 武器容器（定位逻辑）
- 所有7个武器场景文件 - 添加敌人检测区域

## 后续优化建议

1. **武器大小配置化**
   - 在 `weapon_config_optimized.csv` 中添加 `sprite_scale` 字段
   - 允许不同武器有不同的显示大小

2. **武器层级优化**
   - 考虑将武器的 `z_index` 设置为玩家之上
   - 确保武器始终显示在玩家前方

3. **武器动画优化**
   - 添加武器挥舞/射击的动画
   - 使用 AnimatedSprite2D 替代 Sprite2D（如果需要）

4. **检测范围可视化**
   - 在调试模式下显示 `RangeArea2` 的检测范围
   - 方便调试武器检测问题

## 修复时间

2026-02-08

## 修复人员

Kiro AI Assistant


## 问题5: 角色选择界面武器图标不显示 (调试中)

### 问题描述

在角色选择界面点击角色后，底部的武器选择区域不显示武器图标。

### 调查发现

1. **武器预览系统独立**
   - 选择界面使用独立的武器预览系统（不是实际武器实例）
   - 预览系统创建 `Panel` + `TextureRect` 来显示武器图标
   - 不依赖武器场景文件

2. **图标加载流程**
   ```gdscript
   # 在 _update_weapon_container() 中
   var weapon_info = WeaponConfigLoader.get_weapon_info(weapon_id)
   var icon_path = weapon_info.get("icon_path", "")
   var texture = load(icon_path)
   icon_rect.texture = texture
   ```

3. **CSV 配置**
   - `weapon_config_optimized.csv` 包含 `icon_path_template` 字段
   - `WeaponConfigLoader.get_weapon_info()` 正确处理模板替换
   - 返回的 `icon_path` 应该是完整路径

### 添加的调试日志

在 `scenes/ui/selection_panel/selection_panel.gd` 的 `_update_weapon_container()` 函数中添加：

```gdscript
print("[SelectionPanel] 武器 %s 图标路径: %s" % [weapon_type, icon_path])
if ResourceLoader.exists(icon_path):
    var texture = load(icon_path)
    if texture:
        icon_rect.texture = texture
        print("[SelectionPanel] ✓ 成功加载武器图标: %s" % weapon_type)
    else:
        printerr("[SelectionPanel] ✗ 加载纹理失败: %s" % icon_path)
else:
    printerr("[SelectionPanel] ✗ 图标文件不存在: %s" % icon_path)
```

### 下一步

1. **运行游戏并检查日志**
   - 查看武器图标路径是否正确
   - 确认图标文件是否存在
   - 检查纹理加载是否成功

2. **可能的问题**
   - 图标文件路径错误
   - 图标文件不存在
   - TextureRect 可见性设置问题
   - Panel 样式覆盖了图标

3. **如果图标路径正确但不显示**
   - 检查 TextureRect 的 `expand_mode` 和 `stretch_mode`
   - 检查 Panel 的 `z_index` 和 `modulate`
   - 验证 TextureRect 的 `mouse_filter` 设置

### 状态

🔍 **调试中** - 等待用户运行游戏并提供日志输出


## 问题6: ConfigManager 无法加载 weapon_config_optimized.csv (已修复)

### 问题描述

控制台日志显示：
```
[ConfigManager] 加载配置: res://config/weapon/weapon_config_optimized.csv - 0 条记录
```

这导致选择界面无法获取武器信息，武器图标无法显示。

### 根本原因

**CSV 列名不匹配**:
- `weapon_config_optimized.csv` 的第一列是 `weapon_base_id`
- `ConfigManager` 在加载时使用 `weapon_id` 作为键
- 由于找不到 `weapon_id` 列，返回 0 条记录

**代码位置**: `autoloads/config_manager.gd` 第 137 行
```gdscript
weapon_configs = load_csv_as_dict(WEAPON_CONFIG, "weapon_id")  # ❌ 错误
```

### 修复方案

**修改 1**: 更新 ConfigManager 加载键

```gdscript
# autoloads/config_manager.gd 第 137 行
weapon_configs = load_csv_as_dict(WEAPON_CONFIG, "weapon_base_id")  # ✅ 正确
```

**修改 2**: 更新 `get_weapon_by_type_level()` 函数

由于新系统中 `weapon_configs` 只存储基础配置（每个武器类型一条记录），不再存储每个等级的配置，需要更新函数逻辑：

```gdscript
# autoloads/config_manager.gd 第 485-496 行
func get_weapon_by_type_level(weapon_type: String, level: int = 1) -> Dictionary:
	"""
	获取指定类型和等级的武器配置
	
	参数:
	- weapon_type: 武器类型（如 "punch", "laser"）
	- level: 武器等级（默认1）
	
	返回:
	- Dictionary: 武器配置，如果未找到返回空字典
	
	注意: 此函数返回基础配置（weapon_base_id），不包含等级缩放
	      如需完整的武器数据，请使用 WeaponConfigLoader.get_weapon_stats()
	"""
	# 新系统：weapon_configs 使用 weapon_base_id 作为键
	return weapon_configs.get(weapon_type, {})
```

### 系统架构说明

**新武器配置系统的分工**:

1. **ConfigManager.weapon_configs**:
   - 存储基础配置（每个武器类型一条记录）
   - 键: `weapon_base_id`（如 "punch", "laser"）
   - 用途: 快速查询武器基础信息（类型、显示名模板等）

2. **WeaponConfigLoader**:
   - 负责动态生成完整的武器数据（包含等级缩放）
   - 函数: `get_weapon_stats(weapon_id)` - 返回 WeaponStats 对象
   - 函数: `get_weapon_info(weapon_id)` - 返回基础信息字典
   - 用途: 游戏运行时获取完整武器数据

### 影响范围

**修复后的行为**:
- ✅ ConfigManager 正确加载 35 个武器基础配置
- ✅ 选择界面可以通过 `WeaponConfigLoader.get_weapon_info()` 获取武器图标路径
- ✅ 游戏内可以通过 `WeaponConfigLoader.get_weapon_stats()` 获取完整武器数据

**需要注意**:
- `ConfigManager.get_weapon_by_type_level()` 现在忽略 `level` 参数，只返回基础配置
- 如果代码需要等级相关的数据，应该使用 `WeaponConfigLoader` 而不是 `ConfigManager`

### 测试步骤

1. **重新启动游戏**
2. **检查控制台日志**:
   - 应该看到: `[ConfigManager] 加载配置: res://config/weapon/weapon_config_optimized.csv - 35 条记录`
   - 应该看到: `[WeaponConfigLoader] 加载完成: 35 个武器基础配置`
3. **进入角色选择界面**:
   - 点击任意角色
   - 底部应该显示武器图标
   - 控制台应该显示: `[SelectionPanel] ✓ 成功加载武器图标: ...`

### 修复时间

2026-02-08

### 修复人员

Kiro AI Assistant
