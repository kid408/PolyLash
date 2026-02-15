extends SkillDrawingBase
class_name SkillPlagueQ

## ==============================================================================
## 瘟疫Q技能 - 腐蚀路径与瘴气池
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建腐蚀路径，对接触的敌人施加 50% 减速和中毒状态
## - 画圈闭合：在闭合区域内创建瘴气池，使区域内敌人受到的伤害增加 30%
## 
## ==============================================================================

# ==============================================================================
# 瘟疫技能专属参数（从CSV加载）
# ==============================================================================

## 减速比例（0.5 = 50%）
var slow_value: float = 0.5

## 毒素每跳伤害
var poison_damage: int = 8

## 毒素持续时间
var poison_duration: float = 5.0

## 伤害放大比例（0.3 = 30%）
var damage_amp_value: float = 0.3

## Debuff区域持续时间
var debuff_zone_duration: float = 6.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成腐蚀路径效果（未闭合状态）- 减速 + 中毒
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	# 创建减速 Debuff 区域
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": poison_duration,
		"tick_interval": 1.0,
		"color": Color(0.4, 0.7, 0.1, 0.5)
	})
	# 创建中毒 Debuff 区域（叠加在同一路径上）
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "poison",
		"debuff_value": poison_damage,
		"debuff_duration": poison_duration,
		"tick_interval": 1.0,
		"color": Color(0.3, 0.5, 0.0, 0.3)
	})

## 生成瘴气池效果（闭合状态）- 伤害放大 30%
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": debuff_zone_duration,
		"debuff_type": "damage_amp",
		"debuff_value": damage_amp_value,
		"debuff_duration": debuff_zone_duration,
		"tick_interval": 1.0,
		"color": Color(0.4, 0.7, 0.1, 0.4)
	})

## 获取规划线条颜色（病态绿色）
func _get_line_color() -> Color:
	return Color(0.4, 0.7, 0.1, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.3, 0.5, 0.0, 1.0)
