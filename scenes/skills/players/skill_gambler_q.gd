extends SkillDrawingBase
class_name SkillGamblerQ

## ==============================================================================
## 赌徒Q技能 - 随机Buff/Debuff区域
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建随机Buff区域（随机选择一种Buff类型）
## - 画圈闭合：在闭合区域内创建随机Debuff区域（随机选择一种Debuff类型）
## 
## ==============================================================================

# ==============================================================================
# 赌徒技能专属参数（从CSV加载）
# ==============================================================================

## 随机Buff数值
var random_buff_value: float = 0.5

## 随机Debuff数值
var random_debuff_value: float = 0.5

## 区域持续时间
var zone_duration: float = 5.0

# ==============================================================================
# 随机池
# ==============================================================================

const BUFF_TYPES: Array = ["attack_boost", "speed_boost", "heal", "cooldown_reduction"]
const DEBUFF_TYPES: Array = ["slow", "damage_amp", "freeze", "poison"]

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成随机Buff区域效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var buff_type: String = BUFF_TYPES[randi() % BUFF_TYPES.size()]
	SkillEffectManager.create_buff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"buff_type": buff_type,
		"buff_value": random_buff_value,
		"tick_interval": 0.5,
		"color": Color(0.9, 0.8, 0.2, 0.5)
	})

## 生成随机Debuff区域效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	var debuff_type: String = DEBUFF_TYPES[randi() % DEBUFF_TYPES.size()]
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": zone_duration,
		"debuff_type": debuff_type,
		"debuff_value": random_debuff_value,
		"debuff_duration": zone_duration,
		"tick_interval": 1.0,
		"color": Color(0.9, 0.8, 0.2, 0.4)
	})

## 获取规划线条颜色（金色/黄色）
func _get_line_color() -> Color:
	return Color(0.9, 0.8, 0.2, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.9, 0.7, 0.1, 1.0)
