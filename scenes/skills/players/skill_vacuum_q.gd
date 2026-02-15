extends SkillDrawingBase
class_name SkillVacuumQ

## ==============================================================================
## 吸尘器Q技能 - 传送带与磁场
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建传送带，将掉落物吸向线段中心
## - 画圈闭合：在闭合区域内创建磁场，将掉落物吸向区域中心
## 
## ==============================================================================

# ==============================================================================
# 吸尘器技能专属参数（从CSV加载）
# ==============================================================================

## 吸引力度（线段）
var pull_force: float = 250.0

## 吸引伤害
var pull_damage: int = 15

## 漩涡吸力（闭合区域）
var vortex_force: float = 400.0

## 漩涡伤害
var vortex_damage: int = 25

## 漩涡持续时间
var vortex_duration: float = 4.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成传送带效果（未闭合状态）- 吸引敌人到线段中心
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": _line_to_polygon(start, end, 24.0),
		"damage": pull_damage,
		"damage_interval": 1.0,
		"duration": _get_line_duration(),
		"color": Color(0.4, 0.2, 0.6, 0.5),
		"pull_to_center": true,
		"pull_force": pull_force
	})

## 生成磁场效果（闭合状态）- 将敌人吸向区域中心
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": vortex_damage,
		"damage_interval": 0.5,
		"duration": vortex_duration,
		"color": Color(0.3, 0.15, 0.5, 0.4),
		"pull_to_center": true,
		"pull_force": vortex_force
	})

## 获取规划线条颜色（暗紫色/灰色）
func _get_line_color() -> Color:
	return Color(0.4, 0.2, 0.6, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.3, 0.15, 0.5, 1.0)

# ==============================================================================
# 辅助方法
# ==============================================================================

## 将线段转换为多边形（用于 create_area_effect）
func _line_to_polygon(start: Vector2, end: Vector2, width: float) -> PackedVector2Array:
	var vec = end - start
	var perp = vec.normalized().rotated(PI / 2.0) * width * 0.5
	var polygon = PackedVector2Array()
	polygon.append(start + perp)
	polygon.append(end + perp)
	polygon.append(end - perp)
	polygon.append(start - perp)
	return polygon
