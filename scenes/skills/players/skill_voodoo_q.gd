extends SkillDrawingBase
class_name SkillVoodooQ

## ==============================================================================
## 巫毒Q技能 - 诅咒线与钉刺坑
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建诅咒区域，对接触的敌人施加 curse 状态
## - 画圈闭合：创建钉刺坑，对区域内敌人造成伤害并施加 curse 状态
## 
## ==============================================================================

# ==============================================================================
# 巫毒技能专属参数（从CSV加载）
# ==============================================================================

## 诅咒持续时间
var curse_duration: float = 6.0

## 诅咒每跳伤害
var curse_damage: int = 10

## 钉刺坑伤害
var pin_damage: int = 30

## 钉刺坑持续时间
var pin_duration: float = 4.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成诅咒线效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "curse",
		"debuff_value": curse_damage,
		"debuff_duration": curse_duration,
		"tick_interval": 1.0,
		"color": Color(0.5, 0.1, 0.4, 0.6)
	})

## 生成钉刺坑效果（闭合状态）- 造成伤害并施加诅咒
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	# 创建区域效果：伤害 + 诅咒 debuff
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": pin_damage,
		"damage_interval": 1.0,
		"duration": pin_duration,
		"color": Color(0.5, 0.1, 0.4, 0.5)
	})
	# 同时创建诅咒 debuff 区域
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": pin_duration,
		"debuff_type": "curse",
		"debuff_value": curse_damage,
		"debuff_duration": curse_duration,
		"tick_interval": 1.5,
		"color": Color(0.4, 0.05, 0.3, 0.3)
	})

## 获取规划线条颜色（暗紫色/巫毒）
func _get_line_color() -> Color:
	return Color(0.5, 0.1, 0.4, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.4, 0.05, 0.3, 1.0)
