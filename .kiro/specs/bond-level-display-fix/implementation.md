# 羁绊等级显示修复 - 实现方案

## 修改文件清单

1. `autoloads/bond_manager.gd` - 添加公共接口
2. `scenes/ui/components/bond_summary_item.gd` - 修改显示逻辑

## 详细实现步骤

### 步骤1：在BondManager中添加公共接口

**文件：** `autoloads/bond_manager.gd`

在文件末尾添加公共接口方法：

```gdscript
# ============================================================================
# 公共查询接口
# ============================================================================

func get_activated_level(bond_id: String, current_count: int) -> int:
	"""公共接口：获取羁绊的激活等级
	
	Args:
		bond_id: 羁绊ID
		current_count: 当前标签数量
	
	Returns:
		激活的等级（0表示未激活）
	
	Example:
		var level = BondManager.get_activated_level("martial", 3)
		# 如果martial有Level 1(需要2个)和Level 2(需要3个)
		# 返回 2
	"""
	return _get_activated_level(bond_id, current_count)

func get_next_level_required(bond_id: String, current_count: int) -> int:
	"""获取下一个等级所需的标签数量
	
	Args:
		bond_id: 羁绊ID
		current_count: 当前标签数量
	
	Returns:
		下一个等级所需的标签数量，如果已达到最高等级则返回0
	
	Example:
		var next = BondManager.get_next_level_required("martial", 1)
		# 如果当前1个标签，下一个等级需要2个
		# 返回 2
	"""
	if not bond_configs.has(bond_id):
		return 0
	
	var levels = bond_configs[bond_id].levels
	
	# 找到第一个未满足的等级
	for level_data in levels:
		if current_count < level_data.required_count:
			return level_data.required_count
	
	# 已达到最高等级
	return 0
```

### 步骤2：修改BondSummaryItem的显示逻辑

**文件：** `scenes/ui/components/bond_summary_item.gd`

修改`_update_count()`方法：

```gdscript
func _update_count() -> void:
	"""更新计数显示"""
	if not count_label:
		return
	
	# 计算激活的等级
	var activated_level = BondManager.get_activated_level(bond_id, current_count)
	
	if activated_level > 0:
		# 已激活：显示等级编号
		count_label.text = "Lv.%d" % activated_level
	else:
		# 未激活：显示进度（当前数量/下一等级需求）
		var next_required = BondManager.get_next_level_required(bond_id, current_count)
		if next_required > 0:
			count_label.text = "%d/%d" % [current_count, next_required]
		else:
			# 没有配置等级（不应该发生）
			count_label.text = "%d" % current_count
```

### 步骤3：更新颜色逻辑（可选优化）

在`_update_colors()`方法中，可以根据激活等级而不是max_count来判断颜色：

```gdscript
func _update_colors() -> void:
	"""更新颜色状态"""
	var color: Color
	
	# 计算激活的等级
	var activated_level = BondManager.get_activated_level(bond_id, current_count)
	var max_level = BondManager.get_bond_max_level(bond_id)
	
	if activated_level >= max_level and max_level > 0:
		# 已激活最高等级 - 绿色
		color = COLOR_ACTIVE
	elif activated_level > 0:
		# 激活了部分等级 - 金色
		color = COLOR_PARTIAL
	else:
		# 未激活 - 灰色
		color = COLOR_INACTIVE
	
	# 应用颜色到标签
	if name_label:
		name_label.add_theme_color_override("font_color", color)
	if count_label:
		count_label.add_theme_color_override("font_color", color)
	
	# 图标也应用颜色调制
	if icon and icon.texture:
		if activated_level >= max_level and max_level > 0:
			icon.modulate = Color.WHITE
		elif activated_level > 0:
			icon.modulate = Color(1.0, 1.0, 0.8)
		else:
			icon.modulate = Color(0.6, 0.6, 0.6)
```

## 测试验证

### 测试用例1：选择2个相同标签的角色

**输入：**
- 选择 butcher (martial) 和 windblade (martial)
- martial 标签数量 = 2

**期望输出：**
- 选择界面显示：`Lv.1`（绿色或金色）
- 战斗界面显示：`Lv.1`
- 悬浮提示显示：
  ```
  【武道世家】(当前: 2)
  [√] (2) 全队暴击率+10%
  [ ] (3) 全队暴击伤害+50%
  ```

### 测试用例2：选择3个相同标签的角色

**输入：**
- 选择 butcher (martial), windblade (martial), diva (martial)
- martial 标签数量 = 3

**期望输出：**
- 选择界面显示：`Lv.2`（绿色）
- 战斗界面显示：`Lv.2`
- 悬浮提示显示：
  ```
  【武道世家】(当前: 3)
  [√] (2) 全队暴击率+10%
  [√] (3) 全队暴击伤害+50%
  ```

### 测试用例3：选择1个角色

**输入：**
- 选择 butcher (martial)
- martial 标签数量 = 1

**期望输出：**
- 选择界面显示：`1/2`（灰色）
- 战斗界面：不显示（未激活）
- 悬浮提示显示：
  ```
  【武道世家】(当前: 1)
  [ ] (2) 全队暴击率+10%
  [ ] (3) 全队暴击伤害+50%
  ```

## 回归测试

确保以下功能不受影响：

1. ✅ 战斗界面的BondHUD显示正常
2. ✅ 羁绊效果正常激活
3. ✅ 悬浮提示显示正确
4. ✅ 颜色编码正确（绿色=已激活，金色=部分激活，灰色=未激活）
5. ✅ 大招的临时羁绊标签功能正常

## 潜在问题

### 问题1：BondManager方法是私有的

**解决方案：** 添加公共接口方法（已在步骤1中实现）

### 问题2：性能考虑

每次更新都调用`BondManager.get_activated_level()`可能有性能开销。

**优化方案：**
- 在`selection_panel.gd`的`_update_team_synergy()`中预先计算激活等级
- 将激活等级作为参数传递给`bond_summary_item.update_info()`

**优化后的代码：**

```gdscript
# 在 selection_panel.gd 中
for bond_data in sorted_bonds:
	var item = BOND_SUMMARY_ITEM.instantiate() as BondSummaryItem
	if item:
		synergy_list.add_child(item)
		
		# 预先计算激活等级
		var activated_level = BondManager.get_activated_level(
			bond_data.bond_id, 
			bond_data.count
		)
		
		item.update_info(
			bond_data.bond_id,
			bond_data.type,
			bond_data.count,
			bond_data.max,
			activated_level  # 新增参数
		)
```

```gdscript
# 在 bond_summary_item.gd 中
var activated_level: int = 0  # 新增成员变量

func update_info(
	p_bond_id: String, 
	p_bond_type: String, 
	p_current_count: int, 
	p_max_count: int,
	p_activated_level: int = -1  # 新增参数，-1表示需要计算
) -> void:
	bond_id = p_bond_id
	bond_type = p_bond_type
	current_count = p_current_count
	max_count = p_max_count
	
	# 如果没有传入激活等级，则计算
	if p_activated_level >= 0:
		activated_level = p_activated_level
	else:
		activated_level = BondManager.get_activated_level(bond_id, current_count)
	
	# ... 其余代码
```

## 完成标准

- [ ] BondManager添加公共接口方法
- [ ] BondSummaryItem修改显示逻辑
- [ ] 测试用例1通过
- [ ] 测试用例2通过
- [ ] 测试用例3通过
- [ ] 回归测试通过
- [ ] 代码审查通过
