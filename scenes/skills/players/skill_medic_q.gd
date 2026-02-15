extends SkillDrawingBase
class_name SkillMedicQ

## ==============================================================================
## 军医Q技能 - 消毒带与圣域
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建消毒带，为经过的队友恢复生命值，对经过的敌人施加减速
## - 画圈闭合：在闭合区域内创建无菌室，为区域内队友恢复生命值并提供无敌状态
## 
## ==============================================================================

# ==============================================================================
# 军医技能专属参数（从CSV加载）
# ==============================================================================

## 治疗量每跳
var heal_value: int = 5

## 减速比例（40%）
var slow_value: float = 0.4

## 无敌持续时间
var invincible_duration: float = 3.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成消毒带效果（未闭合状态）- 治疗队友 + 减速敌人
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	# 治疗 Buff 区域（队友）
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"buff_type": "heal",
		"buff_value": float(heal_value),
		"tick_interval": 0.5,
		"color": Color(0.4, 1.0, 0.5, 0.4)
	})
	# 减速 Debuff 区域（敌人）
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": 2.0,
		"tick_interval": 0.5,
		"color": Color(0.5, 0.9, 0.6, 0.25)
	})

## 生成无菌室效果（闭合状态）- 治疗 + 无敌
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	# 治疗 Buff 区域
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": invincible_duration,
		"buff_type": "heal",
		"buff_value": float(heal_value),
		"tick_interval": 0.5,
		"color": Color(0.4, 1.0, 0.5, 0.4)
	})
	# 无敌 Buff 区域
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": invincible_duration,
		"buff_type": "invincible",
		"buff_value": 1.0,
		"tick_interval": 0.5,
		"color": Color(0.3, 0.9, 0.4, 0.3)
	})

## 获取规划线条颜色（白/绿色治疗色）
func _get_line_color() -> Color:
	return Color(0.4, 1.0, 0.5, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.3, 0.9, 0.4, 1.0)
