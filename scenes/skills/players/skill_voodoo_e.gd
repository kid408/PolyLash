extends SkillBase
class_name SkillVoodooE

var self_damage: int = 20
var curse_damage: int = 60

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.28, 0.38)
	var duration_amp: float = get_e_duration_amp(0.36)
	var real_self_damage: int = max(1, int(round(float(self_damage) * (0.78 if is_f_window_active() else 1.0))))
	var real_curse_damage: int = max(1, int(round(float(curse_damage) * damage_amp)))

	_damage_owner(real_self_damage)

	var cursed_refs: Array = []
	var direct_hits: int = 0
	for enemy in _get_enemies_in_radius(skill_owner.global_position, 520.0):
		if not _has_status(enemy, "curse"):
			continue
		_apply_damage(enemy, real_curse_damage)
		_apply_status(enemy, "slow", 1.1 * duration_amp, 0.28, 1, 0.1)
		cursed_refs.append(weakref(enemy))
		direct_hits += 1

	if cursed_refs.is_empty():
		for seed_enemy in _get_enemies_in_radius(skill_owner.global_position, 190.0 * duration_amp):
			_apply_status(seed_enemy, "curse", 2.2 * duration_amp, 8.0, 1, 0.7)
		Global.spawn_floating_text(skill_owner.global_position, "HEX SEED", Color(0.75, 0.36, 0.62))
		start_cooldown()
		return

	var link_delay: float = 0.24 if not is_f_window_active() else 0.16
	var timer: SceneTreeTimer = get_tree().create_timer(link_delay)
	timer.timeout.connect(_on_link_timeout.bind(cursed_refs, int(round(float(real_curse_damage) * 0.55)), duration_amp))

	Global.spawn_floating_text(skill_owner.global_position, "VOODOO x%d" % direct_hits, Color(0.74, 0.28, 0.62))
	Global.on_camera_shake.emit(8.2, 0.16)
	start_cooldown()

func _on_link_timeout(target_refs: Array, damage: int, duration_amp: float) -> void:
	var valid_targets: Array = []
	for ref_obj in target_refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		if target is Node2D:
			valid_targets.append(target)
	if valid_targets.is_empty():
		return

	var hit: int = 0
	for i in range(valid_targets.size()):
		var from_target: Node2D = valid_targets[i]
		var to_target: Node2D = valid_targets[(i + 1) % valid_targets.size()]
		if from_target == to_target:
			continue
		var center: Vector2 = (from_target.global_position + to_target.global_position) * 0.5
		for enemy in _get_enemies_in_radius(center, 66.0):
			_apply_damage(enemy, damage)
			_apply_status(enemy, "marked", 1.2, 0.18, 1, 0.3)
			hit += 1
		spawn_skill_vfx(center, Color(0.78, 0.35, 0.68, 0.76), 0.55)
	if hit > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "LINK x%d" % hit, Color(0.78, 0.35, 0.68))
		_heal_owner(int(round(float(hit) * 2.0 * duration_amp)))

func _has_status(enemy: Node, status_name: String) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy.has_node("StatusComponent"):
		var status_comp: Node = enemy.get_node("StatusComponent")
		if status_comp and status_comp.has_method("has_status"):
			return bool(status_comp.has_status(status_name))
	if enemy.has_method("has_status"):
		return bool(enemy.has_status(status_name))
	return false

func _damage_owner(amount: int) -> void:
	if amount <= 0:
		return
	if not is_instance_valid(skill_owner):
		return
	if skill_owner.has_node("HealthComponent"):
		var hc: Node = skill_owner.get_node("HealthComponent")
		if hc and hc.has_method("take_damage"):
			hc.take_damage(amount)

func _heal_owner(amount: int) -> void:
	if amount <= 0:
		return
	if not is_instance_valid(skill_owner):
		return
	if skill_owner.has_node("HealthComponent"):
		var hc: Node = skill_owner.get_node("HealthComponent")
		if hc and hc.has_method("heal"):
			hc.heal(float(amount))

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
