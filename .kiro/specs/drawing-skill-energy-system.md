# Q键画线技能能量消耗系统

## 概述

Q键画线技能（牧羊人、织网者、风行者、爆破手等）使用**动态递增能量消耗**算法，随着画线距离增加，能量消耗逐渐提高。

## 配置位置

**文件：** `config/player/skill_params.csv`

相关列：
- `energy_per_10px` - 每10像素消耗的基础能量
- `energy_threshold_distance` - 能量递增阈值距离（像素）
- `energy_scale_multiplier` - 能量递增系数

### 各角色配置

| 技能ID | 角色 | energy_per_10px | energy_threshold_distance | energy_scale_multiplier |
|--------|------|-----------------|---------------------------|------------------------|
| `skill_herder_loop` | 牧羊人 | 1.0 | 1800 | 0.0005 |
| `skill_web_weave` | 织网者 | 1.0 | 1800 | 0.0006 |
| `skill_windblade_path` | 风行者 | 1.0 | 1800 | 0.0006 |
| `skill_fire_path` | 火焰法师 | 1.0 | 1800 | 0.0008 |
| `skill_mine_path` | 爆破手 | 1.0 | 1800 | 0.001 |
| `skill_saw_path` | 屠夫 | 1.0 | 1800 | 0.001 |

**说明：**
- 所有角色的基础能量消耗相同（1.0能量/10像素）
- 阈值距离都是1800像素
- 递增系数不同，影响长距离画线的能量消耗速度

## 能量消耗算法

### 算法实现

```gdscript
## 计算当前能量消耗（动态递增）
func _calculate_current_energy_cost() -> float:
	if total_distance_drawn <= energy_threshold_distance:
		# 基础阶段：固定消耗
		return energy_per_10px
	else:
		# 递增阶段：消耗逐渐增加
		var excess_distance = total_distance_drawn - energy_threshold_distance
		var multiplier = 1.0 + excess_distance * energy_scale_multiplier
		return energy_per_10px * multiplier
```

### 算法说明

#### 阶段1：基础阶段（0 - 1800像素）

- **条件：** `total_distance_drawn <= 1800`
- **消耗：** 固定 `1.0` 能量/10像素
- **总消耗：** `1800 / 10 * 1.0 = 180` 能量

#### 阶段2：递增阶段（1800像素以上）

- **条件：** `total_distance_drawn > 1800`
- **公式：** 
  ```
  excess_distance = total_distance_drawn - 1800
  multiplier = 1.0 + excess_distance * energy_scale_multiplier
  cost_per_10px = 1.0 * multiplier
  ```

### 示例计算

#### 牧羊人（energy_scale_multiplier = 0.0005）

| 总距离 | 超出距离 | 倍数 | 每10px消耗 | 说明 |
|--------|---------|------|-----------|------|
| 0 | 0 | 1.0 | 1.0 | 起始 |
| 1000 | 0 | 1.0 | 1.0 | 基础阶段 |
| 1800 | 0 | 1.0 | 1.0 | 阈值点 |
| 2000 | 200 | 1.1 | 1.1 | 开始递增 |
| 2800 | 1000 | 1.5 | 1.5 | 中等递增 |
| 3800 | 2000 | 2.0 | 2.0 | 高递增 |
| 5800 | 4000 | 3.0 | 3.0 | 极高递增 |

**计算示例（2800像素）：**
```
基础阶段：1800 / 10 * 1.0 = 180 能量
递增阶段：
  - 1800-1810: 1.0 * (1.0 + 0 * 0.0005) = 1.0
  - 1810-1820: 1.0 * (1.0 + 10 * 0.0005) = 1.005
  - ...
  - 2790-2800: 1.0 * (1.0 + 990 * 0.0005) = 1.495
  
总消耗 ≈ 180 + 积分(1800到2800) ≈ 180 + 125 = 305 能量
```

#### 爆破手（energy_scale_multiplier = 0.001）

| 总距离 | 超出距离 | 倍数 | 每10px消耗 | 说明 |
|--------|---------|------|-----------|------|
| 1800 | 0 | 1.0 | 1.0 | 阈值点 |
| 2800 | 1000 | 2.0 | 2.0 | 递增更快 |
| 3800 | 2000 | 3.0 | 3.0 | 高递增 |

**对比：** 爆破手的递增系数是牧羊人的2倍，长距离画线消耗更多能量。

## 视觉反馈

### 线条颜色变化

```gdscript
func _update_visuals() -> void:
	var final_color = Color.WHITE
	
	# 优先级1：已闭合 - 红色
	if has_closure:
		final_color = Color(1.0, 0.2, 0.2, 1.0)
	
	# 优先级2：能量不足 - 灰色
	elif skill_owner.energy < _calculate_current_energy_cost():
		final_color = Color(0.5, 0.5, 0.5, 0.5)
	
	# 优先级3：超过阈值 - 渐变橙色
	elif total_distance_drawn > energy_threshold_distance:
		var excess_ratio = (total_distance_drawn - energy_threshold_distance) / energy_threshold_distance
		excess_ratio = clamp(excess_ratio, 0.0, 1.0)
		final_color = Color.WHITE.lerp(Color.ORANGE, excess_ratio * 0.5)
	
	# 优先级4：正常 - 白色
	else:
		final_color = Color(1.0, 1.0, 1.0, 0.5)
	
	line_2d.default_color = final_color
```

### 颜色含义

| 颜色 | 含义 | 条件 |
|------|------|------|
| 白色 | 正常状态 | 距离 < 1800px，能量充足 |
| 白→橙渐变 | 能量递增警告 | 距离 > 1800px，能量充足 |
| 灰色 | 能量不足 | 当前能量 < 下一步消耗 |
| 红色 | 已闭合 | 检测到闭合区域 |

## 能量返还机制

### 右键清除路径

```gdscript
func _clear_all_points() -> void:
	# 计算已消耗的总能量（积分计算）
	var total_consumed_energy = _calculate_total_consumed_energy()
	
	# 返还能量
	if skill_owner and total_consumed_energy > 0:
		skill_owner.energy += total_consumed_energy
		skill_owner.update_ui_signals()
	
	# 清空数据
	path_points.clear()
	path_segments.clear()
	total_distance_drawn = 0.0
```

### 总能量计算

```gdscript
func _calculate_total_consumed_energy() -> float:
	var total = 0.0
	var distance = 0.0
	
	# 从起点开始，每10像素计算一次
	while distance < total_distance_drawn:
		if distance <= energy_threshold_distance:
			total += energy_per_10px
		else:
			var excess = distance - energy_threshold_distance
			var multiplier = 1.0 + excess * energy_scale_multiplier
			total += energy_per_10px * multiplier
		
		distance += POINT_INTERVAL  # 10像素
	
	return total
```

## 实时消耗流程

### 画线过程

```gdscript
func charge(delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not is_drawing:
			# 开始画线
			is_drawing = true
			total_distance_drawn = 0.0
		
		# 获取鼠标位置
		var mouse_pos = skill_owner.get_global_mouse_position()
		var distance = last_point.distance_to(mouse_pos)
		
		# 每移动10像素添加一个点
		var points_to_add = int(distance / POINT_INTERVAL)
		
		for i in range(points_to_add):
			# 计算当前能量消耗
			var current_energy_cost = _calculate_current_energy_cost()
			
			# 检查能量是否足够
			if skill_owner.energy >= current_energy_cost:
				# 消耗能量
				skill_owner.consume_energy(current_energy_cost)
				
				# 更新总距离
				total_distance_drawn += POINT_INTERVAL
				
				# 添加路径点
				var new_point = last_point + direction * POINT_INTERVAL
				path_points.append(new_point)
				last_point = new_point
			else:
				# 能量不足，停止画线
				is_drawing = false
				Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
				break
```

## 配置调整建议

### 增加基础消耗

```csv
# 让画线更昂贵
energy_per_10px = 1.5  # 从1.0改为1.5
```

### 提前触发递增

```csv
# 让递增更早开始
energy_threshold_distance = 1200  # 从1800改为1200
```

### 加快递增速度

```csv
# 让长距离画线更昂贵
energy_scale_multiplier = 0.002  # 从0.0005改为0.002
```

### 示例：高难度配置

```csv
skill_herder_loop,0,0,0,2000,1,600,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1.5,1200,0.001,0,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,2
```

**效果：**
- 基础消耗：1.5能量/10px（+50%）
- 阈值距离：1200px（-33%）
- 递增系数：0.001（+100%）

**结果：** 1800像素消耗约 270 能量（原来是180）

## 技术细节

### 点间隔

```gdscript
const POINT_INTERVAL: float = 10.0  # 每10像素记录一个点
```

### 距离累计

```gdscript
var total_distance_drawn: float = 0.0  # 已画的总距离

# 每添加一个点
total_distance_drawn += POINT_INTERVAL
```

### 能量检查

```gdscript
# 每次添加点之前检查
if skill_owner.energy >= _calculate_current_energy_cost():
	# 可以继续画线
else:
	# 能量不足，停止
```

## 相关文件

1. **技能脚本：**
   - `scenes/skills/players/skill_herder_loop.gd` - 牧羊人画圈
   - `scenes/skills/players/skill_web_weave.gd` - 织网者蛛网
   - `scenes/skills/players/skill_windblade_path.gd` - 风行者风墙
   - `scenes/skills/players/skill_fire_path.gd` - 火焰法师火线
   - `scenes/skills/players/skill_mine_path.gd` - 爆破手地雷
   - `scenes/skills/players/skill_saw_path.gd` - 屠夫锯条

2. **配置文件：**
   - `config/player/skill_params.csv` - 技能参数配置

3. **玩家基类：**
   - `scenes/unit/players/player_base.gd` - 能量系统

## 总结

Q键画线技能的能量消耗系统设计精妙：

1. **基础阶段**（0-1800px）：固定消耗，鼓励短距离画线
2. **递增阶段**（1800px+）：动态递增，限制超长画线
3. **视觉反馈**：颜色变化提示玩家能量状态
4. **能量返还**：右键清除可返还能量，降低惩罚

这个系统平衡了技能的灵活性和资源管理，让玩家需要在画线长度和能量消耗之间做出权衡。
