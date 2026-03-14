extends SkillBase
class_name SkillSwarmE

const BROOD_META_CENTER: String = "swarm_brood_center"
const BROOD_META_RADIUS: String = "swarm_brood_radius"
const BROOD_META_EXPIRE_MSEC: String = "swarm_brood_expire_msec"

func execute() -> void:
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var origin: Vector2 = skill_owner.global_position
	var window_data: Array = _get_brood_window(origin, 160.0)
	var synergy_used: bool = bool(window_data[0])
	var brood_center: Vector2 = origin
	var brood_radius: float = 160.0
	if synergy_used and window_data.size() > 1 and window_data[1] is Vector2:
		brood_center = window_data[1]
	if synergy_used and window_data.size() > 2:
		brood_radius = max(brood_radius, float(window_data[2]))

	var nearest_enemy: Node2D = _pick_nearest_enemy(brood_center if synergy_used else origin)
	if SkillEffectManager != null and SkillEffectManager.has_method("command_summons"):
		SkillEffectManager.command_summons("skill_swarm_q", "focus_fire", nearest_enemy)

	var damage_amp: float = get_e_damage_amp(0.2, 0.28)
	var duration_amp: float = get_e_duration_amp(0.3)
	if nearest_enemy != null and is_instance_valid(nearest_enemy):
		var dive_center: Vector2 = nearest_enemy.global_position
		if synergy_used:
			dive_center = (dive_center + brood_center) * 0.5
		get_tree().create_timer(0.2).timeout.connect(
			_on_brood_dive_timeout.bind(dive_center, damage_amp, duration_amp, is_f_window_active(), synergy_used)
		)
	elif synergy_used:
		get_tree().create_timer(0.18).timeout.connect(
			_on_brood_dive_timeout.bind(brood_center, damage_amp, duration_amp, is_f_window_active(), true)
		)

	if is_f_window_active():
		var swarm_boost: float = 0.2 + (duration_amp - 1.0) * 0.4
		_apply_temp_attack_boost(swarm_boost, 2.2 * duration_amp)
		Global.spawn_floating_text(origin, "BROOD FRENZY!", Color(0.7, 0.9, 0.35))

	if synergy_used:
		_apply_temp_attack_boost(0.12, 2.4 * duration_amp)
		_refund_q_cooldown(1.0)
		Global.spawn_floating_text(origin, "BROOD LINK", Color(0.62, 0.86, 0.3))
	else:
		Global.spawn_floating_text(origin, "FOCUS FIRE!", Color(0.5, 0.4, 0.1))
	start_cooldown()

func _on_brood_dive_timeout(center: Vector2, damage_amp: float, duration_amp: float, empowered: bool, synergy_used: bool) -> void:
	var radius: float = 120.0 * (1.25 if empowered else 1.0)
	if synergy_used:
		radius *= 1.22
	var damage: int = max(1, int(round(24.0 * damage_amp * (1.35 if empowered else 1.0))))
	if synergy_used:
		damage = int(round(float(damage) * 1.16))
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	var hits: int = 0
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy_node: Node2D = enemy_obj
		if enemy_node.global_position.distance_to(center) > radius:
			continue
		if enemy_node.has_node("HealthComponent"):
			var hc: Node = enemy_node.get_node("HealthComponent")
			if hc != null and hc.has_method("take_damage"):
				hc.call("take_damage", damage)
		if enemy_node.has_method("apply_status"):
			enemy_node.apply_status("poison", 1.6 * duration_amp, max(1.0, float(damage) * 0.4), 1, 0.7)
			if synergy_used:
				enemy_node.apply_status("slow", 0.9 * duration_amp, 0.24, 1, 0.1)
		hits += 1
	if hits > 0:
		spawn_skill_vfx(center, Color(0.65, 0.78, 0.28, 0.75), 0.6)
		if synergy_used:
			Global.spawn_floating_text(center, "BROOD DIVE+ x%d" % hits, Color(0.75, 0.9, 0.35))
		else:
			Global.spawn_floating_text(center, "BROOD DIVE x%d" % hits, Color(0.75, 0.9, 0.35))

func _get_brood_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(BROOD_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(BROOD_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(BROOD_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(BROOD_META_RADIUS, default_radius)
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
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy_node: Node2D = enemy_obj
		var dist: float = origin.distance_to(enemy_node.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_enemy = enemy_node
	return nearest_enemy
