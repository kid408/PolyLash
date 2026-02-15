extends SkillDrawingBase
class_name SkillJailerQ

## ==============================================================================
## 狱警Q技能 - 电网与封闭墙壁
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建电网（StaticBody2D），对接触的敌人造成碰撞伤害和击退
## - 画圈闭合：沿闭合边界的每条边创建墙壁，形成封闭的监狱
## 
## ==============================================================================

# ==============================================================================
# 狱警技能专属参数（从CSV加载）
# ==============================================================================

## 电网接触伤害
var wall_contact_damage: int = 20

## 电网宽度
var wall_width: float = 16.0

## 电网持续时间
var wall_duration: float = 6.0

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成电网效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": _get_line_duration(),
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": wall_contact_damage,
		"contact_interval": 0.5,
		"color": Color(0.9, 0.8, 0.2, 0.7)
	})

## 生成封闭墙壁效果（闭合状态）
## 沿多边形的每条边创建一段墙壁，形成封闭的监狱
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	var point_count = polygon.size()
	if point_count < 3:
		return
	for i in range(point_count):
		var start = polygon[i]
		var end = polygon[(i + 1) % point_count]
		SkillEffectManager.create_wall_effect({
			"start": start,
			"end": end,
			"width": wall_width,
			"duration": wall_duration,
			"block_enemies": true,
			"block_bullets": false,
			"contact_damage": wall_contact_damage,
			"contact_interval": 0.5,
			"color": Color(0.9, 0.8, 0.2, 0.7)
		})

## 获取规划线条颜色（电击黄色）
func _get_line_color() -> Color:
	return Color(0.9, 0.8, 0.2, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.9, 0.8, 0.2, 1.0)
