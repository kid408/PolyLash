extends SkillDrawingBase
class_name SkillNewPyroQ

## ==============================================================================
## 新火法Q技能 - 火墙与火海
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建 StaticBody2D 火墙，阻挡敌人移动并对接触者造成持续伤害
## - 画圈闭合：在闭合区域内创建火海，对区域内敌人造成持续伤害（DOT）
## 
## ==============================================================================

# ==============================================================================
# 新火法技能专属参数（从CSV加载）
# ==============================================================================

## 火墙接触伤害
var wall_contact_damage: int = 15

## 火海伤害
var fire_sea_damage: int = 40

## 火海持续时间
var fire_sea_duration: float = 5.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成火墙效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": 16.0,
		"duration": _get_line_duration(),
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": wall_contact_damage,
		"contact_interval": 0.5,
		"color": Color(1.0, 0.4, 0.1, 0.8)
	})

## 生成火海效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": fire_sea_damage,
		"damage_interval": 0.5,
		"duration": fire_sea_duration,
		"color": Color(1.0, 0.3, 0.0, 0.5)
	})

## 获取规划线条颜色（火焰橙红色）
func _get_line_color() -> Color:
	return Color(1.0, 0.4, 0.1, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(1.0, 0.3, 0.0, 1.0)
