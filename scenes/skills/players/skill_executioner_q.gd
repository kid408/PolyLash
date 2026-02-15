extends SkillDrawingBase
class_name SkillExecutionerQ

## ==============================================================================
## 处刑Q技能 - 处刑区域与断头台
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建处刑区域（Debuff区域），对接触的敌人施加伤害放大（damage_amp）
## - 画圈闭合：在闭合区域内创建断头台效果，对区域内敌人造成高额伤害
## 
## ==============================================================================

# ==============================================================================
# 处刑技能专属参数（从CSV加载）
# ==============================================================================

## 伤害放大比例（40%）
var damage_amp_value: float = 0.4

## 伤害放大持续时间
var damage_amp_duration: float = 5.0

## 断头台伤害
var guillotine_damage: int = 100

## 断头台持续时间
var guillotine_duration: float = 1.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成处刑区域效果（未闭合状态）- 对接触敌人施加 damage_amp debuff
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "damage_amp",
		"debuff_value": damage_amp_value,
		"debuff_duration": damage_amp_duration,
		"tick_interval": 1.0,
		"color": Color(0.6, 0.1, 0.1, 0.5)
	})

## 生成断头台效果（闭合状态）- 对区域内敌人造成高额伤害
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": guillotine_damage,
		"damage_interval": 0.5,
		"duration": guillotine_duration,
		"color": Color(0.6, 0.1, 0.1, 0.6)
	})

## 获取规划线条颜色（暗红色）
func _get_line_color() -> Color:
	return Color(0.6, 0.1, 0.1, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.5, 0.05, 0.05, 1.0)
