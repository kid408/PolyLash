extends RefCounted
class_name FSignaturePickupService

const LootPackService = preload("res://scripts/qef/services/loot_pack_service.gd")
const FRewardEffectService = preload("res://scripts/qef/services/f_reward_effect_service.gd")
const QEFRuntimeService = preload("res://scripts/qef/core/qef_runtime_service.gd")

const MAX_ACTIVE_PICKUPS: int = 8

static func spawn_pickup(
	host: Node,
	pickups: Array,
	role_id: String,
	center: Vector2,
	color: Color,
	reward: Dictionary,
	lifetime_sec: float = 6.0
) -> void:
	var player_ref: Node = _resolve_player_ref(host)
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	if player_ref == null or not is_instance_valid(player_ref):
		return
	_compact_pickups(pickups)

	if pickups.size() >= MAX_ACTIVE_PICKUPS:
		var oldest_var: Variant = pickups[0]
		if oldest_var is Node:
			var oldest: Node = oldest_var
			if is_instance_valid(oldest) and not oldest.is_queued_for_deletion():
				oldest.queue_free()
		_erase_node_from_array(pickups, oldest_var)

	var reward_payload: Dictionary = reward.duplicate(true)
	if not reward_payload.has("vfx_color"):
		reward_payload["vfx_color"] = color

	var pickup: Node = LootPackService.spawn_pack(
		player_ref,
		role_id,
		center,
		reward_payload,
		lifetime_sec,
		str(reward.get("effect_id", "signature_pack"))
	)
	if pickup != null and is_instance_valid(pickup):
		pickups.append(pickup)

	sync_runtime(host, pickups)

static func spawn_pickup_burst(
	host: Node,
	pickups: Array,
	role_id: String,
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
		spawn_pickup(host, pickups, role_id, pos, color, reward, lifetime_sec)

static func update_pickups(host: Node, pickups: Array, delta: float = 0.0) -> void:
	var _unused_delta: float = delta
	if pickups.is_empty():
		return

	if _compact_pickups(pickups):
		sync_runtime(host, pickups)

static func collect_pickup(host: Node, pickups: Array, pickup: Node2D) -> void:
	if pickup == null or not is_instance_valid(pickup):
		return

	if pickup.is_in_group("qef_loot_packs"):
		LootPackService.collect_pack(pickup, _resolve_player_node(host))
	else:
		var reward_var: Variant = pickup.get_meta("reward", {})
		var reward: Dictionary = reward_var if reward_var is Dictionary else {}
		apply_reward(host, pickup.global_position, reward)
		pickup.queue_free()

	_erase_node_from_array(pickups, pickup)
	sync_runtime(host, pickups)

static func apply_reward(host: Node, center: Vector2, reward: Dictionary) -> void:
	if host == null or not is_instance_valid(host) or reward.is_empty():
		return

	var player_node: Node2D = _resolve_player_node(host)
	var global_node: Node = _resolve_global_node(host)
	var text: String = str(reward.get("pickup_text", "PICKUP")).strip_edges()
	var text_color: Color = _resolve_color(reward, "text_color", Color(1.0, 0.9, 0.4))
	var vfx_color: Color = _resolve_color(reward, "vfx_color", Color(1.0, 0.9, 0.4, 0.9))
	var effect_scale: float = float(reward.get("effect_scale", 0.58))
	var reward_radius: float = max(60.0, float(reward.get("radius", 120.0)))

	FRewardEffectService.apply_signature_effect(host, center, reward_radius, reward)

	if reward.has("energy_gain") and host.has_method("_gain_energy"):
		host.call("_gain_energy", float(reward.get("energy_gain", 0.0)))
	if reward.has("armor_gain") and host.has_method("_add_player_armor"):
		host.call("_add_player_armor", int(reward.get("armor_gain", 0)))
	if reward.has("cooldown_slot") and reward.has("cooldown_refund") and host.has_method("_refund_skill_cooldown"):
		host.call(
			"_refund_skill_cooldown",
			str(reward.get("cooldown_slot", "")),
			float(reward.get("cooldown_refund", 0.0))
		)
	if (
		reward.has("temp_meta_key")
		and reward.has("temp_meta_delta")
		and reward.has("temp_meta_duration")
		and host.has_method("_apply_temp_meta_delta")
	):
		host.call(
			"_apply_temp_meta_delta",
			str(reward.get("temp_meta_key", "")),
			float(reward.get("temp_meta_delta", 0.0)),
			float(reward.get("temp_meta_duration", 0.0))
		)

	if player_node != null and global_node != null and global_node.has_method("spawn_floating_text"):
		global_node.call("spawn_floating_text", player_node.global_position, text, text_color)
	if host.has_method("spawn_skill_vfx"):
		host.call("spawn_skill_vfx", center, vfx_color, effect_scale)

static func clear_pickups(host: Node, pickups: Array) -> void:
	for pickup in pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	pickups.clear()
	sync_runtime(host, pickups)

static func sync_runtime(host: Node, pickups: Array) -> int:
	if host == null or not is_instance_valid(host):
		return 0

	var active_pickup_count: int = pickups.size()
	var player_ref: Node = _resolve_player_ref(host)
	var player_id: String = _resolve_player_id(player_ref)
	if not player_id.is_empty():
		active_pickup_count = LootPackService.count_active_packs(player_id)
		QEFRuntimeService.set_active_pickup_count(player_ref, active_pickup_count)

	if host.has_method("update_runtime_profile"):
		host.call("update_runtime_profile", {
			"active_pickup_count": active_pickup_count,
		})
	return active_pickup_count

static func _resolve_player_ref(host: Node) -> Node:
	if host == null or not is_instance_valid(host):
		return null
	if "player_ref" in host:
		var player_ref_var: Variant = host.get("player_ref")
		return player_ref_var as Node
	return null

static func _resolve_player_node(host: Node) -> Node2D:
	if host != null and is_instance_valid(host) and host.has_method("_get_player_node"):
		var player_node_var: Variant = host.call("_get_player_node")
		return player_node_var if player_node_var is Node2D else null
	var player_ref: Node = _resolve_player_ref(host)
	return player_ref as Node2D

static func _resolve_player_id(player_ref: Node) -> String:
	if player_ref == null or not is_instance_valid(player_ref):
		return ""
	if "player_id" in player_ref:
		return str(player_ref.get("player_id")).strip_edges()
	return ""

static func _resolve_global_node(host: Node) -> Node:
	if host == null or not is_instance_valid(host):
		return null
	if host.has_method("_get_autoload_node"):
		var global_var: Variant = host.call("_get_autoload_node", "Global")
		return global_var as Node
	return null

static func _resolve_color(source: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = source.get(key, fallback)
	return value if value is Color else fallback

static func _erase_node_from_array(arr: Array, node: Variant) -> void:
	var target_is_object: bool = typeof(node) == TYPE_OBJECT
	var target_valid: bool = target_is_object and node != null and is_instance_valid(node)
	for idx: int in range(arr.size() - 1, -1, -1):
		var entry: Variant = arr[idx]
		if entry == null:
			arr.remove_at(idx)
			continue
		var entry_is_object: bool = typeof(entry) == TYPE_OBJECT
		if entry_is_object and not is_instance_valid(entry):
			arr.remove_at(idx)
			continue
		if target_valid and entry_is_object and entry == node:
			arr.remove_at(idx)
			return

static func _compact_pickups(pickups: Array) -> bool:
	var removed: bool = false
	for idx: int in range(pickups.size() - 1, -1, -1):
		var entry: Variant = pickups[idx]
		if entry == null:
			pickups.remove_at(idx)
			removed = true
			continue
		var entry_is_object: bool = typeof(entry) == TYPE_OBJECT
		if entry_is_object and not is_instance_valid(entry):
			pickups.remove_at(idx)
			removed = true
			continue
		if entry is Node and (entry as Node).is_queued_for_deletion():
			pickups.remove_at(idx)
			removed = true
	return removed
