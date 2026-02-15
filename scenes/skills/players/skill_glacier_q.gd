extends SkillDrawingBase
class_name SkillGlacierQ

## ==============================================================================
## 冰河Q技能 - 冰墙与冰冻区域
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建 StaticBody2D 冰墙，阻挡敌人和子弹
## - 画圈闭合：在闭合区域内对所有敌人施加冰冻状态
## 
## ==============================================================================

# ==============================================================================
# 冰河技能专属参数（从CSV加载）
# ==============================================================================

## 冰墙持续时间
var wall_duration: float = 5.0

## 冰墙宽度
var wall_width: float = 16.0

## 冰冻持续时间
var freeze_duration: float = 2.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成冰墙效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": _get_line_duration(),
		"block_enemies": true,
		"block_bullets": true,
		"color": Color(0.5, 0.8, 1.0, 0.7)
	})

## 生成冰冻区域效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": freeze_duration,
		"debuff_type": "freeze",
		"debuff_value": 0.0,
		"debuff_duration": freeze_duration,
		"tick_interval": 999.0,
		"color": Color(0.3, 0.6, 1.0, 0.5)
	})

## 获取规划线条颜色（冰蓝色）
func _get_line_color() -> Color:
	return Color(0.5, 0.8, 1.0, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.3, 0.6, 1.0, 1.0)
