extends SkillEBase
class_name SkillLurewardenE

var explosion_radius: float = 220.0
var explosion_damage: int = 108
var explosion_knockback: float = 560.0

var mark_duration: float = 2.0
var mark_amp: float = 0.16
var armor_gain: int = 1

var charge_lane_count: int = 3
var charge_lane_length: float = 280.0
var charge_lane_width: float = 52.0
var charge_lane_damage: int = 42
var decoy_duration: float = 4.2
var decoy_taunt_radius: float = 460.0
var decoy_swap_distance: float = 220.0
var decoy_tick_interval: float = 0.25

const PEN_META_CENTER: String = "lurewarden_pen_center"
const PEN_META_RADIUS: String = "lurewarden_pen_radius"
const PEN_META_EXPIRE_MSEC: String = "lurewarden_pen_expire_msec"
const HERDER_E_PACK_META: String = "lurewarden_e_pack_until_msec"
const DECOY_GROUP: String = "lurewarden_decoys"
const DECOY_OWNER_META: String = "lurewarden_owner_id"
const DECOY_CREATED_META: String = "lurewarden_created_msec"

func execute() -> void:
	if not can_execute():
		if is_on_cooldown and is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "Cooldown!", Color.YELLOW)
		return
	if not consume_energy():
		if is_instance_valid(skill_owner):
			Global.spawn_floating_text(skill_owner.global_position, "No Energy!", Color.RED)
		return
	if not is_instance_valid(skill_owner):
		return

	var damage_amp: float = get_e_damage_amp(0.38, 0.42)
	var duration_amp: float = get_e_duration_amp(0.36)
	var aim_dir: Vector2 = _get_aim_direction()
	var center: Vector2 = skill_owner.global_position
	var final_damage: int = max(1, int(round(float(explosion_damage) * damage_amp)))
	var final_mark: float = mark_amp * damage_amp
	var final_knockback: float = explosion_knockback * duration_amp

	var decoy_node: Node2D = _find_active_decoy()
	var decoy_hits: int = 0
	var decoy_swap_used: bool = false
	var decoy_spawned: bool = false
	if decoy_node != null:
		var player_start: Vector2 = skill_owner.global_position
		var decoy_pos: Vector2 = decoy_node.global_position
		_swap_with_decoy(decoy_node)
		center = skill_owner.global_position
		decoy_swap_used = true
		decoy_hits = _detonate(
			decoy_pos,
			explosion_radius * 0.82,
			max(1, int(round(float(final_damage) * 0.72))),
			final_knockback * 0.78,
			final_mark * 0.85,
			mark_duration * 0.85 * duration_amp
		)
		_damage_along_lane(
			player_start,
			decoy_pos,
			charge_lane_width * 0.74,
			max(1, int(round(float(charge_lane_damage) * damage_amp * 0.82))),
			final_knockback * 0.35,
			final_mark * 0.78,
			mark_duration * 0.8
		)
		_consume_decoy(decoy_node)
	else:
		var decoy_pos: Vector2 = skill_owner.global_position + aim_dir * min(decoy_swap_distance, charge_lane_length * 0.88)
		_spawn_pack_decoy(decoy_pos, decoy_duration + (0.8 if is_f_window_active() else 0.0))
		decoy_spawned = true
		_damage_along_lane(
			skill_owner.global_position,
			decoy_pos,
			charge_lane_width * 0.58,
			max(1, int(round(float(charge_lane_damage) * damage_amp * 0.54))),
			final_knockback * 0.24,
			final_mark * 0.62,
			mark_duration * 0.75
		)

	var burst_hits: int = _detonate(center, explosion_radius, final_damage, final_knockback, final_mark, mark_duration * duration_amp)
	var lane_hits: int = _emit_pack_charge(center, damage_amp, duration_amp, is_f_window_active())
	var pen_hits: int = _apply_pen_synergy(damage_amp, duration_amp)
	_grant_armor()
	spawn_skill_vfx(center, Color(1.1, 0.95, 0.35, 0.9), 0.8)
	Global.on_camera_shake.emit(6.8 + float(burst_hits + lane_hits + pen_hits + decoy_hits) * 0.24, 0.12)
	if burst_hits > 0 or lane_hits > 0 or pen_hits > 0 or decoy_hits > 0:
		Global.spawn_floating_text(
			center,
			"HERD x%d / CHARGE x%d / PEN x%d / DECOY x%d" % [burst_hits, lane_hits, pen_hits, decoy_hits],
			Color(1.2, 1.0, 0.45)
		)
	if decoy_swap_used:
		Global.spawn_floating_text(center, "SWAP + BAIT BLAST", Color(1.0, 0.92, 0.38))
	elif decoy_spawned:
		Global.spawn_floating_text(center, "DECOY DEPLOY", Color(0.88, 1.0, 0.45))
	var pack_window: float = 2.0 + (0.6 if is_f_window_active() else 0.0)
	skill_owner.set_meta(HERDER_E_PACK_META, Time.get_ticks_msec() + int(round(pack_window * 1000.0)))
	publish_e_context(
		center,
		explosion_radius,
		"lurewarden_pack",
		{
			"burst_hits": burst_hits,
			"lane_hits": lane_hits,
			"pen_hits": pen_hits,
			"decoy_hits": decoy_hits,
			"decoy_swap_used": decoy_swap_used,
			"decoy_spawned": decoy_spawned,
		},
		"lurewarden_pack_window",
		pack_window
	)

	start_cooldown()

func _emit_pack_charge(center: Vector2, damage_amp: float, duration_amp: float, enhanced: bool) -> int:
	var total_hits: int = 0
	var lanes: int = charge_lane_count + (1 if enhanced else 0)
	var base_dir: Vector2 = _get_aim_direction()
	var half_span: float = 0.52
	for i: int in range(lanes):
		var ratio: float = 0.5 if lanes <= 1 else float(i) / float(lanes - 1)
		var angle_offset: float = lerp(-half_span, half_span, ratio)
		var dir: Vector2 = base_dir.rotated(angle_offset)
		var lane_length: float = charge_lane_length * (1.1 if enhanced else 1.0)
		var end_pos: Vector2 = center + dir * lane_length
		var lane_damage: int = max(
			1,
			int(round(float(charge_lane_damage) * damage_amp * (1.0 + abs(angle_offset) * 0.12)))
		)
		total_hits += _damage_along_lane(
			center,
			end_pos,
			charge_lane_width * (1.08 if enhanced else 1.0),
			lane_damage,
			explosion_knockback * 0.62 * duration_amp,
			mark_amp * 0.72 * damage_amp,
			mark_duration * 0.9
		)
	return total_hits

func _damage_along_lane(
	start: Vector2,
	finish: Vector2,
	width: float,
	damage: int,
	knockback: float,
	mark_value: float,
	mark_time: float
) -> int:
	var hits: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		var path_dist: float = _distance_point_to_segment(enemy.global_position, start, finish)
		if path_dist > width:
			continue
		_apply_damage(enemy, damage)
		_apply_knockback(enemy, (enemy.global_position - start).normalized(), knockback)
		_apply_status(enemy, "marked", mark_time, mark_value)
		_apply_status(enemy, "slow", max(0.5, mark_time * 0.55), 0.34)
		hits += 1
	return hits

func _detonate(center: Vector2, radius: float, damage: int, knockback: float, mark_value: float, mark_time: float) -> int:
	var hits: int = 0
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj: Variant in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(center) > radius:
			continue
		_apply_damage(enemy, damage)
		_apply_knockback(enemy, (enemy.global_position - center).normalized(), knockback)
		_apply_status(enemy, "marked", mark_time, mark_value)
		_apply_status(enemy, "slow", max(0.45, mark_time * 0.55), 0.32)
		hits += 1
	return hits

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

func _apply_knockback(enemy: Node2D, direction: Vector2, force: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_knockback"):
		enemy.call("apply_knockback", direction, force)

func _distance_point_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.0001:
		return point.distance_to(a)
	var t: float = clamp((point - a).dot(ab) / len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return point.distance_to(closest)

func _get_aim_direction() -> Vector2:
	if not is_instance_valid(skill_owner):
		return Vector2.RIGHT
	var dir: Vector2 = skill_owner.get_global_mouse_position() - skill_owner.global_position
	if dir.length_squared() <= 0.01:
		return Vector2.RIGHT
	return dir.normalized()

func _spawn_pack_decoy(pos: Vector2, duration: float) -> void:
	if not is_instance_valid(skill_owner) or not is_inside_tree():
		return
	if _has_owned_decoy_near(pos, 88.0):
		return
	_trim_owned_decoys(3)
	var decoy := Node2D.new()
	decoy.name = "LurewardenPackDecoy"
	decoy.global_position = pos
	decoy.z_index = 58
	decoy.add_to_group("player")
	decoy.add_to_group("player_skill_effects")
	decoy.add_to_group(DECOY_GROUP)
	decoy.set_meta(DECOY_OWNER_META, skill_owner.get_instance_id())
	decoy.set_meta(DECOY_CREATED_META, Time.get_ticks_msec())

	var marker := Polygon2D.new()
	marker.polygon = PackedVector2Array([
		Vector2(0, -18),
		Vector2(18, 0),
		Vector2(0, 18),
		Vector2(-18, 0),
	])
	marker.color = Color(0.92, 1.0, 0.34, 0.96)
	decoy.add_child(marker)

	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null:
		scene.add_child(decoy)
	else:
		add_child(decoy)

	var taunt_timer := Timer.new()
	taunt_timer.wait_time = max(0.12, decoy_tick_interval)
	taunt_timer.one_shot = false
	taunt_timer.autostart = true
	decoy.add_child(taunt_timer)
	taunt_timer.timeout.connect(_on_decoy_taunt_tick.bind(weakref(decoy)))

	var life_timer := Timer.new()
	life_timer.wait_time = max(0.5, duration)
	life_timer.one_shot = true
	life_timer.autostart = true
	decoy.add_child(life_timer)
	life_timer.timeout.connect(_on_decoy_expire.bind(weakref(decoy)))

	spawn_skill_vfx(pos, Color(0.94, 1.0, 0.34, 0.7), 0.32)

func _on_decoy_taunt_tick(decoy_ref: WeakRef) -> void:
	var decoy_obj: Variant = decoy_ref.get_ref() if decoy_ref != null else null
	if decoy_obj == null or not is_instance_valid(decoy_obj):
		return
	if not (decoy_obj is Node2D):
		return
	var decoy: Node2D = decoy_obj
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if enemy.global_position.distance_to(decoy.global_position) > decoy_taunt_radius:
			continue
		if enemy.has_method("set_taunt_target"):
			enemy.call("set_taunt_target", decoy)
		if enemy.has_method("apply_status"):
			enemy.call("apply_status", "marked", 1.0, mark_amp * 0.7, 1, 0.2)
			enemy.call("apply_status", "slow", 0.6, 0.22, 1, 0.1)

func _on_decoy_expire(decoy_ref: WeakRef) -> void:
	var decoy_obj: Variant = decoy_ref.get_ref() if decoy_ref != null else null
	if decoy_obj == null or not is_instance_valid(decoy_obj):
		return
	if not (decoy_obj is Node2D):
		return
	var decoy: Node2D = decoy_obj
	spawn_skill_vfx(decoy.global_position, Color(1.0, 0.92, 0.3, 0.46), 0.24)
	decoy.queue_free()

func _find_active_decoy() -> Node2D:
	var decoys: Array[Node2D] = _owned_decoys()
	if decoys.is_empty():
		return null
	var best: Node2D = null
	var best_dist: float = 999999.0
	for decoy: Node2D in decoys:
		var dist: float = skill_owner.global_position.distance_to(decoy.global_position)
		if dist > decoy_swap_distance * 2.2:
			continue
		if dist < best_dist:
			best_dist = dist
			best = decoy
	return best

func _swap_with_decoy(decoy: Node2D) -> void:
	if not is_instance_valid(skill_owner) or not is_instance_valid(decoy):
		return
	var player_pos: Vector2 = skill_owner.global_position
	skill_owner.global_position = decoy.global_position
	decoy.global_position = player_pos
	spawn_skill_vfx(skill_owner.global_position, Color(1.0, 1.0, 0.38, 0.82), 0.42)

func _consume_decoy(decoy: Node2D) -> void:
	if decoy != null and is_instance_valid(decoy):
		decoy.queue_free()

func _owned_decoys() -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not is_inside_tree() or not is_instance_valid(skill_owner):
		return result
	for node_var: Variant in get_tree().get_nodes_in_group(DECOY_GROUP):
		if node_var == null or not is_instance_valid(node_var):
			continue
		if not (node_var is Node2D):
			continue
		var node: Node2D = node_var
		if int(node.get_meta(DECOY_OWNER_META, 0)) != skill_owner.get_instance_id():
			continue
		result.append(node)
	return result

func _has_owned_decoy_near(pos: Vector2, min_distance: float) -> bool:
	for decoy: Node2D in _owned_decoys():
		if decoy.global_position.distance_to(pos) < min_distance:
			return true
	return false

func _trim_owned_decoys(max_count: int) -> void:
	var decoys: Array[Node2D] = _owned_decoys()
	if decoys.size() <= max_count:
		return
	decoys.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return int(a.get_meta(DECOY_CREATED_META, 0)) < int(b.get_meta(DECOY_CREATED_META, 0))
	)
	var remove_count: int = decoys.size() - max_count
	for i: int in range(remove_count):
		if is_instance_valid(decoys[i]):
			decoys[i].queue_free()

func _grant_armor() -> void:
	if not is_instance_valid(skill_owner):
		return
	if not ("armor" in skill_owner and "max_armor" in skill_owner):
		return
	var before: int = int(skill_owner.armor)
	var after: int = min(int(skill_owner.max_armor), before + armor_gain)
	if after <= before:
		return
	skill_owner.armor = after
	if skill_owner.has_signal("armor_changed"):
		skill_owner.armor_changed.emit(after)
	Global.spawn_floating_text(skill_owner.global_position, "+ARMOR", Color(0.6, 1.0, 1.0))

func _apply_pen_synergy(damage_amp: float, duration_amp: float) -> int:
	if not is_instance_valid(skill_owner):
		return 0
	var center := Vector2.ZERO
	var radius := 0.0
	var asset := get_recent_q_asset("lurewarden_pen", 7000)
	if not asset.is_empty():
		center = asset.get("center", Vector2.ZERO) if asset.get("center", Vector2.ZERO) is Vector2 else Vector2.ZERO
		radius = float(asset.get("radius", 0.0))
	else:
		if not skill_owner.has_meta(PEN_META_CENTER):
			return 0
		var expire_msec: int = 0
		if skill_owner.has_meta(PEN_META_EXPIRE_MSEC):
			expire_msec = int(skill_owner.get_meta(PEN_META_EXPIRE_MSEC))
		if Time.get_ticks_msec() > expire_msec:
			return 0
		center = Vector2(skill_owner.get_meta(PEN_META_CENTER))
		radius = float(skill_owner.get_meta(PEN_META_RADIUS, 0.0))
	if radius <= 8.0:
		return 0
	var pen_damage: int = max(1, int(round(float(explosion_damage) * 0.42 * damage_amp)))
	var mark_value: float = mark_amp * 0.8 * damage_amp
	var mark_time: float = max(0.8, mark_duration * 0.9 * duration_amp)
	var hit_count: int = _detonate(center, radius * 0.74, pen_damage, explosion_knockback * 0.42 * duration_amp, mark_value, mark_time)
	if hit_count > 0:
		var sweep_dir: Vector2 = _get_aim_direction()
		var sweep_end: Vector2 = center + sweep_dir * radius
		_damage_along_lane(center, sweep_end, charge_lane_width * 0.8, pen_damage, explosion_knockback * 0.35, mark_value, mark_time)
		spawn_skill_vfx(center, Color(1.2, 0.92, 0.32, 0.78), 0.52)
	return hit_count

func cleanup() -> void:
	for decoy: Node2D in _owned_decoys():
		if is_instance_valid(decoy):
			decoy.queue_free()
