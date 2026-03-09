extends SkillBase
class_name SkillTeslaE

var silence_duration: float = 3.0
var silence_radius: float = 200.0

var chain_range: float = 280.0
var chain_base_damage: int = 24
var chain_jump_count: int = 3
var chain_decay: float = 0.82

func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.25, 0.32)
	var duration_amp: float = get_e_duration_amp(0.35)
	var final_radius: float = silence_radius * (1.0 + (duration_amp - 1.0) * 0.3)
	var final_duration: float = silence_duration * duration_amp
	var final_damage: int = max(1, int(round(30.0 * damage_amp)))

	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var hit_count: int = 0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		if skill_owner.global_position.distance_to(enemy_node.global_position) > final_radius:
			continue
		if enemy_node.has_node("HealthComponent"):
			enemy_node.get_node("HealthComponent").take_damage(final_damage)
		if enemy_node.has_method("apply_status"):
			enemy_node.apply_status("silence", final_duration)
		hit_count += 1

	var jump_count: int = chain_jump_count + (2 if is_f_window_active() else 0)
	var chain_hits: int = _emit_overload_chain(skill_owner.global_position, jump_count, damage_amp, duration_amp, is_f_window_active())
	Global.spawn_floating_text(skill_owner.global_position, "EMP x%d / ARC x%d" % [hit_count, chain_hits], Color(0.35, 0.82, 1.25))

	spawn_skill_vfx(skill_owner.global_position, Color(0.3, 0.7, 1.0, 0.8), 0.7)
	Global.on_camera_shake.emit(6.0, 0.2)
	start_cooldown()

func _emit_overload_chain(origin: Vector2, jumps: int, damage_amp: float, duration_amp: float, empowered: bool) -> int:
	var hit_count: int = 0
	var used: Array = []
	var current_pos: Vector2 = origin
	var current_damage: float = float(chain_base_damage) * damage_amp
	for i in range(max(1, jumps)):
		var target: Node2D = _pick_next_enemy(current_pos, chain_range, used)
		if target == null:
			break
		used.append(target)
		current_pos = target.global_position
		if target.has_node("HealthComponent"):
			target.get_node("HealthComponent").take_damage(max(1, int(round(current_damage))))
		if target.has_method("apply_status"):
			if i == 0 and empowered:
				target.apply_status("stun", 0.55 * duration_amp, 0.0)
			target.apply_status("marked", 1.4 * duration_amp, 0.2)
		spawn_skill_vfx(target.global_position, Color(0.45, 0.95, 1.35, 0.72), 0.4)
		current_damage *= chain_decay
		hit_count += 1
	return hit_count

func _pick_next_enemy(origin: Vector2, radius: float, used: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = radius
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		if used.has(enemy):
			continue
		var enemy_node: Node2D = enemy
		var dist: float = origin.distance_to(enemy_node.global_position)
		if dist <= nearest_dist:
			nearest = enemy_node
			nearest_dist = dist
	return nearest
