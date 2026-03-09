extends SkillDrawingBase
class_name SkillFirePathRefactored

var fire_line_damage: int = 34
var fire_line_duration: float = 6.0
var fire_line_width: float = 30.0
var afterburn_damage: int = 14
var afterburn_interval: float = 0.45
var fire_sea_damage: int = 62
var fire_sea_duration: float = 6.2
var inferno_pulse_damage: int = 42
var inferno_pulse_interval: float = 0.9
var scorch_damage_amp: float = 0.22

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = float(max(fire_line_duration, _get_line_duration()))
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": fire_line_width,
		"duration": duration,
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": fire_line_damage,
		"contact_interval": 0.22,
		"color": Color(1.25, 0.52, 0.12, 0.9)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": fire_line_width + 6.0,
		"duration": duration,
		"debuff_type": "poison",
		"debuff_value": float(afterburn_damage),
		"debuff_duration": 2.0,
		"tick_interval": afterburn_interval,
		"color": Color(1.0, 0.45, 0.08, 0.32)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": fire_line_width,
		"duration": duration,
		"debuff_type": "damage_amp",
		"debuff_value": scorch_damage_amp * 0.45,
		"debuff_duration": 1.2,
		"tick_interval": 0.35,
		"color": Color(1.0, 0.6, 0.18, 0.2)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	var duration: float = float(max(fire_sea_duration, _get_line_duration() + 1.0))
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": fire_sea_damage,
		"damage_interval": 0.3,
		"duration": duration,
		"color": Color(1.25, 0.35, 0.05, 0.58),
		"z_index": 12
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": duration,
		"debuff_type": "damage_amp",
		"debuff_value": scorch_damage_amp,
		"debuff_duration": 1.8,
		"tick_interval": 0.45,
		"color": Color(1.0, 0.52, 0.12, 0.24)
	})

	_pulse_area(polygon, inferno_pulse_damage, "INFERNO!")
	if inferno_pulse_interval > 0.0:
		var delayed_damage := int(round(float(inferno_pulse_damage) * 0.7))
		get_tree().create_timer(min(inferno_pulse_interval, 1.2)).timeout.connect(func() -> void:
			_pulse_area(polygon, delayed_damage, "BURN!")
		)

func _pulse_area(polygon: PackedVector2Array, damage: int, text: String) -> void:
	var hit_count := 0
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_node("HealthComponent"):
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue

		var health_component = enemy.get_node("HealthComponent")
		health_component.take_damage(max(1, damage))
		Global.spawn_floating_text(enemy.global_position, text, Color(1.35, 0.55, 0.18))
		hit_count += 1

	if hit_count > 0:
		Global.on_camera_shake.emit(6.0 + float(hit_count), 0.14)

func _get_line_color() -> Color:
	return Color(1.25, 0.52, 0.12, 1.0)

func _get_closure_color() -> Color:
	return Color(1.55, 0.25, 0.06, 1.0)
