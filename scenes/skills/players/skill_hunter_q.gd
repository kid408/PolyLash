extends SkillDrawingBase
class_name SkillHunterQ

## ==============================================================================
## 猎人Q技能 - 陷阱线与猎场
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建陷阱线，对接触的敌人施加减速Debuff
## - 画圈闭合：在闭合区域内创建猎场，对区域内敌人施加冰冻Debuff
## 
## ==============================================================================

# ==============================================================================
# 猎人技能专属参数（从CSV加载）
# ==============================================================================

## 陷阱减速比例（0.5 = 50%减速）
var slow_value: float = 0.5

## 减速持续时间
var slow_duration: float = 3.0

## 冰冻持续时间
var freeze_duration: float = 2.0

## 陷阱持续时间
var trap_duration: float = 8.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成陷阱线效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": slow_duration,
		"tick_interval": 1.0,
		"color": Color(0.2, 0.5, 0.2, 0.5)
	})

## 生成猎场效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": trap_duration,
		"debuff_type": "freeze",
		"debuff_value": 0.0,
		"debuff_duration": freeze_duration,
		"tick_interval": 999.0,
		"color": Color(0.2, 0.5, 0.2, 0.4)
	})

## 获取规划线条颜色（森林绿）
func _get_line_color() -> Color:
	return Color(0.2, 0.5, 0.2, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.15, 0.4, 0.15, 1.0)
