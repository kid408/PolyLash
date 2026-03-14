extends SkillBase
class_name SkillWindE

var storm_eye_radius: float = 160.0
var storm_eye_damage: int = 36
var storm_eye_pull_force: float = 540.0
var storm_eye_duration: float = 2.2

var dash_distance: float = 260.0
var path_slash_width: float = 54.0
var path_slash_damage: int = 28
var return_slash_delay: float = 0.14
var return_slash_damage_scale: float = 0.72
var wind_zone_drift_speed: float = 145.0
const WIND_ACTIVE_META: String = "wind_path_active_until_msec"
const WIND_E_GUST_META: String = "wind_e_gust_until_msec"

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

	var damage_amp: float = get_e_damage_amp(0.42, 0.36)
	var duration_amp: float = get_e_duration_amp(0.38)
	var enhanced: bool = is_f_window_active()
	var q_combo_active: bool = _is_wind_path_active()
	if q_combo_active:
		enhanced = true
	var dash_data: Dictionary = _dash_to_cursor()
	var start_pos: Vector2 = Vector2(dash_data.get("start", skill_owner.global_position))
	var end_pos: Vector2 = Vector2(dash_data.get("end", skill_owner.global_position))
	var dash_dir: Vector2 = (end_pos - start_pos).normalized()
	if dash_dir.length_squared() <= 0.01:
		dash_dir = Vector2.RIGHT

	_apply_path_slash(start_pos, end_pos, damage_amp, duration_amp)
	_schedule_return_slash(end_pos, start_pos, damage_amp, duration_amp, enhanced, q_combo_active)
	_spawn_wind_zone(end_pos, damage_amp, duration_amp, enhanced, dash_dir)
	if q_combo_active:
		var side_dir: Vector2 = Vector2(-dash_dir.y, dash_dir.x)
		_spawn_wind_zone(end_pos + side_dir * 96.0, damage_amp * 0.86, duration_amp * 0.9, false, dash_dir)
	var gust_window: float = 1.8 + (0.7 if q_combo_active else 0.0) + (0.4 if enhanced else 0.0)
	skill_owner.set_meta(WIND_E_GUST_META, Time.get_ticks_msec() + int(round(gust_window * 1000.0)))
	spawn_skill_vfx(end_pos, Color(0.45, 1.25, 1.35, 0.85), 0.7)
	Global.on_camera_shake.emit(5.8, 0.11)
	Global.spawn_floating_text(end_pos, "WIND STEP / RETURN", Color(0.55, 1.25, 1.35))
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

func _apply_path_slash(start: Vector2, finish: Vector2, damage_amp: float, duration_amp: float) -> void:
	var damage: int = max(1, int(round(float(path_slash_damage) * damage_amp)))
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist_to_path: float = _distance_point_to_segment(enemy.global_position, start, finish)
		if dist_to_path > path_slash_width:
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 1.2 * duration_amp, 0.34)
		_apply_pull(enemy, finish, storm_eye_pull_force * 0.42 * duration_amp)

func _spawn_wind_zone(center: Vector2, damage_amp: float, duration_amp: float, enhanced: bool, dash_dir: Vector2) -> void:
	var zone: Node2D = Node2D.new()
	zone.name = "WindEZone"
	zone.global_position = center
	zone.z_index = 55

	var visual: Polygon2D = Polygon2D.new()
	visual.polygon = _build_circle_polygon(storm_eye_radius, 24)
	visual.color = Color(0.3, 1.0, 1.2, 0.42)
	visual.z_index = 55
	zone.add_child(visual)

	var scene: Node = get_tree().current_scene if get_tree() else null
	if scene != null:
		scene.add_child(zone)
	else:
		add_child(zone)

	var tick_timer: Timer = Timer.new()
	tick_timer.wait_time = 0.15
	tick_timer.one_shot = false
	tick_timer.autostart = true
	zone.add_child(tick_timer)

	var zone_duration: float = storm_eye_duration * duration_amp * (1.2 if enhanced else 1.0)
	var tick_damage: int = max(1, int(round(float(storm_eye_damage) * 0.48 * damage_amp)))
	zone.set_meta("elapsed", 0.0)
	zone.set_meta("damage_clock", 0.0)
	zone.set_meta("duration", zone_duration)
	zone.set_meta("tick_damage", tick_damage)
	zone.set_meta("duration_amp", duration_amp)
	zone.set_meta("tick_wait", tick_timer.wait_time)
	zone.set_meta("drift_dir", dash_dir)
	tick_timer.timeout.connect(_on_wind_zone_tick.bind(zone, visual))

func _on_wind_zone_tick(zone: Node2D, visual: Polygon2D) -> void:
	if not is_instance_valid(zone):
		return
	var tick_wait: float = float(zone.get_meta("tick_wait", 0.15))
	var elapsed: float = float(zone.get_meta("elapsed", 0.0)) + tick_wait
	var damage_clock: float = float(zone.get_meta("damage_clock", 0.0)) + tick_wait
	var zone_duration: float = float(zone.get_meta("duration", 2.0))
	var tick_damage: int = int(zone.get_meta("tick_damage", 12))
	var duration_amp: float = float(zone.get_meta("duration_amp", 1.0))
	var drift_dir: Vector2 = Vector2(zone.get_meta("drift_dir", Vector2.RIGHT))
	zone.set_meta("elapsed", elapsed)
	zone.set_meta("damage_clock", damage_clock)
	if elapsed >= zone_duration:
		zone.queue_free()
		return

	if drift_dir.length_squared() > 0.01:
		zone.global_position += drift_dir.normalized() * wind_zone_drift_speed * tick_wait

	var alpha_ratio: float = clamp((zone_duration - elapsed) / max(0.1, zone_duration), 0.2, 1.0)
	if is_instance_valid(visual):
		visual.modulate.a = 0.42 * alpha_ratio

	var do_damage: bool = false
	if damage_clock >= 0.45:
		zone.set_meta("damage_clock", 0.0)
		do_damage = true
	_tick_wind_zone(zone.global_position, tick_damage, storm_eye_radius, storm_eye_pull_force * duration_amp, do_damage)

func _schedule_return_slash(from_pos: Vector2, to_pos: Vector2, damage_amp: float, duration_amp: float, enhanced: bool, q_combo_active: bool) -> void:
	var delay_scale: float = 0.75 if enhanced else 1.0
	if q_combo_active:
		delay_scale *= 0.75
	var delay: float = return_slash_delay * delay_scale
	get_tree().create_timer(delay).timeout.connect(
		_on_return_slash_timeout.bind(from_pos, to_pos, damage_amp, duration_amp, enhanced, q_combo_active)
	)

func _on_return_slash_timeout(from_pos: Vector2, to_pos: Vector2, damage_amp: float, duration_amp: float, enhanced: bool, q_combo_active: bool) -> void:
	if not is_instance_valid(skill_owner):
		return
	var bonus_scale: float = 1.15 if enhanced else 1.0
	if q_combo_active:
		bonus_scale *= 1.18
	var return_damage: int = max(1, int(round(float(path_slash_damage) * return_slash_damage_scale * damage_amp * bonus_scale)))
	var return_width: float = path_slash_width * (1.15 if enhanced else 1.0)
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist_to_path: float = _distance_point_to_segment(enemy.global_position, from_pos, to_pos)
		if dist_to_path > return_width:
			continue
		_apply_damage(enemy, return_damage)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.36)
		_apply_pull(enemy, to_pos, storm_eye_pull_force * 0.5 * duration_amp)
		if q_combo_active:
			_apply_status(enemy, "marked", 1.1, 0.16)
	spawn_skill_vfx(to_pos, Color(0.55, 1.35, 1.45, 0.85), 0.55)

func _tick_wind_zone(center: Vector2, damage: int, radius: float, pull_force: float, do_damage: bool) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist: float = enemy.global_position.distance_to(center)
		if dist > radius:
			continue
		_apply_pull(enemy, center, pull_force)
		if do_damage:
			_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 0.6, 0.28)

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", amount)

func _apply_status(enemy: Node2D, status_type: String, duration: float, value: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_type, duration, value)

func _apply_pull(enemy: Node2D, target_pos: Vector2, force: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var pull_dir: Vector2 = (target_pos - enemy.global_position).normalized()
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", pull_dir, force)
	else:
		enemy.global_position += pull_dir * min(28.0, force * 0.012)

func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var seg_count: int = max(6, segments)
	for i: int in range(seg_count):
		var angle: float = TAU * float(i) / float(seg_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.0001:
		return point.distance_to(a)
	var t: float = clamp((point - a).dot(ab) / len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return point.distance_to(closest)

func _is_wind_path_active() -> bool:
	if not is_instance_valid(skill_owner):
		return false
	if not skill_owner.has_meta(WIND_ACTIVE_META):
		return false
	var expire_msec: int = int(skill_owner.get_meta(WIND_ACTIVE_META))
	return Time.get_ticks_msec() <= expire_msec
