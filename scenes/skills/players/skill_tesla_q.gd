extends SkillDrawingBase
class_name SkillTeslaQ

## ==============================================================================
## 特斯拉Q技能 - 电弧线与雷电场
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建电弧线，对接触的敌人造成伤害并施加 0.5 秒眩晕
## - 画圈闭合：在闭合区域内创建雷电场，每 0.5 秒对区域内敌人造成伤害
## 
## ==============================================================================

# ==============================================================================
# 特斯拉技能专属参数（从CSV加载）
# ==============================================================================

## 电弧伤害
var arc_damage: int = 25

## 电弧眩晕时间
var arc_stun_duration: float = 0.5

## 雷电场伤害
var field_damage: int = 30

## 雷电场持续时间
var field_duration: float = 4.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成电弧线效果（未闭合状态）
## 使用 debuff_zone 实现伤害 + 眩晕（freeze）效果
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"damage": arc_damage,
		"damage_interval": 0.5,
		"duration": _get_line_duration(),
		"debuff_type": "freeze",
		"debuff_value": 0.0,
		"debuff_duration": arc_stun_duration,
		"tick_interval": 0.5,
		"color": Color(0.3, 0.7, 1.0, 0.9)
	})

## 生成雷电场效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": field_damage,
		"damage_interval": 0.5,
		"duration": field_duration,
		"color": Color(0.2, 0.5, 1.0, 0.5)
	})

## 获取规划线条颜色（电蓝色）
func _get_line_color() -> Color:
	return Color(0.3, 0.7, 1.0, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.2, 0.5, 1.0, 1.0)
