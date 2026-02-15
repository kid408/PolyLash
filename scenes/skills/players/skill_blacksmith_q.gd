extends SkillDrawingBase
class_name SkillBlacksmithQ

## ==============================================================================
## 铁匠Q技能 - 磨刀石与锻造炉
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建磨刀石区域，为经过的队友提供 +50% 攻击力加成
## - 画圈闭合：在闭合区域内创建锻造炉，为区域内队友提供 +100% 攻击速度加成
## 
## ==============================================================================

# ==============================================================================
# 铁匠技能专属参数（从CSV加载）
# ==============================================================================

## 攻击力加成值（50%）
var attack_boost_value: float = 0.5

## 锻造炉攻速加成值（100%）
var forge_boost_value: float = 1.0

## Buff持续时间
var buff_duration: float = 5.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成磨刀石效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"buff_type": "attack_boost",
		"buff_value": attack_boost_value,
		"tick_interval": 0.5,
		"color": Color(0.9, 0.5, 0.1, 0.5)
	})

## 生成锻造炉效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "attack_boost",
		"buff_value": forge_boost_value,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.4, 0.0, 0.5)
	})

## 获取规划线条颜色（橙色/锻造色）
func _get_line_color() -> Color:
	return Color(0.9, 0.5, 0.1, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(1.0, 0.4, 0.0, 1.0)
