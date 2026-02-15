extends SkillDrawingBase
class_name SkillAmmoQ

## ==============================================================================
## 弹药Q技能 - 加速轨道与补给站
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建加速轨道，队友的子弹穿过该线段时变大并增加伤害
## - 画圈闭合：在闭合区域内创建补给站，减少区域内队友的技能冷却时间
## 
## ==============================================================================

# ==============================================================================
# 弹药技能专属参数（从CSV加载）
# ==============================================================================

## 弹药加速值（50%）
var projectile_boost_value: float = 0.5

## 冷却缩减值（30%）
var cooldown_reduction_value: float = 0.3

## Buff持续时间
var buff_duration: float = 5.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成加速轨道效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"buff_type": "attack_boost",
		"buff_value": projectile_boost_value,
		"tick_interval": 0.5,
		"color": Color(0.3, 0.6, 0.2, 0.5)
	})

## 生成补给站效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "cooldown_reduction",
		"buff_value": cooldown_reduction_value,
		"tick_interval": 0.5,
		"color": Color(0.2, 0.5, 0.1, 0.5)
	})

## 获取规划线条颜色（军绿色/弹药色）
func _get_line_color() -> Color:
	return Color(0.3, 0.6, 0.2, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.2, 0.5, 0.1, 1.0)
