extends RefCounted
class_name FRewardEffectService

static func apply_signature_effect(host: Node, center: Vector2, reward_radius: float, reward: Dictionary) -> void:
	if host == null or not is_instance_valid(host) or reward.is_empty():
		return

	var effect_id: String = str(reward.get("effect_id", "")).strip_edges()
	match effect_id:
		"butcher_hook":
			var butcher_dir: Vector2 = _call_vec2(host, "_get_player_aim_direction", Vector2.RIGHT)
			host.call(
				"_line_slice_burst",
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
			host.call("_gain_energy", 2.0)
		"runeblazer_rune":
			host.call("_spawn_pyro_patch", center, reward_radius * 0.34, 1.2, 0.20)
			host.call("_apply_status_burst", center, reward_radius * 0.62, 6, "burn", 1.4, 8.0)
			host.call("_gain_energy", 1.6)
		"lurewarden_decoy":
			host.call("_knock_enemies_burst", center, reward_radius * 0.68, 5, 150.0)
			host.call("_apply_status_burst", center, reward_radius * 0.72, 6, "marked", 1.2, 0.18)
			host.call("_apply_temp_meta_delta", "buff_speed_boost", 0.05, 1.4)
		"weaver_recall":
			host.call("_pull_enemies_burst", center, reward_radius * 0.78, 6, 18.0)
			host.call("_apply_status_burst", center, reward_radius * 0.72, 6, "slow", 1.0, 0.30)
			host.call("_gain_energy", 1.8)
		"glacier_wedge":
			host.call("_add_player_armor", 1)
			var glacier_damage: int = int(max(1.0, _call_float(host, "_get_player_base_damage", 12.0) * 0.18))
			host.call("_spawn_glacier_core_zone", center, reward_radius * 0.42, 1.2, glacier_damage, 0.34)
			for enemy in _call_array(host, "_get_enemies_in_radius", [center, reward_radius * 0.56]):
				host.call("_apply_enemy_status", enemy, "freeze", 0.55, 0.0, 1, 0.1)
		"wind_gust":
			var wind_dir: Vector2 = _call_vec2(host, "_get_player_aim_direction", Vector2.RIGHT)
			host.call(
				"_line_slice_burst",
				center - wind_dir * reward_radius * 0.32,
				center + wind_dir * reward_radius * 0.72,
				18.0,
				0.22,
				"slow",
				1.0,
				0.28,
				true,
				180.0
			)
			host.call("_apply_temp_meta_delta", "buff_speed_boost", 0.08, 1.4)
		"breachmarshal_badge":
			var breach_dir: Vector2 = _call_vec2(host, "_get_player_aim_direction", Vector2.RIGHT)
			host.call(
				"_line_slice_burst",
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
			host.call("_gain_energy", 1.8)
		"executioner_order":
			var execute_count: int = 0
			var base_damage: float = _call_float(host, "_get_player_base_damage", 12.0)
			for enemy in _call_array(host, "_sort_enemies_by_distance", [_call_array(host, "_get_enemies_in_radius", [center, reward_radius * 0.68]), center]):
				if _call_bool(host, "_is_enemy_below_threshold", [enemy, 0.30]):
					host.call("_damage_enemy", enemy, base_damage * 1.2, "ORDER", Color(1.0, 0.24, 0.24))
					execute_count += 1
				else:
					host.call("_apply_enemy_status", enemy, "marked", 1.4, 0.22, 1, 0.3)
			if execute_count > 0:
				host.call("_gain_energy", 1.2 + float(execute_count) * 0.4)
		"singularist_dust":
			host.call("_pull_enemies_burst", center, reward_radius * 0.84, 8, 22.0)
			var tree: SceneTree = host.get_tree()
			if tree != null and host.has_method("_on_singularist_implode_timeout"):
				tree.create_timer(0.18).timeout.connect(
					Callable(host, "_on_singularist_implode_timeout").bind(center, reward_radius * 0.42, 0.52),
					CONNECT_ONE_SHOT
				)
		"quartermaster_reload":
			host.call("_gain_energy", 2.0)
			host.call("_apply_temp_attack_boost", 1.8, 0.10)
			host.call("_refund_skill_cooldown", "q", 0.8)
			host.call("_refund_skill_cooldown", "e", 0.8)

static func _call_array(host: Node, method_name: String, args: Array = []) -> Array:
	if host == null or not is_instance_valid(host) or not host.has_method(method_name):
		return []
	var result: Variant = host.callv(method_name, args)
	return result if result is Array else []

static func _call_bool(host: Node, method_name: String, args: Array = []) -> bool:
	if host == null or not is_instance_valid(host) or not host.has_method(method_name):
		return false
	return bool(host.callv(method_name, args))

static func _call_float(host: Node, method_name: String, fallback: float = 0.0, args: Array = []) -> float:
	if host == null or not is_instance_valid(host) or not host.has_method(method_name):
		return fallback
	return float(host.callv(method_name, args))

static func _call_vec2(host: Node, method_name: String, fallback: Vector2 = Vector2.ZERO, args: Array = []) -> Vector2:
	if host == null or not is_instance_valid(host) or not host.has_method(method_name):
		return fallback
	var result: Variant = host.callv(method_name, args)
	return result if result is Vector2 else fallback
