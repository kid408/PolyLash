extends SkillDrawingBase
class_name SkillMerchantQ

## ==============================================================================
## 商人Q技能 - 赏金线与黑市
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建赏金线（Buff区域），接触的敌人死亡时掉落双倍金币
## - 画圈闭合：在闭合区域内创建黑市，区域内敌人每秒掉落1金币并进入逃跑状态
## 
## ==============================================================================

# ==============================================================================
# 商人技能专属参数（从CSV加载）
# ==============================================================================

## 金币加成比例
var gold_bonus: float = 0.2

## 商店折扣值
var discount_value: float = 0.15

## Buff持续时间
var buff_duration: float = 8.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成赏金线效果（未闭合状态）- 使用 attack_boost 作为金币加成代理
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"buff_type": "attack_boost",
		"buff_value": gold_bonus,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.8, 0.2, 0.5)
	})

## 生成黑市效果（闭合状态）- 使用 speed_boost 作为商店折扣代理
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "speed_boost",
		"buff_value": discount_value,
		"tick_interval": 0.5,
		"color": Color(1.0, 0.7, 0.1, 0.4)
	})

## 获取规划线条颜色（金色）
func _get_line_color() -> Color:
	return Color(1.0, 0.8, 0.2, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(1.0, 0.7, 0.1, 1.0)
