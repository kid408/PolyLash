extends SkillDrawingBase
class_name SkillMidasQ

## ==============================================================================
## 炼金Q技能 - 金光射线与转化阵
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建金光射线（Debuff区域），对接触的敌人施加石化状态（95%减速代理）
## - 画圈闭合：在闭合区域内创建转化阵，对区域内敌人施加伤害放大（damage_amp）
## 
## ==============================================================================

# ==============================================================================
# 炼金技能专属参数（从CSV加载）
# ==============================================================================

## 石化减速比例（95%减速作为石化代理）
var petrify_slow: float = 0.95

## 石化持续时间
var petrify_duration: float = 3.0

## 变金伤害放大比例
var transmute_damage_amp: float = 0.5

## 变金圈持续时间
var transmute_duration: float = 5.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成金光射线效果（未闭合状态）- 使用 slow 作为石化代理（95%减速）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 24.0,
		"duration": _get_line_duration(),
		"debuff_type": "slow",
		"debuff_value": petrify_slow,
		"debuff_duration": petrify_duration,
		"tick_interval": 1.0,
		"color": Color(0.9, 0.7, 0.1, 0.5)
	})

## 生成转化阵效果（闭合状态）- 对区域内敌人施加伤害放大
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": transmute_duration,
		"debuff_type": "damage_amp",
		"debuff_value": transmute_damage_amp,
		"debuff_duration": transmute_duration,
		"tick_interval": 1.0,
		"color": Color(0.9, 0.7, 0.1, 0.4)
	})

## 获取规划线条颜色（金色/琥珀色）
func _get_line_color() -> Color:
	return Color(0.9, 0.7, 0.1, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.8, 0.6, 0.0, 1.0)
