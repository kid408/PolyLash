# 画线技能系统快速参考

## 快速开始

### 创建新的画线技能（3步）

```gdscript
# 1. 继承基类
extends SkillDrawingBase
class_name MyNewDrawingSkill

# 2. 定义专属参数
var my_line_damage: int = 30
var my_area_damage: int = 60

# 3. 实现虚函数
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
    SkillEffectManager.create_line_effect({
        "start": start,
        "end": end,
        "damage": my_line_damage
    })

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
    SkillEffectManager.create_area_effect({
        "polygon": polygon,
        "damage": my_area_damage
    })
```

## 基类API

### 自动继承的功能

✅ **能量消耗**：动态递增算法  
✅ **划线检测**：鼠标轨迹跟踪  
✅ **闭合检测**：线段交叉和距离闭合  
✅ **视觉反馈**：Line2D绘制和颜色变化  
✅ **能量返还**：右键清除时返还能量  

### 必须实现的虚函数

```gdscript
# 生成线段效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void

# 生成区域效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void
```

### 可选重写的虚函数

```gdscript
# 自定义规划线条颜色
func _get_line_color() -> Color:
    return Color.WHITE  # 默认白色

# 自定义闭合提示颜色
func _get_closure_color() -> Color:
    return Color.RED  # 默认红色
```

## 参数配置

### CSV参数（自动加载）

```csv
skill_id,energy_per_10px,energy_threshold_distance,energy_scale_multiplier
my_skill,1,1800,0.0007
```

**参数说明**：
- `energy_per_10px`: 每10像素消耗的基础能量（通常为1.0）
- `energy_threshold_distance`: 能量递增阈值（通常为1800）
- `energy_scale_multiplier`: 能量递增系数（0.0005~0.001）

### 子类专属参数

```gdscript
# 在子类中定义
var my_line_damage: int = 30
var my_line_duration: float = 5.0
var my_area_damage: int = 60
```

## 能量消耗算法

### 公式

```gdscript
# 基础阶段（距离 <= 1800px）
energy_cost = 1.0

# 递增阶段（距离 > 1800px）
excess = distance - 1800
multiplier = 1.0 + excess * 0.0007
energy_cost = 1.0 * multiplier
```

### 示例

| 距离 | 能量消耗 | 说明 |
|------|---------|------|
| 1000px | 1.0 | 基础阶段 |
| 1800px | 1.0 | 阈值点 |
| 2000px | 1.14 | 递增阶段 |
| 3000px | 1.84 | 递增阶段 |

## 闭合检测

### 检测条件

1. **线段交叉**：任意两条不相邻线段相交
2. **距离闭合**：终点接近起点（< 60px）
3. **路径闭合**：终点接近路径中的早期点（< 60px）

### 视觉反馈

- **未闭合**：白色线条（或自定义颜色）
- **闭合**：红色线条（或自定义颜色）
- **能量不足**：灰色线条
- **超过阈值**：渐变到橙色

## 常用代码片段

### 使用SkillEffectManager

```gdscript
# 创建线段效果
SkillEffectManager.create_line_effect({
    "start": start_pos,
    "end": end_pos,
    "width": 24.0,
    "damage": 20,
    "damage_interval": 0.5,
    "duration": 5.0,
    "color": Color(2.0, 1.2, 0.4, 0.9)
})

# 创建区域效果
SkillEffectManager.create_area_effect({
    "polygon": polygon_points,
    "damage": 40,
    "damage_interval": 0.3,
    "duration": 5.0,
    "color": Color(1.5, 0.7, 0.2, 0.6),
    "z_index": 10
})

# 创建吸附效果（风墙）
SkillEffectManager.create_line_effect({
    "start": start_pos,
    "end": end_pos,
    "pull_to_line": true,
    "pull_force": 350.0,
    "pull_interval": 0.05
})

# 创建聚怪效果（暴风区）
SkillEffectManager.create_area_effect({
    "polygon": polygon_points,
    "pull_to_center": true,
    "pull_force": 400.0,
    "pull_interval": 0.05
})
```

### 使用PolygonUtils

```gdscript
# 查找所有闭合多边形
var polygons = PolygonUtils.find_all_closing_polygons(path_points, close_threshold)

# 显示闭合遮罩
PolygonUtils.show_closure_masks(polygons, Color(1.0, 0.3, 0.0, 0.7), get_tree(), 0.6)

# 计算多边形中心
var center = PolygonUtils.calculate_polygon_center(polygon)

# 计算多边形面积
var area = PolygonUtils.calculate_polygon_area(polygon)
```

### 添加视觉效果

```gdscript
# 相机震动
Global.on_camera_shake.emit(15.0, 0.4)

# 浮动文字
Global.spawn_floating_text(position, "INFERNO!", Color(2.0, 1.0, 0.0))

# 音效
Global.play_player_dash()
```

## 技能示例

### 烈焰者Q技能

```gdscript
extends SkillDrawingBase
class_name SkillFirePath

var fire_line_damage: int = 20
var fire_sea_damage: int = 40

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
    SkillEffectManager.create_line_effect({
        "start": start, "end": end,
        "damage": fire_line_damage,
        "color": Color(2.0, 1.2, 0.4, 0.9)
    })

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
    Global.spawn_floating_text(polygon[0], "INFERNO!", Color.ORANGE)
    SkillEffectManager.create_area_effect({
        "polygon": polygon,
        "damage": fire_sea_damage,
        "color": Color(1.5, 0.7, 0.2, 0.6)
    })

func _get_line_color() -> Color:
    return Color(2.0, 1.0, 0.3, 1.0)  # 金橙色
```

### 御风者Q技能

```gdscript
extends SkillDrawingBase
class_name SkillWindPath

var wind_wall_pull_force: float = 350.0
var storm_zone_pull_force: float = 400.0

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
    SkillEffectManager.create_line_effect({
        "start": start, "end": end,
        "pull_to_line": true,
        "pull_force": wind_wall_pull_force,
        "color": Color(0.2, 1.5, 1.5, 0.8)
    })

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
    Global.spawn_floating_text(polygon[0], "STORM!", Color.CYAN)
    SkillEffectManager.create_area_effect({
        "polygon": polygon,
        "pull_to_center": true,
        "pull_force": storm_zone_pull_force,
        "color": Color(0.2, 1.2, 1.2, 0.5)
    })

func _get_line_color() -> Color:
    return Color(0.2, 1.5, 1.5, 1.0)  # 青色
```

## 调试技巧

### 打印能量消耗

```gdscript
func _continue_drawing() -> void:
    var cost = _calculate_current_energy_cost()
    print("当前能量消耗: %.2f, 总距离: %.0f" % [cost, total_distance_drawn])
    # ... 其他逻辑
```

### 打印闭合检测

```gdscript
func _check_intersection_and_closure() -> void:
    if has_closure:
        return
    
    # ... 检测逻辑
    
    if _segments_intersect(latest_seg, old_seg):
        print("检测到线段交叉！线段 %d 和最新线段" % i)
        has_closure = true
```

### 打印多边形信息

```gdscript
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
    var center = PolygonUtils.calculate_polygon_center(polygon)
    var area = PolygonUtils.calculate_polygon_area(polygon)
    print("多边形: 中心=(%.1f, %.1f), 面积=%.1f, 点数=%d" % [center.x, center.y, area, polygon.size()])
    # ... 生成效果
```

## 常见问题

### Q: 如何修改能量消耗算法？

**A**: 修改 `SkillDrawingBase` 中的 `_calculate_current_energy_cost()` 函数。

### Q: 如何自定义线条颜色？

**A**: 重写 `_get_line_color()` 和 `_get_closure_color()` 函数。

### Q: 如何添加新的画线技能？

**A**: 继承 `SkillDrawingBase`，实现 `_spawn_line_effect()` 和 `_spawn_area_effect()`。

### Q: 如何调整能量递增速度？

**A**: 修改CSV中的 `energy_scale_multiplier` 参数（值越大递增越快）。

### Q: 如何调整闭合判定距离？

**A**: 修改 `close_threshold` 参数（默认60像素）。

## 性能优化

### 避免频繁创建节点

```gdscript
# ❌ 不好：每帧创建新节点
func _process(delta):
    var line = Line2D.new()
    add_child(line)

# ✅ 好：复用现有节点
func _ready():
    line_2d = Line2D.new()
    add_child(line_2d)

func _process(delta):
    line_2d.clear_points()
    # 更新点
```

### 使用SkillEffectManager

```gdscript
# ✅ 好：使用统一的效果管理器
SkillEffectManager.create_line_effect({...})

# ❌ 不好：手动管理效果生命周期
var area = Area2D.new()
add_child(area)
# ... 需要手动清理
```

### 批量处理

```gdscript
# ✅ 好：一次性处理所有多边形
var polygons = PolygonUtils.find_all_closing_polygons(path_points, close_threshold)
for polygon in polygons:
    _spawn_area_effect(polygon)

# ❌ 不好：多次查找
for i in range(path_points.size()):
    var polygon = _find_polygon_at(i)
    if polygon:
        _spawn_area_effect(polygon)
```

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2026-01-25 | 初始版本 |

---

**快速链接**：
- [完整文档](DRAWING_SKILL_REFACTORING.md)
- [对比文档](DRAWING_SKILL_COMPARISON.md)
- [迁移指南](DRAWING_SKILL_MIGRATION_GUIDE.md)
