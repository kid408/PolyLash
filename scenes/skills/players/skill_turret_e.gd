extends SkillBase
class_name SkillTurretE

var beacon_radius: float = 170.0
var beacon_duration: float = 2.8
var beacon_tick_damage: int = 26
var beacon_tick_interval: float = 0.35
var detonate_damage: int = 45

func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.24, 0.34)
	var duration_amp: float = get_e_duration_amp(0.3)
	var nearest_enemy: Node2D = _pick_nearest_enemy(skill_owner.global_position)
	var target_pos: Vector2 = nearest_enemy.global_position if nearest_enemy != null else skill_owner.global_position

	if SkillEffectManager != null and SkillEffectManager.has_method("command_summons"):
		SkillEffectManager.command_summons("skill_turret_q", "focus_fire", nearest_enemy)

	_spawn_emp_beacon(target_pos, damage_amp, duration_amp, is_f_window_active())

	if is_f_window_active() and SkillEffectManager != null and SkillEffectManager.has_method("command_summons"):
		SkillEffectManager.command_summons("skill_turret_q", "self_destruct")
		_detonate_at(target_pos, max(1, int(round(float(detonate_damage) * damage_amp * 1.25))), beacon_radius * 0.92)
		Global.spawn_floating_text(target_pos, "OVERLOAD DETONATE!", Color(0.72, 0.9, 0.62))
	else:
		Global.spawn_floating_text(target_pos, "LOCKDOWN BEACON!", Color(0.62, 0.82, 0.52))

	Global.on_camera_shake.emit(8.0, 0.18)
	start_cooldown()

func _spawn_emp_beacon(center: Vector2, damage_amp: float, duration_amp: float, empowered: bool) -> void:
	var beacon: Node2D = Node2D.new()
	beacon.global_position = center
	beacon.z_index = 58
	var radius: float = beacon_radius * (1.15 if empowered else 1.0) * (1.0 + (duration_amp - 1.0) * 0.35)
	var tick_damage: int = max(1, int(round(float(beacon_tick_damage) * damage_amp * (1.18 if empowered else 1.0))))
	var duration: float = beacon_duration * duration_amp * (1.2 if empowered else 1.0)

	var ring: Polygon2D = Polygon2D.new()
	ring.polygon = _build_circle_polygon(radius, 20)
	ring.color = Color(0.58, 0.75, 0.45, 0.28)
	ring.z_index = 58
	beacon.add_child(ring)

	var scene: Node = get_tree().current_scene if get_tree() else self
	scene.add_child(beacon)

	var tick_timer: Timer = Timer.new()
	tick_timer.wait_time = beacon_tick_interval
	tick_timer.one_shot = false
	tick_timer.autostart = true
	beacon.add_child(tick_timer)
	tick_timer.timeout.connect(_on_beacon_tick.bind(beacon, radius, tick_damage, duration_amp, empowered))

	var life_timer: Timer = Timer.new()
	life_timer.wait_time = max(0.5, duration)
	life_timer.one_shot = true
	life_timer.autostart = true
	beacon.add_child(life_timer)
	life_timer.timeout.connect(_on_beacon_timeout.bind(beacon))

func _on_beacon_tick(beacon: Node2D, radius: float, tick_damage: int, duration_amp: float, empowered: bool) -> void:
	if not is_instance_valid(beacon):
		return
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var hit_count: int = 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		if enemy_node.global_position.distance_to(beacon.global_position) > radius:
			continue
		if enemy_node.has_node("HealthComponent"):
			enemy_node.get_node("HealthComponent").take_damage(tick_damage)
		if enemy_node.has_method("apply_status"):
			enemy_node.apply_status("slow", 0.8 * duration_amp, 0.32)
			if empowered:
				enemy_node.apply_status("marked", 1.0 * duration_amp, 0.16)
		hit_count += 1
	if hit_count > 0:
		spawn_skill_vfx(beacon.global_position, Color(0.6, 0.82, 0.52, 0.62), 0.35)

func _on_beacon_timeout(beacon: Node2D) -> void:
	if is_instance_valid(beacon):
		beacon.queue_free()

func _detonate_at(center: Vector2, damage: int, radius: float) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		if enemy_node.global_position.distance_to(center) > radius:
			continue
		if enemy_node.has_node("HealthComponent"):
			enemy_node.get_node("HealthComponent").take_damage(damage)
		if enemy_node.has_method("apply_status"):
			enemy_node.apply_status("slow", 1.0, 0.35)
		if enemy_node.has_method("apply_knockback"):
			var dir: Vector2 = (enemy_node.global_position - center).normalized()
			enemy_node.apply_knockback(dir, 420.0)
	spawn_skill_vfx(center, Color(0.75, 0.95, 0.62, 0.75), 0.7)

func _pick_nearest_enemy(origin: Vector2) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dist: float = origin.distance_to(enemy_node.global_position)
		if dist < nearest_dist:
			nearest = enemy_node
			nearest_dist = dist
	return nearest

func _build_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var seg_count: int = max(6, segments)
	for i in range(seg_count):
		var angle: float = TAU * float(i) / float(seg_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
