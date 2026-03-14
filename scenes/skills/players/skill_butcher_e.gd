extends SkillBase
class_name SkillButcherE

var e_damage_or_heal: float = 1.2
var e_control_duration_or_buff_duration: float = 1.8
var stake_impact_damage: int = 26
var stake_duration: float = 5.6

var hook_radius: float = 900.0
var pull_force: float = 980.0
var chain_synergy_range: float = 420.0
var chain_synergy_damage_ratio: float = 0.72
var chain_synergy_pull_ratio: float = 0.78
const BUTCHER_E_CHAIN_META: String = "butcher_e_chain_until_msec"

func execute() -> void:
	if not can_execute():
		if is_on_cooldown and is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "Cooldown!", Color.YELLOW)
		return

	var target: Node2D = _find_nearest_enemy(hook_radius)
	if target == null:
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "MISS", Color(1.0, 0.75, 0.55))
		return

	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return

	var damage_amp: float = get_e_damage_amp(0.45, 0.4)
	var duration_amp: float = get_e_duration_amp(0.45)
	var final_damage: int = max(1, int(round(float(stake_impact_damage) * e_damage_or_heal * damage_amp)))
	var control_duration: float = max(0.4, e_control_duration_or_buff_duration * duration_amp)
	var final_pull: float = max(420.0, pull_force * (0.75 + duration_amp * 0.3))

	_pull_target(target, final_pull)
	_apply_damage(target, final_damage)
	_apply_status(target, "stun", control_duration, 0.0)
	_apply_status(target, "marked", max(1.1, control_duration), 0.18 * damage_amp)
	spawn_skill_vfx(target.global_position, Color(1.2, 0.35, 0.25, 0.9), 0.7)
	Global.spawn_floating_text(target.global_position, "HOOK!", Color(1.25, 0.55, 0.3))
	Global.on_camera_shake.emit(6.5, 0.12)

	if _enemy_has_status(target, "slow") or _enemy_has_status(target, "marked"):
		var target_ref: WeakRef = weakref(target)
		var follow_damage: int = max(1, int(round(float(final_damage) * 0.58)))
		get_tree().create_timer(0.32).timeout.connect(
			_on_follow_rip_timeout.bind(target_ref, follow_damage)
		)

	_apply_chain_anchor_synergy(target, final_damage, final_pull, control_duration)
	var chain_window: float = 2.2 + (0.6 if is_f_window_active() else 0.0)
	skill_owner.set_meta(BUTCHER_E_CHAIN_META, Time.get_ticks_msec() + int(round(chain_window * 1000.0)))

	start_cooldown()

func _find_nearest_enemy(max_distance: float) -> Node2D:
	if not is_inside_tree() or not is_instance_valid(skill_owner):
		return null
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var best: Node2D = null
	var best_dist: float = max_distance
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist: float = skill_owner.global_position.distance_to(enemy.global_position)
		if dist <= best_dist:
			best = enemy
			best_dist = dist
	return best

func _pull_target(enemy: Node2D, force: float) -> void:
	if enemy == null or not is_instance_valid(enemy) or not is_instance_valid(skill_owner):
		return
	var pull_dir: Vector2 = (skill_owner.global_position - enemy.global_position).normalized()
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", pull_dir, force)
	else:
		enemy.global_position += pull_dir * min(72.0, force * 0.08)

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

func _enemy_has_status(enemy: Node2D, status_type: String) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.has_method("has_status"):
		return bool(enemy.call("has_status", status_type))
	return false

func _apply_chain_anchor_synergy(target: Node2D, final_damage: int, final_pull: float, control_duration: float) -> void:
	var anchor: Node2D = _find_active_saw_anchor(target.global_position, chain_synergy_range)
	if anchor == null:
		return
	var pull_to_anchor: float = max(360.0, final_pull * chain_synergy_pull_ratio)
	var extra_damage: int = max(1, int(round(float(final_damage) * chain_synergy_damage_ratio)))
	_pull_to_anchor(target, anchor.global_position, pull_to_anchor)
	_apply_damage(target, extra_damage)
	_apply_status(target, "slow", max(0.9, control_duration * 0.8), 0.45)
	_apply_status(target, "curse", max(1.2, control_duration), 10.0)
	spawn_skill_vfx(anchor.global_position, Color(1.2, 0.28, 0.26, 0.88), 0.55)
	Global.spawn_floating_text(anchor.global_position, "CHAIN RIP!", Color(1.25, 0.38, 0.3))
	if is_f_window_active():
		_apply_chain_cleave(anchor.global_position, extra_damage)

func _find_active_saw_anchor(reference_pos: Vector2, max_distance: float) -> Node2D:
	if not is_inside_tree():
		return null
	var nodes: Array = get_tree().get_nodes_in_group("projectiles")
	var best: Node2D = null
	var best_dist: float = max_distance
	for node_var: Variant in nodes:
		if node_var == null or not is_instance_valid(node_var):
			continue
		if not (node_var is Node2D):
			continue
		var node2d: Node2D = node_var
		var node_name: String = String(node2d.name)
		if node_name.findn("Saw_") != 0:
			continue
		var landed: bool = bool(node2d.get("is_landed")) if "is_landed" in node2d else false
		if not landed:
			continue
		var dist: float = reference_pos.distance_to(node2d.global_position)
		if dist > best_dist:
			continue
		best_dist = dist
		best = node2d
	return best

func _pull_to_anchor(enemy: Node2D, anchor_pos: Vector2, force: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var pull_dir: Vector2 = (anchor_pos - enemy.global_position).normalized()
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", pull_dir, force)
	else:
		enemy.global_position += pull_dir * min(88.0, force * 0.1)

func _apply_chain_cleave(center: Vector2, damage: int) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var cleave_radius: float = 130.0
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > cleave_radius:
			continue
		_apply_damage(enemy, max(1, int(round(float(damage) * 0.5))))
		_apply_status(enemy, "marked", 1.1, 0.15)

func _on_follow_rip_timeout(target_ref: WeakRef, follow_damage: int) -> void:
	var target: Variant = target_ref.get_ref() if target_ref != null else null
	if target == null or not is_instance_valid(target):
		return
	if not (target is Node2D):
		return
	var enemy: Node2D = target
	_apply_damage(enemy, follow_damage)
	_apply_status(enemy, "curse", max(1.2, stake_duration * 0.35), 9.0)
	Global.spawn_floating_text(enemy.global_position, "RIP!", Color(1.3, 0.25, 0.25))
