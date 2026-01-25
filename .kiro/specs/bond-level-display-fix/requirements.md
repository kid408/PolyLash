# 羁绊等级显示不一致问题修复

## 问题描述

在角色选择界面（`selection_panel.tscn`）显示的羁绊等级是正确的（等级3），但在战斗界面（`arena.tscn`）右下角的BondHUD显示的羁绊等级却是错误的（等级2）。

## 问题分析

### 选择界面的逻辑
- 使用 `BondUILoader.calculate_team_bonds()` 统计羁绊标签数量
- 使用 `BondManager.get_bond_tooltip_text()` 显示羁绊信息
- `get_bond_tooltip_text()` 方法中的判定逻辑：
  ```gdscript
  var is_active = current_count >= required
  ```
  这个逻辑是**正确的**，它会检查所有等级并标记满足条件的等级

### 战斗界面的逻辑
- 使用 `BondManager.recalculate_active_bonds()` 计算激活的羁绊
- 使用 `BondManager._get_activated_level()` 判定激活等级
- `_get_activated_level()` 方法中的判定逻辑：
  ```gdscript
  for level_data in levels:
      if current_count >= level_data.required_count:
          activated_level = level_data.level
      else:
          break  # ⚠️ 问题在这里！
  ```
  这个`break`语句会在遇到第一个不满足条件的等级时**立即退出循环**

### 问题根源

假设有3个相同羁绊标签的角色（count = 3），羁绊配置如下：
- Level 1: required_count = 2 ✅ 满足
- Level 2: required_count = 3 ✅ 满足
- Level 3: required_count = 6 ❌ 不满足

**错误的逻辑流程：**
1. 检查 Level 1 (required=2): 3 >= 2 ✅ → activated_level = 1
2. 检查 Level 2 (required=3): 3 >= 3 ✅ → activated_level = 2
3. 检查 Level 3 (required=6): 3 >= 6 ❌ → **break退出循环**

但是，如果CSV配置中Level 3的required_count是4或5，而不是6，那么：
1. 检查 Level 1 (required=2): 3 >= 2 ✅ → activated_level = 1
2. 检查 Level 2 (required=3): 3 >= 3 ✅ → activated_level = 2
3. 检查 Level 3 (required=4): 3 >= 4 ❌ → **break退出循环**

**实际上，当前CSV配置中只有2个等级（Level 1和Level 2），所以不存在Level 3。**

让我重新检查CSV配置...

## 实际问题

查看`bond_config.csv`，每个羁绊只有2个等级：
- Level 1: required_count = 2
- Level 2: required_count = 3

如果选择了3个相同标签的角色，那么：
- 标签数量 = 3
- 应该激活 Level 2（因为 3 >= 3）
- 战斗界面显示 "Lv.2" ✅ **正确**
- 选择界面显示 "3/3" ❌ **容易误解**

### 显示差异的原因

**选择界面（`bond_summary_item.gd`）：**
- 显示格式：`count/max`
- 例如：`3/3`（3个标签 / 最高等级需要3个）
- 用户误以为这是"等级3"，但实际上是"3个标签，满足最高等级（Level 2）的要求"

**战斗界面（`bond_icon.gd`）：**
- 显示格式：`Lv.{level}`
- 例如：`Lv.2`（激活了Level 2）
- 清楚地显示激活的等级编号

**结论：两个界面显示的内容不同，导致用户误解！**
- 选择界面显示的是"标签数量/需求数量"
- 战斗界面显示的是"激活的等级编号"
- 两者都是正确的，但表达方式不一致

## 修复方案

### 推荐方案：统一显示格式为"Lv.X"

修改`bond_summary_item.gd`，使其显示激活的等级编号而不是标签数量。

**修改前：**
```gdscript
func _update_count() -> void:
	count_label.text = "%d/%d" % [current_count, max_count]
```

**修改后：**
```gdscript
func _update_count() -> void:
	# 计算激活的等级
	var activated_level = BondManager._get_activated_level(bond_id, current_count)
	
	if activated_level > 0:
		# 已激活：显示等级
		count_label.text = "Lv.%d" % activated_level
	else:
		# 未激活：显示进度
		var next_required = _get_next_level_required()
		count_label.text = "%d/%d" % [current_count, next_required]
```

### 备选方案：同时显示等级和标签数量

```gdscript
func _update_count() -> void:
	var activated_level = BondManager._get_activated_level(bond_id, current_count)
	
	if activated_level > 0:
		# 已激活：显示等级和标签数量
		count_label.text = "Lv.%d (%d)" % [activated_level, current_count]
	else:
		# 未激活：显示进度
		var next_required = _get_next_level_required()
		count_label.text = "%d/%d" % [current_count, next_required]
```

### 需要暴露的BondManager方法

`_get_activated_level`方法目前是私有的（以`_`开头），需要创建公共接口：

```gdscript
# 在 bond_manager.gd 中添加
func get_activated_level(bond_id: String, current_count: int) -> int:
	"""公共接口：获取羁绊的激活等级"""
	return _get_activated_level(bond_id, current_count)
```

## 用户故事

**作为玩家**，我希望在选择界面和战斗界面看到一致的羁绊等级显示，这样我才能准确了解当前激活的羁绊效果。

## 验收标准

1. ✅ 选择界面和战斗界面都显示"Lv.X"格式的等级编号
2. ✅ 当有3个相同标签时，两个界面都应该显示"Lv.2"
3. ✅ 未激活的羁绊应该显示进度（如"1/2"）
4. ✅ 悬浮提示应该清楚地显示每个等级的激活状态和标签数量

## 测试场景

| 标签数量 | 期望显示 | 说明 |
|---------|---------|------|
| 0 | 不显示或灰色 | 没有该羁绊 |
| 1 | 1/2 | 未激活，需要2个 |
| 2 | Lv.1 | 激活Level 1 |
| 3 | Lv.2 | 激活Level 2（最高等级）|
| 4+ | Lv.2 | 仍然是Level 2（没有更高等级）|

## 下一步

1. 确认用户期望的行为（选择界面应该显示Level 2还是Level 3？）
2. 检查`bond_summary_item.gd`的实现
3. 修复显示逻辑
4. 测试所有场景
