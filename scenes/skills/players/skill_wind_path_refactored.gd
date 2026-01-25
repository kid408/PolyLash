extends SkillDrawingBase
class_name SkillWindPathRefactored

## ==============================================================================
## 御风者Q技能 - 风墙与暴风区域（重构版）
## ==============================================================================
## 
## 功能说明:
## - 继承SkillDrawingBase，复用能量消耗和划线逻辑
## - 只需实现风系特效的生成逻辑
## - 能量消耗、闭合检测等由基类统一管理
## 
## ==============================================================================

# ==============================================================================
# 风系技能专属参数（从CSV加载）
# ==============================================================================

## 风墙吸附力度
var wind_wall_pull_force: float = 350.0

## 风墙伤害
var wind_wall_damage: int = 15

## 风墙持续时间
var wind_wall_duration: float = 3.0

## 风墙宽度
var wind_wall_width: float = 24.0

## 风墙效果半径
var wind_wall_effect_radius: float = 120.0

## 暴风区域伤害
var storm_zone_damage: int = 30

## 暴风区域吸附力度
var storm_zone_pull_force: float = 400.0

## 暴风区域持续时间
var storm_zone_duration: float = 3.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成风墙效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": wind_wall_width,
		"damage": wind_wall_damage,
		"damage_interval": 0.5,
		"duration": wind_wall_duration,
		"color": Color(0.2, 1.5, 1.5, 0.8),
		"pull_to_line": true,
		"pull_force": wind_wall_pull_force,
		"pull_interval": 0.05
	})

## 生成暴风区域效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	
	print("[SkillWindPath] 触发暴风区域！多边形点数: %d" % polygon.size())
	
	Global.spawn_floating_text(polygon[0], "STORM!", Color.CYAN)
	Global.on_camera_shake.emit(10.0, 0.3)
	
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": storm_zone_damage,
		"damage_interval": 0.5,
		"duration": storm_zone_duration,
		"color": Color(0.2, 1.2, 1.2, 0.5),
		"pull_to_center": true,
		"pull_force": storm_zone_pull_force,
		"pull_interval": 0.05,
		"z_index": 10,
		"fade_in_duration": 0.2,
		"fade_out_duration": 0.3
	})

## 获取规划线条颜色（风系青色）
func _get_line_color() -> Color:
	return Color(0.2, 1.5, 1.5, 1.0)

## 获取闭合提示颜色（高亮红色）
func _get_closure_color() -> Color:
	return Color(2.0, 0.1, 0.1, 1.0)
