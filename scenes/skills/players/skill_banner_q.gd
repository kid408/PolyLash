extends SkillDrawingBase
class_name SkillBannerQ

## ==============================================================================
## 旗手Q技能 - 冲锋线与决斗场
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建冲锋线，使经过的队友忽略单位碰撞
## - 画圈闭合：在闭合区域内创建决斗场，使区域内敌人的防御力降为0
## 
## ==============================================================================

# ==============================================================================
# 旗手技能专属参数（从CSV加载）
# ==============================================================================

## 防御削减比例（100%）
var defense_reduction: float = 1.0

## 决斗场持续时间
var debuff_duration: float = 5.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成冲锋线效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"buff_type": "ignore_collision",
		"buff_value": 1.0,
		"tick_interval": 0.5,
		"color": Color(0.9, 0.2, 0.2, 0.5)
	})

## 生成决斗场效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": debuff_duration,
		"debuff_type": "damage_amp",
		"debuff_value": defense_reduction,
		"debuff_duration": debuff_duration,
		"tick_interval": 1.0,
		"color": Color(0.8, 0.1, 0.1, 0.4)
	})

## 获取规划线条颜色（红色/旗帜色）
func _get_line_color() -> Color:
	return Color(0.9, 0.2, 0.2, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.8, 0.1, 0.1, 1.0)
