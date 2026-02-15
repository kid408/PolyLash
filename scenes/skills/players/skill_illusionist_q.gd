extends SkillDrawingBase
class_name SkillIllusionistQ

## ==============================================================================
## 魔术师Q技能 - 镜面墙与幻影分身
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建镜面墙（StaticBody2D），反射敌人子弹
## - 画圈闭合：在闭合区域中心创建幻影分身，吸引敌人仇恨
## 
## ==============================================================================

# ==============================================================================
# 魔术师技能专属参数（从CSV加载）
# ==============================================================================

## 镜面宽度
var wall_width: float = 16.0

## 镜面持续时间
var wall_duration: float = 5.0

## 幻影攻击伤害
var phantom_damage: int = 15

## 幻影存活时间
var phantom_duration: float = 10.0

## 幻影数量
var phantom_count: int = 2

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成镜面墙效果（未闭合状态）
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": wall_width,
		"duration": _get_line_duration(),
		"block_enemies": true,
		"block_bullets": true,
		"reflect_bullets": true,
		"color": Color(0.7, 0.7, 0.9, 0.7)
	})

## 生成幻影分身效果（闭合状态）
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	var center = _get_polygon_center(polygon)
	for i in range(phantom_count):
		var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		SkillEffectManager.create_summon({
			"position": center + offset,
			"summon_type": "phantom",
			"duration": phantom_duration,
			"damage": phantom_damage,
			"attack_interval": 1.0,
			"attack_range": 150.0,
			"max_count": phantom_count,
			"owner_skill_id": "skill_illusionist_q",
			"color": Color(0.7, 0.7, 0.9, 0.6)
		})

## 计算多边形中心点
func _get_polygon_center(polygon: PackedVector2Array) -> Vector2:
	var center = Vector2.ZERO
	for p in polygon:
		center += p
	return center / polygon.size()

## 获取规划线条颜色（银色/镜面）
func _get_line_color() -> Color:
	return Color(0.7, 0.7, 0.9, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.6, 0.6, 0.85, 1.0)
