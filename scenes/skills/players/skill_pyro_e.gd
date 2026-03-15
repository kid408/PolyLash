extends SkillEBase
class_name SkillPyroE

var fire_nova_radius: float = 180.0
var fire_nova_damage: int = 46
var fire_nova_duration: float = 2.4

var dash_distance: float = 280.0
var dash_width: float = 56.0
var path_burn_damage: int = 14

func execute() -> void:
	if not can_execute():
		if is_on_cooldown and is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "Cooldown!", Color.YELLOW)
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.4, 0.45)
	var duration_amp: float = get_e_duration_amp(0.35)
	var dash_data: Dictionary = _dash_to_cursor()
	var start_pos: Vector2 = Vector2(dash_data.get("start", skill_owner.global_position))
	var end_pos: Vector2 = Vector2(dash_data.get("end", skill_owner.global_position))

	_apply_path_burn(start_pos, end_pos, damage_amp, duration_amp)
	var nova_damage: int = max(1, int(round(float(fire_nova_damage) * damage_amp)))
	var nova_duration: float = max(0.8, fire_nova_duration * duration_amp)
	_explode_at(end_pos, fire_nova_radius, nova_damage, nova_duration, damage_amp)
	spawn_skill_vfx(end_pos, Color(1.35, 0.45, 0.1, 0.95), 0.75)
	Global.on_camera_shake.emit(7.0, 0.14)
	Global.spawn_floating_text(end_pos, "BLAZE STEP", Color(1.35, 0.55, 0.15))
	publish_e_context(
		end_pos,
		fire_nova_radius,
		"pyro_blaze_step",
		{
			"nova_damage": nova_damage,
			"nova_duration": nova_duration,
		},
		"pyro_blaze_step",
		nova_duration
	)

	if is_f_window_active():
		var pulse_radius: float = fire_nova_radius * 0.78
		var pulse_damage: int = max(1, int(round(float(nova_damage) * 0.62)))
		get_tree().create_timer(0.28).timeout.connect(
			_on_extra_pulse_timeout.bind(end_pos, pulse_radius, pulse_damage, nova_duration, damage_amp)
		)

	start_cooldown()

func _dash_to_cursor() -> Dictionary:
	var start: Vector2 = skill_owner.global_position
	var mouse_pos: Vector2 = skill_owner.get_global_mouse_position()
	var offset: Vector2 = mouse_pos - start
	if offset.length() < 1.0:
		offset = Vector2.RIGHT
	var end: Vector2 = start + offset.normalized() * min(offset.length(), dash_distance)
	skill_owner.global_position = end
	return {"start": start, "end": end}

func _apply_path_burn(start: Vector2, finish: Vector2, damage_amp: float, duration_amp: float) -> void:
	var burn_damage: int = max(1, int(round(float(path_burn_damage) * damage_amp)))
	var direct_damage: int = max(1, int(round(float(burn_damage) * 0.68)))
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist_to_path: float = _distance_point_to_segment(enemy.global_position, start, finish)
		if dist_to_path > dash_width:
			continue
		_apply_damage(enemy, direct_damage)
		_apply_status(enemy, "burn", fire_nova_duration * duration_amp, float(burn_damage), 1.0, 0.55)
		_apply_status(enemy, "marked", max(1.1, fire_nova_duration * 0.65), 0.12 * damage_amp, 1.0, 0.6)

func _explode_at(center: Vector2, radius: float, damage: int, burn_time: float, damage_amp: float) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "burn", burn_time, max(2.0, float(damage) * 0.24), 1.0, 0.6)
		_apply_status(enemy, "marked", max(1.0, burn_time * 0.55), 0.14 * damage_amp, 1.0, 0.6)

func _on_extra_pulse_timeout(center: Vector2, pulse_radius: float, pulse_damage: int, burn_time: float, damage_amp: float) -> void:
	_explode_at(center, pulse_radius, pulse_damage, burn_time * 0.72, damage_amp)
	spawn_skill_vfx(center, Color(1.45, 0.55, 0.2, 0.75), 0.55)

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", amount)

func _apply_status(
	enemy: Node2D,
	status_type: String,
	duration: float,
	value: float,
	stacks: float,
	tick_interval: float
) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_type, duration, value, int(round(stacks)), tick_interval)

func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.0001:
		return point.distance_to(a)
	var t: float = clamp((point - a).dot(ab) / len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return point.distance_to(closest)
