extends SkillBase
class_name SkillIllusionistE

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.28, 0.30)
	var duration_amp: float = get_e_duration_amp(0.36)
	var strike_damage: int = max(1, int(round(44.0 * damage_amp)))
	var strike_radius: float = 130.0 * (1.0 + (duration_amp - 1.0) * 0.42)
	var speed_delta: float = 0.14 + (0.04 if is_f_window_active() else 0.0)
	var speed_duration: float = 2.1 * duration_amp

	var phantom: Node2D = _pick_nearest_phantom()
	if phantom == null:
		Global.spawn_floating_text(skill_owner.global_position, "No Phantom!", Color(0.72, 0.74, 0.84))
		start_cooldown()
		return

	var owner_pos: Vector2 = skill_owner.global_position
	var phantom_pos: Vector2 = phantom.global_position
	skill_owner.global_position = phantom_pos
	phantom.global_position = owner_pos

	_hit_enemies_at(owner_pos, strike_radius, strike_damage)
	_hit_enemies_at(phantom_pos, strike_radius, strike_damage)
	_apply_temp_meta_delta("buff_speed_boost", speed_delta, speed_duration)

	var timer: SceneTreeTimer = get_tree().create_timer(0.18 if not is_f_window_active() else 0.12)
	timer.timeout.connect(_on_mirror_slice_timeout.bind(owner_pos, phantom_pos, int(round(float(strike_damage) * 0.66))))

	spawn_skill_vfx(skill_owner.global_position, Color(0.74, 0.75, 1.0, 0.78), 0.70)
	Global.on_camera_shake.emit(7.6, 0.14)
	Global.spawn_floating_text(skill_owner.global_position, "MIRROR SWAP", Color(0.74, 0.76, 1.0))
	start_cooldown()

func _on_mirror_slice_timeout(start_pos: Vector2, end_pos: Vector2, damage: int) -> void:
	var line_center: Vector2 = (start_pos + end_pos) * 0.5
	var line_dir: Vector2 = (end_pos - start_pos).normalized()
	var line_len: float = start_pos.distance_to(end_pos)
	var half_width: float = 46.0
	var hit: int = 0
	for enemy in _get_enemies_in_radius(line_center, line_len * 0.8 + 70.0):
		var rel: Vector2 = enemy.global_position - line_center
		var forward: float = absf(rel.dot(line_dir))
		if forward > line_len * 0.5 + 22.0:
			continue
		var side: float = absf(rel.dot(line_dir.orthogonal()))
		if side > half_width:
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "marked", 1.4, 0.20, 1, 0.3)
		_apply_status(enemy, "slow", 0.9, 0.26, 1, 0.1)
		hit += 1
	if hit > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "SLICE x%d" % hit, Color(0.78, 0.78, 1.0))

func _pick_nearest_phantom() -> Node2D:
	if SkillEffectManager == null:
		return null
	if not ("active_effects" in SkillEffectManager):
		return null
	var nearest: Node2D = null
	var best: float = INF
	for eid in SkillEffectManager.active_effects.keys():
		var data: Dictionary = SkillEffectManager.active_effects[eid]
		if str(data.get("type", "")) != "summon":
			continue
		if str(data.get("owner_skill_id", "")) != "skill_illusionist_q":
			continue
		var node = data.get("node")
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		var node2d: Node2D = node
		var dist: float = skill_owner.global_position.distance_to(node2d.global_position)
		if dist < best:
			best = dist
			nearest = node2d
	return nearest

func _hit_enemies_at(center: Vector2, radius: float, damage: int) -> void:
	for enemy in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "marked", 1.2, 0.16, 1, 0.3)

func _apply_temp_meta_delta(meta_key: String, delta: float, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var old_value: float = float(skill_owner.get_meta(meta_key, 0.0))
	skill_owner.set_meta(meta_key, old_value + delta)
	var owner_ref: WeakRef = weakref(skill_owner)
	var timer: SceneTreeTimer = get_tree().create_timer(max(0.1, duration))
	timer.timeout.connect(_on_temp_meta_timeout.bind(owner_ref, meta_key, delta))

func _on_temp_meta_timeout(owner_ref: WeakRef, meta_key: String, delta: float) -> void:
	var owner = owner_ref.get_ref() if owner_ref != null else null
	if owner == null or not is_instance_valid(owner):
		return
	if not owner.has_meta(meta_key):
		return
	var current: float = float(owner.get_meta(meta_key))
	var next: float = current - delta
	if absf(next) <= 0.0001:
		owner.remove_meta(meta_key)
	else:
		owner.set_meta(meta_key, next)

func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var result: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		if center.distance_to(enemy_node.global_position) <= radius:
			result.append(enemy_node)
	return result

func _apply_damage(enemy: Node, amount: int) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_node("HealthComponent"):
		var hc: Node = enemy.get_node("HealthComponent")
		if hc and hc.has_method("take_damage"):
			hc.take_damage(max(1, amount))

func _apply_status(enemy: Node, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.apply_status(status_name, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))
