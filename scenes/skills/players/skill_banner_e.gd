extends SkillBase
class_name SkillBannerE

var speed_boost_value: float = 0.5
var speed_boost_duration: float = 4.0
var warhorn_damage: int = 28
var warhorn_radius: float = 210.0
var warhorn_angle_deg: float = 96.0
var warhorn_fear_duration: float = 0.6

const RALLY_META_CENTER: String = "banner_rally_center"
const RALLY_META_RADIUS: String = "banner_rally_radius"
const RALLY_META_EXPIRE_MSEC: String = "banner_rally_expire_msec"

func execute() -> void:
	if not can_execute():
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var duration_amp: float = get_e_duration_amp(0.35)
	var damage_amp: float = get_e_damage_amp(0.2, 0.25)
	var final_speed_boost: float = speed_boost_value * (1.0 + (damage_amp - 1.0) * 0.6)
	var final_duration: float = speed_boost_duration * duration_amp
	var extra_attack_boost: float = 0.0
	if is_f_window_active():
		extra_attack_boost = 0.12 + (damage_amp - 1.0) * 0.35

	_apply_team_rally_buff(final_speed_boost, final_duration, extra_attack_boost)

	var horn_hits: int = _cast_warhorn_cone(
		max(1, int(round(float(warhorn_damage) * damage_amp))),
		warhorn_radius * (1.0 + (duration_amp - 1.0) * 0.35),
		warhorn_angle_deg * (1.0 + (0.08 if is_f_window_active() else 0.0)),
		warhorn_fear_duration * duration_amp
	)

	var rally_hits: int = _trigger_rally_sync(damage_amp, duration_amp)
	var text: String = "CHARGE %d" % horn_hits
	if rally_hits > 0:
		text += " / RALLY %d" % rally_hits
	Global.spawn_floating_text(skill_owner.global_position, text, Color(1.0, 0.35, 0.25))
	Global.on_camera_shake.emit(5.6 + float(rally_hits) * 0.2, 0.15)
	start_cooldown()

func _apply_team_rally_buff(final_speed_boost: float, final_duration: float, extra_attack_boost: float) -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	for player_obj: Variant in players:
		if player_obj == null or not is_instance_valid(player_obj):
			continue
		var player: Node = player_obj
		var had_speed_meta: bool = player.has_meta("buff_speed_boost")
		var old_speed_meta: float = float(player.get_meta("buff_speed_boost")) if had_speed_meta else 0.0
		player.set_meta("buff_speed_boost", final_speed_boost)

		var had_attack_meta: bool = player.has_meta("attack_boost")
		var old_attack_meta: float = float(player.get_meta("attack_boost")) if had_attack_meta else 0.0
		if extra_attack_boost > 0.0:
			player.set_meta("attack_boost", old_attack_meta + extra_attack_boost)

		var player_ref: WeakRef = weakref(player)
		var timer: SceneTreeTimer = get_tree().create_timer(final_duration)
		timer.timeout.connect(
			_on_banner_buff_timeout.bind(
				player_ref,
				had_speed_meta,
				old_speed_meta,
				extra_attack_boost,
				had_attack_meta,
				old_attack_meta
			)
		)

func _on_banner_buff_timeout(
	player_ref: WeakRef,
	had_speed_meta: bool,
	old_speed_meta: float,
	extra_attack_boost: float,
	had_attack_meta: bool,
	old_attack_meta: float
) -> void:
	var player_obj: Variant = player_ref.get_ref() if player_ref != null else null
	if player_obj == null or not is_instance_valid(player_obj):
		return
	var player: Node = player_obj
	if had_speed_meta:
		player.set_meta("buff_speed_boost", old_speed_meta)
	elif player.has_meta("buff_speed_boost"):
		player.remove_meta("buff_speed_boost")
	if extra_attack_boost > 0.0:
		if had_attack_meta:
			player.set_meta("attack_boost", old_attack_meta)
		elif player.has_meta("attack_boost"):
			player.remove_meta("attack_boost")

func _cast_warhorn_cone(damage: int, radius: float, angle_deg: float, fear_duration: float) -> int:
	if not is_instance_valid(skill_owner):
		return 0
	var origin: Vector2 = skill_owner.global_position
	var aim: Vector2 = skill_owner.get_global_mouse_position()
	var forward: Vector2 = (aim - origin).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT.rotated(skill_owner.rotation)
	var cos_limit: float = cos(deg_to_rad(angle_deg * 0.5))
	var hit_count: int = 0
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var vec: Vector2 = enemy.global_position - origin
		var dist: float = vec.length()
		if dist > radius or dist <= 0.1:
			continue
		var dir: Vector2 = vec / dist
		if forward.dot(dir) < cos_limit:
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "fear", fear_duration, 1.0, 1, 0.1)
		_apply_status(enemy, "slow", 0.8, 0.24, 1, 0.1)
		if enemy.has_method("apply_knockback"):
			enemy.call("apply_knockback", dir, 260.0)
		hit_count += 1
	return hit_count

func _trigger_rally_sync(damage_amp: float, duration_amp: float) -> int:
	if not is_instance_valid(skill_owner):
		return 0
	if not skill_owner.has_meta(RALLY_META_EXPIRE_MSEC):
		return 0
	var expire_msec: int = int(skill_owner.get_meta(RALLY_META_EXPIRE_MSEC, 0))
	if Time.get_ticks_msec() > expire_msec:
		return 0
	var center_val: Variant = skill_owner.get_meta(RALLY_META_CENTER, Vector2.ZERO)
	var radius_val: Variant = skill_owner.get_meta(RALLY_META_RADIUS, 0.0)
	if not (center_val is Vector2):
		return 0
	var center: Vector2 = center_val
	var radius: float = max(24.0, float(radius_val))
	var damage: int = max(1, int(round(32.0 * damage_amp)))
	var hit_count: int = 0
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "marked", 1.2 * duration_amp, 0.16, 1, 0.3)
		hit_count += 1
	if hit_count > 0:
		spawn_skill_vfx(center, Color(1.0, 0.5, 0.35, 0.8), 0.6)
	return hit_count

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if enemy.has_node("HealthComponent"):
		var hc: Node = enemy.get_node("HealthComponent")
		if hc != null and hc.has_method("take_damage"):
			hc.call("take_damage", max(1, amount))

func _apply_status(enemy: Node2D, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_name, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))
