extends Node

const PARASITE_RESIDUE_SCRIPT := preload("res://scenes/effects/assist_parasite_residue.gd")
const JOULE_FUMES_SCRIPT := preload("res://scenes/effects/assist_joule_fumes.gd")
const SILK_LINK_UTILS := preload("res://scenes/effects/silk_link_utils.gd")

const PARASITE_DEFAULT_SLOW_RATIO: float = 0.20
const PARASITE_DEFAULT_SLOW_DURATION: float = 2.0
const JOULE_DEFAULT_ATTACK: float = 40.0
const ARC_DEFAULT_ATTACK: float = 40.0
const OVERTONE_DEFAULT_ATTACK: float = 40.0

const COLLAPSE_DEFAULT_PULL_DISTANCE: float = 30.0

const MINIMALIST_DEFAULT_REFUND_RATIO: float = 0.20
const MINIMALIST_DEFAULT_REFUND_CAP: float = 5.0
const MINIMALIST_DEFAULT_STRAIGHTNESS_THRESHOLD: float = 0.90
const OVERTONE_DEFAULT_MARK_DURATION: float = 3.0
const OVERTONE_DEFAULT_CONTACT_RADIUS: float = 34.0
const OVERTONE_DEFAULT_ENERGY_RESTORE: float = 5.0
const OVERTONE_DEFAULT_DAMAGE_RATIO: float = 1.5
const PHALANX_DEFAULT_PUSH_DISTANCE: float = 50.0

var _cooldowns: Dictionary = {}
var _condition_cache: Dictionary = {}
var _overtone_marked_targets: Array[Dictionary] = []
var _last_front_player_position: Vector2 = Vector2.ZERO
var _has_last_front_player_position: bool = false

func _ready() -> void:
	if ConfigRepositoryV2 != null and ConfigRepositoryV2.has_signal("configs_reloaded"):
		var callable_ref: Callable = Callable(self, "_on_configs_reloaded")
		if not ConfigRepositoryV2.configs_reloaded.is_connected(callable_ref):
			ConfigRepositoryV2.configs_reloaded.connect(callable_ref)

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var expired: Array[String] = []
	for key_variant in _cooldowns.keys():
		var key: String = str(key_variant)
		var remaining: float = max(0.0, float(_cooldowns.get(key, 0.0)) - delta)
		if remaining <= 0.0:
			expired.append(key)
		else:
			_cooldowns[key] = remaining
	for key in expired:
		_cooldowns.erase(key)
	_process_overtone_marks(delta)

func _on_configs_reloaded() -> void:
	_condition_cache.clear()

func on_front_enemy_killed(enemy: Enemy) -> void:
	if not is_instance_valid(enemy):
		return
	for assist_entry: Dictionary in _get_bench_assists_for_trigger("enemy_killed"):
		_execute_enemy_killed_assist(assist_entry, enemy)

func on_front_draw_release(owner: Node, release_data: Dictionary) -> void:
	var payload: Dictionary = release_data.duplicate(true)
	for assist_entry: Dictionary in _get_bench_assists_for_trigger("space_released"):
		_execute_space_release_assist(owner, assist_entry, payload)

func on_front_dash(owner: Node, dash_data: Dictionary) -> void:
	var payload: Dictionary = dash_data.duplicate(true)
	for assist_entry: Dictionary in _get_bench_assists_for_trigger("dash_started"):
		_execute_dash_assist(owner, assist_entry, payload)

func on_front_skill_damage(owner: Node, skill_slot: String, hit_enemies: Array, payload: Dictionary = {}) -> void:
	var merged_payload: Dictionary = payload.duplicate(true)
	merged_payload["skill_slot"] = skill_slot
	merged_payload["hit_enemies"] = hit_enemies.duplicate()
	for assist_entry: Dictionary in _get_bench_assists_for_trigger("skill_damage"):
		_execute_skill_damage_assist(owner, assist_entry, merged_payload)

func on_front_pre_hit(owner: Node, payload: Dictionary) -> Dictionary:
	var merged_payload: Dictionary = payload.duplicate(true)
	for assist_entry: Dictionary in _get_bench_assists_for_trigger("player_pre_hit"):
		var assist_result: Dictionary = _execute_pre_hit_assist(owner, assist_entry, merged_payload)
		if bool(assist_result.get("cancel", false)):
			return assist_result
	return {"cancel": false}

func _execute_enemy_killed_assist(assist_entry: Dictionary, enemy: Enemy) -> void:
	var assist_config: Dictionary = assist_entry.get("config", {})
	var execution_profile_id: String = str(assist_config.get("execution_profile_id", "")).strip_edges()
	match execution_profile_id:
		"parasite_residue_assist":
			_try_trigger_parasite_assist(str(assist_entry.get("player_id", "")), assist_config, enemy.global_position)

func _execute_space_release_assist(owner: Node, assist_entry: Dictionary, payload: Dictionary) -> void:
	var assist_config: Dictionary = assist_entry.get("config", {})
	var execution_profile_id: String = str(assist_config.get("execution_profile_id", "")).strip_edges()
	match execution_profile_id:
		"collapse_pull_assist":
			_try_trigger_collapse_assist(str(assist_entry.get("player_id", "")), assist_config, assist_entry.get("conditions", {}), payload)
		"minimalist_straight_refund":
			_try_trigger_minimalist_assist(owner, str(assist_entry.get("player_id", "")), assist_config, assist_entry.get("conditions", {}), payload)
		"joule_fumes_assist":
			_try_trigger_joule_assist(owner, str(assist_entry.get("player_id", "")), assist_config, payload)
		"silk_empathy_assist":
			_try_trigger_silk_assist(owner, str(assist_entry.get("player_id", "")), assist_config, assist_entry.get("conditions", {}), payload)

func _execute_dash_assist(owner: Node, assist_entry: Dictionary, payload: Dictionary) -> void:
	var assist_config: Dictionary = assist_entry.get("config", {})
	var execution_profile_id: String = str(assist_config.get("execution_profile_id", "")).strip_edges()
	match execution_profile_id:
		"arc_dash_afterimage":
			_try_trigger_arc_assist(owner, str(assist_entry.get("player_id", "")), assist_config, payload)

func _execute_skill_damage_assist(owner: Node, assist_entry: Dictionary, payload: Dictionary) -> void:
	var assist_config: Dictionary = assist_entry.get("config", {})
	var execution_profile_id: String = str(assist_config.get("execution_profile_id", "")).strip_edges()
	match execution_profile_id:
		"overtone_echo_assist":
			_try_trigger_overtone_assist(
				owner,
				str(assist_entry.get("player_id", "")),
				assist_config,
				assist_entry.get("conditions", {}),
				payload
			)

func _execute_pre_hit_assist(owner: Node, assist_entry: Dictionary, payload: Dictionary) -> Dictionary:
	var assist_config: Dictionary = assist_entry.get("config", {})
	var execution_profile_id: String = str(assist_config.get("execution_profile_id", "")).strip_edges()
	match execution_profile_id:
		"phalanx_reactive_armor":
			return _try_trigger_phalanx_assist(owner, str(assist_entry.get("player_id", "")), assist_config, assist_entry.get("conditions", {}), payload)
	return {"cancel": false}

func _try_trigger_parasite_assist(player_id: String, assist_config: Dictionary, origin: Vector2) -> void:
	if not _commit_assist_trigger(player_id, assist_config):
		return

	var conditions: Dictionary = _get_assist_conditions(assist_config)
	var radius: float = max(0.0, float(assist_config.get("effect_radius", 50.0)))
	var duration: float = max(0.0, float(assist_config.get("effect_duration", 1.0)))
	var slow_ratio: float = clamp(float(conditions.get("slow_ratio", PARASITE_DEFAULT_SLOW_RATIO)), 0.0, 1.0)
	var slow_duration: float = max(0.0, float(conditions.get("slow_duration", PARASITE_DEFAULT_SLOW_DURATION)))
	var residue: AssistParasiteResidue = PARASITE_RESIDUE_SCRIPT.new() as AssistParasiteResidue
	if residue == null:
		return
	residue.global_position = origin
	residue.setup(radius, duration, slow_ratio, slow_duration)
	residue.modulate = Color(1.0, 1.0, 1.0, 0.3)
	get_tree().current_scene.call_deferred("add_child", residue)
	_spawn_assist_burst(origin, radius * 0.65, radius * 1.3, Color(0.52, 1.0, 0.66, 0.26), Color(0.78, 1.0, 0.84, 0.9), 9.0, 0.28)
	Global.on_camera_shake.emit(2.4, 0.08)
	Global.spawn_floating_text(origin + Vector2(0, -20), "SPORE", Color(0.62, 1.2, 0.72))

func _try_trigger_collapse_assist(player_id: String, assist_config: Dictionary, conditions: Dictionary, payload: Dictionary) -> void:
	var require_closed: bool = bool(conditions.get("require_closed", true))
	if require_closed and not bool(payload.get("is_closed", false)):
		return

	var approx_area: float = float(payload.get("approx_area", 0.0))
	var max_area: float = float(conditions.get("max_area", 40000.0))
	if approx_area <= 0.0 or approx_area >= max_area:
		return
	if not _commit_assist_trigger(player_id, assist_config):
		return

	var centroid: Vector2 = payload.get("centroid", Vector2.ZERO)
	var pull_radius: float = max(0.0, float(assist_config.get("effect_radius", 200.0)))
	var fade_time: float = max(0.05, float(assist_config.get("effect_duration", 0.2)))
	var pull_distance: float = max(0.0, float(conditions.get("pull_distance", COLLAPSE_DEFAULT_PULL_DISTANCE)))
	var ring: Line2D = _create_assist_ring(centroid, 34.0, Color(0.68, 0.82, 1.0, 0.26), 6.0)
	get_tree().current_scene.add_child(ring)
	var ring_tween: Tween = ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(1.18, 1.18), fade_time)
	ring_tween.tween_property(ring, "modulate:a", 0.0, fade_time)
	ring_tween.finished.connect(ring.queue_free)
	_spawn_assist_burst(centroid, 28.0, pull_radius * 0.92, Color(0.52, 0.82, 1.0, 0.14), Color(0.84, 0.94, 1.0, 0.85), 10.0, max(0.12, fade_time))
	_spawn_assist_burst(centroid, 16.0, pull_radius * 0.58, Color(0.72, 0.90, 1.0, 0.10), Color(0.94, 0.98, 1.0, 0.65), 6.0, max(0.10, fade_time * 0.85))
	Global.on_camera_shake.emit(3.2, 0.10)
	Global.spawn_floating_text(centroid + Vector2(0, -20), "GRAVITY", Color(0.72, 0.9, 1.0))

	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var distance_to_center: float = enemy.global_position.distance_to(centroid)
		if distance_to_center > pull_radius:
			continue
		var pull_dir: Vector2 = (centroid - enemy.global_position).normalized()
		if pull_dir.length_squared() <= 0.0:
			continue
		enemy.global_position += pull_dir * min(pull_distance, distance_to_center)

func _try_trigger_minimalist_assist(owner: Node, player_id: String, assist_config: Dictionary, conditions: Dictionary, payload: Dictionary) -> void:
	if bool(payload.get("is_closed", false)):
		return
	var points_variant: Variant = payload.get("points", [])
	if not (points_variant is Array):
		return
	var points: Array = points_variant
	if points.size() < 2:
		return

	var straightness_threshold: float = float(conditions.get("straightness_threshold", MINIMALIST_DEFAULT_STRAIGHTNESS_THRESHOLD))
	var refund_ratio: float = max(0.0, float(conditions.get("refund_ratio", MINIMALIST_DEFAULT_REFUND_RATIO)))
	var refund_cap: float = max(0.0, float(conditions.get("refund_cap", MINIMALIST_DEFAULT_REFUND_CAP)))
	var straight_ratio: float = _compute_straightness_ratio(points)
	if straight_ratio < straightness_threshold:
		return
	if not _commit_assist_trigger(player_id, assist_config):
		return

	var draw_cost: float = max(0.0, float(payload.get("draw_cost", 0.0)))
	var refund_amount: float = min(refund_cap, draw_cost * refund_ratio)
	var target_player: Node = owner if is_instance_valid(owner) else Global.player
	if refund_amount > 0.0 and is_instance_valid(target_player):
		target_player.energy = min(target_player.max_energy, target_player.energy + refund_amount)
		if target_player.has_method("update_ui_signals"):
			target_player.update_ui_signals()
		Global.spawn_floating_text(target_player.global_position + Vector2(0, -28), "+%.1f ENERGY" % refund_amount, Color(0.82, 0.96, 1.0))
	Global.on_camera_shake.emit(1.8, 0.06)
	_create_assist_trace(points)

func _try_trigger_joule_assist(owner: Node, player_id: String, assist_config: Dictionary, payload: Dictionary) -> void:
	var centroid: Vector2 = payload.get("centroid", Vector2.ZERO)
	if centroid == Vector2.ZERO:
		return
	if not _commit_assist_trigger(player_id, assist_config):
		return

	var radius: float = max(0.0, float(assist_config.get("effect_radius", 80.0)))
	var duration: float = max(0.0, float(assist_config.get("effect_duration", 2.0)))
	var attack_value: float = _resolve_assist_attack_value(player_id, owner)
	var fumes: Node2D = JOULE_FUMES_SCRIPT.new() as Node2D
	if fumes == null:
		return
	fumes.global_position = centroid
	if fumes.has_method("setup"):
		fumes.call("setup", radius, duration, attack_value, 8.0, 10.0)
	get_tree().current_scene.call_deferred("add_child", fumes)
	_spawn_assist_burst(centroid, radius * 0.25, radius * 1.05, Color(1.0, 0.54, 0.18, 0.12), Color(1.0, 0.82, 0.44, 0.82), 8.0, 0.24)
	Global.on_camera_shake.emit(2.6, 0.08)
	Global.spawn_floating_text(centroid + Vector2(0, -20), "FUMES", Color(1.0, 0.82, 0.48))

func _try_trigger_arc_assist(owner: Node, player_id: String, assist_config: Dictionary, payload: Dictionary) -> void:
	var start_pos: Vector2 = payload.get("start", Vector2.ZERO)
	var end_pos: Vector2 = payload.get("end", Vector2.ZERO)
	if start_pos == end_pos:
		return
	if not _commit_assist_trigger(player_id, assist_config):
		return

	var half_width: float = max(4.0, float(assist_config.get("effect_radius", 36.0)))
	var damage_amount: float = _resolve_assist_attack_value(player_id, owner)
	var hit_count: int = 0
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start_pos, end_pos)
		if enemy.global_position.distance_to(closest) > half_width:
			continue
		enemy.apply_modifier_damage(damage_amount, owner, {
			"kind": "arc_assist_afterimage",
			"damage_type": "DMG_AOE",
		})
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()
		hit_count += 1

	var root: Node2D = Node2D.new()
	root.top_level = true
	root.z_index = 31
	get_tree().current_scene.add_child(root)

	var outer_line: Line2D = Line2D.new()
	outer_line.points = PackedVector2Array([start_pos, end_pos])
	outer_line.width = half_width * 2.0 + 12.0
	outer_line.default_color = Color(0.42, 0.88, 1.0, 0.24)
	outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.antialiased = true
	root.add_child(outer_line)

	var inner_line: Line2D = Line2D.new()
	inner_line.points = PackedVector2Array([start_pos, end_pos])
	inner_line.width = half_width * 2.0
	inner_line.default_color = Color(0.90, 0.98, 1.0, 0.92)
	inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.antialiased = true
	root.add_child(inner_line)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(outer_line, "modulate:a", 0.0, 0.16)
	tween.tween_property(inner_line, "modulate:a", 0.0, 0.12)
	tween.finished.connect(root.queue_free)

	Global.on_camera_shake.emit(2.0, 0.06)
	Global.spawn_floating_text((start_pos + end_pos) * 0.5, "AFTERIMAGE x%d" % hit_count, Color(0.72, 0.96, 1.0))

func _try_trigger_overtone_assist(owner: Node, player_id: String, assist_config: Dictionary, conditions: Dictionary, payload: Dictionary) -> void:
	var skill_slot: String = str(payload.get("skill_slot", "")).strip_edges().to_lower()
	if skill_slot != "e" and skill_slot != "f":
		return

	var hit_enemies_variant: Variant = payload.get("hit_enemies", [])
	if not (hit_enemies_variant is Array):
		return
	var hit_enemies: Array = hit_enemies_variant
	if hit_enemies.is_empty():
		return

	if not _commit_assist_trigger(player_id, assist_config):
		return

	var duration: float = max(0.1, float(conditions.get("mark_duration", OVERTONE_DEFAULT_MARK_DURATION)))
	var contact_radius: float = max(8.0, float(conditions.get("contact_radius", OVERTONE_DEFAULT_CONTACT_RADIUS)))
	var energy_restore: float = max(0.0, float(conditions.get("energy_restore", OVERTONE_DEFAULT_ENERGY_RESTORE)))
	var damage_ratio: float = max(0.1, float(conditions.get("damage_ratio", OVERTONE_DEFAULT_DAMAGE_RATIO)))
	var damage_amount: float = _resolve_assist_attack_value(player_id, owner) * damage_ratio

	var marked_count: int = 0
	for enemy_variant: Variant in hit_enemies:
		if not (enemy_variant is Enemy):
			continue
		var enemy: Enemy = enemy_variant as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if enemy.has_method("apply_tag_marker"):
			enemy.apply_tag_marker(
				"overtone_echo_marker",
				"overtone_echo",
				duration,
				CombatModifierComponent.STACK_REFRESH,
				owner,
				{"kind": "overtone_echo_assist"}
			)
		_register_overtone_mark(enemy, duration, contact_radius, damage_amount, energy_restore)
		if enemy.has_method("set_flash_material"):
			enemy.set_flash_material()
		marked_count += 1

	if marked_count <= 0:
		return
	Global.on_camera_shake.emit(1.8, 0.06)
	Global.spawn_floating_text(
		(owner.global_position if is_instance_valid(owner) and owner is Node2D else Vector2.ZERO) + Vector2(0, -18),
		"ECHO x%d" % marked_count,
		Color(1.0, 0.88, 0.42)
	)

func _try_trigger_phalanx_assist(owner: Node, player_id: String, assist_config: Dictionary, conditions: Dictionary, payload: Dictionary) -> Dictionary:
	if owner == null or not is_instance_valid(owner):
		return {"cancel": false}
	if not _commit_assist_trigger(player_id, assist_config):
		return {"cancel": false}

	var push_distance: float = max(0.0, float(conditions.get("push_distance", PHALANX_DEFAULT_PUSH_DISTANCE)))
	var source_variant: Variant = payload.get("source", null)
	if source_variant != null and is_instance_valid(source_variant) and source_variant is Node2D and owner is Node2D:
		var attacker: Node2D = source_variant as Node2D
		var target_owner: Node2D = owner as Node2D
		var push_dir: Vector2 = attacker.global_position - target_owner.global_position
		if push_dir.length_squared() <= 0.0001:
			push_dir = Vector2.RIGHT.rotated(randf() * TAU)
		else:
			push_dir = push_dir.normalized()
		attacker.global_position += push_dir * push_distance
		if attacker.has_method("set_flash_material"):
			attacker.set_flash_material()

	Global.on_camera_shake.emit(2.2, 0.06)
	if owner is Node2D:
		Global.spawn_floating_text((owner as Node2D).global_position + Vector2(0, -20), "REACTIVE", Color(0.82, 0.96, 1.0))
	return {
		"cancel": true,
		"reason": "phalanx_reactive_armor",
	}

func _try_trigger_silk_assist(owner: Node, player_id: String, assist_config: Dictionary, conditions: Dictionary, payload: Dictionary) -> void:
	if bool(conditions.get("require_closed", true)) and not bool(payload.get("is_closed", false)):
		return
	var polygon: PackedVector2Array = _build_polygon_from_payload(payload)
	if polygon.size() < 3:
		return

	var source_enemy: Enemy = null
	var source_health: float = -1.0
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if not Geometry2D.is_point_in_polygon(enemy.global_position, polygon):
			continue
		var enemy_health: float = float(enemy.health_component.current_health) if enemy.health_component != null else 0.0
		if enemy_health > source_health:
			source_health = enemy_health
			source_enemy = enemy
	if source_enemy == null:
		return
	if not _commit_assist_trigger(player_id, assist_config):
		return

	var target_limit: int = int(conditions.get("target_count", assist_config.get("target_limit", 3)))
	var search_radius: float = float(conditions.get("search_radius", assist_config.get("effect_radius", 300.0)))
	var link_duration: float = float(conditions.get("link_duration", assist_config.get("effect_duration", 5.0)))
	var damage_ratio: float = float(conditions.get("damage_ratio", 0.5))
	var base_damage: float = float(payload.get("resolved_damage", 0.0))
	if base_damage <= 0.0 and is_instance_valid(owner) and "damage" in owner:
		base_damage = float(owner.get("damage"))
	base_damage = max(1.0, base_damage) * damage_ratio

	SILK_LINK_UTILS.apply_link(source_enemy, owner if is_instance_valid(owner) else source_enemy, link_duration, false, link_duration)
	var targets: Array[Enemy] = _find_nearest_enemies(source_enemy.global_position, search_radius, target_limit, [source_enemy])
	if targets.is_empty():
		Global.spawn_floating_text(source_enemy.global_position + Vector2(0, -20), "EMPATHY", Color(1.0, 0.72, 0.82))
		return

	for target: Enemy in targets:
		target.apply_modifier_damage(base_damage, owner, {
			"kind": "silk_assist",
			"damage_type": "DMG_TRUE",
		})
		SILK_LINK_UTILS.apply_link(target, owner if is_instance_valid(owner) else source_enemy, link_duration, false, link_duration)
		_spawn_silk_empathy_line(source_enemy.global_position, target.global_position)
		if target.has_method("set_flash_material"):
			target.set_flash_material()

	Global.on_camera_shake.emit(2.8, 0.08)
	Global.spawn_floating_text(source_enemy.global_position + Vector2(0, -20), "EMPATHY", Color(1.0, 0.72, 0.82))

func _get_bench_assists_for_trigger(trigger_event: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player_id: String in _get_bench_player_ids():
		var assist_config: Dictionary = _get_assist_config_for_player(player_id)
		if assist_config.is_empty():
			continue
		if not _trigger_matches(str(assist_config.get("trigger_event", "")), trigger_event):
			continue
		result.append({
			"player_id": player_id,
			"config": assist_config,
			"conditions": _get_assist_conditions(assist_config),
		})
	return result

func _get_assist_config_for_player(player_id: String) -> Dictionary:
	var runtime_binding: Dictionary = ConfigRepositoryV2.get_runtime_binding(player_id)
	if runtime_binding.is_empty() and RoleRuntimeService != null and RoleRuntimeService.has_method("get_v2_runtime_binding"):
		runtime_binding = RoleRuntimeService.get_v2_runtime_binding(player_id)
	if runtime_binding.is_empty():
		return {}
	var assist_id: String = str(runtime_binding.get("assist_id", "")).strip_edges()
	if assist_id.is_empty():
		return {}
	var assist_config: Dictionary = ConfigRepositoryV2.get_assist_config(assist_id)
	if assist_config.is_empty():
		return {}
	var owner_player_id: String = str(assist_config.get("owner_player_id", "")).strip_edges()
	if not owner_player_id.is_empty() and owner_player_id != player_id:
		return {}
	return assist_config

func _get_assist_conditions(assist_config: Dictionary) -> Dictionary:
	var assist_id: String = str(assist_config.get("assist_id", "")).strip_edges()
	if assist_id.is_empty():
		return {}
	if _condition_cache.has(assist_id):
		return _condition_cache.get(assist_id, {})

	var raw_json: String = str(assist_config.get("trigger_condition_json", "")).strip_edges()
	var parsed: Dictionary = {}
	if not raw_json.is_empty():
		var parsed_variant: Variant = JSON.parse_string(raw_json)
		if parsed_variant is Dictionary:
			parsed = parsed_variant
	_condition_cache[assist_id] = parsed
	return parsed

func _trigger_matches(configured_event: String, requested_event: String) -> bool:
	var normalized_configured: String = configured_event.strip_edges().to_lower()
	var normalized_requested: String = requested_event.strip_edges().to_lower()
	if normalized_configured.is_empty():
		return false
	if normalized_configured == normalized_requested:
		return true
	if normalized_requested == "space_released":
		return normalized_configured == "space_draw_released"
	return false

func _commit_assist_trigger(player_id: String, assist_config: Dictionary) -> bool:
	var cooldown_key: String = _cooldown_key(str(assist_config.get("assist_id", "")), player_id)
	if _is_on_cooldown(cooldown_key):
		return false

	var proc_chance: float = clamp(float(assist_config.get("proc_chance", 1.0)), 0.0, 1.0)
	if proc_chance < 1.0 and randf() > proc_chance:
		return false

	var internal_cooldown: float = max(0.0, float(assist_config.get("internal_cooldown", 0.0)))
	if internal_cooldown > 0.0:
		_cooldowns[cooldown_key] = internal_cooldown
	return true

func _compute_straightness_ratio(points: Array) -> float:
	if points.size() < 2:
		return 0.0
	var total_length: float = 0.0
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		total_length += a.distance_to(b)
	if total_length <= 0.001:
		return 0.0
	var start_point: Vector2 = points[0]
	var end_point: Vector2 = points[points.size() - 1]
	return start_point.distance_to(end_point) / total_length

func _create_assist_trace(points: Array) -> void:
	var packed_points: PackedVector2Array = PackedVector2Array()
	for point in points:
		if point is Vector2:
			packed_points.append(point)
	if packed_points.size() < 2:
		return

	var root: Node2D = Node2D.new()
	root.top_level = true
	root.z_index = 29
	get_tree().current_scene.add_child(root)

	var outer_line: Line2D = Line2D.new()
	outer_line.points = packed_points
	outer_line.width = 28.0
	outer_line.default_color = Color(0.90, 0.98, 1.0, 0.18)
	outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.joint_mode = Line2D.LINE_JOINT_ROUND
	outer_line.antialiased = true
	root.add_child(outer_line)

	var inner_line: Line2D = Line2D.new()
	inner_line.points = packed_points
	inner_line.width = 12.0
	inner_line.default_color = Color(1.0, 1.0, 1.0, 0.88)
	inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.joint_mode = Line2D.LINE_JOINT_ROUND
	inner_line.antialiased = true
	root.add_child(inner_line)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(outer_line, "width", 40.0, 0.18)
	tween.tween_property(inner_line, "width", 18.0, 0.16)
	tween.tween_property(outer_line, "modulate:a", 0.0, 0.22)
	tween.tween_property(inner_line, "modulate:a", 0.0, 0.18)
	tween.finished.connect(root.queue_free)

func _spawn_silk_empathy_line(from_pos: Vector2, to_pos: Vector2) -> void:
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.z_index = 31
	get_tree().current_scene.add_child(root)

	var outer_line: Line2D = Line2D.new()
	outer_line.points = PackedVector2Array([from_pos, to_pos])
	outer_line.width = 12.0
	outer_line.default_color = Color(1.0, 0.24, 0.32, 0.28)
	outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.antialiased = true
	root.add_child(outer_line)

	var inner_line: Line2D = Line2D.new()
	inner_line.points = PackedVector2Array([from_pos, to_pos])
	inner_line.width = 5.0
	inner_line.default_color = Color(1.0, 0.82, 0.88, 0.92)
	inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.antialiased = true
	root.add_child(inner_line)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(outer_line, "modulate:a", 0.0, 0.24)
	tween.tween_property(inner_line, "modulate:a", 0.0, 0.18)
	tween.finished.connect(root.queue_free)

func _find_nearest_enemies(center: Vector2, radius: float, target_limit: int, excluded: Array[Enemy] = []) -> Array[Enemy]:
	var candidates: Array[Enemy] = []
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if not (enemy_node is Enemy):
			continue
		var enemy: Enemy = enemy_node as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
		if excluded.has(enemy):
			continue
		if center.distance_to(enemy.global_position) > radius:
			continue
		candidates.append(enemy)
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return center.distance_squared_to(a.global_position) < center.distance_squared_to(b.global_position)
	)
	if target_limit <= 0 or candidates.size() <= target_limit:
		return candidates
	return candidates.slice(0, target_limit)

func _build_polygon_from_payload(payload: Dictionary) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	var points_variant: Variant = payload.get("points", [])
	if not (points_variant is Array):
		return polygon
	var points: Array = points_variant
	for point_variant: Variant in points:
		if point_variant is Vector2:
			polygon.append(point_variant)
	if polygon.size() >= 2 and polygon[0].distance_to(polygon[polygon.size() - 1]) <= 60.0:
		polygon.remove_at(polygon.size() - 1)
	return polygon

func _create_assist_ring(center: Vector2, radius: float, color: Color, width: float) -> Line2D:
	var ring: Line2D = Line2D.new()
	ring.top_level = true
	ring.closed = true
	ring.z_index = 28
	ring.width = width
	ring.default_color = color
	ring.antialiased = true
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(25):
		var angle: float = (float(i) / 24.0) * TAU
		points.append(center + Vector2.RIGHT.rotated(angle) * radius)
	ring.points = points
	return ring

func _spawn_assist_burst(center: Vector2, start_radius: float, end_radius: float, fill_color: Color, ring_color: Color, ring_width: float, duration: float) -> void:
	var root: Node2D = Node2D.new()
	root.top_level = true
	root.global_position = center
	root.z_index = 30

	var fill: Polygon2D = Polygon2D.new()
	fill.color = fill_color
	root.add_child(fill)

	var ring: Line2D = Line2D.new()
	ring.closed = true
	ring.width = ring_width
	ring.default_color = ring_color
	ring.antialiased = true
	root.add_child(ring)

	_update_assist_burst_geometry(fill, ring, start_radius)
	get_tree().current_scene.add_child(root)

	var tween: Tween = root.create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(fill) and is_instance_valid(ring):
			_update_assist_burst_geometry(fill, ring, value)
	, start_radius, end_radius, duration)
	tween.tween_property(fill, "modulate:a", 0.0, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.finished.connect(root.queue_free)

func _update_assist_burst_geometry(fill: Polygon2D, ring: Line2D, radius: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(25):
		var angle: float = (float(i) / 24.0) * TAU
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	fill.polygon = points
	ring.points = points

func _get_bench_player_ids() -> Array[String]:
	var bench_ids: Array[String] = []
	var active_id: String = _get_active_player_id()
	for id_variant in Global.selected_player_ids:
		var player_id: String = str(id_variant)
		if player_id.is_empty() or player_id == active_id:
			continue
		bench_ids.append(player_id)
	return bench_ids

func _get_active_player_id() -> String:
	if Global != null and Global.has_method("get_current_player_id"):
		var current_id: String = str(Global.get_current_player_id())
		if not current_id.is_empty():
			return current_id
	if is_instance_valid(Global.player) and "player_id" in Global.player:
		return str(Global.player.player_id)
	return ""

func _cooldown_key(assist_id: String, player_id: String) -> String:
	return "%s:%s" % [assist_id, player_id]

func _is_on_cooldown(key: String) -> bool:
	return float(_cooldowns.get(key, 0.0)) > 0.0

func _resolve_assist_attack_value(player_id: String, owner: Node) -> float:
	if player_id == "arc":
		return ARC_DEFAULT_ATTACK
	if player_id == "overtone":
		return OVERTONE_DEFAULT_ATTACK
	if is_instance_valid(owner) and "damage" in owner:
		return float(owner.get("damage"))
	var player_bundle: Dictionary = RoleRuntimeService.get_v2_role_bundle(player_id)
	var player_config: Dictionary = player_bundle.get("player_config", {})
	var fallback_attack: float = float(player_config.get("base_attack", JOULE_DEFAULT_ATTACK))
	return max(1.0, fallback_attack)

func _register_overtone_mark(enemy: Enemy, duration: float, contact_radius: float, damage_amount: float, energy_restore: float) -> void:
	for i: int in range(_overtone_marked_targets.size()):
		var entry_variant: Variant = _overtone_marked_targets[i]
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var enemy_ref_variant: Variant = entry.get("enemy_ref", null)
		if enemy_ref_variant == null or not (enemy_ref_variant is WeakRef):
			continue
		var existing_enemy_variant: Variant = (enemy_ref_variant as WeakRef).get_ref()
		if existing_enemy_variant == null or not is_instance_valid(existing_enemy_variant) or not (existing_enemy_variant is Enemy):
			continue
		var existing_enemy: Enemy = existing_enemy_variant as Enemy
		if existing_enemy != enemy:
			continue
		entry["remaining"] = duration
		entry["contact_radius"] = contact_radius
		entry["damage_amount"] = damage_amount
		entry["energy_restore"] = energy_restore
		_overtone_marked_targets[i] = entry
		return

	_overtone_marked_targets.append({
		"enemy_ref": weakref(enemy),
		"remaining": duration,
		"contact_radius": contact_radius,
		"damage_amount": damage_amount,
		"energy_restore": energy_restore,
	})

func _process_overtone_marks(delta: float) -> void:
	var active_player_variant: Variant = Global.player
	if active_player_variant == null or not is_instance_valid(active_player_variant) or not (active_player_variant is PlayerBase):
		_has_last_front_player_position = false
		_cleanup_expired_overtone_marks(delta)
		return
	var active_player: PlayerBase = active_player_variant as PlayerBase

	var current_position: Vector2 = active_player.global_position
	if not _has_last_front_player_position:
		_last_front_player_position = current_position
		_has_last_front_player_position = true
		_cleanup_expired_overtone_marks(delta)
		return

	var previous_position: Vector2 = _last_front_player_position
	_last_front_player_position = current_position

	var remaining_marks: Array[Dictionary] = []
	for entry_variant: Variant in _overtone_marked_targets:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var enemy_ref_variant: Variant = entry.get("enemy_ref", null)
		if enemy_ref_variant == null or not (enemy_ref_variant is WeakRef):
			continue
		var enemy_variant: Variant = (enemy_ref_variant as WeakRef).get_ref()
		if enemy_variant == null or not is_instance_valid(enemy_variant) or not (enemy_variant is Enemy):
			continue
		var enemy: Enemy = enemy_variant as Enemy
		if enemy.is_dead:
			continue

		var remaining_time: float = max(0.0, float(entry.get("remaining", 0.0)) - delta)
		if remaining_time <= 0.0:
			_clear_overtone_marker(enemy)
			continue

		entry["remaining"] = remaining_time
		var contact_radius: float = float(entry.get("contact_radius", OVERTONE_DEFAULT_CONTACT_RADIUS))
		if _segment_hits_enemy(previous_position, current_position, enemy.global_position, contact_radius):
			_trigger_overtone_echo(active_player, enemy, float(entry.get("damage_amount", OVERTONE_DEFAULT_ATTACK * OVERTONE_DEFAULT_DAMAGE_RATIO)), float(entry.get("energy_restore", OVERTONE_DEFAULT_ENERGY_RESTORE)))
			continue
		remaining_marks.append(entry)
	_overtone_marked_targets = remaining_marks

func _cleanup_expired_overtone_marks(delta: float) -> void:
	var remaining_marks: Array[Dictionary] = []
	for entry_variant: Variant in _overtone_marked_targets:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var enemy_ref_variant: Variant = entry.get("enemy_ref", null)
		if enemy_ref_variant == null or not (enemy_ref_variant is WeakRef):
			continue
		var enemy_variant: Variant = (enemy_ref_variant as WeakRef).get_ref()
		if enemy_variant == null or not is_instance_valid(enemy_variant) or not (enemy_variant is Enemy):
			continue
		var enemy: Enemy = enemy_variant as Enemy
		if enemy.is_dead:
			continue
		var remaining_time: float = max(0.0, float(entry.get("remaining", 0.0)) - delta)
		if remaining_time <= 0.0:
			_clear_overtone_marker(enemy)
			continue
		entry["remaining"] = remaining_time
		remaining_marks.append(entry)
	_overtone_marked_targets = remaining_marks

func _segment_hits_enemy(from_pos: Vector2, to_pos: Vector2, enemy_pos: Vector2, radius: float) -> bool:
	if from_pos.distance_squared_to(to_pos) <= 0.001:
		return enemy_pos.distance_to(to_pos) <= radius
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy_pos, from_pos, to_pos)
	return enemy_pos.distance_to(closest) <= radius

func _trigger_overtone_echo(active_player: PlayerBase, enemy: Enemy, damage_amount: float, energy_restore: float) -> void:
	_clear_overtone_marker(enemy)
	enemy.apply_modifier_damage(
		damage_amount,
		active_player,
		{
			"kind": "overtone_echo_assist",
			"damage_type": "DMG_AOE",
		}
	)
	if enemy.has_method("set_flash_material"):
		enemy.set_flash_material()
	if energy_restore > 0.0 and is_instance_valid(active_player):
		active_player.energy = min(active_player.max_energy, active_player.energy + energy_restore)
		active_player.update_ui_signals()
	Global.on_camera_shake.emit(2.2, 0.07)
	Global.spawn_floating_text(enemy.global_position, "ECHO", Color(1.0, 0.86, 0.40))

func _clear_overtone_marker(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var modifier_component: CombatModifierComponent = enemy.get_node_or_null("CombatModifierComponent") as CombatModifierComponent
	if modifier_component != null:
		modifier_component.clear_tag_marker("overtone_echo")
