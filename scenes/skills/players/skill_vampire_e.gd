extends SkillBase
class_name SkillVampireE

var drain_radius: float = 200.0
var drain_damage: int = 40
var heal_percent: float = 0.5

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.30, 0.36)
	var duration_amp: float = get_e_duration_amp(0.35)
	var final_radius: float = drain_radius * (1.0 + (duration_amp - 1.0) * 0.34)
	var base_damage: int = max(1, int(round(float(drain_damage) * damage_amp)))
	var heal_scale: float = heal_percent * (1.0 + (damage_amp - 1.0) * 0.45)
	var target: Node2D = _pick_priority_target(skill_owner.global_position, final_radius)

	if target != null:
		var to_target: Vector2 = target.global_position - skill_owner.global_position
		if to_target.length_squared() > 0.01:
			skill_owner.global_position += to_target.normalized() * min(90.0, to_target.length() * 0.45)
		_apply_damage(target, base_damage)
		_apply_status(target, "curse", 2.2 * duration_amp, max(1.0, float(base_damage) * 0.28), 1, 0.7)
		_apply_status(target, "marked", 1.4, 0.22, 1, 0.3)
		var healed: int = max(1, int(round(float(base_damage) * heal_scale)))
		_heal_owner(healed)
		Global.spawn_floating_text(target.global_position, "BITE!", Color(0.95, 0.25, 0.25))
		if is_f_window_active():
			var timer: SceneTreeTimer = get_tree().create_timer(0.18)
			timer.timeout.connect(_on_blood_nova_timeout.bind(target.global_position, final_radius * 0.52, int(round(float(base_damage) * 0.72)), duration_amp))
	else:
		var total_damage: int = 0
		for enemy in _get_enemies_in_radius(skill_owner.global_position, final_radius):
			_apply_damage(enemy, base_damage)
			_apply_status(enemy, "curse", 1.6 * duration_amp, max(1.0, float(base_damage) * 0.22), 1, 0.7)
			total_damage += base_damage
		if total_damage > 0:
			var aoe_heal: int = max(1, int(round(float(total_damage) * heal_scale * 0.65)))
			_heal_owner(aoe_heal)
		else:
			Global.spawn_floating_text(skill_owner.global_position, "No Target!", Color(0.8, 0.7, 0.7))

	spawn_skill_vfx(skill_owner.global_position, Color(0.88, 0.2, 0.25, 0.8), 0.74)
	Global.on_camera_shake.emit(7.5, 0.14)
	start_cooldown()

func _on_blood_nova_timeout(center: Vector2, radius: float, damage: int, duration_amp: float) -> void:
	var hit: int = 0
	for enemy in _get_enemies_in_radius(center, radius):
		_apply_damage(enemy, damage)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.32, 1, 0.1)
		_apply_status(enemy, "curse", 1.4 * duration_amp, max(1.0, float(damage) * 0.24), 1, 0.7)
		hit += 1
	if hit > 0 and is_instance_valid(skill_owner):
		var heal_amount: int = max(1, int(round(float(damage) * float(hit) * heal_percent * 0.35)))
		_heal_owner(heal_amount)
		Global.spawn_floating_text(skill_owner.global_position, "BLOOD NOVA", Color(0.95, 0.28, 0.28))
	spawn_skill_vfx(center, Color(0.95, 0.22, 0.3, 0.82), 0.66)

func _pick_priority_target(center: Vector2, radius: float) -> Node2D:
	var enemies: Array = _get_enemies_in_radius(center, radius)
	for enemy in enemies:
		if enemy.has_method("has_status") and enemy.has_status("marked"):
			return enemy
	for enemy in enemies:
		if enemy.has_method("has_status") and enemy.has_status("curse"):
			return enemy
	return enemies[0] if not enemies.is_empty() else null

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

func _heal_owner(amount: int) -> void:
	if amount <= 0:
		return
	if not is_instance_valid(skill_owner):
		return
	if skill_owner.has_node("HealthComponent"):
		var hc: Node = skill_owner.get_node("HealthComponent")
		if hc and hc.has_method("heal"):
			hc.heal(float(amount))
