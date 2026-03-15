extends SkillEBase
class_name SkillHexwardenE

var self_damage: int = 20
var curse_damage: int = 60

const HEX_META_CENTER: String = "hexwarden_hex_center"
const HEX_META_RADIUS: String = "hexwarden_hex_radius"
const HEX_META_EXPIRE_MSEC: String = "hexwarden_hex_expire_msec"

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

	var origin: Vector2 = skill_owner.global_position
	var cast_radius: float = 520.0
	var hex_data: Array = _get_hex_window(origin, cast_radius * 0.45)
	var synergy_used: bool = bool(hex_data[0])
	if synergy_used and hex_data.size() > 1 and hex_data[1] is Vector2:
		origin = hex_data[1]
	if synergy_used and hex_data.size() > 2:
		cast_radius = max(cast_radius, float(hex_data[2]) * 2.0)
		real_curse_damage = int(round(float(real_curse_damage) * 1.12))

	_damage_owner(real_self_damage)

	var cursed_refs: Array = []
	var direct_hits: int = 0
	for enemy: Node2D in _get_enemies_in_radius(origin, cast_radius):
		if not _has_status(enemy, "curse"):
			continue
		_apply_damage(enemy, real_curse_damage)
		_apply_status(enemy, "slow", 1.1 * duration_amp, 0.28, 1, 0.1)
		cursed_refs.append(weakref(enemy))
		direct_hits += 1

	if cursed_refs.is_empty():
		var seed_radius: float = 190.0 * duration_amp
		if synergy_used and hex_data.size() > 2:
			seed_radius = max(seed_radius, float(hex_data[2]))
		for seed_enemy: Node2D in _get_enemies_in_radius(origin, seed_radius):
			_apply_status(seed_enemy, "curse", 2.2 * duration_amp, 8.0, 1, 0.7)
			if synergy_used:
				_apply_status(seed_enemy, "marked", 1.2, 0.18, 1, 0.3)
		Global.spawn_floating_text(skill_owner.global_position, "HEX SEED", Color(0.75, 0.36, 0.62))
		start_cooldown()
		return

	var link_delay: float = 0.24 if not is_f_window_active() else 0.16
	if synergy_used:
		link_delay = max(0.1, link_delay - 0.06)
	var timer: SceneTreeTimer = get_tree().create_timer(link_delay)
	timer.timeout.connect(_on_link_timeout.bind(cursed_refs, int(round(float(real_curse_damage) * 0.55)), duration_amp, synergy_used))

	if synergy_used:
		_refund_q_cooldown(1.0)
		Global.spawn_floating_text(skill_owner.global_position, "VOODOO+ x%d" % direct_hits, Color(0.74, 0.28, 0.62))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "VOODOO x%d" % direct_hits, Color(0.74, 0.28, 0.62))
	Global.on_camera_shake.emit(8.2, 0.16)
	start_cooldown()

func _on_link_timeout(target_refs: Array, damage: int, duration_amp: float, synergy_used: bool) -> void:
	var valid_targets: Array = []
	for ref_obj: Variant in target_refs:
		var target: Variant = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		if target is Node2D:
			valid_targets.append(target)
	if valid_targets.is_empty():
		return

	var hit: int = 0
	for i: int in range(valid_targets.size()):
		var from_target: Node2D = valid_targets[i]
		var to_target: Node2D = valid_targets[(i + 1) % valid_targets.size()]
		if from_target == to_target:
			continue
		var center: Vector2 = (from_target.global_position + to_target.global_position) * 0.5
		var chain_radius: float = 66.0 if not synergy_used else 82.0
		for enemy: Node2D in _get_enemies_in_radius(center, chain_radius):
			_apply_damage(enemy, damage)
			_apply_status(enemy, "marked", 1.2, 0.18, 1, 0.3)
			if synergy_used:
				_apply_status(enemy, "curse", 1.6 * duration_amp, 8.0, 1, 0.7)
			hit += 1
		spawn_skill_vfx(center, Color(0.78, 0.35, 0.68, 0.76), 0.55)
	if hit > 0 and is_instance_valid(skill_owner):
		Global.spawn_floating_text(skill_owner.global_position, "LINK x%d" % hit, Color(0.78, 0.35, 0.68))
		_heal_owner(int(round(float(hit) * 2.0 * duration_amp)))

func _get_hex_window(default_center: Vector2, default_radius: float) -> Array:
	var data: Array = [false, default_center, default_radius]
	if not is_instance_valid(skill_owner):
		return data
	if not skill_owner.has_meta(HEX_META_EXPIRE_MSEC):
		return data
	var expire_msec: int = int(skill_owner.get_meta(HEX_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return data
	var center_val: Variant = skill_owner.get_meta(HEX_META_CENTER, default_center)
	var radius_val: Variant = skill_owner.get_meta(HEX_META_RADIUS, default_radius)
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

