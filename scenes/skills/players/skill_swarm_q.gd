extends SkillDrawingBase
class_name SkillSwarmQ

## ==============================================================================
## 虫母Q技能 - 裂缝与孵化场
## ==============================================================================
## 
## 功能说明:
## - 画线：沿路径创建裂缝，每1秒生成一只自爆甲虫
## - 画圈闭合：在闭合区域内创建孵化场，生成3个远程炮塔并为队友恢复生命
## 
## ==============================================================================

# ==============================================================================
# 虫母技能专属参数（从CSV加载）
# ==============================================================================

## 甲虫自爆伤害
var beetle_damage: int = 30

## 甲虫生成间隔
var beetle_interval: float = 1.0

## 甲虫存活时间
var beetle_duration: float = 5.0

## 炮塔伤害
var turret_damage: int = 15

## 孵化场炮塔数量
var turret_count: int = 3

## 孵化场治疗量
var heal_value: int = 3

# ==============================================================================
# 实现基类虚函数
# ==============================================================================

## 生成裂缝效果（未闭合状态）
## 沿线段每隔 beetle_interval 秒生成一只自爆甲虫
func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var s = start
	var e = end
	var dur = _get_line_duration()
	var spawn_count = int(dur / beetle_interval)
	for i in range(spawn_count):
		var delay = beetle_interval * i
		var timer = get_tree().create_timer(delay)
		var t = float(i) / max(spawn_count - 1, 1)
		var pos = s.lerp(e, t)
		timer.timeout.connect(func():
			SkillEffectManager.create_summon({
				"position": pos,
				"summon_type": "beetle",
				"duration": beetle_duration,
				"damage": beetle_damage,
				"attack_interval": 0.5,
				"attack_range": 80.0,
				"max_count": 10,
				"owner_skill_id": "skill_swarm_q",
				"color": Color(0.5, 0.4, 0.1)
			})
		)

## 生成孵化场效果（闭合状态）
## 在闭合区域内生成炮塔并为队友恢复生命
func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	# 生成炮塔
	for i in range(turret_count):
		var center = _get_polygon_center(polygon)
		var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		SkillEffectManager.create_summon({
			"position": center + offset,
			"summon_type": "turret",
			"duration": 10.0,
			"damage": turret_damage,
			"attack_interval": 1.0,
			"attack_range": 200.0,
			"max_count": 5,
			"owner_skill_id": "skill_swarm_q",
			"color": Color(0.4, 0.3, 0.0)
		})

	# 治疗 Buff 区域
	SkillEffectManager.create_buff_zone({
		"polygon": polygon,
		"duration": 8.0,
		"buff_type": "heal",
		"buff_value": float(heal_value),
		"tick_interval": 1.0,
		"color": Color(0.5, 0.6, 0.2, 0.3)
	})

## 计算多边形中心点
func _get_polygon_center(polygon: PackedVector2Array) -> Vector2:
	var center = Vector2.ZERO
	for p in polygon:
		center += p
	return center / polygon.size()

## 获取规划线条颜色（虫绿/棕色）
func _get_line_color() -> Color:
	return Color(0.5, 0.4, 0.1, 1.0)

## 获取闭合提示颜色
func _get_closure_color() -> Color:
	return Color(0.4, 0.3, 0.0, 1.0)
