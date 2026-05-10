extends Node
class_name HealthComponent

const COMBAT_EVENT_TYPES := preload("res://scenes/components/combat_event_types.gd")

signal on_unit_hit
signal damage_applied(applied_damage: float, payload: Dictionary)
signal heal_applied(applied_amount: float, overflow_amount: float)
signal on_unit_died
signal on_health_changed(current: float, max: float)

var max_health: float = 1.0:
	set(value):
		max_health = value
		on_health_changed.emit(current_health, max_health)

var current_health: float = 1.0:
	set(value):
		current_health = value
		on_health_changed.emit(current_health, max_health)

# Debug overlay and future shield systems can use this generic gate.
var is_invincible: bool = false

func setup_with_health(health_value: float) -> void:
	max_health = health_value
	current_health = max_health

func setup(stats) -> void:
	if stats and "health" in stats:
		setup_with_health(stats.health)
	else:
		setup_with_health(100.0)
	on_health_changed.emit(current_health, max_health)

func take_damage(value: float, payload: Dictionary = {}) -> void:
	if is_invincible:
		return
	if current_health <= 0.0:
		print("[HealthComponent] already dead, ignore damage")
		return

	var damage_payload: Dictionary = payload.duplicate(true)
	damage_payload["damage_type"] = COMBAT_EVENT_TYPES.normalize_damage_type(
		damage_payload.get("damage_type", COMBAT_EVENT_TYPES.DamageType.DIRECT)
	)
	damage_payload["is_shared_damage"] = bool(damage_payload.get("is_shared_damage", false))

	var owner_node: Node = get_parent()
	if owner_node and owner_node.has_method("preprocess_incoming_damage"):
		var local_preprocess_result: Variant = owner_node.call("preprocess_incoming_damage", value, damage_payload)
		if local_preprocess_result is Dictionary:
			var local_preprocess_dict: Dictionary = local_preprocess_result
			value = float(local_preprocess_dict.get("damage", value))
			var local_processed_payload: Variant = local_preprocess_dict.get("payload", damage_payload)
			if local_processed_payload is Dictionary:
				damage_payload = (local_processed_payload as Dictionary).duplicate(true)
	if BondManager != null and BondManager.has_method("preprocess_damage"):
		var preprocess_result: Variant = BondManager.preprocess_damage(owner_node, value, damage_payload)
		if preprocess_result is Dictionary:
			var preprocess_dict: Dictionary = preprocess_result
			value = float(preprocess_dict.get("damage", value))
			var processed_payload: Variant = preprocess_dict.get("payload", damage_payload)
			if processed_payload is Dictionary:
				damage_payload = (processed_payload as Dictionary).duplicate(true)

	if owner_node and owner_node.has_method("has_status") and owner_node.has_status("marked") and not owner_node.has_meta("ignore_incoming_damage_multiplier_once"):
		var marked_value: float = 0.0
		if "active_statuses" in owner_node and owner_node.active_statuses.has("marked"):
			marked_value = float(owner_node.active_statuses["marked"].value)
		elif owner_node.has_node("StatusComponent"):
			marked_value = float(owner_node.get_node("StatusComponent").get_status_value("marked"))
		if marked_value > 0.0:
			value *= (1.0 + marked_value)

	if owner_node and owner_node.has_method("get_incoming_damage_multiplier") and not owner_node.has_meta("ignore_incoming_damage_multiplier_once"):
		value *= float(owner_node.call("get_incoming_damage_multiplier"))

	var previous_health: float = current_health
	current_health -= value
	if current_health < 0.01:
		current_health = 0.0

	var applied_damage: float = max(0.0, previous_health - current_health)
	if applied_damage > 0.0:
		damage_payload["applied_damage"] = applied_damage
		damage_payload["target"] = owner_node
		damage_applied.emit(applied_damage, damage_payload)
		if owner_node and owner_node.has_method("on_health_component_damage_applied"):
			owner_node.call("on_health_component_damage_applied", applied_damage, damage_payload)
		if BondManager != null and BondManager.has_method("record_damage_event"):
			BondManager.record_damage_event(
				damage_payload.get("source", null),
				owner_node,
				applied_damage,
				damage_payload
			)

	on_unit_hit.emit()
	on_health_changed.emit(current_health, max_health)

	if current_health == 0.0:
		if BondManager != null and BondManager.has_method("try_prevent_player_lethal"):
			var lethal_result: Variant = BondManager.try_prevent_player_lethal(owner_node, damage_payload)
			if lethal_result is Dictionary and bool((lethal_result as Dictionary).get("prevent_death", false)):
				current_health = max(1.0, float((lethal_result as Dictionary).get("restored_health", current_health)))
				on_health_changed.emit(current_health, max_health)
				return
		print("[HealthComponent] health reached zero, emit death")
		on_unit_died.emit()
		die()

func heal(amount: float) -> void:
	if current_health <= 0.0:
		return
	var previous_health: float = current_health
	current_health += amount
	current_health = min(current_health, max_health)
	var applied_amount: float = max(0.0, current_health - previous_health)
	var overflow_amount: float = max(0.0, previous_health + amount - max_health)
	heal_applied.emit(applied_amount, overflow_amount)
	var owner_node: Node = get_parent()
	if owner_node and owner_node.has_method("on_health_component_healed"):
		owner_node.call("on_health_component_healed", applied_amount, overflow_amount)
	if BondManager != null and BondManager.has_method("on_health_component_healed"):
		BondManager.on_health_component_healed(owner_node, applied_amount, overflow_amount)

func die() -> void:
	pass
