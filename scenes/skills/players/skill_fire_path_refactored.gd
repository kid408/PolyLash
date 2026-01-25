extends SkillDrawingBase
class_name SkillFirePathRefactored

## ==============================================================================
## 烈焰者Q技能 - 火线与火海（重构版）
## ==============================================================================
## 
## 功能说明:
## - 继承SkillDrawingBase，复用能量消耗和划线逻辑
## - 只需实现火焰特效的生成逻辑
## - 能量消耗、闭合检测等由基类统一管理
## 
## ==============================================================================

# ==============================================================================
# 火焰技能专属参数（从CSV加载）
# ==============================================================================

## 火线伤害
var fire_line_damage: int = 20

## 火线持续时间
var fire_line_duration: float = 5.0

## 火线宽度
var fire_line_width: float = 24.0

## 火海伤害
var fire_sea_damage: int = 40

## 火海持续时间
var fire_sea_duration: float = 5.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成火线效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": fire_line_width,
		"damage": fire_line_damage,
		"damage_interval": 0.5,
		"duration": fire_line_duration,
		"color": Color(2.0, 1.2, 0.4, 0.9)
	})

## 生成火海效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	
	print("[SkillFirePath] 触发火海！多边形点数: %d" % polygon.size())
	
	Global.spawn_floating_text(polygon[0], "INFERNO!", Color(2.0, 1.0, 0.0))
	Global.on_camera_shake.emit(15.0, 0.4)
	
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": fire_sea_damage,
		"damage_interval": 0.3,
		"duration": fire_sea_duration,
		"color": Color(1.5, 0.7, 0.2, 0.6),
		"z_index": 10,
		"fade_in_duration": 0.2,
		"fade_out_duration": 0.3
	})

## 获取规划线条颜色（火焰金橙色）
func _get_line_color() -> Color:
	return Color(2.0, 1.0, 0.3, 1.0)

## 获取闭合提示颜色（火焰红色）
func _get_closure_color() -> Color:
	return Color(2.0, 0.1, 0.1, 1.0)
