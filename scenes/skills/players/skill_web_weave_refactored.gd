extends SkillDrawingBase
class_name SkillWebWeaveRefactored

var recall_fly_speed: float = 3.2
var recall_damage: int = 46
var recall_execute_mult: float = 2.8
var auto_recall_delay: float = 7.0
var web_slow_value: float = 0.58
var web_mark_amp: float = 0.24
var web_cut_interval: float = 0.32
var execute_threshold_ratio: float = 0.33
var cocoon_duration: float = 1.1
var cocoon_damage: int = 20

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = float(max(2.0, _get_line_duration() + recall_fly_speed * 0.2))
	var line_damage: int = max(1, int(round(float(recall_damage) * 0.45)))

	SkillEffectManager.create_line_effect({
		"start": start,
		"end": end,
		"width": 16.0,
		"damage": line_damage,
		"damage_interval": web_cut_interval,
		"duration": duration,
		"color": Color(0.52, 0.8, 1.2, 0.74)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 20.0,
		"duration": duration,
		"debuff_type": "slow",
		"debuff_value": web_slow_value,
		"debuff_duration": 1.2,
		"tick_interval": 0.35,
		"color": Color(0.45, 0.72, 1.0, 0.24)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": 18.0,
		"duration": duration,
		"debuff_type": "damage_amp",
		"debuff_value": web_mark_amp * 0.6,
		"debuff_duration": 1.4,
		"tick_interval": 0.45,
		"color": Color(0.75, 0.88, 1.0, 0.18)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	var zone_duration: float = float(clamp(auto_recall_delay, 2.5, 8.0))
	var freeze_duration: float = float(clamp(cocoon_duration + recall_fly_speed * 0.08, 0.8, 1.6))

	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": cocoon_damage,
		"damage_interval": web_cut_interval,
		"duration": zone_duration,
		"color": Color(0.95, 0.52, 0.2, 0.45)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": zone_duration,
		"debuff_type": "freeze",
		"debuff_value": 0.0,
		"debuff_duration": freeze_duration,
		"tick_interval": 0.9,
		"color": Color(0.95, 0.62, 0.24, 0.2)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": zone_duration,
		"debuff_type": "damage_amp",
		"debuff_value": web_mark_amp,
		"debuff_duration": 1.6,
		"tick_interval": 0.45,
		"color": Color(1.0, 0.7, 0.26, 0.22)
	})

	_apply_execute_damage(polygon)

func _apply_execute_damage(polygon: PackedVector2Array) -> void:
	var base_execute: int = max(1, int(round(float(recall_damage) * (max(1.0, recall_execute_mult) - 1.0))))
	var hit_count := 0
	var execute_count := 0
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_node("HealthComponent"):
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue

		var health_component = enemy.get_node("HealthComponent")
		var final_damage: int = base_execute
		var ratio: float = 1.0
		if health_component.max_health > 0.0:
			ratio = health_component.current_health / health_component.max_health
		if ratio <= execute_threshold_ratio:
			final_damage = int(round(float(base_execute) * 1.6))
			Global.spawn_floating_text(enemy.global_position, "WEB EXEC!", Color(1.3, 0.7, 0.2))
			execute_count += 1
		else:
			Global.spawn_floating_text(enemy.global_position, "WEB CUT!", Color(1.15, 0.62, 0.2))

		health_component.take_damage(max(1, final_damage))
		hit_count += 1

	if hit_count > 0:
		Global.on_camera_shake.emit(6.0 + float(execute_count) * 2.0 + float(hit_count) * 0.4, 0.16)
		SoundManager.play("skill_q_closure_generic")

func _get_line_color() -> Color:
	return Color(0.52, 0.8, 1.2, 1.0)

func _get_closure_color() -> Color:
	return Color(1.05, 0.45, 0.2, 1.0)
