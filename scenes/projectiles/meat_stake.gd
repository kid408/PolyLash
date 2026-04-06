extends Node2D
class_name MeatStake

const DEFAULT_THROW_SPEED: float = 1200.0
const DEFAULT_MAX_DISTANCE: float = 800.0
const DEFAULT_SOFT_ATTRACT_RADIUS: float = 60.0
const DEFAULT_DIRECT_HIT_RADIUS: float = 24.0
const DEFAULT_DIRECT_HIT_DAMAGE_RATIO: float = 0.85
const DEFAULT_SHORT_PIN_DURATION: float = 0.35
const DEFAULT_STAKE_LIFE_DURATION: float = 7.0
const DEFAULT_TETHER_RADIUS: float = 250.0
const DEFAULT_LANDING_CAPTURE_RADIUS: float = 80.0
const DEFAULT_Q_RECALL_RADIUS: float = 420.0

var target_pos: Vector2 = Vector2.ZERO
var player_ref: Node2D = null
var skill_ref: WeakRef = null

var is_landed: bool = false
var landing_reason: String = ""
var flight_direction: Vector2 = Vector2.RIGHT
var speed: float = DEFAULT_THROW_SPEED
var max_distance: float = DEFAULT_MAX_DISTANCE
var travel_distance: float = 0.0

var soft_attract_radius: float = DEFAULT_SOFT_ATTRACT_RADIUS
var direct_hit_radius: float = DEFAULT_DIRECT_HIT_RADIUS
var direct_hit_damage_ratio: float = DEFAULT_DIRECT_HIT_DAMAGE_RATIO
var short_pin_duration: float = DEFAULT_SHORT_PIN_DURATION
var stake_life_duration: float = DEFAULT_STAKE_LIFE_DURATION
var tether_radius: float = DEFAULT_TETHER_RADIUS
var landing_capture_radius: float = DEFAULT_LANDING_CAPTURE_RADIUS
var q_recall_radius: float = DEFAULT_Q_RECALL_RADIUS

var main_target_ref: WeakRef = null
var linked_targets: Dictionary = {}
var q_handoff_completed: bool = false
var q_recall_attempted: bool = false

var lifetime_timer: Timer = null
var visual_body: Polygon2D = null
var body_color: Color = Color(0.25, 0.10, 0.10, 1.0)

func setup(_target_pos: Vector2, _player: Node2D, _direction: Vector2 = Vector2.RIGHT, _skill_node: Object = null) -> void:
	target_pos = _target_pos
	player_ref = _player
	if _skill_node != null:
		skill_ref = weakref(_skill_node)

	flight_direction = _direction
	if flight_direction.length_squared() <= 0.0001:
		flight_direction = Vector2.RIGHT
	else:
		flight_direction = flight_direction.normalized()

	speed = _get_player_float("stake_throw_speed", DEFAULT_THROW_SPEED)
	max_distance = _get_player_float("max_throw_distance", DEFAULT_MAX_DISTANCE)
	soft_attract_radius = DEFAULT_SOFT_ATTRACT_RADIUS
	direct_hit_radius = DEFAULT_DIRECT_HIT_RADIUS
	direct_hit_damage_ratio = DEFAULT_DIRECT_HIT_DAMAGE_RATIO
	short_pin_duration = DEFAULT_SHORT_PIN_DURATION
	stake_life_duration = _get_player_float("stake_duration", DEFAULT_STAKE_LIFE_DURATION)
	tether_radius = _get_player_float("chain_radius", DEFAULT_TETHER_RADIUS)
	landing_capture_radius = DEFAULT_LANDING_CAPTURE_RADIUS
	q_recall_radius = DEFAULT_Q_RECALL_RADIUS
	body_color = _get_player_color("chain_color", body_color)

	add_to_group("projectiles")
	add_to_group("player_skill_effects")

	_build_visual()
	_ensure_lifetime_timer()
	set_process(true)

func _process(delta: float) -> void:
	if not is_landed:
		_process_flying(delta)
	else:
		_process_landed(delta)
	queue_redraw()

func get_runtime_snapshot() -> Dictionary:
	var main_target: Node2D = get_main_target()
	return {
		"active": is_butcher_runtime_active(),
		"center": get_center(),
		"is_landed": is_landed,
		"landing_reason": landing_reason,
		"travel_distance": travel_distance,
		"target_pos": target_pos,
		"speed": speed,
		"max_distance": max_distance,
		"life_duration": stake_life_duration,
		"life_remaining": _get_life_remaining(),
		"tether_radius": tether_radius,
		"landing_capture_radius": landing_capture_radius,
		"soft_attract_radius": soft_attract_radius,
		"direct_hit_radius": direct_hit_radius,
		"direct_hit_damage_ratio": direct_hit_damage_ratio,
		"short_pin_duration": short_pin_duration,
		"linked_target_count": linked_targets.size(),
		"linked_target_ids": _get_linked_target_ids(),
		"linked_target_names": _get_linked_target_names(),
		"main_target_id": _get_target_id(main_target) if is_instance_valid(main_target) else 0,
		"main_target_name": main_target.name if is_instance_valid(main_target) else "",
		"q_handoff_completed": q_handoff_completed,
		"q_recall_attempted": q_recall_attempted,
	}

func get_center() -> Vector2:
	return global_position

func get_linked_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for entry_key in linked_targets.keys():
		var entry: Variant = linked_targets.get(entry_key, {})
		if not (entry is Dictionary):
			continue
		var ref: Variant = (entry as Dictionary).get("ref", null)
		var target_obj: Variant = ref.get_ref() if ref is WeakRef else null
		if target_obj == null or not is_instance_valid(target_obj):
			continue
		if not (target_obj is Node2D):
			continue
		targets.append(target_obj)
	return targets

func is_butcher_runtime_active() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(player_ref)

func transfer_q_chain_to_stake(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	var target_id: int = _get_target_id(target)
	if not linked_targets.has(target_id):
		linked_targets[target_id] = {
			"ref": weakref(target),
			"captured_msec": Time.get_ticks_msec(),
			"source": "q"
		}
	else:
		var existing: Variant = linked_targets.get(target_id, {})
		if existing is Dictionary:
			var existing_dict: Dictionary = existing
			existing_dict["ref"] = weakref(target)
			linked_targets[target_id] = existing_dict

	q_handoff_completed = true
	_remove_target_from_q_runtime(target)
	return true

func request_q_recall_once() -> void:
	_attempt_q_recall_once()

func _process_flying(delta: float) -> void:
	var dist_to_target: float = global_position.distance_to(target_pos)
	if dist_to_target <= 0.5 or travel_distance >= max_distance:
		_land("terminal")
		return

	var move_step: float = min(speed * delta, min(dist_to_target, max_distance - travel_distance))
	if move_step <= 0.0:
		_land("terminal")
		return

	global_position += flight_direction * move_step
	travel_distance += move_step
	rotation += 8.0 * delta

	_apply_soft_attract(delta)

	var hit_target: Node2D = _find_direct_hit_target()
	if hit_target != null:
		main_target_ref = weakref(hit_target)
		_apply_direct_hit(hit_target)
		_land("direct_hit")
		return

	if travel_distance >= max_distance or global_position.distance_to(target_pos) <= 0.5:
		_land("terminal")

func _process_landed(delta: float) -> void:
	_enforce_tether_bounds(delta)
	if is_instance_valid(visual_body):
		visual_body.rotation = 0.0

func _build_visual() -> void:
	if is_instance_valid(visual_body):
		visual_body.queue_free()
	visual_body = Polygon2D.new()
	visual_body.name = "MeatStakeVisual"
	visual_body.polygon = PackedVector2Array([
		Vector2(0, -18),
		Vector2(12, 0),
		Vector2(0, 28),
		Vector2(-12, 0),
	])
	visual_body.color = body_color
	add_child(visual_body)

func _ensure_lifetime_timer() -> void:
	if is_instance_valid(lifetime_timer):
		return
	lifetime_timer = Timer.new()
	lifetime_timer.one_shot = true
	lifetime_timer.wait_time = stake_life_duration
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	add_child(lifetime_timer)

func _apply_soft_attract(delta: float) -> void:
	var enemies: Array = _get_valid_enemies()
	if enemies.is_empty():
		return
	var attract_factor: float = min(1.0, 8.0 * delta)
	for enemy in enemies:
		if global_position.distance_to(enemy.global_position) > soft_attract_radius:
			continue
		enemy.global_position += (global_position - enemy.global_position) * attract_factor

func _find_direct_hit_target() -> Node2D:
	var enemies: Array = _get_valid_enemies()
	var best_target: Node2D = null
	var best_dist: float = INF
	var best_angle: float = INF
	var best_id: int = 2147483647
	for enemy in enemies:
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist > direct_hit_radius:
			continue
		var angle_score: float = 0.0
		var to_enemy: Vector2 = enemy.global_position - global_position
		if flight_direction.length_squared() > 0.0001 and to_enemy.length_squared() > 0.0001:
			angle_score = abs(flight_direction.angle_to(to_enemy.normalized()))
		var target_id: int = _get_target_id(enemy)
		if best_target == null or dist < best_dist - 0.0001 or (
			abs(dist - best_dist) <= 0.0001 and (
				angle_score < best_angle - 0.0001 or (
					abs(angle_score - best_angle) <= 0.0001 and target_id < best_id
				)
			)
		):
			best_target = enemy
			best_dist = dist
			best_angle = angle_score
			best_id = target_id
	return best_target

func _apply_direct_hit(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	_apply_damage(target, _get_direct_hit_damage())
	_apply_status(target, "stun", short_pin_duration, 0.0)
	if Global != null:
		Global.spawn_floating_text(target.global_position, "PIN!", Color(1.2, 0.42, 0.32))

func _land(reason: String) -> void:
	if is_landed:
		return
	is_landed = true
	landing_reason = reason
	rotation = 0.0
	if is_instance_valid(visual_body):
		visual_body.scale = Vector2(1.15, 1.15)
		visual_body.color = body_color

	_capture_landing_targets()
	_attempt_q_recall_once()
	_start_lifetime_timer()

	if Global != null:
		Global.on_camera_shake.emit(7.0, 0.16)
		Global.spawn_floating_text(global_position, "THUD!", Color(0.95, 0.72, 0.62))

	if skill_ref != null:
		var skill_obj: Variant = skill_ref.get_ref()
		if skill_obj != null and is_instance_valid(skill_obj) and skill_obj.has_method("register_landed_stake"):
			skill_obj.call("register_landed_stake", self)

func _capture_landing_targets() -> void:
	var q_targets: Array[Node2D] = _get_q_linked_targets()
	var capture_map: Dictionary = {}

	for target in q_targets:
		if target == null or not is_instance_valid(target):
			continue
		if _should_capture_target(target):
			capture_map[_get_target_id(target)] = target

	for enemy in _get_valid_enemies():
		if _should_capture_target(enemy):
			capture_map[_get_target_id(enemy)] = enemy

	var main_target: Node2D = get_main_target()
	if is_instance_valid(main_target):
		capture_map[_get_target_id(main_target)] = main_target

	for target_id in capture_map.keys():
		var target: Variant = capture_map[target_id]
		if target != null and is_instance_valid(target) and target is Node2D:
			transfer_q_chain_to_stake(target)

func _should_capture_target(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target == get_main_target():
		return true
	var dist: float = global_position.distance_to(target.global_position)
	return dist <= tether_radius or dist <= landing_capture_radius

func _enforce_tether_bounds(_delta: float) -> void:
	var next_entries: Dictionary = {}
	for entry_key in linked_targets.keys():
		var entry: Variant = linked_targets.get(entry_key, {})
		if not (entry is Dictionary):
			continue
		var ref: Variant = (entry as Dictionary).get("ref", null)
		var target_obj: Variant = ref.get_ref() if ref is WeakRef else null
		if target_obj == null or not is_instance_valid(target_obj):
			continue
		if not (target_obj is Node2D):
			continue
		var target: Node2D = target_obj
		var dist: float = global_position.distance_to(target.global_position)
		if dist > tether_radius and dist > 0.001:
			var dir: Vector2 = (target.global_position - global_position).normalized()
			target.global_position = global_position + dir * tether_radius
		next_entries[entry_key] = entry
	linked_targets = next_entries

func _attempt_q_recall_once() -> void:
	if q_recall_attempted:
		return
	q_recall_attempted = true

	var q_runtime: Node = _get_q_runtime()
	if q_runtime == null or not is_instance_valid(q_runtime):
		return

	var q_center: Vector2 = _get_q_center(q_runtime)
	if q_center.distance_to(global_position) > q_recall_radius:
		return

	if q_runtime.has_method("attempt_recall"):
		q_runtime.call("attempt_recall")
	elif q_runtime.has_method("request_recall"):
		q_runtime.call("request_recall")
	elif q_runtime.has_method("manual_dismiss"):
		q_runtime.call("manual_dismiss")
	elif q_runtime.has_method("queue_free"):
		q_runtime.queue_free()

func _start_lifetime_timer() -> void:
	if not is_instance_valid(lifetime_timer):
		return
	lifetime_timer.stop()
	lifetime_timer.wait_time = stake_life_duration
	lifetime_timer.start()

func _on_lifetime_timeout() -> void:
	queue_free()

func _draw() -> void:
	if is_landed:
		for target in get_linked_targets():
			draw_line(Vector2.ZERO, to_local(target.global_position), body_color, 2.0)
		return

	if global_position.distance_to(target_pos) > 0.5:
		draw_line(Vector2.ZERO, to_local(target_pos), Color(0.55, 0.18, 0.16, 0.75), 1.5)

func _get_valid_enemies() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	if not is_inside_tree():
		return targets
	for enemy_obj: Variant in get_tree().get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy: Node2D = enemy_obj
		if not enemy.has_node("HealthComponent"):
			continue
		targets.append(enemy)
	return targets

func _get_q_linked_targets() -> Array[Node2D]:
	var q_runtime: Node = _get_q_runtime()
	if q_runtime == null or not is_instance_valid(q_runtime):
		return []

	if q_runtime.has_method("get_linked_targets"):
		var q_targets_var: Variant = q_runtime.call("get_linked_targets")
		return _normalize_target_array(q_targets_var)

	if "chained_enemies" in q_runtime:
		var q_chain_var: Variant = q_runtime.get("chained_enemies")
		if q_chain_var is Array:
			var q_targets: Array[Node2D] = []
			for ref_var in q_chain_var:
				var ref: Variant = ref_var
				var target_obj: Variant = ref.get_ref() if ref is WeakRef else null
				if target_obj == null or not is_instance_valid(target_obj):
					continue
				if not (target_obj is Node2D):
					continue
				q_targets.append(target_obj)
			return q_targets

	return []

func _normalize_target_array(raw_value: Variant) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	if not (raw_value is Array):
		return targets
	for item in raw_value:
		if item == null or not is_instance_valid(item):
			continue
		if not (item is Node2D):
			continue
		targets.append(item)
	return targets

func _get_q_runtime() -> Node:
	if not is_instance_valid(player_ref):
		return null
	if "active_saw" in player_ref:
		var active_saw_var: Variant = player_ref.get("active_saw")
		if active_saw_var is Node and is_instance_valid(active_saw_var):
			return active_saw_var
	if player_ref.has_method("get_active_saw"):
		var active_saw_method: Variant = player_ref.call("get_active_saw")
		if active_saw_method is Node and is_instance_valid(active_saw_method):
			return active_saw_method
	return null

func _get_q_center(q_runtime: Node) -> Vector2:
	if q_runtime == null or not is_instance_valid(q_runtime):
		return global_position
	if q_runtime.has_method("get_center"):
		var center_var: Variant = q_runtime.call("get_center")
		if center_var is Vector2:
			return center_var
	if "global_position" in q_runtime:
		var position_var: Variant = q_runtime.get("global_position")
		if position_var is Vector2:
			return position_var
	return global_position

func _remove_target_from_q_runtime(target: Node2D) -> void:
	var q_runtime: Node = _get_q_runtime()
	if q_runtime == null or not is_instance_valid(q_runtime) or target == null or not is_instance_valid(target):
		return

	if q_runtime.has_method("transfer_q_chain_to_stake"):
		q_runtime.call("transfer_q_chain_to_stake", target)
		return

	if "chained_enemies" in q_runtime:
		var q_chain_var: Variant = q_runtime.get("chained_enemies")
		if q_chain_var is Array:
			var filtered: Array = []
			for ref_var in q_chain_var:
				var ref: Variant = ref_var
				var obj: Variant = ref.get_ref() if ref is WeakRef else null
				if obj == target:
					continue
				filtered.append(ref)
			q_runtime.set("chained_enemies", filtered)

func _apply_damage(target: Node2D, amount: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_node("HealthComponent"):
		return
	var health_component: Node = target.get_node("HealthComponent")
	if health_component != null and health_component.has_method("take_damage"):
		health_component.call("take_damage", max(1, amount))

func _apply_status(target: Node2D, status_type: String, duration: float, value: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("apply_status"):
		target.call("apply_status", status_type, max(0.05, duration), value)

func _get_direct_hit_damage() -> int:
	var owner_damage: float = _get_owner_damage()
	return max(1, int(round(owner_damage * direct_hit_damage_ratio)))

func _get_owner_damage() -> float:
	if not is_instance_valid(player_ref):
		return 10.0
	if "damage" in player_ref:
		return float(player_ref.get("damage"))
	return 10.0

func _get_player_float(property_name: String, default_value: float) -> float:
	if is_instance_valid(player_ref) and (property_name in player_ref):
		return float(player_ref.get(property_name))
	return default_value

func _get_player_color(property_name: String, default_value: Color) -> Color:
	if is_instance_valid(player_ref) and (property_name in player_ref):
		var value: Variant = player_ref.get(property_name)
		if value is Color:
			return value
	return default_value

func _get_target_id(target: Node2D) -> int:
	if target == null or not is_instance_valid(target):
		return 0
	return int(target.get_instance_id())

func _get_linked_target_ids() -> Array[int]:
	var ids: Array[int] = []
	for target in get_linked_targets():
		ids.append(_get_target_id(target))
	return ids

func _get_linked_target_names() -> Array[String]:
	var names: Array[String] = []
	for target in get_linked_targets():
		names.append(target.name)
	return names

func _get_life_remaining() -> float:
	if not is_instance_valid(lifetime_timer):
		return 0.0
	if not lifetime_timer.is_stopped():
		return lifetime_timer.time_left
	return 0.0

func get_main_target() -> Node2D:
	var target_obj: Variant = main_target_ref.get_ref() if main_target_ref != null else null
	if target_obj == null or not is_instance_valid(target_obj):
		return null
	if not (target_obj is Node2D):
		return null
	return target_obj

func _clear_owner_references() -> void:
	if skill_ref != null:
		var skill_obj: Variant = skill_ref.get_ref()
		if skill_obj != null and is_instance_valid(skill_obj):
			if "active_stake" in skill_obj and skill_obj.get("active_stake") == self:
				skill_obj.set("active_stake", null)

	if is_instance_valid(player_ref) and ("active_stake" in player_ref) and player_ref.get("active_stake") == self:
		player_ref.set("active_stake", null)

func _exit_tree() -> void:
	_clear_owner_references()
	skill_ref = null
	player_ref = null
