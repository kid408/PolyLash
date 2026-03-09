extends SkillBase
class_name SkillMerchantE

var gold_amount: int = 50

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.22, 0.30)
	var duration_amp: float = get_e_duration_amp(0.35)
	var main_coins: int = max(1, int(round(float(gold_amount) * (1.0 + (damage_amp - 1.0) * 0.70))))
	var mark_count: int = 3 if not is_f_window_active() else 5
	var settlement_delay: float = 0.34 if not is_f_window_active() else 0.24
	var settle_damage: int = max(1, int(round(32.0 * damage_amp)))

	_drop_coins_at(skill_owner.global_position, min(8, main_coins))
	if main_coins > 8:
		_drop_coins_at(skill_owner.global_position + Vector2(26, -8), main_coins - 8)

	var targets: Array = _pick_nearest_enemies(skill_owner.global_position, 260.0 * duration_amp, mark_count)
	var refs: Array = []
	for enemy in targets:
		_apply_status(enemy, "marked", 1.8 * duration_amp, 0.26, 1, 0.3)
		_apply_status(enemy, "slow", 1.0, 0.24, 1, 0.1)
		refs.append(weakref(enemy))

	if not refs.is_empty():
		var timer: SceneTreeTimer = get_tree().create_timer(settlement_delay)
		timer.timeout.connect(_on_settlement_timeout.bind(refs, settle_damage, duration_amp))

	_apply_temp_meta_delta("buff_speed_boost", 0.10 if not is_f_window_active() else 0.16, 1.8 * duration_amp)
	if is_f_window_active():
		_apply_temp_meta_delta("buff_cooldown_reduction", 0.08, 1.8 * duration_amp)

	Global.spawn_floating_text(skill_owner.global_position, "SETTLEMENT", Color(1.0, 0.88, 0.4))
	Global.on_camera_shake.emit(6.2, 0.14)
	start_cooldown()

func _on_settlement_timeout(target_refs: Array, damage: int, duration_amp: float) -> void:
	var hit: int = 0
	for ref_obj in target_refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		_apply_damage(target, damage)
		_apply_status(target, "marked", 1.2 * duration_amp, 0.18, 1, 0.3)
		if target is Node2D:
			_drop_coins_at((target as Node2D).global_position, 1)
		hit += 1
	if hit > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "PROFIT x%d" % hit, Color(1.0, 0.9, 0.46))

func _pick_nearest_enemies(center: Vector2, radius: float, count: int) -> Array:
	var sorted: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dist: float = center.distance_to(enemy_node.global_position)
		if dist > radius:
			continue
		var inserted: bool = false
		for i in range(sorted.size()):
			var current: Node2D = sorted[i]
			if dist < center.distance_to(current.global_position):
				sorted.insert(i, enemy_node)
				inserted = true
				break
		if not inserted:
			sorted.append(enemy_node)
	if sorted.size() > count:
		sorted.resize(count)
	return sorted

func _apply_temp_meta_delta(meta_key: String, delta: float, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	if meta_key.strip_edges() == "":
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

func _drop_coins_at(center: Vector2, count: int) -> void:
	if count <= 0:
		return
	if not Global.has_method("spawn_coin"):
		return
	for i in range(count):
		var offset: Vector2 = Vector2(randf_range(-45.0, 45.0), randf_range(-45.0, 45.0))
		Global.spawn_coin(center + offset, 1)

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
