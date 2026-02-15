extends SkillDrawingBase
class_name SkillPaladinQ

## ==============================================================================
## 圣骑士Q技能 - 光墙与净化场
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建光墙，阻挡敌人子弹通过（不阻挡敌人移动）
## - 画圈闭合：在闭合区域内创建净化场，为队友恢复生命（净化代理）
## 
## ==============================================================================

# ==============================================================================
# 圣骑士技能专属参数（从CSV加载）
# ==============================================================================

## 光墙宽度
var wall_width: float = 16.0

## 光墙持续时间
var wall_duration: float = 6.0

## 净化场治疗量
var heal_value: int = 3

## 净化场持续时间
var buff_duration: float = 5.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成光墙效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": _get_line_duration(),
		"block_enemies": false,
		"block_bullets": true,
		"color": Color(1.0, 0.85, 0.3, 0.7)
	})

## 生成净化场效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": buff_duration,
		"buff_type": "heal",
		"buff_value": float(heal_value),
		"tick_interval": 0.5,
		"color": Color(1.0, 0.9, 0.4, 0.4)
	})

## 获取规划线条颜色（金色/圣光色）
func _get_line_color() -> Color:
	return Color(1.0, 0.85, 0.3, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(1.0, 0.9, 0.4, 1.0)
