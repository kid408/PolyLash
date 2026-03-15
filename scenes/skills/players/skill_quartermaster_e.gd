extends SkillEBase
class_name SkillQuartermasterE

var barrage_damage: int = 34
var barrage_radius: float = 180.0
var barrage_mark_amp: float = 0.2
var overclock_cd_buff: float = 0.18
var overclock_duration: float = 2.6
var reload_line_width: float = 54.0
var reload_line_length: float = 280.0
var reload_return_delay: float = 0.18
var reload_line_damage_ratio: float = 0.74
var reload_pull_force: float = 34.0

const SUPPLY_META_CENTER: String = "quartermaster_supply_center"
const SUPPLY_META_RADIUS: String = "quartermaster_supply_radius"
const SUPPLY_META_EXPIRE_MSEC: String = "quartermaster_supply_expire_msec"

func execute() -> void:
	if not can_execute():
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.28, 0.30)
	var duration_amp: float = get_e_duration_amp(0.35)

	_refill_energy()
	var overclock_bonus: float = overclock_cd_buff * (1.0 + (duration_amp - 1.0) * 0.45)
	_apply_overclock(overclock_bonus, overclock_duration * duration_amp)

	var supply_asset := _get_recent_supply_asset()
	var supply_points: Array[Vector2] = get_q_asset_points(supply_asset)
	var context_center: Vector2 = skill_owner.global_position
	var context_radius: float = barrage_radius
	var supply_kind: String = str(supply_asset.get("kind", "")).strip_edges()
	var synergy_used: bool = false
	var mode: String = "self_reload"

	if supply_kind == "quartermaster_supply_hub":
		synergy_used = _trigger_supply_hub_reload(supply_asset, damage_amp, duration_amp)
		mode = "supply_hub_reload"
		var center_var: Variant = supply_asset.get("center", skill_owner.global_position)
		if center_var is Vector2:
			context_center = center_var
		context_radius = max(barrage_radius, float(supply_asset.get("radius", barrage_radius)))
	elif supply_points.size() >= 2:
		synergy_used = _trigger_supply_line_reload(supply_points, damage_amp, duration_amp)
		mode = "supply_line_reload"
		context_center = supply_points[supply_points.size() - 1]
		context_radius = max(barrage_radius, _points_radius(supply_points, _points_center(supply_points)))
	else:
		synergy_used = _trigger_personal_reload(damage_amp, duration_amp)

	if synergy_used:
		Global.on_camera_shake.emit(7.0, 0.14)
	publish_e_context(
		context_center,
		context_radius,
		"quartermaster_resupply",
		{
			"synergy_used": synergy_used,
			"overclock_bonus": overclock_bonus,
			"mode": mode,
			"supply_kind": supply_kind,
		},
		"quartermaster_resupply",
		overclock_duration * duration_amp
	)

	start_cooldown()

func _refill_energy() -> void:
	if not is_instance_valid(skill_owner):
		return
	if "energy" in skill_owner and "max_energy" in skill_owner:
		skill_owner.energy = skill_owner.max_energy

func _apply_overclock(cd_buff: float, duration: float) -> void:
	if not is_instance_valid(skill_owner):
		return
	var had_cd_buff: bool = skill_owner.has_meta("buff_cooldown_reduction")
	var old_cd_buff: float = float(skill_owner.get_meta("buff_cooldown_reduction")) if had_cd_buff else 0.0
	var next_cd_buff: float = clamp(old_cd_buff + cd_buff, 0.0, 0.85)
	skill_owner.set_meta("buff_cooldown_reduction", next_cd_buff)
	var owner_ref: WeakRef = weakref(skill_owner)
	get_tree().create_timer(max(0.1, duration)).timeout.connect(
		_on_overclock_timeout.bind(owner_ref, had_cd_buff, old_cd_buff)
	)

func _on_overclock_timeout(owner_ref: WeakRef, had_cd_buff: bool, old_cd_buff: float) -> void:
	var owner: Variant = owner_ref.get_ref() if owner_ref != null else null
	if owner == null or not is_instance_valid(owner):
		return
	if had_cd_buff:
		owner.set_meta("buff_cooldown_reduction", old_cd_buff)
	elif owner.has_meta("buff_cooldown_reduction"):
		owner.remove_meta("buff_cooldown_reduction")

func _get_recent_supply_asset() -> Dictionary:
	var hub_asset := get_recent_q_asset("quartermaster_supply_hub", 8000)
	if not hub_asset.is_empty():
		return hub_asset
	var link_asset := get_recent_q_asset("quartermaster_supply_link", 8000)
	if not link_asset.is_empty():
		return link_asset
	return get_recent_q_asset("", 8000)

func _trigger_personal_reload(damage_amp: float, duration_amp: float) -> bool:
	var aim_dir: Vector2 = get_aim_direction()
	var fan_count: int = 3 + (1 if is_f_window_active() else 0)
	var half_span: float = 0.32
	var hit_count: int = 0
	for i in range(fan_count):
		var ratio: float = 0.5 if fan_count <= 1 else float(i) / float(fan_count - 1)
		var angle: float = lerp(-half_span, half_span, ratio)
		var dir: Vector2 = aim_dir.rotated(angle)
		var end_pos: Vector2 = skill_owner.global_position + dir * reload_line_length
		spawn_transient_polyline(
			[skill_owner.global_position, end_pos],
			Color(0.62, 0.96, 1.08, 0.95),
			10.0,
			0.26
		)
		hit_count += _apply_line_reload_pass(
			skill_owner.global_position,
			end_pos,
			reload_line_width * 0.58,
			max(1, int(round(float(barrage_damage) * reload_line_damage_ratio * damage_amp))),
			0.85 * duration_amp,
			14.0
		)
	if hit_count > 0:
		Global.spawn_floating_text(skill_owner.global_position, "TACTICAL RELOAD x%d" % hit_count, Color(0.55, 0.9, 1.0))
	else:
		Global.spawn_floating_text(skill_owner.global_position, "TACTICAL RELOAD", Color(0.55, 0.9, 1.0))
	spawn_skill_vfx(skill_owner.global_position, Color(0.45, 0.82, 1.0, 0.82), 0.62)
	return true

func _trigger_supply_line_reload(points: Array[Vector2], damage_amp: float, duration_amp: float) -> bool:
	if points.size() < 2:
		return false
	spawn_transient_polyline(points, Color(0.68, 1.05, 1.15, 0.96), 15.0, 0.42)
	var hit_count: int = 0
	for i in range(points.size() - 1):
		hit_count += _apply_line_reload_pass(
			points[i],
			points[i + 1],
			reload_line_width,
			max(1, int(round(float(barrage_damage) * 0.68 * damage_amp))),
			duration_amp,
			18.0
		)
	var center: Vector2 = _points_center(points)
	var radius: float = _points_radius(points, center)
	spawn_transient_ring(center, radius * 0.68, Color(0.54, 0.92, 1.05, 0.72), 7.0, 0.34)
	get_tree().create_timer(reload_return_delay * (0.8 if is_f_window_active() else 1.0)).timeout.connect(
		_on_supply_line_return_timeout.bind(points.duplicate(), damage_amp, duration_amp)
	)
	Global.spawn_floating_text(points[points.size() - 1], "LOAD THE LINE", Color(0.52, 0.92, 1.0))
	_refund_q_cooldown(1.0)
	return hit_count > 0

func _on_supply_line_return_timeout(points: Array[Vector2], damage_amp: float, duration_amp: float) -> void:
	if points.size() < 2:
		return
	var reversed_points: Array[Vector2] = points.duplicate()
	reversed_points.reverse()
	spawn_transient_polyline(reversed_points, Color(0.9, 1.12, 1.22, 0.96), 12.0, 0.34)
	for i in range(reversed_points.size() - 1):
		_apply_line_reload_pass(
			reversed_points[i],
			reversed_points[i + 1],
			reload_line_width * 0.82,
			max(1, int(round(float(barrage_damage) * 0.52 * damage_amp))),
			duration_amp,
			-20.0
		)

func _trigger_supply_hub_reload(asset: Dictionary, damage_amp: float, duration_amp: float) -> bool:
	var center_var: Variant = asset.get("center", Vector2.ZERO)
	if not (center_var is Vector2):
		return false
	var center: Vector2 = center_var
	var radius: float = max(56.0, float(asset.get("radius", barrage_radius)))
	spawn_transient_ring(center, radius, Color(0.58, 0.96, 1.08, 0.95), 9.0, 0.42)
	var hit_count: int = 0
	var final_damage: int = max(1, int(round(float(barrage_damage) * damage_amp)))
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		_apply_damage(enemy, final_damage)
		_apply_status(enemy, "marked", 1.3 * duration_amp, barrage_mark_amp, 1, 0.3)
		_apply_status(enemy, "slow", 1.0 * duration_amp, 0.28, 1, 0.1)
		_apply_pull_towards(enemy, center, reload_pull_force)
		hit_count += 1
	if hit_count > 0:
		Global.spawn_floating_text(center, "SUPPLY HUB LOAD x%d" % hit_count, Color(0.48, 0.9, 1.0))
		spawn_skill_vfx(center, Color(0.4, 0.88, 1.0, 0.86), 0.72)
	get_tree().create_timer(0.16 if not is_f_window_active() else 0.12).timeout.connect(
		_on_supply_hub_overload_timeout.bind(center, radius, damage_amp, duration_amp)
	)
	_refund_q_cooldown(1.4)
	return hit_count > 0

func _on_supply_hub_overload_timeout(center: Vector2, radius: float, damage_amp: float, duration_amp: float) -> void:
	var spoke_count: int = 4 + (2 if is_f_window_active() else 0)
	for i in range(spoke_count):
		var angle: float = TAU * float(i) / float(max(1, spoke_count))
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var start: Vector2 = center + dir * radius * 1.1
		var finish: Vector2 = center - dir * radius * 0.1
		spawn_transient_polyline([start, finish], Color(0.86, 1.12, 1.24, 0.95), 10.0, 0.26)
		_apply_line_reload_pass(
			start,
			finish,
			reload_line_width * 0.62,
			max(1, int(round(float(barrage_damage) * 0.56 * damage_amp))),
			duration_amp,
			-24.0
		)
	Global.spawn_floating_text(center, "MANUAL OVERLOAD", Color(0.65, 1.0, 1.12))

func _apply_line_reload_pass(
	start: Vector2,
	finish: Vector2,
	width: float,
	damage: int,
	duration_amp: float,
	push_amount: float
) -> int:
	var hit_count: int = 0
	var dir: Vector2 = (finish - start).normalized()
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var dist_to_path: float = distance_point_to_segment(enemy.global_position, start, finish)
		if dist_to_path > width:
			continue
		_apply_damage(enemy, damage)
		_apply_status(enemy, "marked", 1.2 * duration_amp, barrage_mark_amp, 1, 0.25)
		_apply_status(enemy, "slow", 0.85 * duration_amp, 0.24, 1, 0.1)
		if push_amount >= 0.0:
			enemy.global_position += dir * push_amount
		else:
			enemy.global_position -= dir * absf(push_amount)
		hit_count += 1
	return hit_count

func _apply_pull_towards(enemy: Node2D, center: Vector2, amount: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var offset: Vector2 = center - enemy.global_position
	var dist: float = offset.length()
	if dist <= 0.001:
		return
	enemy.global_position += offset / dist * amount

func _points_center(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return skill_owner.global_position if is_instance_valid(skill_owner) else Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for point: Vector2 in points:
		center += point
	return center / float(points.size())

func _points_radius(points: Array[Vector2], center: Vector2) -> float:
	var radius: float = 0.0
	for point: Vector2 in points:
		radius = max(radius, center.distance_to(point))
	return max(48.0, radius)

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

func _apply_damage(enemy: Node2D, amount: int) -> void:
	if not enemy.has_node("HealthComponent"):
		return
	var hc: Node = enemy.get_node("HealthComponent")
	if hc != null and hc.has_method("take_damage"):
		hc.call("take_damage", max(1, amount))

func _apply_status(enemy: Node2D, status_name: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status_name, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))
