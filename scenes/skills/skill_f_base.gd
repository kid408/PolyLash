extends SkillUltimate
class_name SkillFBase

const MIN_TICK_INTERVAL: float = 0.25

var _tick_accum: float = 0.0
var _line_event_count: int = 0
var _closure_event_count: int = 0
var _tick_event_count: int = 0
var _diva_mines: Array = []
var _turret_pylons: Array = []
var _chronomancer_pools: Array = []
var _signature_pickups: Array = []

func _on_ultimate_activated() -> void:
	_tick_accum = 0.0
	_line_event_count = 0
	_closure_event_count = 0
	_tick_event_count = 0
	_clear_signature_nodes()
	_sync_pickup_runtime_count()
	_publish_f_packet("activate", _build_phase_packet("activate", _resolve_runtime_center(), _resolve_runtime_radius()))

func _on_ultimate_deactivated() -> void:
	_tick_accum = 0.0
	_clear_signature_nodes()
	_sync_pickup_runtime_count()
	_publish_f_packet("deactivate", _build_phase_packet("deactivate", _resolve_runtime_center(), _resolve_runtime_radius()))

func _on_ultimate_update(delta: float) -> void:
	var tick_interval: float = max(MIN_TICK_INTERVAL, f_internal_cd)
	_tick_accum += max(0.0, delta)
	while _tick_accum >= tick_interval:
		_tick_accum -= tick_interval
		_tick_event_count += 1
		var packet := _build_phase_packet("tick", _resolve_runtime_center(), _resolve_runtime_radius())
		_apply_mode_signature("tick", packet, packet.get("center", Vector2.ZERO), 0)
		_publish_f_packet("tick", packet)
	_update_signature_pickups(delta)

func on_q_path_executed(is_closed: bool, segment_count: int, polygon_count: int) -> void:
	if not is_active:
		return

	var q_ctx := _resolve_recent_q_context()
	var q_center_var: Variant = q_ctx.get("center", _resolve_runtime_center())
	var center: Vector2 = q_center_var if q_center_var is Vector2 else _resolve_runtime_center()
	var radius := float(q_ctx.get("radius", _resolve_runtime_radius()))
	var phase := "closure" if is_closed else "line"
	var packet := _build_phase_packet(phase, center, radius)
	packet["segment_count"] = max(0, segment_count)
	packet["polygon_count"] = max(0, polygon_count)
	packet["is_closed"] = is_closed
	packet["q_context"] = q_ctx

	if is_closed:
		_closure_event_count += 1
	else:
		_line_event_count += 1

	_apply_mode_signature(phase, packet, center, 0)
	_apply_q_link_signature(phase, packet, center)
	_publish_f_packet(phase, packet)

func _resolve_f_role_id() -> String:
	if f_role_id.strip_edges() != "":
		return f_role_id.strip_edges().to_lower()
	if is_instance_valid(player_ref) and "player_id" in player_ref:
		return str(player_ref.get("player_id")).strip_edges().to_lower()
	return ult_id.trim_suffix("_ult").strip_edges().to_lower()

func _apply_mode_signature(_phase: String, _packet: Dictionary, _center: Vector2, _hit_count: int) -> void:
	pass

func _apply_q_link_signature(_phase: String, _packet: Dictionary, _center: Vector2) -> void:
	pass

func _resolve_recent_q_context(max_age_msec: int = 6000) -> Dictionary:
	return SkillContextBridge.get_q_context(player_ref, max_age_msec)

func get_q_skill() -> Node:
	if not is_instance_valid(player_ref):
		return null
	var skill_manager: Node = player_ref.get_node_or_null("SkillManager")
	if skill_manager == null or not is_instance_valid(skill_manager):
		return null
	if not skill_manager.has_method("get_skill"):
		return null
	var q_skill_var: Variant = skill_manager.call("get_skill", "q")
	if q_skill_var is Node:
		return q_skill_var as Node
	return null

func _resolve_recent_q_asset(kind_filter: String = "", max_age_msec: int = 6000) -> Dictionary:
	return SkillContextBridge.get_recent_q_asset(player_ref, kind_filter, max_age_msec)

func _resolve_recent_e_context(max_age_msec: int = 4000) -> Dictionary:
	return SkillContextBridge.get_e_context(player_ref, max_age_msec)

func _resolve_recent_e_asset(kind_filter: String = "", max_age_msec: int = 0) -> Dictionary:
	return SkillContextBridge.get_recent_e_asset(player_ref, kind_filter, max_age_msec)

func _is_e_window_active(asset_kind: String, legacy_meta_key: String = "", max_age_msec: int = 0) -> bool:
	var asset := _resolve_recent_e_asset(asset_kind, max_age_msec)
	if not asset.is_empty():
		return true
	if legacy_meta_key.strip_edges().is_empty():
		return false
	if not is_instance_valid(player_ref) or not player_ref.has_meta(legacy_meta_key):
		return false
	var expire_msec: int = int(player_ref.get_meta(legacy_meta_key))
	return Time.get_ticks_msec() <= expire_msec

func _build_phase_packet(phase: String, center: Vector2, radius: float) -> Dictionary:
	return {
		"phase": phase,
		"center": center,
		"radius": max(60.0, radius),
		"f_role_id": _resolve_f_role_id(),
		"line_events": _line_event_count,
		"closure_events": _closure_event_count,
		"tick_events": _tick_event_count,
	}

func _publish_f_packet(phase: String, packet: Dictionary) -> void:
	var payload := packet.duplicate(true)
	payload["phase"] = phase
	var center_var: Variant = packet.get("center", _resolve_runtime_center())
	var center: Vector2 = center_var if center_var is Vector2 else _resolve_runtime_center()
	var semantic_packet := SkillContextBridge.build_packet(
		player_ref,
		"f",
		ult_id,
		"f_%s" % phase,
		center,
		float(packet.get("radius", _resolve_runtime_radius())),
		payload,
		{
			"line_events": _line_event_count,
			"closure_events": _closure_event_count,
			"tick_events": _tick_event_count,
		},
		["f", _resolve_f_role_id()]
	)
	SkillContextBridge.publish_f_context(player_ref, semantic_packet)
	update_runtime_profile({
		"f_role_id": _resolve_f_role_id(),
		"line_events": _line_event_count,
		"closure_events": _closure_event_count,
		"tick_events": _tick_event_count,
	})

func _resolve_runtime_center() -> Vector2:
	var q_ctx := _resolve_recent_q_context()
	var center_var: Variant = q_ctx.get("center", Vector2.ZERO)
	if center_var is Vector2:
		return center_var
	var player_node := player_ref as Node2D
	if player_node != null:
		return player_node.global_position
	return Vector2.ZERO

func _resolve_runtime_radius() -> float:
	var q_ctx := _resolve_recent_q_context()
	if not q_ctx.is_empty():
		return max(60.0, float(q_ctx.get("radius", 120.0)))
	if f_special_value_2 > 0.0:
		return max(60.0, f_special_value_2)
	return 140.0

func _get_player_node() -> Node2D:
	return player_ref as Node2D

func _get_player_aim_direction() -> Vector2:
	var player_node := _get_player_node()
	if player_node == null:
		return Vector2.RIGHT
	var dir := player_node.get_global_mouse_position() - player_node.global_position
	if dir.length_squared() <= 0.01:
		return Vector2.RIGHT
	return dir.normalized()

func _get_player_base_damage() -> float:
	if is_instance_valid(player_ref) and "damage" in player_ref:
		return max(12.0, float(player_ref.get("damage")))
	return 12.0

func _get_enemies_in_radius(center: Vector2, radius: float) -> Array:
	var enemies: Array = []
	var tree := get_tree()
	if tree == null:
		return enemies
	for enemy_obj in tree.get_nodes_in_group("enemies"):
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy := enemy_obj as Node2D
		if center.distance_to(enemy.global_position) <= radius:
			enemies.append(enemy)
	return enemies

func _sort_enemies_by_distance(enemies: Array, center: Vector2) -> Array:
	var sorted := enemies.duplicate()
	sorted.sort_custom(func(a, b):
		var enemy_a := a as Node2D
		var enemy_b := b as Node2D
		if enemy_a == null:
			return false
		if enemy_b == null:
			return true
		return enemy_a.global_position.distance_to(center) < enemy_b.global_position.distance_to(center)
	)
	return sorted

func _damage_enemy(enemy: Node, amount: float, text: String = "", text_color: Color = Color(1.0, 0.85, 0.2)) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_node("HealthComponent"):
		var health_component: Node = enemy.get_node("HealthComponent")
		if health_component != null and health_component.has_method("take_damage"):
			health_component.call("take_damage", max(1.0, amount))
	if text != "" and enemy is Node2D:
		Global.spawn_floating_text((enemy as Node2D).global_position, text, text_color)

func _apply_enemy_status(enemy: Node, status: String, duration: float, value: float, stacks: int = 1, tick_interval: float = 0.6) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_status"):
		enemy.call("apply_status", status, max(0.1, duration), value, max(1, stacks), max(0.05, tick_interval))

func _is_enemy_below_threshold(enemy: Node, threshold: float) -> bool:
	if not is_instance_valid(enemy) or not enemy.has_node("HealthComponent"):
		return false
	var health_component: Node = enemy.get_node("HealthComponent")
	if health_component == null:
		return false
	if not ("max_health" in health_component and "current_health" in health_component):
		return false
	var max_health := float(health_component.get("max_health"))
	if max_health <= 0.0:
		return false
	return float(health_component.get("current_health")) <= max_health * max(0.0, threshold)

func _pull_enemy(enemy: Node, center: Vector2, distance: float) -> void:
	if not is_instance_valid(enemy) or not (enemy is Node2D):
		return
	var enemy_node := enemy as Node2D
	var diff := center - enemy_node.global_position
	if diff.length_squared() <= 1.0:
		return
	enemy_node.global_position += diff.normalized() * distance

func _knock_enemy(enemy: Node, center: Vector2, power: float) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("apply_knockback") and enemy is Node2D:
		var enemy_node := enemy as Node2D
		enemy.call("apply_knockback", center.direction_to(enemy_node.global_position), power)
		return
	if enemy is Node2D:
		var enemy_node2 := enemy as Node2D
		enemy_node2.global_position += center.direction_to(enemy_node2.global_position) * power * 0.02

func _gain_energy(amount: float) -> void:
	if amount <= 0.0:
		return
	if is_instance_valid(player_ref) and player_ref.has_method("gain_energy"):
		player_ref.call("gain_energy", amount)

func _heal_player(amount: float) -> void:
	if amount <= 0.0 or not is_instance_valid(player_ref) or not player_ref.has_node("HealthComponent"):
		return
	var health_component: Node = player_ref.get_node("HealthComponent")
	if health_component != null and health_component.has_method("heal"):
		health_component.call("heal", amount)

func _consume_player_health(amount: float) -> void:
	if amount <= 0.0 or not is_instance_valid(player_ref) or not player_ref.has_node("HealthComponent"):
		return
	var health_component: Node = player_ref.get_node("HealthComponent")
	if health_component != null and health_component.has_method("take_damage"):
		health_component.call("take_damage", amount)

func _add_player_armor(value: int) -> void:
	if value <= 0 or not is_instance_valid(player_ref):
		return
	if not ("armor" in player_ref and "max_armor" in player_ref):
		return
	var before := int(player_ref.get("armor"))
	var after: int = min(int(player_ref.get("max_armor")), before + value)
	if after <= before:
		return
	player_ref.set("armor", after)
	if player_ref.has_signal("armor_changed"):
		player_ref.emit_signal("armor_changed", after)

func _drop_coins(count: int) -> void:
	if count <= 0 or not is_instance_valid(player_ref) or not Global.has_method("spawn_coin"):
		return
	var player_node := _get_player_node()
	if player_node == null:
		return
	for _i in range(count):
		var offset := Vector2(randf_range(-70.0, 70.0), randf_range(-70.0, 70.0))
		Global.spawn_coin(player_node.global_position + offset, 1)

func _drop_coins_at(center: Vector2, count: int) -> void:
	if count <= 0 or not Global.has_method("spawn_coin"):
		return
	for _i in range(count):
		var offset := Vector2(randf_range(-45.0, 45.0), randf_range(-45.0, 45.0))
		Global.spawn_coin(center + offset, 1)

func _apply_temp_attack_boost(duration: float, bonus: float) -> void:
	_apply_temp_meta_delta("attack_boost", bonus, duration)

func _apply_temp_meta_delta(meta_key: String, delta: float, duration: float) -> void:
	if meta_key.strip_edges() == "" or absf(delta) <= 0.0001 or duration <= 0.0:
		return
	if not is_instance_valid(player_ref):
		return
	var current: float = float(player_ref.get_meta(meta_key, 0.0)) if player_ref.has_meta(meta_key) else 0.0
	player_ref.set_meta(meta_key, current + delta)
	get_tree().create_timer(duration).timeout.connect(
		_on_temp_meta_delta_timeout.bind(meta_key, delta),
		CONNECT_ONE_SHOT
	)

func _on_temp_meta_delta_timeout(meta_key: String, delta: float) -> void:
	if not is_instance_valid(player_ref) or not player_ref.has_meta(meta_key):
		return
	var current := float(player_ref.get_meta(meta_key))
	var next := current - delta
	if absf(next) <= 0.0001:
		player_ref.remove_meta(meta_key)
	else:
		player_ref.set_meta(meta_key, next)

func _apply_status_burst(center: Vector2, radius: float, max_targets: int, status: String, duration: float, value: float) -> int:
	var hit_count := 0
	for enemy in _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center):
		if hit_count >= max_targets:
			break
		_apply_enemy_status(enemy, status, duration, value, 1, 0.1)
		hit_count += 1
	return hit_count

func _pull_enemies_burst(center: Vector2, radius: float, max_targets: int, distance: float) -> int:
	var hit_count := 0
	for enemy in _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center):
		if hit_count >= max_targets:
			break
		_pull_enemy(enemy, center, distance)
		hit_count += 1
	return hit_count

func _knock_enemies_burst(center: Vector2, radius: float, max_targets: int, power: float) -> int:
	var hit_count := 0
	for enemy in _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center):
		if hit_count >= max_targets:
			break
		_knock_enemy(enemy, center, power)
		hit_count += 1
	return hit_count

func _line_slice_burst(
	start: Vector2,
	finish: Vector2,
	hit_radius: float,
	damage_scale: float,
	status: String,
	status_duration: float,
	status_value: float,
	pull_to_center: bool,
	force: float
) -> int:
	var hit_count := 0
	var base_damage := _get_player_base_damage()
	var center := start.lerp(finish, 0.5)
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for enemy_obj in enemies:
		if enemy_obj == null or not is_instance_valid(enemy_obj):
			continue
		if not (enemy_obj is Node2D):
			continue
		var enemy := enemy_obj as Node2D
		var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, start, finish)
		if enemy.global_position.distance_to(closest) > hit_radius:
			continue
		if damage_scale > 0.0:
			_damage_enemy(enemy, base_damage * damage_scale)
		if not status.strip_edges().is_empty():
			_apply_enemy_status(enemy, status, status_duration, status_value, 1, 0.3)
		if force > 0.0:
			if pull_to_center:
				_pull_enemy(enemy, center, force * 0.08)
			else:
				_knock_enemy(enemy, center, force)
		hit_count += 1
	return hit_count

func _schedule_line_sweep_sequence(
	center: Vector2,
	direction: Vector2,
	length: float,
	lateral_span: float,
	repeat_count: int,
	interval: float,
	hit_radius: float,
	damage_scale: float,
	status: String,
	status_duration: float,
	status_value: float,
	pull_to_center: bool,
	force: float
) -> void:
	var total: int = max(1, repeat_count)
	var dir := direction.normalized()
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side := Vector2(-dir.y, dir.x)
	for i in range(total):
		var offset := 0.0
		if total > 1:
			offset = lerp(-lateral_span * 0.5, lateral_span * 0.5, float(i) / float(total - 1))
		var sweep_center := center + side * offset
		get_tree().create_timer(max(0.0, interval) * float(i)).timeout.connect(
			_on_line_sweep_timeout.bind(
				sweep_center,
				dir,
				length,
				hit_radius,
				damage_scale,
				status,
				status_duration,
				status_value,
				pull_to_center,
				force
			),
			CONNECT_ONE_SHOT
		)

func _on_line_sweep_timeout(
	center: Vector2,
	direction: Vector2,
	length: float,
	hit_radius: float,
	damage_scale: float,
	status: String,
	status_duration: float,
	status_value: float,
	pull_to_center: bool,
	force: float
) -> void:
	var half_len: float = max(10.0, length * 0.5)
	var start: Vector2 = center - direction * half_len
	var finish: Vector2 = center + direction * half_len
	_line_slice_burst(start, finish, hit_radius, damage_scale, status, status_duration, status_value, pull_to_center, force)

func _spawn_parallel_wall_pair(
	center: Vector2,
	direction: Vector2,
	length: float,
	gap: float,
	duration: float,
	contact_damage: int,
	color: Color
) -> void:
	var dir := direction.normalized()
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	var side := Vector2(-dir.y, dir.x)
	var half_len: float = max(12.0, length * 0.5)
	for sign in [-1.0, 1.0]:
		var offset_center: Vector2 = center + side * gap * 0.5 * sign
		SkillEffectManager.create_wall_effect({
			"start": offset_center - dir * half_len,
			"end": offset_center + dir * half_len,
			"width": 12.0,
			"duration": max(0.1, duration),
			"block_enemies": true,
			"block_bullets": false,
			"contact_damage": max(0, contact_damage),
			"contact_interval": 0.24,
			"color": color,
		})

func _spawn_ignis_patch(center: Vector2, radius: float, duration: float, damage_scale: float) -> void:
	var polygon := _build_circle_polygon(center, radius, 16)
	var damage: int = max(1, int(round(_get_player_base_damage() * max(0.0, damage_scale))))
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": damage,
		"damage_interval": 0.35,
		"duration": max(0.1, duration),
		"color": Color(1.0, 0.38, 0.12, 0.32),
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": max(0.1, duration),
		"debuff_type": "burn",
		"debuff_value": max(1.0, float(damage) * 0.35),
		"debuff_duration": 1.4,
		"tick_interval": 0.45,
		"color": Color(1.0, 0.45, 0.16, 0.18),
	})

func _spawn_bulwark_ring_walls(
	center: Vector2,
	radius: float,
	duration: float,
	segment_count: int,
	contact_damage: int,
	contact_interval: float,
	block_bullets: bool
) -> void:
	var points := _build_circle_polygon(center, radius, max(6, segment_count))
	if points.size() < 3:
		return
	for i in range(points.size()):
		var start := points[i]
		var finish := points[(i + 1) % points.size()]
		SkillEffectManager.create_wall_effect({
			"start": start,
			"end": finish,
			"width": 10.0,
			"duration": max(0.1, duration),
			"block_enemies": true,
			"block_bullets": block_bullets,
			"contact_damage": max(0, contact_damage),
			"contact_interval": max(0.05, contact_interval),
			"color": Color(0.65, 0.92, 1.0, 0.74),
		})

func _spawn_bulwark_core_zone(center: Vector2, radius: float, duration: float, damage: int, slow_value: float) -> void:
	var polygon := _build_circle_polygon(center, radius, 16)
	SkillEffectManager.create_area_effect({
		"polygon": polygon,
		"damage": max(0, damage),
		"damage_interval": 0.28,
		"duration": max(0.1, duration),
		"color": Color(0.58, 0.88, 1.0, 0.24),
	})
	SkillEffectManager.create_debuff_zone({
		"polygon": polygon,
		"duration": max(0.1, duration),
		"debuff_type": "slow",
		"debuff_value": slow_value,
		"debuff_duration": 1.0,
		"tick_interval": 0.35,
		"color": Color(0.52, 0.85, 1.0, 0.16),
	})

func _signature_gunslinger(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(120.0, float(packet.get("radius", 120.0)) * 1.08)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var base_damage: float = _get_player_base_damage()
	var wave_power: float = 130.0 if phase == "line" else (190.0 if phase == "closure" else 90.0)
	var damage_scale: float = 0.36 if phase == "line" else (0.58 if phase == "closure" else 0.24)
	for enemy in _get_enemies_in_radius(center, radius):
		if is_instance_valid(enemy) and enemy is Node2D:
			var enemy_node := enemy as Node2D
			var dot_forward: float = (enemy_node.global_position - center).normalized().dot(aim_dir)
			if dot_forward < -0.25:
				continue
		_damage_enemy(enemy, base_damage * damage_scale)
		_knock_enemy(enemy, center - aim_dir * 20.0, wave_power)
		_apply_enemy_status(enemy, "marked", 1.2, 0.14, 1, 0.3)
	var speed_delta: float = 0.08 if phase == "line" else (0.12 if phase == "closure" else 0.05)
	var speed_duration: float = 1.5 if phase == "line" else (2.3 if phase == "closure" else 1.0)
	_apply_temp_meta_delta("buff_speed_boost", speed_delta, speed_duration)
	if phase == "line":
		_schedule_line_sweep_sequence(
			center + aim_dir * radius * 0.22,
			aim_dir,
			radius * 1.5,
			34.0,
			2,
			0.10,
			16.0,
			0.24,
			"marked",
			1.0,
			0.18,
			false,
			180.0
		)
	elif phase == "closure":
		_spawn_parallel_wall_pair(
			center + aim_dir * radius * 0.16,
			aim_dir,
			radius * 1.35,
			60.0,
			1.5,
			int(max(1.0, base_damage * 0.14)),
			Color(1.0, 0.88, 0.45, 0.72)
		)
		_schedule_line_sweep_sequence(
			center + aim_dir * radius * 0.24,
			aim_dir,
			radius * 1.6,
			46.0,
			3,
			0.09,
			17.0,
			0.30,
			"marked",
			1.1,
			0.20,
			false,
			220.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-aim_dir.y, aim_dir.x),
			radius * 1.3,
			36.0,
			2,
			0.12,
			15.0,
			0.22,
			"slow",
			0.9,
			0.22,
			true,
			140.0
		)

func _signature_demolitionist(phase: String, packet: Dictionary, center: Vector2) -> void:
	if not is_instance_valid(player_ref):
		return
	var radius: float = max(100.0, float(packet.get("radius", 120.0)) * 1.00)
	var base_damage: float = _get_player_base_damage()
	var streak: int = 0
	if player_ref.has_meta("demolitionist_jackpot_streak"):
		streak = int(player_ref.get_meta("demolitionist_jackpot_streak"))
	var roll: float = randf() - min(0.28, float(streak) * 0.08)
	var jackpot: bool = roll < 0.22
	if jackpot:
		player_ref.set_meta("demolitionist_jackpot_streak", 0)
		for enemy in _get_enemies_in_radius(center, radius * 0.75):
			_damage_enemy(enemy, base_damage * (0.74 if phase != "closure" else 1.05), "JACKPOT", Color(1.0, 0.82, 0.3))
			_apply_enemy_status(enemy, "marked", 1.6, 0.24, 1, 0.3)
		_drop_coins(2 if phase != "closure" else 4)
		_apply_temp_attack_boost(2.0 if phase != "closure" else 2.8, 0.10 if phase != "closure" else 0.16)
		return
	player_ref.set_meta("demolitionist_jackpot_streak", streak + 1)
	var safe_outcome: bool = roll < 0.72
	if safe_outcome:
		for enemy in _get_enemies_in_radius(center, radius):
			_damage_enemy(enemy, base_damage * (0.26 if phase == "tick" else (0.40 if phase == "line" else 0.54)))
			_apply_enemy_status(enemy, "marked", 1.1, 0.18, 1, 0.3)
		_gain_energy(2.0 if phase != "closure" else 3.0)
	else:
		for enemy in _get_enemies_in_radius(center, radius * 1.12):
			_apply_enemy_status(enemy, "slow", 1.2 + (0.4 if phase == "closure" else 0.0), 0.30, 1, 0.1)
			_damage_enemy(enemy, base_damage * (0.18 if phase == "tick" else 0.30))
		_consume_player_health(1.2 if phase != "closure" else 2.2)
		_gain_energy(3.2 if phase != "closure" else 4.5)
		_drop_coins(1)

func _signature_medium(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(110.0, float(packet.get("radius", 120.0)))
	var energy_gain: float = 5.0 if phase == "tick" else (8.0 if phase == "line" else 12.0)
	_gain_energy(energy_gain)
	if phase != "tick":
		var cd_delta: float = 0.08 if phase == "line" else 0.13
		var cd_duration: float = 1.6 if phase == "line" else 2.2
		_apply_temp_meta_delta("buff_cooldown_reduction", cd_delta, cd_duration)
	var damage_scale: float = 0.42 if phase == "line" else (0.66 if phase == "closure" else 0.34)
	var base_damage: float = _get_player_base_damage()
	for enemy in _get_enemies_in_radius(center, radius):
		_damage_enemy(enemy, base_damage * damage_scale)
		_apply_enemy_status(enemy, "marked", 1.1, 0.18, 1, 0.3)
	var medium_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			medium_dir,
			radius * 1.5,
			30.0,
			2,
			0.10,
			13.0,
			0.24,
			"marked",
			1.0,
			0.18,
			false,
			120.0
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			medium_dir,
			radius * 1.65,
			34.0,
			3,
			0.08,
			14.0,
			0.30,
			"marked",
			1.2,
			0.22,
			false,
			150.0
		)

func _signature_inkweaver(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(120.0, float(packet.get("radius", 120.0)) * 1.06)
	var heal_ratio: float = 0.10 if phase == "line" else (0.16 if phase == "closure" else 0.08)
	var aim_dir: Vector2 = _get_player_aim_direction()
	_heal_player(_get_player_base_damage() * heal_ratio * 4.0)
	if phase != "tick":
		_apply_temp_meta_delta("lifesteal_bonus", 0.08 if phase == "line" else 0.14, 1.8 if phase == "line" else 2.4)
	var enemies: Array = _get_enemies_in_radius(center, radius)
	var hit_count: int = 0
	for enemy in enemies:
		if hit_count >= 10:
			break
		_apply_enemy_status(enemy, "slow", 1.1 + (0.3 if phase == "closure" else 0.0), 0.24, 1, 0.1)
		if phase == "closure":
			_apply_enemy_status(enemy, "marked", 1.4, 0.16, 1, 0.3)
		hit_count += 1
	if phase == "line":
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.25,
			58.0,
			1.2,
			int(max(1.0, _get_player_base_damage() * 0.12)),
			Color(0.65, 1.0, 0.85, 0.65)
		)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.3,
			28.0,
			2,
			0.12,
			14.0,
			0.18,
			"slow",
			0.9,
			0.22,
			true,
			120.0
		)
	elif phase == "closure":
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.35,
			66.0,
			1.6,
			int(max(1.0, _get_player_base_damage() * 0.14)),
			Color(0.62, 0.95, 0.88, 0.72)
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-aim_dir.y, aim_dir.x),
			radius * 1.45,
			34.0,
			3,
			0.10,
			16.0,
			0.22,
			"slow",
			1.0,
			0.24,
			true,
			150.0
		)

func _signature_earthshaker(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(115.0, float(packet.get("radius", 120.0)) * 1.05)
	var enemies: Array = _get_enemies_in_radius(center, radius)
	var base_damage: float = _get_player_base_damage()
	var aim_dir: Vector2 = _get_player_aim_direction()
	var hit_count: int = 0
	for enemy in enemies:
		if hit_count >= 12:
			break
		if phase == "closure":
			_apply_enemy_status(enemy, "stun", 0.45, 0.0, 1, 0.1)
		else:
			_apply_enemy_status(enemy, "slow", 0.9, 0.3, 1, 0.1)
		_apply_enemy_status(enemy, "marked", 1.4, 0.16, 1, 0.3)
		if phase != "tick":
			_damage_enemy(enemy, base_damage * (0.34 if phase == "line" else 0.52))
		hit_count += 1
	if hit_count > 0:
		_add_player_armor(1 if phase != "closure" else 2)
		if phase == "closure":
			_heal_player(base_damage * 0.7)
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.3,
			0.0,
			1,
			0.08,
			16.0,
			0.24,
			"marked",
			1.0,
			0.18,
			false,
			160.0
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.45,
			44.0,
			3,
			0.09,
			16.0,
			0.30,
			"stun",
			0.22,
			0.0,
			false,
			180.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-aim_dir.y, aim_dir.x),
			radius * 1.45,
			44.0,
			3,
			0.12,
			16.0,
			0.26,
			"marked",
			1.1,
			0.20,
			true,
			150.0
		)
		_spawn_parallel_wall_pair(
			center,
			aim_dir,
			radius * 1.2,
			64.0,
			1.4,
			int(max(1.0, base_damage * 0.16)),
			Color(1.0, 0.92, 0.65, 0.70)
		)

func _signature_necromancer(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(95.0, float(packet.get("radius", 120.0)) * 0.95)
	var target: Node2D = _pick_nearest_enemy(center, radius, [])
	if target == null:
		return
	var base_damage: float = _get_player_base_damage()
	var damage_scale: float = 0.48 if phase == "line" else (0.82 if phase == "closure" else 0.36)
	var amount: float = base_damage * damage_scale
	var coin_count: int = 1 if phase != "closure" else 2
	if _is_enemy_below_threshold(target, 0.2):
		amount = base_damage * (2.6 if phase == "closure" else 1.8)
		coin_count += 1
		_damage_enemy(target, amount, "GOLD EXEC", Color(1.0, 0.82, 0.3))
	else:
		_damage_enemy(target, amount, "GILD", Color(0.95, 0.72, 0.24))
	_apply_enemy_status(target, "slow", 1.0 + (0.4 if phase == "closure" else 0.0), 0.28, 1, 0.1)
	_drop_coins_at(target.global_position, coin_count)
	var necromancer_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			necromancer_dir,
			radius * 1.4,
			30.0,
			2,
			0.10,
			14.0,
			0.24,
			"slow",
			0.9,
			0.22,
			false,
			140.0
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			necromancer_dir,
			radius * 1.55,
			36.0,
			3,
			0.09,
			15.0,
			0.30,
			"slow",
			1.1,
			0.26,
			false,
			170.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-necromancer_dir.y, necromancer_dir.x),
			radius * 1.25,
			28.0,
			2,
			0.12,
			13.0,
			0.20,
			"marked",
			1.0,
			0.16,
			true,
			110.0
		)
		_drop_coins_at(center, 1)

func _signature_frostbite(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(90.0, float(packet.get("radius", 120.0)) * 0.78)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var rune_count: int = 1
	var patch_scale: float = 0.24
	var delay_base: float = 0.20
	match phase:
		"line":
			rune_count = 2
			patch_scale = 0.30
			delay_base = 0.16
		"closure":
			rune_count = 3
			patch_scale = 0.38
			delay_base = 0.11
		_:
			rune_count = 1
			patch_scale = 0.24
			delay_base = 0.20
	for i in range(rune_count):
		var spread: float = randf_range(-0.42, 0.42)
		var dir: Vector2 = aim_dir.rotated(spread)
		var pos: Vector2 = center + dir * (56.0 + float(i) * 52.0)
		_spawn_ignis_patch(pos, radius * 0.44, 1.2 + 0.25 * float(rune_count), patch_scale)
		var delay: float = delay_base + float(i) * 0.09
		get_tree().create_timer(delay).timeout.connect(_on_frostbite_rune_timeout.bind(pos, radius * 0.58, patch_scale + 0.12))

func _signature_matrix(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(110.0, float(packet.get("radius", 120.0)) * 1.08)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var limit: int = 3 if phase == "tick" else (5 if phase == "line" else 7)
	var refs: Array = []
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_apply_enemy_status(enemy, "poison", 1.8 + (0.6 if phase == "closure" else 0.2), max(1.0, _get_player_base_damage() * 0.18), 1, 0.6)
		_apply_enemy_status(enemy, "slow", 0.9 + 0.2 * float(i), 0.28, 1, 0.1)
		if phase != "tick":
			_apply_enemy_status(enemy, "curse", 1.2, max(1.0, _get_player_base_damage() * 0.12), 1, 0.7)
		refs.append(weakref(enemy))
	if refs.is_empty():
		return
	var delay: float = 0.42 if phase != "closure" else 0.28
	var bloom_radius: float = radius * (0.28 if phase != "closure" else 0.34)
	var bloom_scale: float = 0.34 if phase != "closure" else 0.56
	get_tree().create_timer(delay).timeout.connect(_on_matrix_bloom_timeout.bind(refs, bloom_radius, bloom_scale))
	var matrix_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			matrix_dir,
			radius * 1.55,
			40.0,
			2,
			0.12,
			16.0,
			0.22,
			"poison",
			1.2,
			max(1.0, _get_player_base_damage() * 0.08),
			false,
			120.0
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			matrix_dir,
			radius * 1.65,
			48.0,
			3,
			0.10,
			17.0,
			0.26,
			"poison",
			1.4,
			max(1.0, _get_player_base_damage() * 0.10),
			false,
			160.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-matrix_dir.y, matrix_dir.x),
			radius * 1.45,
			36.0,
			2,
			0.14,
			15.0,
			0.22,
			"curse",
			1.0,
			max(1.0, _get_player_base_damage() * 0.08),
			true,
			120.0
		)

func _signature_warden(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(100.0, float(packet.get("radius", 120.0)) * 1.02)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	var limit: int = 4 if phase == "tick" else (7 if phase == "line" else 10)
	var verdict_refs: Array = []
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_pull_enemy(enemy, center, 10.0 + (8.0 if phase == "closure" else 3.0))
		if phase == "closure":
			_apply_enemy_status(enemy, "stun", 0.52, 0.0, 1, 0.1)
			if _is_enemy_below_threshold(enemy, 0.24):
				_damage_enemy(enemy, base_damage * 2.0, "VERDICT", Color(1.0, 0.5, 0.45))
			else:
				_damage_enemy(enemy, base_damage * 0.60)
		else:
			_apply_enemy_status(enemy, "slow", 1.0 + 0.15 * float(i), 0.34, 1, 0.1)
			_damage_enemy(enemy, base_damage * (0.30 if phase == "line" else 0.20))
			if phase == "line" and i < 3:
				verdict_refs.append(weakref(enemy))
	if phase == "line" and not verdict_refs.is_empty():
		get_tree().create_timer(0.24).timeout.connect(_on_warden_verdict_timeout.bind(verdict_refs, 0.48))
	var warden_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			warden_dir,
			radius * 1.35,
			32.0,
			2,
			0.11,
			15.0,
			0.20,
			"slow",
			0.9,
			0.26,
			true,
			130.0
		)
	elif phase == "closure":
		_spawn_parallel_wall_pair(
			center,
			warden_dir,
			radius * 1.2,
			56.0,
			1.3,
			int(max(1.0, base_damage * 0.12)),
			Color(0.95, 0.72, 0.62, 0.66)
		)
		_schedule_line_sweep_sequence(
			center,
			warden_dir,
			radius * 1.45,
			36.0,
			3,
			0.10,
			16.0,
			0.26,
			"stun",
			0.22,
			0.0,
			true,
			160.0
		)

func _signature_snareweaver(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(110.0, float(packet.get("radius", 120.0)) * 1.12)
	var core_count: int = 1 if phase == "tick" else (2 if phase == "line" else 3)
	var pull_force: float = 12.0 if phase == "tick" else (18.0 if phase == "line" else 24.0)
	var damage_scale: float = 0.28 if phase == "tick" else (0.40 if phase == "line" else 0.56)
	var base_damage: float = _get_player_base_damage()
	for i in range(core_count):
		var angle: float = TAU * float(i) / float(core_count) + (0.18 if phase == "closure" else 0.0)
		var core_pos: Vector2 = center + Vector2.RIGHT.rotated(angle) * radius * (0.34 + 0.06 * float(i % 2))
		for enemy in _get_enemies_in_radius(core_pos, radius * 0.54):
			_pull_enemy(enemy, core_pos, pull_force)
			_damage_enemy(enemy, base_damage * damage_scale)
			_apply_enemy_status(enemy, "slow", 1.1 + (0.3 if phase == "closure" else 0.0), 0.30, 1, 0.1)
	if phase != "tick":
		_apply_temp_meta_delta("buff_speed_boost", 0.08 if phase == "line" else 0.13, 1.6 if phase == "line" else 2.3)
	var snareweaver_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			snareweaver_dir,
			radius * 1.55,
			36.0,
			2,
			0.10,
			16.0,
			0.22,
			"slow",
			1.0,
			0.24,
			true,
			160.0
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			snareweaver_dir,
			radius * 1.7,
			40.0,
			3,
			0.09,
			17.0,
			0.28,
			"slow",
			1.2,
			0.28,
			true,
			200.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-snareweaver_dir.y, snareweaver_dir.x),
			radius * 1.45,
			34.0,
			2,
			0.13,
			15.0,
			0.22,
			"slow",
			1.0,
			0.24,
			true,
			150.0
		)

func _signature_astrologer(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(95.0, float(packet.get("radius", 120.0)) * 0.96)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	var limit: int = 2 if phase == "tick" else (4 if phase == "line" else 6)
	var self_cost: float = 1.2 if phase == "tick" else (2.0 if phase == "line" else 3.2)
	var heal_scale: float = 0.10 if phase == "tick" else (0.14 if phase == "line" else 0.22)
	_consume_player_health(self_cost)
	var drained: int = 0
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_apply_enemy_status(enemy, "curse", 1.6 + (0.5 if phase == "closure" else 0.2), max(1.0, base_damage * 0.18), 1, 0.6)
		_damage_enemy(enemy, base_damage * (0.34 if phase == "tick" else (0.48 if phase == "line" else 0.72)))
		if phase == "closure" and _is_enemy_below_threshold(enemy, 0.28):
			_damage_enemy(enemy, base_damage * 1.9, "FEAST", Color(1.0, 0.2, 0.2))
		drained += 1
	if drained > 0:
		_heal_player(base_damage * heal_scale * float(drained))
	var astrologer_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			astrologer_dir,
			radius * 1.35,
			30.0,
			2,
			0.11,
			14.0,
			0.22,
			"curse",
			1.0,
			max(1.0, base_damage * 0.08),
			true,
			130.0
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			astrologer_dir,
			radius * 1.5,
			34.0,
			3,
			0.10,
			15.0,
			0.28,
			"curse",
			1.3,
			max(1.0, base_damage * 0.10),
			true,
			160.0
		)

func _signature_polaris(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(120.0, float(packet.get("radius", 120.0)) * 1.18)
	var lane_len: float = radius * (0.95 if phase == "tick" else 1.14)
	var half_width: float = radius * (0.24 if phase == "tick" else 0.30)
	var aim_dir: Vector2 = _get_player_aim_direction()
	var base_damage: float = _get_player_base_damage()
	var first_scale: float = 0.34 if phase == "tick" else (0.52 if phase == "line" else 0.82)
	var knock_power: float = 120.0 if phase == "tick" else (190.0 if phase == "line" else 280.0)
	for enemy in _get_enemies_in_radius(center, lane_len):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var rel: Vector2 = enemy_node.global_position - center
		var forward: float = rel.dot(aim_dir)
		if forward < -20.0 or forward > lane_len:
			continue
		var side: float = absf(rel.dot(aim_dir.orthogonal()))
		if side > half_width:
			continue
		_damage_enemy(enemy, base_damage * first_scale, "RAIL", Color(1.0, 0.82, 0.35))
		_knock_enemy(enemy, center - aim_dir * 45.0, knock_power)
		_apply_enemy_status(enemy, "slow", 0.9 + (0.4 if phase == "closure" else 0.1), 0.30, 1, 0.1)
	if phase != "tick":
		var delay: float = 0.22 if phase == "line" else 0.15
		var second_scale: float = 0.40 if phase == "line" else 0.72
		get_tree().create_timer(delay).timeout.connect(_on_polaris_aftershock_timeout.bind(center, aim_dir, lane_len, half_width * 1.16, second_scale))
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			lane_len * 1.1,
			36.0,
			2,
			0.09,
			16.0,
			0.24,
			"slow",
			1.0,
			0.24,
			false,
			200.0
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			lane_len * 1.2,
			42.0,
			3,
			0.08,
			17.0,
			0.30,
			"slow",
			1.2,
			0.28,
			false,
			240.0
		)

func _signature_plague(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(100.0, float(packet.get("radius", 120.0)) * 1.02)
	var pulse_count: int = 1 if phase == "tick" else (2 if phase == "line" else 3)
	var pulse_scale: float = 0.26 if phase == "tick" else (0.40 if phase == "line" else 0.58)
	var aim_dir: Vector2 = _get_player_aim_direction()
	for i in range(pulse_count):
		var ratio: float = 0.5 if pulse_count <= 1 else float(i) / float(pulse_count - 1)
		var angle: float = lerp(-0.85, 0.85, ratio)
		var dir: Vector2 = aim_dir.rotated(angle)
		var pos: Vector2 = center + dir * (54.0 + 24.0 * float(i))
		var delay: float = 0.11 * float(i)
		get_tree().create_timer(delay).timeout.connect(_on_plague_pulse_timeout.bind(pos, radius * 0.52, pulse_scale + 0.08 * float(i), phase == "closure"))
	if phase != "tick":
		_gain_energy(2.0 if phase == "line" else 3.5)
	var totem_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			totem_dir,
			radius * 1.35,
			30.0,
			2,
			0.11,
			14.0,
			0.20,
			"marked",
			1.0,
			0.16,
			true,
			120.0
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			totem_dir,
			radius * 1.5,
			34.0,
			3,
			0.10,
			15.0,
			0.26,
			"marked",
			1.2,
			0.20,
			true,
			150.0
		)

func _signature_chronomancer(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(96.0, float(packet.get("radius", 120.0)) * 1.06)
	var pool_count: int = 1 if phase == "tick" else (2 if phase == "line" else 3)
	var duration: float = 1.6 if phase == "tick" else (2.3 if phase == "line" else 3.0)
	var scale: float = 0.22 if phase == "tick" else (0.32 if phase == "line" else 0.46)
	var split_count: int = 0 if phase != "closure" else 1
	var aim_dir: Vector2 = _get_player_aim_direction()
	for i in range(pool_count):
		var angle: float = randf_range(0.0, TAU)
		var offset_len: float = radius * (0.18 + 0.26 * randf())
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * offset_len
		_spawn_chronomancer_pool(pos, radius * (0.30 + 0.06 * float(i)), duration, scale, split_count)
	if phase == "line":
		for step in range(3):
			var t: float = float(step) / 2.0
			var trail_pos: Vector2 = center + aim_dir * radius * (0.25 + 0.55 * t)
			_spawn_chronomancer_pool(trail_pos, radius * (0.22 + 0.05 * float(step)), 1.7, 0.26, 0)
	elif phase == "closure":
		for step in range(4):
			var t2: float = float(step) / 3.0
			var front: Vector2 = center + aim_dir * radius * (0.20 + 0.70 * t2)
			var back: Vector2 = center - aim_dir * radius * (0.20 + 0.45 * t2)
			_spawn_chronomancer_pool(front, radius * (0.24 + 0.05 * float(step)), 2.1, 0.30, 1 if step >= 2 else 0)
			if step <= 2:
				_spawn_chronomancer_pool(back, radius * (0.20 + 0.04 * float(step)), 1.8, 0.24, 0)
		_schedule_line_sweep_sequence(
			center,
			aim_dir,
			radius * 1.55,
			34.0,
			3,
			0.10,
			18.0,
			0.22,
			"poison",
			1.2,
			max(1.0, _get_player_base_damage() * 0.08),
			false,
			110.0
		)

func _signature_viper(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(105.0, float(packet.get("radius", 120.0)) * 1.04)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var limit: int = 2 if phase == "tick" else (4 if phase == "line" else 6)
	var base_damage: float = _get_player_base_damage()
	var shot_scale: float = 0.32 if phase == "tick" else (0.50 if phase == "line" else 0.72)
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		_apply_enemy_status(enemy, "marked", 1.1 + (0.4 if phase == "closure" else 0.1), 0.20, 1, 0.3)
		_damage_enemy(enemy, base_damage * 0.24)
		var mirror_dir: Vector2 = (center - enemy_node.global_position).normalized()
		var mirror_pos: Vector2 = center + mirror_dir * min(radius * 0.45, 92.0)
		var delay: float = 0.16 + 0.04 * float(i)
		get_tree().create_timer(delay).timeout.connect(_on_viper_mirror_timeout.bind(weakref(enemy), mirror_pos, shot_scale))
	var illusion_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			illusion_dir,
			radius * 1.35,
			30.0,
			2,
			0.12,
			13.0,
			0.18,
			"marked",
			0.9,
			0.16,
			false,
			100.0
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			illusion_dir,
			radius * 1.45,
			34.0,
			3,
			0.09,
			14.0,
			0.24,
			"marked",
			1.1,
			0.20,
			false,
			130.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-illusion_dir.y, illusion_dir.x),
			radius * 1.25,
			26.0,
			2,
			0.13,
			12.0,
			0.18,
			"slow",
			0.8,
			0.20,
			true,
			100.0
		)

func _signature_leviathan(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(105.0, float(packet.get("radius", 120.0)) * 1.00)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var refs: Array = []
	var limit: int = 2 if phase == "tick" else (4 if phase == "line" else 5)
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_apply_enemy_status(enemy, "curse", 1.8 + (0.4 if phase == "closure" else 0.0), max(1.0, _get_player_base_damage() * 0.16), 1, 0.7)
		_apply_enemy_status(enemy, "marked", 1.0, 0.16, 1, 0.3)
		refs.append(weakref(enemy))
	if refs.is_empty():
		return
	var delay: float = 0.38 if phase != "closure" else 0.24
	var link_scale: float = 0.30 if phase != "closure" else 0.52
	get_tree().create_timer(delay).timeout.connect(_on_leviathan_link_timeout.bind(refs, center, link_scale))
	var leviathan_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			leviathan_dir,
			radius * 1.4,
			30.0,
			2,
			0.12,
			14.0,
			0.22,
			"curse",
			1.1,
			max(1.0, _get_player_base_damage() * 0.08),
			true,
			120.0
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			leviathan_dir,
			radius * 1.55,
			36.0,
			3,
			0.10,
			15.0,
			0.28,
			"curse",
			1.3,
			max(1.0, _get_player_base_damage() * 0.10),
			true,
			150.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-leviathan_dir.y, leviathan_dir.x),
			radius * 1.3,
			28.0,
			2,
			0.14,
			14.0,
			0.22,
			"marked",
			1.0,
			0.18,
			true,
			110.0
		)

func _signature_pathfinder(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(100.0, float(packet.get("radius", 120.0)) * 0.98)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	var limit: int = 3 if phase == "tick" else (6 if phase == "line" else 8)
	var coin_total: int = 0
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		_apply_enemy_status(enemy, "marked", 1.2 + (0.3 if phase == "closure" else 0.0), 0.18, 1, 0.3)
		_damage_enemy(enemy, base_damage * (0.22 if phase == "tick" else (0.34 if phase == "line" else 0.50)))
		if _is_enemy_below_threshold(enemy, 0.30 if phase == "closure" else 0.22):
			if enemy is Node2D:
				_drop_coins_at((enemy as Node2D).global_position, 1)
			coin_total += 1
	if phase != "tick":
		_apply_temp_meta_delta("buff_speed_boost", 0.06 if phase == "line" else 0.12, 1.6 if phase == "line" else 2.4)
		_gain_energy(1.6 if phase == "line" else 2.6)
	if phase == "closure" and coin_total >= 3:
		_drop_coins(1)
	var pathfinder_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			pathfinder_dir,
			radius * 1.45,
			34.0,
			2,
			0.11,
			14.0,
			0.18,
			"marked",
			1.0,
			0.16,
			false,
			100.0
		)
	elif phase == "closure":
		_spawn_parallel_wall_pair(
			center,
			pathfinder_dir,
			radius * 1.25,
			52.0,
			1.3,
			int(max(1.0, base_damage * 0.10)),
			Color(0.95, 0.78, 0.35, 0.68)
		)
		_schedule_line_sweep_sequence(
			center,
			pathfinder_dir,
			radius * 1.55,
			38.0,
			3,
			0.09,
			15.0,
			0.22,
			"marked",
			1.1,
			0.18,
			false,
			130.0
		)
		if coin_total >= 2:
			_drop_coins_at(center, 1)

func _signature_beastmaster(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(130.0, float(packet.get("radius", 120.0)) * 1.20)
	var pull_force: float = 12.0 if phase == "tick" else (18.0 if phase == "line" else 28.0)
	var base_damage: float = _get_player_base_damage()
	for enemy in _get_enemies_in_radius(center, radius):
		_pull_enemy(enemy, center, pull_force)
		_apply_enemy_status(enemy, "slow", 0.9 + (0.4 if phase == "closure" else 0.1), 0.30, 1, 0.1)
		if phase == "closure":
			_damage_enemy(enemy, base_damage * 0.46)
	if phase != "tick":
		var delay: float = 0.22 if phase == "line" else 0.16
		var implode_scale: float = 0.44 if phase == "line" else 0.72
		get_tree().create_timer(delay).timeout.connect(_on_beastmaster_implode_timeout.bind(center, radius * 0.56, implode_scale))
	var beastmaster_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			beastmaster_dir,
			radius * 1.6,
			40.0,
			2,
			0.10,
			18.0,
			0.20,
			"slow",
			1.0,
			0.24,
			true,
			180.0
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			beastmaster_dir,
			radius * 1.75,
			46.0,
			3,
			0.08,
			20.0,
			0.24,
			"slow",
			1.2,
			0.28,
			true,
			240.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-beastmaster_dir.y, beastmaster_dir.x),
			radius * 1.55,
			38.0,
			2,
			0.12,
			18.0,
			0.20,
			"slow",
			1.0,
			0.24,
			true,
			180.0
		)

func _signature_bloodhowl(phase: String, packet: Dictionary, center: Vector2) -> void:
	var radius: float = max(95.0, float(packet.get("radius", 120.0)) * 0.90)
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if targets.is_empty():
		return
	var base_damage: float = _get_player_base_damage()
	var threshold: float = 0.26 if phase == "tick" else (0.32 if phase == "line" else 0.40)
	var limit: int = 3 if phase == "tick" else (5 if phase == "line" else 7)
	var execute_count: int = 0
	for i in range(min(limit, targets.size())):
		var enemy: Node = targets[i]
		if _is_enemy_below_threshold(enemy, threshold):
			_damage_enemy(enemy, base_damage * (1.6 if phase == "tick" else (2.2 if phase == "line" else 3.2)), "EXEC", Color(1.0, 0.2, 0.2))
			execute_count += 1
		else:
			_damage_enemy(enemy, base_damage * (0.30 if phase == "tick" else (0.46 if phase == "line" else 0.64)))
			_apply_enemy_status(enemy, "marked", 1.3 + (0.6 if phase == "closure" else 0.0), 0.22, 1, 0.3)
			if phase == "closure":
				_apply_enemy_status(enemy, "slow", 0.9, 0.34, 1, 0.1)
	if execute_count > 0:
		_gain_energy(1.0 + float(execute_count) * 0.6)
	if phase == "closure":
		var guillotine_scale: float = 0.74 + 0.08 * float(min(3, execute_count))
		get_tree().create_timer(0.18).timeout.connect(_on_bloodhowl_guillotine_timeout.bind(center, radius * 0.58, guillotine_scale))
	var exec_dir: Vector2 = _get_player_aim_direction()
	if phase == "line":
		_schedule_line_sweep_sequence(
			center,
			exec_dir,
			radius * 1.35,
			28.0,
			2,
			0.10,
			14.0,
			0.24,
			"marked",
			1.0,
			0.20,
			false,
			140.0
		)
	elif phase == "closure":
		_schedule_line_sweep_sequence(
			center,
			exec_dir,
			radius * 1.5,
			32.0,
			3,
			0.09,
			15.0,
			0.30,
			"marked",
			1.2,
			0.24,
			false,
			170.0
		)
		_schedule_line_sweep_sequence(
			center,
			Vector2(-exec_dir.y, exec_dir.x),
			radius * 1.25,
			24.0,
			2,
			0.12,
			13.0,
			0.22,
			"slow",
			0.9,
			0.26,
			true,
			130.0
		)

func _on_frostbite_rune_timeout(center: Vector2, radius: float, damage_scale: float) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	for enemy in _get_enemies_in_radius(center, radius):
		_damage_enemy(enemy, damage, "RUNE", Color(1.0, 0.45, 0.2))
		_apply_enemy_status(enemy, "burn", 1.5, max(1.0, damage * 0.42), 1, 0.5)
		_knock_enemy(enemy, center, 90.0)

func _on_matrix_bloom_timeout(target_refs: Array, bloom_radius: float, bloom_scale: float) -> void:
	var damage: float = _get_player_base_damage() * bloom_scale
	for ref_obj in target_refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		if not (target is Node2D):
			continue
		var target_node: Node2D = target
		for enemy in _get_enemies_in_radius(target_node.global_position, bloom_radius):
			_damage_enemy(enemy, damage)
			_apply_enemy_status(enemy, "poison", 1.4, max(1.0, damage * 0.36), 1, 0.6)
			_apply_enemy_status(enemy, "slow", 0.8, 0.22, 1, 0.1)

func _on_warden_verdict_timeout(target_refs: Array, damage_scale: float) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	for ref_obj in target_refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		_damage_enemy(target, damage, "LOCK", Color(0.95, 0.7, 0.5))
		_apply_enemy_status(target, "stun", 0.34, 0.0, 1, 0.1)

func _on_polaris_aftershock_timeout(center: Vector2, aim_dir: Vector2, lane_len: float, half_width: float, damage_scale: float) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	for enemy in _get_enemies_in_radius(center, lane_len):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var rel: Vector2 = enemy_node.global_position - center
		var forward: float = rel.dot(aim_dir)
		if forward < -20.0 or forward > lane_len:
			continue
		var side: float = absf(rel.dot(aim_dir.orthogonal()))
		if side > half_width:
			continue
		_damage_enemy(enemy, damage, "AFTERSHOCK", Color(1.0, 0.88, 0.45))
		_knock_enemy(enemy, center, 170.0)

func _on_plague_pulse_timeout(center: Vector2, radius: float, damage_scale: float, apply_stun: bool) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	for enemy in _get_enemies_in_radius(center, radius):
		_damage_enemy(enemy, damage, "PULSE", Color(0.62, 0.95, 1.0))
		_apply_enemy_status(enemy, "marked", 1.2, 0.20, 1, 0.3)
		_apply_enemy_status(enemy, "slow", 0.9, 0.22, 1, 0.1)
		if apply_stun:
			_apply_enemy_status(enemy, "stun", 0.24, 0.0, 1, 0.1)

func _on_viper_mirror_timeout(target_ref: WeakRef, mirror_pos: Vector2, damage_scale: float) -> void:
	var target = target_ref.get_ref() if target_ref != null else null
	if target == null or not is_instance_valid(target):
		return
	var damage: float = _get_player_base_damage() * damage_scale
	_damage_enemy(target, damage, "MIRROR", Color(0.85, 0.65, 1.0))
	_apply_enemy_status(target, "marked", 1.3, 0.22, 1, 0.3)
	for enemy in _get_enemies_in_radius(mirror_pos, 70.0):
		if enemy == target:
			continue
		_damage_enemy(enemy, damage * 0.42)
		_apply_enemy_status(enemy, "slow", 0.8, 0.24, 1, 0.1)

func _on_leviathan_link_timeout(target_refs: Array, center: Vector2, damage_scale: float) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	var valid_targets: Array = []
	for ref_obj in target_refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		valid_targets.append(target)
	if valid_targets.is_empty():
		return
	for target in valid_targets:
		_damage_enemy(target, damage, "HEX", Color(0.78, 0.42, 1.0))
		_apply_enemy_status(target, "curse", 1.6, max(1.0, damage * 0.45), 1, 0.7)
		_pull_enemy(target, center, 8.0)

func _on_beastmaster_implode_timeout(center: Vector2, radius: float, damage_scale: float) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	for enemy in _get_enemies_in_radius(center, radius):
		_damage_enemy(enemy, damage, "IMPLODE", Color(0.7, 0.95, 1.0))
		_knock_enemy(enemy, center, 210.0)

func _on_bloodhowl_guillotine_timeout(center: Vector2, radius: float, damage_scale: float) -> void:
	var damage: float = _get_player_base_damage() * damage_scale
	var targets: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	for i in range(min(5, targets.size())):
		var enemy: Node = targets[i]
		_damage_enemy(enemy, damage, "GUILLOTINE", Color(1.0, 0.26, 0.26))
		_apply_enemy_status(enemy, "slow", 0.9, 0.30, 1, 0.1)

func _on_illusionist_reap_timeout(target_refs: Array, damage_scale: float, center: Vector2) -> void:
	var base_damage: float = _get_player_base_damage()
	for ref_obj in target_refs:
		var target = ref_obj.get_ref() if ref_obj != null else null
		if target == null or not is_instance_valid(target):
			continue
		_damage_enemy(target, base_damage * damage_scale, "REAP", Color(0.75, 0.3, 0.95))
		_pull_enemy(target, center, 10.0)
		_apply_enemy_status(target, "slow", 0.9, 0.26, 1, 0.1)

func _on_botanist_shot_timeout(target_ref: WeakRef, damage_scale: float) -> void:
	var target = target_ref.get_ref() if target_ref != null else null
	if target == null or not is_instance_valid(target):
		return
	var base_damage: float = _get_player_base_damage()
	if _is_enemy_below_threshold(target, 0.2):
		_damage_enemy(target, base_damage * max(1.6, damage_scale * 2.0), "EXECUTE", Color(1.0, 0.25, 0.25))
	else:
		_damage_enemy(target, base_damage * damage_scale, "HUNT", Color(0.75, 1.0, 0.55))

func _build_chain_targets(origin: Vector2, radius: float, max_count: int, link_range: float) -> Array:
	var result: Array = []
	var first: Node2D = _pick_nearest_enemy(origin, radius, [])
	if first == null:
		return result
	result.append(first)
	var used: Array = [first]
	var current_pos: Vector2 = first.global_position
	for _i in range(max(0, max_count - 1)):
		var next_enemy: Node2D = _pick_nearest_enemy(current_pos, link_range, used)
		if next_enemy == null:
			break
		result.append(next_enemy)
		used.append(next_enemy)
		current_pos = next_enemy.global_position
	return result

func _pick_nearest_enemy(origin: Vector2, radius: float, used: Array) -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = radius
	var enemies: Array = _get_enemies_in_radius(origin, radius)
	for enemy in enemies:
		if used.has(enemy):
			continue
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node: Node2D = enemy
		var dist: float = origin.distance_to(enemy_node.global_position)
		if dist <= nearest_dist:
			nearest = enemy_node
			nearest_dist = dist
	return nearest

func _pick_botanist_target(center: Vector2, radius: float) -> Node2D:
	var enemies: Array = _sort_enemies_by_distance(_get_enemies_in_radius(center, radius), center)
	if enemies.is_empty():
		return null
	for enemy in enemies:
		if enemy.has_method("has_status") and enemy.call("has_status", "marked"):
			return enemy
	return enemies[0]

func _spawn_turret_pylon(pos: Vector2, radius: float, duration: float, damage_scale: float) -> void:
	if _turret_pylons.size() >= 4:
		var oldest: Node = _turret_pylons[0]
		if is_instance_valid(oldest):
			oldest.queue_free()
		_erase_node_from_array(_turret_pylons, oldest)
	var pylon: Node2D = Node2D.new()
	pylon.global_position = pos
	pylon.z_index = 58
	pylon.set_meta("radius", radius)
	pylon.set_meta("damage_scale", damage_scale)
	var visual: Polygon2D = Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0.0, -12.0),
		Vector2(11.0, 10.0),
		Vector2(-11.0, 10.0),
	])
	visual.color = Color(0.55, 0.72, 0.4, 0.9)
	visual.z_index = 58
	pylon.add_child(visual)
	var scene: Node = get_tree().current_scene if get_tree() else self
	scene.add_child(pylon)
	_turret_pylons.append(pylon)
	var tick_timer: Timer = Timer.new()
	tick_timer.wait_time = 0.35
	tick_timer.one_shot = false
	tick_timer.autostart = true
	pylon.add_child(tick_timer)
	tick_timer.timeout.connect(_on_turret_pylon_tick.bind(pylon))
	var life_timer: Timer = Timer.new()
	life_timer.wait_time = max(0.4, duration)
	life_timer.one_shot = true
	life_timer.autostart = true
	pylon.add_child(life_timer)
	life_timer.timeout.connect(_on_turret_pylon_timeout.bind(pylon))

func _on_turret_pylon_tick(pylon: Node2D) -> void:
	if not is_instance_valid(pylon):
		return
	var radius: float = float(pylon.get_meta("radius", 80.0))
	var damage_scale: float = float(pylon.get_meta("damage_scale", 0.35))
	var damage: float = _get_player_base_damage() * damage_scale
	var enemies: Array = _get_enemies_in_radius(pylon.global_position, radius)
	var hit: int = 0
	for enemy in enemies:
		if hit >= 4:
			break
		_damage_enemy(enemy, damage)
		_apply_enemy_status(enemy, "marked", 1.1, 0.18, 1, 0.4)
		hit += 1

func _on_turret_pylon_timeout(pylon: Node2D) -> void:
	if is_instance_valid(pylon):
		pylon.queue_free()
	_erase_node_from_array(_turret_pylons, pylon)

func _spawn_chronomancer_pool(pos: Vector2, radius: float, duration: float, damage_scale: float, split_count: int) -> void:
	if not is_inside_tree():
		return
	if _chronomancer_pools.size() >= 8:
		var oldest: Node = _chronomancer_pools[0]
		if is_instance_valid(oldest):
			oldest.queue_free()
		_erase_node_from_array(_chronomancer_pools, oldest)
	var pool: Node2D = Node2D.new()
	pool.global_position = pos
	pool.z_index = 55
	pool.set_meta("radius", radius)
	pool.set_meta("damage_scale", damage_scale)
	pool.set_meta("split_count", split_count)
	var visual: Polygon2D = Polygon2D.new()
	visual.polygon = _build_local_circle_polygon(radius, 16)
	visual.color = Color(0.4, 0.85, 0.45, 0.35)
	visual.z_index = 55
	pool.add_child(visual)
	var scene: Node = get_tree().current_scene if get_tree() else self
	scene.add_child(pool)
	_chronomancer_pools.append(pool)
	var tick_timer: Timer = Timer.new()
	tick_timer.wait_time = 0.35
	tick_timer.one_shot = false
	tick_timer.autostart = true
	pool.add_child(tick_timer)
	tick_timer.timeout.connect(_on_chronomancer_pool_tick.bind(pool))
	var life_timer: Timer = Timer.new()
	life_timer.wait_time = max(0.45, duration)
	life_timer.one_shot = true
	life_timer.autostart = true
	pool.add_child(life_timer)
	life_timer.timeout.connect(_on_chronomancer_pool_timeout.bind(pool))

func _on_chronomancer_pool_tick(pool: Node2D) -> void:
	if not is_instance_valid(pool):
		return
	var radius: float = float(pool.get_meta("radius", 50.0))
	var scale: float = float(pool.get_meta("damage_scale", 0.25))
	var damage: float = _get_player_base_damage() * scale
	for enemy in _get_enemies_in_radius(pool.global_position, radius):
		_damage_enemy(enemy, damage)
		_apply_enemy_status(enemy, "poison", 1.4, max(1.0, damage * 0.38), 1, 0.6)
		_apply_enemy_status(enemy, "slow", 0.9, 0.26, 1, 0.1)

func _on_chronomancer_pool_timeout(pool: Node2D) -> void:
	if not is_instance_valid(pool):
		_erase_node_from_array(_chronomancer_pools, pool)
		return
	var split_count: int = int(pool.get_meta("split_count", 0))
	var radius: float = float(pool.get_meta("radius", 50.0))
	var scale: float = float(pool.get_meta("damage_scale", 0.25))
	var center: Vector2 = pool.global_position
	pool.queue_free()
	_erase_node_from_array(_chronomancer_pools, pool)
	if split_count <= 0:
		return
	for _i in range(2):
		var angle: float = randf_range(0.0, TAU)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.65
		_spawn_chronomancer_pool(center + offset, max(26.0, radius * 0.62), 1.2, max(0.12, scale * 0.75), split_count - 1)

func _spawn_diva_mine(pos: Vector2, delay: float, radius: float, damage_scale: float) -> void:
	if not is_inside_tree():
		return
	if _diva_mines.size() >= 6:
		var oldest: Node = _diva_mines[0]
		_detonate_diva_mine(oldest, false)
	var mine: Node2D = Node2D.new()
	mine.global_position = pos
	mine.set_meta("radius", radius)
	mine.set_meta("damage_scale", damage_scale)
	mine.z_index = 57
	var marker: Polygon2D = Polygon2D.new()
	marker.polygon = PackedVector2Array([
		Vector2(0, -10),
		Vector2(9, 6),
		Vector2(-9, 6),
	])
	marker.color = Color(1.0, 0.78, 0.22, 0.95)
	marker.z_index = 57
	mine.add_child(marker)
	var scene: Node = get_tree().current_scene if get_tree() else self
	scene.add_child(mine)
	_diva_mines.append(mine)
	var timer: Timer = Timer.new()
	timer.wait_time = max(0.25, delay)
	timer.one_shot = true
	timer.autostart = true
	mine.add_child(timer)
	timer.timeout.connect(_on_diva_mine_timeout.bind(mine))

func _on_diva_mine_timeout(mine: Node) -> void:
	_detonate_diva_mine(mine, false)

func _detonate_all_diva_mines(from_closure: bool) -> void:
	var snapshot: Array = _diva_mines.duplicate()
	for mine in snapshot:
		_detonate_diva_mine(mine, from_closure)

func _detonate_diva_mine(mine: Node, from_closure: bool) -> void:
	if not is_instance_valid(mine):
		_erase_node_from_array(_diva_mines, mine)
		return
	var center: Vector2 = (mine as Node2D).global_position
	var radius: float = float(mine.get_meta("radius", 52.0))
	var scale: float = float(mine.get_meta("damage_scale", 0.52))
	if from_closure:
		scale *= 1.35
	var damage: float = _get_player_base_damage() * scale
	var enemies: Array = _get_enemies_in_radius(center, radius)
	for enemy in enemies:
		_damage_enemy(enemy, damage)
		_apply_enemy_status(enemy, "marked", 1.2, 0.18, 1, 0.4)
		_apply_enemy_status(enemy, "slow", 0.8, 0.28, 1, 0.1)
	spawn_skill_vfx(center, Color(1.2, 0.8, 0.25, 0.85), 0.4)
	mine.queue_free()
	_erase_node_from_array(_diva_mines, mine)

func _erase_node_from_array(arr: Array, node: Node) -> void:
	var idx: int = arr.find(node)
	if idx >= 0:
		arr.remove_at(idx)

func _spawn_signature_pickup(center: Vector2, color: Color, reward: Dictionary, lifetime_sec: float = 6.0) -> void:
	if not is_inside_tree():
		return
	var scene: Node = get_tree().current_scene if get_tree() else null
	if scene == null:
		return
	if _signature_pickups.size() >= 8:
		var oldest: Node = _signature_pickups[0]
		if is_instance_valid(oldest):
			oldest.queue_free()
		_erase_node_from_array(_signature_pickups, oldest)

	var pickup: Node2D = Node2D.new()
	pickup.global_position = center
	pickup.z_index = 59
	pickup.set_meta("expire_msec", Time.get_ticks_msec() + int(round(max(0.8, lifetime_sec) * 1000.0)))
	pickup.set_meta("reward", reward.duplicate(true))
	pickup.set_meta("bob_seed", randf() * TAU)

	var visual: Polygon2D = Polygon2D.new()
	visual.name = "Visual"
	visual.polygon = PackedVector2Array([
		Vector2(0.0, -9.0),
		Vector2(9.0, 0.0),
		Vector2(0.0, 9.0),
		Vector2(-9.0, 0.0),
	])
	visual.color = color
	visual.z_index = 59
	pickup.add_child(visual)

	scene.add_child(pickup)
	_signature_pickups.append(pickup)
	_sync_pickup_runtime_count()

func _spawn_signature_pickup_burst(
	center: Vector2,
	count: int,
	spread_radius: float,
	color: Color,
	reward: Dictionary,
	lifetime_sec: float = 6.0
) -> void:
	var burst_count: int = max(1, count)
	var safe_radius: float = max(18.0, spread_radius)
	for i in range(burst_count):
		var angle: float = randf() * TAU
		if burst_count > 1:
			angle = TAU * float(i) / float(burst_count) + randf_range(-0.28, 0.28)
		var offset_len: float = randf_range(safe_radius * 0.25, safe_radius)
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * offset_len
		_spawn_signature_pickup(pos, color, reward, lifetime_sec)

func _update_signature_pickups(delta: float) -> void:
	if _signature_pickups.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	var player_node: Node2D = _get_player_node()
	var player_pos: Vector2 = player_node.global_position if player_node != null else Vector2.ZERO
	var snapshot: Array = _signature_pickups.duplicate()
	for pickup_var in snapshot:
		if pickup_var == null or not is_instance_valid(pickup_var):
			_erase_node_from_array(_signature_pickups, pickup_var)
			continue
		if not (pickup_var is Node2D):
			continue
		var pickup: Node2D = pickup_var
		if now_msec > int(pickup.get_meta("expire_msec", 0)):
			pickup.queue_free()
			_erase_node_from_array(_signature_pickups, pickup)
			continue
		var visual: Polygon2D = pickup.get_node_or_null("Visual") as Polygon2D
		var bob_seed: float = float(pickup.get_meta("bob_seed", 0.0))
		pickup.rotation += delta * 2.8
		if is_instance_valid(visual):
			var bob_scale: float = 0.92 + 0.08 * sin((Time.get_ticks_msec() / 180.0) + bob_seed)
			visual.scale = Vector2.ONE * bob_scale
		if player_node != null and pickup.global_position.distance_to(player_pos) <= 26.0:
			_collect_signature_pickup(pickup)

func _collect_signature_pickup(pickup: Node2D) -> void:
	if pickup == null or not is_instance_valid(pickup):
		return
	var reward_var: Variant = pickup.get_meta("reward", {})
	var reward: Dictionary = reward_var if reward_var is Dictionary else {}
	var center: Vector2 = pickup.global_position
	_apply_signature_pickup_reward(center, reward)
	pickup.queue_free()
	_erase_node_from_array(_signature_pickups, pickup)
	_sync_pickup_runtime_count()

func _apply_signature_pickup_reward(center: Vector2, reward: Dictionary) -> void:
	if reward.is_empty():
		return
	var player_node: Node2D = _get_player_node()
	var effect_id: String = str(reward.get("effect_id", "")).strip_edges()
	var text: String = str(reward.get("pickup_text", "PICKUP")).strip_edges()
	var text_color: Color = reward.get("text_color", Color(1.0, 0.9, 0.4)) as Color
	var vfx_color: Color = reward.get("vfx_color", Color(1.0, 0.9, 0.4, 0.9)) as Color
	var effect_scale: float = float(reward.get("effect_scale", 0.58))
	var reward_radius: float = max(60.0, float(reward.get("radius", 120.0)))

	match effect_id:
		"butcher_hook":
			var butcher_dir: Vector2 = _get_player_aim_direction()
			_line_slice_burst(
				center - butcher_dir * reward_radius * 0.42,
				center + butcher_dir * reward_radius * 0.62,
				18.0,
				0.28,
				"marked",
				1.1,
				0.18,
				true,
				160.0
			)
			_gain_energy(2.0)
		"frostbite_rune":
			_spawn_ignis_patch(center, reward_radius * 0.34, 1.2, 0.20)
			_apply_status_burst(center, reward_radius * 0.62, 6, "burn", 1.4, 8.0)
			_gain_energy(1.6)
		"shaman_decoy":
			_knock_enemies_burst(center, reward_radius * 0.68, 5, 150.0)
			_apply_status_burst(center, reward_radius * 0.72, 6, "marked", 1.2, 0.18)
			_apply_temp_meta_delta("buff_speed_boost", 0.05, 1.4)
		"nexus_recall":
			_pull_enemies_burst(center, reward_radius * 0.78, 6, 18.0)
			_apply_status_burst(center, reward_radius * 0.72, 6, "slow", 1.0, 0.30)
			_gain_energy(1.8)
		"bulwark_wedge":
			_add_player_armor(1)
			_spawn_bulwark_core_zone(center, reward_radius * 0.42, 1.2, int(max(1.0, _get_player_base_damage() * 0.18)), 0.34)
			for enemy in _get_enemies_in_radius(center, reward_radius * 0.56):
				_apply_enemy_status(enemy, "freeze", 0.55, 0.0, 1, 0.1)
		"windblade_gust":
			var windblade_dir: Vector2 = _get_player_aim_direction()
			_line_slice_burst(
				center - windblade_dir * reward_radius * 0.32,
				center + windblade_dir * reward_radius * 0.72,
				18.0,
				0.22,
				"slow",
				1.0,
				0.28,
				true,
				180.0
			)
			_apply_temp_meta_delta("buff_speed_boost", 0.08, 1.4)
		"polaris_badge":
			var breach_dir: Vector2 = _get_player_aim_direction()
			_line_slice_burst(
				center - breach_dir * reward_radius * 0.18,
				center + breach_dir * reward_radius * 0.88,
				20.0,
				0.28,
				"marked",
				1.1,
				0.18,
				false,
				220.0
			)
			_gain_energy(1.8)
		"bloodhowl_order":
			var execute_count: int = 0
			for enemy in _sort_enemies_by_distance(_get_enemies_in_radius(center, reward_radius * 0.68), center):
				if _is_enemy_below_threshold(enemy, 0.30):
					_damage_enemy(enemy, _get_player_base_damage() * 1.2, "ORDER", Color(1.0, 0.24, 0.24))
					execute_count += 1
				else:
					_apply_enemy_status(enemy, "marked", 1.4, 0.22, 1, 0.3)
			if execute_count > 0:
				_gain_energy(1.2 + float(execute_count) * 0.4)
		"beastmaster_dust":
			_pull_enemies_burst(center, reward_radius * 0.84, 8, 22.0)
			get_tree().create_timer(0.18).timeout.connect(
				_on_beastmaster_implode_timeout.bind(center, reward_radius * 0.42, 0.52),
				CONNECT_ONE_SHOT
			)
		"medium_reload":
			_gain_energy(2.0)
			_apply_temp_attack_boost(1.8, 0.10)
			_refund_skill_cooldown("q", 0.8)
			_refund_skill_cooldown("e", 0.8)
		_:
			if float(reward.get("energy_gain", 0.0)) > 0.0:
				_gain_energy(float(reward.get("energy_gain", 0.0)))

	if reward.has("energy_gain"):
		_gain_energy(float(reward.get("energy_gain", 0.0)))
	if reward.has("armor_gain"):
		_add_player_armor(int(reward.get("armor_gain", 0)))
	if reward.has("cooldown_slot") and reward.has("cooldown_refund"):
		_refund_skill_cooldown(str(reward.get("cooldown_slot", "")), float(reward.get("cooldown_refund", 0.0)))
	if reward.has("temp_meta_key") and reward.has("temp_meta_delta") and reward.has("temp_meta_duration"):
		_apply_temp_meta_delta(
			str(reward.get("temp_meta_key", "")),
			float(reward.get("temp_meta_delta", 0.0)),
			float(reward.get("temp_meta_duration", 0.0))
		)
	if player_node != null:
		Global.spawn_floating_text(player_node.global_position, text, text_color)
	spawn_skill_vfx(center, vfx_color, effect_scale)

func _refund_skill_cooldown(slot_name: String, seconds: float) -> void:
	if slot_name.strip_edges().is_empty() or seconds <= 0.0 or not is_instance_valid(player_ref):
		return
	var skill_manager: Node = player_ref.get_node_or_null("SkillManager")
	if skill_manager == null or not ("skill_slots" in skill_manager):
		return
	var slots: Dictionary = skill_manager.skill_slots
	if not slots.has(slot_name):
		return
	var skill_obj: Variant = slots.get(slot_name)
	if not (skill_obj is SkillBase):
		return
	var skill: SkillBase = skill_obj
	var remaining: float = skill.get_cooldown_remaining()
	if remaining <= 0.0:
		return
	skill.set_cooldown_remaining(max(0.0, remaining - seconds))

func _clear_signature_nodes() -> void:
	for mine in _diva_mines:
		if is_instance_valid(mine):
			mine.queue_free()
	_diva_mines.clear()
	for pylon in _turret_pylons:
		if is_instance_valid(pylon):
			pylon.queue_free()
	_turret_pylons.clear()
	for pool in _chronomancer_pools:
		if is_instance_valid(pool):
			pool.queue_free()
	_chronomancer_pools.clear()
	for pickup in _signature_pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	_signature_pickups.clear()
	_sync_pickup_runtime_count()

func _sync_pickup_runtime_count() -> void:
	update_runtime_profile({
		"active_pickup_count": _signature_pickups.size()
	})

func _build_local_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var seg_count: int = max(6, segments)
	for i in range(seg_count):
		var angle: float = TAU * float(i) / float(seg_count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _build_circle_polygon(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var safe_segments: int = max(6, segments)
	for i in range(safe_segments):
		var angle := TAU * float(i) / float(safe_segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

