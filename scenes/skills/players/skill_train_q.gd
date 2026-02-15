extends SkillDrawingBase
class_name SkillTrainQ

## ==============================================================================
## 火车王Q技能 - 幽灵轨道与旋转光束
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建幽灵轨道，延迟1秒后沿轨道释放冲击波造成大量伤害
## - 画圈闭合：在闭合区域内创建旋转光束，持续对区域内敌人造成伤害
## 
## ==============================================================================

# ==============================================================================
# 火车王技能专属参数（从CSV加载）
# ==============================================================================

## 冲击波延迟时间
var shockwave_delay: float = 1.0

## 冲击波伤害
var shockwave_damage: int = 50

## 旋转光束伤害
var beam_damage: int = 25

## 旋转光束持续时间
var beam_duration: float = 5.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成幽灵轨道效果（未闭合状态）
## 延迟1秒后沿轨道释放冲击波
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var s = start
	var e = end
	var dur = _get_line_duration()
	var timer = get_tree().create_timer(shockwave_delay)
	timer.timeout.connect(func():
		SkillEffectManager.create_line_effect({
			"start": s,
			"end": e,
			"width": 32.0,
			"damage": shockwave_damage,
			"damage_interval": 0.5,
			"duration": dur - shockwave_delay,
			"color": Color(0.6, 0.6, 0.7, 0.8)
		})
	)

## 生成旋转光束效果（闭合状态）
## 持续对区域内敌人造成伤害
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": beam_damage,
		"damage_interval": 0.5,
		"duration": beam_duration,
		"color": Color(0.5, 0.5, 0.6, 0.5)
	})

## 获取规划线条颜色（钢铁/火车色）
func _get_line_color() -> Color:
	return Color(0.6, 0.6, 0.7, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.5, 0.5, 0.6, 1.0)
