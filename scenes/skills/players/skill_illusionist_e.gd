extends SkillEBase
class_name SkillIllusionistE

const MIRROR_META_CENTER: String = "illusion_mirror_center"
const MIRROR_META_RADIUS: String = "illusion_mirror_radius"
const MIRROR_META_EXPIRE_MSEC: String = "illusion_mirror_expire_msec"

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

	var mirror_data: Array = _get_mirror_window(skill_owner.global_position, strike_radius)
	var synergy_used: bool = bool(mirror_data[0])
	var mirror_center: Vector2 = skill_owner.global_position
	var mirror_radius: float = strike_radius
	if synergy_used and mirror_data.size() > 1 and mirror_data[1] is Vector2:
		mirror_center = mirror_data[1]
	if synergy_used and mirror_data.size() > 2:
		mirror_radius = max(strike_radius, float(mirror_data[2]))

	var phantom: Node2D = _pick_nearest_phantom()
	if phantom == null:
		if synergy_used:
			_hit_enemies_at(mirror_center, mirror_radius * 0.9, int(round(float(strike_damage) * 0.85)))
			_apply_temp_meta_delta("buff_speed_boost", speed_delta * 0.8, speed_duration)
			Global.spawn_floating_text(skill_owner.global_position, "MIRROR ECHO", Color(0.72, 0.74, 0.84))
			_refund_q_cooldown(1.0)
			start_cooldown()
			return
		Global.spawn_floating_text(skill_owner.global_position, "No Phantom!", Color(0.72, 0.74, 0.84))
		start_cooldown()
		return

	var owner_pos: Vector2 = skill_owner.global_position
	var phantom_pos: Vector2 = phantom.global_position
	skill_owner.global_position = phantom_pos
	phantom.global_position = owner_pos

	_hit_enemies_at(owner_pos, strike_radius, strike_damage)
	_hit_enemies_at(phantom_pos, strike_radius, strike_damage)
	if synergy_used:
		_hit_enemies_at(mirror_center, mirror_radius * 0.7, int(round(float(strike_damage) * 0.62)))
	_apply_temp_meta_delta("buff_speed_boost", speed_delta, speed_duration)

	var timer: SceneTreeTimer = get_tree().create_timer(0.18 if not is_f_window_active() else 0.12)
	timer.timeout.connect(
		_on_mirror_slice_timeout.bind(
			owner_pos,
			phantom_pos,
			int(round(float(strike_damage) * 0.66)),
			synergy_used
		)
	)

	if synergy_used:
		_refund_q_cooldown(1.0)
	spawn_skill_vfx(skill_owner.global_position, Color(0.74, 0.75, 1.0, 0.78), 0.70)
	Global.on_camera_shake.emit(7.6, 0.14)
	Global.spawn_floating_text(skill_owner.global_position, "MIRROR SWAP", Color(0.74, 0.76, 1.0))
	start_cooldown()

func _on_mirror_slice_timeout(start_pos: Vector2, end_pos: Vector2, damage: int, synergy_used: bool) -> void:
	var line_center: Vector2 = (start_pos + end_pos) * 0.5
	var line_delta: Vector2 = end_pos - start_pos
	if line_delta.length_squared() <= 0.01:
		line_delta = Vector2.RIGHT
	var line_dir: Vector2 = line_delta.normalized()
	var line_len: float = start_pos.distance_to(end_pos)
	var half_width: float = 46.0
	var hit: int = 0
	for enemy: Node2D in _get_enemies_in_radius(line_center, line_len * 0.8 + 70.0):
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
		if synergy_used:
			_apply_status(enemy, "fear", 0.5, 1.0, 1, 0.2)
		hit += 1
	if hit > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "SLICE x%d" % hit, Color(0.78, 0.78, 1.0))

func _get_mirror_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(MIRROR_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(MIRROR_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(MIRROR_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(MIRROR_META_RADIUS, default_radius)
	if not (center_val is Vector2):
		return data
	data[0] = true
	data[1] = center_val
	data[2] = max(default_radius, float(radius_val))
	return data

func _refund_q_cooldown(seconds: float) -> void:
	if seconds <= 0.0 or not is_instance_valid(skill_owner):
		return
	var skill_manager: Node = skill_owner.get_node_or_null("SkillManager")
	if skill_manager == null or not ("skill_slots" in skill_manager):
		return
	var slots: Dictionary = skill_manager.skill_slots
	if not slots.has("q"):
		return
	var q_skill_obj: Variant = slots.get("q")
	if q_skill_obj == null or not (q_skill_obj is SkillBase):
		return
	var q_skill: SkillBase = q_skill_obj
	var remaining: float = q_skill.get_cooldown_remaining()
	if remaining <= 0.0:
		return
	q_skill.set_cooldown_remaining(max(0.0, remaining - seconds))

func _pick_nearest_phantom() -> Node2D:
	if SkillEffectManager == null:
		return null
	if not ("active_effects" in SkillEffectManager):
		return null
	var nearest: Node2D = null
	var best: float = INF
	for eid: Variant in SkillEffectManager.active_effects.keys():
		var data: Dictionary = SkillEffectManager.active_effects[eid]
		if str(data.get("type", "")) != "summon":
			continue
		if str(data.get("owner_skill_id", "")) != "skill_illusionist_q":
			continue
		var node_obj: Variant = data.get("node")
		if node_obj == null or not is_instance_valid(node_obj):
			continue
		if not (node_obj is Node2D):
			continue
		var node2d: Node2D = node_obj
		var dist: float = skill_owner.global_position.distance_to(node2d.global_position)
		if dist < best:
			best = dist
			nearest = node2d
	return nearest

func _hit_enemies_at(center: Vector2, radius: float, damage: int) -> void:
	for enemy: Node2D in _get_enemies_in_radius(center, radius):
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
	var owner: Variant = owner_ref.get_ref() if owner_ref != null else null
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
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy_node: Node2D = enemy_obj
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

