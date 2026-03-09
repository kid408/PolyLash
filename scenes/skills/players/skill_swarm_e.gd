extends SkillBase
class_name SkillSwarmE

func execute() -> void:
	if not consume_energy():
		if skill_owner:
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var nearest_enemy: Node2D = _pick_nearest_enemy(skill_owner.global_position)
	if SkillEffectManager != null and SkillEffectManager.has_method("command_summons"):
		SkillEffectManager.command_summons("skill_swarm_q", "focus_fire", nearest_enemy)

	var damage_amp: float = get_e_damage_amp(0.2, 0.28)
	var duration_amp: float = get_e_duration_amp(0.3)
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		get_tree().create_timer(0.2).timeout.connect(
			_on_brood_dive_timeout.bind(weakref(nearest_enemy), damage_amp, duration_amp, is_f_window_active())
		)

	if is_f_window_active():
		var swarm_boost: float = 0.2 + (duration_amp - 1.0) * 0.4
		_apply_temp_attack_boost(swarm_boost, 2.2 * duration_amp)
		Global.spawn_floating_text(skill_owner.global_position, "BROOD FRENZY!", Color(0.7, 0.9, 0.35))

	Global.spawn_floating_text(skill_owner.global_position, "FOCUS FIRE!", Color(0.5, 0.4, 0.1))
	start_cooldown()

func _on_brood_dive_timeout(target_ref: WeakRef, damage_amp: float, duration_amp: float, empowered: bool) -> void:
	var target = target_ref.get_ref() if target_ref != null else null
	if target == null or not is_instance_valid(target):
		return
	if not (target is Node2D):
		return
	var center: Vector2 = target.global_position
	var radius: float = 120.0 * (1.25 if empowered else 1.0)
	var damage: int = max(1, int(round(24.0 * damage_amp * (1.35 if empowered else 1.0))))
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var hits: int = 0
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
			enemy_node.apply_status("poison", 1.6 * duration_amp, max(1.0, float(damage) * 0.4))
		hits += 1
	if hits > 0:
		spawn_skill_vfx(center, Color(0.65, 0.78, 0.28, 0.75), 0.6)
		Global.spawn_floating_text(center, "BROOD DIVE x%d" % hits, Color(0.75, 0.9, 0.35))

func _apply_temp_attack_boost(boost: float, duration: float) -> void:
	if boost <= 0.0 or duration <= 0.0:
		return
	if not is_instance_valid(skill_owner):
		return
	var current: float = 0.0
	if skill_owner.has_meta("attack_boost"):
		current = float(skill_owner.get_meta("attack_boost"))
	skill_owner.set_meta("attack_boost", current + boost)
	get_tree().create_timer(duration).timeout.connect(_on_attack_boost_timeout.bind(boost))

func _on_attack_boost_timeout(boost: float) -> void:
	if boost <= 0.0:
		return
	if not is_instance_valid(skill_owner):
		return
	if not skill_owner.has_meta("attack_boost"):
		return
	var current: float = float(skill_owner.get_meta("attack_boost"))
	var next: float = current - boost
	if absf(next) <= 0.001:
		skill_owner.remove_meta("attack_boost")
	else:
		skill_owner.set_meta("attack_boost", next)

func _pick_nearest_enemy(origin: Vector2) -> Node2D:
	var nearest_enemy: Node2D = null
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
			nearest_dist = dist
			nearest_enemy = enemy_node
	return nearest_enemy
