extends SkillDrawingBase
class_name SkillSawPathRefactored

## ==============================================================================
## 屠夫Q技能（重构版）- 锯刃路径与绞杀区域
## ==============================================================================

var saw_damage_tick: int = 3
var saw_damage_open: int = 1
var chain_radius: float = 250.0
var saw_rotation_speed: float = 25.0
var saw_push_force: float = 1000.0
var dismember_damage: int = 200

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": 18.0,
		"duration": _get_line_duration(),
		"block_enemies": false,
		"contact_damage": saw_damage_open,
		"contact_interval": 0.25,
		"color": Color(1.2, 0.25, 0.2, 0.88)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	var pull_force = max(180.0, chain_radius * 1.5)
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": saw_damage_tick,
		"damage_interval": 0.22,
		"duration": max(3.0, _get_line_duration() + 1.0),
		"color": Color(1.2, 0.15, 0.15, 0.55),
		"pull_to_center": true,
		"pull_force": pull_force,
		"pull_interval": 0.05
	})

	_apply_dismember_damage(polygon)

func _apply_dismember_damage(polygon: PackedVector2Array) -> void:
	var burst_damage = max(1, dismember_damage)
	var hit_count = 0
	var enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_node("HealthComponent"):
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue

		var health_component = enemy.get_node("HealthComponent")
		health_component.take_damage(burst_damage)
		Global.spawn_floating_text(enemy.global_position, "DISMEMBER!", Color(1.4, 0.35, 0.15))
		hit_count += 1

	if hit_count > 0:
		Global.on_camera_shake.emit(8.0 + float(hit_count), 0.18)
		SoundManager.play("skill_q_closure_generic")

func _get_line_color() -> Color:
	return Color(1.2, 0.25, 0.2, 1.0)

func _get_closure_color() -> Color:
	return Color(1.6, 0.1, 0.1, 1.0)
