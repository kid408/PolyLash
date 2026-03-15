extends SkillQBase
class_name SkillFirePath

# Core parameters from config/player/skill_params_wide.csv (skill_fire_path).
var fire_line_damage: int = 20
var fire_line_duration: float = 5.0
var fire_line_width: float = 24.0
var fire_sea_damage: int = 40
var fire_sea_duration: float = 5.0

# Extra tuning for new drawing framework implementation.
var afterburn_damage: int = 12
var afterburn_interval: float = 0.45
var inferno_pulse_damage: int = 28
var inferno_pulse_interval: float = 0.9
var scorch_mark_amp: float = 0.18
const FIRE_ACTIVE_META: String = "pyro_fire_active_until_msec"

func _spawn_line_effect(start: Vector2, end: Vector2) -> void:
	var duration: float = max(_get_line_duration(), fire_line_duration)
	_mark_fire_active(duration)
	SkillEffectManager.create_wall_effect({
		"start": start,
		"end": end,
		"width": fire_line_width,
		"duration": duration,
		"block_enemies": true,
		"block_bullets": false,
		"contact_damage": fire_line_damage,
		"contact_interval": 0.22,
		"color": Color(1.25, 0.5, 0.12, 0.92)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": fire_line_width + 5.0,
		"duration": duration,
		"debuff_type": "burn",
		"debuff_value": float(afterburn_damage),
		"debuff_duration": 2.0,
		"tick_interval": afterburn_interval,
		"color": Color(1.0, 0.42, 0.12, 0.28)
	})

	SkillEffectManager.create_debuff_zone({
		"start": start,
		"end": end,
		"width": fire_line_width + 2.0,
		"duration": duration,
		"debuff_type": "marked",
		"debuff_value": scorch_mark_amp * 0.65,
		"debuff_duration": 1.4,
		"tick_interval": 0.45,
		"color": Color(1.0, 0.62, 0.22, 0.2)
	})

func _spawn_area_effect(polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return

	var duration: float = max(3.2, fire_sea_duration)
	_mark_fire_active(duration + inferno_pulse_interval + 0.2)
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": fire_sea_damage,
		"damage_interval": 0.3,
		"duration": duration,
		"color": Color(1.22, 0.28, 0.08, 0.56),
		"z_index": 12
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": duration,
		"debuff_type": "burn",
		"debuff_value": float(max(1, int(round(float(afterburn_damage) * 1.3)))),
		"debuff_duration": 2.2,
		"tick_interval": afterburn_interval,
		"color": Color(1.0, 0.36, 0.1, 0.24)
	})

	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": duration,
		"debuff_type": "marked",
		"debuff_value": scorch_mark_amp,
		"debuff_duration": 1.6,
		"tick_interval": 0.45,
		"color": Color(1.0, 0.58, 0.18, 0.2)
	})

	_pulse_area(polygon, inferno_pulse_damage, "INFERNO!")
	if inferno_pulse_interval > 0.0:
		var delayed_damage: int = max(1, int(round(float(inferno_pulse_damage) * 0.72)))
		var delay: float = min(inferno_pulse_interval, 1.2)
		get_tree().create_timer(delay).timeout.connect(
			_on_delayed_pulse_timeout.bind(PackedVector2Array(polygon), delayed_damage)
		)

func _on_delayed_pulse_timeout(polygon: PackedVector2Array, damage: int) -> void:
	_pulse_area(polygon, damage, "BURN!")

func _pulse_area(polygon: PackedVector2Array, damage: int, text: String) -> void:
	var hit_count: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		if enemy.has_node("HealthComponent"):
			var hc: Node = enemy.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", max(1, damage))
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", "burn", 1.8, float(max(1, int(round(float(damage) * 0.38)))))
		hit_count += 1

	if hit_count > 0:
		var center: Vector2 = _polygon_center(polygon)
		Global.spawn_floating_text(center, text, Color(1.35, 0.58, 0.18))
		spawn_skill_vfx(center, Color(1.38, 0.45, 0.15, 0.85), 0.6)
		Global.on_camera_shake.emit(4.8 + float(hit_count) * 0.35, 0.1)

func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	if polygon.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in polygon:
		center += point
	return center / float(polygon.size())

func _get_line_color() -> Color:
	return Color(1.25, 0.52, 0.16, 1.0)

func _get_closure_color() -> Color:
	return Color(1.45, 0.24, 0.1, 1.0)

func _mark_fire_active(duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var expire_msec: int = Time.get_ticks_msec() + int(round(max(0.2, duration) * 1000.0))
	skill_owner.set_meta(FIRE_ACTIVE_META, expire_msec)

func _get_q_asset_kind(is_closed_path: bool) -> String:
	return "pyro_inferno_zone" if is_closed_path else "pyro_fire_line"

func _get_q_asset_duration(is_closed_path: bool) -> float:
	return max(fire_sea_duration, 1.0) if is_closed_path else max(fire_line_duration, _get_line_duration())

func _build_q_asset_payload(
	is_closed_path: bool,
	segment_count: int,
	polygon_count: int,
	center: Vector2,
	radius: float
) -> Dictionary:
	return {
		"role_id": "pyro",
		"is_closed": is_closed_path,
		"segment_count": segment_count,
		"polygon_count": polygon_count,
		"center": center,
		"radius": radius,
		"afterburn_damage": afterburn_damage,
		"inferno_pulse_damage": inferno_pulse_damage,
	}

