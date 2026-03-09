extends SkillBase
class_name SkillGamblerE

var buff_value: float = 1.0
var buff_duration: float = 5.0
var self_damage: int = 30

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.30, 0.26)
	var duration_amp: float = get_e_duration_amp(0.34)
	var f_active: bool = is_f_window_active()
	var bad_streak: int = int(skill_owner.get_meta("gambler_e_bad_streak", 0))
	var jackpot_rate: float = 0.22 + min(0.36, float(bad_streak) * 0.08) + (0.08 if f_active else 0.0)
	var stable_rate: float = 0.50
	var roll: float = randf()

	if roll < jackpot_rate:
		skill_owner.set_meta("gambler_e_bad_streak", 0)
		_apply_temp_meta_delta("attack_boost", buff_value * damage_amp, buff_duration * duration_amp)
		var burst_damage: int = max(1, int(round(58.0 * damage_amp * (1.0 + float(min(3, bad_streak)) * 0.12))))
		var hit: int = _burst_hit(skill_owner.global_position, 180.0 * duration_amp, burst_damage)
		_drop_coins_at(skill_owner.global_position, 2 + (1 if f_active else 0))
		Global.spawn_floating_text(skill_owner.global_position, "JACKPOT x%d" % max(1, hit), Color(1.0, 0.88, 0.2))
		Global.on_camera_shake.emit(8.8, 0.20)
		start_cooldown()
		return

	if roll < jackpot_rate + stable_rate:
		skill_owner.set_meta("gambler_e_bad_streak", bad_streak + 1)
		var energy_gain: float = 18.0 + (6.0 if f_active else 0.0)
		if skill_owner.has_method("gain_energy"):
			skill_owner.gain_energy(energy_gain)
		_apply_temp_meta_delta("buff_cooldown_reduction", 0.12 if not f_active else 0.18, 1.8 * duration_amp)
		var hit2: int = _burst_hit(skill_owner.global_position, 150.0 * duration_amp, max(1, int(round(28.0 * damage_amp))))
		Global.spawn_floating_text(skill_owner.global_position, "SAFE BET x%d" % max(1, hit2), Color(0.9, 0.82, 0.3))
		start_cooldown()
		return

	skill_owner.set_meta("gambler_e_bad_streak", bad_streak + 1)
	var real_self_damage: int = max(1, int(round(float(self_damage) * (0.7 if f_active else 1.0))))
	_damage_owner(real_self_damage)
	var consolation_energy: float = 20.0 + 5.0 * float(min(3, bad_streak))
	if skill_owner.has_method("gain_energy"):
		skill_owner.gain_energy(consolation_energy)
	_burst_status(skill_owner.global_position, 180.0 * duration_amp, "marked", 1.3, 0.18, "BUST!")
	Global.spawn_floating_text(skill_owner.global_position, "BUST", Color(0.92, 0.32, 0.28))
	start_cooldown()

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

func _burst_hit(center: Vector2, radius: float, damage: int) -> int:
	var hit: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "marked", 1.0, 0.16, 1, 0.3)
		hit += 1
	return hit

func _burst_status(center: Vector2, radius: float, status_name: String, duration: float, value: float, text: String) -> void:
	var affected: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		_apply_status(enemy, status_name, duration, value, 1, 0.3)
		affected += 1
	if affected > 0:
		Global.spawn_floating_text(center, "%s x%d" % [text, affected], Color(0.95, 0.52, 0.35))

func _damage_owner(amount: int) -> void:
	if not is_instance_valid(skill_owner):
		return
	if skill_owner.has_node("HealthComponent"):
		var hc: Node = skill_owner.get_node("HealthComponent")
		if hc and hc.has_method("take_damage"):
			hc.take_damage(max(1, amount))

func _drop_coins_at(center: Vector2, count: int) -> void:
	if count <= 0:
		return
	if not Global.has_method("spawn_coin"):
		return
	for i in range(count):
		var offset: Vector2 = Vector2(randf_range(-50.0, 50.0), randf_range(-50.0, 50.0))
		Global.spawn_coin(center + offset, 1)

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
