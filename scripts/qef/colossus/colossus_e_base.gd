extends SkillEBase
class_name ColossusEBase

const Utils = preload("res://scripts/qef/core/colossus_skill_utils.gd")

var colossus_role_id: String = ""
var _dash_combo_target_ref: WeakRef = null
var _dash_combo_expire_msec: int = 0
var _dash_combo_active: bool = false
var _dash_combo_offset: Vector2 = Vector2.ZERO
var _dash_combo_hit_index: int = 0
var _dash_combo_mode: String = ""

const DASH_HIT_STEPS: Array[float] = [0.30, 0.60, 0.90]


func _ready() -> void:
	super._ready()
	_connect_dash_signals()


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

	match colossus_role_id:
		"butcher":
			_execute_butcher()
		"glacier":
			_execute_glacier()
		"jailer":
			_execute_jailer()
		"blacksmith":
			_execute_blacksmith()
		"paladin":
			_execute_paladin()
		"breachmarshal":
			_execute_breachmarshal()
		"hexwarden":
			_execute_hexwarden()
		"executioner":
			_execute_executioner()
		_:
			start_cooldown()


func _get_colossus_q() -> Node:
	return get_q_skill()


func _get_open_q_state() -> Dictionary:
	var q_skill: Node = _get_colossus_q()
	if q_skill != null and q_skill.has_method("get_open_state"):
		var state_var: Variant = q_skill.call("get_open_state")
		if state_var is Dictionary:
			return state_var
	return {}


func _get_closed_q_state() -> Dictionary:
	var q_skill: Node = _get_colossus_q()
	if q_skill != null and q_skill.has_method("get_closed_state"):
		var state_var: Variant = q_skill.call("get_closed_state")
		if state_var is Dictionary:
			return state_var
	return {}


func _mutate_open_q_state(updates: Dictionary) -> void:
	var q_skill: Node = _get_colossus_q()
	if q_skill != null and q_skill.has_method("mutate_open_state"):
		q_skill.call("mutate_open_state", updates)


func _mutate_closed_q_state(updates: Dictionary) -> void:
	var q_skill: Node = _get_colossus_q()
	if q_skill != null and q_skill.has_method("mutate_closed_state"):
		q_skill.call("mutate_closed_state", updates)


func _connect_dash_signals() -> void:
	if not is_instance_valid(skill_owner):
		return
	var started_callable := Callable(self, "_on_owner_dash_started")
	var active_callable := Callable(self, "_on_owner_dash_active")
	var finished_callable := Callable(self, "_on_owner_dash_finished")
	if skill_owner.has_signal("dash_started") and not skill_owner.is_connected("dash_started", started_callable):
		skill_owner.connect("dash_started", started_callable)
	if skill_owner.has_signal("dash_active") and not skill_owner.is_connected("dash_active", active_callable):
		skill_owner.connect("dash_active", active_callable)
	if skill_owner.has_signal("dash_finished") and not skill_owner.is_connected("dash_finished", finished_callable):
		skill_owner.connect("dash_finished", finished_callable)


func _select_target_cone_then_radius(cone_deg: float, radius: float) -> Node2D:
	var aim_dir: Vector2 = get_aim_direction()
	var target: Node2D = Utils.find_nearest_enemy(get_tree(), skill_owner.global_position, radius, aim_dir, cone_deg)
	if target != null:
		return target
	return Utils.find_nearest_enemy(get_tree(), skill_owner.global_position, radius)


func _nearest_enemy_to_point(point: Vector2, radius: float) -> Node2D:
	return Utils.find_nearest_enemy(get_tree(), point, radius)


func _enemy_near_polyline(enemy: Node2D, points: Array[Vector2], radius: float) -> bool:
	if enemy == null or points.size() < 2:
		return false
	return Utils.distance_to_polyline(enemy.global_position, points) <= radius


func _mouse_near_polyline(points: Array[Vector2], radius: float) -> bool:
	if points.size() < 2 or not is_instance_valid(skill_owner):
		return false
	return Utils.distance_to_polyline(skill_owner.get_global_mouse_position(), points) <= radius


func _arm_dash_combo(target: Node2D, mode: String, window_sec: float) -> void:
	if target == null or not is_instance_valid(target) or not is_instance_valid(skill_owner):
		return
	_dash_combo_target_ref = weakref(target)
	_dash_combo_expire_msec = Time.get_ticks_msec() + int(round(max(0.05, window_sec) * 1000.0))
	_dash_combo_active = false
	_dash_combo_hit_index = 0
	_dash_combo_mode = mode
	_dash_combo_offset = target.global_position - skill_owner.global_position


func _resolve_dash_combo_target() -> Node2D:
	var target_var: Variant = _dash_combo_target_ref.get_ref() if _dash_combo_target_ref != null else null
	if target_var == null or not is_instance_valid(target_var):
		return null
	if target_var is Node2D:
		return target_var as Node2D
	return null


func _clear_dash_combo_state() -> void:
	_dash_combo_target_ref = null
	_dash_combo_expire_msec = 0
	_dash_combo_active = false
	_dash_combo_hit_index = 0
	_dash_combo_mode = ""
	_dash_combo_offset = Vector2.ZERO


func _on_owner_dash_started(player_id: String, _start_pos: Vector2, _direction: Vector2) -> void:
	if not is_instance_valid(skill_owner) or str(skill_owner.get("player_id")) != player_id:
		return
	if Time.get_ticks_msec() > _dash_combo_expire_msec:
		return
	if _resolve_dash_combo_target() == null:
		return
	_dash_combo_active = true
	_dash_combo_hit_index = 0
	var target: Node2D = _resolve_dash_combo_target()
	_dash_combo_offset = target.global_position - skill_owner.global_position
	Global.spawn_floating_text(target.global_position, "冲带", Color(1.0, 0.72, 0.34))


func _on_owner_dash_active(player_id: String, current_pos: Vector2, _direction: Vector2, normalized_time: float) -> void:
	if not _dash_combo_active or not is_instance_valid(skill_owner) or str(skill_owner.get("player_id")) != player_id:
		return
	var target: Node2D = _resolve_dash_combo_target()
	if target == null:
		_clear_dash_combo_state()
		return
	target.global_position = current_pos + _dash_combo_offset
	while _dash_combo_hit_index < DASH_HIT_STEPS.size() and normalized_time >= DASH_HIT_STEPS[_dash_combo_hit_index]:
		Utils.apply_damage(target, max(1, int(round(_get_base_damage_value(0.45)))))
		Utils.apply_status(target, "marked", 0.8, 0.18, 1, 0.3)
		_dash_combo_hit_index += 1


func _on_owner_dash_finished(player_id: String, end_pos: Vector2, _direction: Vector2) -> void:
	if not _dash_combo_active or not is_instance_valid(skill_owner) or str(skill_owner.get("player_id")) != player_id:
		return
	var target: Node2D = _resolve_dash_combo_target()
	if target == null:
		_clear_dash_combo_state()
		return
	match colossus_role_id:
		"butcher":
			_finish_butcher_dash_combo(target)
		"glacier":
			_finish_glacier_dash_combo(target, end_pos)
		"jailer":
			_finish_jailer_dash_combo(target, end_pos)
		"blacksmith":
			_finish_blacksmith_dash_combo(target, end_pos)
		"paladin":
			_finish_paladin_dash_combo(target, end_pos)
		"breachmarshal":
			_finish_breachmarshal_dash_combo(target)
		"hexwarden":
			_finish_hexwarden_dash_combo(target)
		"executioner":
			_finish_executioner_dash_combo(target, end_pos)
	_clear_dash_combo_state()


func _get_base_damage_value(multiplier: float = 1.0) -> float:
	if is_instance_valid(skill_owner) and "damage" in skill_owner:
		return max(12.0, float(skill_owner.get("damage")) * multiplier)
	return 12.0 * multiplier


func _push_target_to_point(enemy: Node2D, target: Vector2, step: float) -> void:
	Utils.move_enemy_towards(enemy, target, step)


func _apply_burst_circle(center: Vector2, radius: float, damage: int, color: Color) -> void:
	var polygon: PackedVector2Array = Utils.build_circle_polygon(center, radius, 18)
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": 0,
		"damage_interval": 0.2,
		"duration": 0.18,
		"color": color,
	})
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		if enemy.global_position.distance_to(center) > radius:
			continue
		Utils.apply_damage(enemy, damage)


func _push_enemies_in_cone(center: Vector2, aim_dir: Vector2, angle_deg: float, radius: float, distance: float, status_name: String = "") -> int:
	var hit_count: int = 0
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		if not Utils.is_point_in_cone(enemy.global_position, center, aim_dir, angle_deg, radius):
			continue
		var push_dir: Vector2 = (enemy.global_position - center).normalized()
		if push_dir.length_squared() <= 0.0001:
			push_dir = aim_dir
		Utils.apply_knockback_or_move(enemy, push_dir, distance * 9.0, 0.1)
		if not status_name.is_empty():
			Utils.apply_status(enemy, status_name, 1.2, 0.2, 1, 0.3)
		hit_count += 1
	return hit_count


func _execute_butcher() -> void:
	var target: Node2D = _select_target_cone_then_radius(30.0, 260.0)
	if target == null:
		Global.spawn_floating_text(skill_owner.global_position, "MISS", Color(1.0, 0.72, 0.56))
		start_cooldown()
		return
	var damage_amp: float = get_e_damage_amp(0.40, 0.40)
	var open_state: Dictionary = _get_open_q_state()
	var closed_state: Dictionary = _get_closed_q_state()
	var points: Array[Vector2] = _read_points(open_state.get("points", []))
	var used_synergy: bool = false
	if points.size() >= 2 and _enemy_near_polyline(target, points, 120.0):
		var projected: Dictionary = Utils.project_point_to_polyline(target.global_position, points)
		var hit_point: Vector2 = projected.get("point", target.global_position)
		target.global_position = hit_point
		var advance: Dictionary = Utils.advance_along_polyline(points, int(projected.get("index", 0)), float(projected.get("t", 0.0)), 160.0, true)
		var anchor: Vector2 = open_state.get("anchor_point", points.back())
		var final_point: Vector2 = advance.get("point", anchor)
		_push_target_to_point(target, final_point, 120.0)
		for _i: int in range(2):
			Utils.apply_damage(target, max(1, int(round(_get_base_damage_value(0.65) * damage_amp))))
		Utils.apply_status(target, "marked", 1.2, 0.24, 1, 0.3)
		used_synergy = true
		publish_e_context(final_point, 110.0, "butcher_return_line", {"mode": "open_return"}, "butcher_hook_window", 0.26)
	elif not closed_state.is_empty():
		var polygon: PackedVector2Array = _read_polygon(closed_state.get("polygon", PackedVector2Array()))
		var edge_info: Dictionary = Utils.distance_to_polygon_edge(target.global_position, polygon)
		if polygon.size() >= 3 and (Geometry2D.is_point_in_polygon(target.global_position, polygon) or float(edge_info.get("distance", INF)) <= 80.0):
			var mouth_dir: Vector2 = get_aim_direction()
			var center: Vector2 = closed_state.get("center", skill_owner.global_position)
			var radius: float = max(72.0, float(closed_state.get("radius", 120.0)) * 0.78)
			var mouth_center: Vector2 = center + mouth_dir * min(radius * 0.55, 110.0)
			_mutate_closed_q_state({"mouth_center": mouth_center, "radius": radius})
			for enemy: Node2D in Utils.get_enemies(get_tree()):
				if polygon.size() < 3 or not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
					continue
				_push_target_to_point(enemy, mouth_center, 70.0)
				Utils.apply_status(enemy, "marked", 0.8, 0.24, 1, 0.3)
				Utils.apply_damage(enemy, max(1, int(round(_get_base_damage_value(0.55) * damage_amp))))
			used_synergy = true
			publish_e_context(center, radius, "butcher_close_press", {"mode": "close_press"}, "butcher_hook_window", 0.26)
	if not used_synergy:
		var hold_point: Vector2 = skill_owner.global_position + get_aim_direction() * 72.0
		_push_target_to_point(target, hold_point, 140.0)
		Utils.apply_status(target, "stun", 0.35, 0.0, 1, 0.1)
		Utils.apply_damage(target, max(1, int(round(_get_base_damage_value(0.95) * damage_amp))))
		publish_e_context(hold_point, 96.0, "butcher_hook", {"mode": "hook"}, "butcher_hook_window", 0.26)
	spawn_skill_vfx(target.global_position, Color(1.0, 0.22, 0.18, 0.92), 0.74)
	_arm_dash_combo(target, "butcher", 0.26)
	start_cooldown()


func _execute_glacier() -> void:
	var aim_dir: Vector2 = get_aim_direction()
	var damage_amp: float = get_e_damage_amp(0.30, 0.34)
	var base_hits: int = _push_enemies_in_cone(skill_owner.global_position, aim_dir, 70.0, 180.0, 120.0, "marked")
	var open_state: Dictionary = _get_open_q_state()
	var closed_state: Dictionary = _get_closed_q_state()
	var target: Node2D = _select_target_cone_then_radius(70.0, 180.0)
	var used_synergy: bool = false
	if target != null and not open_state.is_empty():
		var points: Array[Vector2] = _read_points(open_state.get("points", []))
		if points.size() >= 2 and (_enemy_near_polyline(target, points, 120.0) or _mouse_near_polyline(points, 120.0)):
			var projected: Dictionary = Utils.project_point_to_polyline(target.global_position, points)
			var crack_points: Array[Vector2] = _read_points(open_state.get("crack_points", []))
			var crack_point: Vector2 = _nearest_of_two(projected.get("point", target.global_position), crack_points)
			target.global_position = projected.get("point", target.global_position)
			_push_target_to_point(target, crack_point, 160.0)
			Utils.apply_damage(target, max(1, int(round(_get_base_damage_value(0.9) * damage_amp))))
			Utils.apply_knockback_or_move(target, (target.global_position - crack_point).normalized(), 520.0, 0.1)
			_apply_burst_circle(crack_point, 64.0, max(1, int(round(_get_base_damage_value(0.55) * damage_amp))), Color(0.72, 0.95, 1.18, 0.75))
			used_synergy = true
			publish_e_context(crack_point, 92.0, "glacier_edge_reel", {"mode": "open_edge"}, "glacier_shatter_window", 0.35)
	if not used_synergy and not closed_state.is_empty():
		var polygon: PackedVector2Array = _read_polygon(closed_state.get("polygon", PackedVector2Array()))
		if polygon.size() >= 3:
			var return_corner: Vector2 = Utils.choose_vertex_by_direction(polygon, closed_state.get("center", skill_owner.global_position), aim_dir)
			_mutate_closed_q_state({"return_corner": return_corner})
			for enemy: Node2D in Utils.get_enemies(get_tree()):
				if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
					continue
				_push_target_to_point(enemy, return_corner, 80.0)
				Utils.apply_damage(enemy, max(1, int(round(_get_base_damage_value(0.5) * damage_amp))))
				Utils.apply_status(enemy, "freeze", 0.45, 0.0, 1, 0.1)
			used_synergy = true
			publish_e_context(return_corner, 84.0, "glacier_corner_shatter", {"mode": "close_corner"}, "glacier_shatter_window", 0.35)
	Global.spawn_floating_text(skill_owner.global_position, "爆棱 x%d" % base_hits, Color(0.78, 1.0, 1.18))
	_arm_dash_combo(target, "glacier", 0.35)
	start_cooldown()


func _execute_jailer() -> void:
	var open_state: Dictionary = _get_open_q_state()
	var closed_state: Dictionary = _get_closed_q_state()
	var aim_dir: Vector2 = get_aim_direction()
	var target: Node2D = _select_target_cone_then_radius(70.0, 260.0)
	var used_synergy: bool = false
	if not open_state.is_empty():
		var gate_points: Array[Vector2] = _read_points(open_state.get("gate_points", []))
		var nearest_gate: Vector2 = _find_nearest_gate(skill_owner.global_position, gate_points, 260.0)
		if nearest_gate != Vector2.ZERO and target != null and (target.global_position.distance_to(nearest_gate) <= 100.0 or skill_owner.get_global_mouse_position().distance_to(nearest_gate) <= 100.0):
			var gate_normal: Vector2 = Vector2(-aim_dir.y, aim_dir.x)
			_push_target_to_point(target, nearest_gate + gate_normal * 160.0, 120.0)
			Utils.apply_status(target, "marked", 1.2, 0.20, 1, 0.3)
			Utils.apply_status(target, "slow", 1.0, 0.32, 1, 0.1)
			used_synergy = true
			publish_e_context(nearest_gate, 90.0, "jailer_rotate_gate", {"mode": "open_gate"}, "jailer_verdict_window", 0.35)
	if not used_synergy and not closed_state.is_empty():
		var polygon: PackedVector2Array = _read_polygon(closed_state.get("polygon", PackedVector2Array()))
		if polygon.size() >= 3:
			var dead_door: Vector2 = Utils.choose_edge_midpoint_by_direction(polygon, closed_state.get("center", skill_owner.global_position), -aim_dir).get("point", skill_owner.global_position)
			_mutate_closed_q_state({"dead_door_point": dead_door})
			for enemy: Node2D in Utils.get_enemies(get_tree()):
				if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
					continue
				_push_target_to_point(enemy, dead_door, 70.0)
				Utils.apply_status(enemy, "slow", 0.9, 0.34, 1, 0.1)
				Utils.apply_status(enemy, "marked", 1.0, 0.20, 1, 0.3)
			used_synergy = true
			publish_e_context(dead_door, 96.0, "jailer_dead_gate", {"mode": "close_verdict"}, "jailer_verdict_window", 0.35)
	if not used_synergy:
		var gate_center: Vector2 = skill_owner.global_position + aim_dir * 120.0
		if target != null and target.global_position.distance_to(gate_center) <= 72.0:
			Utils.apply_status(target, "stun", 0.35, 0.0, 1, 0.1)
			Utils.apply_status(target, "marked", 1.0, 0.18, 1, 0.3)
		_apply_burst_circle(gate_center, 60.0, max(1, int(round(_get_base_damage_value(0.55)))), Color(1.0, 0.88, 0.38, 0.7))
		publish_e_context(gate_center, 80.0, "jailer_lock_gate", {"mode": "lock"}, "jailer_verdict_window", 0.35)
	_arm_dash_combo(target, "jailer", 0.35)
	start_cooldown()


func _execute_blacksmith() -> void:
	var aim_dir: Vector2 = get_aim_direction()
	var damage_amp: float = get_e_damage_amp(0.24, 0.30)
	var hit_count: int = _push_enemies_in_cone(skill_owner.global_position, aim_dir, 75.0, 170.0, 90.0, "marked")
	var open_state: Dictionary = _get_open_q_state()
	var closed_state: Dictionary = _get_closed_q_state()
	var target: Node2D = _select_target_cone_then_radius(75.0, 170.0)
	var used_synergy: bool = false
	if not open_state.is_empty():
		var points: Array[Vector2] = _read_points(open_state.get("points", []))
		var slot_points: Array[Vector2] = _read_points(open_state.get("slot_points", []))
		if points.size() >= 2 and (_mouse_near_polyline(points, 160.0) or (target != null and _enemy_near_polyline(target, points, 160.0))):
			var forge_point: Vector2 = _find_nearest_gate(skill_owner.get_global_mouse_position(), slot_points, 9999.0)
			if forge_point == Vector2.ZERO:
				forge_point = _find_nearest_gate(skill_owner.global_position, slot_points, 9999.0)
			var asset_nodes: Array[Node2D] = Utils.get_reforge_assets(get_tree(), forge_point, 72.0)
			_apply_burst_circle(forge_point, 68.0, max(1, int(round(_get_base_damage_value(0.8) * damage_amp))), Color(1.0, 0.64, 0.3, 0.78))
			for asset_node: Node2D in asset_nodes:
				asset_node.set_meta("blacksmith_reforged", true)
				spawn_skill_vfx(asset_node.global_position, Color(1.0, 0.72, 0.36, 0.82), 0.42)
			if asset_nodes.is_empty():
				var lava_end: Vector2 = forge_point + aim_dir * 120.0
				spawn_transient_polyline([forge_point, lava_end], Color(1.0, 0.55, 0.2, 0.92), 18.0, 0.4, false)
				for enemy: Node2D in Utils.get_enemies(get_tree()):
					var projected: Dictionary = Utils.project_point_to_segment(enemy.global_position, forge_point, lava_end)
					if float(projected.get("distance", INF)) > 28.0:
						continue
					Utils.apply_damage(enemy, max(1, int(round(_get_base_damage_value(0.7) * damage_amp))))
					Utils.apply_status(enemy, "burn", 0.8, 8.0, 1, 0.35)
			used_synergy = true
			publish_e_context(forge_point, 92.0, "blacksmith_reforge", {"mode": "open_reforge"}, "blacksmith_reforge_window", 0.35)
	if not used_synergy and not closed_state.is_empty():
		var center: Vector2 = closed_state.get("center", skill_owner.global_position)
		var radius: float = float(closed_state.get("radius", 120.0))
		var asset_nodes: Array[Node2D] = Utils.get_reforge_assets(get_tree(), center, radius + 20.0)
		for asset_node: Node2D in asset_nodes:
			asset_node.set_meta("blacksmith_reforged", true)
			spawn_skill_vfx(asset_node.global_position, Color(1.0, 0.72, 0.34, 0.82), 0.4)
		for enemy: Node2D in Utils.get_enemies(get_tree()):
			if enemy.global_position.distance_to(center) > radius + 24.0:
				continue
			var tangent: Vector2 = Vector2(-(enemy.global_position - center).y, (enemy.global_position - center).x).normalized()
			Utils.apply_knockback_or_move(enemy, tangent, 460.0, 0.08)
			Utils.apply_status(enemy, "burn", 0.9, 8.0, 1, 0.35)
		used_synergy = true
		publish_e_context(center, radius, "blacksmith_ring_pulse", {"mode": "close_ring"}, "blacksmith_reforge_window", 0.35)
	Global.spawn_floating_text(skill_owner.global_position, "锻击 x%d" % hit_count, Color(1.0, 0.74, 0.38))
	_arm_dash_combo(target, "blacksmith", 0.35)
	start_cooldown()


func _execute_paladin() -> void:
	var aim_dir: Vector2 = get_aim_direction()
	var damage_amp: float = get_e_damage_amp(0.26, 0.30)
	var open_state: Dictionary = _get_open_q_state()
	var closed_state: Dictionary = _get_closed_q_state()
	var target: Node2D = _select_target_cone_then_radius(70.0, 200.0)
	var used_synergy: bool = false
	if not open_state.is_empty():
		var points: Array[Vector2] = _read_points(open_state.get("points", []))
		if points.size() >= 2 and (_mouse_near_polyline(points, 120.0) or (target != null and _enemy_near_polyline(target, points, 120.0))):
			var projected: Dictionary = Utils.project_point_to_polyline(skill_owner.global_position, points)
			var idx: int = int(projected.get("index", 0))
			var seg_dir: Vector2 = (points[min(idx + 1, points.size() - 1)] - points[idx]).normalized()
			var normal: Vector2 = Vector2(-seg_dir.y, seg_dir.x) * -float(open_state.get("safe_side", 1.0))
			var push_origin: Vector2 = projected.get("point", skill_owner.global_position)
			for enemy: Node2D in Utils.get_enemies(get_tree()):
				if enemy.global_position.distance_to(push_origin) > 120.0:
					continue
				Utils.apply_knockback_or_move(enemy, normal, 560.0, 0.08)
			_apply_burst_circle(push_origin, 72.0, max(1, int(round(_get_base_damage_value(0.55) * damage_amp))), Color(1.0, 0.92, 0.48, 0.72))
			used_synergy = true
			publish_e_context(push_origin, 96.0, "paladin_wall_push", {"mode": "open_wall"}, "paladin_oath_window", 0.35)
	if not used_synergy and not closed_state.is_empty():
		var polygon: PackedVector2Array = _read_polygon(closed_state.get("polygon", PackedVector2Array()))
		if polygon.size() >= 3:
			var verdict_point: Vector2 = Utils.choose_edge_midpoint_by_direction(polygon, closed_state.get("center", skill_owner.global_position), -aim_dir).get("point", skill_owner.global_position)
			_mutate_closed_q_state({"verdict_point": verdict_point})
			var shield_hits: int = 0
			for enemy: Node2D in Utils.get_enemies(get_tree()):
				if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
					continue
				_push_target_to_point(enemy, verdict_point, 76.0)
				shield_hits += 1
			_gain_guard_stacks(min(3, shield_hits))
			used_synergy = true
			publish_e_context(verdict_point, 96.0, "paladin_court_push", {"mode": "close_court"}, "paladin_oath_window", 0.35)
	if not used_synergy:
		skill_owner.global_position += aim_dir * 140.0
		if target != null and target.global_position.distance_to(skill_owner.global_position) <= 90.0:
			Utils.apply_knockback_or_move(target, aim_dir, 520.0, 0.08)
			Utils.apply_damage(target, max(1, int(round(_get_base_damage_value(0.9) * damage_amp))))
		_gain_guard_stacks(1)
		publish_e_context(skill_owner.global_position, 90.0, "paladin_charge", {"mode": "charge"}, "paladin_oath_window", 0.35)
	_arm_dash_combo(target, "paladin", 0.35)
	start_cooldown()


func _execute_breachmarshal() -> void:
	var aim_dir: Vector2 = get_aim_direction()
	var damage_amp: float = get_e_damage_amp(0.24, 0.32)
	var open_state: Dictionary = _get_open_q_state()
	var closed_state: Dictionary = _get_closed_q_state()
	var target: Node2D = _select_target_cone_then_radius(75.0, 220.0)
	var used_synergy: bool = false
	if not open_state.is_empty():
		var points: Array[Vector2] = _read_points(open_state.get("points", []))
		if target != null and points.size() >= 2 and (_enemy_near_polyline(target, points, 110.0) or _mouse_near_polyline(points, 110.0)):
			var projected: Dictionary = Utils.project_point_to_polyline(target.global_position, points)
			var mouth_point: Vector2 = open_state.get("mouth_point", points.back())
			target.global_position = projected.get("point", target.global_position)
			_push_target_to_point(target, mouth_point, 140.0)
			_apply_burst_circle(mouth_point, 78.0, max(1, int(round(_get_base_damage_value(0.8) * damage_amp))), Color(0.96, 0.9, 0.78, 0.74))
			used_synergy = true
			publish_e_context(mouth_point, 96.0, "breachmarshal_groove", {"mode": "open_groove"}, "breachmarshal_charge_window", 0.4)
	if not used_synergy and not closed_state.is_empty():
		var polygon: PackedVector2Array = _read_polygon(closed_state.get("polygon", PackedVector2Array()))
		if polygon.size() >= 3:
			var reverb_point: Vector2 = Utils.choose_edge_midpoint_by_direction(polygon, closed_state.get("center", skill_owner.global_position), aim_dir).get("point", skill_owner.global_position)
			_mutate_closed_q_state({"reverb_point": reverb_point})
			for enemy: Node2D in Utils.get_enemies(get_tree()):
				if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
					continue
				_push_target_to_point(enemy, reverb_point, 72.0)
				Utils.apply_damage(enemy, max(1, int(round(_get_base_damage_value(0.65) * damage_amp))))
				_push_target_to_point(enemy, closed_state.get("center", skill_owner.global_position), 48.0)
			used_synergy = true
			publish_e_context(reverb_point, 96.0, "breachmarshal_reverb", {"mode": "close_reverb"}, "breachmarshal_charge_window", 0.4)
	if not used_synergy:
		skill_owner.global_position += aim_dir * 160.0
		if target != null and target.global_position.distance_to(skill_owner.global_position) <= 96.0:
			Utils.apply_knockback_or_move(target, aim_dir, 560.0, 0.08)
			Utils.apply_status(target, "marked", 1.0, 0.18, 1, 0.3)
			Utils.apply_damage(target, max(1, int(round(_get_base_damage_value(0.95) * damage_amp))))
		publish_e_context(skill_owner.global_position, 96.0, "breachmarshal_charge", {"mode": "charge"}, "breachmarshal_charge_window", 0.4)
	_arm_dash_combo(target, "breachmarshal", 0.4)
	start_cooldown()


func _execute_hexwarden() -> void:
	var aim_dir: Vector2 = get_aim_direction()
	var damage_amp: float = get_e_damage_amp(0.24, 0.30)
	var open_state: Dictionary = _get_open_q_state()
	var closed_state: Dictionary = _get_closed_q_state()
	var target: Node2D = _select_target_cone_then_radius(100.0, 180.0)
	var used_synergy: bool = false
	if not open_state.is_empty():
		var points: Array[Vector2] = _read_points(open_state.get("points", []))
		if target != null and points.size() >= 2 and (_enemy_near_polyline(target, points, 110.0) or _mouse_near_polyline(points, 110.0)):
			var nail_points: Array[Vector2] = _read_points(open_state.get("nail_points", []))
			var nail_point: Vector2 = _find_nearest_gate(target.global_position, nail_points, 9999.0)
			if nail_point == Vector2.ZERO:
				nail_point = skill_owner.global_position
			_push_target_to_point(target, nail_point, 160.0)
			Utils.apply_status(target, "curse", 1.8, 8.0, 1, 0.7)
			Utils.apply_status(target, "marked", 1.2, 0.18, 1, 0.3)
			used_synergy = true
			publish_e_context(nail_point, 88.0, "hexwarden_face_flip", {"mode": "open_flip"}, "hexwarden_bite_window", 0.35)
	if not used_synergy and not closed_state.is_empty():
		var polygon: PackedVector2Array = _read_polygon(closed_state.get("polygon", PackedVector2Array()))
		if polygon.size() >= 3:
			var center: Vector2 = closed_state.get("center", skill_owner.global_position)
			for enemy: Node2D in Utils.get_enemies(get_tree()):
				if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
					continue
				if aim_dir.dot(enemy.global_position - center) < 0.0:
					continue
				_push_target_to_point(enemy, center - aim_dir * 180.0, 110.0)
				Utils.apply_status(enemy, "curse", 1.8, 8.0, 1, 0.7)
			used_synergy = true
			publish_e_context(center, 110.0, "hexwarden_hall_repel", {"mode": "close_hall"}, "hexwarden_bite_window", 0.35)
	if not used_synergy:
		_apply_burst_circle(skill_owner.global_position, 140.0, max(1, int(round(_get_base_damage_value(0.7) * damage_amp))), Color(0.9, 0.42, 1.0, 0.76))
		for enemy: Node2D in Utils.get_enemies(get_tree()):
			if enemy.global_position.distance_to(skill_owner.global_position) > 140.0:
				continue
			Utils.apply_knockback_or_move(enemy, (enemy.global_position - skill_owner.global_position).normalized(), 420.0, 0.08)
			Utils.apply_status(enemy, "curse", 1.2, 8.0, 1, 0.7)
		publish_e_context(skill_owner.global_position, 140.0, "hexwarden_bite", {"mode": "bite"}, "hexwarden_bite_window", 0.35)
	_arm_dash_combo(target, "hexwarden", 0.35)
	start_cooldown()


func _execute_executioner() -> void:
	var damage_amp: float = get_e_damage_amp(0.22, 0.40)
	var open_state: Dictionary = _get_open_q_state()
	var closed_state: Dictionary = _get_closed_q_state()
	var threshold: float = 0.28
	var target: Node2D = _find_execution_target(threshold)
	if target == null:
		start_cooldown()
		return
	var used_synergy: bool = false
	if not open_state.is_empty():
		var points: Array[Vector2] = _read_points(open_state.get("points", []))
		if points.size() >= 2 and (Utils.enemy_has_status(target, "marked") or _enemy_near_polyline(target, points, 90.0)):
			var projected: Dictionary = Utils.project_point_to_polyline(target.global_position, points)
			target.global_position = projected.get("point", target.global_position)
			Utils.apply_damage(target, max(1, int(round(_get_base_damage_value(1.0) * damage_amp))))
			if Utils.is_enemy_below_threshold(target, threshold):
				Utils.apply_damage(target, 9999)
			else:
				Utils.apply_status(target, "marked", 1.2, 0.22, 1, 0.3)
			used_synergy = true
			publish_e_context(target.global_position, 88.0, "executioner_line_adjust", {"mode": "open_adjust"}, "executioner_chase_window", 0.30)
	if not used_synergy and not closed_state.is_empty():
		var center: Vector2 = closed_state.get("center", skill_owner.global_position)
		var radius: float = float(closed_state.get("radius", 120.0))
		var chain_count: int = 0
		for enemy: Node2D in Utils.get_enemies(get_tree()):
			if enemy.global_position.distance_to(center) > radius + 24.0:
				continue
			if not Utils.is_enemy_below_threshold(enemy, threshold) and not Utils.enemy_has_status(enemy, "marked"):
				continue
			skill_owner.global_position = enemy.global_position
			if Utils.is_enemy_below_threshold(enemy, threshold):
				Utils.apply_damage(enemy, 9999)
				chain_count += 1
			else:
				Utils.apply_damage(enemy, max(1, int(round(_get_base_damage_value(0.75) * damage_amp))))
			if chain_count >= 3:
				break
		used_synergy = true
		publish_e_context(center, radius, "executioner_chain", {"mode": "close_chain", "chain_count": chain_count}, "executioner_chase_window", 0.30)
	if not used_synergy:
		skill_owner.global_position += get_aim_direction() * 120.0
		if Utils.is_enemy_below_threshold(target, threshold):
			Utils.apply_damage(target, 9999)
		else:
			Utils.apply_damage(target, max(1, int(round(_get_base_damage_value(1.05) * damage_amp))))
			Utils.apply_status(target, "marked", 1.4, 0.24, 1, 0.3)
		publish_e_context(target.global_position, 88.0, "executioner_chase", {"mode": "chase"}, "executioner_chase_window", 0.30)
	_arm_dash_combo(target, "executioner", 0.30)
	start_cooldown()


func _finish_butcher_dash_combo(target: Node2D) -> void:
	var open_state: Dictionary = _get_open_q_state()
	if not open_state.is_empty():
		var anchor: Vector2 = open_state.get("anchor_point", target.global_position)
		target.global_position = anchor
	elif not _get_closed_q_state().is_empty():
		target.global_position = _get_closed_q_state().get("mouth_center", target.global_position)
	else:
		target.global_position = skill_owner.global_position + get_aim_direction() * 90.0
	Utils.apply_damage(target, max(1, int(round(_get_base_damage_value(0.75)))))
	Utils.apply_status(target, "stun", 0.35, 0.0, 1, 0.1)


func _finish_glacier_dash_combo(target: Node2D, end_pos: Vector2) -> void:
	var open_state: Dictionary = _get_open_q_state()
	var crack_points: Array[Vector2] = _read_points(open_state.get("crack_points", []))
	var crack_point: Vector2 = _nearest_of_two(end_pos, crack_points)
	if crack_point == Vector2.ZERO and not _get_closed_q_state().is_empty():
		crack_point = _get_closed_q_state().get("return_corner", end_pos)
	if crack_point != Vector2.ZERO:
		_apply_burst_circle(crack_point, 68.0, max(1, int(round(_get_base_damage_value(0.6)))), Color(0.76, 0.98, 1.18, 0.72))
		target.global_position = crack_point


func _finish_jailer_dash_combo(target: Node2D, end_pos: Vector2) -> void:
	_apply_burst_circle(end_pos, 64.0, max(1, int(round(_get_base_damage_value(0.4)))), Color(1.0, 0.88, 0.42, 0.66))
	Utils.apply_status(target, "slow", 0.8, 0.30, 1, 0.1)


func _finish_blacksmith_dash_combo(_target: Node2D, end_pos: Vector2) -> void:
	var line_start: Vector2 = skill_owner.global_position
	spawn_transient_polyline([line_start, end_pos], Color(1.0, 0.62, 0.24, 0.84), 16.0, 0.7, false)
	var open_state: Dictionary = _get_open_q_state()
	var slot_points: Array[Vector2] = _read_points(open_state.get("slot_points", []))
	var slot_point: Vector2 = _find_nearest_gate(end_pos, slot_points, 9999.0)
	if slot_point != Vector2.ZERO:
		_apply_burst_circle(slot_point, 64.0, max(1, int(round(_get_base_damage_value(0.45)))), Color(1.0, 0.7, 0.3, 0.72))


func _finish_paladin_dash_combo(_target: Node2D, end_pos: Vector2) -> void:
	_apply_burst_circle(end_pos, 72.0, max(1, int(round(_get_base_damage_value(0.45)))), Color(1.0, 0.92, 0.54, 0.7))
	_gain_guard_stacks(1)


func _finish_breachmarshal_dash_combo(target: Node2D) -> void:
	var open_state: Dictionary = _get_open_q_state()
	var points: Array[Vector2] = _read_points(open_state.get("points", []))
	if points.size() >= 2:
		for enemy: Node2D in Utils.get_enemies(get_tree()):
			var projected: Dictionary = Utils.project_point_to_polyline(enemy.global_position, points)
			if float(projected.get("distance", INF)) > 42.0:
				continue
			Utils.apply_damage(enemy, max(1, int(round(_get_base_damage_value(0.55)))))
		target.global_position = open_state.get("mouth_point", target.global_position)


func _finish_hexwarden_dash_combo(target: Node2D) -> void:
	var open_state: Dictionary = _get_open_q_state()
	var nail_points: Array[Vector2] = _read_points(open_state.get("nail_points", []))
	var nail_point: Vector2 = _find_nearest_gate(target.global_position, nail_points, 9999.0)
	if nail_point == Vector2.ZERO and not _get_closed_q_state().is_empty():
		nail_point = _get_closed_q_state().get("center", target.global_position)
	if nail_point != Vector2.ZERO:
		target.global_position = nail_point
		Utils.apply_status(target, "curse", 1.4, 8.0, 1, 0.7)


func _finish_executioner_dash_combo(target: Node2D, end_pos: Vector2) -> void:
	var open_state: Dictionary = _get_open_q_state()
	var points: Array[Vector2] = _read_points(open_state.get("points", []))
	var marker_pos: Vector2 = end_pos
	if points.size() >= 2:
		var projected: Dictionary = Utils.project_point_to_polyline(end_pos, points)
		marker_pos = projected.get("point", end_pos)
		target.global_position = marker_pos
	spawn_transient_ring(marker_pos, 32.0, Color(1.0, 0.26, 0.26, 0.84), 8.0, 0.18)
	if Utils.is_enemy_below_threshold(target, 0.28):
		Utils.apply_damage(target, 9999)
	else:
		Utils.apply_damage(target, max(1, int(round(_get_base_damage_value(0.65)))))


func _find_execution_target(threshold: float) -> Node2D:
	var best_low: Node2D = null
	var best_low_dist: float = 260.0
	for enemy: Node2D in Utils.get_enemies(get_tree()):
		var dist: float = skill_owner.global_position.distance_to(enemy.global_position)
		if dist > 260.0:
			continue
		if Utils.is_enemy_below_threshold(enemy, threshold) and dist < best_low_dist:
			best_low = enemy
			best_low_dist = dist
	if best_low != null:
		return best_low
	return Utils.find_nearest_enemy(get_tree(), skill_owner.global_position, 260.0)


func _gain_guard_stacks(stacks: int) -> void:
	if not is_instance_valid(skill_owner):
		return
	if "armor" in skill_owner and "max_armor" in skill_owner:
		var next_armor: int = min(int(skill_owner.get("max_armor")), int(skill_owner.get("armor")) + max(1, stacks))
		skill_owner.set("armor", next_armor)


func _nearest_of_two(origin: Vector2, points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]
	return points[0] if origin.distance_to(points[0]) <= origin.distance_to(points[1]) else points[1]


func _find_nearest_gate(origin: Vector2, points: Array[Vector2], radius: float) -> Vector2:
	var best_point: Vector2 = Vector2.ZERO
	var best_dist: float = radius
	for point: Vector2 in points:
		var dist: float = origin.distance_to(point)
		if dist > best_dist:
			continue
		best_dist = dist
		best_point = point
	return best_point


func _read_points(raw_points: Variant) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if raw_points is PackedVector2Array:
		for point: Vector2 in raw_points:
			points.append(point)
		return points
	if raw_points is Array:
		for point_var: Variant in raw_points:
			if point_var is Vector2:
				points.append(point_var)
	return points


func _read_polygon(raw_polygon: Variant) -> PackedVector2Array:
	if raw_polygon is PackedVector2Array:
		return raw_polygon
	var polygon: PackedVector2Array = PackedVector2Array()
	if raw_polygon is Array:
		for point_var: Variant in raw_polygon:
			if point_var is Vector2:
				polygon.append(point_var)
	return polygon
